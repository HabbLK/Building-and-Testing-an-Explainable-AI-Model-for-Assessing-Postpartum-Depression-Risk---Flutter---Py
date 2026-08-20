import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../services/local_store.dart';
import '../theme/app_theme.dart';
import '../widgets/illustrations.dart';

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});

  @override
  State<HistoryScreen> createState() => HistoryScreenState();
}

class HistoryScreenState extends State<HistoryScreen> {
  List<ServerAssessment> _history = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> refresh() => _load();

  Future<void> _load() async {
    setState(() => _error = null);
    final token = await LocalStore.getToken();
    if (token == null) {
      setState(() {
        _loading = false;
        _error = 'Not signed in';
      });
      return;
    }
    try {
      final h = await ApiService.getAssessments(token);
      if (!mounted) return;
      setState(() {
        _history = h;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = 'Could not load history: $e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Your History')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(child: Padding(padding: const EdgeInsets.all(24), child: Text(_error!)))
              : _history.isEmpty
                  ? _emptyState(context)
                  : RefreshIndicator(
                  onRefresh: _load,
                  child: ListView(
                    padding: const EdgeInsets.all(20),
                    children: [
                      if (_history.length > 1) _chart(context),
                      if (_history.length > 1) const SizedBox(height: 24),
                      Text('Past check-ins', style: Theme.of(context).textTheme.titleLarge),
                      const SizedBox(height: 12),
                      ..._history.map(_recordTile),
                    ],
                  ),
                ),
    );
  }

  Widget _emptyState(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AppIllustration.calendarSparkle(size: 180),
            const SizedBox(height: 16),
            Text('No check-ins yet', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 8),
            Text(
              'Complete a wellbeing check-in and your results will show up here over time.',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ],
        ),
      ),
    );
  }

  Widget _chart(BuildContext context) {
    final chronological = _history.reversed.toList();
    final spots = <FlSpot>[
      for (var i = 0; i < chronological.length; i++) FlSpot(i.toDouble(), chronological[i].riskProbability),
    ];

    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 20, 20, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(left: 8),
              child: Text('Risk trend', style: Theme.of(context).textTheme.titleMedium),
            ),
            const SizedBox(height: 12),
            SizedBox(
              height: 160,
              child: LineChart(
                LineChartData(
                  minY: 0,
                  maxY: 1,
                  gridData: const FlGridData(show: false),
                  borderData: FlBorderData(show: false),
                  titlesData: const FlTitlesData(
                    topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    bottomTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    leftTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  ),
                  lineBarsData: [
                    LineChartBarData(
                      spots: spots,
                      isCurved: true,
                      color: AppColors.primary,
                      barWidth: 3,
                      dotData: const FlDotData(show: true),
                      belowBarData: BarAreaData(show: true, color: AppColors.primary.withValues(alpha: 0.12)),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _recordTile(ServerAssessment r) {
    final color = AppColors.bandColor(r.riskBand);
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: ExpansionTile(
        shape: const RoundedRectangleBorder(side: BorderSide.none),
        leading: CircleAvatar(
          backgroundColor: color.withValues(alpha: 0.15),
          child: Text('${(r.riskProbability * 100).round()}', style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.bold)),
        ),
        title: Text(r.riskBand, style: TextStyle(color: color, fontWeight: FontWeight.w700)),
        subtitle: Text(_formatDate(r.timestamp)),
        children: [
          ...r.topFactors.map((f) => ListTile(
                dense: true,
                leading: Icon(
                  f.direction == 'increases' ? Icons.arrow_upward_rounded : Icons.arrow_downward_rounded,
                  color: f.direction == 'increases' ? AppColors.danger : AppColors.success,
                  size: 18,
                ),
                title: Text(f.factor),
              )),
          if (r.note.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.06),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.edit_note_rounded, size: 16, color: AppColors.primary),
                    const SizedBox(width: 8),
                    Expanded(child: Text(r.note, style: const TextStyle(fontStyle: FontStyle.italic, fontSize: 13))),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  String _formatDate(DateTime dt) {
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    final h = dt.hour.toString().padLeft(2, '0');
    final m = dt.minute.toString().padLeft(2, '0');
    return '${dt.day} ${months[dt.month - 1]} ${dt.year} · $h:$m';
  }
}
