import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:async/async.dart';

import 'package:chat/utils/TextStyles.dart' as TS;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:ffmpeg_kit_flutter_new/ffmpeg_kit.dart';
import 'package:ffmpeg_kit_flutter_new/ffmpeg_kit_config.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:location/location.dart';
import 'package:nb_utils/nb_utils.dart';
import 'package:onesignal_flutter/onesignal_flutter.dart';
import 'package:path_provider/path_provider.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:video_thumbnail/video_thumbnail.dart';
import 'package:chat/centralized_import.dart';

import 'package:crypto/crypto.dart';

Color getPrimaryColor() =>
    appStore.isDarkMode ? scaffoldSecondaryDark : primaryColor;

extension SExt on String {
  String get translate => appLocalizations!.translate(this);
}

Future<void> appLaunchUrl(String url, {bool forceWebView = false}) async {
  await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication)
      .catchError((e) {
    toast('Invalid URL: $url');
    return e;
  });
}

bool highlightLink({required String msg}) {
  if (checkIsUrl(msg: msg)) {
    return true;
  } else if (checkIsNumber(msg: msg)) {
    return true;
  }
  if (checkIsEmail(msg: msg)) {
    return true;
  }
  return false;
}

bool checkIsUrl({required String msg}) {
  try {
    bool _validURL = Uri.parse(msg).isAbsolute;
    return _validURL;
  } catch (e) {
    return false;
  }
}

bool checkIsNumber({required String msg}) {
  try {
    String pattern = r'(^(?:[+0]9)?[0-9]{10,12}$)';
    RegExp regExp = new RegExp(pattern);
    return regExp.hasMatch(msg);
  } catch (e) {
    return false;
  }
}

bool checkIsEmail({required String msg}) {
  try {
    return RegExp(
            r"^[a-zA-Z0-9.a-zA-Z0-9.!#$%&'*+-/=?^_`{|}~]+@[a-zA-Z0-9]+\.[a-zA-Z]+")
        .hasMatch(msg);
  } catch (e) {
    return false;
  }
}

/*List<TextSpan> buildMessageSpans(String message,BuildContext context) {
  final urlRegExp = RegExp(
    r'((https?:\/\/|www\.)[^\s]+)|(@\w+)|(----userId>([^<]+)<userId----)',
    caseSensitive: false,
  );

  final spans = <TextSpan>[];
  final matches = urlRegExp.allMatches(message);

  int currentIndex = 0;

  for (final match in matches) {
    if (match.start > currentIndex) {
      spans.add(TextSpan(
        text: message.substring(currentIndex, match.start),
        style: TextStyle(
          color: appStore.isDarkMode ? Colors.white : Colors.black,
        ),
      ));
    }

    final url = message.substring(match.start, match.end);

    spans.add(
      TextSpan(
        text: url,
        style: TextStyle(
          color: Colors.blueAccent,
          decoration: TextDecoration.underline,
        ),
        recognizer: TapGestureRecognizer()
          ..onTap = () async {
          if(url.contains("@")){
            print("--------112>>${url}");

            /* ChatScreen(
              userModelList[index],
              isArchive: false,
              isAdmin: false,
            ).launch(context);*/

            return;

          }
          final linkToOpen = url.startsWith('http') ? url : 'https://$url';
          launchUrl(Uri.parse(linkToOpen));
          },
      ),
    );

    currentIndex = match.end;
  }

  // Add remaining non-link text after last match
  if (currentIndex < message.length) {
    spans.add(TextSpan(
      text: message.substring(currentIndex),
      style: TextStyle(
        color: appStore.isDarkMode ? Colors.white : Colors.black,
      ),
    ));
  }

  return spans;
}*/

