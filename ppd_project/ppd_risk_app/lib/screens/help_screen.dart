import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../widgets/illustrations.dart';

class _Contact {
  final String name;
  final String detail;
  final IconData icon;
  _Contact(this.name, this.detail, this.icon);
}

class HelpScreen extends StatelessWidget {
  const HelpScreen({super.key});

  static final _contacts = [
    _Contact('Emergency services', 'If you or someone else is in immediate danger, call your local emergency number (e.g. 999 in the UK, 911 in the US).', Icons.emergency_rounded),
    _Contact('Samaritans (UK & ROI)', 'Free, 24/7 confidential support: call 116 123.', Icons.phone_in_talk_rounded),
    _Contact('NHS 111 (UK)', 'For urgent (non-emergency) health advice: call 111.', Icons.local_hospital_rounded),
    _Contact('Your midwife, GP, or health visitor', 'They can assess how you are feeling and refer you to specialist perinatal mental health support.', Icons.diversity_1_rounded),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Help & Crisis Support')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Center(child: AppIllustration.supportCall(size: 170)),
          const SizedBox(height: 8),
          Text('You are not alone', style: Theme.of(context).textTheme.headlineMedium, textAlign: TextAlign.center),
          const SizedBox(height: 8),
          Text(
            'If this app suggested an elevated risk, or you are simply struggling, please reach out — support is available.',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: 24),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.danger.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppColors.danger.withValues(alpha: 0.3)),
            ),
            child: Row(
              children: [
                const Icon(Icons.warning_amber_rounded, color: AppColors.danger),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'This app is a research prototype and cannot respond in an emergency. If you are in danger, contact emergency services immediately.',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: AppColors.textPrimary),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          ..._contacts.map((c) => Card(
                margin: const EdgeInsets.only(bottom: 12),
                child: ListTile(
                  contentPadding: const EdgeInsets.all(14),
                  leading: Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(color: AppColors.primary.withValues(alpha: 0.1), shape: BoxShape.circle),
                    child: Icon(c.icon, color: AppColors.primary),
                  ),
                  title: Text(c.name, style: Theme.of(context).textTheme.titleMedium),
                  subtitle: Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(c.detail, style: Theme.of(context).textTheme.bodyMedium),
                  ),
                ),
              )),
          const SizedBox(height: 8),
          Text(
            'This is not an exhaustive list. Search for perinatal mental health services in your own country if you need local support.',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyMedium,
          ),
        ],
      ),
    );
  }
}
