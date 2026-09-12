import 'package:flutter/material.dart';
import 'package:nb_utils/nb_utils.dart';

import 'package:chat/centralized_import.dart';

import '../../utils/TextStyles.dart' as TS;

class VideoChatComponent extends StatelessWidget {
  final ChatMessageModel data;
  final bool? isDeletedForMe;
  final String time;

  VideoChatComponent(
      {required this.data, required this.time, this.isDeletedForMe});

  @override
  Widget build(BuildContext context) {
    print("------------19>>${isDeletedForMe}");
    print("------------20>>${data.isDeleted}");

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

    if (!data.photoUrl.validate().isEmptyOrNull) {
      return ConstrainedBox(
        constraints: BoxConstraints(maxWidth: 250),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Stack(
              alignment: Alignment.center,
              children: [
                ClipRRect(
                  borderRadius: radius(defaultInkWellRadius),
                  child: videoThumbnailImage(
                      path: data.photoUrl.validate(), height: 250, width: 250),
                ),
                Container(
                  padding: EdgeInsets.all(6),
                  decoration: boxDecorationWithShadow(
                    backgroundColor: Colors.black38,
                    boxShape: BoxShape.circle,
                    spreadRadius: 0,
                    blurRadius: 0,
                  ),
                  child: Icon(Icons.play_arrow, color: Colors.white),
                ).onTap(() {
                  VideoPlayScreen(data.photoUrl.validate()).launch(context);
                }),
              ],
            ),
            if (!data.message.isEmptyOrNull)
              Padding(
                padding: const EdgeInsets.only(left: 5, top: 5),
                child: Text(
                  data.message ?? '',
                  style: TS.boldTextStyle(),
                ),
              ),
            if (data.groupReaction != null && data.groupReaction!.isNotEmpty)
              Align(
                alignment: Alignment.bottomLeft,
                child: Padding(
                  padding: const EdgeInsets.only(left: 5, bottom: 5),
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
            Align(
              alignment: isRTL ? Alignment.bottomLeft : Alignment.bottomRight,
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
                            size: 16, color: Colors.blueGrey.withOpacity(0.6)),
                ],
              ),
            ),
          ],
        ),
      );
    }
    return SizedBox(child: Loader(), height: 250, width: 250);
  }
}
