import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:nb_utils/nb_utils.dart';
import 'package:path/path.dart' as path;
import 'package:http/http.dart' as http;


import 'package:chat/centralized_import.dart';



class GroupChatMessageService extends BaseService {
  FirebaseFirestore fireStore = FirebaseFirestore.instance;
  FirebaseStorage _storage = FirebaseStorage.instance;
  late CollectionReference userRef;
  late CollectionReference grpRef;

  GroupChatMessageService() {
    userRef = fireStore.collection(USER_COLLECTION);
    grpRef = fireStore.collection(GROUPS_COLLECTION);
  }



  Future<DocumentReference> addGroup(GroupModel data,List<UserModel> userModelList,String? adminName) async {
    print('--------------37>>>${data.toJson()}');
    try {
      var doc = await grpRef.add(data.toJson());

      await doc.update({'id': doc.id});

      for (UserModel user in userModelList) {
        var chatRef = doc.collection(GROUP_CHATS).doc();
        await chatRef.set({
          "id": chatRef.id,
          "addRemoveStatus": "${adminName} added ${user.name}",
          "messageType": ADD_REMOVE_GROUP,
          "createdAt": DateTime.now().millisecondsSinceEpoch,
        });
      }

      return doc;
    } catch (e) {
      toast(e.toString());
      rethrow;
    }
  }


  editMessage({required String groupChatId,required String documentId,required String message}) async{
    return grpRef.doc(groupChatId).collection(GROUP_CHATS).doc(documentId).update({
      "message":"$message"
    });
  }

  Future<void> addReaction({
    required String groupChatId,
    required String documentId,
    required ReactionModel reactionModel,
  }) async {
    print("----------40>>$groupChatId");
    print("----------41>>$documentId");

    final docRef = grpRef
        .doc(groupChatId)
        .collection(GROUP_CHATS)
        .doc(documentId);


    await FirebaseFirestore.instance.runTransaction((transaction) async {
      final snapshot = await transaction.get(docRef);

      if (!snapshot.exists) {
        transaction.set(docRef, {
          "groupReaction": [reactionModel.toJson()],
        }, SetOptions(merge: true));
        return;
      }

      final data = snapshot.data() as Map<String, dynamic>? ?? {};
      List<dynamic> reactions = List.from(data["groupReaction"] ?? []);
      reactions.removeWhere((r) => r["uid"] == reactionModel.uid);
      reactions.add(reactionModel.toJson());
      transaction.update(docRef, {
        "groupReaction": reactions,
      });
    });
  }

  Future<void> removeReaction({
    required String groupChatId,
    required String documentId,
    required String reaction,
  }) async {
    print("----------40>>$groupChatId");
    print("----------41>>$documentId");

    final docRef = grpRef
        .doc(groupChatId)
        .collection(GROUP_CHATS)
        .doc(documentId);

    final uid = getStringAsync(userId);


    await FirebaseFirestore.instance.runTransaction((transaction) async {
      final snapshot = await transaction.get(docRef);
      if (!snapshot.exists) return;
      List<dynamic> reactions = [];
      if (snapshot.exists && snapshot.data()!.containsKey("groupReaction")) {
        reactions = List.from(snapshot["groupReaction"]);
      }

      // remove old reaction of same user
      reactions.removeWhere((r) => r["uid"] == uid);

      // add new reaction
      transaction.update(docRef, {
        "groupReaction": reactions,
      });
    });
  }


  Stream<List<dynamic>> group({String? searchText}) {
    return grpRef.where('searchCase', arrayContains: searchText.validate().isEmpty ? null : searchText!.toLowerCase()).snapshots().map((x) {
      return x.docs.map((y) {
        return y.data();
      }).toList();
    });
  }
  Future<void> deleteGrpSingleMessageOnlyForMe({String? groupDocId, String? messageDocId,}) async {
    try {
      log("here");
      print("---------53>>>>${groupDocId}");
      print("---------54>>>>${messageDocId}");

      grpRef.doc(groupDocId).collection(GROUP_CHATS).doc(messageDocId).update({
       // "delete_for_sender":true
        'deletedFor': FieldValue.arrayUnion([getStringAsync(userId)])
      });

      // log("done----------------");
    } on Exception catch (e,s) {
      print("------------65>>>>>>${e.toString()}");
      print("------------66>>>>>>${s.toString()}");
      throw 'Something went wrong';
    }
  }

  Future<DocumentReference> addMessage(ChatMessageModel data, String docId) async {
    var doc = await grpRef.doc(docId).collection(GROUP_CHATS).add(data.toJson());
    doc.update({'id': doc.id});
    return doc;
  }


