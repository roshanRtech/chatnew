import 'package:flutter/material.dart';
import 'package:nb_utils/nb_utils.dart';
import 'package:chat/centralized_import.dart';

import '../../utils/TextStyles.dart' as TS;

class StickerChatComponent extends StatelessWidget {
  final ChatMessageModel data;
  final String time;
  final EdgeInsetsGeometry padding;
  final bool? isDeletedForMe;

  StickerChatComponent(
      {required this.data,
      required this.time,
      required this.padding,
      this.isDeletedForMe});

  @override
  Widget build(BuildContext context) {
    if (isDeletedForMe == true) {
      return Padding(
        padding: const EdgeInsets.all(6),
        child: Text('you_delete_msg'.translate,
            style: TS.primaryTextStyle(color: Colors.grey)),
      );
    }

    if (data.isDeleted == true) {
      return Padding(
        padding: const EdgeInsets.all(6),
        child: Text('this_delete_msg'.translate,
            style: TS.primaryTextStyle(color: Colors.grey)),
      );
    }

    if (data.stickerPath.validate().isNotEmpty) {
      return Stack(
        children: [
          cachedImage(data.stickerPath.validate(), fit: BoxFit.fill, width: 110)
              .paddingBottom(10)
              .onTap(() {
            FullScreenImageWidget(
                    photoUrl: data.stickerPath,
                    isFromChat: true,
                    name: data.messageType)
                .launch(context);
          }),
          Positioned(
            bottom: 0,
            left: data.isMe.validate() ? null : 0,
            right: data.isMe.validate() ? 0 : null,
            child: Container(
              margin: data.isMe.validate()
                  ? EdgeInsets.only(
                      top: 0.0,
                      bottom: 0.0,
                      left: isRTL ? 0 : context.width() * 0.25,
                      right: 8)
                  : EdgeInsets.only(
                      top: 2.0,
                      bottom: 2.0,
                      left: 8,
                      right: isRTL ? 0 : context.width() * 0.25),
              padding: padding,
              decoration: BoxDecoration(
                boxShadow: appStore.isDarkMode ? null : defaultBoxShadow(),
                color: data.isMe.validate() ? primaryColor : context.cardColor,
                borderRadius: radiusOnly(
                  bottomLeft: chatMsgRadius,
                  topLeft: chatMsgRadius,
                  bottomRight: chatMsgRadius,
                  topRight: chatMsgRadius,
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    time,
                    style: TS.primaryTextStyle(
                      color: !data.isMe.validate()
                          ? Colors.blueGrey.withOpacity(0.6)
                          : whiteColor.withOpacity(0.6),
                      size: 10,
                    ),
                  ),
                  2.width,
                  data.isMe!
                      ? !data.isMessageRead!
                          ? Icon(Icons.done,
                              size: 16, color: Colors.blueGrey.withOpacity(0.6))
                          : Icon(Icons.done_all,
                              size: 16,
                              color: appStore.isDarkMode
                                  ? textPrimaryColor
                                  : primaryColor)
                      : Offstage(),
                ],
              ),
            ),
          ),
          if (data.groupReaction != null && data.groupReaction!.isNotEmpty)
            Align(
              alignment: Alignment.bottomLeft,
              child: Padding(
                padding: const EdgeInsets.only(left: 5),
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: data.groupReaction!.map((entry) {
                      return !entry.reaction.isEmptyOrNull
                          ? Container(
                              margin: const EdgeInsets.only(top: 4, right: 6),
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: Colors.grey.shade100,
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(
                                    color: Colors.grey.shade300, width: 1),
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
              log("value" + data.id.toString());
              showReactionBottomSheet(context, data.groupReaction);
            }),
        ],
      );
    }

    return Container(
      child: Loader(),
      height: 120,
      width: 120,
    );
  }
}