List<TextSpan> buildMessageSpans(
    String message, BuildContext context, String currantUserID) {
  final mentionRegExp = RegExp(r'(@.+?)\s*----userId>([^<]+)<userId----');
  final urlRegExp = RegExp(r'(https?:\/\/[^\s]+|www\.[^\s]+)');

  final spans = <TextSpan>[];
  int currentIndex = 0;

  final matches = <({RegExpMatch match, String type})>[
    for (final m in mentionRegExp.allMatches(message))
      (match: m, type: 'mention'),
    for (final m in urlRegExp.allMatches(message)) (match: m, type: 'url'),
  ]..sort((a, b) => a.match.start.compareTo(b.match.start));

  for (final m in matches) {
    final match = m.match;

    if (match.start > currentIndex) {
      spans.add(TextSpan(
        text: message.substring(currentIndex, match.start),
        style: TS.boldTextStyle(
          color: appStore.isDarkMode ? Colors.white : Colors.black,
        ),
      ));
    }

    if (m.type == 'mention') {
      final name = match.group(1) ?? '';
      final userId = match.group(2) ?? '';

      spans.add(
        TextSpan(
          text: name,
          style: TS.boldTextStyle(
            color: Colors.red,
            decoration: TextDecoration.underline,
          ),
          recognizer: TapGestureRecognizer()
            ..onTap = () async {
              print("-----------183>>${userId}");
              print("-----------184>>${currantUserID}");
              if (userId != currantUserID) {
                UserModel userModel =
                    await userService.getUserById(val: userId);
                ChatScreen(
                  userModel,
                  isArchive: false,
                  isAdmin: false,
                ).launch(context);
              }

              print("Clicked mention: $name → userId=$userId");
            },
        ),
      );
    } else if (m.type == 'url') {
      final url = match.group(0) ?? '';
      spans.add(
        TextSpan(
          text: url,
          style: TS.boldTextStyle(
            color: Colors.blueAccent,
            decoration: TextDecoration.underline,
          ),
          recognizer: TapGestureRecognizer()
            ..onTap = () {
              final linkToOpen = url.startsWith('http') ? url : 'https://$url';
              launchUrl(Uri.parse(linkToOpen));
            },
        ),
      );
    }

    currentIndex = match.end;
  }

  if (currentIndex < message.length) {
    print("---------314>>${message.substring(currentIndex)}");
    spans.add(TextSpan(
      text: message.substring(currentIndex),
      style: TS.primaryTextStyle(
        color: appStore.isDarkMode ? Colors.white : Colors.black,
      ),
    ));
  }

  return spans;
}

TextSpan buildMessageLastMsg(String message) {
  final mentionRegExp = RegExp(r'(@.+?)\s*----userId>([^<]+)<userId----');
  final urlRegExp = RegExp(r'(https?:\/\/[^\s]+|www\.[^\s]+)');

  final spans = <TextSpan>[];
  int currentIndex = 0;

  final matches = <({RegExpMatch match, String type})>[
    for (final m in mentionRegExp.allMatches(message))
      (match: m, type: 'mention'),
    for (final m in urlRegExp.allMatches(message)) (match: m, type: 'url'),
  ]..sort((a, b) => a.match.start.compareTo(b.match.start));

  for (final m in matches) {
    final match = m.match;

    if (match.start > currentIndex) {
      spans.add(TextSpan(
        text: message.substring(currentIndex, match.start),
        style: TS.boldTextStyle(
          color: appStore.isDarkMode ? Colors.white : Colors.black,
        ),
      ));
    }

    if (m.type == 'mention') {
      final name = match.group(1) ?? '';
      final userId = match.group(2) ?? '';

      spans.add(
        TextSpan(
            text: name,
            style: TS.boldTextStyle(
              color: Colors.red,
              decoration: TextDecoration.underline,
            ),
            recognizer: TapGestureRecognizer()),
      );
    } else if (m.type == 'url') {
      final url = match.group(0) ?? '';
      spans.add(
        TextSpan(
            text: url,
            style: TS.boldTextStyle(
              color: Colors.blueAccent,
              decoration: TextDecoration.underline,
            ),
            recognizer: TapGestureRecognizer()),
      );
    }

    currentIndex = match.end;
  }

  if (currentIndex < message.length) {
    spans.add(TextSpan(
      text: message.substring(currentIndex),
      style: TS.boldTextStyle(
        color: appStore.isDarkMode ? Colors.white : Colors.black,
      ),
    ));
  }

  return TextSpan(children: spans);
}

