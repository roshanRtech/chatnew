import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_vector_icons/flutter_vector_icons.dart';
import 'package:intl/intl.dart';
import 'package:nb_utils/nb_utils.dart';

import 'package:chat/centralized_import.dart';

import '../../utils/TextStyles.dart' as TS;

class LastMessageContainer extends StatelessWidget {
  final bool isGroup;
  final stream;

  LastMessageContainer({required this.stream, this.isGroup = false});

  Widget typeWidget(ChatMessageModel message) {
    var isDeletedForMe =
        message.deletedFor?.contains(getStringAsync(userId)) ?? false;
    String? type = message.messageType;
    String? displayMessage;

    // print("-----22>>${type}");
    // print("-----26>>${decryptedData(message.message.validate())}");
    switch (type) {
      case TEXT:
        if (!isDeletedForMe && message.isDeleted == false) {
          displayMessage = message.isEncrypt == true
              ? decryptedData(message.message ?? "")
              : message.message;
        } else {
          displayMessage = message.isDeleted == true
              ? 'this_delete_msg'.translate
              : 'you_delete_msg'.translate;
        }

        return RichText(
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          text: buildMessageLastMsg(displayMessage ?? ''),
        ).expand();

      case IMAGE:
        if (!isDeletedForMe && message.isDeleted == false) {
          return Row(
            children: [
              Icon(Icons.photo_sharp, size: 16, color: textSecondaryColor),
              4.width,
              Text('image'.translate, style: TS.secondaryTextStyle()),
            ],
          );
        } else {
          var displayImgMessage = isDeletedForMe
              ? 'you_delete_msg'.translate
              : 'this_delete_msg'.translate;

          return Text(
            displayImgMessage,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TS.secondaryTextStyle(),
          );
        }
      case VIDEO:
        if (!isDeletedForMe && message.isDeleted == false) {
          return Row(
            children: [
              Icon(Icons.videocam_outlined,
                  size: 16, color: textSecondaryColor),
              4.width,
              Text('video'.translate, style: TS.secondaryTextStyle()),
            ],
          );
        } else {
          var displayImgMessage = isDeletedForMe
              ? 'you_delete_msg'.translate
              : 'this_delete_msg'.translate;

          return Text(
            displayImgMessage,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TS.secondaryTextStyle(),
          );
        }

      case AUDIO:
        if (!isDeletedForMe && message.isDeleted == false) {
          return Row(
            children: [
              Icon(Icons.audiotrack, size: 16, color: textSecondaryColor),
              4.width,
              Text('audio'.translate, style: TS.secondaryTextStyle()),
            ],
          );
        } else {
          var displayImgMessage = isDeletedForMe
              ? 'you_delete_msg'.translate
              : 'this_delete_msg'.translate;

          return Text(
            displayImgMessage,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TS.secondaryTextStyle(),
          );
        }

      case SHAREPROFILE:
        if (!isDeletedForMe && message.isDeleted == false) {
          return Row(
            children: [
              Icon(Icons.person, size: 16, color: textSecondaryColor),
              4.width,
              Text('Profile', style: TS.secondaryTextStyle()),
            ],
          );
        } else {
          var displayImgMessage = isDeletedForMe
              ? 'you_delete_msg'.translate
              : 'this_delete_msg'.translate;

          return Text(
            displayImgMessage,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TS.secondaryTextStyle(),
          );
        }

      case STORY_REPLY:
        if (!isDeletedForMe && message.isDeleted == false) {
          return Row(
            children: [
              Icon(Icons.add_circle_outline,
                  size: 16, color: textSecondaryColor),
              4.width,
              Text('Story', style: TS.secondaryTextStyle()),
            ],
          );
        } else {
          var displayImgMessage = isDeletedForMe
              ? 'you_delete_msg'.translate
              : 'this_delete_msg'.translate;

          return Text(
            displayImgMessage,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TS.secondaryTextStyle(),
          );
        }

      case DOC:
        if (!isDeletedForMe && message.isDeleted == false) {
          return Row(
            children: [
              Icon(FontAwesome.file, size: 16, color: textSecondaryColor),
              4.width,
              Text('document'.translate, style: TS.secondaryTextStyle()),
            ],
          );
        } else {
          var displayImgMessage = isDeletedForMe
              ? 'you_delete_msg'.translate
              : 'this_delete_msg'.translate;

          return Text(
            displayImgMessage,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TS.secondaryTextStyle(),
          );
        }
      case LOCATION:
        if (!isDeletedForMe && message.isDeleted == false) {
          return Row(
            children: [
              Icon(Icons.location_on, size: 16, color: textSecondaryColor),
              4.width,
              Text('location'.translate, style: TS.secondaryTextStyle()),
            ],
          );
        } else {
          var displayImgMessage = isDeletedForMe
              ? 'you_delete_msg'.translate
              : 'this_delete_msg'.translate;

          return Text(
            displayImgMessage,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TS.secondaryTextStyle(),
          );
        }

      case VOICE_NOTE:
        if (!isDeletedForMe && message.isDeleted == false) {
          return Row(
            children: [
              Icon(Icons.mic, size: 16, color: textSecondaryColor),
              4.width,
              Text('voice_note'.translate, style: secondaryTextStyle()),
            ],
          );
        } else {
          var displayImgMessage = isDeletedForMe
              ? 'you_delete_msg'.translate
              : 'this_delete_msg'.translate;

          return Text(
            displayImgMessage,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TS.secondaryTextStyle(),
          );
        }

      case STICKER:
        if (!isDeletedForMe && message.isDeleted == false) {
          return Row(
            children: [
              Icon(Icons.face, size: 16, color: textSecondaryColor),
              4.width,
              Text('sticker'.translate, style: TS.secondaryTextStyle()),
            ],
          );
        } else {
          var displayImgMessage = isDeletedForMe
              ? 'you_delete_msg'.translate
              : 'this_delete_msg'.translate;

          return Text(
            displayImgMessage,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TS.secondaryTextStyle(),
          );
        }

      default:
        return Container();
    }
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder(
      stream: stream,
      builder: (context, AsyncSnapshot<QuerySnapshot> snapshot) {
        if (snapshot.hasData) {
          var docList = snapshot.data!.docs;

          if (docList.isNotEmpty) {
            ChatMessageModel message = ChatMessageModel.fromJson(
                docList.last.data() as Map<String, dynamic>);

            message.isMe = message.senderId == getStringAsync(userId);
            var isDeletedForMe =
                message.deletedFor?.contains(getStringAsync(userId)) ?? false;

            String time = '';
            DateTime date =
                DateTime.fromMicrosecondsSinceEpoch(message.createdAt! * 1000);
            if (date.day == DateTime.now().day) {
              time = DateFormat('hh:mm a').format(
                  DateTime.fromMicrosecondsSinceEpoch(
                      message.createdAt! * 1000));
            } else {
              time = DateFormat('dd/MM/yyy').format(
                  DateTime.fromMicrosecondsSinceEpoch(
                      message.createdAt! * 1000));
            }
            return Row(
              children: [
                Row(
                  children: [
                    if (isDeletedForMe == false ||
                        message.isDeleted == false) ...[
                      message.isMe!
                          ? !message.isMessageRead!
                              ? Icon(Icons.done,
                                  size: 16, color: textSecondaryColor)
                              : Icon(Icons.done_all,
                                  size: 16,
                                  color: appStore.isDarkMode
                                      ? textPrimaryColor
                                      : primaryColor)
                          : SizedBox(),
                    ] else ...[
                      Image.asset('assets/Icons/traffic.png',
                          width: 15, height: 15, color: Colors.grey),
                    ],
                    4.width,
                    typeWidget(message)
                  ],
                ).expand(),
                Text(time,
                    style: TS.secondaryTextStyle(
                        size: (appStore.fontSize - 4).toInt())),
              ],
            ).paddingTop(2).expand();
          }
          return Text("", style: TextStyle(color: Colors.grey, fontSize: 14));
        }
        return Text("..", style: TextStyle(color: Colors.grey, fontSize: 14));
      },
    );
  }
}
