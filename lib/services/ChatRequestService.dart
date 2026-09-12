import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:nb_utils/nb_utils.dart';

import 'package:chat/centralized_import.dart';

class ChatRequestService extends BaseService {
  FirebaseFirestore fireStore = FirebaseFirestore.instance;

  ChatRequestService() {
    ref = fireStore
        .collection(USER_COLLECTION)
        .doc(getStringAsync(userId))
        .collection(CHAT_REQUEST);
  }

  Future<DocumentReference> addChatWithCustomId(
      String id, Map<String, dynamic> data, String receiverId) async {
    CollectionReference receiverRef = fireStore
        .collection(USER_COLLECTION)
        .doc(receiverId)
        .collection(CHAT_REQUEST);

    var doc = receiverRef.doc(id);

    return await doc.set(data).then((value) {
      //
      return doc;
    }).catchError((e) {
      log(e);
      throw e;
    });
  }

  Future<bool> isRequestUserExist(String? val, String receiverId) async {
    CollectionReference receiverRef = fireStore
        .collection(USER_COLLECTION)
        .doc(receiverId)
        .collection(CHAT_REQUEST);
    Query query = receiverRef.limit(1).where('uid', isEqualTo: val);
    var res = await query.get();

    return res.docs.isNotEmpty;
  }

  Future<bool> isRequestsUserExist(String? val) async {
    CollectionReference receiverRef = fireStore
        .collection(USER_COLLECTION)
        .doc(getStringAsync(userId))
        .collection(CHAT_REQUEST);
    Query query = receiverRef
        .limit(1)
        .where('uid', isEqualTo: val)
        .where('requestStatus', isEqualTo: RequestStatus.Pending.index);
    var res = await query.get();
    print(res.docs);
    print(res.docs.isNotEmpty);

    return res.docs.isNotEmpty;
  }

  Stream<List<ChatRequestModel>> getChatRequestList() {
    return fireStore
        .collection(USER_COLLECTION)
        .doc(getStringAsync(userId))
        .collection(CHAT_REQUEST)
        .where('requestStatus', isEqualTo: RequestStatus.Pending.index)
        .snapshots()
        .asyncMap((snapshot) async {
      // Convert to model list
      List<ChatRequestModel> allRequests = snapshot.docs
          .map((doc) => ChatRequestModel.fromJson(doc.data()))
          .toList();
      List<ChatRequestModel> validRequests = [];
      for (var request in allRequests) {
        if (request.senderIdRef != null) {
          DocumentSnapshot senderSnapshot = await request.senderIdRef!.get();

          if (senderSnapshot.exists) {
            validRequests.add(request);
          }
        }
      }

      return validRequests;
    });
  }

  Stream<int> getRequestLength() {
    return fireStore
        .collection(USER_COLLECTION)
        .doc(getStringAsync(userId))
        .collection(CHAT_REQUEST)
        .where('requestStatus', isEqualTo: RequestStatus.Pending.index)
        .snapshots()
        .asyncMap((snapshot) async {
      List<ChatRequestModel> allRequests = snapshot.docs
          .map((doc) => ChatRequestModel.fromJson(doc.data()))
          .toList();
      var checks = allRequests.map((request) async {
        if (request.senderIdRef != null) {
          DocumentSnapshot senderSnapshot = await request.senderIdRef!.get();
          if (senderSnapshot.exists) return true;
        }
        return false;
      });
      var results = await Future.wait(checks);
      return results.where((exists) => exists).length;
    });
  }
}
