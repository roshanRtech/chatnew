import 'dart:io';
import 'package:chat/main.dart';
import 'package:chat/models/ChatMessageModel.dart';
import 'package:chat/models/ChatRequestModel.dart';
import 'package:chat/models/ContactModel.dart';
import 'package:chat/models/StoryModel.dart';
import 'package:chat/utils/AppColors.dart';
import 'package:chat/utils/AppCommon.dart';
import 'package:chat/utils/providers/ChatRequestProvider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:emoji_picker_flutter/emoji_picker_flutter.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:nb_utils/nb_utils.dart';

import 'package:story_view/story_view.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:wakelock_plus/wakelock_plus.dart';
import '../services/ChatMessageService.dart';
import '../utils/AppConstants.dart';
import '../../utils/TextStyles.dart' as TS;

// Separate widget for the story player to prevent rebuilds
class StoryPlayerWidget extends StatefulWidget {
  final List<StoryModel> storyItems;
  final StoryController controller;
  final Function(StoryItem? storyItem, int index) onStoryShow;
  final Function() onComplete;

  const StoryPlayerWidget({
    Key? key,
    required this.storyItems,
    required this.controller,
    required this.onStoryShow,
    required this.onComplete,
  }) : super(key: key);

  @override
  _StoryPlayerWidgetState createState() => _StoryPlayerWidgetState();
}

class _StoryPlayerWidgetState extends State<StoryPlayerWidget> {
  List<StoryItem> _storyItems = [];

  @override
  void initState() {
    super.initState();
    WakelockPlus.enable();
    _buildStoryItems();
  }