  Query chatMessagesWithPagination({String? currentUserId, required String groupDocId, int? user_clear_chat_time}) {
    print("CLEARFILTER:::${groupDocId} :::${user_clear_chat_time}");
    if(user_clear_chat_time==-1 || user_clear_chat_time==null){
      print("Tjet");
      return grpRef.doc(groupDocId).collection(GROUP_CHATS).orderBy('createdAt', descending: true);
    }else{
      print("Tjet11213::::$user_clear_chat_time");
      print("Tjet11213:DATETME:::${DateTime.fromMillisecondsSinceEpoch(user_clear_chat_time).toString()}");
      // 1730968649813
      // 1730964369288
      print("Tjet11213:DATETME2:::${DateTime.fromMillisecondsSinceEpoch(1730964369288).toString()}");
      return grpRef.doc(groupDocId).collection(GROUP_CHATS).where('createdAt',isGreaterThan: user_clear_chat_time)
          .orderBy('createdAt', descending: true);
    }
  }

  Future<int> getGroupDetails({required String groupDocId,String? currentUserId,}) async{
    print("getGroupDetails.called:::${groupDocId}===>$currentUserId");
    DocumentSnapshot<Object?> a= await grpRef.doc(groupDocId).get();
    var x=await a.data() as Map<String,dynamic>;
    if(x['clear_chat']!=null &&x['clear_chat'][currentUserId]!=null){
      return x['clear_chat'][currentUserId];
    }
    return -1;
  }


  Future<void> addMessageToDb({required DocumentReference senderDoc, ChatMessageModel? data, UserModel? sender, UserModel? user, File? image, bool isRequest = false}) async {
    String imageUrl = '';

    if (image != null) {
      String originalFileName = path.basename(image.path ?? '');
      String extension = path.extension(originalFileName);
      String nameWithoutExt = path.basenameWithoutExtension(originalFileName);
      String timestamp = DateTime.now().millisecondsSinceEpoch.toString();
      String fileName = "${nameWithoutExt}_$timestamp$extension";
      Reference storageRef = _storage.ref().child("$GROUP_PROFILE_IMAGES/${getStringAsync(userId)}/$fileName");
      UploadTask uploadTask = storageRef.putFile(image);

      await uploadTask.then((e) async {
        await e.ref.getDownloadURL().then((value) async {
          imageUrl = value;
          log(imageUrl);
        }).catchError((e) {
          toast(e.toString());
        });
      }).catchError((e) {
        toast(e.toString());
      });
    }
    userRef.doc(getStringAsync(userId)).update({"lastMessageTime": DateTime.now().millisecondsSinceEpoch});
    updateChatDocument(senderDoc, image: image, imageUrl: imageUrl);
  }

  ///Forward Message
    Future<void> addMessageToDbForward({required DocumentReference senderDoc, ChatMessageModel? data, UserModel? sender, UserModel? user, File? image, bool isRequest = false}) async {
      print("Group Time Add Message Db Function Calling ");

      String imageUrl = '';

      if (data?.messageType == IMAGE || data?.messageType == VIDEO || data?.messageType == AUDIO ||
          data?.messageType == VOICE_NOTE || data?.messageType == DOC) {
        String originalFileName = getFileNameFromUrl(data?.photoUrl ?? '');
        String extension = path.extension(originalFileName);
        String nameWithoutExt = path.basenameWithoutExtension(originalFileName);
        String timestamp = DateTime.now().millisecondsSinceEpoch.toString();

        String fileName = "${nameWithoutExt}_$timestamp$extension";

        Reference storageRef = _storage.ref().child("$CHAT_DATA_IMAGES/${getStringAsync(userId)}/${fileName}");
        print("--------------181>>>>>${image?.path}");
        final response = await http.get(Uri.parse(image?.path??''));
        final Uint8List datas = response.bodyBytes;
        try {
          print("-----------189>>${datas.toString()}");
          UploadTask uploadTask = storageRef.putData(datas);

          // UploadTask uploadTask = storageRef.putFile(fileToUpload);
          TaskSnapshot snapshot = await uploadTask;
          imageUrl = await snapshot.ref.getDownloadURL();
          fileList.removeWhere((element) => element.id == senderDoc.id);
        } catch (e,s) {
          print("File does not exist: ${e.toString()}");
          print("File does not exist: ${s.toString()}");
        }
      } else {
        print("File does not exist: ${image?.path}");
        //toast("File not found.");
      }
      userRef.doc(getStringAsync(userId)).update({"lastMessageTime": DateTime.now().millisecondsSinceEpoch});
      updateChatDocument(senderDoc, image: image, imageUrl: imageUrl);
    }


