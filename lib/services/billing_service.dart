import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:in_app_purchase/in_app_purchase.dart';

import 'storage_service.dart';

enum BillingStatus { unknown, loading, subscribed, failed, pending }

class BillingService {
  final InAppPurchase _iap = InAppPurchase.instance;
  final StorageService storage;

  BillingService(this.storage) {
    _init();
  }

  static const String monthlyId = 'cal_matters_monthly';
  static const String yearlyId = 'cal_matters_yearly';

  BillingStatus status = BillingStatus.unknown;
  String? error;

  VoidCallback? onStatusChanged;
  StreamSubscription<List<PurchaseDetails>>? _sub;

  void _init() {
    _iap.isAvailable().then((isAvailable) {
      if (!isAvailable) {
        status = BillingStatus.failed;
        error = 'In-app billing not available on this device';
        onStatusChanged?.call();
      }
    });
    _sub = _iap.purchaseStream.listen(_handlePurchases, onError: (e) {});
  }

  /// Queries the two subscription products from the store.
  Future<List<ProductDetails>> loadProducts() async {
    try {
      final res = await _iap.queryProductDetails({
        monthlyId,
        yearlyId,
      });
      if (res.productDetails.isEmpty) {
        error = 'Products not found — create them in Play Console first';
        onStatusChanged?.call();
      }
      return res.productDetails;
    } catch (e) {
      error = 'Failed to load products: $e';
      onStatusChanged?.call();
      return [];
    }
  }

  /// Launches the store's subscription purchase UI.
  Future<void> buyUnit(ProductDetails product) async {
    try {
      status = BillingStatus.loading;
      onStatusChanged?.call();
      await _iap.buyNonConsumable(
        purchaseParam: PurchaseParam(productDetails: product),
      );
      // On success the purchaseStream listener calls _handlePurchases which
      // saves paid=true and flips status to subscribed.
    } catch (e) {
      error = 'Purchase failed: $e';
      status = BillingStatus.failed;
      onStatusChanged?.call();
    }
  }

  Future<void> _handlePurchases(List<PurchaseDetails> purchases) async {
    for (final purchase in purchases) {
      if (purchase.status == PurchaseStatus.purchased ||
          purchase.status == PurchaseStatus.restored) {
        final plan = purchase.productID == yearlyId ? 'yearly' : 'monthly';
        await storage.startTrial(plan);
        await storage.savePaid(true);
        status = BillingStatus.subscribed;
      } else if (purchase.status == PurchaseStatus.error) {
        status = BillingStatus.failed;
        error = 'Purchase error: ${purchase.error?.message}';
      } else if (purchase.status == PurchaseStatus.canceled) {
        status = BillingStatus.failed;
        error = 'Purchase cancelled';
      } else {
        status = BillingStatus.pending;
      }
      onStatusChanged?.call();
    }
  }

  /// Restores previous purchases (new device / reinstall).
  Future<void> restore() async {
    try {
      await _iap.restorePurchases();
    } catch (_) {
      error = 'Restore failed';
      onStatusChanged?.call();
    }
  }

  void dispose() {
    _sub?.cancel();
  }
}
