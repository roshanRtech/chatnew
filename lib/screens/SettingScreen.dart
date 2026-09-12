import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_mobx/flutter_mobx.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:nb_utils/nb_utils.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:share_plus/share_plus.dart';

import 'package:chat/centralized_import.dart';

import '../utils/TextStyles.dart' as TS;

class SettingScreen extends StatefulWidget {
  @override
  _SettingScreenState createState() => _SettingScreenState();
}

class _SettingScreenState extends State<SettingScreen> {
  BannerAd? myBanner;
  bool isBannerReady = false;

  @override
  void initState() {
    super.initState();
    init();
  }

  init() async {
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
          //
        },
        onAdFailedToLoad: (Ad ad, LoadAdError error) {
          print('BannerAd failedToLoad: $error');
          setState(() {
            isBannerReady = false;
          });
          myBanner?.dispose();
          myBanner = null;
          // nativeAdCompleter.completeError(null);
        },
      ),
      request: AdRequest(),
    );
  }

  @override
  void setState(fn) {
    if (mounted) super.setState(fn);
  }

  @override
  void dispose() {
    super.dispose();
  }

  Future<void> removeUserGroup() async {
    groupIds?.forEach((element) async {
      await groupChatMessageService.removeUserAsAdmin(
          userId: getStringAsync(userId), groupId: element);
      await groupChatMessageService.leaveGroup(
          UserId: getStringAsync(userId),
          groupId: element,
          userName: getStringAsync(userDisplayName));
    });
  }

  @override
  Widget build(BuildContext context) {
    return PickupLayout(
        child: Scaffold(
      appBar: appBarWidget("settings".translate,
          textColor: Colors.white, textSize: appStore.fontSize.toInt()),
      body: Stack(
        children: [
          ListView(
            children: [
              8.height,
              UserProfileWidget(),
              Divider(color: context.dividerColor),
              SettingItemWidget(
                padding: EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                titleTextStyle: TS.primaryTextStyle(),
                title: 'chats'.translate,
                leading: Image.asset(ic_chats,
                    height: 22, width: 22, color: context.iconColor),
                subTitle: 'theme_wallpaper'.translate,
                subTitleTextStyle: TS.secondaryTextStyle(),
                onTap: () {
                  ChatSettingScreen().launch(context).then((value) {
                    setState(() {});
                  });
                },
              ),
              if (!getBoolAsync(isSocialLogin))
                SettingItemWidget(
                  titleTextStyle: TS.primaryTextStyle(),
                  title: 'change_password'.translate,
                  padding: EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                  leading: Image.asset(ic_change_password,
                      height: 22, width: 22, color: context.iconColor),
                  subTitle:
                      'change_your_password_to_protect_your_account'.translate,
                  subTitleTextStyle: TS.secondaryTextStyle(),
                  onTap: () {
                    ChangePassword().launch(context).then((value) {
                      setState(() {});
                    });
                  },
                ),
              SettingItemWidget(
                titleTextStyle: TS.primaryTextStyle(),
                padding: EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                title: 'blocked_user'.translate,
                leading: Image.asset(ic_block_user,
                    height: 22, width: 22, color: context.iconColor),
                subTitle: 'list_blocked'.translate,
                subTitleTextStyle: TS.secondaryTextStyle(),
                onTap: () {
                  BlockListScreen().launch(context).then((value) {
                    setState(() {});
                  });
                },
              ),
              SettingItemWidget(
                titleTextStyle: TS.primaryTextStyle(),
                padding: EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                leading: Image.asset(ic_contact_us,
                    height: 22, width: 22, color: context.iconColor),
                title: 'contact_us'.translate,
                subTitle: 'for_all_enquires_please_email_us'.translate,
                onTap: () {
                  appLaunchUrl('mailto: ${appSettingStore.mail}');
                },
              ),
              SettingItemWidget(
                titleTextStyle: TS.primaryTextStyle(),
                padding: EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                leading: Image.asset(ic_rate_us,
                    height: 22, width: 22, color: context.iconColor),
                title: 'rate_us'.translate,
                subTitle: "your_review_counts".translate,
                onTap: () {
                  PackageInfo.fromPlatform().then((value) {
                    if (isIOS) {
                      appLaunchUrl(appStoreBaseURL + value.packageName);
                    } else {
                      appLaunchUrl(playStoreBaseURL + value.packageName,
                          forceWebView: true);
                    }
                  });
                },
              ),
              SettingItemWidget(
                padding: EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                titleTextStyle: TS.primaryTextStyle(),
                leading: Image.asset(ic_term_condition,
                    height: 22, width: 22, color: context.iconColor),
                title: 'terms_and_conditions'.translate,
                subTitle: "read_our_t_and_c".translate,
                onTap: () {
                  appLaunchUrl(appSettingStore.termsCond.validate());
                },
              ),
              SettingItemWidget(
                titleTextStyle: TS.primaryTextStyle(),
                title: 'logout'.translate,
                subTitle: 'visit_again'.translate,
                padding: EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                subTitleTextStyle: TS.secondaryTextStyle(),
                leading: Image.asset(ic_log_out,
                    height: 22, width: 22, color: context.iconColor),
                onTap: () async {
                  await showConfirmDialogCustom(context,
                      title: "are_you_sure_you_want_to_logout".translate,
                      primaryColor: primaryColor,
                      positiveText: 'lbl_yes'.translate,
                      negativeText: 'lbl_no'.translate, onAccept: (v) async {
                    try {
                      Map<String, dynamic> presenceStatusFalse = {
                        'isPresence': false,
                        'lastSeen': DateTime.now().millisecondsSinceEpoch,
                        'oneSignalPlayerId': '',
                      };
                      userService.updateUserStatus(
                          presenceStatusFalse, getStringAsync(userId));
                      var isRemembers = getBoolAsync(isRemember);
                      var userEmails = getStringAsync(userEmail);
                      var userPasswords = getStringAsync(userPassword);
                      await clearSharedPref();
                      if (isRemembers == true) {
                        await (isRemember, isRemembers);
                        await setValue(userEmail, userEmails);
                        await setValue(userPassword, userPasswords);
                      }
                      authService.logout(context);
                    } catch (e, s) {
                      print("-----------217>>${e.toString()}");
                      print("-----------218>>${s.toString()}");
                    }
                  });
                },
              ),
              //     Divider(indent: 55),
              Divider(
                color: context.dividerColor,
              ),
              SettingItemWidget(
                titleTextStyle: TS.primaryTextStyle(),
                leading: Image.asset(ic_about_app,
                    height: 22, width: 22, color: context.iconColor),
                title: 'app_info'.translate,
                onTap: () {
                  AboutUsScreen().launch(context);
                },
                padding: EdgeInsets.symmetric(vertical: 12, horizontal: 16),
              ),
              SettingItemWidget(
                titleTextStyle: TS.primaryTextStyle(),
                padding: EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                title: "delete_account".translate,
                subTitleTextStyle: TS.secondaryTextStyle(),
                leading: Image.asset(ic_delete_acc,
                    height: 22, width: 22, color: context.iconColor),
                onTap: () async {
                  await showConfirmDialogCustom(context,
                      dialogAnimation: DialogAnimation.SCALE,
                      title: "are_you_sure_you_want_to_delete_this_account"
                          .translate,
                      positiveText: 'lbl_yes'.translate,
                      negativeText: 'lbl_no'.translate,
                      primaryColor: primaryColor, onAccept: (v) async {
                    appStore.setLoading(true);

                    await removeUserGroup();

                    await userService.ref!
                        .doc(getStringAsync(userId))
                        .collection(CHAT_REQUEST)
                        .get()
                        .then((value) async {
                      for (var doc in value.docs) {
                        await doc.reference.delete();
                      }
                      await userService.ref!
                          .doc(getStringAsync(userId))
                          .collection(CHAT_REQUEST)
                          .parent
                          ?.delete();
                    }).whenComplete(() async {
                      await userService.ref!
                          .doc(getStringAsync(userId))
                          .collection(CONTACT_COLLECTION)
                          .get()
                          .then((value) async {
                        for (var doc in value.docs) {
                          await doc.reference.delete();
                        }
                        await userService.ref!
                            .doc(getStringAsync(userId))
                            .collection(CONTACT_COLLECTION)
                            .parent!
                            .delete();
                      });
                    }).whenComplete(() async {
                      await storyService.ref!
                          .where('userId', isEqualTo: getStringAsync(userId))
                          .get()
                          .then((value) async {
                        for (var doc in value.docs) {
                          await doc.reference.delete();
                        }
                      }).whenComplete(() async {
                        await storyService.storage
                            .ref()
                            .child(
                                "$STORY_DATA_IMAGES/${getStringAsync(userId)}/")
                            .listAll()
                            .then((value) {
                          value.items.forEach((element) {
                            storyService.storage.ref(element.fullPath).delete();
                          });
                        });
                      });
                    });

                    FirebaseAuth.instance.currentUser?.delete();
                    await FirebaseAuth.instance.signOut();
                    await authService
                        .deleteUserPermanent(uid: getStringAsync(userId))
                        .then((value) async {
                      removeKey(userEmail);
                      removeKey(userPassword);
                      removeKey(isRemember);
                      deviceService.removeUser(
                          context: context, uid: getStringAsync(userId));
                      authService.logout(context);
                      await clearSharedPref();
                      appStore.setLoading(false);
                    }).catchError((e) {
                      appStore.setLoading(false);
                      log(e);
                    });
                  });
                },
              ),
              SettingItemWidget(
                titleTextStyle: TS.primaryTextStyle(),
                padding: EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                title: 'invite_a_friend'.translate,
                subTitleTextStyle: TS.secondaryTextStyle(),
                leading: Image.asset(ic_invite_people,
                    height: 22, width: 22, color: context.iconColor),
                onTap: () {
                  PackageInfo.fromPlatform().then((value) {
                    Share.share(
                        'Share $AppName app\n\n$playStoreBaseURL${value.packageName}');
                  });
                },
              ),
            ],
          ),
          Observer(builder: (context) {
            return Positioned.fill(
                    child: Container(
                        color: Colors.transparent,
                        child: Loader(
                            valueColor:
                                AlwaysStoppedAnimation<Color>(primaryColor))))
                .visible(appStore.isLoading);
          })
        ],
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
                Text('v${snap.data!.version}', style: TS.primaryTextStyle()),
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
    ));
  }
}
