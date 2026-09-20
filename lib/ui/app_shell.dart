import 'package:flutter/material.dart';

import '../design/tokens.dart';
import 'calendar/calendar_screen.dart';
import 'settings/settings_screen.dart';
import 'stats/stats_screen.dart';
import 'table/table_screen.dart';

class AppShell extends StatefulWidget {
  const AppShell({super.key});

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  int _tab = 0;

  static const _labels = ['Table', 'Stats', 'Days', 'Rules'];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColor.feltLo,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            Expanded(
              child: IndexedStack(
                index: _tab,
                children: const [
                  TableScreen(),
                  StatsScreen(),
                  CalendarScreen(),
                  RulesScreen(),
                ],
              ),
            ),
            _NavBar(
              index: _tab,
              labels: _labels,
              onChanged: (i) => setState(() => _tab = i),
            ),
          ],
        ),
      ),
    );
  }
}

/// Type-only navigation, set in the same tracked caps the table is printed in.
class _NavBar extends StatelessWidget {
  const _NavBar({required this.index, required this.labels, required this.onChanged});

  final int index;
  final List<String> labels;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    final inset = MediaQuery.paddingOf(context).bottom;

    return Container(
      decoration: const BoxDecoration(
        color: AppColor.rail,
        border: Border(top: BorderSide(color: AppColor.line)),
      ),
      padding: EdgeInsets.only(bottom: inset),
      child: SizedBox(
        height: 54,
        child: Row(
          children: [
            for (var i = 0; i < labels.length; i++)
              Expanded(
                child: Semantics(
                  button: true,
                  selected: i == index,
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () => onChanged(i),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        AnimatedContainer(
                          duration: const Duration(milliseconds: 180),
                          width: i == index ? 18 : 0,
                          height: 2,
                          color: AppColor.amber,
                        ),
                        const SizedBox(height: 9),
                        AnimatedDefaultTextStyle(
                          duration: const Duration(milliseconds: 180),
                          style: AppText.eyebrow(
                            10.5,
                            color: i == index ? AppColor.bone : AppColor.slate,
                            weight: i == index ? 600 : 500,
                          ),
                          child: Text(labels[i].toUpperCase()),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
