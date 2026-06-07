import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../services/firestore_service.dart';
import '../../models/ticket.dart';

class ManageTicketsScreen extends StatefulWidget {
  const ManageTicketsScreen({super.key});

  @override
  State<ManageTicketsScreen> createState() => _ManageTicketsScreenState();
}

class _ManageTicketsScreenState extends State<ManageTicketsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabCtrl;
  final _firestore = FirestoreService();

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: 4, vsync: this);
  }

  @override
  void dispose() {
    _tabCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Manage Tickets'),
        bottom: TabBar(
          controller: _tabCtrl,
          isScrollable: true,
          tabs: const [
            Tab(text: 'Help Requests'),
            Tab(text: 'Class Changes'),
            Tab(text: 'Error Reports'),
            Tab(text: 'Feedback'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabCtrl,
        children: [
          _HelpRequestsTab(firestore: _firestore),
          _ClassChangeRequestsTab(firestore: _firestore),
          _ErrorReportsTab(firestore: _firestore),
          _FeedbackTab(firestore: _firestore),
        ],
      ),
    );
  }
}

// --- Help Requests Tab ---

class _HelpRequestsTab extends StatelessWidget {
  final FirestoreService firestore;
  const _HelpRequestsTab({required this.firestore});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<HelpRequest>>(
      stream: firestore.getHelpRequestsStream(),
      builder: (context, snap) {
        if (snap.hasError) return Center(child: Text('Error: ${snap.error}'));
        if (!snap.hasData) return const Center(child: CircularProgressIndicator());
        final items = snap.data!;
        if (items.isEmpty) return const Center(child: Text('No help requests yet.', style: TextStyle(color: Colors.grey)));
        return ListView.builder(
          itemCount: items.length,
          itemBuilder: (_, i) {
            final item = items[i];
            return Card(
              margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              child: ListTile(
                leading: CircleAvatar(
                  backgroundColor: item.status == 'resolved' ? Colors.green[100] : Colors.orange[100],
                  child: Icon(
                    item.status == 'resolved' ? Icons.check_circle : Icons.help_outline,
                    color: item.status == 'resolved' ? Colors.green : Colors.orange,
                  ),
                ),
                title: Text(item.title, style: const TextStyle(fontWeight: FontWeight.w600)),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('${item.userName} - ${item.userEmail}'),
                    Text(item.message, maxLines: 2, overflow: TextOverflow.ellipsis),
                  ],
                ),
                trailing: item.status == 'pending'
                    ? TextButton(
                        onPressed: () => firestore.resolveHelpRequest(item.id, 'Admin'),
                        child: const Text('Resolve', style: TextStyle(color: Colors.green)),
                      )
                    : const Icon(Icons.check, size: 18, color: Colors.green),
                isThreeLine: true,
              ),
            );
          },
        );
      },
    );
  }
}

// --- Class Change Requests Tab ---

class _ClassChangeRequestsTab extends StatelessWidget {
  final FirestoreService firestore;
  const _ClassChangeRequestsTab({required this.firestore});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: firestore.getClassChangeRequestsStream(),
      builder: (context, snap) {
        if (snap.hasError) return Center(child: Text('Error: ${snap.error}'));
        if (!snap.hasData) return const Center(child: CircularProgressIndicator());
        final docs = snap.data!.docs;
        if (docs.isEmpty) return const Center(child: Text('No class change requests.', style: TextStyle(color: Colors.grey)));
        return ListView.builder(
          itemCount: docs.length,
          itemBuilder: (_, i) {
            final doc = docs[i];
            final d = doc.data() as Map<String, dynamic>;
            final status = d['status'] ?? 'pending';
            return Card(
              margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              child: ListTile(
                leading: CircleAvatar(
                  backgroundColor: status == 'approved' ? Colors.green[100] : Colors.blue[100],
                  child: Icon(
                    status == 'approved' ? Icons.check_circle : Icons.swap_horiz,
                    color: status == 'approved' ? Colors.green : Colors.blue,
                  ),
                ),
                title: Text('${d['userName'] ?? ''}', style: const TextStyle(fontWeight: FontWeight.w600)),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(d['userEmail'] ?? ''),
                    Text('Wants: ${d['desiredClass'] ?? ''}'),
                    if ((d['reason'] ?? '').isNotEmpty) Text('Reason: ${d['reason']}'),
                  ],
                ),
                trailing: status == 'pending'
                    ? ElevatedButton(
                        onPressed: () => firestore.approveClassChangeRequest(
                          doc.id, d['userId'], d['desiredClass']),
                        style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
                        child: const Text('Approve', style: TextStyle(color: Colors.white, fontSize: 12)),
                      )
                    : const Icon(Icons.check, size: 18, color: Colors.green),
                isThreeLine: true,
              ),
            );
          },
        );
      },
    );
  }
}

