import 'package:flutter/material.dart';
import 'package:nb_utils/nb_utils.dart';

import 'package:chat/centralized_import.dart';

import '../../utils/TextStyles.dart' as TS;

class ImageChatComponent extends StatelessWidget {
  final ChatMessageModel data;
  final bool? isDeletedForMe;
  final String time;

  ImageChatComponent(
      {required this.data, this.isDeletedForMe, required this.time});

  @override
  Widget build(BuildContext context) {
    if (isDeletedForMe == true || data.isDeleted == true) {
      String deletedText = data.isDeleted == true
          ? 'this_delete_msg'.translate
          : 'you_delete_msg'.translate;

      return Padding(
        padding: const EdgeInsets.all(6),
        child: Text(
          deletedText,
          style: TS.primaryTextStyle(color: Colors.grey),
        ),
      );
    }

    if (data.photoUrl.validate().isNotEmpty) {
      return ConstrainedBox(
        constraints: BoxConstraints(maxWidth: 250),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            cachedImage(
              data.photoUrl.validate(),
              fit: BoxFit.cover,
              width: 250,
              height: 250,
            ).cornerRadiusWithClipRRect(10).onTap(() {
              log("value" + data.id.toString());
              FullScreenImageWidget(
                photoUrl: data.photoUrl,
                heroId: data.id,
                isFromChat: true,
              ).launch(context);
            }),
            if (!data.message.isEmptyOrNull)
              Padding(
                padding: const EdgeInsets.only(left: 5, top: 5),
                child: Text(
                  data.message ?? '',
                  style: TS.boldTextStyle(),
                ),
              ),
            if (data.groupReaction != null && data.groupReaction!.isNotEmpty)
              SingleChildScrollView(
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
              ).onTap(() {
                log("value" + data.id.toString());
                showReactionBottomSheet(context, data.groupReaction);
              }),
            Align(
              alignment: isRTL ? Alignment.bottomLeft : Alignment.bottomRight,
              child: Container(
                padding: EdgeInsets.only(bottom: 6, left: 6, right: 6),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      time,
                      style: TS.secondaryTextStyle(),
                    ),
                    2.width,
                    if (data.isMe!)
                      data.isMessageRead!
                          ? Icon(Icons.done_all,
                              size: 16,
                              color: appStore.isDarkMode
                                  ? textPrimaryColor
                                  : primaryColor)
                          : Icon(Icons.done,
                              size: 16,
                              color: Colors.blueGrey.withOpacity(0.6)),
                  ],
                ),
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      height: 250,
      width: 250,
      child: Loader(),
    );
  }
}