List<TextSpan> buildMessageStatus(
    String message, BuildContext context, String currantUserID) {
  final mentionRegExp = RegExp(r'(@.+?)\s*----userId>([^<]+)<userId----');
  final urlRegExp = RegExp(r'(https?:\/\/[^\s]+|www\.[^\s]+)');

  final spans = <TextSpan>[];
  int currentIndex = 0;

  final matches = <({RegExpMatch match, String type})>[
    for (final m in mentionRegExp.allMatches(message))
      (match: m, type: 'mention'),
    for (final m in urlRegExp.allMatches(message)) (match: m, type: 'url'),
  ]..sort((a, b) => a.match.start.compareTo(b.match.start));

  for (final m in matches) {
    final match = m.match;

    if (match.start > currentIndex) {
      spans.add(TextSpan(
        text: message.substring(currentIndex, match.start),
        style: TS.boldTextStyle(
          color: appStore.isDarkMode ? Colors.white : Colors.black,
        ),
      ));
    }

    if (m.type == 'mention') {
      final name = match.group(1) ?? '';
      final userId = match.group(2) ?? '';

      spans.add(
        TextSpan(
          text: name,
          style: TS.boldTextStyle(
            color: Colors.white,
            decoration: TextDecoration.underline,
          ),
          recognizer: TapGestureRecognizer()
            ..onTap = () async {
              if (userId != currantUserID) {
                UserModel userModel =
                    await userService.getUserById(val: userId);
                ChatScreen(
                  userModel,
                  isArchive: false,
                  isAdmin: false,
                ).launch(context);
              }
              print("Clicked mention: $name → userId=$userId");
            },
        ),
      );
    } else if (m.type == 'url') {
      final url = match.group(0) ?? '';
      spans.add(
        TextSpan(
          text: url,
          style: TS.boldTextStyle(
            color: Colors.white,
            decoration: TextDecoration.underline,
          ),
          recognizer: TapGestureRecognizer()
            ..onTap = () {
              final linkToOpen = url.startsWith('http') ? url : 'https://$url';
              launchUrl(Uri.parse(linkToOpen));
            },
        ),
      );
    }

    currentIndex = match.end;
  }

  if (currentIndex < message.length) {
    print("---------314>>${message.substring(currentIndex)}");
    spans.add(TextSpan(
      text: message.substring(currentIndex),
      style: TS.boldTextStyle(
        color: Colors.white,
      ),
    ));
  }

  return spans;
}

Future<XFile?> imageCompress({required String filepath}) async {
  try {
    Directory b = await getTemporaryDirectory();
    var result = await FlutterImageCompress.compressAndGetFile(
      filepath,
      b.path,
      quality: 100,
    );
    return result;
  } catch (e, s) {
    print("IMage Compress Error::${e}. =>$s");
    return null;
  }
}

bool get isRTL => rtlLanguage.contains(appStore.selectedLanguageCode);

InputDecoration inputDecoration(BuildContext context,
        {required String labelText, String? hintText, Widget? prefix}) =>
    InputDecoration(
      labelText: labelText,
      labelStyle: TS.secondaryTextStyle(),
      alignLabelWithHint: true,
      hintText: hintText,
      hintStyle: TS.primaryTextStyle(),
      isDense: true,
      suffixIconColor: context.iconColor,
      contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 14),
      prefixIcon: prefix,
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(defaultRadius),
        borderSide: BorderSide(color: Colors.red, width: 1.0),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(defaultRadius),
        borderSide: BorderSide(color: Colors.red, width: 1.0),
      ),
      errorMaxLines: 2,
      errorStyle: TS.primaryTextStyle(color: Colors.red, size: 12),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(defaultRadius),
        borderSide: BorderSide(width: 1.0, color: context.dividerColor),
      ),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(defaultRadius),
        borderSide: BorderSide(width: 1.0, color: context.dividerColor),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(defaultRadius),
        borderSide: BorderSide(color: context.dividerColor, width: 1.0),
      ),
      disabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(defaultRadius),
        borderSide: BorderSide(color: context.dividerColor, width: 1.0),
      ),
    );

List<String> setSearchParam(String caseNumber) {
  List<String> caseSearchList = [];
  String temp = "";
  for (int i = 0; i < caseNumber.length; i++) {
    temp = temp + caseNumber[i];
    caseSearchList.add(temp.toLowerCase());
  }
  return caseSearchList;
}

