import 'package:flutter/material.dart';
import 'package:nb_utils/nb_utils.dart';

import 'package:chat/centralized_import.dart';

import '../../utils/TextStyles.dart' as TS;

class statusChatComponent extends StatelessWidget {
  final ChatMessageModel? data;
  final String time;
  final bool? isDeletedForMe;

  statusChatComponent({required this.data, required this.time, this.isDeletedForMe});

  @override
  Widget build(BuildContext context) {
    bool? isExpired = false;
    if (isDeletedForMe == true) {
      return Padding(
        padding: const EdgeInsets.all(6),
        child: Text('you_delete_msg'.translate, style: TS.primaryTextStyle(color: Colors.grey)),
      );
    }

    if (data?.isDeleted == true) {
      return Padding(
        padding: const EdgeInsets.all(6),
        child: Text('this_delete_msg'.translate, style: TS.primaryTextStyle(color: Colors.grey)),
      );
    }

    if (!(data?.storyModel?.createAt.toString().isEmptyOrNull ?? false)) {
      final DateTime createdDate = data!.storyModel!.createAt!.toDate();
      final DateTime now = DateTime.now();
      final difference = now.difference(createdDate);
      isExpired = difference.inHours >= 24;
    }

    if (data?.storyModel != null) {
      return Container(
        width: 250,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (data?.storyModel != null)
              Container(
                decoration: BoxDecoration(
                  color: primaryColor.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 10),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '${data?.storyModel?.userName ?? ''}${' • Story'}',
                            maxLines: 3,
                            overflow: TextOverflow.ellipsis,
                            softWrap: false,
                            style: TS.boldTextStyle(),
                          ),
                          Text(
                            '${data?.storyModel?.caption}',
                            maxLines: 3,
                            overflow: TextOverflow.ellipsis,
                            softWrap: false,
                            style: TS.boldTextStyle(),
                          ).visible(!(data?.storyModel?.caption.isEmptyOrNull ?? false)),
                        ],
                      ),
                    ).expand(),
                    Align(
                      alignment: Alignment.centerRight,
                      child: cachedImage(
                        data?.storyModel?.imagePath,
                        fit: BoxFit.fitWidth,
                        width: 50,
                        height: 50,
                      ).cornerRadiusWithClipRRect(10).onTap(() {}),
                    ),
                  ],
                ),
              ).onTap(() {
                if (isExpired == true) {
                  toast("Status was expire");
                } else {
                  var storyData = data?.storyModel;
                  storyShowChatScreen(
                    list: [storyData!],
                    userName: data?.storyModel?.userName ?? '',
                    time: data?.storyModel?.createAt,
                    userImg: data?.storyModel?.userImgPath,
                  ).launch(context);
                }
              }),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 2),
              child: RichText(
                text: TextSpan(
                  children: buildMessageSpans(data?.message ?? '',context,getStringAsync(userId)),
                ),
              ),
            ),
            Align(
              alignment: isRTL ? Alignment.bottomLeft : Alignment.bottomRight,
              child: Container(
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      time,
                      style: TS.primaryTextStyle(color: Colors.blueGrey, size: (appStore.fontSize - 4).toInt())
                    ),
                    2.width,
                    if (data!.isMe!)
                      data?.isMessageRead == false
                          ? Icon(Icons.done, size: 16, color: Colors.blueGrey.withOpacity(0.6))
                          : Icon(Icons.done_all, size: 16, color: appStore.isDarkMode ? textPrimaryColor : primaryColor),
                  ],
                ),
              ).paddingAll(6),
            ),
            if (data?.groupReaction != null && (data?.groupReaction?.isNotEmpty ?? false))
              Align(
                alignment: Alignment.bottomLeft,
                child: Padding(
                  padding: const EdgeInsets.only(left: 5),
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: data!.groupReaction!.map((entry) {
                        return !entry.reaction.isEmptyOrNull
                            ? Container(
                                margin: const EdgeInsets.only(top: 4, right: 6),
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: Colors.grey.shade100,
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(color: Colors.grey.shade300, width: 1),
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
                showReactionBottomSheet(context, data?.groupReaction);
              }),
          ],
        ),
      );
    }

    return Container(
      child: Loader(),
      height: 250,
      width: 250,
    );
  }
}
