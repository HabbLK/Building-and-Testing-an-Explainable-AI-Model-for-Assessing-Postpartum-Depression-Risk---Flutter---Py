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

class HomeScreenState extends State<HomeScreen> {
  String _name = '';
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
      _latest = history.isNotEmpty ? history.first : null;
      _streak = computeStreak(history);
      _loading = false;
    });
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
                    Row(
                      children: [
                        Expanded(
                          child: Text('How are you feeling today?',
                              style: Theme.of(context).textTheme.bodyMedium),
                        ),
                        if (_streak > 0) _streakChip(context),
                      ],
                    ),
                    const SizedBox(height: 20),
                    _heroCard(context),
                    const SizedBox(height: 20),
                    _latestCard(context),
                    const SizedBox(height: 24),
                    Text('Quick actions', style: Theme.of(context).textTheme.titleMedium),
                    const SizedBox(height: 12),
                    _quickActions(context),
                  ],
                ),
              ),
      ),
    );
  }

  Widget _streakChip(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.warning.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text('🔥', style: TextStyle(fontSize: 13)),
          const SizedBox(width: 4),
          Text(
            '$_streak-day streak',
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.warning),
          ),
        ],
      ),
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
