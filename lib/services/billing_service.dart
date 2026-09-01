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

  static String monthlyId = 'cal_matters_monthly';
  static String yearlyId = 'cal_matters_yearly';

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

  /// Picks the product entry to purchase: Google Play returns one
  /// [ProductDetails] per base plan/offer, so the free-trial offer shows up
  /// as its own entry whose first pricing phase is free (rawPrice 0).
  /// Preferring it means subscribing starts the free trial; when the offer
  /// isn't available (already used / not eligible / iOS), fall back to the
  /// base plan.
  ProductDetails? productFor(
    List<ProductDetails> products,
    String productId, {
    bool preferTrial = false,
  }) {
    final matches = products.where((p) => p.id == productId).toList();
    if (matches.isEmpty) return null;
    if (preferTrial) {
      for (final p in matches) {
        if (p.rawPrice <= 0) return p;
      }
    }
    return matches.first;
  }

  /// Launches the store's subscription purchase UI.
  ///
  /// On Android the free-trial offer token is read directly off the
  /// [GooglePlayProductDetails] entry we pass in, so passing the trial entry
  /// here starts the offer. The purchaseStream listener then saves paid=true
  /// and flips status to subscribed.
  Future<void> buyUnit(ProductDetails product) async {
    try {
      status = BillingStatus.loading;
      onStatusChanged?.call();
      await _iap.buyNonConsumable(
        purchaseParam: PurchaseParam(productDetails: product),
      );
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
        // Trial is part of the Play subscription offer — no app timer.
        // Record which plan the user picked (monthly | yearly).
        final plan = purchase.productID == yearlyId ? 'yearly' : 'monthly';
        await storage.setSubscriptionPlan(plan);
        await storage.savePaid(true);
        status = BillingStatus.subscribed;
    } else if (purchase.status == PurchaseStatus.error) {
      status = BillingStatus.failed;
      error = 'Purchase error: ${purchase.error?.message}';
    } else if (purchase.status == PurchaseStatus.canceled) {
      // The purchase being cancelled:
      //
      //   * Trial/subscription expired or was cancelled -> Play will stop
      //     renewing, but we must NOT blind-revoke: a device-side cache
      //     could be stale while the user is still in grace/hold period, or
      //     the account may genuinely still be active (cloud is source of
      //     truth for paid work done on other devices).
      //
      //   * BUT if the user is on the no-internet edge or has no cloud doc,
      //     the safer move is preserving the last known paid state rather
      //     than locking them out of the app mid-test.
      //
      // So: do not flip savePaid(false) here. The app's `isPaid` gate will
      // follow PaymentState from Play (cloud sync on next load) or the user
      // can restore their purchase from the paywall via "Restore purchase".
      status = BillingStatus.failed;
      error = 'Subscription not active — restore your purchase from the paywall.';
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
