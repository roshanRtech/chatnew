import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_mobx/flutter_mobx.dart';
import 'package:flutter_vector_icons/flutter_vector_icons.dart';
import 'package:intl/intl.dart';
import 'package:nb_utils/nb_utils.dart';
import 'package:path_provider/path_provider.dart';
import 'package:swipe_to/swipe_to.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:universal_file_viewer/universal_file_viewer.dart';
import 'package:http/http.dart' as http;

import 'package:chat/centralized_import.dart';

import '../../utils/TextStyles.dart' as TS;

class ChatItemWidget extends StatefulWidget {
  String? groupId;
  final ChatMessageModel? data;
  final bool isGroup;
  final String currentlySentAudioPath;
  final String? onSearchValueChanged;
  final Function(String?, String?, String?, bool?, String?, String?, String?,
      String?, String?, UserModel?, String?, String?, String?)? onArrowSearch;

  final bool? isFromReply;
  final bool? isFromForward;
  final String? receiverName;
  final String? messageId;
  final bool? isAdminAV;

  ChatItemWidget(
      {this.groupId,
      this.data,
      this.isGroup = false,
      this.currentlySentAudioPath = "",
      this.isAdminAV,
      this.onSearchValueChanged,
      this.onArrowSearch,
      this.isFromForward,
      this.isFromReply,
      this.receiverName,
      this.messageId});

  @override
  _ChatItemWidgetState createState() => _ChatItemWidgetState();
}

class _ChatItemWidgetState extends State<ChatItemWidget> {
  String? images;
  UserModel userModel = UserModel();
  String replyMessage = "";
  String replyMessageType = "";
  bool isReplying = false;
  String messageID = "";
  String receiverName = "";
  String replyLatitude = "";
  String replyLongitude = "";
  bool? isDeletedForMe;
  Future<File?>? _filePreviewFuture;

  void initState() {
    super.initState();
    init();
    if (widget.data!.photoUrl != null &&
        widget.data!.photoUrl!.isNotEmpty &&
        widget.data!.messageType == DOC) {
      _filePreviewFuture = getCachedDocument(widget.data!.photoUrl!,
          widget.data?.documentName ?? 'doc_${widget.data!.id}');
    }

    print("sender: ${widget.data?.senderId}");
    print("currentUser: ${getStringAsync(userId)}");
    print("delete_for_sender: ${widget.data?.delete_for_sender}");
  }

  init() async {
    print("=================== Chat item Screen ===============");
    print("Chat Item Widget Data Id Is ===> " + widget.data!.id.toString());

    /// Dunmp Data ion print
    log("Data Dump ${widget.data!.toJson()}");

    print("My Usrer id ==>" + getStringAsync(userId).toString());
    print("Receiver id Is ==>");
    print("Sender id Is ==> ${widget.data!.senderId}");
    appStore.isLoading = true;

    await userService.getUserById(val: widget.data!.senderId).then((value) {
      userModel = value;
      appStore.isLoading = false;
    });

    setState(() {});

    print("Init Time Id Is ===> " + widget.data!.id.toString());
    print("Is From Group ==>" + widget.isGroup.toString());
  }

  void sendMessagesData(
      message,
      replyMsg,
      replyMsgType,
      isFrom,
      messageID,
      receiverName,
      sId,
      replyLatitude,
      replyLongitude,
      userShareData,
      groupName,
      groupId,
      groupProfile) {
    widget.onArrowSearch!(
        message,
        replyMessage,
        replyMessageType,
        isFrom,
        messageID,
        receiverName,
        sId,
        replyLatitude,
        replyLongitude,
        userShareData,
        groupName,
        groupId,
        groupProfile);
  }

  void replyToMessage(ChatMessageModel message, bool isFromMe, String mId,
      String senderId, UserModel? userShareData) {
    print("-------------82>>${message.messageType}");
    if (message.messageType == IMAGE ||
        message.messageType == VIDEO ||
        message.messageType == VOICE_NOTE ||
        message.messageType == STICKER ||
        message.messageType == DOC ||
        message.messageType == AUDIO) {
      replyMessage = message.photoUrl.toString();
    } else if (message.messageType == LOCATION &&
        message.currentLat != null &&
        message.currentLong != null) {
      replyLatitude = message.currentLat!;
      replyLongitude = message.currentLong!;
    } else {
      replyMessage = message.message.toString();
    }
    isReplying = true;
    messageID = mId;
    replyMessageType = message.messageType.toString();
    if (userModel.uid == senderId) {
      receiverName = userModel.name.toString();
    }

    print("-------------109>>${replyMessage.toString()}");

    sendMessagesData(
        widget.onArrowSearch.toString(),
        replyMessage.toString(),
        replyMessageType,
        isReplying,
        messageID,
        receiverName,
        senderId,
        replyLatitude,
        replyLongitude,
        userShareData,
        message.groupName,
        message.groupId,
        message.groupProfile);
    setState(() {});
  }

