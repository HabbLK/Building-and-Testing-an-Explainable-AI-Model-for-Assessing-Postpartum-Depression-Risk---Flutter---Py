import 'package:flutter/material.dart';
import 'home_screen.dart';
import 'assessment_screen.dart';
import 'history_screen.dart';
import 'resources_screen.dart';
import 'profile_screen.dart';

/// Bottom-nav shell hosting the 5 main tabs of the app.
class MainShell extends StatefulWidget {
  const MainShell({super.key});

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  int _index = 0;
  final _homeKey = GlobalKey<HomeScreenState>();
  final _historyKey = GlobalKey<HistoryScreenState>();
  final _profileKey = GlobalKey<ProfileScreenState>();

  void goToTab(int i) {
    setState(() => _index = i);
    _refreshTab(i);
  }

  void _refreshTab(int i) {
    switch (i) {
      case 0:
        _homeKey.currentState?.refresh();
        break;
      case 2:
        _historyKey.currentState?.refresh();
        break;
      case 4:
        _profileKey.currentState?.refresh();
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    final pages = [
      HomeScreen(key: _homeKey, onNavigateToTab: goToTab),
      const AssessmentScreen(),
      HistoryScreen(key: _historyKey),
      const ResourcesScreen(),
      ProfileScreen(key: _profileKey),
    ];

    return Scaffold(
      body: IndexedStack(index: _index, children: pages),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _index,
        onTap: (i) {
          setState(() => _index = i);
          _refreshTab(i);
        },
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.home_rounded), label: 'Home'),
          BottomNavigationBarItem(icon: Icon(Icons.edit_note_rounded), label: 'Check-in'),
          BottomNavigationBarItem(icon: Icon(Icons.show_chart_rounded), label: 'History'),
          BottomNavigationBarItem(icon: Icon(Icons.spa_rounded), label: 'Resources'),
          BottomNavigationBarItem(icon: Icon(Icons.person_rounded), label: 'Profile'),
        ],
      ),
    );
  }
}
