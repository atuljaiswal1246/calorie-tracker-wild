import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/storage_service.dart';

class GroupsScreen extends StatefulWidget {
  final StorageService storage;
  const GroupsScreen({super.key, required this.storage});

  @override
  State<GroupsScreen> createState() => _GroupsScreenState();
}

class _GroupsScreenState extends State<GroupsScreen> {
  static const _bg = Color(0xFFFAF9F7);
  static const _ink = Color(0xFF1C1C1E);
  static const _muted = Color(0xFF8E8E93);
  static const _cardShadow = [
    BoxShadow(
      color: Color(0x0F000000),
      blurRadius: 24,
      offset: Offset(0, 8),
    ),
  ];

  String? get _uid => FirebaseAuth.instance.currentUser?.uid;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        backgroundColor: _bg,
        surfaceTintColor: _ink,
        title: const Text(
          'Groups',
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.w800,
            color: _ink,
            letterSpacing: -0.5,
          ),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, size: 20, color: _ink),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          TextButton.icon(
            onPressed: () => _showCreateGroupSheet(context),
            icon: const Icon(Icons.add_rounded, size: 18),
            label: const Text(
              'New group',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
            ),
            style: TextButton.styleFrom(
              foregroundColor: _ink,
              padding: const EdgeInsets.symmetric(horizontal: 16),
            ),
          ),
        ],
      ),
      body: _uid == null
          ? const Center(
              child: Text(
                'Sign in to use groups',
                style: TextStyle(fontSize: 16, color: _muted),
              ),
            )
          : StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('groups')
                  .where('members', arrayContains: _uid)
                  .orderBy('createdAt', descending: true)
                  .snapshots(),
              builder: (ctx, snap) {
                if (snap.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                final docs = snap.data?.docs ?? [];
                if (docs.isEmpty) return _buildEmpty();
                return ListView.builder(
                  padding: const EdgeInsets.fromLTRB(20, 10, 20, 100),
                  itemCount: docs.length,
                  itemBuilder: (ctx, i) => _groupCard(docs[i]),
                );
              },
            ),
    );
  }

  Widget _buildEmpty() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.group_outlined, size: 56, color: _muted.withOpacity(0.4)),
          const SizedBox(height: 14),
          const Text(
            'No groups yet',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: _ink,
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            'Create a group to share progress\nwith friends and family.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 14,
              color: _muted,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }

  Widget _groupCard(QueryDocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    final name = data['name'] as String? ?? 'Group';
    final members = (data['members'] as List?)?.length ?? 0;
    final createdBy = data['createdBy'] as String? ?? '';

    return GestureDetector(
      onTap: () => _openGroup(doc.id, name),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: _cardShadow,
        ),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: _ink.withOpacity(0.06),
                borderRadius: BorderRadius.circular(14),
              ),
              child: const Icon(Icons.group, color: _ink, size: 24),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name,
                    style: const TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w700,
                      color: _ink,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '$members member${members == 1 ? '' : 's'}',
                    style: const TextStyle(
                      fontSize: 13,
                      color: _muted,
                    ),
                  ),
                ],
              ),
            ),
            if (createdBy == _uid)
              GestureDetector(
                onTap: () => _showInviteCode(doc.id),
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: _ink.withOpacity(0.06),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.share, size: 16, color: _ink),
                ),
              ),
          ],
        ),
      ),
    );
  }

  void _openGroup(String groupId, String name) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => GroupDetailScreen(
          groupId: groupId,
          groupName: name,
          storage: widget.storage,
        ),
      ),
    );
  }

  void _showCreateGroupSheet(BuildContext context) {
    final nameController = TextEditingController();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => Padding(
        padding: EdgeInsets.fromLTRB(
            24, 24, 24, MediaQuery.of(ctx).viewInsets.bottom + 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Create a group',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w700,
                color: _ink,
              ),
            ),
            const SizedBox(height: 4),
            const Text(
              'Friends can join with the invite code',
              style: TextStyle(fontSize: 13, color: _muted),
            ),
            const SizedBox(height: 20),
            TextField(
              controller: nameController,
              autofocus: true,
              textCapitalization: TextCapitalization.words,
              style: const TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w600,
                color: _ink,
              ),
              decoration: InputDecoration(
                hintText: 'Group name',
                hintStyle: const TextStyle(color: _muted),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: const BorderSide(color: Color(0xFFE5E5EA)),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: const BorderSide(color: _ink, width: 2),
                ),
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              height: 54,
              child: FilledButton(
                onPressed: () async {
                  final name = nameController.text.trim();
                  if (name.isEmpty || _uid == null) return;
                  await FirebaseFirestore.instance.collection('groups').add({
                    'name': name,
                    'createdBy': _uid,
                    'members': [_uid],
                    'createdAt': FieldValue.serverTimestamp(),
                  });
                  if (ctx.mounted) Navigator.pop(ctx);
                },
                style: FilledButton.styleFrom(
                  backgroundColor: _ink,
                  foregroundColor: Colors.white,
                  shape: const StadiumBorder(),
                ),
                child: const Text(
                  'Create',
                  style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w600,
                      letterSpacing: -0.5),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showInviteCode(String groupId) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text(
          'Invite code',
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Share this code with friends to join:',
              style: TextStyle(fontSize: 14, color: _muted),
            ),
            const SizedBox(height: 16),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 16),
              decoration: BoxDecoration(
                color: _ink.withOpacity(0.06),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Center(
                child: Text(
                  groupId.substring(0, 8).toUpperCase(),
                  style: const TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.w800,
                    color: _ink,
                    letterSpacing: 4,
                    fontFamily: 'monospace',
                  ),
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }
}

class GroupDetailScreen extends StatefulWidget {
  final String groupId;
  final String groupName;
  final StorageService storage;

  const GroupDetailScreen({
    super.key,
    required this.groupId,
    required this.groupName,
    required this.storage,
  });

  @override
  State<GroupDetailScreen> createState() => _GroupDetailScreenState();
}

class _GroupDetailScreenState extends State<GroupDetailScreen> {
  static const _bg = Color(0xFFFAF9F7);
  static const _ink = Color(0xFF1C1C1E);
  static const _muted = Color(0xFF8E8E93);
  static const _cardShadow = [
    BoxShadow(
      color: Color(0x0F000000),
      blurRadius: 24,
      offset: Offset(0, 8),
    ),
  ];

  String? get _uid => FirebaseAuth.instance.currentUser?.uid;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        backgroundColor: _bg,
        surfaceTintColor: _ink,
        title: Text(
          widget.groupName,
          style: const TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.w800,
            color: _ink,
            letterSpacing: -0.5,
          ),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, size: 20, color: _ink),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 10, 20, 100),
        children: [
          _joinCodeSection(),
          const SizedBox(height: 20),
          _membersSection(),
          const SizedBox(height: 20),
          _activitySection(),
        ],
      ),
    );
  }

  Widget _joinCodeSection() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: _cardShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Share invite code',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: _ink,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                  decoration: BoxDecoration(
                    color: _ink.withOpacity(0.06),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Center(
                    child: Text(
                      widget.groupId.substring(0, 8).toUpperCase(),
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                        color: _ink,
                        letterSpacing: 3,
                        fontFamily: 'monospace',
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              GestureDetector(
                onTap: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Code copied!'),
                      behavior: SnackBarBehavior.floating,
                    ),
                  );
                },
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: _ink,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.copy, size: 20, color: Colors.white),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _membersSection() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: _cardShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Members',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: _ink,
            ),
          ),
          const SizedBox(height: 12),
          StreamBuilder<DocumentSnapshot>(
            stream: FirebaseFirestore.instance
                .collection('groups')
                .doc(widget.groupId)
                .snapshots(),
            builder: (ctx, snap) {
              if (!snap.hasData) return const SizedBox();
              final data = snap.data!.data() as Map<String, dynamic>?;
              final members = (data?['members'] as List?) ?? [];
              return Column(
                children: members.map<Widget>((memberId) {
                  final isMe = memberId == _uid;
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Row(
                      children: [
                        Container(
                          width: 36,
                          height: 36,
                          decoration: BoxDecoration(
                            color: _ink.withOpacity(0.06),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Icon(
                            isMe ? Icons.person : Icons.person_outline,
                            size: 18,
                            color: _ink,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            isMe ? 'You' : memberId.substring(0, 8),
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                              color: _ink,
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                }).toList(),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _activitySection() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: _cardShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Today\'s activity',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: _ink,
            ),
          ),
          const SizedBox(height: 12),
          StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection('groups')
                .doc(widget.groupId)
                .collection('activity')
                .orderBy('timestamp', descending: true)
                .limit(20)
                .snapshots(),
            builder: (ctx, snap) {
              if (!snap.hasData || snap.data!.docs.isEmpty) {
                return const Padding(
                  padding: EdgeInsets.symmetric(vertical: 20),
                  child: Center(
                    child: Text(
                      'No activity yet',
                      style: TextStyle(fontSize: 14, color: _muted),
                    ),
                  ),
                );
              }
              final docs = snap.data!.docs;
              return Column(
                children: docs.map<Widget>((doc) {
                  final data = doc.data() as Map<String, dynamic>;
                  final text = data['text'] as String? ?? '';
                  final time = data['timestamp'] as Timestamp?;
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Row(
                      children: [
                        const Icon(Icons.circle, size: 6, color: _muted),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            text,
                            style: const TextStyle(
                              fontSize: 14,
                              color: _ink,
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                }).toList(),
              );
            },
          ),
        ],
      ),
    );
  }
}
