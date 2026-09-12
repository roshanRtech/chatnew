import 'dart:async';

import 'package:chat/services/DeviceService.dart';
import 'package:chat/services/StickerService.dart';
import 'package:chat/services/WallpaperService.dart';
import 'package:chat/services/localDB/LogRepository.dart';
import 'package:chat/services/settingService.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:country_code_picker/country_code_picker.dart';
import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_mobx/flutter_mobx.dart';
import 'package:nb_utils/nb_utils.dart';
import 'package:onesignal_flutter/onesignal_flutter.dart';
import 'package:sqflite/sqflite.dart';
import 'package:app_links/app_links.dart';

import '../../models/FileModel.dart';
import '../../models/Language.dart';
import '../../screens/SplashScreen.dart';
import '../../services/AuthService.dart';
import '../../services/CallService.dart';
import '../../services/ChatMessageService.dart';
import '../../services/ChatRequestService.dart';
import '../../services/GroupChatMessageService.dart';
import '../../services/NotificationService.dart';
import '../../services/StoryService.dart';
import '../../services/UserService.dart';
import '../../store/AppSettingStore.dart';
import '../../store/AppStore.dart';
import '../../store/LoginStore.dart';
import '../../store/MessageRequestStore.dart';
import '../../utils/AppColors.dart';
import '../../utils/AppCommon.dart';
import '../../utils/AppConstants.dart';
import '../../utils/AppLocalizations.dart';
import '../../utils/AppTheme.dart';
import 'components/NoInternetScreen.dart';

List<String>? groupIds;

//region Services Objects
UserService userService = UserService();
AuthService authService = AuthService();
DeviceService deviceService = DeviceService();
ChatMessageService chatMessageService = ChatMessageService();
CallService callService = CallService();
NotificationService notificationService = NotificationService();
StoryService storyService = StoryService();
ChatRequestService chatRequestService = ChatRequestService();
WallpaperService wallpaperService = WallpaperService();
StickerService stickerService = StickerService();
GroupChatMessageService groupChatMessageService = GroupChatMessageService();
SettingsService settingsService = SettingsService();

final appLinks = AppLinks();

//endregion
final navigatorKey = GlobalKey<NavigatorState>();
String? groupIdRedirection;
String? groupNameRedirection;
String? userPhoneNumber;

String pathToRingingTone = "";
int RingingToneSoundId = 1;

get getContext1 => navigatorKey.currentState?.overlay?.context;

FirebaseFirestore fireStore = FirebaseFirestore.instance;
late AppLocalizations? appLocalizations;
late Language? language;
List<Language> languages = Language.getLanguages();
late List<FileModel> fileList = [];
OneSignal oneSignal = OneSignal();
//AudioPlayer? instance = AudioPlayer();
//region MobX Objects
AppStore appStore = AppStore();
LoginStore loginStore = LoginStore();
AppSettingStore appSettingStore = AppSettingStore();
MessageRequestStore messageRequestStore = MessageRequestStore();
//endregion

late MessageType? messageType;

ValueNotifier<String> searchNotifier = ValueNotifier<String>('');

//region Default Settings
int mChatFontSize = 16;
int mAdShowCount = 0;

String mSelectedImage =
    appStore.isDarkMode ? mSelectedImageDark : "assets/default_wallpaper.png";
String mSelectedImageDark = "assets/default_wallpaper_dark.jpg";

bool mIsEnterKey = false;
List<String?> postViewedList = [];
List<String?> listOfMyConnectedContacts = [];

Database? localDbInstance;
Color defaultLoaderAccentColorGlobal = primaryColor;
//endregion

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  await settingsService.getSettings().then((value) {
    appSettingStore.secretKey = value.secretKey.validate();
    appSettingStore.publishableKey = value.publishableKey.validate();
  });

  await FirebaseAppCheck.instance.activate(
    androidProvider: AndroidProvider.playIntegrity,
    appleProvider: AppleProvider.appAttest,
  );

  Function? originalOnError = FlutterError.onError;

  FlutterError.onError = (FlutterErrorDetails errorDetails) async {
    await FirebaseCrashlytics.instance.recordFlutterError(errorDetails);
    originalOnError!(errorDetails);
  };
  await initialize();

  appSetting();

  appButtonBackgroundColorGlobal = primaryColor;
  defaultAppButtonTextColorGlobal = Colors.white;
  appBarBackgroundColorGlobal = primaryColor;
  defaultLoaderBgColorGlobal = chatColor;
  appStore.setLanguage(getStringAsync(LANGUAGE, defaultValue: defaultLanguage));

  int themeModeIndex = getIntAsync(THEME_MODE_INDEX);
  int statusPrivacyIndex = getIntAsync(STATUS_PRIVACY_INDEX);

  if (themeModeIndex == ThemeModeLight) {
    appStore.setDarkMode(false);
  } else if (themeModeIndex == ThemeModeDark) {
    appStore.setDarkMode(true);
  }

  if (statusPrivacyIndex == StatusPrivacyMyContacts) {
    appStore.setStatusPrivacy(false);
  } else if (statusPrivacyIndex == StatusPrivacyMyContactsExcept) {
    appStore.setStatusPrivacy(true);
  }

  if (getBoolAsync(IS_LOGGED_IN)) {
    loginData();
  }
  oneSignalData();
  runApp(MyApp());
}

class MyApp extends StatefulWidget {
  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  late StreamSubscription<List<ConnectivityResult>> _connectivitySubscription;

  bool isCurrentlyOnNoInternet = false;
  ConnectivityResult connectionStatus = ConnectivityResult.none;
  final Connectivity connectivity = Connectivity();

  @override
  void initState() {
    super.initState();
    afterBuildCreated(() {
      _connectivitySubscription = Connectivity()
          .onConnectivityChanged
          .listen((List<ConnectivityResult> results) {
        _handleConnectivityChange(results.first);
      });
    });
  }

  void _handleConnectivityChange(ConnectivityResult result) {
    if (result == ConnectivityResult.none) {
      log('Not connected');
      if (!isCurrentlyOnNoInternet) {
        isCurrentlyOnNoInternet = true;
        NoInternetScreen().launch(context);
        // Navigator.of(context).push(buildPageRoute(NoInternetScreen(), pageRouteAnimationGlobal, Duration(seconds: 1)));
      }
    } else {
      if (isCurrentlyOnNoInternet) {
        Navigator.of(context).pop();
        isCurrentlyOnNoInternet = false;
        toast('Internet is connected.');
      }
    }
  }

  @override
  void setState(fn) {
    if (mounted) super.setState(fn);
    _connectivitySubscription.cancel();
  }

  @override
  void dispose() {
    super.dispose();
    _connectivitySubscription.cancel();
  }

  @override
  Widget build(BuildContext context) {
    return Observer(
      builder: (_) => MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: AppTheme.lightTheme,
        navigatorKey: navigatorKey,
        darkTheme: AppTheme.darkTheme,
        themeMode: appStore.isDarkMode ? ThemeMode.dark : ThemeMode.light,
        supportedLocales: Language.languagesLocale(),
        localizationsDelegates: [
          AppLocalizations.delegate,
          CountryLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
        ],
        localeResolutionCallback: (locale, supportedLocales) => locale,
        locale: Locale(appStore.selectedLanguageCode),
        home: SplashScreen(),
        builder: (context, child) {
          return ScrollConfiguration(
            behavior: SBehavior(),
            child: SafeArea(
              top: false,
              child: child!,
            ),
          );
        },
      ),
    );
  }
}
