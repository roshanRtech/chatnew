import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:nb_utils/nb_utils.dart';
import '../../utils/TextStyles.dart' as TS;

import 'package:chat/centralized_import.dart';

// ignore: must_be_immutable
class ChatWidget extends StatelessWidget {
  bool isMe;
  String? message;
  int? createdAt;

  ChatWidget({this.isMe = false, this.message, this.createdAt});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: context.width(),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment:
            isMe.validate() ? CrossAxisAlignment.end : CrossAxisAlignment.start,
        mainAxisAlignment:
            isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
        children: [
          Container(
            margin: isMe.validate()
                ? EdgeInsets.only(
                    top: 3.0,
                    bottom: 3.0,
                    left: context.width() * 0.25,
                    right: 8)
                : EdgeInsets.only(
                    top: 4.0,
                    bottom: 4.0,
                    left: 8,
                    right: context.width() * 0.25),
            padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              boxShadow: defaultBoxShadow(),
              color: isMe.validate() ? primaryColor : Colors.white,
              borderRadius: isMe.validate()
                  ? BorderRadius.only(
                      bottomLeft: Radius.circular(chatMsgRadius),
                      topLeft: Radius.circular(chatMsgRadius),
                      bottomRight: Radius.circular(0),
                      topRight: Radius.circular(chatMsgRadius),
                    )
                  : BorderRadius.only(
                      bottomLeft: Radius.circular(0),
                      topLeft: Radius.circular(chatMsgRadius),
                      bottomRight: Radius.circular(chatMsgRadius),
                      topRight: Radius.circular(chatMsgRadius),
                    ),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment:
                  isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
              children: [
                Text(message!,
                    style: TS.primaryTextStyle(
                        color: isMe ? Colors.white : textPrimaryColor),
                    maxLines: null),
                Text(
                  DateFormat('HH:mm a').format(
                      DateTime.fromMicrosecondsSinceEpoch(createdAt! * 1000)),
                  style: TS.primaryTextStyle(
                      color: !isMe.validate()
                          ? Colors.blueGrey.withOpacity(0.6)
                          : whiteColor.withOpacity(0.6)),
                ),
              ],
            ),
          ).onTap(() {
            //
          }),
        ],
      ),
      margin: EdgeInsets.only(top: 4, bottom: 4),
    );
  }
}
