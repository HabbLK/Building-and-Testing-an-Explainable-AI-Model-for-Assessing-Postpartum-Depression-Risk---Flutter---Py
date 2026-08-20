import '../services/api_service.dart';

/// Consecutive-day check-in streak, counting back from today.
/// Returns 0 if the most recent check-in wasn't today or yesterday.
int computeStreak(List<ServerAssessment> history) {
  if (history.isEmpty) return 0;

  final dates = history
      .map((r) => DateTime(r.timestamp.year, r.timestamp.month, r.timestamp.day))
      .toSet()
      .toList()
    ..sort((a, b) => b.compareTo(a));

  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final yesterday = today.subtract(const Duration(days: 1));

  if (dates.first != today && dates.first != yesterday) return 0;

  var streak = 1;
  for (var i = 0; i < dates.length - 1; i++) {
    if (dates[i].difference(dates[i + 1]).inDays == 1) {
      streak++;
    } else {
      break;
    }
  }
  return streak;
}
