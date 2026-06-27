import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../services/auth_code_service.dart';
import '../../services/auth_provider.dart';

class ManageAuthCodesScreen extends StatefulWidget {
  const ManageAuthCodesScreen({super.key});

  @override
  State<ManageAuthCodesScreen> createState() => _ManageAuthCodesScreenState();
}

class _ManageAuthCodesScreenState extends State<ManageAuthCodesScreen> {
  final AuthCodeService _service = AuthCodeService();
  bool _isGenerating = false;
  AuthCodeRule _selectedRule = AuthCodeRule.predefined[0];

  Future<void> _generateCode(String role) async {
    setState(() => _isGenerating = true);
    final user = context.read<AuthProvider>().currentUser;
    await _service.generateCode(role, user?.email ?? 'admin', rule: _selectedRule);
    if (mounted) {
      setState(() => _isGenerating = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$role code generated (${_selectedRule.label})')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Authentication Codes'),
      ),
      body: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            color: theme.colorScheme.primary.withValues(alpha: 0.05),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Generate Registration Codes',
                    style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                DropdownButtonFormField<AuthCodeRule>(
                  value: _selectedRule,
                  decoration: InputDecoration(
                    labelText: 'Code Rule',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  ),
                  items: AuthCodeRule.predefined.map((r) {
                    final desc = StringBuffer();
                    if (r.maxUses != null) desc.write('${r.maxUses} use${r.maxUses! > 1 ? 's' : ''}');
                    if (r.expiresAfter != null) {
                      if (desc.isNotEmpty) desc.write(', ');
                      if (r.expiresAfter == Duration.zero) {
                        desc.write('immediate expiry');
                      } else if (r.expiresAfter!.inHours >= 24) desc.write('${r.expiresAfter!.inDays} days');
                      else desc.write('${r.expiresAfter!.inHours} hours');
                    }
                    return DropdownMenuItem(
                      value: r,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(r.label, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                          if (desc.isNotEmpty)
                            Text(desc.toString(), style: TextStyle(fontSize: 11, color: Colors.grey[600])),
                        ],
                      ),
                    );
                  }).toList(),
                  onChanged: (val) {
                    if (val != null) setState(() => _selectedRule = val);
                  },
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    _buildGenerateButton('Leader', Colors.purple),
                    const SizedBox(width: 12),
                    _buildGenerateButton('Teacher', Colors.orange),
                    const SizedBox(width: 12),
                    _buildGenerateButton('Official', Colors.red),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                Text('Generated Codes',
                    style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold)),
                const Spacer(),
                Text('Tap to revoke', style: TextStyle(fontSize: 12, color: Colors.grey[500])),
              ],
            ),
          ),
          const SizedBox(height: 4),
          Expanded(
            child: StreamBuilder<List<AuthCode>>(
              stream: _service.getCodesStream(),
              builder: (context, snap) {
                if (snap.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snap.hasError) {
                  return Center(child: Text('Error loading codes: ${snap.error}'));
                }
                final codes = snap.data ?? [];
                if (codes.isEmpty) {
                  return const Center(child: Text('No codes generated yet'));
                }
                return ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: codes.length,
                  itemBuilder: (context, index) {
                    final code = codes[index];
                    final rule = AuthCodeRule.predefined.where((r) => r.id == code.ruleId).firstOrNull;
                    return Card(
                      margin: const EdgeInsets.only(bottom: 8),
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor: _roleColor(code.role).withValues(alpha: 0.1),
                          child: Icon(Icons.vpn_key, color: _roleColor(code.role), size: 20),
                        ),
                        title: Text(code.code,
                            style: const TextStyle(fontWeight: FontWeight.bold, letterSpacing: 2)),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '${code.role} · ${code.isUsed ? "Used by ${code.usedBy ?? 'unknown'}" : (code.isExpired ? "Expired" : code.isExhausted ? "Exhausted" : "Available")}',
                              style: TextStyle(
                                fontSize: 12,
                                color: code.isUsed || code.isExpired || code.isExhausted ? Colors.grey : Colors.green,
                              ),
                            ),
                            if (rule != null)
                              Text(
                                rule.label,
                                style: TextStyle(fontSize: 11, color: Colors.grey[500]),
                              ),
                            if (code.useCount > 0 || code.maxUses != null)
                              Text(
                                'Used ${code.useCount}x${code.maxUses != null ? ' / ${code.maxUses}x max' : ''}',
                                style: TextStyle(fontSize: 11, color: Colors.grey[500]),
                              ),
                          ],
                        ),
                        trailing: IconButton(
                          icon: const Icon(Icons.delete_outline, color: Colors.red),
                          onPressed: () => _confirmRevoke(code.id),
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGenerateButton(String role, Color color) {
    return Expanded(
      child: ElevatedButton(
        onPressed: _isGenerating ? null : () => _generateCode(role),
        style: ElevatedButton.styleFrom(
          backgroundColor: color,
          foregroundColor: Colors.white,
          minimumSize: const Size(0, 44),
        ),
        child: _isGenerating
            ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
            : Text(role, style: const TextStyle(fontSize: 13)),
      ),
    );
  }

  Color _roleColor(String role) {
    switch (role) {
      case 'Leader':
        return Colors.purple;
      case 'Teacher':
        return Colors.orange;
      case 'Official':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  void _confirmRevoke(String codeId) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Revoke Code'),
        content: const Text('This will permanently delete this code. Continue?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () {
              _service.revokeCode(codeId);
              Navigator.pop(ctx);
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
            child: const Text('Revoke'),
          ),
        ],
      ),
    );
  }
}
