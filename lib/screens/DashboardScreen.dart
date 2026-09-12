import 'dart:async';
import 'dart:io';
import 'dart:ui';

import 'package:app_links/app_links.dart';
import 'package:chat/screens/OptimizedChatListScreen.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:nb_utils/nb_utils.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'package:receive_sharing_intent/receive_sharing_intent.dart';
import 'package:chat/centralized_import.dart';

import '../../utils/TextStyles.dart' as TS;

bool isSearch = false;
bool subFlag = false;

class DashboardScreen extends StatefulWidget {
  final int? initialTabIndex;

  DashboardScreen({this.initialTabIndex});

  @override
  _DashboardScreenState createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen>
    with SingleTickerProviderStateMixin {
  TabController? tabController;
  TextEditingController searchCont = TextEditingController();
  BannerAd? myBanner;
  FocusNode searchFocus = FocusNode();
  int tabIndex = 0;
  bool autoFocus = false;
  bool isBannerReady = false;

  StreamSubscription<Uri>? _linkSubscription;
  StreamSubscription? _intentSub;
  List<SharedMediaFile> _sharedFiles = [];

  Timer? _searchDebounce;

  final List<Widget> _screens = [
    OptimizedChatListScreen(),
    StoriesScreen(),
    CallLogScreen(),
  ];

  @override
  void initState() {
    super.initState();
    tabIndex = widget.initialTabIndex ?? 0;
    tabController =
        TabController(vsync: this, initialIndex: tabIndex, length: 3);
    init();
    initBanner();
    getRingtonePath();
    getAllConnectedContacts();
    getUserDetails();
    Future.delayed(Duration(seconds: 2), () {
      handleIncomingData();
    });
  }

  Future<void> getAllConnectedContacts() async {
    listOfMyConnectedContacts = await getAllContactUids(loginStore.mId ?? "");
  }

  getUserDetails() async {
    UserModel u =
        await ChatMessageService().getUserById(uid: getStringAsync(userId));
    AuthService().setUserDetailPreference(u);
    loginStore.setCurrentUser(u);
  }

  Future<List<String>> getAllContactUids(String userId) async {
    final contactSnapshots = await FirebaseFirestore.instance
        .collection(USER_COLLECTION)
        .doc(userId)
        .collection(CONTACT_COLLECTION)
        .get();

    List<String> uidList = contactSnapshots.docs
        .map((doc) => doc.data()['uid'] as String?)
        .whereType<String>()
        .toList();
    return uidList;
  }

  Future<void> getRingtonePath() async {
    final ByteData data = await rootBundle.load('assets/callingtone.mp3');
    final directory = await getTemporaryDirectory();
    final file = File('${directory.path}/callingtone.mp3');
    await file.writeAsBytes(data.buffer.asUint8List());
    pathToRingingTone = file.path;
  }

  openUserChatSharedLink() async {
    try {
      UserModel userModel =
          await userService.getUserByPhoneNumber(phoneNumber: userPhoneNumber);
      print("----------72>>${userModel}");
      await ChatScreen(
        userModel,
        isArchive: false,
        isAdmin: false,
      ).launch(context);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString())),
      );
    }
  }

  initBanner() async {
    myBanner = buildBannerAd()..load();
    print("USERID IS ==>" + getStringAsync(userId).toString());
  }

  BannerAd buildBannerAd() {
    return BannerAd(
      adUnitId: isAndroid
          ? appSettingStore.adMobBannerAd!
          : appSettingStore.adMobBannerIos!,
      size: AdSize.fullBanner,
      listener: BannerAdListener(
        onAdLoaded: (ad) {
          setState(() => isBannerReady = true);
        },
        onAdFailedToLoad: (Ad ad, LoadAdError error) {
          print('BannerAd failedToLoad: $error');
          setState(() {
            isBannerReady = false;
          });
          myBanner?.dispose();
          myBanner = null;
        },
      ),
      request: AdRequest(),
    );
  }

  init() async {
    afterBuildCreated(() {
      chatMessageService.fetchForMessageCount(loginStore.mId);
      setState(() {});
    });

    settingsService.getAdmobSettings().then((value) {
      appSettingStore.adMobBannerAd = value.adMobBannerAd.validate();
      appSettingStore.adMobInterstitialAd =
          value.adMobInterstitialAd.validate();
      appSettingStore.adMobBannerIos = value.adMobBannerIos.validate();
      appSettingStore.adMobInterstitialIos =
          value.adMobInterstitialIos.validate();
      appStore.setLoading(false);
    });
    settingsService.getSettings().then((value) {
      appSettingStore.agoraCallId = value.agoraCallId.validate();
      appSettingStore.termsCond = value.termsCondition.validate();
      appSettingStore.privacyPolicy = value.privacyPolicy.validate();
      appSettingStore.couponCode = value.couponCode.validate();
      appSettingStore.copyRight = value.copyRightText.validate();
      appStore.setLoading(false);
    });
    tabController!.addListener(() {
      setState(() {
        isSearch = false;
        tabIndex = tabController!.index;
      });
    });

    PlatformDispatcher.instance.onPlatformBrightnessChanged = () {
      if (getIntAsync(THEME_MODE_INDEX) == ThemeModeSystem) {
        appStore.setDarkMode(
            MediaQuery.of(context).platformBrightness == Brightness.light);
      }
    };

    LogRepository.init(dbName: getStringAsync(userId));
    localDbInstance = await SqliteMethods.initInstance();
    UserModel admin = UserModel();
    await fireStore.collection(ADMIN).get().then((value) {
      admin = UserModel.fromJson(value.docs.first.data());
      return admin;
    }).catchError((e) {
      log(e.toString());
      return admin;
    });
    appSettingStore.setReportCount(
        aReportCount: admin.reportUserCount.validate(value: 0),
        isInitialize: true);
    await VersionService().getVersionData(context);
  }

  @override
  void setState(fn) {
    if (mounted) super.setState(fn);
  }

  Future<bool> _onWillPop() async {
    if (tabIndex == 2) {
      setState(() {
        tabIndex = 0;
        tabController?.animateTo(0);
      });
      return false;
    }
    if (tabIndex == 1) {
      setState(() {
        tabIndex = 0;
        tabController?.animateTo(0);
      });
      return false;
    }
    return true;
  }

  void handleIncomingData() async {
    _startDeepLinkListener();
    _startIntentListener();
  }

  // Separate method for starting deep link listener
  void _startDeepLinkListener() {
    _linkSubscription?.cancel();
    _linkSubscription = AppLinks().uriLinkStream.listen((uri) async {
      print("Received deep link: $uri");
      final path = uri.path.replaceAll('/', '');

      // Cancel intent listener when deep link is received
      _intentSub?.cancel();

      if (uri.path.contains("join")) {
        print("Already in group link");
        final groupId = uri.queryParameters['group'];
        final groupName = uri.queryParameters['name'] ?? "Group";
        if (groupId == null) return;

        // Cancel both listeners while showing dialog
        _linkSubscription?.cancel();
        _intentSub?.cancel();
        if (!await checkIfGroupExists(groupId)) {
          await showConfirmDialogCustom(
            context,
            title: "are_you_sure_you_want_to_join".translate,
            primaryColor: primaryColor,
            positiveText: 'Open',
            negativeText: 'lbl_no'.translate,
            onAccept: (v) async {
              ContactModel data = ContactModel()
                ..uid = groupId
                ..addedOn = Timestamp.now()
                ..lastMessageTime = DateTime.now().millisecondsSinceEpoch
                ..groupRefUrl = groupId;
              await chatMessageService
                  .getContactsDocument(
                      of: getStringAsync(userId), forContact: groupId)
                  .set(data.toJson());
              await groupChatMessageService.joinGroup(
                groupDocId: groupId,
                currentUserId: getStringAsync(userId),
              );
              await setValue(CURRENT_GROUP_ID, groupId);
              GroupChatScreen(groupChatId: groupId, groupName: groupName)
                  .launch(context);
              // Restart deep link listener after action
              _startDeepLinkListener();
            },
            onCancel: (v) {
              // Restart deep link listener when canceled
              _startDeepLinkListener();
            },
          );
        } else {
          await setValue(CURRENT_GROUP_ID, groupId);
          GroupChatScreen(groupChatId: groupId, groupName: groupName)
              .launch(context);
          // Restart deep link listener after action
          _startDeepLinkListener();
        }
      } else if (RegExp(r'^\d{10,15}$').hasMatch(path)) {
        final number = path;

        // Cancel both listeners while showing dialog
        _linkSubscription?.cancel();
        _intentSub?.cancel();

        if (!await checkIfUserContactExists(number)) {
          await showConfirmDialogCustom(
            context,
            title: "DoYouWantToStartAChatWithThisNumber".translate,
            subTitle: number,
            primaryColor: primaryColor,
            positiveText: 'StartChat'.translate,
            negativeText: 'cancel'.translate,
            onAccept: (v) async {
              UserModel userModel =
                  await userService.getUserByPhoneNumber(phoneNumber: number);
              await ChatScreen(userModel, isArchive: false, isAdmin: false)
                  .launch(context);
              _startDeepLinkListener();
            },
            onCancel: (v) {
              _startDeepLinkListener();
            },
          );
        } else {
          UserModel userModel =
              await userService.getUserByPhoneNumber(phoneNumber: number);
          await ChatScreen(userModel, isArchive: false, isAdmin: false)
              .launch(context);
        }
      }
      print("Skipping to intent: $uri");
      // Start intent listener if no deep link was handled
      _startIntentListener();
    }, onError: (err) {
      print("Deep link error: $err");
      _startIntentListener();
    });
  }

  Future<bool> checkIfGroupExists(String groupId) async {
    final String userIdValue = getStringAsync(userId);

    try {
      // Get the first snapshot from the stream
      final snapshot =
          await chatMessageService.fetchContacts(userId: userIdValue).first;

      // Convert docs to contact list
      List<ContactModel> contacts = snapshot.docs
          .map((doc) =>
              ContactModel.fromJson(doc.data() as Map<String, dynamic>))
          .toList();
      bool groupExists =
          contacts.any((contact) => contact.groupRefUrl == groupId);

      if (groupExists) {
        print("✅ Group $groupId exists in your contacts.");
        return true;
      } else {
        print("❌ Group $groupId not found.");
        return false;
      }
    } catch (e, stackTrace) {
      print("❗ Error checking group existence: $e");
      print(stackTrace);
      return false;
    }
  }

  Future<bool> checkIfUserContactExists(String number) async {
    try {
      UserModel userModel =
          await userService.getUserByPhoneNumber(phoneNumber: number);

      final userUid = userModel.uid;

      final snapshot = await chatMessageService
          .fetchContacts(userId: getStringAsync(userId))
          .first;

      List<ContactModel> contacts = snapshot.docs
          .map((doc) =>
              ContactModel.fromJson(doc.data() as Map<String, dynamic>))
          .toList();

      bool userExists = contacts.any((contact) => contact.uid == userUid);

      if (userExists) {
        return true;
      } else {
        return false;
      }
    } catch (e) {
      print("❗ Error: $e");
      return false;
    }
  }

  void _startIntentListener() {
    _intentSub?.cancel();
    _intentSub = ReceiveSharingIntent.instance.getMediaStream().listen((value) {
      bool isDeepLink =
          value.any((media) => media.path.contains(CHAT_WEB_DOAMAIN_URL));
      if (isDeepLink) {
        return;
      }
      _linkSubscription?.cancel();
      setState(() {
        _sharedFiles.clear();
        _sharedFiles.addAll(value);
      });
      if (_sharedFiles.isNotEmpty) {
        NewChatScreen(
          isSharing: true,
          sharedMedia: List<SharedMediaFile>.from(_sharedFiles),
        ).launch(context, pageRouteAnimation: PageRouteAnimation.Slide);
        ReceiveSharingIntent.instance.reset();
        _startDeepLinkListener();
      }
    }, onError: (err) {
      _startDeepLinkListener();
    });

    ReceiveSharingIntent.instance.getInitialMedia().then((value) {
      bool isDeepLink =
          value.any((media) => media.path.contains(CHAT_WEB_DOAMAIN_URL));
      if (isDeepLink) {
        return;
      }
      setState(() {
        _sharedFiles.clear();
        _sharedFiles.addAll(value);
        if (_sharedFiles.isNotEmpty) {
          _linkSubscription?.cancel();
          NewChatScreen(
            isSharing: true,
            sharedMedia: List<SharedMediaFile>.from(_sharedFiles),
          ).launch(context, pageRouteAnimation: PageRouteAnimation.Slide);
          ReceiveSharingIntent.instance.reset();
          _startDeepLinkListener();
        }
      });
    });
  }

  @override
  void dispose() {
    _linkSubscription?.cancel();
    _intentSub?.cancel();
    tabController?.dispose();
    searchCont.clear();
    searchNotifier.value = '';
    _searchDebounce?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return PickupLayout(
      child: WillPopScope(
        onWillPop: _onWillPop,
        child: Scaffold(
          appBar: AppBar(
            actions: [
              AnimatedContainer(
                duration: Duration(milliseconds: 100),
                curve: Curves.decelerate,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    if (isSearch)
                      TextField(
                        textAlignVertical: TextAlignVertical.center,
                        cursorColor: Colors.white,
                        onChanged: (s) {
                          _searchDebounce?.cancel();
                          _searchDebounce =
                              Timer(const Duration(milliseconds: 600), () {
                            searchNotifier.value = s.trim();
                          });
                        },
                        style: TS.boldTextStyle(color: Colors.white),
                        controller: searchCont,
                        focusNode: searchFocus,
                        decoration: InputDecoration(
                          border: InputBorder.none,
                          hintText: 'search_here'.translate,
                          hintStyle: TS.secondaryTextStyle(color: Colors.white),
                        ),
                      ).expand(),
                    if (tabIndex == 0)
                      IconButton(
                        icon: isSearch ? Icon(Icons.close) : Icon(Icons.search),
                        onPressed: () async {
                          isSearch = !isSearch;
                          searchCont.clear();
                          LiveStream().emit(SEARCH_KEY, '');
                          searchNotifier.value = '';
                          setState(() {});
                          if (isSearch) {
                            300.milliseconds.delay.then((value) {
                              context.requestFocus(searchFocus);
                            });
                          }
                        },
                        color: Colors.white,
                      )
                  ],
                ),
                width: isSearch ? context.width() - 86 : 50,
              ).visible(tabIndex == 0),
              PopupMenuButton(
                icon: Icon(Icons.more_vert, color: Colors.white),
                color:
                    appStore.isDarkMode ? scaffoldSecondaryDark : Colors.white,
                onSelected: (dynamic value) async {
                  print("Selected Value: $value");

                  /// Tab index
                  print("Current Tab Index: $tabIndex");
                  if (tabIndex == 0) {
                    if (value == 1) {
                      NewChatScreen().launch(context,
                          pageRouteAnimation: PageRouteAnimation.Slide);
                    } else if (value == 3) {
                      QRScannerScreen().launch(context,
                          pageRouteAnimation: PageRouteAnimation.Slide);
                    } else if (value == 2) {
                      NewGroupScreen().launch(context,
                          pageRouteAnimation: PageRouteAnimation.Slide);
                    } else if (value == 4) {
                      SettingScreen().launch(context);
                    }
                  } else if (tabIndex == 1) {
                    if (value == 1) {
                      SettingScreen().launch(context);
                    }
                    if (value == 2) {
                      StoryPrivacySettingScreen().launch(context);
                    }
                  } else {
                    if (value == 1) {
                      await showConfirmDialogCustom(context,
                          dialogAnimation: DialogAnimation.SCALE,
                          primaryColor: primaryColor,
                          title: "log_confirmation".translate,
                          positiveText: 'lbl_yes'.translate,
                          negativeText: 'lbl_no'.translate, onAccept: (v) {
                        LogRepository.deleteAllLogs();
                        setState(() {});
                      });
                    }
                  }
                },
                itemBuilder: (context) {
                  if (tabIndex == 0)
                    return dashboardPopUpMenuItem;
                  else if (tabIndex == 1)
                    return statusPopUpMenuItem;
                  else
                    return chatLogPopUpMenuItem;
                },
              )
            ],
            bottom: TabBar(
              overlayColor:
                  MaterialStateProperty.all<Color>(Colors.transparent),
              indicatorWeight: 7,
              indicatorColor: primaryColor,
              unselectedLabelColor: Colors.grey,
              unselectedLabelStyle: secondaryTextStyle(),
              labelColor: primaryColor,
              labelStyle: boldTextStyle(),
              controller: tabController,
              onTap: (index) {
                setState(() {});
                isSearch = false;
                tabIndex = index;
              },
              tabs: [
                Tab(
                    child: Text('chats'.translate,
                        style: TS.boldTextStyle(color: Colors.white),
                        textAlign: TextAlign.center)),
                Tab(
                    child: Text('status'.translate,
                        style: TS.boldTextStyle(color: Colors.white),
                        textAlign: TextAlign.center)),
                Tab(
                    child: Text('calls'.translate,
                        style: TS.boldTextStyle(color: Colors.white),
                        textAlign: TextAlign.center)),
              ],
            ),
            backgroundColor: context.primaryColor,
            title: Text(AppName, style: TS.boldTextStyle(color: Colors.white)),
          ),
          bottomNavigationBar: FutureBuilder<PackageInfo>(
            future: PackageInfo.fromPlatform(),
            builder: (_, snap) {
              if (snap.hasData) {
                return Column(
                  mainAxisSize: MainAxisSize.min,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    2.height,
                    Text('v${snap.data?.version}',
                        style: TS.primaryTextStyle()),
                    8.height,
                    if (isBannerReady && myBanner != null)
                      SizedBox(
                        child: AdWidget(ad: myBanner!),
                        height: AdSize.banner.height.toDouble(),
                        width: context.width(),
                      ),
                  ],
                );
              }
              return snapWidgetHelper(snap);
            },
          ),
          body: SafeArea(
            child: IndexedStack(
              index: tabIndex,
              children: _screens,
            ),
          ),
        ),
      ),
    );
  }
}
