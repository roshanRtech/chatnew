import 'package:chat/main.dart';
import 'package:chat/models/ContactModel.dart';
import 'package:chat/screens/ChatScreen.dart';
import 'package:chat/screens/GroupChat/GroupChatScreen.dart';
import 'package:chat/utils/AppCommon.dart';
import 'package:chat/utils/AppConstants.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:nb_utils/nb_utils.dart';

import '../../models/ChatMessageModel.dart';
import '../../utils/Appwidgets.dart';
import '../utils/AppColors.dart';

class ShareChatComponent extends StatefulWidget {
  final ChatMessageModel data;
  final bool? isDeletedForMe;
  final String time;

  ShareChatComponent(
      {required this.data, this.isDeletedForMe, required this.time});

  @override
  State<ShareChatComponent> createState() => _ShareChatComponentState();
}

class _ShareChatComponentState extends State<ShareChatComponent> {
  @override
  Widget build(BuildContext context) {
    final isDeleted = widget.data.isDeleted == true;
    final isDeletedForMe = widget.isDeletedForMe == true;
    final isSharedUser =
        widget.data.shareUser?.name != null && widget.data.groupName == null;
    final isGroupInvite = widget.data.groupName != null;

    if (isDeleted || isDeletedForMe) {
      final message =
          isDeleted ? 'this_delete_msg'.translate : 'you_delete_msg'.translate;
      return Padding(
        padding: const EdgeInsets.all(6),
        child: Text(message, style: primaryTextStyle(color: Colors.grey)),
      );
    }

    if (isSharedUser) {
      return Container(
        width: 250,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: widget.data.isMe!
              ? CrossAxisAlignment.end
              : CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                cachedImage(widget.data.shareUser?.photoUrl.validate(),
                        height: 35, width: 35, fit: BoxFit.cover)
                    .cornerRadiusWithClipRRect(50),
                8.width,
                Text(widget.data.shareUser?.name ?? '', style: boldTextStyle()),
              ],
            ),
            10.height,
            Divider(height: 0.2, color: Colors.grey),
            8.height,
            if (widget.data.shareUser?.uid != getStringAsync(userId))
              GestureDetector(
                onTap: () {
                  ChatScreen(widget.data.shareUser, isAdmin: false)
                      .launch(context);
                },
                child: Container(
                  width: double.infinity,
                  alignment: Alignment.center,
                  child: Text('lblMessage'.translate,
                      style: boldTextStyle(color: primaryColor)),
                ),
              ),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(widget.time, style: secondaryTextStyle(size: 10)),
                2.width,
                if (widget.data.isMe!)
                  widget.data.isMessageRead == false
                      ? Icon(Icons.done, size: 16, color: textSecondaryColor)
                      : Icon(Icons.done_all, size: 16, color: primaryColor),
              ],
            ),
          ],
        ),
      ).onTap(() {
        ChatScreen(widget.data.shareUser, isAdmin: false).launch(context);
      });
    }

    if (isGroupInvite) {
      return Container(
        width: 250,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: widget.data.isMe!
              ? CrossAxisAlignment.end
              : CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                cachedImage(widget.data.groupProfile ?? '',
                        height: 35, width: 35, fit: BoxFit.cover)
                    .cornerRadiusWithClipRRect(50),
                8.width,
                Text(widget.data.groupName ?? '', style: boldTextStyle()),
              ],
            ),
            10.height,
            Divider(height: 0.2, color: Colors.grey),
            8.height,
            if (!groupIds!.contains(widget.data.groupId))
              GestureDetector(
                onTap: () async {
                  ContactModel data = ContactModel()
                    ..uid = widget.data.groupId
                    ..addedOn = Timestamp.now()
                    ..lastMessageTime = DateTime.now().millisecondsSinceEpoch
                    ..groupRefUrl = widget.data.groupId;
                  await chatMessageService
                      .getContactsDocument(
                          of: getStringAsync(userId),
                          forContact: widget.data.groupId)
                      .set(data.toJson());
                  await groupChatMessageService.joinGroup(
                    groupDocId: widget.data.groupId!,
                    currentUserId: getStringAsync(userId),
                  );
                  await setValue(CURRENT_GROUP_ID, widget.data.groupId!);
                  GroupChatScreen(
                    groupChatId: widget.data.groupId!,
                    groupName: widget.data.groupName!,
                  ).launch(context);
                },
                child: Container(
                  width: double.infinity,
                  alignment: Alignment.center,
                  child: Text('lblJoin'.translate,
                      style: boldTextStyle(color: primaryColor)),
                ),
              ),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(widget.time, style: secondaryTextStyle(size: 10)),
                2.width,
                if (widget.data.isMe!)
                  widget.data.isMessageRead == false
                      ? Icon(Icons.done, size: 16, color: textSecondaryColor)
                      : Icon(Icons.done_all, size: 16, color: primaryColor),
              ],
            ),
          ],
        ),
      ).onTap(() async {
        if (groupIds!.contains(widget.data.groupId)) {
          await setValue(CURRENT_GROUP_ID, widget.data.groupId ?? '');
          GroupChatScreen(
            groupChatId: widget.data.groupId ?? '',
            groupName: widget.data.groupName ?? '',
          ).launch(context);
        }
      });
    }

    // 4. Fallback
    return Container(
      child: Loader(),
      height: 250,
      width: 250,
    );
  }
}
