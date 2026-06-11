// cc_shell.dart — Firebase version with auth-aware profile
import 'package:flutter/material.dart';
import 'cc_theme.dart';
import 'cc_home.dart';
import 'cc_checkin.dart';
import 'cc_meds.dart';
import 'cc_monitor.dart';
import 'cc_profile.dart';

import 'models/circle_model.dart';

class Shell extends StatefulWidget {
  final CircleModel circle;
  final Function(bool) onToggleElder;
  const Shell({super.key, required this.circle, required this.onToggleElder});
  @override
  State<Shell> createState() => _ShellState();
}

class _ShellState extends State<Shell> {
  late final PageController _pageController;
  int _i = 0;

  @override
  void initState() {
    super.initState();
    _pageController = PageController(initialPage: _i);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final e = context.elder;
    final pages = [
      HomeTab(
        circle: widget.circle,
        onNavigateToTab: (index) {
          _pageController.animateToPage(
            index,
            duration: const Duration(milliseconds: 400),
            curve: Curves.easeInOutCubic,
          );
        },
      ),
      CheckinTab(circle: widget.circle),
      MedsTab(circle: widget.circle),
      MonitorTab(circle: widget.circle),
      ProfileTab(onToggleElder: widget.onToggleElder),
    ];

    return Scaffold(
      body: PageView(
        controller: _pageController,
        physics: const NeverScrollableScrollPhysics(),
        onPageChanged: (index) {
          setState(() {
            _i = index;
          });
        },
        children: pages,
      ),
      bottomNavigationBar: Container(
        decoration: const BoxDecoration(
          color: C.surface,
          border: Border(top: BorderSide(color: C.divider))),
        child: NavigationBar(
          selectedIndex: _i,
          onDestinationSelected: (i) {
            _pageController.animateToPage(
              i,
              duration: const Duration(milliseconds: 400),
              curve: Curves.easeInOutCubic,
            );
          },
          backgroundColor: C.surface,
          elevation: 0,
          height: e ? 72 : 64,
          destinations: [
            _d(Icons.home_outlined, Icons.home_rounded, 'HOME', e),
            _d(Icons.favorite_outline_rounded, Icons.favorite_rounded, 'CHECK-IN', e),
            _d(Icons.medication_outlined, Icons.medication_rounded, 'MEDS', e),
            _d(Icons.people_outline_rounded, Icons.people_rounded, 'MONITOR', e),
            _d(Icons.person_outline_rounded, Icons.person_rounded, 'PROFILE', e),
          ],
        ),
      ),
    );
  }

  NavigationDestination _d(IconData off, IconData on, String label, bool e) =>
    NavigationDestination(
      icon: Icon(off, size: e ? 26 : 22),
      selectedIcon: Icon(on, size: e ? 26 : 22),
      label: label);
}