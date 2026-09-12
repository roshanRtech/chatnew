import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:nb_utils/nb_utils.dart';

import 'package:chat/centralized_import.dart';

import '../../utils/TextStyles.dart' as TS;

class StatusEditorScreen extends StatefulWidget {
  @override
  _StatusEditorScreenState createState() => _StatusEditorScreenState();
}

class _StatusEditorScreenState extends State<StatusEditorScreen> {
  int backgroundColor = 0xFF9C27B0;
  TextEditingController _controller = TextEditingController();

  List<int?> colorOptions = [
    0xFF9C27B0,
    0xFFF44336,
    0xFF4CAF50,
    0xFFFF9800,
    0xFF2196F3,
    0xFF000000,
  ];

  void _changeBackgroundColor() {
    setState(() {
      backgroundColor = (colorOptions..shuffle()).first ?? 0;
    });
  }

  Future<void> uploadStory() async {
    appStore.setLoading(true);
    // SubscriptionInfo? info = await chatMessageService.getSubscription(getStringAsync(userId));
    StoryModel data = StoryModel();
    data.userId = getStringAsync(userId);
    data.caption = _controller.text;
    data.createAt = Timestamp.now();
    data.updatedAt = Timestamp.now();
    data.backgroundColor = backgroundColor;
    data.type = 'text';
    data.userImgPath = loginStore.mPhotoUrl;
    data.userName = loginStore.mDisplayName;
    data.oneSignalKey = getStringAsync(playerId);
    data.excludedUserList = appStore.excludedSelectedUserList;
    data.includedUserList = appStore.includedSelectedUserList;
    data.statusPrivacyIndex = getIntAsync(STATUS_PRIVACY_INDEX);

    // data.userImgPath = getStringAsync(USER_PROFILE_IMAGE);

    await storyService
        .addStory(data, userId: getStringAsync(userId))
        .then((value) {
      appStore.setLoading(false);
    }).catchError((e) {
      appStore.setLoading(false);
      log('error' + e.toString());
    });
    finish(context, true);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Color(backgroundColor),
      body: SafeArea(
        child: Stack(
          children: [
            // Center text input
            Center(
              child: TextField(
                controller: _controller,
                textAlign: TextAlign.center,
                style: TS.boldTextStyle(
                  color: Colors.white,
                ),
                maxLines: null,
                keyboardType: TextInputType.multiline,
                textInputAction: TextInputAction.newline,
                decoration: InputDecoration(
                  border: InputBorder.none,
                  hintText: 'lblTypeAStatus'.translate,
                  hintStyle: TS.secondaryTextStyle(color: Colors.white70),
                ),
              ).paddingSymmetric(horizontal: 32),
            ),

            Positioned(
              top: 16,
              left: 16,
              child: CircleAvatar(
                backgroundColor: Colors.black45,
                child: IconButton(
                  icon: Icon(Icons.close, color: Colors.white),
                  onPressed: () => Navigator.pop(context),
                ),
              ),
            ),

            Positioned(
              top: 16,
              right: 16,
              child: CircleAvatar(
                backgroundColor: Colors.black45,
                child: IconButton(
                  icon: Icon(Icons.color_lens, color: Colors.white),
                  onPressed: _changeBackgroundColor,
                ),
              ),
            ),
            Align(
              alignment: isRTL ? Alignment.bottomLeft : Alignment.bottomRight,
              child: Container(
                height: 60,
                width: 60,
                padding: EdgeInsets.all(8),
                decoration:
                    BoxDecoration(shape: BoxShape.circle, color: primaryColor),
                child: Icon(Icons.send, color: Colors.white),
              )
                  .paddingOnly(
                      bottom: 50, right: isRTL ? 16 : 10, left: isRTL ? 10 : 16)
                  .onTap(() {
                uploadStory();
              }, borderRadius: BorderRadius.circular(50)),
            ),
          ],
        ),
      ),
    );
  }
}
