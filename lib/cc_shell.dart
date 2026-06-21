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
  final List<CircleModel> allCircles;
  final Function(String) onSwitchCircle;

  const Shell({
    super.key,
    required this.circle,
    required this.onToggleElder,
    required this.allCircles,
    required this.onSwitchCircle,
  });

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
      MonitorTab(
        circle: widget.circle,
        allCircles: widget.allCircles,
        onSwitchCircle: widget.onSwitchCircle,
      ),
      ProfileTab(onToggleElder: widget.onToggleElder),
    ];


    return Scaffold(
      extendBody: true,
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
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
          child: Container(
            height: e ? 84 : 74,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(40),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.08),
                  blurRadius: 20,
                  spreadRadius: 2,
                  offset: const Offset(0, 4),
                )
              ],
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _navItem(0, Icons.home_rounded, Icons.home_outlined, 'HOME', e),
                _navItem(1, Icons.favorite_rounded, Icons.favorite_outline_rounded, 'CHECK-IN', e),
                _navItem(2, Icons.medication_rounded, Icons.medication_outlined, 'MEDS', e),
                _navItem(3, Icons.people_rounded, Icons.people_outline_rounded, 'CIRCLE', e),
                _navItem(4, Icons.person_rounded, Icons.person_outline_rounded, 'PROFILE', e),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _navItem(int index, IconData on, IconData off, String label, bool e) {
    final isSelected = _i == index;
    return GestureDetector(
      onTap: () {
        _pageController.animateToPage(
          index,
          duration: const Duration(milliseconds: 400),
          curve: Curves.easeInOutCubic,
        );
      },
      behavior: HitTestBehavior.opaque,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: EdgeInsets.all(e ? 10 : 8),
            decoration: BoxDecoration(
              color: isSelected ? C.primary.withValues(alpha: 0.15) : Colors.transparent,
              shape: BoxShape.circle,
            ),
            child: Icon(
              isSelected ? on : off,
              color: isSelected ? C.primary : Colors.blueGrey.shade300,
              size: e ? 28 : 24,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: e ? 11 : 9,
              fontWeight: FontWeight.w900,
              color: isSelected ? C.primary : Colors.blueGrey.shade300,
              letterSpacing: 0.5,
            ),
          ),
        ],
      ),
    );
  }
}