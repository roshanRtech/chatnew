import 'package:chat/centralized_import.dart';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:nb_utils/nb_utils.dart';

class CallService extends BaseService {
  FirebaseFirestore fireStore = FirebaseFirestore.instance;

  CallService() {
    ref = fireStore.collection("call");
  }

  Stream<DocumentSnapshot> callStream({String? uid}) =>
      ref!.doc(uid).snapshots();

  Future<bool> makeCall(
      {required CallModel callModel, bool isVoiceCall = false}) async {
    try {
      callModel.hasDialed = true;
      callModel.isVoice = isVoiceCall;
      Map<String, dynamic> hasDialedMap = callModel.toJson();
      callModel.hasDialed = false;

      Map<String, dynamic> hasNotDialedMap = callModel.toJson();

      await ref!.doc(callModel.callerId).set(hasDialedMap);
      await ref!.doc(callModel.receiverId).set(hasNotDialedMap);
      return true;
    } on Exception catch (e) {
      log(e);
      return false;
    }
  }

  Future<bool> endCall({required CallModel callModel}) async {
    try {
      await ref!.doc(callModel.callerId).delete();
      await ref!.doc(callModel.receiverId).delete();
      return true;
    } on Exception catch (e) {
      log(e);
      return false;
    }
  }

  Future<bool> makeGroupCall({required CallModel callModel, required List<String> participants}) async {
    try {
      await fireStore.collection("groupCalls").doc(callModel.channelId).set({
        ...callModel.toJson(),
        "participants": participants,
      });
      return true;
    } catch (e) {
      log("makeGroupCall error: $e");
      return false;
    }
  }

  Stream<DocumentSnapshot> groupCallStream(String channelId) {
    return fireStore.collection("groupCalls").doc(channelId).snapshots();
  }

  Future<void> endGroupCallStream(String channelId) async {
    await fireStore.collection("groupCalls").doc(channelId).delete();
  }



  Future<void> endGroupCall({
    required String userId,
  }) async {
    try {
      await ref!.doc(userId).delete();
      log('User $userId left group call');
    } catch (e) {
      log('Error ending group call: $e');
    }
  }
}