String getThemeModeString(int value) {
  if (value == 0) {
    return 'light_mode'.translate;
  } else if (value == 1) {
    return 'dark_mode'.translate;
  } else if (value == 2) {
    return 'system_default'.translate;
  }
  return '';
}

String getFontSizeString(int value) {
  if (value == 0) {
    return 'small'.translate;
  } else if (value == 1) {
    return 'medium'.translate;
  } else if (value == 2) {
    return 'large'.translate;
  }
  return '';
}

void appSetting() {
  // mChatFontSize = getIntAsync(FONT_SIZE_PREF, defaultValue: 16);
  mIsEnterKey = getBoolAsync(IS_ENTER_KEY, defaultValue: false);
  mSelectedImage = getStringAsync(SELECTED_WALLPAPER,
      defaultValue: "assets/default_wallpaper.png");
  appSettingStore.setReportCount(aReportCount: getIntAsync(reportCount));
}

void loginData() {
  loginStore.setPhotoUrl(aPhotoUrl: getStringAsync(userPhotoUrl));
  loginStore.setDisplayName(aDisplayName: getStringAsync(userDisplayName));
  loginStore.setEmail(aEmail: getStringAsync(userEmail));
  loginStore.setMobileNumber(aMobileNumber: getStringAsync(userMobileNumber));
  loginStore.setId(aId: getStringAsync(userId));
  loginStore.setIsEmailLogin(aIsEmailLogin: getBoolAsync(isEmailLogin));
  loginStore.setStatus(aStatus: getStringAsync(userStatus));
}

Future<void> oneSignalData() async {
  await Permissions.notificationPermissions();
  settingsService.getOneSignalSettings().then((value) {
    appSettingStore.oneSignalAppId = value.appId.validate();
    appSettingStore.oneSignalRestApi = value.restApiKey.validate();
    appSettingStore.oneSignalChannelId = value.channelId.validate();
    appSettingStore.oneSignalCallChannelId = value.callChannelId.validate();

    OneSignal.Debug.setLogLevel(OSLogLevel.verbose);
    OneSignal.Debug.setAlertLevel(OSLogLevel.none);

    OneSignal.consentRequired(false);

    OneSignal.Notifications.addPermissionObserver((state) {
      print("Has permission " + state.toString());
    });

    OneSignal.Notifications.requestPermission(true);

    OneSignal.initialize(value.appId.validate());

    OneSignal.Notifications.addForegroundWillDisplayListener((event) {
      print(
          'NOTIFICATION WILL DISPLAY LISTENER CALLED WITH: ${event.notification.jsonRepresentation()}');
      event.preventDefault();
      event.notification.display();
      chatMessageService.fetchForMessageCount(loginStore.mId);
    });

    OneSignal.User.pushSubscription.addObserver((state) async {
      print('-----------------227>>${OneSignal.User.pushSubscription.optedIn}');
      print('-----------------228>>${OneSignal.User.pushSubscription.id}');
      print('-----------------229>>${OneSignal.User.pushSubscription.token}');
      await setValue(playerId, OneSignal.User.pushSubscription.id);
      if (!OneSignal.User.pushSubscription.id.isEmptyOrNull)
        await setValue(playerId, OneSignal.User.pushSubscription.id.validate());
    });
    if (getBoolAsync(IS_LOGGED_IN)) {
      userService.updateDocument({
        'oneSignalPlayerId': getStringAsync(playerId).validate(),
        'updatedAt': Timestamp.now(),
      }, getStringAsync(userId)).then((value) {
        log("Updated");
      }).catchError((e) {
        log(e.toString());
      });
    }
    appStore.setLoading(false);
  });
  OneSignal.Notifications.addClickListener((notification) async {
    var notId = notification.notification.additionalData!["id"];
    bool isGrpId = notification.notification.additionalData!["isGrp"];
    if (notId != null && isGrpId != null) {
      if (isGrpId == true) {
        GroupChatScreen(groupChatId: notId, groupName: "").launch(getContext);
      } else {
        await userService.getUserById(val: notId!).then((value) {
          ChatScreen(
            value,
            isArchive: false,
          ).launch(getContext);
        });
      }
    }

    /*   final actionId = notification.result.actionId;
    final additionalData = notification.notification.additionalData;
    if (actionId == 'accept_call') {
      final callId = additionalData?['id'] as String?;
      final flow = additionalData?['flow'] as String?;
      if (flow == 'call' && callId != null) {
       // _joinCall(callId);
      }
    } else if (actionId == 'decline_call') {
     // _declineCall();
    }*/
  });
}

