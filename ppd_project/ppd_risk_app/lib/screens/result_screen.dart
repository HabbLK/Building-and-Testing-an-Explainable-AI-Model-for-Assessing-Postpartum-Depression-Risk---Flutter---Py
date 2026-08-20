import 'package:flutter/material.dart';
import 'package:percent_indicator/percent_indicator.dart';
import '../services/api_service.dart';
import '../services/local_store.dart';
import '../theme/app_theme.dart';
import '../widgets/illustrations.dart';
import 'help_screen.dart';

class _TipItem {
  final IconData icon;
  final String text;
  const _TipItem(this.icon, this.text);
}

const _sadTips = [
  _TipItem(Icons.bedtime_rounded,
      'Protect your sleep — nap when the baby naps, and ask someone to cover one night feed if you can.'),
  _TipItem(Icons.groups_rounded, 'Tell someone you trust how you\'re really feeling today, even briefly.'),
  _TipItem(Icons.directions_walk_rounded,
      'Ten minutes outside, even just on the doorstep, can genuinely lift your mood.'),
  _TipItem(Icons.restaurant_rounded,
      'Keep meals simple and accept help with food if it\'s offered — it matters more than "perfect".'),
  _TipItem(Icons.self_improvement_rounded, 'Be gentle with yourself — this feeling is common, and it is treatable.'),
];

const _tearfulTips = [
  _TipItem(Icons.support_agent_rounded,
      'You don\'t have to manage this alone — tell a partner, friend, or health visitor today.'),
  _TipItem(Icons.medical_services_rounded, 'Consider raising this with your GP, midwife, or health visitor this week.'),
  _TipItem(Icons.self_improvement_rounded, 'A few slow breaths before a feed can take the edge off in the moment.'),
  _TipItem(Icons.checklist_rtl_rounded, 'Lower the bar on chores — rest matters more than getting things done right now.'),
  _TipItem(Icons.favorite_rounded,
      'If this feeling doesn\'t ease over the next couple of weeks, please don\'t wait to ask for support.'),
];

class ResultScreen extends StatefulWidget {
  final RiskResult result;

  const ResultScreen({super.key, required this.result});

  @override
  State<ResultScreen> createState() => _ResultScreenState();
}

class _ResultScreenState extends State<ResultScreen> {
  final _noteController = TextEditingController();
  String? _savedAssessmentId;
  bool _saving = true;
  bool _saveFailed = false;
  bool _savingNote = false;

  @override
  void initState() {
    super.initState();
    _persist();
  }

  Future<void> _persist() async {
    final token = await LocalStore.getToken();
    if (token == null) {
      setState(() {
        _saving = false;
        _saveFailed = true;
      });
      return;
    }
    try {
      final saved = await ApiService.saveAssessment(
        token,
        riskProbability: widget.result.riskProbability,
        riskBand: widget.result.riskBand,
        topFactors: widget.result.topFactors,
      );
      if (!mounted) return;
      setState(() {
        _savedAssessmentId = saved.id;
        _saving = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _saveFailed = true;
      });
    }
  }

