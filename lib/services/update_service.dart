import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:open_filex/open_filex.dart';
import 'package:package_info_plus/package_info_plus.dart';

class UpdateService {
  static const String _githubApiUrl =
      "https://api.github.com/repos/shelad3/Kabete-Poly/releases/latest";

  static Future<void> checkForUpdates(BuildContext context,
      {bool showNoUpdateMsg = false}) async {
    try {
      final packageInfo = await PackageInfo.fromPlatform();
      final currentVersion = packageInfo.version;

      final response = await http.get(Uri.parse(_githubApiUrl));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        String latestVersionTag = data['tag_name'];

        if (latestVersionTag.startsWith('v') || latestVersionTag.startsWith('V')) {
          latestVersionTag = latestVersionTag.substring(1);
        }

        if (_isUpdateAvailable(currentVersion, latestVersionTag)) {
          String? downloadUrl;
          if (data['assets'] != null && data['assets'].isNotEmpty) {
            downloadUrl = data['assets'][0]['browser_download_url'];
          }
          downloadUrl ??= data['html_url'];

          final releaseNotes = data['body'] ?? '';

          if (context.mounted) {
            _showUpdateDialog(context, latestVersionTag, downloadUrl!, releaseNotes);
          }
        } else if (showNoUpdateMsg && context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
                content: Text('You are already on the latest version!'),
                backgroundColor: Colors.green),
          );
        }
      } else {
        debugPrint("Failed to fetch updates. Status Code: ${response.statusCode}");
        if (showNoUpdateMsg && context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
                content: Text('Unable to connect to GitHub Update Servers.'),
                backgroundColor: Colors.red),
          );
        }
      }
    } catch (e) {
      debugPrint("Error checking for updates: $e");
      if (showNoUpdateMsg && context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('Check your internet connection.'),
              backgroundColor: Colors.red),
        );
      }
    }
  }

  static bool _isUpdateAvailable(String currentVersion, String latestVersion) {
    try {
      List<int> currentParts =
          currentVersion.split('.').map(int.parse).toList();
      List<int> latestParts =
          latestVersion.split('.').map(int.parse).toList();

      for (int i = 0;
          i < currentParts.length && i < latestParts.length;
          i++) {
        if (latestParts[i] > currentParts[i]) return true;
        if (latestParts[i] < currentParts[i]) return false;
      }

      return latestParts.length > currentParts.length;
    } catch (e) {
      return latestVersion.compareTo(currentVersion) > 0;
    }
  }

  static void _showUpdateDialog(
      BuildContext context, String newVersion, String url, String releaseNotes) {
    bool downloading = false;
    double progress = 0;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: Row(
                children: const [
                  Icon(Icons.system_update_alt, color: Colors.blue),
                  SizedBox(width: 8),
                  Text('Update Available!'),
                ],
              ),
              content: downloading
                  ? Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Text('Downloading update...'),
                        const SizedBox(height: 16),
                        LinearProgressIndicator(
                            value: progress > 0 ? progress : null),
                        const SizedBox(height: 8),
                        Text('${(progress * 100).toStringAsFixed(0)}%'),
                      ],
                    )
                  : SingleChildScrollView(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Version $newVersion is now available.',
                              style:
                                  const TextStyle(fontWeight: FontWeight.bold)),
                          if (releaseNotes.isNotEmpty) ...[
                            const SizedBox(height: 12),
                            const Text('What\'s new:',
                                style: TextStyle(fontWeight: FontWeight.w600)),
                            const SizedBox(height: 4),
                            Text(releaseNotes),
                          ],
                          const SizedBox(height: 12),
                          const Text(
                              'Please update to get the latest features and fixes.'),
                        ],
                      ),
                    ),
              actions: [
                TextButton(
                  onPressed: downloading
                      ? null
                      : () => Navigator.of(dialogContext).pop(),
                  child: const Text('Later',
                      style: TextStyle(color: Colors.grey)),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue,
                      foregroundColor: Colors.white),
                  onPressed: downloading
                      ? null
                      : () async {
                          setDialogState(() => downloading = true);
                          try {
                            final filePath =
                                await _downloadApk(url, (p) {
                              setDialogState(() => progress = p);
                            });
                            if (filePath != null && context.mounted) {
                              Navigator.of(dialogContext).pop();
                              await _installApk(filePath);
                            }
                          } catch (e) {
                            if (context.mounted) {
                              setDialogState(() => downloading = false);
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text('Download failed: $e'),
                                  backgroundColor: Colors.red,
                                ),
                              );
                            }
                          }
                        },
                  child: Text(downloading ? 'Downloading...' : 'Update Now'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  static Future<String?> _downloadApk(
      String url, void Function(double progress) onProgress) async {
    final client = http.Client();
    try {
      final request = http.Request('GET', Uri.parse(url));
      final response = await client.send(request);

      final contentLength = response.contentLength;
      final dir = Directory.systemTemp;
      final fileName = 'kabete_poly_update.apk';
      final file = File('${dir.path}/$fileName');

      if (file.existsSync()) {
        await file.delete();
      }

      final sink = file.openWrite();
      int bytesDownloaded = 0;

      await for (final chunk in response.stream) {
        sink.add(chunk);
        bytesDownloaded += chunk.length;
        if (contentLength != null && contentLength > 0) {
          onProgress(bytesDownloaded / contentLength);
        }
      }

      await sink.close();
      return file.path;
    } finally {
      client.close();
    }
  }

  static Future<void> _installApk(String filePath) async {
    final result = await OpenFilex.open(filePath);
    if (result.type != ResultType.done) {
      throw Exception('Installation failed: ${result.message}');
    }
  }
}