/*void showNotification() {
  AwesomeNotifications().createNotification(
    content: NotificationContent(
      id: 100,
      channelKey: 'basic_channel',
      title: '🎉 Hello from Awesome Notifications!',
      body: 'This notification was triggered by a button click.',
      notificationLayout: NotificationLayout.Default,
    ),
  );
}*/

getCallStatusIcon(String? callStatus) {
  Icon _icon;
  double _iconSize = 15;

  switch (callStatus) {
    case CALLED_STATUS_DIALLED:
      _icon = Icon(Icons.call_made, size: _iconSize, color: Colors.green);
      break;

    case CALLED_STATUS_MISSED:
      _icon = Icon(Icons.call_missed, size: _iconSize, color: Colors.red);
      break;

    default:
      _icon = Icon(Icons.call_received, size: _iconSize, color: Colors.grey);
      break;
  }

  return Container(margin: EdgeInsets.only(right: 5), child: _icon);
}

String formatDateString(String dateString) {
  DateTime dateTime = DateTime.parse(dateString);

  return dateTime.timeAgo;
}

copyMessageFun({required String msg}) async {
  await Clipboard.setData(ClipboardData(text: msg));
  toast("Message Copied to clipboard");
}

UserModel sender = UserModel(
  name: getStringAsync(userDisplayName),
  photoUrl: getStringAsync(userPhotoUrl),
  uid: getStringAsync(userId),
  oneSignalPlayerId: getStringAsync(playerId),
);

void unblockDialog(BuildContext context, {required UserModel receiver}) async {
  await showConfirmDialogCustom(
    context,
    dialogType: DialogType.CONFIRMATION,
    primaryColor: primaryColor,
    title: 'Unblock ${receiver.name} to send a message',
    dialogAnimation: DialogAnimation.SCALE,
    positiveText: "Unblock".translate.capitalizeFirstLetter(),
    negativeText: 'cancel'.translate.capitalizeFirstLetter(),
    onAccept: (v) async {
      List<DocumentReference> temp = [];

      temp = await userService
          .userByEmail(getStringAsync(userEmail))
          .then((value) => value.blockedTo!);

      if (temp.contains(
          userService.getUserReference(uid: receiver.uid.validate()))) {
        temp.removeWhere((element) =>
            element ==
            userService.getUserReference(uid: receiver.uid.validate()));
      }

      userService.unBlockUser({"blockedTo": temp}).then((value) {
        finish(context);
      }).catchError((e) {
        //
      });
    },
    // actions: [
    //   TextButton(
    //     onPressed: () {
    //       finish(context);
    //     },
    //     child: Text(
    //       "cancel".translate,
    //       style: TextStyle(color: secondaryColor),
    //     ),
    //   ),
    //   TextButton(
    //     onPressed: () async {
    //       List<DocumentReference> temp = [];
    //
    //       temp = await userService.userByEmail(getStringAsync(userEmail)).then((value) => value.blockedTo!);
    //
    //       if (temp.contains(userService.getUserReference(uid: receiver.uid.validate()))) {
    //         temp.removeWhere((element) => element == userService.getUserReference(uid: receiver.uid.validate()));
    //       }
    //
    //       userService.unBlockUser({"blockedTo": temp}).then((value) {
    //         finish(context);
    //         finish(context);
    //         finish(context);
    //       }).catchError((e) {
    //         //
    //       });
    //     },
    //     child: Text(
    //       "Unblock".toUpperCase(),
    //       style: TextStyle(color: secondaryColor),
    //     ),
    //   ),
    // ],
  );
}

