import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../services/local_store.dart';
import '../theme/app_theme.dart';
import '../utils/streak.dart';
import '../widgets/illustrations.dart';
import 'help_screen.dart';
import 'insights_screen.dart';

class HomeScreen extends StatefulWidget {
  final void Function(int) onNavigateToTab;
  const HomeScreen({super.key, required this.onNavigateToTab});

  @override
  State<HomeScreen> createState() => HomeScreenState();
}

class _Tip {
  final IconData icon;
  final Color color;
  final String text;
  const _Tip(this.icon, this.color, this.text);
}

class HomeScreenState extends State<HomeScreen> {
  static const _tips = [
    _Tip(Icons.bedtime_rounded, AppColors.primary,
        'Sleep when the baby sleeps where you can — even one longer stretch makes a difference.'),
    _Tip(Icons.groups_rounded, AppColors.accent,
        'A short, honest chat with someone you trust can ease a heavy day.'),
    _Tip(Icons.directions_walk_rounded, AppColors.secondary,
        'Ten minutes outside is linked with a real lift in mood and energy.'),
    _Tip(Icons.self_improvement_rounded, AppColors.success,
        'A few slow breaths before a feed can take the edge off anxiety in the moment.'),
    _Tip(Icons.restaurant_rounded, AppColors.warning,
        'Simple, regular meals matter more than "perfect" ones — accept the help if it\'s offered.'),
  ];

