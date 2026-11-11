import 'package:flutter/material.dart';

import '../core/app_side.dart';
import 'core/emp_settings_controller.dart';
import 'core/error_boundary.dart';
import 'features/auth/controllers/emp_session.dart';
import 'features/home/screens/home_page.dart';

/// The way into the employee screens, from either door:
///
///   * a worker's own login — AuthGate shows this as the whole app;
///   * an office login linked to an employee record — "My work" pushes
///     this over the office screens, with [staffView] set.
///
/// It reads who the employee is (EmpSession.load), and for "My work"
/// tells AppSide the employee side is open while it is, so the app is
/// drawn in the employee screens' light theme and back again after.
class EmployeeArea extends StatefulWidget {
  final bool staffView;
  const EmployeeArea({super.key, this.staffView = false});

  @override
  State<EmployeeArea> createState() => _EmployeeAreaState();
}

class _EmployeeAreaState extends State<EmployeeArea> {
  @override
  void initState() {
    super.initState();
    EmpSession.find.load();
    // After this frame: both change what the root draws, and the root
    // cannot be told to rebuild while it is building.
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (widget.staffView) {
        AppSide.to.enterFromStaff();
      } else {
        // A worker's screens in the language they picked last time.
        AppSide.setLanguage(await EmpSettingsController.find.restore());
      }
    });
  }

  @override
  void dispose() {
    if (widget.staffView) {
      // Not during dispose itself: the tree is locked then.
      WidgetsBinding.instance
          .addPostFrameCallback((_) => AppSide.to.leaveFromStaff());
      // A frame is not always coming (nothing else may change); ask for
      // one so the callback above runs.
      WidgetsBinding.instance.scheduleFrame();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => ErrorBoundary(
        label: 'employee home',
        child: HomePage(staffView: widget.staffView),
      );
}
