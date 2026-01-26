import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../services/notification_service.dart';
import '../../services/settings_service.dart';
import '../theme_card.dart';

/// A settings card for configuring daily reminder notifications.
class NotificationCard extends StatefulWidget {
  const NotificationCard({super.key});

  @override
  State<NotificationCard> createState() => _NotificationCardState();
}

class _NotificationCardState extends State<NotificationCard> {
  late SettingsService _settingsService;
  late NotificationService _notificationService;
  late bool _notificationsEnabled;
  late TimeOfDay _notificationTime;

  @override
  void initState() {
    super.initState();
    _settingsService = context.read<SettingsService>();
    _notificationService = context.read<NotificationService>();
    _notificationsEnabled = _settingsService.getNotificationsEnabled();
    _notificationTime = _settingsService.getNotificationTime();
  }

  Future<void> _onEnabledChanged(bool value) async {
    setState(() {
      _notificationsEnabled = value;
    });
    await _settingsService.setNotificationsEnabled(value);
    await _notificationService.scheduleDailyNotification();
  }

  Future<void> _onTimePressed() async {
    final pickedTime = await showTimePicker(
      context: context,
      initialTime: _notificationTime,
    );
    if (pickedTime != null && mounted) {
      setState(() {
        _notificationTime = pickedTime;
      });
      await _settingsService.setNotificationTime(pickedTime);
      await _notificationService.scheduleDailyNotification();
    }
  }

  String _formatTime(TimeOfDay time) {
    final hour = time.hourOfPeriod == 0 ? 12 : time.hourOfPeriod;
    final minute = time.minute.toString().padLeft(2, '0');
    final period = time.period == DayPeriod.am ? 'AM' : 'PM';
    return '$hour:$minute $period';
  }

  @override
  Widget build(BuildContext context) => ThemeCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Daily Reminder',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 12),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Enable notifications'),
              subtitle: Text(
                _notificationsEnabled
                    ? 'You will receive daily reminders'
                    : 'Notifications are disabled',
              ),
              value: _notificationsEnabled,
              onChanged: _onEnabledChanged,
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Reminder Time',
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _formatTime(_notificationTime),
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: _notificationsEnabled
                                  ? Colors.green
                                  : Colors.grey,
                            ),
                      ),
                    ],
                  ),
                ),
                FilledButton.tonal(
                  onPressed: _notificationsEnabled ? _onTimePressed : null,
                  child: const Text('Change Time'),
                ),
              ],
            ),
          ],
        ),
      );
}
