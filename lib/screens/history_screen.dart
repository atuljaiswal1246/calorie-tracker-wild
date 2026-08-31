import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/food_entry.dart';
import '../services/storage_service.dart';
import '../theme/app_colors.dart';
import '../widgets/widgets.dart';
import 'meal_detail_screen.dart';

class HistoryScreen extends StatefulWidget {
  final StorageService storage;

  const HistoryScreen({super.key, required this.storage});

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
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
              child: Row(
                children: [
                  GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: const Icon(Icons.arrow_back_ios_new, color: AppColors.ink, size: 20),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
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
                    style: const TextStyle(
                      fontSize: 13,
                      color: AppColors.muted,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Expanded(
              child: _entries.isEmpty
                  ? const Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text('🍽️', style: TextStyle(fontSize: 48)),
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
                  : ListView.builder(
                      padding: const EdgeInsets.fromLTRB(20, 0, 20, 100),
                      itemCount: sorted.length,
                      itemBuilder: (context, index) {
                        final entry = sorted[index];
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 10),
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
        title: const Text('Delete entry?'),
        content: const Text('This cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete', style: TextStyle(color: AppColors.missedRed)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await widget.storage.deleteEntry(entry.id);
      setState(() {
        _entries = widget.storage.entries;
      });
    }
  }
}