videoThumbnailImage({String? path, double? width, double? height}) {
  AsyncMemoizer<Widget> _memoizer = AsyncMemoizer<Widget>();

  return FutureBuilder<Widget>(
      future: _memoizer.runOnce(
          () => getVideoThumb(path: path, width: width, height: height)),
      builder: (BuildContext context, AsyncSnapshot<Widget> snapshot) {
        if (snapshot.hasData) {
          return snapshot.data!; //get a red underline here
        } else {
          return cachedImage('', width: width, height: height.validate());
        }
      });
}

/*Widget videoThumbnailImage({String? path, double? width, double? height}) {
  return FutureBuilder<Widget>(
    future: getVideoThumb(path: path, width: width, height: height),
    builder: (BuildContext context, AsyncSnapshot<Widget> snapshot) {
      if (snapshot.connectionState == ConnectionState.done && snapshot.hasData) {
        return snapshot.data!;
      } else if (snapshot.hasError) {
        return Icon(Icons.broken_image, size: width ?? 50);
      } else {
        return Container(
          width: width,
          height: height,
          color: Colors.grey.shade200,
          child: Center(
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        );
      }
    },
  );
}*/

Future<Widget> getVideoThumb(
    {String? path, double? width, double? height}) async {
  if (path == null || path.isEmpty) {
    return Icon(Icons.videocam_off, size: width ?? 50);
  }

  final uint8list = await VideoThumbnail.thumbnailData(
    video: path,
    imageFormat: ImageFormat.PNG,
    maxWidth: width?.toInt() ?? 250,
    quality: 75,
  );

  if (uint8list != null) {
    return Image.memory(
      uint8list,
      width: width,
      height: height,
      fit: BoxFit.cover,
    );
  } else {
    return Icon(Icons.videocam_off, size: width ?? 50);
  }
}

Widget noProfileImageFound(
    {double? height,
    double? width,
    bool isNoRadius = false,
    bool isGroup = false}) {
  return Image.asset(isGroup ? 'assets/group_user.jpg' : 'assets/user.jpg',
          height: height, width: width, fit: BoxFit.cover)
      .cornerRadiusWithClipRRect(isNoRadius ? 0 : height! / 2);
}

Future<bool> setupLocation() async {
  Location? location;
  location = Location();

  var _serviceEnabled = await location.serviceEnabled();

  if (!_serviceEnabled) {
    _serviceEnabled = await location.requestService();

    if (!_serviceEnabled) {
      return false;
    }
  }

  var _permissionGranted = await location.hasPermission();

  if (_permissionGranted == PermissionStatus.denied) {
    _permissionGranted = await location.requestPermission();

    if (_permissionGranted != PermissionStatus.granted) {
      return false;
    }
  }

  return true;
}

Future<Position?> determinePosition() async {
  LocationPermission permission;
  permission = await Geolocator.checkPermission();
  if (permission == LocationPermission.denied) {
    permission = await Geolocator.requestPermission();
    if (permission == LocationPermission.deniedForever) {
      return Future.error('Location Not Available');
    }
  } else {
    //throw Exception('Error');
  }
  return await Geolocator.getCurrentPosition();
}

Future<bool> checkPermission() async {
  // Request app level location permission
  LocationPermission locationPermission = await Geolocator.requestPermission();

  if (locationPermission == LocationPermission.whileInUse ||
      locationPermission == LocationPermission.always) {
    // Check system level location permission
    if (!await Geolocator.isLocationServiceEnabled()) {
      return await Geolocator.openLocationSettings()
          .then((value) => false)
          .catchError((e) => false);
    } else {
      return true;
    }
  } else {
    toast('Please enable your device location');
    await Geolocator.openAppSettings();

    return false;
  }
}

// ignore: body_might_complete_normally_nullable
InterstitialAd? buildInterstitialAd() {
  print("------------520>>${appSettingStore.adMobInterstitialAd.validate()}");
  InterstitialAd.load(
    adUnitId: isAndroid
        ? appSettingStore.adMobInterstitialAd.validate()
        : appSettingStore.adMobInterstitialIos.validate(),
    request: AdRequest(),
    adLoadCallback:
        InterstitialAdLoadCallback(onAdFailedToLoad: (LoadAdError error) {
      print("-----------524>>${error.message}");
      throw error.message;
    }, onAdLoaded: (InterstitialAd ad) {
      ad.show();
    }),
  );
}