  // ignore: body_might_complete_normally_nullable
  DocumentReference? updateChatDocument(DocumentReference data, {File? image, String? imageUrl}) {
    Map<String, dynamic> sendData = {'id': data.id};

    if (image != null) {
      sendData.putIfAbsent('photoUrl', () => imageUrl);
    }
    data.update(sendData);
  }

  addLatLong(ChatMessageModel data, {String? lat, String? long, String? groupId}) {
    Map<String, dynamic> sendData = {'id': data.id};
    grpRef.doc(groupId).collection(GROUP_CHATS).doc(data.id).set({'currentLat': lat, 'currentLong': long}, SetOptions(merge: true)).then((value) {
      //
    });

    sendData.putIfAbsent('current_lat', () => lat);
    sendData.putIfAbsent('current_lat', () => long);
  }

  addIsEncrypt(ChatMessageModel data) {
    Map<String, dynamic> sendData = {'id': data.id};
    sendData.putIfAbsent("isEncrypt", () => true);
  }


  Future<void> joinGroup({String? groupDocId, String? currentUserId}) async {
    try {
      grpRef.doc(groupDocId).update({
        'membersList': FieldValue.arrayUnion([currentUserId])
      });
    } on Exception catch (e) {
      log(e);
      throw 'Something went wrong';
    }
  }

  Future<void> leaveGroup({String? groupId, String? UserId,String? userName,String? groupName}) async {
    try {
      await grpRef.doc(groupId).update({
        'membersList': FieldValue.arrayRemove([UserId])
      });

      var chatRef = grpRef.doc(groupId).collection(GROUP_CHATS).doc();
      await chatRef.set({
        "id": chatRef.id,
        "addRemoveStatus": "$userName left the group",
        "messageType": ADD_REMOVE_GROUP,
        "createdAt": DateTime.now().millisecondsSinceEpoch,
      });
    } on Exception catch (e) {
      log(e.toString());
      throw 'Something went wrong';
    }
  }

  Future<void> deleteGrpSingleMessage({String? groupDocId, String? messageDocId}) async {
    try {
      final docRef = grpRef.doc(groupDocId).collection(GROUP_CHATS).doc(messageDocId);
      final docSnapshot = await docRef.get();

      if (docSnapshot.exists) {
        final data = docSnapshot.data();
        final imageUrl = data?['photoUrl'];

        // Delete image from Firebase Storage if present
        if (imageUrl != null && imageUrl.toString().startsWith('https://')) {
          try {
            final imageRef = FirebaseStorage.instance.refFromURL(imageUrl);
            await imageRef.delete();
          } catch (e) {
            log('🔥 Error deleting group chat image: $e');
          }
        }

        // Soft delete: update fields
        await docRef.update({
          'photoUrl': null,
          'catalogue': null,
          'isDeleted': true,
          'deletedFor': FieldValue.delete(),
          'replyMessage': "",
          'replyMessageId': "",
          'replyMessageSenderName': "",
          'replyMessageType': "",
          'shareUser': null,
          'groupId': "",
          'groupName': "",
          'groupProfile': "",
        });

        log("✅ Group message soft-deleted: $messageDocId");
      } else {
        log("❌ Group message not found: $messageDocId");
      }
    } catch (e) {
      log('🔥 Group message delete error: $e');
      throw 'Something went wrong';
    }
  }

  Future<void> clearAllMessages({String? groupDocId, required String deleteForUser}) async {
    print("CLearCHatGroup::${groupDocId}==>${deleteForUser}");
    DocumentSnapshot<Object?> a= await grpRef.doc(groupDocId).get();
    var x=await a.data() as Map<String,dynamic>;
    Map<String,dynamic> y={};
    if(x['clear_chat']!=null){
      y=x['clear_chat'];
    }
    y[deleteForUser]=Timestamp.now().millisecondsSinceEpoch;
    await grpRef.doc(groupDocId).update({
      "clear_chat":y
    });
    return;
    final WriteBatch _batch = fireStore.batch();

    grpRef.doc(groupDocId).update({
      "clear_chat":{
        "$deleteForUser":Timestamp.now()
      }
    });
    // grpRef.doc(groupDocId).collection(GROUP_CHATS).get().then((value) async {
    //   value.docs.forEach((document) {
    //     _batch.delete(document.reference);
    //   });
    //
    //   return _batch.commit();
    // }).catchError(log);
  }
  // Future<void> clearAllMessages({String? groupDocId}) async {
  //   final WriteBatch _batch = fireStore.batch();
  //
  //   grpRef.doc(groupDocId).collection(GROUP_CHATS).get().then((value) async {
  //     value.docs.forEach((document) {
  //       _batch.delete(document.reference);
  //     });
  //
  //     return _batch.commit();
  //   }).catchError(log);
  // }

