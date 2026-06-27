import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:open_filex/open_filex.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'notification_service.dart';

class UpdateService {
  static const String _githubApiUrl =
      'https://api.github.com/repos/shelad3/Kabete-Poly/releases/latest';

  static const String _fileName = 'kabete_poly_update.apk';

  static String get _filePath => '${Directory.systemTemp.path}/$_fileName';

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

          final prefs = await SharedPreferences.getInstance();
          await prefs.setBool('update_available', true);
          await prefs.setString('pending_update_version', latestVersionTag);
          await prefs.setString('pending_update_notes', releaseNotes);

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
        debugPrint('Failed to fetch updates. Status Code: ${response.statusCode}');
        if (showNoUpdateMsg && context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
                content: Text('Unable to connect to GitHub Update Servers.'),
                backgroundColor: Colors.red),
          );
        }
      }
    } catch (e) {
      debugPrint('Error checking for updates: $e');
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

  static Future<bool> hasPendingUpdate() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool('update_available') ?? false;
  }

  static Future<Map<String, String>?> getPendingUpdateInfo() async {
    final prefs = await SharedPreferences.getInstance();
    final available = prefs.getBool('update_available') ?? false;
    if (!available) return null;
    return {
      'version': prefs.getString('pending_update_version') ?? '',
      'notes': prefs.getString('pending_update_notes') ?? '',
    };
  }

  static Future<void> clearPendingUpdate() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('update_available');
    await prefs.remove('pending_update_version');
    await prefs.remove('pending_update_notes');
  }

  static String _formatBytes(int bytes) {
    if (bytes < 1024 * 1024) {
      return '${(bytes / 1024).toStringAsFixed(0)} KB';
    }
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  /// Returns the expected content length from the download URL via a HEAD request,
  /// or null if it cannot be determined.
  static Future<int?> _fetchExpectedSize(String url) async {
    try {
      final head = await http.head(Uri.parse(url)).timeout(const Duration(seconds: 10));
      final len = head.headers['content-length'];
      if (len != null) return int.tryParse(len);
    } catch (_) {}
    return null;
  }

  /// Checks whether the file at [filePath] was fully downloaded by comparing
  /// its size on disk against the expected content-length from a HEAD request.
  /// Returns `true` if the file doesn't exist (no download attempted yet),
  /// so callers should check existence first.
  static Future<bool> _isFileComplete(String url, String filePath) async {
    final file = File(filePath);
    if (!file.existsSync()) return false;
    final actual = file.lengthSync();
    final expected = await _fetchExpectedSize(url);
    if (expected == null) {
      // can't verify — assume it's OK
      return true;
    }
    return actual >= expected;
  }

  static void _showUpdateDialog(
      BuildContext context, String newVersion, String url, String releaseNotes) {
    bool downloading = false;
    bool downloadComplete = false;
    bool installing = false;
    double progress = 0;
    int downloadedBytes = 0;
    int totalBytes = 0;
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
                            'Tap "Install Now" to open the package installer.')
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
                                  if (totalBytes > 0) ...[
                                    const SizedBox(height: 4),
                                    Text(
                                      '${_formatBytes(downloadedBytes)} / ${_formatBytes(totalBytes)}',
                                      style: TextStyle(
                                        color: Colors.grey[600],
                                        fontSize: 13,
                                      ),
                                    ),
                                  ],
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
                  else if (downloadComplete) ...[
                    TextButton(
                      onPressed: () {
                        setDialogState(() => installing = true);
                        _installAndFinish(
                          setDialogState,
                          _filePath,
                          (s) {
                            installStatus = s;
                            setDialogState(() {});
                          },
                          () {
                            setDialogState(() {
                              installing = false;
                              downloadComplete = true;
                            });
                          },
                        );
                      },
                      child: const Text('Later',
                          style: TextStyle(color: Colors.grey)),
                    ),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green,
                          foregroundColor: Colors.white),
                      onPressed: () {
                        setDialogState(() => installing = true);
                        _installAndFinish(
                          setDialogState,
                          _filePath,
                          (s) {
                            installStatus = s;
                            setDialogState(() {});
                          },
                          () {
                            setDialogState(() {
                              installing = false;
                              downloadComplete = true;
                            });
                          },
                        );
                      },
                      child: const Text('Install Now'),
                    ),
                  ]
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
                              // Check if APK already exists and is fully downloaded
                              final existing = File(_filePath);
                              if (existing.existsSync()) {
                                final complete = await _isFileComplete(url, _filePath);
                                if (complete) {
                                  setDialogState(() => downloadComplete = true);
                                  _showPersistentNotification();
                                  return;
                                }
                                // Partial file — delete and re-download
                                await existing.delete();
                              }

                              setDialogState(() {
                                downloading = true;
                                progress = 0;
                                downloadedBytes = 0;
                                totalBytes = 0;
                              });

                              try {
                                final result = await _downloadApk(url, (pct, downloaded, total) {
                                  setDialogState(() {
                                    progress = pct;
                                    downloadedBytes = downloaded;
                                    totalBytes = total;
                                  });
                                });

                                if (result != null) {
                                  final (path, contentLength) = result;
                                  setDialogState(() {
                                    downloading = false;
                                    downloadComplete = true;
                                    totalBytes = contentLength;
                                    downloadedBytes = contentLength;
                                  });
                                  _showPersistentNotification();
                                }
                              } catch (e) {
                                if (context.mounted) {
                                  setDialogState(() {
                                    downloading = false;
                                    downloadComplete = false;
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
                      child: const Text('Update Now'),
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

  static void _installAndFinish(
    StateSetter setDialogState,
    String filePath,
    void Function(String) onStatus,
    VoidCallback onDone,
  ) async {
    try {
      await _installApk(filePath, onStatus);
      onDone();
    } catch (e) {
      onStatus('Installation failed: $e');
      onDone();
    }
  }

  static void _showPersistentNotification() {
    NotificationService().showDownloadCompleteNotification(_filePath);
  }

  /// Downloads the APK, returning the file path and the total content length.
  /// [onProgress] receives (fraction, bytesDownloaded, totalBytes).
  static Future<(String, int)?> _downloadApk(
    String url,
    void Function(double progress, int downloaded, int total) onProgress,
  ) async {
    final file = File(_filePath);
    if (file.existsSync()) {
      return (file.path, file.lengthSync());
    }

    final client = http.Client();
    try {
      final request = http.Request('GET', Uri.parse(url));
      final response = await client.send(request).timeout(const Duration(minutes: 5));

      final contentLength = response.contentLength ?? 0;

      final sink = file.openWrite();
      int bytesDownloaded = 0;
      int lastNotifiedProgress = -1;

      await for (final chunk in response.stream) {
        sink.add(chunk);
        bytesDownloaded += chunk.length;
        if (contentLength > 0) {
          final pct = bytesDownloaded / contentLength;
          onProgress(pct, bytesDownloaded, contentLength);

          final pctInt = (pct * 100).toInt();
          if (pctInt - lastNotifiedProgress >= 5 || pctInt == 100) {
            lastNotifiedProgress = pctInt;
            NotificationService().showDownloadProgressNotification(
              id: 9999,
              progress: pctInt,
            );
          }
        } else {
          onProgress(0, bytesDownloaded, contentLength);
        }
      }

      await sink.close();
      return (file.path, contentLength);
    } finally {
      client.close();
    }
  }

  static Future<void> _installApk(String filePath, void Function(String) onStatus) async {
    onStatus('Opening package installer...');
    await NotificationService().cancelDownloadNotification(ids: [9999]);
    await NotificationService().showDownloadCompleteNotification(filePath);

    final result = await OpenFilex.open(filePath);
    if (result.type != ResultType.done) {
      onStatus('Installer failed — tap notification to retry');
      debugPrint('OpenFilex failed: ${result.message}');
    }
  }
}
