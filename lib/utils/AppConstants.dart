//region start region
import 'package:chat/utils/Appwidgets.dart';
import 'package:flutter/material.dart';
import 'package:nb_utils/nb_utils.dart';

import 'AppCommon.dart';

const AppName = 'Mighty Chat';
//endregion

//region agora call key
// Pass via --dart-define=AGORA_APP_ID=your_key at build time or fetch from secure backend
const agoraVideoCallId = String.fromEnvironment('AGORA_APP_ID', defaultValue: "");
//endregion

//region firebase app id
const mFirebaseAppId = String.fromEnvironment('FIREBASE_STORAGE_BUCKET', defaultValue: 'mighty-chat-app.appspot.com');
const mAppIconUrl =
    'https://firebasestorage.googleapis.com/v0/b/$mFirebaseAppId/o/app_icon.png?alt=media';
//endregion

//region Notification
// Do NOT hardcode master REST keys into mobile/web client code! REST notifications must be dispatched by a secure backend function.
const mOneSignalAppId = String.fromEnvironment('ONESIGNAL_APP_ID', defaultValue: "");
const mOneSignalRestKey = String.fromEnvironment('ONESIGNAL_REST_KEY', defaultValue: "");
const mOneSignalChannelId = String.fromEnvironment('ONESIGNAL_CHANNEL_ID', defaultValue: "");
//endregion

//region AdMobIntegration
// Use standard Google test ad IDs as defaults; production ad unit IDs should be provided via environment configs
const mAdMobAppId = String.fromEnvironment('ADMOB_APP_ID', defaultValue: "ca-app-pub-3940256099942544~3347511713");
const mAdMobBannerId = String.fromEnvironment('ADMOB_BANNER_ID', defaultValue: "ca-app-pub-3940256099942544/6300978111");
const mAdMobInterstitialId = String.fromEnvironment('ADMOB_INTERSTITIAL_ID', defaultValue: "ca-app-pub-3940256099942544/1033173712");
//endregion

//region copyright
const copyRight = 'Meet Mighty';
//endregion

//region country code
const defaultCountry = 'IN';
const defaultCountryCode = '+91';
const defaultLanguage = 'en';
//endregion

//region AppUrls
const termsAndConditionURL =
    'https://meetmighty.com/codecanyon/document/mightychat/#mm-help-support';
const privacyPolicy = 'https://support.meetmighty.com/page/privacy-policy';
const supportURL = 'https://support.meetmighty.com/';
const mailto = 'app.meetmighty@gmail.com';
//endregion

List<String> rtlLanguage = ['ar', 'ur'];

const SEARCH_KEY = "Search";
const SEARCH_KEY_FORWARD = "SearchForward";

const LANGUAGE = "LANGUAGE";
const SELECTED_LANGUAGE = "SELECTED_LANGUAGE";

enum MessageType {
  TEXT,
  IMAGE,
  VIDEO,
  AUDIO,
  STICKER,
  DOC,
  LOCATION,
  VOICE_NOTE,
  MUL_IMAGE,
  SHAREPROFILE
}

const TEXT = "TEXT";
const IMAGE = "IMAGE";
const VIDEO = "VIDEO";
const AUDIO = "AUDIO";
const DOC = "DOC";
const STICKER = "STICKER";
const SHAREPROFILE = "SHAREPROFILE";
const LOCATION = "LOCATION";
const VOICE_NOTE = "VOICE_NOTE";

const MUL_IMAGE = "MUL_IMAGE";

extension MessageExtension on MessageType {
  String? get name {
    switch (this) {
      case MessageType.TEXT:
        return 'TEXT';
      case MessageType.IMAGE:
        return 'IMAGE';
      case MessageType.VIDEO:
        return 'VIDEO';
      case MessageType.AUDIO:
        return 'AUDIO';
      case MessageType.LOCATION:
        return 'LOCATION';
      case MessageType.DOC:
        return 'DOC';
      case MessageType.STICKER:
        return 'STICKER';
      case MessageType.VOICE_NOTE:
        return 'VOICE_NOTE';
      case MessageType.MUL_IMAGE:
        return 'MUL_IMAGE';
      default:
        return null;
    }
  }
}

Icon getIconForMessageType(String messageType) {
  switch (messageType) {
    case 'IMAGE':
      return Icon(Icons.image_outlined, color: Colors.grey, size: 14);
    case 'VIDEO':
      return Icon(Icons.videocam_outlined, color: Colors.grey, size: 14);
    case 'AUDIO':
      return Icon(Icons.headset_outlined, color: Colors.grey, size: 14);
    case 'LOCATION':
      return Icon(Icons.location_on_outlined, color: Colors.grey, size: 14);
    case 'DOC':
      return Icon(Icons.description, color: Colors.grey, size: 14);
    case 'VOICE_NOTE':
      return Icon(Icons.mic_none_outlined, color: Colors.grey, size: 14);
    case 'MUL_IMAGE':
      return Icon(Icons.image_outlined, color: Colors.grey, size: 14);
    default:
      return Icon(Icons.error, color: Colors.transparent, size: 14);
  }
}

