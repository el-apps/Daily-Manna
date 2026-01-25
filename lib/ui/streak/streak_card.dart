import 'package:daily_manna/services/streak_service.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

/// Home page card displaying current streak status.
class StreakCard extends StatelessWidget {
  const StreakCard({super.key});

  @override
  Widget build(BuildContext context) {
    final streakService = context.read<StreakService>();

    return StreamBuilder<StreakState>(
      stream: streakService.watchStreak(),
      builder: (context, snapshot) {
        final state = snapshot.data ?? 
            const StreakState(streakDays: 0, activityToday: false);

        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Card.filled(
            child: InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: () => _showStreakDialog(context, state),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  vertical: 24,
                  horizontal: 24,
                ),
                child: Center(child: _buildContent(context, state)),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildContent(BuildContext context, StreakState state) {
    final textStyle = Theme.of(context).textTheme.titleLarge;

    if (state.streakDays == 0) {
      return Text(
        'Start a daily habit in the Word!',
        style: textStyle,
        textAlign: TextAlign.center,
      );
    }

    final emoji = state.activityToday ? '🔥' : '⚠️';
    final days = state.streakDays == 1 ? 'day' : 'days';

    return Text(
      '$emoji ${state.streakDays} $days',
      style: textStyle?.copyWith(fontSize: 28),
      textAlign: TextAlign.center,
    );
  }

  void _showStreakDialog(BuildContext context, StreakState state) {
    final message = _getDialogMessage(state);

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Your Streak'),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  String _getDialogMessage(StreakState state) {
    if (state.streakDays == 0) {
      return 'Complete any practice, review, or study activity to start your streak.';
    }

    if (!state.activityToday) {
      return 'Complete an activity today to keep your ${state.streakDays} day streak going!';
    }

    return "You've extended your streak to ${state.streakDays} days! Keep it up!";
  }
}
