import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:open_filex/open_filex.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'notification_service.dart';

class UpdateService {
  static const String _githubApiUrl =
      "https://api.github.com/repos/shelad3/Kabete-Poly/releases/latest";

  static const String _fileName = 'kabete_poly_update.apk';

  static Future<void> checkForUpdates(BuildContext context,
      {bool showNoUpdateMsg = false}) async {
    try {
      final packageInfo = await PackageInfo.fromPlatform();
      final currentVersion = packageInfo.version;

      final response = await http.get(Uri.parse(_githubApiUrl)).timeout(const Duration(seconds: 15));

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
    bool downloadComplete = false;
    bool installing = false;
    double progress = 0;
    String installStatus = 'Opening package installer...';

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return PopScope(
              canPop: !downloading,
              child: AlertDialog(
                title: Row(
                  children: [
                    Icon(
                      installing
                          ? Icons.download_done
                          : downloadComplete
                              ? Icons.check_circle
                              : Icons.system_update_alt,
                      color: installing || downloadComplete
                          ? Colors.green
                          : Colors.blue,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      installing
                          ? 'Installing...'
                          : downloadComplete
                              ? 'Download Complete'
                              : 'Update Available!',
                    ),
                  ],
                ),
                content: installing
                    ? Text(installStatus)
                    : downloadComplete
                        ? const Text(
                            'The update file has been downloaded. '
                            'The installer will open to complete the installation.')
                        : downloading
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
                                        style: const TextStyle(
                                            fontWeight: FontWeight.bold)),
                                    if (releaseNotes.isNotEmpty) ...[
                                      const SizedBox(height: 12),
                                      const Text('What\'s new:',
                                          style: TextStyle(
                                              fontWeight: FontWeight.w600)),
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
                  if (installing)
                    const SizedBox.shrink()
                  else if (downloadComplete)
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green,
                          foregroundColor: Colors.white),
                      onPressed: () {
                        Navigator.of(dialogContext).pop();
                      },
                      child: const Text('Close'),
                    )
                  else ...[
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
                                if (filePath != null) {
                                  setDialogState(() {
                                    downloading = false;
                                    downloadComplete = true;
                                  });
                                  setDialogState(() {
                                    installing = true;
                                    downloadComplete = false;
                                  });
                                  await _installApk(filePath, (s) {
                                    setDialogState(() => installStatus = s);
                                  });
                                  setDialogState(() {
                                    installing = false;
                                    downloadComplete = true;
                                  });
                                }
                              } catch (e) {
                                if (context.mounted) {
                                  setDialogState(() {
                                    downloading = false;
                                    downloadComplete = false;
                                    installing = false;
                                  });
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text(
                                          'Download failed: ${e.toString().replaceAll("Exception: ", "")}'),
                                      backgroundColor: Colors.red,
                                    ),
                                  );
                                }
                              }
                            },
                      child: Text(downloading ? 'Downloading...' : 'Update Now'),
                    ),
                  ],
                ],
              ),
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
      final response = await client.send(request).timeout(const Duration(minutes: 5));

      final contentLength = response.contentLength;
      final dir = Directory.systemTemp;
      final file = File('${dir.path}/$_fileName');

      if (file.existsSync()) {
        await file.delete();
      }

      final sink = file.openWrite();
      int bytesDownloaded = 0;
      int lastNotifiedProgress = -1;

      await for (final chunk in response.stream) {
        sink.add(chunk);
        bytesDownloaded += chunk.length;
        if (contentLength != null && contentLength > 0) {
          final pct = bytesDownloaded / contentLength;
          onProgress(pct);

          // Update notification every 5%
          final pctInt = (pct * 100).toInt();
          if (pctInt - lastNotifiedProgress >= 5 || pctInt == 100) {
            lastNotifiedProgress = pctInt;
            NotificationService().showDownloadProgressNotification(
              id: 9999,
              progress: pctInt,
            );
          }
        }
      }

      await sink.close();
      return file.path;
    } finally {
      client.close();
    }
  }

  static Future<void> _installApk(String filePath, void Function(String) onStatus) async {
    onStatus('Opening package installer...');
    // Cancel progress notification
    await NotificationService().cancelDownloadNotification(ids: [9999]);
    // Show completion notification for retry if installer fails
    await NotificationService().showDownloadCompleteNotification(filePath);

    final result = await OpenFilex.open(filePath);
    if (result.type != ResultType.done) {
      onStatus('Installer failed, tap notification to retry');
      debugPrint('OpenFilex failed: ${result.message}');
    }
  }
}
