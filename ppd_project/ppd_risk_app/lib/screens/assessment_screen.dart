import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../services/on_device_model.dart';
import '../theme/app_theme.dart';
import 'result_screen.dart';

class AssessmentScreen extends StatefulWidget {
  const AssessmentScreen({super.key});

  @override
  State<AssessmentScreen> createState() => _AssessmentScreenState();
}

class _AssessmentScreenState extends State<AssessmentScreen> {
  late Future<OnDeviceModel> _modelFuture;
  final PageController _pageController = PageController();
  final Map<String, String> _answers = {};
  int _step = 0;
  bool _submitting = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _modelFuture = OnDeviceModel.load();
  }

  List<QuestionSchema> _allQuestions(AppSchema schema) => [schema.age, ...schema.symptoms];

  void _select(String key, String value, int totalSteps) {
    setState(() => _answers[key] = value);
    Future.delayed(const Duration(milliseconds: 180), () {
      if (!mounted) return;
      if (_step < totalSteps - 1) {
        _pageController.nextPage(duration: const Duration(milliseconds: 280), curve: Curves.easeOut);
      }
    });
  }

  Future<void> _submit(OnDeviceModel model) async {
    setState(() {
      _submitting = true;
      _error = null;
    });
    try {
      // Runs entirely on-device (logistic regression + linear-SHAP), no
      // network call and no Python backend required.
      final result = model.predict(_answers);
      if (!mounted) return;
      final restart = await Navigator.of(context).push<bool>(
        MaterialPageRoute(builder: (_) => ResultScreen(result: result)),
      );
      if (restart == true) {
        setState(() {
          _answers.clear();
          _step = 0;
        });
        _pageController.jumpToPage(0);
      }
    } catch (e) {
      setState(() => _error = 'Could not compute a result: $e');
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Wellbeing Check-in')),
      body: FutureBuilder<OnDeviceModel>(
        future: _modelFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text('Could not load the questionnaire.\n${snapshot.error}', textAlign: TextAlign.center),
              ),
            );
          }

          final model = snapshot.data!;
          final schema = model.schema;
          final questions = _allQuestions(schema);
          final total = questions.length;

          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: LinearProgressIndicator(
                    value: (_step + 1) / total,
                    minHeight: 8,
                    backgroundColor: Theme.of(context).colorScheme.outlineVariant.withValues(alpha: 0.4),
                    valueColor: const AlwaysStoppedAnimation(AppColors.primary),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text('Question ${_step + 1} of $total', style: Theme.of(context).textTheme.bodyMedium),
                ),
              ),
              Expanded(
                child: PageView.builder(
                  controller: _pageController,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: total,
                  onPageChanged: (i) => setState(() => _step = i),
                  itemBuilder: (context, i) {
                    final q = questions[i];
                    return Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          const SizedBox(height: 8),
                          Text(
                            q.label,
                            style: Theme.of(context).textTheme.headlineMedium,
                          ),
                          const SizedBox(height: 24),
                          ...q.options.map((opt) {
                            final selected = _answers[q.key] == opt;
                            return Padding(
                              padding: const EdgeInsets.only(bottom: 12),
                              child: InkWell(
                                borderRadius: BorderRadius.circular(16),
                                onTap: () => _select(q.key, opt, total),
                                child: AnimatedContainer(
                                  duration: const Duration(milliseconds: 200),
                                  padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
                                  decoration: BoxDecoration(
                                    color: selected
                                        ? Theme.of(context).colorScheme.primary.withValues(alpha: 0.14)
                                        : Theme.of(context).cardColor,
                                    borderRadius: BorderRadius.circular(16),
                                    border: Border.all(
                                      color: selected
                                          ? Theme.of(context).colorScheme.primary
                                          : Theme.of(context).colorScheme.outlineVariant,
                                      width: selected ? 1.6 : 1,
                                    ),
                                  ),
                                  child: Row(
                                    children: [
                                      Expanded(
                                        child: Text(
                                          opt,
                                          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                                color: selected
                                                    ? Theme.of(context).colorScheme.primary
                                                    : Theme.of(context).colorScheme.onSurface,
                                              ),
                                        ),
                                      ),
                                      if (selected)
                                        Icon(Icons.check_circle_rounded, color: Theme.of(context).colorScheme.primary),
                                    ],
                                  ),
                                ),
                              ),
                            );
                          }),
                          if (i == total - 1 && _error != null) ...[
                            const SizedBox(height: 8),
                            Text(_error!, style: const TextStyle(color: Colors.red)),
                          ],
                        ],
                      ),
                    );
                  },
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(20),
                child: Row(
                  children: [
                    if (_step > 0)
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () => _pageController.previousPage(
                            duration: const Duration(milliseconds: 280),
                            curve: Curves.easeOut,
                          ),
                          child: const Text('Back'),
                        ),
                      ),
                    if (_step > 0) const SizedBox(width: 12),
                    if (_step == total - 1)
                      Expanded(
                        flex: 2,
                        child: ElevatedButton(
                          onPressed: (_submitting || !_answers.containsKey(questions[_step].key))
                              ? null
                              : () => _submit(model),
                          child: _submitting
                              ? const SizedBox(
                                  height: 20,
                                  width: 20,
                                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                              : const Text('Get my result'),
                        ),
                      ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