  void _buildStoryItems() {
    _storyItems = widget.storyItems.map((story) {
      if (story.type == "text") {
        final text = story.caption ?? '';
        final linkRegex = RegExp(r'(https?:\/\/[^\s]+)');
        final matches = linkRegex.allMatches(text);
        final spans = <TextSpan>[];
        int currentIndex = 0;

        for (final match in matches) {
          if (match.start > currentIndex) {
            spans
                .add(TextSpan(text: text.substring(currentIndex, match.start)));
          }
          final url = match.group(0)!;
          spans.add(
            TextSpan(
              text: url,
              style: TS.boldTextStyle(
                color: Colors.blue,
                decoration: TextDecoration.underline,
              ),
              recognizer: TapGestureRecognizer()
                ..onTap = () async {
                  final uri = Uri.parse(url);
                  if (await canLaunchUrl(uri)) {
                    await launchUrl(uri, mode: LaunchMode.externalApplication);
                  }
                },
            ),
          );
          currentIndex = match.end;
        }
        if (currentIndex < text.length) {
          spans.add(TextSpan(text: text.substring(currentIndex)));
        }

        return StoryItem.text(
          title: story.caption ?? '',
          backgroundColor: Color(story.backgroundColor ?? 0xFF9C27B0),
          textStyle: TS.boldTextStyle(),
        );
      } else if (story.type == "video") {
        return StoryItem.pageVideo(story.imagePath ?? '',
            imageFit: BoxFit.cover,
            controller: widget.controller,
            duration:
                Duration(seconds: int.parse(story.videoDuration ?? "15")));
      } else {
        return StoryItem.pageImage(
          url: story.imagePath ?? '',
          controller: widget.controller,
        );
      }
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    return StoryView(
      indicatorForegroundColor: primaryColor,
      indicatorHeight: IndicatorHeight.small,
      onComplete: widget.onComplete,
      onStoryShow: widget.onStoryShow,
      controller: widget.controller,
      storyItems: _storyItems,
    );
  }
}

class StoryListScreen extends StatefulWidget {
  final List<StoryModel>? list;
  final String? userName;
  final Timestamp? time;
  final String? userImg;
  final String? oneSignalkey;
  final bool? isStoryItemShow;

  StoryListScreen({
    this.list,
    this.userName,
    this.time,
    this.userImg,
    this.isStoryItemShow,
    this.oneSignalkey,
  });

  @override
  _StoryListScreenState createState() => _StoryListScreenState();
}

class _StoryListScreenState extends State<StoryListScreen>
    with WidgetsBindingObserver {
  final StoryController controller = StoryController();
  String userIdS = "";
  ValueNotifier<String> extraCaption = ValueNotifier<String>("");
  bool? currentUser = false;
  ValueNotifier<String?> statusTime = ValueNotifier(null);
  TextEditingController replyController = TextEditingController();
  bool emojiStickerShowing = false;
  bool emojiShowing = false;
  ValueNotifier<bool> _isReplying = ValueNotifier(false);
  ValueNotifier<bool> _isSending = ValueNotifier(false);
  List<StoryModel> storyItems = [];
  int currentStoryIndex = 0;
  int currentStatusIndex = 0;
  var receiverUserId = '';
  StoryModel? storyModel;
  bool _isKeyboardVisible = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    inits();
    receiverUserId = widget.list?.first.userId ?? '';
  }

  @override
  void didChangeMetrics() {
    final newKeyboardVisible = MediaQuery.of(context).viewInsets.bottom > 0;
    if (newKeyboardVisible != _isKeyboardVisible) {
      _isKeyboardVisible = newKeyboardVisible;
      _handleKeyboardVisibilityChange();
    }
  }

  void _handleKeyboardVisibilityChange() {
    print("_handleKeyboardVisibilityChange called()");
    if (_isKeyboardVisible && !_isReplying.value) {
      _isReplying.value = true;
      controller.pause();
    } else if (!_isKeyboardVisible &&
        _isReplying.value &&
        !emojiStickerShowing) {
      _isReplying.value = false;
      if (!_isSending.value) {
        controller.play();
      }
    }
  }

  Future<void> inits() async {
    userIdS = getStringAsync(userId);
    initializeStoryItems();
  }

  void initializeStoryItems() async {
    if (widget.list != null) {
      for (var e in widget.list ?? []) {
        if (e.userId == getStringAsync(userId)) {
          currentUser = true;
        }
        if (e.statusPrivacyIndex == 2 &&
            e.includedUserList != null &&
            e.includedUserList!.contains(userIdS)) {
          storyItems.add(e);
          continue;
        }
        if (e.statusPrivacyIndex == 1 &&
            e.excludedUserList != null &&
            e.excludedUserList!.contains(userIdS)) {
          continue;
        }
        if (e.userId == getStringAsync(userId)) {
          storyItems.add(e);
          continue;
        }
        if (e.excludedUserList!.isEmpty && e.includedUserList!.isEmpty) {
          storyItems.add(e);
          continue;
        }
      }
      if (mounted) setState(() {});
    } else {
      storyItems = [];
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    controller.dispose();
    replyController.dispose();
    extraCaption.dispose();
    statusTime.dispose();
    _isReplying.dispose();
    _isSending.dispose();
    WakelockPlus.disable();
    super.dispose();
  }

  void handleTap() {
    if (!replyController.text.isEmptyOrNull && !_isSending.value) {
      _isSending.value = true;
      sendMessage(storyModel);
      hideKeyboard(context);
      Future.delayed(Duration(milliseconds: 300), () {
        if (mounted) {
          _isSending.value = false;
          _isReplying.value = false;
        }
        // replyController.clear();
        controller.play();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async {
        controller.pause();
        return true;
      },
      child: Scaffold(
        backgroundColor: Colors.black,
        body: Stack(
          alignment: Alignment.bottomCenter,
          children: [
            StoryPlayerWidget(
              storyItems: storyItems,
              controller: controller,
              onStoryShow: (v, index) async {
                if (!_isReplying.value) {
                  currentStatusIndex = index;
                  storyModel = storyItems[currentStatusIndex];
                  extraCaption.value = storyModel?.extraCaption ?? '';
                  statusTime.value = formatTime(
                          storyModel?.createAt?.millisecondsSinceEpoch ?? 0)
                      .toString();
                  widget.list?.forEach((data) async {
                    if (getStringAsync(userId) != data.userId) {
                      await storyService.addUserToSeenStatus(
                        storyModel?.id ?? '',
                        currentStatusIndex,
                        getStringAsync(userId),
                        getStringAsync(userDisplayName),
                        getStringAsync(userPhotoUrl),
                      );
                    }
                  });
                }
              },
              onComplete: () {
                if (!_isReplying.value && !_isSending.value) {
                  finish(context);
                } else {
                  controller.pause();
                }
              },
            ),
            Positioned(
              top: MediaQuery.of(context).size.height * 0.07,
              left: 10,
              child: Row(
                children: [
                  GestureDetector(
                    onTap: () {
                      finish(context);
                    },
                    child: Icon(Icons.arrow_back, color: Colors.white),
                  ),
                  15.width,
                  ClipRRect(
                    borderRadius: BorderRadius.circular(100),
                    child: Image.network(
                      !widget.userImg.isEmptyOrNull
                          ? widget.userImg ?? ''
                          : "https://www.fagerhult.com/cdn-cgi/image/width=525,quality=80,fit=scale-down,onerror=redirect/assets/images/no-image-available.jpg",
                      fit: BoxFit.cover,
                      width: 45,
                      height: 45,
                      loadingBuilder: (context, child, loadingProgress) {
                        if (loadingProgress == null) return child;
                        return Center(
                          child: CircularProgressIndicator(
                            color: primaryColor,
                            value: loadingProgress.expectedTotalBytes != null
                                ? loadingProgress.cumulativeBytesLoaded /
                                    (loadingProgress.expectedTotalBytes ?? 1)
                                : null,
                          ),
                        );
                      },
                      errorBuilder: (context, error, stackTrace) {
                        return Icon(Icons.error, color: Colors.red);
                      },
                    ),
                  ),
                  10.width,
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(widget.userName ?? '',
                          style: TS.boldTextStyle(color: Colors.white)),
                      4.height,
                      ValueListenableBuilder<String?>(
                        valueListenable: statusTime,
                        builder: (context, value, child) {
                          return Text(
                            value ?? '',
                            style: TS.secondaryTextStyle(color: Colors.white),
                          );
                        },
                      ),
                    ],
                  ),
                ],
              ),
            ),
            Positioned(
              right: 10,
              left: 10,
              bottom: MediaQuery.of(context).size.height * 0.15,
              child: ValueListenableBuilder<String>(
                valueListenable: extraCaption,
                builder: (context, caption, child) {
                  if (caption.isEmpty) return const SizedBox();
                  return RichText(
                    textAlign: TextAlign.center,
                    text: TextSpan(
                      style: TS.boldTextStyle(),
                      children: buildMessageStatus(
                          caption, context, getStringAsync(userId)),
                    ),
                  );
                },
              ),
            ),
            if (currentUser!) ...[
              Container(
                height: 50,
                alignment: Alignment.center,
                child: IconButton(
                  icon:
                      Icon(Icons.remove_red_eye_outlined, color: Colors.white),
                  onPressed: () async {
                    controller.pause();
                    var seenUsers = storyModel?.seenUserList ?? [];
                    _showStatusBottomSheet(context, seenUsers, controller);
                  },
                ),
              ),
            ],
            ValueListenableBuilder<bool>(
              valueListenable: _isReplying,
              builder: (context, isReplying, child) {
                return AnimatedPositioned(
                  duration: Duration(milliseconds: 300),
                  bottom: isReplying
                      ? (emojiStickerShowing
                          ? MediaQuery.of(context).size.height * 0.3
                          : MediaQuery.of(context).padding.bottom + 8)
                      : -100,
                  left: 0,
                  right: 0,
                  child: Container(
                    padding: EdgeInsets.only(
                      left: 8,
                      right: 8,
                      bottom: MediaQuery.of(context).padding.bottom + 8,
                      top: 8,
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Expanded(
                          child: Container(
                            constraints: BoxConstraints(minHeight: 50),
                            decoration: boxDecorationWithShadow(
                              borderRadius: BorderRadius.circular(20),
                              spreadRadius: 0,
                              blurRadius: 0,
                              backgroundColor: context.cardColor,
                            ),
                            padding: EdgeInsets.only(left: 0, right: 8),
                            child: Row(
                              children: [
                                IconButton(
                                  icon: Icon(Icons.emoji_emotions_outlined),
                                  iconSize: 24.0,
                                  padding: EdgeInsets.all(2),
                                  color: Colors.grey,
                                  onPressed: () {
                                    hideKeyboard(context);
                                    setState(() {
                                      emojiStickerShowing =
                                          !emojiStickerShowing;
                                      emojiShowing = true;
                                      controller.pause();
                                    });
                                  },
                                ),
                                Expanded(
                                  child: AppTextField(
                                    controller: replyController,
                                    textFieldType: TextFieldType.OTHER,
                                    cursorColor: appStore.isDarkMode
                                        ? Colors.white
                                        : Colors.black,
                                    textCapitalization:
                                        TextCapitalization.sentences,
                                    keyboardType: TextInputType.multiline,
                                    minLines: 1,
                                    maxLines: 5,
                                    decoration: InputDecoration(
                                      border: InputBorder.none,
                                      hintText: 'lblMessage'.translate,
                                      hintStyle: TS.secondaryTextStyle(),
                                      isDense: true,
                                      contentPadding: EdgeInsets.symmetric(
                                          vertical: 12, horizontal: 8),
                                    ),
                                    onTap: () {
                                      controller.pause();
                                    },
                                    onFieldSubmitted: (value) => handleTap(),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        8.width,
                        GestureDetector(
                          onTap: handleTap,
                          child: Container(
                            width: 50,
                            height: 50,
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                                color: primaryColor, shape: BoxShape.circle),
                            child:
                                Icon(Icons.send, color: Colors.white, size: 22),
                          ),
                        ),
                        8.width,
                        GestureDetector(
                          onTap: () {
                            hideKeyboard(context); // Close keyboard
                            _isReplying.value = false; // Hide reply interface
                            replyController.clear(); // Clear text field
                            if (!_isSending.value) {
                              controller.play(); // Resume story
                            }
                          },
                          child: Container(
                            width: 50,
                            height: 50,
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                                color: Colors.grey, shape: BoxShape.circle),
                            child: Icon(Icons.close,
                                color: Colors.white, size: 22),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
            if (emojiStickerShowing) showEmojiBottomsheet(),
            Positioned(
              bottom: MediaQuery.of(context).padding.bottom + 20,
              left: 0,
              right: 0,
              child: ValueListenableBuilder<bool>(
                valueListenable: _isReplying,
                builder: (context, isReplying, child) {
                  if (!isReplying && !currentUser!)
                    return Center(
                      child: GestureDetector(
                        onTap: () {
                          _isReplying.value = true;
                          controller.pause();
                        },
                        child: Container(
                          padding: EdgeInsets.symmetric(
                              horizontal: 20, vertical: 12),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(25),
                            border: Border.all(
                              color: Colors.white.withOpacity(0.3),
                              width: 1,
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.reply, color: Colors.white, size: 18),
                              8.width,
                              Text(
                                'reply'.translate,
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 16,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  return SizedBox.shrink();
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showStatusBottomSheet(
      BuildContext context, List<SeenUser>? list, StoryController controller) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: context.cardColor,
      builder: (BuildContext context) {
        double itemHeight = 70;
        int itemCount = list?.length ?? 0;
        double maxHeight = MediaQuery.of(context).size.height * 0.6;
        double calculatedHeight = (itemCount * itemHeight) + 80;
        double finalHeight =
            calculatedHeight > maxHeight ? maxHeight : calculatedHeight;
        return Container(
          height: finalHeight,
          width: double.infinity,
          decoration: BoxDecoration(
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
                                child: Image.network(
                                  list?[index].userImgPath ?? '',
                                  fit: BoxFit.cover,
                                  errorBuilder: (context, error, stackTrace) {
                                    return Container(
                                      color: getColorFromString(
                                          list?[index].userId ?? ''),
                                      child: Text(
                                        list?[index]
                                                .userName
                                                .validate()[0]
                                                .toUpperCase() ??
                                            '',
                                        style: TS.secondaryTextStyle(
                                            color: Colors.white),
                                      ).center().fit(),
                                    );
                                  },
                                ).cornerRadiusWithClipRRect(45),
                              ),
                            ),
                            title: Text(list?[index].userName ?? '',
                                style:
                                    TS.secondaryTextStyle(color: Colors.black)),
                            onTap: () {
                              Navigator.pop(context);
                            },
                          );
                        },
                      ),
                    )
                  : Center(
                      child: Text('emptyView'.translate,
                          style: TS.boldTextStyle())),
            ],
          ),
        );
      },
    ).whenComplete(() {
      if (!_isReplying.value && !_isSending.value) {
        controller.play();
      }
    });
  }

  Widget showEmojiBottomsheet() {
    return Stack(
      alignment: Alignment.bottomCenter,
      children: [
        Container(
          child: emojiShowing
              ? Container(
                  height: 255,
                  width: context.width(),
                  color: context.cardColor,
                  constraints: BoxConstraints(maxHeight: 500),
                  child: EmojiPicker(
                    onEmojiSelected: (Category? category, Emoji emoji) {
                      replyController.text = replyController.text + emoji.emoji;
                      _isReplying.value = true;
                      controller.pause();
                    },
                    config: Config(
                      checkPlatformCompatibility: true,
                      emojiViewConfig: EmojiViewConfig(
                        columns: 8,
                        emojiSizeMax: 32 * (Platform.isIOS ? 1.30 : 1.0),
                        verticalSpacing: 0,
                        horizontalSpacing: 0,
                        gridPadding: EdgeInsets.only(bottom: 50),
                        recentsLimit: 28,
                        replaceEmojiOnLimitExceed: false,
                        noRecents: Text('no_recent'.translate,
                            style: TS.boldTextStyle(color: Colors.black26),
                            textAlign: TextAlign.center),
                        buttonMode: ButtonMode.MATERIAL,
                      ),
                      skinToneConfig: SkinToneConfig(
                          indicatorColor: Colors.grey,
                          enabled: true,
                          dialogBackgroundColor: context.cardColor),
                      categoryViewConfig: const CategoryViewConfig(
                        categoryIcons: CategoryIcons(),
                        tabIndicatorAnimDuration: kTabScrollDuration,
                        recentTabBehavior: RecentTabBehavior.RECENT,
                        backspaceColor: primaryColor,
                        indicatorColor: primaryColor,
                        initCategory: Category.RECENT,
                        iconColorSelected: primaryColor,
                        iconColor: Colors.grey,
                      ),
                      searchViewConfig: SearchViewConfig(),
                      bottomActionBarConfig: BottomActionBarConfig(
                          enabled: true,
                          backgroundColor: context.cardColor,
                          showSearchViewButton: false),
                    ),
                  ),
                )
              : SizedBox.shrink(),
        ),
        Container(
          height: 40,
          alignment: Alignment.center,
          width: context.width(),
          color: context.cardColor,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              IconButton(
                onPressed: () {
                  setState(() {
                    emojiShowing = true;
                    emojiStickerShowing = !emojiStickerShowing;
                    if (emojiStickerShowing) {
                      controller.pause();
                    } else {
                      if (_isReplying.value) {
                      } else if (!_isSending.value) {
                        controller.play();
                      }
                    }
                  });
                },
                icon: Icon(Icons.emoji_emotions_outlined,
                    size: 28,
                    color: emojiShowing
                        ? primaryColor
                        : textSecondaryColorGlobal.withOpacity(0.7)),
              ),
            ],
          ),
        ),
      ],
    );
  }

  void sendMessage(StoryModel? storyModel) async {
    var userExist = await chatMessageService.checkUserStatus(
        senderId: getStringAsync(userId), receiverId: receiverUserId);
    ChatMessageModel data = ChatMessageModel();
    data.receiverId = receiverUserId;
    data.senderId = sender.uid;
    data.message = replyController.text.trim();
    data.isMessageRead = false;
    data.createdAt = DateTime.now().millisecondsSinceEpoch;
    data.isFromReply = false;
    data.isFromForward = false;
    if (storyModel != null) {
      data.messageType = STORY_REPLY;
      data.storyModel = storyModel;
      if (receiverUserId != null) {
        var isBlocked =
            await userService.isUserBlocked(widget.list?.first.userId ?? '');
        if (isBlocked) {
          data.isMessageRead = true;
          chatMessageService.addMessage(data).then((value) {
            replyController.clear();
            if (mounted) setState(() {});
          });
        } else {
          if (await chatRequestService.isRequestsUserExist(receiverUserId)) {
            sendNormalMessages(data);
          } else {
            if (userExist == false) {
              sendChatRequest(data);
            } else {
              sendNormalMessages(data);
            }
          }
          chatMessageService
              .getContactsDocument(
                  of: getStringAsync(userId), forContact: receiverUserId)
              .update(<String, dynamic>{
            "lastMessageTime": DateTime.now().millisecondsSinceEpoch,
          });
          chatMessageService
              .getContactsDocument(
                  of: receiverUserId, forContact: getStringAsync(userId))
              .update(<String, dynamic>{
            "lastMessageTime": DateTime.now().millisecondsSinceEpoch,
          });
        }
        //// Update Last Message
        print("Sending Message => ${data.message}");
        chatMessageService.updateLastMessage(
            senderId: getStringAsync(userId),
            text: encryptData(data.message!),
            receiverId: receiverUserId,
            isRequest: userExist == false ? true : false,
            timestamp: FieldValue.serverTimestamp(),
            isGroupMessage: false,
            isArchive: false);
      }
    }
  }

  void sendNormalMessages(ChatMessageModel data) async {
    ContactModel contactData = ContactModel();
    contactData.uid = receiverUserId;
    contactData.addedOn = Timestamp.now();
    contactData.lastMessageTime = DateTime.now().millisecondsSinceEpoch;
    chatMessageService
        .getContactsDocument(
            of: getStringAsync(userId), forContact: receiverUserId)
        .set(contactData.toJson())
        .then((value) {})
        .catchError((e, s) {
      log(e);
    });
    String? message = replyController.text.trim().validate();
    if (!(widget.oneSignalkey.isEmptyOrNull)) {
      notificationService
          .sendPushNotifications(
        getStringAsync(userDisplayName),
        message,
        recevierUid: receiverUserId,
        receiverPlayerId: widget.oneSignalkey,
      )
          .catchError((e) {
        print("erooor============${e.toString()}");
      });
    }
    replyController.clear();
    if (mounted) setState(() {});
    await chatMessageService.addMessage(data).then((value) async {
      await chatMessageService
          .addMessageToDb(
              senderDoc: value,
              data: data,
              sender: sender,
              image: null,
              isRequest: false)
          .then((value) {});
    }).catchError((e, s) {
      print("-----------817${e.toString()}");
      print("-----------818${s.toString()}");
    });
    userService.fireStore
        .collection(USER_COLLECTION)
        .doc(getStringAsync(userId))
        .collection(CONTACT_COLLECTION)
        .doc(receiverUserId)
        .update({
      'lastMessageTime': DateTime.now().millisecondsSinceEpoch
    }).catchError((e) {});
    userService.fireStore
        .collection(USER_COLLECTION)
        .doc(receiverUserId)
        .collection(CONTACT_COLLECTION)
        .doc(getStringAsync(userId))
        .update({
      'lastMessageTime': DateTime.now().millisecondsSinceEpoch
    }).catchError((e) {
      print("-----------674>>${e}");
    });
  }

  void sendChatRequest(ChatMessageModel data) async {
    String? message = replyController.text.trim().validate();
    if (!(widget.oneSignalkey.isEmptyOrNull)) {
      notificationService
          .sendPushNotifications(
        getStringAsync(userDisplayName),
        message,
        recevierUid: receiverUserId,
        receiverPlayerId: widget.oneSignalkey,
      )
          .catchError((e, s) {
        print("--------------933>>>>${e.toString()}");
        print("--------------934>>>>${s.toString()}");
      });
    }
    replyController.clear();
    ChatRequestModel chatReq = ChatRequestModel();
    chatReq.uid = getStringAsync(userId);
    chatReq.requestStatus = RequestStatus.Pending.index;
    chatReq.senderIdRef = userService.ref!.doc(sender.uid);
    chatReq.createdAt = DateTime.now().millisecondsSinceEpoch;
    chatReq.updatedAt = DateTime.now().millisecondsSinceEpoch;
    if (await chatRequestService.isRequestUserExist(
        sender.uid ?? "", receiverUserId)) {
      chatMessageService.addMessage(data).then((value) async {
        await chatMessageService
            .addMessageToDb(
                senderDoc: value,
                data: data,
                sender: sender,
                image: null,
                isRequest: true)
            .then((value) {
          chatMessageService.addToContacts(
              receiverId: receiverUserId, senderId: getStringAsync(userId));
          if (mounted) setState(() {});
        });
      });
    } else {
      chatRequestService
          .addChatWithCustomId(
              getStringAsync(userId), chatReq.toJson(), receiverUserId)
          .then((value) {})
          .catchError((e) {
        print("Chat Request Calling");
      });
      chatMessageService.addMessage(data).then((value) async {
        await chatMessageService
            .addMessageToDb(
                senderDoc: value,
                data: data,
                sender: sender,
                image: null,
                isRequest: true)
            .then((value) {});
        userService.fireStore
            .collection(USER_COLLECTION)
            .doc(getStringAsync(userId))
            .collection(CONTACT_COLLECTION)
            .doc(receiverUserId)
            .update({
          'lastMessageTime': DateTime.now().millisecondsSinceEpoch
        }).catchError((e) {
          if (mounted) setState(() {});
        });
        userService.fireStore
            .collection(USER_COLLECTION)
            .doc(receiverUserId)
            .collection(CONTACT_COLLECTION)
            .doc(getStringAsync(userId))
            .update({
          'lastMessageTime': DateTime.now().millisecondsSinceEpoch
        }).catchError((e) {
          if (mounted) setState(() {});
        });
      });
    }
  }
}
