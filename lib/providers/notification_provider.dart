import 'package:flutter_riverpod/flutter_riverpod.dart';

class AppNotification {
  final String message;
  final DateTime time;
  AppNotification(this.message, this.time);
}

class NotificationNotifier extends Notifier<List<AppNotification>> {
  @override
  List<AppNotification> build() => [];

  void add(String message) {
    state = [AppNotification(message, DateTime.now()), ...state];
  }

  void clear() => state = [];
}

final notificationProvider =
    NotifierProvider<NotificationNotifier, List<AppNotification>>(
  NotificationNotifier.new,
);