import 'package:flutter/material.dart';
import 'package:tutorial_coach_mark/tutorial_coach_mark.dart';
import 'package:shared_preferences/shared_preferences.dart';

class TutorialService {
  late TutorialCoachMark tutorialCoachMark;

  // Global Keys for targeting specific UI elements
  static final GlobalKey omniFabKey = GlobalKey();
  static final GlobalKey scheduleTabKey = GlobalKey();
  static final GlobalKey notificationIconKey = GlobalKey();
  static final GlobalKey settingsKey = GlobalKey(); // For the drawer

  static const String _firstLaunchKey = 'has_seen_tutorial_v1';

  /// Initializes and displays the tutorial overlay.
  /// If it has already been seen (via SharedPreferences), this quietly returns.
  Future<void> showTutorialIfFirstLaunch(BuildContext context, {required bool canAddContent}) async {
    final prefs = await SharedPreferences.getInstance();
    final bool hasSeen = prefs.getBool(_firstLaunchKey) ?? false;

    if (!hasSeen) {
      // Delay slightly to ensure UI is fully rendered before capturing keys
      Future.delayed(const Duration(milliseconds: 500), () {
        if (context.mounted) {
          _initTutorial(context, canAddContent: canAddContent);
          tutorialCoachMark.show(context: context);
          prefs.setBool(_firstLaunchKey, true); // Mark as completely seen
        }
      });
    }
  }

  /// Forces the tutorial to show (e.g. for a "Help" button in settings)
  void forceShowTutorial(BuildContext context, {required bool canAddContent}) {
    _initTutorial(context, canAddContent: canAddContent);
    tutorialCoachMark.show(context: context);
  }

  void _initTutorial(BuildContext context, {required bool canAddContent}) {
    tutorialCoachMark = TutorialCoachMark(
      targets: _createTargets(canAddContent: canAddContent),
      colorShadow: Colors.blueGrey,
      textSkip: "SKIP",
      paddingFocus: 10,
      opacityShadow: 0.8,
      onFinish: () {
         debugPrint("Tutorial Finished");
      },
      onClickTarget: (target) {
         debugPrint('Clicked target logic: $target');
      },
      onSkip: () {
         debugPrint("Tutorial Skipped");
         return true;
      },
    );
  }

  List<TargetFocus> _createTargets({required bool canAddContent}) {
    List<TargetFocus> targets = [];

    // 1. Omni FAB Target (Only if they have permission to see the FAB)
    if (canAddContent) {
      targets.add(
        TargetFocus(
          identify: "OmniFab",
          keyTarget: omniFabKey,
          alignSkip: Alignment.topRight,
          contents: [
            TargetContent(
              align: ContentAlign.top,
              builder: (context, controller) {
                return Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: const [
                    Text(
                      "Upload Content Here",
                      style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                          fontSize: 24),
                    ),
                    SizedBox(height: 10),
                    Text(
                      "Tap this button to post announcements, schedules, or directly attach PDF documents to the cloud.",
                      style: TextStyle(color: Colors.white, fontSize: 16),
                    ),
                  ],
                );
              },
            ),
          ],
        ),
      );
    }

    // 2. Schedule Tab Target
    targets.add(
      TargetFocus(
        identify: "ScheduleTab",
        keyTarget: scheduleTabKey,
        alignSkip: Alignment.topRight,
        shape: ShapeLightFocus.RRect,
        contents: [
          TargetContent(
            align: ContentAlign.bottom,
            builder: (context, controller) {
              return Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: const [
                  Text(
                    "View Timetables",
                    style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                        fontSize: 24),
                  ),
                  SizedBox(height: 10),
                  Text(
                    "Check your official Mandatory department schedule or view live daily adjustments here.",
                    style: TextStyle(color: Colors.white, fontSize: 16),
                  ),
                ],
              );
            },
          ),
        ],
      ),
    );

     // 3. Notification Logic
    targets.add(
      TargetFocus(
        identify: "Notifications",
        keyTarget: notificationIconKey,
        alignSkip: Alignment.bottomLeft,
        contents: [
          TargetContent(
            align: ContentAlign.bottom,
            builder: (context, controller) {
              return Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: const [
                  Text(
                    "Stay Updated",
                    style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                        fontSize: 24),
                  ),
                  SizedBox(height: 10),
                  Text(
                    "All class alerts and urgent department broadcasts will appear here.",
                    style: TextStyle(color: Colors.white, fontSize: 16),
                  ),
                ],
              );
            },
          ),
        ],
      ),
    );

    return targets;
  }
}
