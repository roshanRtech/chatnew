import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:nb_utils/nb_utils.dart';
import 'package:chat/centralized_import.dart';


class groupCallFunctions {
  static Future<void> dialGroup({
    required BuildContext context,
    required UserModel from,
    required List<UserModel> toUsers,
    String? groupId,
    String? groupName,
    String? callType,
  }) async {
    print("dialGroup() is called");

    // 🔑 One channel for everyone
    final channelId = Random().nextInt(1000).toString();

    // Caller's callModel (group owner)
    final callerCallModel = CallModel(
      callerId: from.uid,
      callerName: from.name,
      callerPhotoUrl: from.photoUrl,
      flow: "GroupCall",
      channelId: channelId,
      receiverId: "",
      receiverName: groupName ?? "Group",
      receiverPhotoUrl: "",
      groupName: groupName,
      callType: callType,
      isVoice: false,
    );


    if (callType ==  CALL_TYPE_GROUP_VIDEO_CALL) {
      AgoraGroupVideoCallScreen(
        callModel: callerCallModel,
        isCaller: true,
      ).launch(context);
    } else {
      AgoraGroupVoiceCallScreen(
        callModel: callerCallModel,
        isCaller: true,
      ).launch(context);
    }

    await FirebaseFirestore.instance
        .collection('groupCall')
        .doc(channelId)
        .set({
      'channelId': channelId,
      'groupId': groupId,
      'groupName': groupName ?? "Group",
      'callType': callType,
      'initiator': from.uid,
      'participants': [],
      'invited': [from.uid, ...toUsers.map((u) => u.uid)],
      'createdAt': FieldValue.serverTimestamp(),
      'active': true,
    });

    Future.microtask(() async {
      for (var to in toUsers) {
        if (to.uid == getStringAsync(userId)) continue;

        CallModel individualCallModel = CallModel(
          callerId: from.uid,
          callerName: from.name,
          callerPhotoUrl: from.photoUrl,
          flow: "GroupCall",
          channelId: channelId,
          receiverId: to.uid,
          receiverName: to.name,
          receiverPhotoUrl: to.photoUrl,
          callType: callType,
          groupName: groupName,
          isVoice: false,
        );

        try {
          bool callMade = await callService.makeCall(callModel: individualCallModel);
          if (callMade) {
            if (!to.oneSignalPlayerId.isEmptyOrNull) {
              if (to.uid == getStringAsync(userId)) return;
              print("My oneSignal");
              notificationService.sendPushNotifications(
                "${groupName} Group Call",
                '${from.name} started a group call',
                receiverPlayerId: to.oneSignalPlayerId,
                flow: 'call',
              );
            }
            // Add log (also async but we don't await)
            LogModel log = LogModel(
              callerId: from.uid,
              receiverId: to.uid,
              callerName: from.name,
              callerPic: from.photoUrl,
              callStatus: CALLED_STATUS_DIALLED,
              receiverName: to.name,
              receiverPic: to.photoUrl,
              callType: "Group video call",
              timestamp: DateTime.now().toString(),
            );
            LogRepository.addLogs(log);
          }
        } catch (e) {
          print("Error notifying user ${to.uid}: $e");
        }
      }
    });
  }
}
