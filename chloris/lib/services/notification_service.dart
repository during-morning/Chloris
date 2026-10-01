import 'package:flutter_local_notifications/flutter_local_notifications.dart';

/// 本地通知服务（Android/iOS/macOS；其它平台可编译但不展示）。
class NotificationService {
  const NotificationService();

  Future<void> showTest() => _show('Cholris', '这是一条测试通知');

  Future<void> _show(String title, String body) async {
    final plugin = FlutterLocalNotificationsPlugin();
    await plugin.initialize(
      settings: const InitializationSettings(
        android: AndroidInitializationSettings('@mipmap/ic_launcher'),
        iOS: DarwinInitializationSettings(),
        macOS: DarwinInitializationSettings(),
      ),
    );
    const android = AndroidNotificationDetails(
      'default',
      '默认',
      importance: Importance.high,
      priority: Priority.high,
    );
    const ios = DarwinNotificationDetails();
    await plugin.show(
      id: 1,
      title: title,
      body: body,
      notificationDetails: const NotificationDetails(
      android: android,
      iOS: ios,
      macOS: ios,
    ));
  }
}
