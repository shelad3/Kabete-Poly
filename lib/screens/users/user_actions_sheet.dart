import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../models/user_profile.dart';

class UserActionsSheet extends StatelessWidget {
  final UserProfile user;

  const UserActionsSheet({super.key, required this.user});

  @override
  Widget build(BuildContext context) {
    final hasPhone = user.mobileNumber.isNotEmpty;
    final hasEmail = user.email.isNotEmpty;

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40, height: 4,
              decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(2)),
            ),
            const SizedBox(height: 20),
            CircleAvatar(
              radius: 36,
              backgroundColor: Theme.of(context).primaryColor.withValues(alpha: 0.1),
              backgroundImage: user.profilePhotoUrl.isNotEmpty ? NetworkImage(user.profilePhotoUrl) : null,
              child: user.profilePhotoUrl.isEmpty
                  ? Text(user.fullName[0].toUpperCase(), style: TextStyle(fontSize: 28, color: Theme.of(context).primaryColor))
                  : null,
            ),
            const SizedBox(height: 12),
            Text(user.fullName, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            const SizedBox(height: 4),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              decoration: BoxDecoration(
                color: _roleColor(context).withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(user.role, style: TextStyle(color: _roleColor(context), fontWeight: FontWeight.w600, fontSize: 13)),
            ),
            if (user.designation != null && user.designation!.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(user.designation!, style: TextStyle(color: Colors.grey[600], fontSize: 13)),
            ],
            const SizedBox(height: 4),
            Text(user.registrationNumber, style: TextStyle(color: Colors.grey[500], fontSize: 12)),
            const SizedBox(height: 24),
            if (hasPhone) ...[
              _ActionTile(
                icon: Icons.phone, label: user.mobileNumber, color: Colors.green,
                onTap: () => launchUrl(Uri.parse('tel:${user.mobileNumber}')),
                onLongPress: () {
                  Clipboard.setData(ClipboardData(text: user.mobileNumber));
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Phone number copied')));
                },
              ),
              const SizedBox(height: 8),
              _ActionTile(
                icon: Icons.chat, label: 'WhatsApp', color: const Color(0xFF25D366),
                subtitle: user.mobileNumber,
                onTap: () => launchUrl(Uri.parse('https://wa.me/${user.mobileNumber.replaceAll(RegExp(r'[^0-9+]'), '')}')),
              ),
              const SizedBox(height: 8),
              _ActionTile(
                icon: Icons.sms, label: 'Send SMS', color: Colors.blue,
                subtitle: user.mobileNumber,
                onTap: () => launchUrl(Uri.parse('sms:${user.mobileNumber}')),
              ),
              const SizedBox(height: 8),
              _ActionTile(
                icon: Icons.copy, label: 'Copy Phone Number', color: Colors.grey[700]!,
                onTap: () {
                  Clipboard.setData(ClipboardData(text: user.mobileNumber));
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Phone number copied')));
                },
              ),
            ],
            if (!hasPhone) ...[
              Container(
                padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                decoration: BoxDecoration(
                  color: Colors.grey[100],
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    Icon(Icons.info_outline, color: Colors.grey[500], size: 20),
                    const SizedBox(width: 12),
                    Text('No phone number available', style: TextStyle(color: Colors.grey[600])),
                  ],
                ),
              ),
            ],
            if (hasEmail) ...[
              const SizedBox(height: 12),
              _ActionTile(
                icon: Icons.email, label: user.email, color: Colors.red,
                onTap: () => launchUrl(Uri.parse('mailto:${user.email}')),
                onLongPress: () {
                  Clipboard.setData(ClipboardData(text: user.email));
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Email copied')));
                },
              ),
            ],
          ],
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

class _ActionTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final String? subtitle;
  final Color color;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;

  const _ActionTile({
    required this.icon, required this.label, required this.color,
    this.subtitle, required this.onTap, this.onLongPress,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: color.withValues(alpha: 0.08),
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        onLongPress: onLongPress,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            children: [
              Icon(icon, color: color, size: 22),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(label, style: TextStyle(fontWeight: FontWeight.w500, color: color)),
                    if (subtitle != null) Text(subtitle!, style: TextStyle(fontSize: 12, color: Colors.grey[500])),
                  ],
                ),
              ),
              Icon(Icons.chevron_right, color: color.withValues(alpha: 0.5), size: 20),
            ],
          ),
        ),
      ),
    );
  }
}