  String _name = '';
  List<ServerAssessment> _history = [];
  ServerAssessment? _latest;
  int _streak = 0;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    refresh();
  }

  Future<void> refresh() async {
    final user = await LocalStore.currentUser();
    final token = await LocalStore.getToken();
    List<ServerAssessment> history = [];
    if (token != null) {
      try {
        history = await ApiService.getAssessments(token);
      } catch (_) {
        // Keep whatever's on screen if the network call fails.
      }
    }
    if (!mounted) return;
    setState(() {
      _name = user?['name']?.split(' ').first ?? 'there';
      _history = history;
      _latest = history.isNotEmpty ? history.first : null;
      _streak = computeStreak(history);
      _loading = false;
    });
  }

  int get _checkinsThisMonth {
    final now = DateTime.now();
    return _history.where((r) => r.timestamp.year == now.year && r.timestamp.month == now.month).length;
  }

  _Tip get _todaysTip {
    final dayOfYear = DateTime.now().difference(DateTime(DateTime.now().year, 1, 1)).inDays;
    return _tips[dayOfYear % _tips.length];
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : RefreshIndicator(
                onRefresh: refresh,
                child: ListView(
                  padding: const EdgeInsets.all(20),
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text(
                            'Hi, $_name 👋',
                            style: Theme.of(context).textTheme.headlineMedium,
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.support_agent_rounded, color: AppColors.primary),
                          tooltip: 'Help & crisis support',
                          onPressed: () => Navigator.of(context)
                              .push(MaterialPageRoute(builder: (_) => const HelpScreen())),
                        ),
                      ],
                    ),
                    Text('How are you feeling today?', style: Theme.of(context).textTheme.bodyMedium),
                    const SizedBox(height: 18),
                    _statRow(context),
                    const SizedBox(height: 20),
                    _heroCard(context),
                    const SizedBox(height: 20),
                    _latestCard(context),
                    if (_history.length > 1) ...[
                      const SizedBox(height: 20),
                      _trendCard(context),
                    ],
                    const SizedBox(height: 24),
                    Text('Quick actions', style: Theme.of(context).textTheme.titleMedium),
                    const SizedBox(height: 12),
                    _quickActions(context),
                    const SizedBox(height: 24),
                    _tipCard(context),
                    const SizedBox(height: 16),
                    _resourceTeaser(context),
                  ],
                ),
              ),
      ),
    );
  }

  Widget _statRow(BuildContext context) {
    final stats = [
      ('🔥', '$_streak', 'Day streak'),
      ('📅', '$_checkinsThisMonth', 'This month'),
      ('📝', '${_history.length}', 'Total check-ins'),
    ];
    return Row(
      children: stats.map((s) {
        final (emoji, value, label) = s;
        return Expanded(
          child: Container(
            margin: EdgeInsets.only(right: s == stats.last ? 0 : 10),
            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 6),
            decoration: BoxDecoration(
              color: Theme.of(context).cardColor,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
            ),
            child: Column(
              children: [
                Text(emoji, style: const TextStyle(fontSize: 15)),
                const SizedBox(height: 4),
                Text(value,
                    style: Theme.of(context)
                        .textTheme
                        .titleLarge
                        ?.copyWith(fontSize: 17, fontWeight: FontWeight.w800)),
                const SizedBox(height: 2),
                Text(
                  label,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontSize: 10),
                ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _heroCard(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: AppColors.gradientPrimary,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Start today\'s wellbeing check-in',
                  style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 8),
                const Text(
                  '9 quick questions, ~1 minute, with a clear explanation of your result.',
                  style: TextStyle(color: Colors.white70, fontSize: 12.5),
                ),
                const SizedBox(height: 14),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: AppColors.primaryDark,
                    disabledBackgroundColor: Colors.white,
                    elevation: 4,
                    shadowColor: Colors.black.withValues(alpha: 0.35),
                    padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800),
                  ),
                  onPressed: () => widget.onNavigateToTab(1),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text('Begin check-in'),
                      SizedBox(width: 6),
                      Icon(Icons.arrow_forward_rounded, size: 18),
                    ],
                  ),
                ),
              ],
            ),
          ),
          AppIllustration.motherAndBaby(size: 90),
        ],
      ),
    );
  }

  Widget _latestCard(BuildContext context) {
    if (_latest == null) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Row(
            children: [
              AppIllustration.calendarSparkle(size: 64),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'No check-ins yet. Your first result will appear here.',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ),
            ],
          ),
        ),
      );
    }
    final color = AppColors.bandColor(_latest!.riskBand);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Row(
          children: [
            Container(
              width: 54,
              height: 54,
              decoration: BoxDecoration(color: color.withValues(alpha: 0.15), shape: BoxShape.circle),
              child: Icon(Icons.favorite_rounded, color: color),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Last result: ${_latest!.riskBand}',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(color: color)),
                  const SizedBox(height: 4),
                  Text(
                    _formatDate(_latest!.timestamp),
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ],
              ),
            ),
            TextButton(onPressed: () => widget.onNavigateToTab(2), child: const Text('View')),
          ],
        ),
      ),
    );
  }

  Widget _trendCard(BuildContext context) {
    final recent = _history.take(7).toList().reversed.toList();
    final spots = <FlSpot>[
      for (var i = 0; i < recent.length; i++) FlSpot(i.toDouble(), recent[i].riskProbability),
    ];
    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(18, 16, 18, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Recent trend', style: Theme.of(context).textTheme.titleMedium),
                Text('Last ${recent.length}', style: Theme.of(context).textTheme.bodyMedium),
              ],
            ),
            const SizedBox(height: 10),
            SizedBox(
              height: 90,
              child: LineChart(
                LineChartData(
                  minY: 0,
                  maxY: 1,
                  gridData: const FlGridData(show: false),
                  borderData: FlBorderData(show: false),
                  titlesData: const FlTitlesData(show: false),
                  lineTouchData: const LineTouchData(enabled: false),
                  lineBarsData: [
                    LineChartBarData(
                      spots: spots,
                      isCurved: true,
                      color: AppColors.primary,
                      barWidth: 3,
                      dotData: FlDotData(
                        show: true,
                        getDotPainter: (spot, percent, bar, index) => FlDotCirclePainter(
                          radius: index == spots.length - 1 ? 4.5 : 2.5,
                          color: AppColors.bandColor(recent[index].riskBand),
                          strokeWidth: 0,
                        ),
                      ),
                      belowBarData: BarAreaData(show: true, color: AppColors.primary.withValues(alpha: 0.10)),
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

  Widget _quickActions(BuildContext context) {
    final actions = [
      (Icons.edit_note_rounded, 'Check-in', AppColors.primary, () => widget.onNavigateToTab(1)),
      (Icons.show_chart_rounded, 'History', AppColors.accent, () => widget.onNavigateToTab(2)),
      (Icons.spa_rounded, 'Resources', AppColors.secondary, () => widget.onNavigateToTab(3)),
      (
        Icons.support_agent_rounded,
        'Crisis Help',
        AppColors.danger,
        () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const HelpScreen())),
      ),
      (
        Icons.groups_2_rounded,
        'Community Insights',
        AppColors.primaryDark,
        () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const InsightsScreen())),
      ),
    ];
    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 12,
      crossAxisSpacing: 12,
      childAspectRatio: 2.2,
      children: actions.map((a) {
        final (icon, label, color, onTap) = a;
        return InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: onTap,
          child: Container(
            decoration: BoxDecoration(
              color: Theme.of(context).cardColor,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 14),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(color: color.withValues(alpha: 0.12), shape: BoxShape.circle),
                  child: Icon(icon, color: color, size: 20),
                ),
                const SizedBox(width: 10),
                Flexible(
                  child: Text(label, style: Theme.of(context).textTheme.titleMedium, overflow: TextOverflow.ellipsis),
                ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _tipCard(BuildContext context) {
    final tip = _todaysTip;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: tip.color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: tip.color.withValues(alpha: 0.18)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(9),
            decoration: BoxDecoration(color: tip.color.withValues(alpha: 0.16), shape: BoxShape.circle),
            child: Icon(tip.icon, color: tip.color, size: 18),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Tip for today', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontSize: 13)),
                const SizedBox(height: 4),
                Text(tip.text, style: Theme.of(context).textTheme.bodyMedium),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _resourceTeaser(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(18),
      onTap: () => widget.onNavigateToTab(3),
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              AppIllustration.book(size: 48),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Explore self-care resources', style: Theme.of(context).textTheme.titleMedium),
                    const SizedBox(height: 2),
                    Text(
                      'Short, practical tips for the postpartum weeks.',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right_rounded, color: AppColors.textSecondary),
            ],
          ),
        ),
      ),
    );
  }

  String _formatDate(DateTime dt) {
    final now = DateTime.now();
    final diff = now.difference(dt);
    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inHours < 1) return '${diff.inMinutes} min ago';
    if (diff.inDays < 1) return '${diff.inHours} hr ago';
    if (diff.inDays < 7) return '${diff.inDays} day${diff.inDays == 1 ? '' : 's'} ago';
    return '${dt.day}/${dt.month}/${dt.year}';
  }
}
