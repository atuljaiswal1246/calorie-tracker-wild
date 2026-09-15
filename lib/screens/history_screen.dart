import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/food_entry.dart';
import '../services/storage_service.dart';
import '../theme/app_colors.dart';
import '../widgets/widgets.dart';
import 'meal_detail_screen.dart';

class HistoryScreen extends StatefulWidget {
  final StorageService storage;

  HistoryScreen({super.key, required this.storage});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  late List<FoodEntry> _entries;

  @override
  void initState() {
    super.initState();
    _entries = widget.storage.entries;
  }

  Future<void> _refresh() async {
    try {
      final cloud = await widget.storage.loadEntriesFromCloud();
      if (mounted) {
        setState(() => _entries = cloud);
      }
    } catch (_) {
      // Offline — pull-to-refresh silently keeps local data.
    }
  }

  @override
  Widget build(BuildContext context) {
    final sorted = List<FoodEntry>.from(_entries)
      ..sort((a, b) => b.dateTime.compareTo(a.dateTime));

    return Scaffold(
      backgroundColor: AppColors.bg,
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: EdgeInsets.fromLTRB(20, 16, 20, 0),
              child: Row(
                children: [
                  GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: Icon(Icons.arrow_back_ios_new, color: AppColors.ink, size: 20),
                  ),
                  SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'History',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: AppColors.ink,
                      ),
                    ),
                  ),
                  Text(
                    '${_entries.length} meals',
                    style: TextStyle(
                      fontSize: 13,
                      color: AppColors.muted,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(height: 16),
            Expanded(
              child: _entries.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const EmptyIllustration(
                            asset: 'assets/illustrations/empty_meals.jpg',
                            size: 132,
                          ),
                          SizedBox(height: 16),
                          Text(
                            'No meals logged yet',
                            style: TextStyle(
                              fontSize: 16,
                              color: AppColors.muted,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    )
                  : RefreshIndicator(
                      color: AppColors.ink,
                      onRefresh: _refresh,
                      child: ListView.builder(
                      padding: EdgeInsets.fromLTRB(20, 0, 20, 100),
                      keyboardDismissBehavior:
                          ScrollViewKeyboardDismissBehavior.onDrag,
                      physics: AlwaysScrollableScrollPhysics(),
                      itemCount: sorted.length,
                      itemBuilder: (context, index) {
                        final entry = sorted[index];
                        return Padding(
                          padding: EdgeInsets.only(bottom: 10),
                          child: MealCard(
                            entry: entry,
                            onTap: () {
                              Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (_) => MealDetailScreen(
                                    entry: entry,
                                    storage: widget.storage,
                                    onDeleted: () => _confirmDelete(entry),
                                  ),
                                ),
                              );
                            },
                            onLongPress: () => _confirmDelete(entry),
                          ),
                        );
                      },
                    ),
                  ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _confirmDelete(FoodEntry entry) async {
    HapticFeedback.mediumImpact();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text('Delete entry?'),
        content: Text('You can undo this right after.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text('Delete', style: TextStyle(color: AppColors.missedRed)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await widget.storage.deleteEntry(entry.id);
      setState(() {
        _entries = widget.storage.entries;
      });
      if (!mounted) return;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: Text('Entry deleted'),
            behavior: SnackBarBehavior.floating,
            margin: EdgeInsets.fromLTRB(16, 0, 16, 92),
            duration: Duration(seconds: 6),
            action: SnackBarAction(
              label: 'Undo',
              onPressed: () async {
                await widget.storage.restoreEntry(entry);
                if (!mounted) return;
                setState(() {
                  _entries = widget.storage.entries;
                });
              },
            ),
          ),
        );
    }
  }
}