Widget getViewForMessageType(String messageType, String url) {
  print("----------125>>${messageType}");
  switch (messageType) {
    case 'IMAGE':
      return cachedImage(url, fit: BoxFit.cover, width: 55, height: 55);
    case 'VIDEO':
      return videoThumbnailImage(path: url.validate(), height: 40, width: 40);
    case 'AUDIO':
      return Icon(Icons.headset_outlined, color: Colors.grey, size: 14);
    case 'LOCATION':
      return Icon(Icons.location_on_outlined, color: Colors.grey, size: 14);
    case 'DOC':
      return Icon(Icons.description, color: Colors.grey, size: 14);
    case 'VOICE_NOTE':
      return Icon(Icons.mic_none_outlined, color: Colors.grey, size: 14);
    case 'MUL_IMAGE':
      return cachedImage(url, fit: BoxFit.cover, width: 20, height: 20);
    default:
      return Icon(Icons.error, color: Colors.transparent, size: 14);
  }
}

const EXCEPTION_NO_USER_FOUND = "EXCEPTION_NO_USER_FOUND";

//FireBase Collection Name
const MESSAGES_COLLECTION = "messages";
const LAST_MESSAGE_COLLECTION = "lastMessages";
const USER_COLLECTION = "users";
const CONTACT_COLLECTION = "contact";
const CURRANT_USER_ARCHIVED = "currant_user_archived";
const STORY_COLLECTION = 'story';
const CHAT_REQUEST = 'chatRequest';
const ARCHIVE_MESSAGE = 'archive';
const MY_CONTACTS_COLLECTION = 'myContacts';
const ADMIN = 'admin';
//const GROUP_COLLECTION = 'groups';
const GROUPS_COLLECTION = 'group';
const GROUP_CHATS = 'chats';
const GROUP_GROUPCHATS = 'groupChats';
const DEVICE_COLLECTION = 'device';
const WALLPAPER = 'Wallpaper';
const STICKER_COLLECTION = 'Sticker';
const SETTING = 'Setting';
const HIDESHOWNODE = 'subscriptionFlag';

const USER_PROFILE_IMAGE = "userProfileImage";
const CHAT_DATA_IMAGES = "chatImages";
const STORY_DATA_IMAGES = "storyImages";
const GROUP_PROFILE_IMAGE = "groupProfileImage";
const GROUP_PROFILE_IMAGES = "groupChatImages";
const ADD_REMOVE_GROUP = "ADD_REMOVE_GROUP";
const CURRENT_LOCATION = "current_location";

// Call Status For Call Logs
const CALLED_STATUS_DIALLED = "dialled";
const CALLED_STATUS_RECEIVED = "received";
const CALLED_STATUS_MISSED = "missed";

/* Theme Mode Type */
const ThemeModeLight = 0;
const ThemeModeDark = 1;
const ThemeModeSystem = 2;

//Default Font Size
const FONT_SIZE_SMALL = 12.0;
const FONT_SIZE_MEDIUM = 16.0;
const FONT_SIZE_LARGE = 20.0;

const chatMsgRadius = 12.0;
//Pagination Setting
const PER_PAGE_CHAT_COUNT = 50;

//region SharePreference Key
const IS_LOGGED_IN = 'IS_LOGGED_IN';
const userId = 'userId';
const userDisplayName = 'userDisplayName';
const userEmail = 'userEmail';
const userPhotoUrl = 'userPhotoUrl';
const isEmailLogin = "isEmailLogin";
const isCountryCode = "isCountryCode";
const userStatus = "userStatus";
const userMobileNumber = "userMobileNumber";
const playerId = "playerId";
const reportCount = "reportCount";
const selectedMember = "selectedMember";
const selectedGroup = "selectedGroup";
const isSocialLogin = "isSocialLogin";
const CURRENT_GROUP_ID = "current_group_chat_id";
const isRemember = "isRemember";
const userPassword = 'userPassword';
//endregion

//region DefaultSettingConstant
const FONT_SIZE_INDEX = "FONT_SIZE_INDEX";
const FONT_SIZE_PREF = "FONT_SIZE_PREF";
const IS_ENTER_KEY = "IS_ENTER_KEY";
const SELECTED_WALLPAPER = "SELECTED_WALLPAPER";
const SELECTED_WALLPAPER_CATEGORY = "SELECTED_WALLPAPER_CATEGORY";
//endregion

//region message type
const TYPE_AUDIO = "audio";
const TYPE_MUL_IMAGE = "mul_image";
const TYPE_VIDEO = "video";
const TYPE_Image = "image";
const TYPE_DOC = "doc";
const TYPE_LOCATION = "current_location";
const TYPE_VOICE_NOTE = "voice_note";
const TYPE_STICKER = "sticker";
const STORY_REPLY = "STORY_REPLY";
//endregion

//region status privacy
const StatusPrivacyMyContacts = 0;
const StatusPrivacyMyContactsExcept = 1;
const StatusPrivacyOnlyShareWith = 2;
//endregion

const EXCLUDED = "excluded";
const INCLUDED = "included";
const String STATUS_PRIVACY_INDEX = 'status_privacy_index';
const String EXCLUDED_LIST_KEY = 'excluded_list';
const String INCLUDED_LIST_KEY = 'included_list';

const CALL_TYPE_GROUP_VIDEO_CALL = "group_video_call";
const CALL_TYPE_GROUP_AUDIO_CALL = "group_audio_call";

const CHAT_WEB_DOAMAIN_URL = "mighty-chat-app.web.app/";
