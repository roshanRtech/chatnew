import 'package:flutter/material.dart';
import 'package:nb_utils/nb_utils.dart';
import 'package:flutter_link_previewer/flutter_link_previewer.dart';
import 'package:flutter_chat_core/flutter_chat_core.dart' show LinkPreviewData;

import 'package:chat/centralized_import.dart';
import '../../utils/TextStyles.dart' as TS;

class TextChatComponent extends StatefulWidget {
  final ChatMessageModel data;
  final String time;
  final bool? isDeletedForMe;
  final String? onSearchValueChanged;

  const TextChatComponent({
    required this.data,
    required this.time,
    this.onSearchValueChanged,
    this.isDeletedForMe,
    Key? key,
  }) : super(key: key);

  @override
  State<TextChatComponent> createState() => _TextChatComponentState();
}

class _TextChatComponentState extends State<TextChatComponent> {
  LinkPreviewData? _linkPreviewData;

  @override
  initState() {
    super.initState();

    print("TextChatComponent initState called");
  }

  @override
  Widget build(BuildContext context) {
    final messageText = widget.data.isEncrypt == true
        ? decryptedData(widget.data.message ?? '')
        : widget.data.message ?? '';

    // Regex to detect URL
    final urlRegex = RegExp(
      r'((https?:\/\/)?([\w-]+(\.[\w-]+)+)([\w.,@?^=%&:/~+#-]*[\w@?^=%&/~+#-])?)',
    );
    final allMatches = urlRegex.allMatches(messageText);
    final urls = allMatches.map((m) => m.group(0)).whereType<String>().toList();

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment:
          widget.data.isMe! ? CrossAxisAlignment.end : CrossAxisAlignment.start,
      children: [
        // Deleted message handling
        if (widget.isDeletedForMe == true)
          Text('you_delete_msg'.translate,
              style: TS.primaryTextStyle(color: Colors.grey)),
        if (widget.data.isDeleted == true)
          Text('this_delete_msg'.translate,
              style: TS.primaryTextStyle(color: Colors.grey)),

        // Normal message display
        if (widget.data.isDeleted == false &&
            widget.isDeletedForMe == false) ...[
          // The actual message text
          RichText(
            text: TextSpan(
              children: buildMessageSpans(
                messageText,
                context,
                getStringAsync(userId),
              ),
            ),
          ),

          // Display previews for all URLs in the message
          if (urls.isNotEmpty)
            ...urls.map((url) {
              return Container(
                margin: const EdgeInsets.only(top: 8),
                child: LinkPreview(
                  text: url,
                  backgroundColor: Colors.grey.shade100,
                  onLinkPreviewDataFetched: (data) {
                    setState(() {
                      _linkPreviewData = data;
                    });
                  },
                  parentContent: url,
                  borderRadius: 4,
                  sideBorderColor: Colors.white,
                  sideBorderWidth: 4,
                  insidePadding: const EdgeInsets.fromLTRB(12, 8, 8, 8),
                  outsidePadding: const EdgeInsets.symmetric(vertical: 4),
                  titleTextStyle: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 20,
                  ),
                ),
              );
            }).toList(),

          const SizedBox(height: 4),

          // Time + read status
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(widget.time,
                  style: TS.secondaryTextStyle(
                      size: (appStore.fontSize - 5).toInt())),
              4.width,
              if (widget.data.isMe!)
                Icon(
                  widget.data.isMessageRead == true
                      ? Icons.done_all
                      : Icons.done,
                  size: 16,
                  color: widget.data.isMessageRead == true
                      ? primaryColor
                      : textSecondaryColor,
                ),
            ],
          ),

          // Reaction display
          if (widget.data.groupReaction != null &&
              widget.data.groupReaction!.isNotEmpty)
            Row(
              children: widget.data.groupReaction!.map((entry) {
                return !entry.reaction.isEmptyOrNull
                    ? Container(
                        margin: const EdgeInsets.only(top: 4, right: 6),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.grey.shade100,
                          borderRadius: BorderRadius.circular(16),
                          border:
                              Border.all(color: Colors.grey.shade300, width: 1),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.05),
                              blurRadius: 2,
                              offset: const Offset(0, 1),
                            ),
                          ],
                        ),
                        child: Text(entry.reaction ?? '',
                            style: TS.boldTextStyle()),
                      )
                    : const SizedBox.shrink();
              }).toList(),
            ).onTap(() {
              showReactionBottomSheet(context, widget.data.groupReaction);
            }),
        ],
      ],
    );
  }
}
