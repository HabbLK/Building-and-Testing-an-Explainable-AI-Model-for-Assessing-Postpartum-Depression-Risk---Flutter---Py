import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../widgets/illustrations.dart';
import 'help_screen.dart';
import 'insights_screen.dart';

class _Tip {
  final IconData icon;
  final Color color;
  final String title;
  final String body;
  _Tip(this.icon, this.color, this.title, this.body);
}

class ResourcesScreen extends StatelessWidget {
  const ResourcesScreen({super.key});

  static final _tips = [
    _Tip(Icons.bedtime_rounded, AppColors.primary, 'Protect your sleep',
        'Sleep when the baby sleeps where possible, and ask a partner or family member to cover a night feed so you can get one longer stretch of rest.'),
    _Tip(Icons.groups_rounded, AppColors.accent, 'Talk to someone you trust',
        'Sharing how you feel with a partner, friend, or health visitor — even briefly — can reduce feelings of isolation.'),
    _Tip(Icons.directions_walk_rounded, AppColors.secondary, 'Gentle movement',
        'A short walk outside, even 10 minutes, is linked with improved mood and energy during the postpartum period.'),
    _Tip(Icons.restaurant_rounded, AppColors.warning, 'Keep meals simple',
        'Regular, simple meals matter more than "perfect" ones. Batch-cooking or accepting help with food reduces daily load.'),
    _Tip(Icons.self_improvement_rounded, AppColors.success, 'Small mindful pauses',
        'A few slow breaths before feeding or during a nap can help regulate anxiety in the moment.'),
    _Tip(Icons.medical_services_rounded, AppColors.danger, 'Know when to ask for help',
        'Persistent sadness, anxiety, or difficulty bonding for more than two weeks is worth raising with a healthcare professional.'),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Resources')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Row(
                children: [
                  AppIllustration.book(size: 90),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Self-care while you adjust', style: Theme.of(context).textTheme.titleMedium),
                        const SizedBox(height: 6),
                        Text(
                          'General wellbeing tips — not a substitute for professional care.',
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),
          ..._tips.map((t) => Card(
                margin: const EdgeInsets.only(bottom: 12),
                child: ListTile(
                  contentPadding: const EdgeInsets.all(14),
                  leading: Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(color: t.color.withValues(alpha: 0.12), shape: BoxShape.circle),
                    child: Icon(t.icon, color: t.color),
                  ),
                  title: Text(t.title, style: Theme.of(context).textTheme.titleMedium),
                  subtitle: Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(t.body, style: Theme.of(context).textTheme.bodyMedium),
                  ),
                ),
              )),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const HelpScreen())),
            icon: const Icon(Icons.support_agent_rounded),
            label: const Text('Need urgent support? See crisis contacts'),
          ),
          const SizedBox(height: 10),
          OutlinedButton.icon(
            onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const InsightsScreen())),
            icon: const Icon(Icons.groups_2_rounded),
            label: const Text('See community insights'),
          ),
        ],
      ),
    );
  }
}
