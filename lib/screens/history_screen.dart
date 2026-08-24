import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/food_entry.dart';
import '../services/storage_service.dart';

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
    return Scaffold(
      appBar: AppBar(title: const Text('History')),
      body: _entries.isEmpty
          ? const Center(child: Text('No meals logged yet'))
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: _entries.length,
              itemBuilder: (context, index) {
                final entry = _entries[index];
                final day = DateFormat('EEE, d MMM yyyy')
                    .format(entry.dateTime);
                final time = DateFormat('h:mm a').format(entry.dateTime);
                final itemsStr =
                    entry.items.map((e) => e.name).join(', ');

                return Card(
                  margin: const EdgeInsets.only(bottom: 12),
                  child: ListTile(
                    leading: CircleAvatar(
                      backgroundColor: Colors.orange.shade100,
                      child: Text(
                        entry.mealType[0].toUpperCase(),
                        style: const TextStyle(color: Colors.deepOrange),
                      ),
                    ),
                    title: Text('${_capitalize(entry.mealType)} · $time'),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(day),
                        Text(itemsStr, maxLines: 2, overflow: TextOverflow.ellipsis),
                      ],
                    ),
                    trailing: Text(
                      '${entry.totalCalories} kcal',
                      style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Colors.deepOrange),
                    ),
                    onLongPress: () => _confirmDelete(entry),
                  ),
                );
              },
            ),
    );
  }

  Future<void> _confirmDelete(FoodEntry entry) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete entry?'),
        content: const Text('This cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete'),
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

  String _capitalize(String s) =>
      s.isEmpty ? s : s[0].toUpperCase() + s.substring(1);
}
