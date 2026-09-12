import 'package:flutter/material.dart';
import 'package:flutter_mobx/flutter_mobx.dart';
import 'package:nb_utils/nb_utils.dart';
import 'package:share_plus/share_plus.dart';

import 'package:chat/centralized_import.dart';

import '../utils/TextStyles.dart' as TS;

class UserProfileWidget extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return PickupLayout(
      child: Observer(
        builder: (_) {
          return Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              InkWell(
                onTap: () {
                  SaveProfileScreen(mIsShowBack: true, mIsFromLogin: false)
                      .launch(context);
                },
                child: Row(
                  children: [
                    !loginStore.mPhotoUrl.validate().isEmptyOrNull
                        ? Hero(
                            tag: "profile_image",
                            child: cachedImage(
                              loginStore.mPhotoUrl.validate(),
                              height: 50,
                              width: 50,
                              radius: 25,
                              fit: BoxFit.cover,
                            ).cornerRadiusWithClipRRect(25),
                          )
                        : Hero(
                            tag: "profile_image",
                            child: CircleAvatar(
                              radius: 32.0,
                              backgroundColor:
                                  getColorFromString(getStringAsync(userId)),
                              child: Text(
                                loginStore.mDisplayName.validate()[0],
                                style: TS.primaryTextStyle(color: Colors.white),
                              ),
                            ),
                          ),
                    10.width,
                    Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                            loginStore.mDisplayName
                                .validate()
                                .capitalizeEachWord(),
                            style: TS.boldTextStyle()),
                        4.height,
                        Text(
                            loginStore.mStatus
                                .validate()
                                .capitalizeFirstLetter(),
                            style: TS.secondaryTextStyle(),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis),
                      ],
                    ).expand(),
                  ],
                ).paddingAll(12),
              ).expand(),
              IconButton(
                icon: Icon(Icons.qr_code_scanner),
                onPressed: () async {
                  await QRScannerScreen().launch(context);
                  appStore.setLoading(false);
                },
              ),
              IconButton(
                icon: Icon(Icons.share),
                onPressed: () async {
                  _showVideoBottomSheet(context, loginStore.mMobileNumber);
                },
              )
            ],
          );
        },
      ),
    );
  }

  void _showVideoBottomSheet(BuildContext context, String? mobileNumber) {
    showModalBottomSheet<void>(
      backgroundColor: context.cardColor,
      context: context,
      builder: (BuildContext context) {
        return Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            SettingItemWidget(
              title: 'lblInApp'.translate,
              leading: Image.asset(inapp,
                  height: 25, width: 25, color: primaryColor),
              onTap: () async {
                UserModel user =
                    await userService.getUserById(val: getStringAsync(userId));
                Shareprofilescreen(
                  receiverUser: user,
                ).launch(context);
              },
            ),
            Divider(color: context.dividerColor),
            SettingItemWidget(
              title: 'lblChooser'.translate,
              leading: Image.asset(statusIcon,
                  height: 25, width: 25, color: primaryColor),
              onTap: () {
                String groupLink =
                    '${CHAT_WEB_DOAMAIN_URL}${mobileNumber?.replaceAll("+", "")}';
                Share.share('Add me as a contact on ${AppName}: $groupLink');
              },
            ),
          ],
        ).paddingAll(16.0);
      },
    );
  }
}
