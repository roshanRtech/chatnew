import 'dart:convert';
import 'dart:io';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:http/http.dart';
import 'package:nb_utils/nb_utils.dart';
import 'package:chat/centralized_import.dart';

class NotificationService {
  final FlutterLocalNotificationsPlugin _flutterLocalNotificationsPlugin =
      FlutterLocalNotificationsPlugin();

  NotificationService() {
    _initializeLocalNotifications();
  }

  /// Initialize local notifications
  void _initializeLocalNotifications() async {
    const androidSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosSettings = DarwinInitializationSettings();

    await _flutterLocalNotificationsPlugin.initialize(
      const InitializationSettings(android: androidSettings, iOS: iosSettings),
    );

    // Create a high-importance channel for heads-up
    final androidChannel = AndroidNotificationChannel(
        appSettingStore.oneSignalCallChannelId!, 'Call Notifications',
        description: 'Incoming call notifications',
        importance: Importance.high,
        playSound: true,
        sound: RawResourceAndroidNotificationSound('call_noti'));

    await _flutterLocalNotificationsPlugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(androidChannel);
  }

  /// Show local heads-up notification
  Future<void> showHeadsUpNotification(String title, String body) async {
    final androidDetails = AndroidNotificationDetails(
        appSettingStore.oneSignalCallChannelId!, 'Call Notifications',
        channelDescription: 'Incoming call notifications',
        importance: Importance.high,
        priority: Priority.high,
        playSound: true,
        sound: RawResourceAndroidNotificationSound('call_noti'));

    final notificationDetails = NotificationDetails(android: androidDetails);

    await _flutterLocalNotificationsPlugin.show(
      0, // Notification ID
      title,
      body,
      notificationDetails,
    );
  }

  /// Send push notifications via OneSignal
  Future<void> sendPushNotifications(String title, String content,
      {String? recevierUid,
      List<String>? receivierUids,
      String? id,
      String? image,
      String? receiverPlayerId,
      bool? isGrp = false,
      String? flow,
      List<String>? mPlayerIds}) async {
    String? channelId = !flow.isEmptyOrNull
        ? appSettingStore.oneSignalCallChannelId
        : appSettingStore.oneSignalChannelId;

    Map? req;
    var header = {
      HttpHeaders.authorizationHeader:
          'Basic ${appSettingStore.oneSignalRestApi}',
      HttpHeaders.contentTypeHeader: 'application/json; charset=utf-8',
      'Content-Type': 'application/json'
    };

    if (!recevierUid.isEmptyOrNull) {
      isGrp == true
          ? req = {
              'headings': {'en': title},
              'contents': {'en': content},
              'data': {
                'id': recevierUid.validate(),
                'isGrp': isGrp,
                'flow': flow
              },
              'big_picture':
                  image.validate().isNotEmpty ? image.validate() : '',
              'large_icon': image.validate().isNotEmpty ? image.validate() : '',
              'app_id': appSettingStore.oneSignalAppId,
              'android_channel_id': channelId,
              'include_player_ids':
                  mPlayerIds!.length >= 1 ? mPlayerIds : [recevierUid],
              'priority': 10,
              'android_priority': 10,
              'android_sound': 'call_noti',
              'small_icon': 'ic_stat_onesignal_default',
              'android_visibility': 1,
            }
          : await chatMessageService
              .getUserPlayerId(uid: recevierUid)
              .then((value) {
              req = {
                'headings': {'en': title},
                'contents': {'en': content},
                'data': {
                  'id': recevierUid.validate(),
                  'isGrp': isGrp,
                  'flow': flow
                },
                'big_picture':
                    image.validate().isNotEmpty ? image.validate() : '',
                'large_icon':
                    image.validate().isNotEmpty ? image.validate() : '',
                'app_id': appSettingStore.oneSignalAppId,
                'android_channel_id': channelId,
                'include_player_ids': isGrp == true
                    ? mPlayerIds
                    : [value.oneSignalPlayerId.validate()],
                'priority': 10,
                'android_priority': 10,
                'android_sound': 'call_noti',
                'small_icon': 'ic_stat_onesignal_default',
                'android_visibility': 1,
              };
            });
    } else {
      req = {
        'headings': {'en': title},
        'contents': {'en': content},
        'data': {'flow': flow},
        'big_picture': image.validate().isNotEmpty ? image.validate() : '',
        'large_icon': image.validate().isNotEmpty ? image.validate() : '',
        'app_id': appSettingStore.oneSignalAppId,
        'android_channel_id': channelId,
        'include_player_ids': isGrp == true && mPlayerIds!.length >= 1
            ? mPlayerIds
            : [receiverPlayerId],
        'priority': 10,
        'android_priority': 10,
        'android_sound': 'call_noti',
        'small_icon': 'ic_stat_onesignal_default',
        'android_visibility': 1,
      };
    }

    log('======Notification request $req');
    // Send OneSignal push
    Response res = await post(
      Uri.parse('https://onesignal.com/api/v1/notifications'),
      body: jsonEncode(req),
      headers: header,
    );

    // if (!flow.isEmptyOrNull && flow == "call") {
    //   showHeadsUpNotification(title, content);
    // }

    print("NOTIFY STATUS:${res.statusCode}");
    print("NOTIFY BODY:${res.body}");

    if (!res.statusCode.isSuccessful()) throw errorSomethingWentWrong;
  }
}