backgroundImage() {
  return Container(
    decoration: getIntAsync(SELECTED_WALLPAPER_CATEGORY) == 3
        ? BoxDecoration(
            image: DecorationImage(
              colorFilter: ColorFilter.mode(
                  Color(int.parse(mSelectedImage.substring(1, 7), radix: 16) +
                      0xFF000000),
                  BlendMode.color),
              fit: BoxFit.cover,
              image: Image.asset(ic_solid_wallpaper).image,
            ),
          )
        : BoxDecoration(
            image: DecorationImage(
              image: getIntAsync(SELECTED_WALLPAPER_CATEGORY) == 0
                  ? Image.asset(mSelectedImage).image
                  : Image.network(mSelectedImage).image,
              fit: BoxFit.cover,
              colorFilter: appStore.isDarkMode
                  ? ColorFilter.mode(Colors.black54, BlendMode.luminosity)
                  : null,
            ),
          ),
  );
}

void showReactionBottomSheet(BuildContext context, List<ReactionModel>? list) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (BuildContext context) {
      double itemHeight = 70;
      int itemCount = list?.length ?? 0;
      double maxHeight = MediaQuery.of(context).size.height * 0.6;
      double calculatedHeight =
          (itemCount * itemHeight) + 80; // 80 for handle + padding
      double finalHeight =
          calculatedHeight > maxHeight ? maxHeight : calculatedHeight;
      return Container(
        height: finalHeight,
        width: double.infinity,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
        ),
        child: Column(
          children: [
            Container(
              width: 50,
              height: 5,
              margin: const EdgeInsets.symmetric(vertical: 8),
              decoration: BoxDecoration(
                color: Colors.grey[400],
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            list?.isNotEmpty == true
                ? Expanded(
                    child: ListView.builder(
                      itemCount: list?.length,
                      itemBuilder: (context, index) {
                        return ListTile(
                          trailing: Text(list?[index].reaction ?? '',
                              style: TS.secondaryTextStyle(size: 18)),
                          leading: Container(
                            height: 45,
                            width: 45,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: primaryColor.withOpacity(0.5),
                                width: 1,
                              ),
                            ),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(45),
                              child:
                                  !(list?[index].image.isEmptyOrNull ?? false)
                                      ? Image.network(
                                          list?[index].image ?? '',
                                          fit: BoxFit.cover,
                                          errorBuilder: (_, __, ___) {
                                            return noProfileImageFound(
                                                height: 45, width: 45);
                                          },
                                        ).cornerRadiusWithClipRRect(45)
                                      : Container(
                                          color: getColorFromString(
                                              list?[index].uid ?? ''),
                                          child: Text(
                                                  list?[index]
                                                          .userName
                                                          .validate()[0]
                                                          .toUpperCase() ??
                                                      '',
                                                  style: TS.secondaryTextStyle(
                                                      color: Colors.white))
                                              .center()
                                              .fit(),
                                        ),
                            ),
                          ),
                          title: Text(list?[index].userName ?? '',
                              style:
                                  TS.secondaryTextStyle(color: Colors.black)),
                          onTap: () {
                            Navigator.pop(context); // Close bottom sheet
                          },
                        );
                      },
                    ),
                  )
                : Center(
                    child:
                        Text('emptyView'.translate, style: TS.boldTextStyle())),
          ],
        ),
      );
    },
  );
}

String getFileNameFromUrl(String url) {
  // Remove query parameters like ?alt=media&token=...
  String cleanUrl = url.split('?').first;

  // Decode URL-encoded characters (%2F -> /)
  cleanUrl = Uri.decodeFull(cleanUrl);

  // Get only the last segment after the last slash
  return cleanUrl.split('/').last;
}

Color getColorFromString(String input) {
  final hash = input.codeUnits.fold(0, (prev, elem) => prev + elem);
  final colors = [
    lightIndigo,
    cyanLight,
    tealLight,
    greenLight,
    limeLight,
    lemonYellow,
    orangeLight,
    brownGrey,
    blueGreyLight,
    orangeDarkLight,
    blueLightLight,
    lavenderTone,
    lightBlueTone
  ];
  return colors[hash % colors.length];
}

