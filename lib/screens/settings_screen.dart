import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:io';
import '../services/auth_provider.dart';
import '../services/firestore_service.dart';
import '../services/storage_service.dart';
import '../widgets/app_drawer.dart';
import '../theme/theme_provider.dart';
import 'faculty_directory_screen.dart';
import 'help_screen.dart';
import 'error_report_screen.dart';
import 'feedback_screen.dart';
import '../services/update_service.dart';
import '../services/class_provider.dart';
import '../utils/timetable_data.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  String _appVersion = '';
  final _picker = ImagePicker();
  final _storageService = StorageService();

  @override
  void initState() {
    super.initState();
    _loadVersion();
  }

  Future<void> _loadVersion() async {
    final info = await PackageInfo.fromPlatform();
    if (mounted) {
      setState(() => _appVersion = '${info.version}+${info.buildNumber}');
    }
  }

  Future<void> _pickAndUploadPhoto() async {
    final file = await _picker.pickImage(source: ImageSource.gallery, maxWidth: 512, maxHeight: 512);
    if (file == null) return;
    try {
      final authProvider = context.read<AuthProvider>();
      final user = authProvider.currentUser;
      if (user == null) return;
      final regNo = user.registrationNumber;
      final path = 'profiles/img_${regNo}_${DateTime.now().millisecondsSinceEpoch}.jpg';
      final uploadedUrl = await _storageService.uploadImage(File(file.path), path);
      if (uploadedUrl != null) {
        final uid = authProvider.currentUserId;
        await FirestoreService().updateUserProfile(uid, {'profilePhotoUrl': uploadedUrl});
        await authProvider.refreshUserProfile();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Profile photo updated!'), backgroundColor: Colors.green),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Upload failed: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _clearCache() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Clear Cache?'),
        content: const Text('This will remove temporary files and cached images. Your data will not be affected.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.orange, foregroundColor: Colors.white),
            child: const Text('Clear'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      final cacheDir = Directory.systemTemp;
      int count = 0;
      if (cacheDir.existsSync()) {
        for (final f in cacheDir.listSync()) {
          if (f is File) {
            await f.delete();
            count++;
          }
        }
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Cleared $count temporary files'), backgroundColor: Colors.green),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Cache clear error: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthProvider>().currentUser;
    final themeNotifier = context.watch<ThemeNotifier>();

    return Scaffold(
      drawer: const AppDrawer(),
      appBar: AppBar(
        title: const Text('Profile & Settings', style: TextStyle(fontWeight: FontWeight.bold)),
        elevation: 0,
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            const SizedBox(height: 16),
            _buildIDCard(context, user),
            const SizedBox(height: 24),
            _buildSettingsSection(context, 'Account Details', [
              _buildSettingItem(context, Icons.email_outlined, 'Email', user?.email ?? '-'),
              _buildSettingItem(context, Icons.phone_android_outlined, 'Mobile', user?.mobileNumber ?? '-'),
              _buildSettingItem(context, Icons.admin_panel_settings_outlined, 'Role', user?.role ?? 'User'),
              if (user?.role == 'Student' || user?.role == 'Leader')
                _buildSettingItem(context, Icons.house_outlined, 'Hostel', user?.isHostelResident == true ? 'Resident' : 'Day Scholar'),
              ListTile(
                leading: const Icon(Icons.class_, color: Colors.grey),
                title: const Text('Enrolled Classes', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w500)),
                trailing: Text(
                  '${user?.enrolledClasses.length ?? 0} classes',
                  style: const TextStyle(color: Colors.grey, fontSize: 14),
                ),
                onTap: () => _showClassManagement(context, user),
              ),
            ]),
            _buildSettingsSection(context, 'Appearance', [
              ListTile(
                leading: const Icon(Icons.palette_outlined, color: Colors.purple),
                title: const Text('Theme', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w500)),
                trailing: SegmentedButton<AppThemeMode>(
                  segments: const [
                    ButtonSegment(value: AppThemeMode.knp, icon: Icon(Icons.palette, size: 18), label: Text('KNP', style: TextStyle(fontSize: 12))),
                    ButtonSegment(value: AppThemeMode.light, icon: Icon(Icons.light_mode, size: 18), label: Text('Light', style: TextStyle(fontSize: 12))),
                    ButtonSegment(value: AppThemeMode.dark, icon: Icon(Icons.dark_mode, size: 18), label: Text('Dark', style: TextStyle(fontSize: 12))),
                  ],
                  selected: {themeNotifier.mode},
                  onSelectionChanged: (s) => themeNotifier.setMode(s.first),
                ),
              ),
            ]),
            _buildSettingsSection(context, 'App Preferences', [
              ListTile(
                leading: Icon(Icons.edit_outlined, color: Colors.teal),
                title: const Text('Edit Profile', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w500)),
                trailing: const Icon(Icons.chevron_right, size: 18, color: Colors.grey),
                onTap: () => _showEditProfile(context, user),
              ),
              ListTile(
                leading: Icon(Icons.lock_reset, color: Theme.of(context).primaryColor),
                title: const Text('Change Password', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w500)),
                trailing: const Icon(Icons.chevron_right, size: 18, color: Colors.grey),
                onTap: () => _showPasswordResetDialog(context, user?.email),
              ),
              ListTile(
                leading: const Icon(Icons.notifications_outlined, color: Colors.cyan),
                title: const Text('Notification Preferences', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w500)),
                trailing: const Icon(Icons.chevron_right, size: 18, color: Colors.grey),
                onTap: () => _showNotificationPrefs(context),
              ),
              ListTile(
                leading: const Icon(Icons.delete_sweep_outlined, color: Colors.orange),
                title: const Text('Clear Cache', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w500)),
                trailing: const Icon(Icons.chevron_right, size: 18, color: Colors.grey),
                onTap: _clearCache,
              ),
              ListTile(
                leading: const Icon(Icons.support_agent_outlined, color: Colors.indigo),
                title: const Text('Help & Support', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w500)),
                trailing: const Icon(Icons.chevron_right, size: 18, color: Colors.grey),
                onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const HelpScreen())),
              ),
              ListTile(
                leading: const Icon(Icons.bug_report_outlined, color: Colors.redAccent),
                title: const Text('Report an Error', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w500)),
                trailing: const Icon(Icons.chevron_right, size: 18, color: Colors.grey),
                onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ErrorReportScreen())),
              ),
              ListTile(
                leading: const Icon(Icons.feedback_outlined, color: Colors.amber),
                title: const Text('Send Feedback', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w500)),
                trailing: const Icon(Icons.chevron_right, size: 18, color: Colors.grey),
                onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const FeedbackScreen())),
              ),
              ListTile(
                leading: Icon(Icons.system_update_alt, color: Colors.blueAccent),
                title: const Text('Check for Updates', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w500)),
                trailing: const Icon(Icons.refresh, size: 18, color: Colors.blueAccent),
                onTap: () {
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Checking latest release...')));
                  UpdateService.checkForUpdates(context, showNoUpdateMsg: true);
                },
              ),
            ]),
            const SizedBox(height: 24),
            _buildSettingsSection(context, 'Institution', [
              ListTile(
                leading: const Icon(Icons.contact_phone_outlined, color: Colors.grey),
                title: const Text('Faculty & Staff Directory', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w500)),
                trailing: const Icon(Icons.chevron_right, size: 18, color: Colors.grey),
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const FacultyDirectoryScreen()),
                  );
                },
              ),
              ListTile(
                leading: const Icon(Icons.info_outline, color: Colors.grey),
                title: const Text('About Kabete Poly App', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w500)),
                trailing: Text(_appVersion, style: const TextStyle(color: Colors.grey, fontSize: 13)),
                onTap: () => _showAboutDialog(context),
              ),
            ]),
            const SizedBox(height: 32),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: OutlinedButton(
                onPressed: () => context.read<AuthProvider>().logout(),
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size(double.infinity, 56),
                  backgroundColor: Colors.red.withValues(alpha: 0.05),
                  foregroundColor: Colors.redAccent,
                  side: const BorderSide(color: Colors.redAccent, width: 2),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                ),
                child: const Text('Secure Logout', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, letterSpacing: 1)),
              ),
            ),
            const SizedBox(height: 48),
          ],
        ),
      ),
    );
  }

  void _showClassManagement(BuildContext context, user) {
    if (user == null) return;
    final canChange = user.canChangeClass;
    final remaining = user.classChangesRemaining;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDState) => AlertDialog(
          title: Row(
            children: [
              const Icon(Icons.class_, size: 20),
              const SizedBox(width: 8),
              Text(canChange ? 'Manage Classes' : 'Class Enrollment'),
            ],
          ),
          content: SizedBox(
            width: double.maxFinite,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Current Classes:', style: TextStyle(fontWeight: FontWeight.w600)),
                const SizedBox(height: 8),
                if (user.enrolledClasses.isEmpty)
                  const Padding(
                    padding: EdgeInsets.only(left: 16),
                    child: Text('No classes enrolled.', style: TextStyle(color: Colors.grey)),
                  )
                else
                  ...user.enrolledClasses.map<Widget>((c) => Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 16),
                    child: Row(children: [
                      const Icon(Icons.check_circle, size: 16, color: Colors.green),
                      const SizedBox(width: 8),
                      Text(c),
                    ]),
                  )),
                const SizedBox(height: 16),
                if (canChange) ...[
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.blue.withValues(alpha: 0.05),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.blue.withValues(alpha: 0.2)),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.refresh, size: 16, color: Colors.blue[700]),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'You can change your class $remaining more time(s).',
                            style: TextStyle(fontSize: 13, color: Colors.blue[800]),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: () {
                        Navigator.pop(ctx);
                        _showClassSelector(context, user);
                      },
                      icon: const Icon(Icons.swap_horiz, size: 18),
                      label: const Text('Change Class'),
                    ),
                  ),
                ] else ...[
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.orange.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.orange.withValues(alpha: 0.3)),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(Icons.warning_amber, size: 16, color: Colors.orange[700]),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Class change limit reached.',
                                style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: Colors.orange[800]),
                              ),
                              const SizedBox(height: 4),
                              const Text(
                                'Submit a help request to request a class change.',
                                style: TextStyle(fontSize: 12, color: Colors.grey),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: () {
                        Navigator.pop(ctx);
                        _showClassChangeRequest(context, user);
                      },
                      icon: const Icon(Icons.help_outline, size: 18),
                      label: const Text('Request Class Change via Help'),
                    ),
                  ),
                ],
              ],
            ),
          ),
          actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Close'))],
        ),
      ),
    );
  }

  void _showClassSelector(BuildContext context, user) {
    final classes = context.read<ClassProvider>().availableClasses
        .where((c) => c != 'Global / General Assembly')
        .toList();
    String? selected;
    TextEditingController customCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDState) => AlertDialog(
          title: const Text('Select New Class'),
          content: SizedBox(
            width: double.maxFinite,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('Choose your new class:', style: TextStyle(fontSize: 14, color: Colors.grey)),
                const SizedBox(height: 12),
                ConstrainedBox(
                  constraints: const BoxConstraints(maxHeight: 300),
                  child: Scrollbar(
                    child: ListView(
                      shrinkWrap: true,
                      children: [
                        ...classes.map((c) => RadioListTile<String>(
                          title: Text(c, style: const TextStyle(fontSize: 13)),
                          value: c,
                          groupValue: selected,
                          onChanged: (v) {
                            setDState(() {
                              selected = v;
                              customCtrl.clear();
                            });
                          },
                          dense: true,
                        )),
                      ],
                    ),
                  ),
                ),
                const Divider(),
                TextField(
                  controller: customCtrl,
                  decoration: const InputDecoration(labelText: 'Or type a class name', border: OutlineInputBorder()),
                  onChanged: (v) {
                    if (v.isNotEmpty) setDState(() => selected = null);
                  },
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
            ElevatedButton(
              onPressed: () async {
                final newClass = selected ?? customCtrl.text.trim();
                if (newClass.isEmpty) return;
                try {
                  final uid = context.read<AuthProvider>().currentUserId;
                  final firestore = FirestoreService();
                  await firestore.updateUserProfile(uid, {
                    'enrolledClasses': [newClass],
                    'classChangeCount': (user.classChangeCount ?? 0) + 1,
                  });
                  await context.read<AuthProvider>().refreshUserProfile();
                  if (ctx.mounted) Navigator.pop(ctx);
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Class changed to $newClass'), backgroundColor: Colors.green),
                    );
                  }
                } catch (e) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Failed: $e'), backgroundColor: Colors.red),
                    );
                  }
                }
              },
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );
  }

  void _showClassChangeRequest(BuildContext context, user) {
    final titleCtrl = TextEditingController();
    final messageCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Request Class Change'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'You have used all your free class changes. Submit a request and an admin will assist you.',
                style: TextStyle(color: Colors.grey[600], fontSize: 13),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: titleCtrl,
                decoration: const InputDecoration(labelText: 'Desired Class', border: OutlineInputBorder()),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: messageCtrl,
                maxLines: 3,
                decoration: const InputDecoration(labelText: 'Reason (optional)', border: OutlineInputBorder()),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () async {
              final cls = titleCtrl.text.trim();
              if (cls.isEmpty) return;
              try {
                final auth = context.read<AuthProvider>();
                await FirestoreService().submitClassChangeRequest(
                  auth.currentUserId,
                  user?.fullName ?? '',
                  user?.email ?? '',
                  cls,
                  messageCtrl.text.trim(),
                );
                if (ctx.mounted) Navigator.pop(ctx);
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Request submitted. Admin will review it.'), backgroundColor: Colors.green),
                  );
                }
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Failed: $e'), backgroundColor: Colors.red),
                  );
                }
              }
            },
            child: const Text('Submit Request'),
          ),
        ],
      ),
    );
  }

  void _showEditProfile(BuildContext context, dynamic user) {
    if (user == null) return;
    final nameCtrl = TextEditingController(text: user.fullName);
    final phoneCtrl = TextEditingController(text: user.mobileNumber);
    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDState) => AlertDialog(
          title: const Text('Edit Profile'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                GestureDetector(
                  onTap: () => _pickAndUploadPhoto(),
                  child: CircleAvatar(
                    radius: 48,
                    backgroundColor: Colors.grey[200],
                    backgroundImage: user.profilePhotoUrl.isNotEmpty
                        ? NetworkImage(user.profilePhotoUrl)
                        : null,
                    child: user.profilePhotoUrl.isEmpty
                        ? const Icon(Icons.camera_alt, size: 32, color: Colors.grey)
                        : null,
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: nameCtrl,
                  decoration: const InputDecoration(labelText: 'Full Name', border: OutlineInputBorder()),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: phoneCtrl,
                  decoration: const InputDecoration(labelText: 'Mobile Number', border: OutlineInputBorder()),
                  keyboardType: TextInputType.phone,
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
            ElevatedButton(
              onPressed: () async {
                if (nameCtrl.text.trim().isEmpty) return;
                try {
                  final uid = context.read<AuthProvider>().currentUserId;
                  final firestore = FirestoreService();
                  await firestore.updateUserProfile(uid, {
                    'fullName': nameCtrl.text.trim(),
                    'mobileNumber': phoneCtrl.text.trim(),
                  });
                  if (ctx.mounted) {
                    Navigator.pop(ctx);
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Profile updated'), backgroundColor: Colors.green),
                    );
                  }
                } catch (e) {
                  if (ctx.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Update failed: $e'), backgroundColor: Colors.red),
                    );
                  }
                }
              },
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );
  }

  void _showNotificationPrefs(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDState) {
          final prefs = SharedPreferences.getInstance();
          return FutureBuilder<SharedPreferences>(
            future: prefs,
            builder: (context, snap) {
              if (snap.hasError) {
                return AlertDialog(content: Text('Error: ${snap.error}'));
              }
              final sp = snap.data;
              if (sp == null) {
                return const AlertDialog(content: CircularProgressIndicator());
              }
              bool lessonsOn = sp.getBool('notif_lessons') ?? true;
              bool scheduleOn = sp.getBool('notif_schedule') ?? true;
              bool forumOn = sp.getBool('notif_forum') ?? true;
              bool announcementsOn = sp.getBool('notif_announcements') ?? true;
              return AlertDialog(
                title: const Text('Notification Preferences'),
                content: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Manage what notifications you receive:', style: TextStyle(fontSize: 14, color: Colors.grey)),
                    const SizedBox(height: 16),
                    SwitchListTile(
                      title: const Text('New Lessons'),
                      subtitle: const Text('When a teacher posts new material'),
                      value: lessonsOn,
                      onChanged: (v) {
                        sp.setBool('notif_lessons', v);
                        setDState(() {});
                      },
                      dense: true,
                    ),
                    SwitchListTile(
                      title: const Text('Schedule Reminders'),
                      subtitle: const Text('30 min before class starts'),
                      value: scheduleOn,
                      onChanged: (v) {
                        sp.setBool('notif_schedule', v);
                        setDState(() {});
                      },
                      dense: true,
                    ),
                    SwitchListTile(
                      title: const Text('Forum Messages'),
                      subtitle: const Text('New posts in your channels'),
                      value: forumOn,
                      onChanged: (v) {
                        sp.setBool('notif_forum', v);
                        setDState(() {});
                      },
                      dense: true,
                    ),
                    SwitchListTile(
                      title: const Text('Announcements'),
                      subtitle: const Text('Important class announcements'),
                      value: announcementsOn,
                      onChanged: (v) {
                        sp.setBool('notif_announcements', v);
                        setDState(() {});
                      },
                      dense: true,
                    ),
                  ],
                ),
                actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Done'))],
              );
            },
          );
        },
      ),
    );
  }

  Widget _buildIDCard(BuildContext context, user) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: Theme.of(context).primaryColor,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(color: Theme.of(context).primaryColor.withValues(alpha: 0.3), blurRadius: 15, offset: const Offset(0, 8)),
        ],
      ),
      child: Stack(
        children: [
          Positioned(
            right: -20,
            top: -20,
            child: Icon(Icons.school, size: 150, color: Colors.white.withValues(alpha: 0.1)),
          ),
          Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    GestureDetector(
                      onTap: _pickAndUploadPhoto,
                      child: Container(
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 3),
                        ),
                        child: CircleAvatar(
                          radius: 40,
                          backgroundColor: Colors.white24,
                          backgroundImage: user?.profilePhotoUrl.isNotEmpty == true 
                            ? NetworkImage(user!.profilePhotoUrl) 
                            : null,
                          child: user?.profilePhotoUrl.isEmpty == true 
                            ? const Icon(Icons.person, size: 40, color: Colors.white) 
                            : null,
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const SizedBox(height: 8),
                          Text(
                            user?.fullName ?? 'Student Name',
                            style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.white),
                          ),
                          const SizedBox(height: 4),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.2),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              user?.registrationNumber ?? 'EE-XXXX-XXX',
                              style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold, letterSpacing: 1),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    _buildIDStat('ROLE', user?.role ?? 'Student'),
                    if (user?.role != 'Student' && user?.designation != null)
                      _buildIDStat('DESIGNATION', user!.designation!),
                    _buildIDStat('STATUS', 'Active', color: Colors.greenAccent),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildIDStat(String label, String value, {Color color = Colors.white}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: TextStyle(color: Colors.white.withValues(alpha: 0.6), fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 1)),
        const SizedBox(height: 4),
        Text(value, style: TextStyle(color: color, fontSize: 14, fontWeight: FontWeight.bold)),
      ],
    );
  }

  Widget _buildSettingsSection(BuildContext context, String title, List<Widget> items) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
          child: Text(
            title.toUpperCase(),
            style: TextStyle(
              color: Theme.of(context).primaryColor,
              fontWeight: FontWeight.bold,
              fontSize: 12,
              letterSpacing: 1.5,
            ),
          ),
        ),
        Container(
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: Theme.of(context).cardColor,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.03),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
            border: Border.all(color: Colors.grey.withValues(alpha: 0.1)),
          ),
          child: Column(children: items),
        ),
      ],
    );
  }

  Widget _buildSettingItem(BuildContext context, IconData icon, String label, String value) {
    return ListTile(
      leading: Icon(icon, color: Colors.grey[700]),
      title: Text(label, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500)),
      trailing: Text(value, style: const TextStyle(color: Colors.grey, fontSize: 14)),
    );
  }

  void _showPasswordResetDialog(BuildContext context, String? email) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Change Password'),
          content: Text('A password reset link will be sent to:\n$email'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                Navigator.of(context).pop();
                try {
                  await context.read<AuthProvider>().sendPasswordResetEmail(email!);
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Password reset email sent. Check your inbox.')));
                  }
                } catch (e) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
                  }
                }
              },
              child: const Text('Send Reset Link'),
            ),
          ],
        );
      },
    );
  }

  void _showAboutDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.info, color: Colors.blue),
            SizedBox(width: 10),
            Text('About Kabete Poly'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Version: $_appVersion', style: const TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 10),
            const Text('Kabete Poly App provides students and faculty with scheduling, document sharing, and real-time alerts.'),
            const SizedBox(height: 10),
            const Text('Built with Flutter & Firebase.', style: TextStyle(fontStyle: FontStyle.italic, fontSize: 12, color: Colors.grey)),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Close'))
        ],
      ),
    );
  }
}
