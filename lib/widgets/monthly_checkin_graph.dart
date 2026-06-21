import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import '../models/checkin_model.dart';
import '../cc_theme.dart';

class MonthlyCheckinGraph extends StatelessWidget {
  final List<CheckinModel> checkins;

  const MonthlyCheckinGraph({super.key, required this.checkins});

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final daysInMonth = DateUtils.getDaysInMonth(now.year, now.month);
    
    // Calculate weeks
    // Week 1: 1-7, Week 2: 8-14, Week 3: 15-21, Week 4: 22-28, Week 5: 29+
    final Map<int, Map<String, int>> weekData = {
      1: {'okay': 0, 'not_okay': 0, 'missed': 7},
      2: {'okay': 0, 'not_okay': 0, 'missed': 7},
      3: {'okay': 0, 'not_okay': 0, 'missed': 7},
      4: {'okay': 0, 'not_okay': 0, 'missed': 7},
      5: {'okay': 0, 'not_okay': 0, 'missed': daysInMonth - 28},
    };

    // Keep track of which days have checkins to calculate missed accurately
    final Set<int> daysCheckedIn = {};

    int totalOkay = 0;
    int totalNotOkay = 0;

    for (var c in checkins) {
      if (c.timestamp.month != now.month || c.timestamp.year != now.year) continue;
      
      final day = c.timestamp.day;
      
      // We only care about the first check-in of the day if there are multiples.
      if (daysCheckedIn.contains(day)) continue;
      daysCheckedIn.add(day);

      final week = ((day - 1) ~/ 7) + 1;
      
      final isOkay = c.note == null || c.note!.isEmpty;
      if (isOkay) {
        weekData[week]!['okay'] = weekData[week]!['okay']! + 1;
        totalOkay++;
      } else {
        weekData[week]!['not_okay'] = weekData[week]!['not_okay']! + 1;
        totalNotOkay++;
      }
      weekData[week]!['missed'] = weekData[week]!['missed']! - 1;
    }

    final totalDaysPassed = now.day;
    final totalMissed = (totalDaysPassed - totalOkay - totalNotOkay).clamp(0, 31);

    // Conclusion text
    String conclusion = "You've been checking in regularly.";
    if (totalOkay > totalNotOkay && totalNotOkay == 0) {
      conclusion = "You've been feeling great this month with $totalOkay okay days! Keep up the good work.";
    } else if (totalNotOkay > totalOkay) {
      conclusion = "It looks like a tough month with $totalNotOkay not okay days. Remember your family is here to support you.";
    } else if (totalOkay > 0 || totalNotOkay > 0) {
      conclusion = "You've had $totalOkay okay days and $totalNotOkay not okay days this month. Thanks for keeping your circle updated!";
    } else if (totalOkay == 0 && totalNotOkay == 0) {
      conclusion = "You haven't checked in yet this month. Start tracking your daily wellness!";
    }
    
    if (totalMissed > 5) {
      conclusion += " However, you've missed $totalMissed check-ins up to today. Try to check in daily!";
    } else if (totalMissed > 0) {
      conclusion += " You've only missed $totalMissed days.";
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const CapLabel('MONTHLY OVERVIEW'),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(28),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.05),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Chart
              SizedBox(
                height: 200,
                child: BarChart(
                  BarChartData(
                    alignment: BarChartAlignment.spaceAround,
                    maxY: 7,
                    barTouchData: BarTouchData(enabled: false),
                    titlesData: FlTitlesData(
                      show: true,
                      bottomTitles: AxisTitles(
                        sideTitles: SideTitles(
                          showTitles: true,
                          getTitlesWidget: (value, meta) {
                            return Padding(
                              padding: const EdgeInsets.only(top: 8.0),
                              child: Text(
                                'W${value.toInt()}',
                                style: const TextStyle(
                                  color: C.textMid,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12,
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                      leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                      rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                      topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    ),
                    gridData: FlGridData(
                      show: true,
                      drawVerticalLine: false,
                      horizontalInterval: 1,
                      getDrawingHorizontalLine: (value) => const FlLine(
                        color: C.divider,
                        strokeWidth: 1,
                      ),
                    ),
                    borderData: FlBorderData(show: false),
                    barGroups: weekData.entries.map((e) {
                      final week = e.key;
                      final data = e.value;
                      final double ok = data['okay']!.toDouble();
                      final double notOk = data['not_okay']!.toDouble();
                      final double missed = data['missed']!.toDouble();
                      
                      return BarChartGroupData(
                        x: week,
                        barRods: [
                          BarChartRodData(
                            toY: ok + notOk + missed,
                            width: 24,
                            borderRadius: BorderRadius.circular(6),
                            rodStackItems: [
                              BarChartRodStackItem(0, ok, C.green),
                              BarChartRodStackItem(ok, ok + notOk, C.red),
                              BarChartRodStackItem(ok + notOk, ok + notOk + missed, C.bg),
                            ],
                          ),
                        ],
                      );
                    }).toList(),
                  ),
                ),
              ),
              const SizedBox(height: 24),
              
              // Legend
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _buildLegend(C.green, 'Okay'),
                  const SizedBox(width: 16),
                  _buildLegend(C.red, 'Not Okay'),
                  const SizedBox(width: 16),
                  _buildLegend(C.bg, 'Missed', border: true),
                ],
              ),
              
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 16),
                child: Divider(color: C.divider, height: 1),
              ),
              
              // Conclusion Text
              const Text(
                'Analysis',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w900,
                  color: C.textDark,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                conclusion,
                style: const TextStyle(
                  fontSize: 14,
                  color: C.textMid,
                  height: 1.5,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildLegend(Color color, String label, {bool border = false}) {
    return Row(
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
            border: border ? Border.all(color: C.textLight) : null,
          ),
        ),
        const SizedBox(width: 6),
        Text(
          label,
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: C.textMid,
          ),
        ),
      ],
    );
  }
}
