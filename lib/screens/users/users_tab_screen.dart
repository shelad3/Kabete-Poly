import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/services.dart';
import '../../models/user_profile.dart';
import 'user_actions_sheet.dart';

class UsersTabScreen extends StatefulWidget {
  const UsersTabScreen({super.key});

  @override
  State<UsersTabScreen> createState() => _UsersTabScreenState();
}

class _UsersTabScreenState extends State<UsersTabScreen> {
  final _searchController = TextEditingController();
  String _searchQuery = '';
  String? _roleFilter;

  static const _roles = ['Official', 'Teacher', 'Leader', 'Student'];

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
          Container(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Search by name, reg no, or class...',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(icon: const Icon(Icons.clear), onPressed: () { _searchController.clear(); setState(() => _searchQuery = ''); })
                    : null,
              ),
              onChanged: (v) => setState(() => _searchQuery = v.toLowerCase()),
            ),
          ),
          const SizedBox(height: 8),
          SizedBox(
            height: 40,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              children: [
                _FilterChip(label: 'All', selected: _roleFilter == null, onTap: () => setState(() => _roleFilter = null)),
                ..._roles.map((r) => _FilterChip(
                  label: r,
                  selected: _roleFilter == r,
                  onTap: () => setState(() => _roleFilter = r),
                )),
              ],
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: _buildUserList(),
          ),
        ],
      ),
    );
  }

  Widget _buildUserList() {
    Query query = FirebaseFirestore.instance.collection('users');

    if (_roleFilter != null) {
      query = query.where('role', isEqualTo: _roleFilter);
    }

    return StreamBuilder<QuerySnapshot>(
      stream: query.snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.error_outline, size: 48, color: Colors.grey[400]),
                const SizedBox(height: 12),
                Text('Failed to load users', style: TextStyle(color: Colors.grey[600])),
              ],
            ),
          );
        }

        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        final users = snapshot.data!.docs
            .map((d) => UserProfile.fromJson(d.data() as Map<String, dynamic>))
            .where((u) => _matchesSearch(u))
            .toList()
          ..sort((a, b) => a.fullName.compareTo(b.fullName));

        if (users.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.people_outline, size: 48, color: Colors.grey[300]),
                const SizedBox(height: 12),
                Text('No users found', style: TextStyle(color: Colors.grey[500], fontSize: 16)),
              ],
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.symmetric(vertical: 4),
          itemCount: users.length,
          itemBuilder: (context, index) => _UserCard(
            user: users[index],
            onTap: () => _showActions(context, users[index]),
          ),
        );
      },
    );
  }

  bool _matchesSearch(UserProfile user) {
    if (_searchQuery.isEmpty) return true;
    return user.fullName.toLowerCase().contains(_searchQuery) ||
        user.registrationNumber.toLowerCase().contains(_searchQuery) ||
        user.email.toLowerCase().contains(_searchQuery) ||
        user.enrolledClasses.any((c) => c.toLowerCase().contains(_searchQuery));
  }

  void _showActions(BuildContext context, UserProfile user) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => UserActionsSheet(user: user),
    );
  }
}

class _FilterChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _FilterChip({required this.label, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).primaryColor;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Material(
        color: selected ? color : Colors.grey[200],
        borderRadius: BorderRadius.circular(20),
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Text(
              label,
              style: TextStyle(
                color: selected ? Colors.white : Colors.grey[700],
                fontWeight: selected ? FontWeight.w600 : FontWeight.normal,
                fontSize: 13,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _UserCard extends StatelessWidget {
  final UserProfile user;
  final VoidCallback onTap;

  const _UserCard({required this.user, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final color = _roleColor(context);
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      elevation: 1,
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        onLongPress: user.mobileNumber.isNotEmpty
            ? () {
                Clipboard.setData(ClipboardData(text: user.mobileNumber));
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                  content: Text('${user.fullName}\'s number copied'),
                  duration: const Duration(seconds: 2),
                ));
              }
            : null,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              CircleAvatar(
                radius: 24,
                backgroundColor: color.withValues(alpha: 0.15),
                backgroundImage: user.profilePhotoUrl.isNotEmpty ? NetworkImage(user.profilePhotoUrl) : null,
                child: user.profilePhotoUrl.isEmpty
                    ? Text(user.fullName[0].toUpperCase(), style: TextStyle(color: color, fontWeight: FontWeight.bold))
                    : null,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(user.fullName, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15)),
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: color.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(user.role, style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w600)),
                        ),
                        const SizedBox(width: 8),
                        if (user.mobileNumber.isNotEmpty)
                          Icon(Icons.phone, size: 14, color: Colors.grey[400]),
                        if (user.mobileNumber.isNotEmpty)
                          const SizedBox(width: 4),
                        Text(user.mobileNumber.isNotEmpty ? user.mobileNumber : 'No phone', style: TextStyle(color: Colors.grey[500], fontSize: 12)),
                      ],
                    ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right, color: Colors.grey[300], size: 20),
            ],
          ),
        ),
      ),
    );
  }

  Color _roleColor(BuildContext context) {
    switch (user.role) {
      case 'Official': return Colors.purple;
      case 'Teacher': return Colors.blue;
      case 'Leader': return Colors.orange;
      case 'Student': return Colors.teal;
      default: return Colors.grey;
    }
  }
}
