import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../theme/app_theme.dart';
import '../widgets/illustrations.dart';

/// Anonymized, aggregated statistics computed across every user's check-ins
/// via a MongoDB aggregation pipeline (see GET /insights). No individual
/// user's data is identifiable here.
class InsightsScreen extends StatefulWidget {
  const InsightsScreen({super.key});

  @override
  State<InsightsScreen> createState() => _InsightsScreenState();
}

class _InsightsScreenState extends State<InsightsScreen> {
  late Future<CommunityInsights> _future;

  @override
  void initState() {
    super.initState();
    _future = ApiService.getInsights();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Community Insights')),
      body: FutureBuilder<CommunityInsights>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text('Could not load community insights.\n${snapshot.error}', textAlign: TextAlign.center),
              ),
            );
          }

          final data = snapshot.data!;
          if (data.totalCheckins == 0) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    AppIllustration.insight(size: 180),
                    const SizedBox(height: 16),
                    Text('No community data yet', style: Theme.of(context).textTheme.titleLarge),
                    const SizedBox(height: 8),
                    Text(
                      'Once people start completing check-ins, anonymized trends will appear here.',
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ],
                ),
              ),
            );
          }

          return ListView(
            padding: const EdgeInsets.all(20),
            children: [
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Row(
                    children: [
                      AppIllustration.insight(size: 80),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('${data.totalCheckins} check-ins so far',
                                style: Theme.of(context).textTheme.titleMedium),
                            const SizedBox(height: 6),
                            Text(
                              'Aggregated and anonymized across everyone using MotherWell — '
                              'no individual result is identifiable here.',
                              style: Theme.of(context).textTheme.bodyMedium,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),
              Text('Risk band distribution', style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 12),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    children: [
                      SizedBox(
                        height: 180,
                        child: PieChart(
                          PieChartData(
                            sectionsSpace: 3,
                            centerSpaceRadius: 40,
                            sections: data.bandDistribution.entries.map((e) {
                              final color = AppColors.bandColor(e.key);
                              return PieChartSectionData(
                                value: e.value,
                                color: color,
                                title: '${e.value.toStringAsFixed(0)}%',
                                radius: 54,
                                titleStyle: const TextStyle(
                                    color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
                              );
                            }).toList(),
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      Wrap(
                        spacing: 16,
                        runSpacing: 8,
                        alignment: WrapAlignment.center,
                        children: data.bandDistribution.keys.map((band) {
                          return Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(
                                width: 10,
                                height: 10,
                                decoration: BoxDecoration(
                                    color: AppColors.bandColor(band), shape: BoxShape.circle),
                              ),
                              const SizedBox(width: 6),
                              Text(band, style: Theme.of(context).textTheme.bodyMedium),
                            ],
                          );
                        }).toList(),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),
              Text('Most common contributing factors', style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 6),
              Text(
                'Across all check-ins, these factors most often shifted someone\'s estimate.',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const SizedBox(height: 12),
              ..._buildFactorBars(context, data),
            ],
          );
        },
      ),
    );
  }

  List<Widget> _buildFactorBars(BuildContext context, CommunityInsights data) {
    if (data.topFactors.isEmpty) return [];
    final maxCount = data.topFactors.map((f) => f.count).reduce((a, b) => a > b ? a : b);
    return data.topFactors.map((f) {
      final up = f.direction == 'increases';
      final fraction = f.count / maxCount;
      return Card(
        margin: const EdgeInsets.only(bottom: 10),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    up ? Icons.arrow_upward_rounded : Icons.arrow_downward_rounded,
                    size: 16,
                    color: up ? AppColors.danger : AppColors.success,
                  ),
                  const SizedBox(width: 6),
                  Expanded(child: Text(f.factor, style: Theme.of(context).textTheme.titleMedium)),
                  Text('${f.count}×', style: Theme.of(context).textTheme.bodyMedium),
                ],
              ),
              const SizedBox(height: 8),
              ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: LinearProgressIndicator(
                  value: fraction,
                  minHeight: 6,
                  backgroundColor: Colors.grey.withValues(alpha: 0.15),
                  valueColor: AlwaysStoppedAnimation(up ? AppColors.danger : AppColors.success),
                ),
              ),
            ],
          ),
        ),
      );
    }).toList();
  }
}