  Future<void> deleteChat({String? groupDocId}) async {
    final WriteBatch _batch = fireStore.batch();
    await grpRef.doc(groupDocId).collection(GROUP_CHATS).get().then((value) {
      value.docs.forEach((document) {
        _batch.delete(document.reference);
      });
    });
    grpRef.doc(groupDocId).delete();

    return await _batch.commit();
  }

  Stream<QuerySnapshot<Object?>> fetchLastMessageBetween({required String groupDocId,int? user_clear_chat_time}) {
    if(user_clear_chat_time!=null){
      return grpRef.doc(groupDocId).collection(GROUP_CHATS).where('createdAt',isGreaterThan: user_clear_chat_time).orderBy('createdAt', descending: false).snapshots();
    }
    return grpRef.doc(groupDocId).collection(GROUP_CHATS).orderBy('createdAt', descending: false).snapshots();
  }
  // Stream<QuerySnapshot<Object?>> fetchLastMessageBetween({required String groupDocId}) {
  //   return grpRef.doc(groupDocId).collection(GROUP_CHATS).orderBy('createdAt', descending: false).snapshots();
  // }

  Stream<int> getUnReadCount({required String? currentUser, required String groupDocId}) {
    return grpRef.doc(groupDocId).collection(GROUP_CHATS).where('readBy.$currentUser', isEqualTo: false).snapshots().map((event) => event.docs.length);
  }


