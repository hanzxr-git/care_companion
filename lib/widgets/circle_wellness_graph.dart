import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import '../models/checkin_model.dart';
import '../models/user_model.dart';
import '../cc_theme.dart';

class CircleWellnessGraph extends StatelessWidget {
  final List<CheckinModel> checkins;
  final List<UserModel> members;

  const CircleWellnessGraph({
    super.key,
    required this.checkins,
    required this.members,
  });

  @override
  Widget build(BuildContext context) {
    if (members.isEmpty) return const SizedBox();

    final now = DateTime.now();
    
    // Assign a fixed color to each member based on their index
    final List<Color> memberColors = [
      C.primary,
      C.green,
      C.orange,
      C.fire,
      const Color(0xFF2D9CDB),
      C.red,
      const Color(0xFF9B51E0),
    ];

    // Group checkins by user
    final Map<String, List<CheckinModel>> userCheckins = {};
    for (var m in members) {
      userCheckins[m.uid] = [];
    }

    for (var c in checkins) {
      if (c.timestamp.month != now.month || c.timestamp.year != now.year) continue;
      if (userCheckins.containsKey(c.uid)) {
        userCheckins[c.uid]!.add(c);
      }
    }

    // Prepare line chart data
    final List<LineChartBarData> lineBars = [];
    int totalCheckins = 0;
    int totalScore = 0;

    for (int i = 0; i < members.length; i++) {
      final user = members[i];
      final uCheckins = userCheckins[user.uid] ?? [];
      final color = memberColors[i % memberColors.length];

      // Keep only the first checkin per day
      final Map<int, CheckinModel> dailyCheckins = {};
      for (var c in uCheckins) {
        if (!dailyCheckins.containsKey(c.timestamp.day)) {
          dailyCheckins[c.timestamp.day] = c;
        }
      }

      final List<FlSpot> spots = [];
      
      // We'll plot up to the current day
      for (int day = 1; day <= now.day; day++) {
        bool isTodayAndSos = (day == now.day && user.sosActive);
        if (dailyCheckins.containsKey(day) || isTodayAndSos) {
          // Map mood to score: SOS = 0, not okay = 1, okay = 2
          double score = 2; // Default to okay
          if (isTodayAndSos) {
            score = 0;
          } else {
            final c = dailyCheckins[day]!;
            if (c.mood == 'SOS') {
              score = 0;
            } else if (c.note != null && c.note!.isNotEmpty) {
              score = 1; // Assuming note means "not okay" in this simplified mapping
            }
          }

          // Add a tiny Y offset based on member index so lines don't completely overlap
          double yOffset = (i * 0.04);
          if (score == 2) yOffset = -yOffset; // offset downwards if at the top
          
          spots.add(FlSpot(day.toDouble(), score + yOffset));
          totalCheckins++;
          totalScore += score.toInt();
        }
      }

      if (spots.isNotEmpty) {
        lineBars.add(
          LineChartBarData(
            spots: spots,
            isCurved: true,
            color: color,
            barWidth: 3,
            isStrokeCapRound: true,
            dotData: const FlDotData(show: true),
            belowBarData: BarAreaData(show: false),
          ),
        );
      }
    }

    // Algorithmic Analysis
    String analysis = "No check-ins have been recorded this month.";
    if (totalCheckins > 0) {
      final avgScore = totalScore / totalCheckins;
      
      if (avgScore >= 1.7) {
        analysis = "The circle is doing exceptionally well this month! Wellness scores are consistently high across members.";
      } else if (avgScore >= 1.0) {
        analysis = "Overall wellness is stable, but there have been a few days where members felt 'not okay'. Keep supporting each other.";
      } else {
        analysis = "The circle has experienced several difficult days recently, including SOS alerts. Please check in on members who might need extra support.";
      }
      
      // Add participation context
      final participationRate = (totalCheckins / (members.length * now.day)) * 100;
      if (participationRate < 30) {
        analysis += " Note: Check-in participation is quite low (${participationRate.toInt()}%). Encourage members to check in daily!";
      } else if (participationRate > 80) {
        analysis += " Your circle has excellent check-in consistency (${participationRate.toInt()}%).";
      }
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const CapLabel('CIRCLE WELLNESS TRENDS'),
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
                child: lineBars.isEmpty
                    ? const Center(child: Text("No data yet.", style: TextStyle(color: C.textMid)))
                    : LineChart(
                        LineChartData(
                          lineTouchData: const LineTouchData(enabled: false),
                          gridData: FlGridData(
                            show: true,
                            drawVerticalLine: false,
                            horizontalInterval: 1,
                            getDrawingHorizontalLine: (value) => const FlLine(
                              color: C.divider,
                              strokeWidth: 1,
                            ),
                          ),
                          titlesData: FlTitlesData(
                            show: true,
                            bottomTitles: AxisTitles(
                              sideTitles: SideTitles(
                                showTitles: true,
                                getTitlesWidget: (value, meta) {
                                  // Show day numbers (every 5 days)
                                  if (value % 5 != 0 && value != 1 && value != now.day) {
                                    return const SizedBox.shrink();
                                  }
                                  return Padding(
                                    padding: const EdgeInsets.only(top: 8.0),
                                    child: Text(
                                      '${value.toInt()}',
                                      style: const TextStyle(
                                        color: C.textMid,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 10,
                                      ),
                                    ),
                                  );
                                },
                              ),
                            ),
                            leftTitles: AxisTitles(
                              sideTitles: SideTitles(
                                showTitles: true,
                                interval: 1,
                                reservedSize: 40,
                                getTitlesWidget: (value, meta) {
                                  String text = '';
                                  if (value == 0) {
                                    text = 'SOS';
                                  } else if (value == 1) {
                                    text = 'Not OK';
                                  } else if (value == 2) {
                                    text = 'Okay';
                                  }
                                  
                                  return Center(
                                    child: Text(
                                      text,
                                      style: const TextStyle(
                                        color: C.textMid,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 10,
                                      ),
                                    ),
                                  );
                                },
                              ),
                            ),
                            rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                            topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                          ),
                          borderData: FlBorderData(show: false),
                          minX: 1,
                          maxX: now.day.toDouble(),
                          minY: 0,
                          maxY: 2,
                          lineBarsData: lineBars,
                        ),
                      ),
              ),
              const SizedBox(height: 24),
              
              // Legend
              Wrap(
                spacing: 12,
                runSpacing: 8,
                children: List.generate(members.length, (i) {
                  return _buildLegend(memberColors[i % memberColors.length], members[i].username);
                }),
              ),
              
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 16),
                child: Divider(color: C.divider, height: 1),
              ),
              
              // Analysis Text
              const Text(
                'Wellness Analysis',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w900,
                  color: C.textDark,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                analysis,
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

  Widget _buildLegend(Color color, String label) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 6),
        Flexible(
          child: Text(
            label,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: C.textMid,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}