// --- Error Reports Tab ---

class _ErrorReportsTab extends StatelessWidget {
  final FirestoreService firestore;
  const _ErrorReportsTab({required this.firestore});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<ErrorReport>>(
      stream: firestore.getErrorReportsStream(),
      builder: (context, snap) {
        if (snap.hasError) return Center(child: Text('Error: ${snap.error}'));
        if (!snap.hasData) return const Center(child: CircularProgressIndicator());
        final items = snap.data!;
        if (items.isEmpty) return const Center(child: Text('No error reports.', style: TextStyle(color: Colors.grey)));
        return ListView.builder(
          itemCount: items.length,
          itemBuilder: (_, i) {
            final item = items[i];
            return Card(
              margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              child: ListTile(
                leading: CircleAvatar(
                  backgroundColor: item.status == 'resolved' ? Colors.green[100] : Colors.red[100],
                  child: const Icon(Icons.bug_report, color: Colors.red),
                ),
                title: Text(item.title, style: const TextStyle(fontWeight: FontWeight.w600)),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('${item.userName} • v${item.appVersion}'),
                    Text(item.message, maxLines: 2, overflow: TextOverflow.ellipsis),
                  ],
                ),
                trailing: PopupMenuButton<String>(
                  onSelected: (v) => firestore.updateErrorReportStatus(item.id, v),
                  itemBuilder: (_) => [
                    const PopupMenuItem(value: 'acknowledged', child: Text('Acknowledge')),
                    const PopupMenuItem(value: 'resolved', child: Text('Mark Resolved')),
                  ],
                ),
                isThreeLine: true,
              ),
            );
          },
        );
      },
    );
  }
}

// --- Feedback Tab ---

class _FeedbackTab extends StatelessWidget {
  final FirestoreService firestore;
  const _FeedbackTab({required this.firestore});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<AppFeedback>>(
      stream: firestore.getFeedbackStream(),
      builder: (context, snap) {
        if (snap.hasError) return Center(child: Text('Error: ${snap.error}'));
        if (!snap.hasData) return const Center(child: CircularProgressIndicator());
        final items = snap.data!;
        if (items.isEmpty) return const Center(child: Text('No feedback yet.', style: TextStyle(color: Colors.grey)));
        return ListView.builder(
          itemCount: items.length,
          itemBuilder: (_, i) {
            final item = items[i];
            return Card(
              margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              child: ListTile(
                leading: CircleAvatar(
                  backgroundColor: Colors.amber[100],
                  child: Text(item.rating != null ? '$item.rating' : '☆', style: const TextStyle(fontWeight: FontWeight.bold)),
                ),
                title: Text(item.userName, style: const TextStyle(fontWeight: FontWeight.w600)),
                subtitle: Text(item.message, maxLines: 2, overflow: TextOverflow.ellipsis),
                trailing: item.status == 'new'
                  ? TextButton(
                      onPressed: () => firestore.markFeedbackRead(item.id),
                      child: const Text('Mark Read', style: TextStyle(fontSize: 12)),
                    )
                  : null,
              ),
            );
          },
        );
      },
    );
  }
}