  Stream<List<GroupModel>> userGroupsStream(String userId) {
    return FirebaseFirestore.instance
        .collection(GROUPS_COLLECTION)
        .where('membersList', arrayContains: userId)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map((doc) {
        final data = doc.data();
        data['fltrdId'] = doc.id;
        return GroupModel.fromJson(data);
      }).toList();
    });
  }




  Future<void> removeUserFromReadyByOnLeavingGroup({required String userId, required String groupId}) async {
    final snapshot = await grpRef.doc(groupId).collection(GROUP_CHATS).get();

    for (var document in snapshot.docs) {
      final data = document.data();

      if (data.containsKey("readBy") && data["readBy"] is Map) {
        Map<String, dynamic> readBy = Map<String, dynamic>.from(data["readBy"]);

        if (readBy.containsKey(userId)) {
          readBy.remove(userId);

          await grpRef
              .doc(groupId)
              .collection(GROUP_CHATS)
              .doc(document.id)
              .update({"readBy": readBy}).catchError((e) {
            print("Error updating readBy: $e");
          });
        }
      }
    }
  }

  // Group Chat Set Reply True
  Future<void> setReplyToTrueGroupChat({required String userId, required String groupId, String? documentId}) async {
    await grpRef.doc(groupId).collection(GROUP_CHATS).get().then((value) {
      value.docs.forEach((document) {
        grpRef.doc(groupId).collection(GROUP_CHATS).doc(document.id).update({"isFromReply": true}).then((value) {}).catchError((e) {
              toast(e.toString());
            });
      });
    });
  }

  Future<void> makeUserAdmin({required String userId, required String groupId}) async {
    List<dynamic> ids = [];
    await grpRef.doc(groupId).get().then((doc) {
      ids = doc.get("adminIds");
      if (!ids.contains(userId)) ids.add(userId);
    });
    await grpRef.doc(groupId).update({"adminIds": ids}).then((value) {}).catchError((e) {
          toast(e.toString());
        });
  }

  Future<void> removeUserAsAdmin({required String userId, required String groupId}) async {
    List<dynamic> adminIds = [];
    List<dynamic> memberIds = [];
    String admin = '';
    await grpRef.doc(groupId).get().then((doc) async {
      adminIds = doc.get("adminIds");
      memberIds = doc.get("membersList");
      admin = doc.get("adminId");
      if (adminIds.contains(userId)) adminIds.remove(userId);
      (doc.get("adminId") == userId)
          ? adminIds.length > 0
              ? admin = adminIds.first
              : admin = memberIds.first
          : admin;
    });
    await grpRef.doc(groupId).update({"adminIds": adminIds, "adminId": admin}).then((value) {}).catchError((e) {
          toast(e.toString());
        });
  }

  Future<void> setUnReadStatusToTrue({required String groupDocId}) async {
    List<dynamic> members = [];
    await grpRef.doc(groupDocId).get().then((value) {
      members.addAll(value.get("membersList"));
    });
    await grpRef.doc(groupDocId).collection(GROUP_CHATS).get().then((value) {
      value.docs.forEach((document) {
        int count = 0;
        Map<String, dynamic> readBy = document.get("readBy");
        if (readBy.containsKey(getStringAsync(userId))) {
          readBy[getStringAsync(userId)] = true;
        }
        readBy.forEach((key, value) {
          if (value == true) count++;
        });
        grpRef
            .doc(groupDocId)
            .collection(GROUP_CHATS)
            .doc(document.id)
            .set({"readBy": readBy, "isMessageRead": count == members.length ? true : false}, SetOptions(merge: true))
            .then((value) {})
            .catchError((e) {
              toast(e.toString());
            });
      });
    });
  }

  StreamSubscription<QuerySnapshot<Map<String, dynamic>>> listenForMessageUpdates(String groupDocId) {
    return grpRef
        .doc(groupDocId)
        .collection(GROUP_CHATS)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .listen((snapshot) async {
      for (var document in snapshot.docs) {
        await updateMessageReadFlag(groupDocId, document);
      }
    });
  }

  Future<void> updateMessageReadFlag(String groupDocId, DocumentSnapshot document) async {
    List<dynamic> members = [];
    await grpRef.doc(groupDocId).get().then((value) {
      members.addAll(value.get("membersList"));
    });

    // Map<String, dynamic> readBy = document.get("readBy") ?? {};
    Map<String, dynamic> readBy = {};

    if (document.data() != null && (document.data() as Map<String, dynamic>).containsKey('readBy')) {
      final field = document.get("readBy");
      if (field is Map<String, dynamic>) {
        readBy = field;
      }
    }


    if (readBy[getStringAsync(userId)] != true) {
      readBy[getStringAsync(userId)] = true;
      int readCount = readBy.values.where((val) => val == true).length;
      bool isMessageRead = readCount == members.length;

      await grpRef
          .doc(groupDocId)
          .collection(GROUP_CHATS)
          .doc(document.id)
          .set(
        {"readBy": readBy, "isMessageRead": isMessageRead},
        SetOptions(merge: true),
      )
          .catchError((e) {
        toast(e.toString());
      });
    }
  }

  Future<void> addNewParticipantToReadyBy({required String groupDocId, required List<String> newParticipantsUserIds,List<UserModel>? userModelList,String? adminName}) async {
    print("------------>>530");
    await grpRef.doc(groupDocId).collection(GROUP_CHATS).get().then((value) {
      value.docs.forEach((document) async {
        Map<String, dynamic> readBy = document.get("readBy");
        newParticipantsUserIds.forEach((element) {
          if (!readBy.containsKey(element)) {
            readBy[element] = true;
          }
        });
        await grpRef.doc(groupDocId).collection(GROUP_CHATS).doc(document.id).update({"readBy": readBy}).then((value) {}).catchError((e) {
              toast(e.toString());
            });
      });
    });
    if (userModelList != null) {
      for (UserModel user in userModelList) {
        var chatRef = grpRef.doc(groupDocId).collection(GROUP_CHATS).doc();
        await chatRef.set({
          "id": chatRef.id,
          "addRemoveStatus": "$adminName added ${user.name}",
          "messageType": ADD_REMOVE_GROUP,
          "createdAt": DateTime.now().millisecondsSinceEpoch,
        });
      }
    }
  }

  Future<void> deleteGroup({String? groupDocId}) async {
    await grpRef.doc(groupDocId).delete();
  }








  /// Update User Archive True
  Future<void> setGroupArchiveToTrue({required String? groupDocId}) async {
    grpRef.doc(groupDocId).update({"isArchive": true});
  }

  /// Update User Archive False

  Future<void> setGroupArchiveToFalse({required String? groupDocId}) async {
    print("-----441>>${groupDocId}");
    grpRef.doc(groupDocId).update({"isArchive": false});
  }

  Stream<int> getGroupArchiveLength() {
    print("---------415>>>>${getStringAsync(userId)}");

    return grpRef.where('isArchive', isEqualTo: true).snapshots().map((documentSnapshot) {
      print("---------420>>>>${documentSnapshot.docs.length}");

      return documentSnapshot.docs.length;
    }
    ).handleError((e) => 0);
  }


}