  Future<void> _saveNote() async {
    if (_savedAssessmentId == null) return;
    final token = await LocalStore.getToken();
    if (token == null) return;
    setState(() => _savingNote = true);
    try {
      await ApiService.updateNote(token, _savedAssessmentId!, _noteController.text);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Note saved privately to this check-in')),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not save note — check your connection')),
      );
    } finally {
      if (mounted) setState(() => _savingNote = false);
    }
  }

  @override
  void dispose() {
    _noteController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final result = widget.result;
    final color = AppColors.bandColor(result.riskBand);

    return Scaffold(
      appBar: AppBar(title: const Text('Your Result')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(28),
                  child: Column(
                    children: [
                      if (result.riskBand == 'Happy')
                        AppIllustration.successBadge(size: 130)
                      else
                        Icon(
                          result.riskBand.startsWith('Extreme')
                              ? Icons.warning_amber_rounded
                              : Icons.info_rounded,
                          size: 64,
                          color: color,
                        ),
                      const SizedBox(height: 16),
                      CircularPercentIndicator(
                        radius: 78,
                        lineWidth: 14,
                        percent: result.riskProbability.clamp(0.0, 1.0),
                        animation: true,
                        animationDuration: 900,
                        circularStrokeCap: CircularStrokeCap.round,
                        backgroundColor: Theme.of(context).colorScheme.outlineVariant.withValues(alpha: 0.4),
                        progressColor: color,
                        center: Text(
                          '${(result.riskProbability * 100).toStringAsFixed(0)}%',
                          style: Theme.of(context).textTheme.headlineMedium?.copyWith(color: color),
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        result.riskBand,
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: color),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Self-reported mood estimate — not a clinical diagnosis',
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                      const SizedBox(height: 10),
                      if (_saving)
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const SizedBox(
                              height: 12, width: 12, child: CircularProgressIndicator(strokeWidth: 2)),
                            const SizedBox(width: 8),
                            Text('Saving to your history…', style: Theme.of(context).textTheme.bodyMedium),
                          ],
                        )
                      else if (_saveFailed)
                        Text('Could not save this result — it will not appear in your history.',
                            style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: AppColors.danger))
                      else
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.cloud_done_rounded, size: 14, color: AppColors.success),
                            const SizedBox(width: 6),
                            Text('Saved to your history', style: Theme.of(context).textTheme.bodyMedium),
                          ],
                        ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),
              Text('What influenced this estimate', style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 12),
              ...result.topFactors.map((f) {
                final up = f.direction == 'increases';
                return Card(
                  margin: const EdgeInsets.only(bottom: 8),
                  child: ListTile(
                    leading: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: (up ? AppColors.danger : AppColors.success).withValues(alpha: 0.12),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        up ? Icons.arrow_upward_rounded : Icons.arrow_downward_rounded,
                        color: up ? AppColors.danger : AppColors.success,
                      ),
                    ),
                    title: Text(f.factor, style: Theme.of(context).textTheme.titleMedium),
                    subtitle: Text(up ? 'Pushed the estimate higher' : 'Pushed the estimate lower'),
                  ),
                );
              }),
              if (result.riskBand == 'Sad' || result.riskBand == 'Tearful') ...[
                const SizedBox(height: 24),
                _tipsSection(context, result.riskBand == 'Sad' ? _sadTips : _tearfulTips, color),
              ],
              if (result.riskBand.startsWith('Extreme')) ...[
                const SizedBox(height: 24),
                _urgentHelpCard(context),
              ],
              const SizedBox(height: 20),
              Text('Private note (optional)', style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 8),
              Text(
                'Jot down anything that might explain today\'s result — only you can see this.',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const SizedBox(height: 10),
              TextField(
                controller: _noteController,
                maxLines: 3,
                enabled: _savedAssessmentId != null,
                decoration: const InputDecoration(hintText: 'e.g. Rough night, baby was unwell...'),
              ),
              const SizedBox(height: 10),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton.icon(
                  onPressed: (_savedAssessmentId == null || _savingNote) ? null : _saveNote,
                  icon: _savingNote
                      ? const SizedBox(height: 14, width: 14, child: CircularProgressIndicator(strokeWidth: 2))
                      : const Icon(Icons.save_rounded, size: 18),
                  label: const Text('Save note'),
                ),
              ),
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.06),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.info_outline_rounded, color: AppColors.primary, size: 20),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(result.disclaimer, style: Theme.of(context).textTheme.bodyMedium),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: () => Navigator.of(context).pop(true),
                child: const Text('Start a new check-in'),
              ),
              const SizedBox(height: 10),
              OutlinedButton(
                onPressed: () => Navigator.of(context).popUntil((route) => route.isFirst),
                child: const Text('Back to home'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _tipsSection(BuildContext context, List<_TipItem> tips, Color color) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Things that might help right now', style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 6),
        Text(
          'A few small, practical things — not a substitute for professional support.',
          style: Theme.of(context).textTheme.bodyMedium,
        ),
        const SizedBox(height: 12),
        ...tips.map((t) => Card(
              margin: const EdgeInsets.only(bottom: 10),
              child: ListTile(
                contentPadding: const EdgeInsets.all(14),
                leading: Container(
                  padding: const EdgeInsets.all(9),
                  decoration: BoxDecoration(color: color.withValues(alpha: 0.12), shape: BoxShape.circle),
                  child: Icon(t.icon, color: color, size: 20),
                ),
                title: Text(t.text, style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: AppColors.textPrimary)),
              ),
            )),
      ],
    );
  }

  Widget _urgentHelpCard(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.critical.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.critical.withValues(alpha: 0.35)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.warning_amber_rounded, color: AppColors.critical),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'This result suggests you may need support soon',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(color: AppColors.critical),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Please consider speaking to your GP, midwife, or health visitor as soon as you can — '
            'or use the crisis contacts below if you need to talk to someone right now.',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.critical, foregroundColor: Colors.white),
              onPressed: () =>
                  Navigator.of(context).push(MaterialPageRoute(builder: (_) => const HelpScreen())),
              icon: const Icon(Icons.support_agent_rounded),
              label: const Text('See crisis support contacts'),
            ),
          ),
        ],
      ),
    );
  }
}