String generateNonceData([int length = 32]) {
  const charset =
      '0123456789ABCDEFGHIJKLMNOPQRSTUVXYZabcdefghijklmnopqrstuvwxyz-._';
  final random = Random.secure();
  return List.generate(length, (_) => charset[random.nextInt(charset.length)])
      .join();
}

String sha256ofString(String input) {
  final bytes = utf8.encode(input);
  final digest = sha256.convert(bytes);
  return digest.toString();
}

Future<void> pickAndSendVideos(
  UserModel? receiverUser,
  BuildContext context,
  Function(File file, String text) onActionDone,
) async {
  FilePickerResult? result = await FilePicker.platform.pickFiles(
    type: FileType.video,
    allowMultiple: true,
    allowCompression: true,
    compressionQuality: 100,
  );
  if (result == null) return;

  final files = result.paths
      .where((path) => path != null)
      .map((path) => File(path!))
      .toList();

  List<String>? texts = await MultipleSelectedAttachmentText(
    attachedFiles: files,
    userModel: receiverUser,
    isVideo: true,
  ).launch(context);
  if (Navigator.canPop(context)) {
    Navigator.of(context, rootNavigator: true).pop();
  }
  if (texts != null) {
    print("Inside If Texts => ${texts}");
    for (int i = 0; i < files.length; i++) {
      onActionDone(files[i], texts[i]);
    }
  }
}

Future<File?> compressVideo(File inputFile, {int maxSizeMB = 8}) async {
  final tempDir = await getTemporaryDirectory();
  final outputPath =
      '${tempDir.path}/${DateTime.now().millisecondsSinceEpoch}_compressed.mp4';

  double videoDurationMs = 0;

  // Step 1: Get video duration
  try {
    await FFmpegKit.execute('-i "${inputFile.path}" -f null -')
        .then((session) async {
      final logs = await session.getLogs();
      for (var log in logs) {
        final logText = log.getMessage();
        final durationRegex =
            RegExp(r'Duration: (\d{2}):(\d{2}):(\d{2})\.(\d{2})');
        final match = durationRegex.firstMatch(logText);
        if (match != null) {
          final hours = int.parse(match.group(1)!);
          final minutes = int.parse(match.group(2)!);
          final seconds = int.parse(match.group(3)!);
          final centiseconds = int.parse(match.group(4)!);
          videoDurationMs = ((hours * 3600 + minutes * 60 + seconds) * 1000 +
                  centiseconds * 10)
              .toDouble();
          break;
        }
      }
    });
  } catch (e) {
    print('Could not determine video duration: $e');
  }

  // Step 2: Track compression progress (optional)
  FFmpegKitConfig.enableStatisticsCallback((stats) {
    double timeInMs = stats.getTime().toDouble();
    double progress = videoDurationMs > 0
        ? (timeInMs / videoDurationMs)
        : (timeInMs / 120000).clamp(0.0, 0.95);
    print('Compression progress: ${(progress * 100).toStringAsFixed(1)}%');
  });

  // Step 3: Execute compression
  await FFmpegKit.executeAsync(
    '-i "${inputFile.path}" -vf scale=720:-2 -vcodec libx264 -preset veryslow -crf 35 "$outputPath"',
    (session) async {
      FFmpegKitConfig.enableStatisticsCallback(null);
    },
  );

  // Step 4: Verify compressed file
  final compressedFile = File(outputPath);
  if (!compressedFile.existsSync()) {
    print('Compression failed.');
    return null;
  }

  final sizeMB = compressedFile.lengthSync() / (1024 * 1024);
  print(
      'Original: ${(inputFile.lengthSync() / 1024 / 1024).toStringAsFixed(2)} MB');
  print('Compressed: ${sizeMB.toStringAsFixed(2)} MB');

  if (sizeMB > maxSizeMB) {
    await compressedFile.delete();
    print('Compressed file exceeds $maxSizeMB MB, deleted.');
    return null;
  }

  return compressedFile;
}
