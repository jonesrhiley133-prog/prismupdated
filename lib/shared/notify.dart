import 'package:flutter_local_notifications/flutter_local_notifications.dart';

/// Notification channels and id ranges used by the 0.24 modules. Each range
/// holds 1000 ids so a module can cancel all of its own notifications.
abstract final class PrismNotify {
  static const availabilityBase = 1500000000;
  static const hydrationBase = 1500001000;
  static const automationBase = 1500002000;
  static const habitBase = 1500003000;
  static const subsystemBase = 1500004000;
  static const range = 1000;

  static NotificationDetails details(String channelId, String channelName) {
    final android = AndroidNotificationDetails(
      channelId,
      channelName,
      importance: Importance.defaultImportance,
      priority: Priority.defaultPriority,
    );
    const darwin = DarwinNotificationDetails();
    return NotificationDetails(android: android, iOS: darwin, macOS: darwin);
  }
}