  @override
  void setState(fn) {
    if (mounted) super.setState(fn);
  }

  Future<File?> getCachedDocument(String url, String documentName) async {
    final dir = await getTemporaryDirectory();
    final file = File('${dir.path}/$documentName');

    if (await file.exists()) {
      return file;
    } else {
      return await downloadFile(url, documentName);
    }
  }

  Future<File?> downloadFile(String url, String fileName) async {
    try {
      final response = await http.get(Uri.parse(url));
      if (response.statusCode == 200) {
        final dir = await getTemporaryDirectory();
        final file = File('${dir.path}/$fileName');
        await file.writeAsBytes(response.bodyBytes);
        return file;
      }
      return null;
    } catch (e) {
      print("Download error: $e");
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    String time;
    DateTime date =
        DateTime.fromMicrosecondsSinceEpoch(widget.data!.createdAt! * 1000);
    if (date.day == DateTime.now().day) {
      time = DateFormat('hh:mm a').format(
          DateTime.fromMicrosecondsSinceEpoch(widget.data!.createdAt! * 1000));
    } else {
      time = DateFormat('dd-MM-yyy hh:mm a').format(
          DateTime.fromMicrosecondsSinceEpoch(widget.data!.createdAt! * 1000));
    }

    EdgeInsetsGeometry customPadding(String? messageTypes) {
      switch (messageTypes) {
        case TEXT:
          return EdgeInsets.symmetric(horizontal: 12, vertical: 8);
        case IMAGE:
        case VIDEO:
        case DOC:
        case LOCATION:
        case AUDIO:
          return EdgeInsets.symmetric(horizontal: 4, vertical: 4);
        default:
          return EdgeInsets.symmetric(horizontal: 4, vertical: 4);
      }
    }

    EdgeInsetsGeometry customPaddingReply(String? messageTypes) {
      switch (messageTypes) {
        case TEXT:
          return EdgeInsets.only(right: 12, left: 12, bottom: 8);
        case IMAGE:
        case VIDEO:
        case DOC:
        case LOCATION:
        case AUDIO:
          return EdgeInsets.symmetric(horizontal: 4, vertical: 4);
        default:
          return EdgeInsets.symmetric(horizontal: 4, vertical: 4);
      }
    }

    Widget chatItem(String? messageTypes) {
      print("-------------198>>${messageTypes}");
      isDeletedForMe =
          widget.data?.deletedFor?.contains(getStringAsync(userId)) ?? false;

      switch (messageTypes) {
        case TEXT:
          return TextChatComponent(
            data: widget.data!,
            time: time,
            isDeletedForMe: isDeletedForMe,
            onSearchValueChanged: widget.onSearchValueChanged,
          );

        case IMAGE:
          return ImageChatComponent(
              data: widget.data!, isDeletedForMe: isDeletedForMe, time: time);

        case SHAREPROFILE:
          return ShareChatComponent(
              data: widget.data!, isDeletedForMe: isDeletedForMe, time: time);

        case VOICE_NOTE:
          return AudioPlayComponent(
            data: widget.data,
            time: time,
            isDeletedForMe: isDeletedForMe,
          );

        case STORY_REPLY:
          return statusChatComponent(
            data: widget.data,
            time: time,
            isDeletedForMe: isDeletedForMe,
          );

        case VIDEO:
          return VideoChatComponent(
              data: widget.data!, time: time, isDeletedForMe: isDeletedForMe);

        case DOC:
          if (isDeletedForMe == true) {
            return Padding(
              padding: const EdgeInsets.all(6),
              child: Text('you_delete_msg'.translate,
                  style: TS.primaryTextStyle(color: Colors.grey)),
            );
          }

          if (widget.data?.isDeleted == true) {
            return Padding(
              padding: const EdgeInsets.all(6),
              child: Text('this_delete_msg'.translate,
                  style: TS.primaryTextStyle(color: Colors.grey)),
            );
          }

          return SizedBox(
            width: context.width() - 48,
            child: Column(
              children: [
                // Document preview container
                Container(
                  height: 300,
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.grey.shade300),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: FutureBuilder<File?>(
                    future: _filePreviewFuture,
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return Center(child: CircularProgressIndicator());
                      } else if (snapshot.hasError || snapshot.data == null) {
                        return Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Ionicons.document,
                                  size: 50, color: Colors.grey),
                              // Text('Preview not available', style: TS.secondaryTextStyle()),
                            ],
                          ),
                        );
                      } else {
                        return UniversalFileViewer(
                          backgroundColor: Colors.grey.shade100,
                          file: snapshot.data!,
                        );
                      }
                    },
                  ),
                ),
                8.height,
                // // Document name and info
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        widget.data?.documentName ?? '',
                        style: TS.secondaryTextStyle(color: Colors.white),
                      ),
                    ),
                    Row(
                      children: [
                        2.width,
                        if (widget.data!.isMe!)
                          Icon(
                            (widget.data!.isMessageRead == 0 ||
                                    widget.data!.isMessageRead == 2)
                                ? Icons.done
                                : Icons.done_all,
                            size: 12,
                            color: (widget.data!.isMessageRead == 0 ||
                                    widget.data!.isMessageRead == 2)
                                ? Colors.blueGrey
                                : primaryColor,
                          ),
                      ],
                    ),
                  ],
                ).onTap(() async {
                  if (!widget.data!.photoUrl.validate().isEmptyOrNull) {
                    await launchUrl(
                      Uri.parse(widget.data?.photoUrl ?? ''),
                      mode: isIOS
                          ? LaunchMode.platformDefault
                          : LaunchMode.externalNonBrowserApplication,
                    ).catchError((e) {
                      log(e);
                      toast('lbl_invalid_url'.translate);
                    });
                  } else {
                    toast("This document is not found");
                  }
                }),
                10.height,

                Align(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      Text(
                        time,
                        style: TS.secondaryTextStyle(color: Colors.white),
                      ),
                      2.width,
                      widget.data!.isMe!
                          ? (widget.data!.isMessageRead == 0 ||
                                  widget.data!.isMessageRead == 2)
                              ? Icon(Icons.done,
                                  size: 16, color: Colors.blueGrey)
                              : Icon(Icons.done_all,
                                  size: 16, color: primaryColor)
                          : Offstage(),
                      8.width,
                    ],
                  ),
                ),
                if (widget.data?.groupReaction != null &&
                    widget.data!.groupReaction!.isNotEmpty)
                  Align(
                    alignment: Alignment.bottomLeft,
                    child: Padding(
                      padding: const EdgeInsets.only(left: 5, bottom: 5),
                      child: SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          children: widget.data!.groupReaction!.map((entry) {
                            return !entry.reaction.isEmptyOrNull
                                ? Container(
                                    margin:
                                        const EdgeInsets.only(top: 4, right: 6),
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 8, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: Colors.grey.shade100,
                                      borderRadius: BorderRadius.circular(16),
                                      border: Border.all(
                                          color: Colors.grey.shade300,
                                          width: 1),
                                      boxShadow: [
                                        BoxShadow(
                                          color: Colors.black.withOpacity(0.05),
                                          blurRadius: 2,
                                          offset: Offset(0, 1),
                                        ),
                                      ],
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Text(
                                          entry.reaction ?? '',
                                          style: TS.boldTextStyle(),
                                        ),
                                      ],
                                    ),
                                  )
                                : SizedBox.shrink();
                          }).toList(),
                        ),
                      ),
                    ),
                  ).onTap(() {
                    showReactionBottomSheet(
                        context, widget.data?.groupReaction);
                  }),
              ],
            ).onTap(() async {
              if (!widget.data!.photoUrl.validate().isEmptyOrNull) {
                await launchUrl(
                  Uri.parse(widget.data?.photoUrl ?? ''),
                  mode: isIOS
                      ? LaunchMode.platformDefault
                      : LaunchMode.externalNonBrowserApplication,
                ).catchError((e) {
                  log(e);
                  toast('lbl_invalid_url'.translate);
                  return false;
                });
              } else {
                toast("This document is not found");
              }
            }),
          );

        case AUDIO:
          return AudioPlayComponent(
              data: widget.data, time: time, isDeletedForMe: isDeletedForMe);

        case LOCATION:
          if (isDeletedForMe == true) {
            return Padding(
              padding: const EdgeInsets.all(6),
              child: Text('you_delete_msg'.translate,
                  style: TS.primaryTextStyle(color: Colors.grey)),
            );
          }

          if (widget.data?.isDeleted == true) {
            return Padding(
              padding: const EdgeInsets.all(6),
              child: Text('this_delete_msg'.translate,
                  style: TS.primaryTextStyle(color: Colors.grey)),
            );
          }

          return Container(
            height: 250,
            width: 250,
            child: Stack(
              children: [
                Image.asset(
                  'assets/map_image.jpeg',
                  height: 245,
                  width: 250,
                  fit: BoxFit.cover,
                ).cornerRadiusWithClipRRect(12).onTap(() async {
                  final url =
                      'https://www.google.com/maps/search/?api=1&query=${widget.data?.currentLat},${widget.data?.currentLong}';
                  await launchUrl(Uri.parse(url));
                }),
                Align(
                  alignment:
                      isRTL ? Alignment.bottomLeft : Alignment.bottomRight,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(time,
                          style: TS.primaryTextStyle(
                              color: Colors.blueGrey,
                              size: (appStore.fontSize - 4).toInt())),
                      2.width,
                      if (widget.data!.isMe!)
                        widget.data!.isMessageRead == false
                            ? Icon(Icons.done, size: 16, color: Colors.blueGrey)
                            : Icon(Icons.done_all,
                                size: 16,
                                color: appStore.isDarkMode
                                    ? textPrimaryColor
                                    : primaryColor),
                      8.width,
                    ],
                  ).paddingBottom(8),
                ),
                if (widget.data?.groupReaction != null &&
                    widget.data!.groupReaction!.isNotEmpty)
                  Align(
                    alignment: Alignment.bottomLeft,
                    child: Padding(
                      padding: const EdgeInsets.only(left: 5, bottom: 5),
                      child: SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          children: widget.data!.groupReaction!.map((entry) {
                            return !entry.reaction.isEmptyOrNull
                                ? Container(
                                    margin:
                                        const EdgeInsets.only(top: 4, right: 6),
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 8, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: Colors.grey.shade100,
                                      borderRadius: BorderRadius.circular(16),
                                      border: Border.all(
                                          color: Colors.grey.shade300,
                                          width: 1),
                                      boxShadow: [
                                        BoxShadow(
                                          color: Colors.black.withOpacity(0.05),
                                          blurRadius: 2,
                                          offset: Offset(0, 1),
                                        ),
                                      ],
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Text(
                                          entry.reaction ?? '',
                                          style: TS.boldTextStyle(),
                                        ),
                                      ],
                                    ),
                                  )
                                : SizedBox.shrink();
                          }).toList(),
                        ),
                      ),
                    ),
                  ).onTap(() {
                    showReactionBottomSheet(
                        context, widget.data?.groupReaction);
                  }),
              ],
            ),
          );

        case STICKER:
          return StickerChatComponent(
              data: widget.data!,
              time: time,
              padding: customPadding(messageTypes),
              isDeletedForMe: isDeletedForMe);

        default:
          return Container();
      }
    }

    return Observer(
      builder: (_) => (getStringAsync(userId).toString() ==
                  widget.data?.senderId &&
              widget.data?.delete_for_sender == true)
          ? SizedBox.shrink()
          : widget.data?.messageType == ADD_REMOVE_GROUP
              ? Padding(
                  padding:
                      const EdgeInsets.symmetric(vertical: 5, horizontal: 20),
                  child: Container(
                    padding: EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                    decoration: BoxDecoration(
                      color: appStore.isDarkMode
                          ? Colors.white.withOpacity(0.1)
                          : Colors.black.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(5),
                    ),
                    child: Text(
                      widget.data?.addRemoveStatus ?? '',
                      style: TS.boldTextStyle(size: appStore.fontSize - 2),
                      textAlign: TextAlign.center,
                    ),
                  ),
                )
              : GestureDetector(
                  onLongPress: () async {
                    print(
                        " =========================================== START =================================== ");
                    print("-------------285>>${widget.isAdminAV}");
                    if (isDeletedForMe == false &&
                        widget.data?.isDeleted == false &&
                        (widget.isAdminAV == false ||
                            widget.isAdminAV == null)) {
                      await showInDialog(
                        context,
                        builder: (p0) {
                          return SelectedMessageComponentDialog(
                            widget.isGroup,
                            widget.data!,
                            widget.data?.isMe,
                            widget.data?.id,
                            widget.data?.senderId,
                            widget.isAdminAV,
                            userModel,
                            groupId: widget.groupId,
                            () {
                              print('dggdfgdfgdfgdfg');
                              replyToMessage(
                                  widget.data!,
                                  widget.data?.isMe ?? false,
                                  widget.data?.id ?? '',
                                  widget.data?.senderId ?? '',
                                  widget.data?.shareUser);
                            },
                            onReaction: (emoji, isGroup) async {
                              print("Selected Emoji: $emoji");
                              print("Selected isGroup: $isGroup");
                              if (isGroup == true) {
                                if (emoji.isEmptyOrNull) {
                                  groupChatMessageService
                                      .removeReaction(
                                          groupChatId:
                                              getStringAsync(CURRENT_GROUP_ID),
                                          reaction: emoji,
                                          documentId: widget.data?.id ?? '')
                                      .then((value) {
                                    //
                                  }).catchError(
                                    (e) {
                                      log("Error:" + e.toString());
                                    },
                                  );
                                } else {
                                  final reactionModel = await ReactionModel(
                                    uid: getStringAsync(userId),
                                    userName: getStringAsync(userDisplayName),
                                    image: getStringAsync(userPhotoUrl),
                                    reaction: emoji,
                                    createdAt:
                                        DateTime.now().millisecondsSinceEpoch,
                                  );
                                  groupChatMessageService
                                      .addReaction(
                                          groupChatId: widget.groupId ?? '',
                                          reactionModel: reactionModel,
                                          documentId: widget.data?.id ?? '')
                                      .then((value) {})
                                      .catchError(
                                    (e) {
                                      log("Error:" + e.toString());
                                    },
                                  );
                                }
                              } else {
                                if (emoji.isEmptyOrNull) {
                                  chatMessageService
                                      .removeReaction(
                                    docId2: widget.data?.id2 ?? '',
                                    documentId: widget.data?.id ?? '',
                                    senderId: widget.data?.senderId ?? '',
                                    receiverId: widget.data?.receiverId ?? '',
                                  )
                                      .then((value) {
                                    //
                                  }).catchError(
                                    (e) {
                                      log("Error:" + e.toString());
                                    },
                                  );
                                } else {
                                  final reactionModel = await ReactionModel(
                                    uid: getStringAsync(userId),
                                    userName: getStringAsync(userDisplayName),
                                    image: getStringAsync(userPhotoUrl),
                                    reaction: emoji,
                                    createdAt:
                                        DateTime.now().millisecondsSinceEpoch,
                                  );
                                  print(
                                      "---------->>${reactionModel.toJson()}");
                                  chatMessageService
                                      .addReaction(
                                          docId2: widget.data?.id2 ?? '',
                                          documentId: widget.data?.id ?? '',
                                          senderId: widget.data?.senderId ?? '',
                                          receiverId:
                                              widget.data?.receiverId ?? '',
                                          reaction: reactionModel)
                                      .then((value) {
                                    //
                                  }).catchError(
                                    (e) {
                                      log("Error:" + e.toString());
                                    },
                                  );
                                }
                              }

                              setState(() {});
                            },
                          );
                        },
                        contentPadding: EdgeInsets.zero,
                        dialogAnimation: DialogAnimation.SLIDE_TOP_BOTTOM,
                      );
                    }
                  },
                  child: SwipeTo(
                    onRightSwipe: (details) {
                      if (isDeletedForMe == true ||
                          widget.data?.isDeleted == true) return;
                      replyToMessage(
                          widget.data!,
                          widget.data!.isMe!,
                          widget.data!.id!,
                          widget.data!.senderId!,
                          widget.data?.shareUser);
                    },
                    child: Container(
                      alignment: widget.data!.isMe.validate()
                          ? Alignment.centerRight
                          : Alignment.centerLeft,
                      color: Colors.transparent,
                      width: double.infinity,
                      child: Container(
                        alignment: widget.data!.isMe.validate()
                            ? Alignment.centerRight
                            : Alignment.centerLeft,
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: widget.data!.isMe.validate()
                              ? CrossAxisAlignment.end
                              : CrossAxisAlignment.start,
                          mainAxisAlignment: widget.data!.isMe!
                              ? MainAxisAlignment.end
                              : MainAxisAlignment.start,
                          children: [
                            //Reply Container
                            if (widget.data?.replyMessageType == LOCATION
                                ? widget.data?.replyLocation != null &&
                                    widget.data?.replyLocation == true &&
                                    !(widget.data?.currentLat.isEmptyOrNull ??
                                        false) &&
                                    !(widget.data?.currentLong.isEmptyOrNull ??
                                        false)
                                : widget.data!.isMe != null &&
                                    widget.data != null &&
                                    !(widget.data?.replyMessage.isEmptyOrNull ??
                                        false) &&
                                    widget.data?.replyMessage == SHAREPROFILE &&
                                    isDeletedForMe == false)
                              Container(
                                margin: widget.data!.isMe.validate()
                                    ? EdgeInsets.only(
                                        left:
                                            isRTL ? 0 : context.width() * 0.25,
                                      )
                                    : EdgeInsets.only(
                                        top: !(widget.data?.replyMessage
                                                    .isEmptyOrNull ??
                                                false)
                                            ? 0
                                            : 2.0,
                                        right:
                                            isRTL ? 0 : context.width() * 0.25),

                                child: Container(
                                  decoration: boxDecorationWithRoundedCorners(
                                    backgroundColor: appStore.isDarkMode
                                        ? Colors.transparent.withOpacity(0.2)
                                        : Colors.transparent.withOpacity(0.1),
                                  ),
                                  child: Row(
                                    children: [
                                      Column(
                                        children: [
                                          if (widget.isGroup)
                                            Text(
                                              /*  !(widget.data?.replyMessageSenderName.isEmptyOrNull ?? false) && widget.data!.isMe!
                                              ? widget.data?.replyMessageSenderName == getStringAsync(userDisplayName)
                                                  ? 'you'.translate
                                                  : widget.data!.replyMessageSenderName.toString()
                                              : (widget.data!.replyMessageSenderName.isEmptyOrNull) ? 'you'.translate :  widget.data?.replyMessageSenderName == getStringAsync(userDisplayName)
                                             ? 'you'.translate
                                             : widget.data!.replyMessageSenderName.toString(),*/
                                              (widget.data?.replyMessageSenderName
                                                          .isEmptyOrNull ??
                                                      true)
                                                  ? 'you'.translate
                                                  : (widget.data
                                                              ?.replyMessageSenderName ==
                                                          getStringAsync(
                                                              userDisplayName))
                                                      ? 'you'.translate
                                                      : widget.data!
                                                          .replyMessageSenderName!,
                                              style: TS.primaryTextStyle(
                                                  color: primaryColor,
                                                  weight: FontWeight.bold),
                                            ),
                                          if (!widget.isGroup)
                                            Text(
                                              widget.data?.replyMessageSenderName ==
                                                      getStringAsync(
                                                          userDisplayName)
                                                  ? 'you'.translate
                                                  : widget.data
                                                          ?.replyMessageSenderName ??
                                                      '',
                                              style: TS.primaryTextStyle(
                                                  color: primaryColor,
                                                  weight: FontWeight.bold),
                                            ),
                                          if (widget.data?.replyMessageType !=
                                                  TEXT &&
                                              widget.data?.replyMessageType !=
                                                  SHAREPROFILE)
                                            Row(
                                              children: [
                                                getIconForMessageType(widget
                                                        .data
                                                        ?.replyMessageType ??
                                                    ''),
                                                Text(
                                                  ' ${widget.data?.replyMessageType.capitalizeEachWord().toString()} ',
                                                  style:
                                                      TS.secondaryTextStyle(),
                                                ),
                                              ],
                                            ),
                                          if (widget.data?.replyMessageType ==
                                              TEXT)
                                            Row(
                                              children: [
                                                Text(
                                                  decryptedData(widget
                                                          .data?.replyMessage
                                                          .toString() ??
                                                      ''),
                                                  style:
                                                      TS.secondaryTextStyle(),
                                                ).expand(),
                                              ],
                                            ),
                                          if (widget.data?.replyMessageType ==
                                              SHAREPROFILE)
                                            Padding(
                                              padding: const EdgeInsets.all(2),
                                              child: Row(
                                                children: [
                                                  cachedImage(
                                                          !(widget
                                                                      .data
                                                                      ?.groupProfile
                                                                      .isEmptyOrNull ??
                                                                  false)
                                                              ? widget.data
                                                                      ?.groupProfile ??
                                                                  ''
                                                              : widget
                                                                  .data
                                                                  ?.shareUser
                                                                  ?.photoUrl
                                                                  .validate(),
                                                          height: 30,
                                                          width: 30,
                                                          fit: BoxFit.cover)
                                                      .cornerRadiusWithClipRRect(
                                                          50),
                                                  5.width,
                                                  Text(
                                                    !(widget.data?.groupName
                                                                .isEmptyOrNull ??
                                                            false)
                                                        ? widget.data
                                                                ?.groupName ??
                                                            ''
                                                        : widget.data?.shareUser
                                                                ?.name ??
                                                            '',
                                                    style:
                                                        TS.secondaryTextStyle(),
                                                  ).expand(),
                                                ],
                                              ),
                                            ),
                                        ],
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                      ).expand(),
                                      Stack(
                                        alignment: Alignment.topRight,
                                        children: [
                                          getViewForMessageType(
                                            widget.data?.replyMessageType ?? '',
                                            widget.data?.replyMessage ?? '',
                                          ).cornerRadiusWithClipRRectOnly(
                                              topRight: 8, bottomRight: 8),
                                        ],
                                      ),
                                    ],
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                  ).paddingOnly(
                                      left: 8,
                                      right: 8,
                                      bottom:
                                          widget.data!.replyMessageType == TEXT
                                              ? 4
                                              : 0),
                                ).paddingAll(8),
                                // width: context.width() * 0.25,
                                decoration: boxDecorationWithRoundedCorners(
                                  borderRadius: widget.data?.replyMessageType ==
                                          LOCATION
                                      ? BorderRadius.only(
                                          topLeft: Radius.circular(8),
                                          bottomLeft: widget.data?.replyMessageType ==
                                                      LOCATION &&
                                                  !widget.data!.isMe!
                                              ? Radius.circular(0)
                                              : Radius.circular(8),
                                          topRight: Radius.circular(8),
                                          bottomRight:
                                              widget.data?.replyMessageType == LOCATION &&
                                                      !widget.data!.isMe!
                                                  ? Radius.circular(8)
                                                  : Radius.circular(0))
                                      : widget.data != null &&
                                              !(widget.data?.replyMessage?.isEmptyOrNull ??
                                                  false)
                                          ? widget.data!.isMe!
                                              ? BorderRadius.only(
                                                  topLeft: Radius.circular(8),
                                                  bottomLeft:
                                                      Radius.circular(8),
                                                  topRight: Radius.circular(8))
                                              : BorderRadius.only(
                                                  topLeft: Radius.circular(8),
                                                  bottomRight: Radius.circular(8),
                                                  topRight: Radius.circular(8))
                                          : null,
                                  backgroundColor: widget.data!.isMe!
                                      ? senderMessageColor
                                      : context.cardColor,
                                ),
                              )
                                  .paddingOnly(left: 8, right: 8)
                                  .visible(isDeletedForMe == false),

                            ///Normal Msg Container

                            Stack(
                              alignment: Alignment.centerLeft,
                              fit: StackFit.loose,
                              children: [
                                // if (widget.data?.messageType !=
                                //         MessageType.STICKER.name &&
                                //     (widget.data?.replyMessageType ==
                                //             LOCATION ||
                                //         widget.data?.replyMessageType ==
                                //             SHAREPROFILE) &&
                                //     (isDeletedForMe == false))
                                Container(
                                  margin: widget.data!.isMe.validate()
                                      ? EdgeInsets.only(
                                          left: isRTL
                                              ? 0
                                              : context.width() * 0.25,
                                          right: 8)
                                      : EdgeInsets.only(
                                          top: widget.data?.replyMessageType ==
                                                      LOCATION &&
                                                  isDeletedForMe == true
                                              ? 0
                                              : !(widget.data?.replyMessage
                                                              .isEmptyOrNull ??
                                                          false) &&
                                                      isDeletedForMe == false
                                                  ? 0
                                                  : 2.0,
                                          bottom: 2.0,
                                          left: 8,
                                          right: isRTL
                                              ? 0
                                              : context.width() * 0.25),
                                  padding:
                                      widget.data?.replyMessageType == LOCATION
                                          ? customPaddingReply(
                                              widget.data?.messageType)
                                          : !(widget.data?.replyMessage
                                                      .isEmptyOrNull ??
                                                  false)
                                              ? customPaddingReply(
                                                  widget.data?.messageType)
                                              : customPadding(
                                                  widget.data?.messageType),
                                  decoration: widget.data?.messageType !=
                                          MessageType.STICKER.name
                                      ? BoxDecoration(
                                          boxShadow: appStore.isDarkMode
                                              ? null
                                              : widget.data?.replyMessageType ==
                                                          LOCATION ||
                                                      widget.data?.replyMessageType ==
                                                              SHAREPROFILE &&
                                                          (isDeletedForMe ==
                                                              false)
                                                  ? null
                                                  : widget.data != null &&
                                                          !(widget
                                                                  .data
                                                                  ?.replyMessage
                                                                  .isEmptyOrNull ??
                                                              false) &&
                                                          isDeletedForMe ==
                                                              false
                                                      ? null
                                                      : defaultBoxShadow(),
                                          color: widget.data!.isMe.validate()
                                              ? appStore.isDarkMode
                                                  ? primaryColor
                                                  : senderMessageColor
                                              : context.cardColor,
                                          borderRadius: widget.data!.isMe
                                                  .validate()
                                              ? radiusOnly(
                                                  bottomLeft: chatMsgRadius,
                                                  topLeft: widget.data
                                                                  ?.replyMessageType ==
                                                              LOCATION &&
                                                          isDeletedForMe ==
                                                              false
                                                      ? 0
                                                      : widget.data != null &&
                                                              !(widget
                                                                      .data
                                                                      ?.replyMessage
                                                                      .isEmptyOrNull ??
                                                                  false) &&
                                                              isDeletedForMe ==
                                                                  false
                                                          ? 0
                                                          : chatMsgRadius,
                                                  bottomRight: chatMsgRadius,
                                                  topRight: 0)
                                              : radiusOnly(
                                                  bottomLeft: chatMsgRadius,
                                                  topLeft: 0,
                                                  bottomRight: chatMsgRadius,
                                                  topRight: widget.data
                                                                  ?.replyMessageType ==
                                                              LOCATION &&
                                                          isDeletedForMe ==
                                                              false
                                                      ? 0
                                                      : widget.data != null &&
                                                              !(widget
                                                                      .data
                                                                      ?.replyMessage
                                                                      .isEmptyOrNull ??
                                                                  false) &&
                                                              !widget.data!
                                                                  .isMe! &&
                                                              isDeletedForMe ==
                                                                  false
                                                          ? 0
                                                          : chatMsgRadius),
                                        )
                                      : null,
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      if (widget.data!.isFromForward == true)
                                        Row(
                                          mainAxisSize: MainAxisSize.min,
                                          // mainAxisAlignment: MainAxisAlignment.start  ,
                                          children: [
                                            Image.asset(
                                              color: textSecondaryColorGlobal,
                                              ic_forward,
                                              height: 18,
                                              width: 18,
                                            ),
                                            8.width,
                                            Text(
                                              'forwarded'.translate,
                                              style: TS.secondaryTextStyle(
                                                  fontStyle: FontStyle.italic),
                                            )
                                          ],
                                        ),
                                      if (widget.isGroup &&
                                          !widget.data!.isMe.validate())
                                        StreamBuilder<DocumentSnapshot>(
                                          stream: FirebaseFirestore.instance
                                              .collection('users')
                                              .doc(widget.data!.senderId)
                                              .snapshots(),
                                          builder: (context, snapshot) {
                                            if (!snapshot.hasData)
                                              return Text("...");
                                            final user = snapshot.data!;
                                            if (!user.exists)
                                              return Text(
                                                      'deletedAccount'
                                                          .translate,
                                                      style: TS.boldTextStyle(
                                                          color: primaryColor))
                                                  .paddingAll(1);
                                            return Text(user['name'],
                                                    style: TS.boldTextStyle(
                                                        color: primaryColor))
                                                .paddingAll(1);
                                          },
                                        ),
                                      if (widget.isGroup &&
                                          userModel.name != null &&
                                          !widget.data!.isMe.validate())
                                        4.height,
                                      chatItem(widget.data?.messageType)
                                    ],
                                  ),
                                ),
                              ],
                              // child:
                            ),
                          ],
                        ).paddingOnly(bottom: 2, top: 2),
                      ),
                    ),
                  )),
    );
  }
}
