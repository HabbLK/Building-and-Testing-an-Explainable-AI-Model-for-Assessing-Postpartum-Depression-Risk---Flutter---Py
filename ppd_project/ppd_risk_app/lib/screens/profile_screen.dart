import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../services/local_store.dart';
import '../theme/app_theme.dart';
import '../theme/theme_controller.dart';
import '../utils/streak.dart';
import 'help_screen.dart';
import 'login_screen.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => ProfileScreenState();
}

class ProfileScreenState extends State<ProfileScreen> {
  String _name = '';
  String _email = '';
  List<ServerAssessment> _history = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> refresh() => _load();

  Future<void> _load() async {
    final user = await LocalStore.currentUser();
    final token = await LocalStore.getToken();
    List<ServerAssessment> history = [];
    if (token != null) {
      try {
        history = await ApiService.getAssessments(token);
      } catch (_) {
        // Keep showing cached values if offline.
      }
    }
    if (!mounted) return;
    setState(() {
      _name = user?['name'] ?? 'Guest';
      _email = user?['email'] ?? '';
      _history = history;
      _loading = false;
    });
  }

  Future<void> _editName() async {
    final controller = TextEditingController(text: _name);
    final newName = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Edit name'),
        content: TextField(controller: controller, autofocus: true),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, controller.text.trim()),
            child: const Text('Save'),
          ),
        ],
      ),
    );
    if (newName != null && newName.isNotEmpty) {
      final token = await LocalStore.getToken();
      if (token != null) {
        try {
          await ApiService.updateName(token, newName);
          await LocalStore.updateCachedName(newName);
        } catch (_) {
          if (!mounted) return;
          ScaffoldMessenger.of(context)
              .showSnackBar(const SnackBar(content: Text('Could not update name — check your connection')));
        }
      }
      _load();
    }
  }

  Future<void> _logout() async {
    final token = await LocalStore.getToken();
    if (token != null) {
      await ApiService.logout(token);
    }
    await LocalStore.clearSession();
    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const LoginScreen()),
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    final lastBand = _history.isNotEmpty ? _history.first.riskBand : '—';
    final streak = computeStreak(_history);
    return Scaffold(
      appBar: AppBar(title: const Text('Profile')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(20),
              children: [
                Center(
                  child: Column(
                    children: [
                      CircleAvatar(
                        radius: 44,
                        backgroundColor: AppColors.primary,
                        child: Text(
                          _name.isNotEmpty ? _name[0].toUpperCase() : '?',
                          style: const TextStyle(color: Colors.white, fontSize: 32, fontWeight: FontWeight.bold),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(_name, style: Theme.of(context).textTheme.headlineMedium),
                      Text(_email, style: Theme.of(context).textTheme.bodyMedium),
                      const SizedBox(height: 10),
                      TextButton.icon(
                        onPressed: _editName,
                        icon: const Icon(Icons.edit_rounded, size: 16),
                        label: const Text('Edit name'),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(child: _statCard('Check-ins', '${_history.length}', Icons.edit_note_rounded, AppColors.primary)),
                    const SizedBox(width: 12),
                    Expanded(child: _statCard('Last result', lastBand, Icons.favorite_rounded, AppColors.secondary)),
                    const SizedBox(width: 12),
                    Expanded(child: _statCard('Streak', '$streak 🔥', Icons.local_fire_department_rounded, AppColors.warning)),
                  ],
                ),
                const SizedBox(height: 24),
                Card(
                  child: Column(
                    children: [
                      SwitchListTile(
                        secondary: const Icon(Icons.dark_mode_rounded, color: AppColors.primary),
                        title: const Text('Dark mode'),
                        value: themeModeNotifier.value == ThemeMode.dark,
                        onChanged: (v) {
                          toggleThemeMode(v);
                          setState(() {});
                        },
                      ),
                      const Divider(height: 1),
                      ListTile(
                        leading: const Icon(Icons.support_agent_rounded, color: AppColors.primary),
                        title: const Text('Help & crisis support'),
                        trailing: const Icon(Icons.chevron_right_rounded),
                        onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const HelpScreen())),
                      ),
                      const Divider(height: 1),
                      ListTile(
                        leading: const Icon(Icons.info_outline_rounded, color: AppColors.primary),
                        title: const Text('About this app'),
                        trailing: const Icon(Icons.chevron_right_rounded),
                        onTap: () => _showAbout(context),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                OutlinedButton.icon(
                  onPressed: _logout,
                  icon: const Icon(Icons.logout_rounded, color: AppColors.danger),
                  label: const Text('Log out', style: TextStyle(color: AppColors.danger)),
                  style: OutlinedButton.styleFrom(side: const BorderSide(color: AppColors.danger)),
                ),
              ],
            ),
    );
  }

  Widget _statCard(String label, String value, IconData icon, Color color) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: color, size: 20),
            const SizedBox(height: 10),
            Text(value, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            Text(label, style: Theme.of(context).textTheme.bodyMedium, overflow: TextOverflow.ellipsis),
          ],
        ),
      ),
    );
  }

  void _showAbout(BuildContext context) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (context) => Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('MotherWell — Research Prototype', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 10),
            Text(
              'An explainable machine learning prototype exploring self-reported low-mood '
              'symptom co-occurrence from a short screening questionnaire. This estimates '
              'how a person\'s OTHER reported symptoms relate to feeling sad or tearful -- '
              'it is not a validated postpartum depression diagnosis or screening tool. '
              'Built for a Computer Science Masters project (7COM1040). Accounts and '
              'check-ins are stored in MongoDB; predictions run on-device.',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 12),
            Text(
              'This app is NOT a diagnostic tool and does not replace professional medical advice.',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: AppColors.danger, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(onPressed: () => Navigator.pop(context), child: const Text('Close')),
            ),
          ],
        ),
      ),
    );
  }
}
