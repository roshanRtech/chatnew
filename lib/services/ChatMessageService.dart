import 'dart:async';
import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:encrypt/encrypt.dart' as encrypt;
import 'package:encrypt/encrypt.dart';
import 'package:path/path.dart' as path;
import 'package:http/http.dart' as http;
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:nb_utils/nb_utils.dart';
import 'package:chat/centralized_import.dart';

import '../models/LastMessageModel.dart';

class ChatMessageService extends BaseService {
  FirebaseFirestore fireStore = FirebaseFirestore.instance;
  late CollectionReference userRef;
  FirebaseStorage _storage = FirebaseStorage.instance;

  ChatMessageService() {
    ref = fireStore.collection(MESSAGES_COLLECTION);
    userRef = fireStore.collection(USER_COLLECTION);
  }

  Query chatMessagesWithPagination(
      {String? currentUserId, required String receiverUserId}) {
    return ref!
        .doc(currentUserId)
        .collection(receiverUserId)
        .orderBy("createdAt", descending: true);
  }

  Future<bool> checkUserStatus({
    required String senderId,
    required String receiverId,
  }) async {
    final contactSenderCollection = await userRef
        .doc(senderId)
        .collection(CONTACT_COLLECTION)
        .doc(receiverId)
        .get();
    final contactReciverCollection = await userRef
        .doc(receiverId)
        .collection(CONTACT_COLLECTION)
        .doc(senderId)
        .get();
    print("---------45>>${contactSenderCollection.exists}");
    print("---------46>>${contactReciverCollection.exists}");
    if (contactSenderCollection.exists && contactReciverCollection.exists) {
      return true;
    }
    return false;
  }

  Future<DocumentReference> addMessage(ChatMessageModel data) async {
    var doc = await ref!
        .doc(data.senderId)
        .collection(data.receiverId!)
        .add(data.toJson());
    doc.update({'id': doc.id});
    Map<String, dynamic> sendData = {'id': doc.id};
    sendData.putIfAbsent("isEncrypt", () => true);
    return doc;
  }

  ///TO READ THE DATA

  Future<ChatMessageModel> getMessage(ChatMessageModel data) async {
    Query query = ref!
        .doc(data.senderId)
        .collection(data.receiverId.isEmptyOrNull
            ? data.id ?? ''
            : data.receiverId ?? '')
        .where("id", isEqualTo: data.id);
    await query.get().then((value) {
      if (value.docs.isNotEmpty) {
        data = ChatMessageModel.fromJson(
            value.docs.first.data() as Map<String, dynamic>);
      }
    });

    return data;
  }

  Future<ChatMessageModel> forwardGetMessage(
      ChatMessageModel data, String? receiverIds) async {
    String receiverId = data.receiverId.toString();

    Query query = ref!
        .doc(data.senderId)
        .collection(receiverId)
        .where("id", isEqualTo: data.id);

    await query.get().then((value) {
      if (value.docs.isNotEmpty) {
        data = ChatMessageModel.fromJson(
            value.docs.first.data() as Map<String, dynamic>);
      }
    });

    return data;
  }

  Future<void> addMessageToDb(
      {required DocumentReference senderDoc,
      required ChatMessageModel data,
      UserModel? sender,
      UserModel? user,
      File? image,
      bool isRequest = false}) async {
    String imageUrl = '';

    if (data.messageType!.toLowerCase() == TYPE_Image ||
        data.messageType!.toLowerCase() == TYPE_DOC ||
        data.messageType!.toLowerCase() == TYPE_VIDEO ||
        data.messageType!.toLowerCase() == TYPE_AUDIO ||
        data.messageType!.toLowerCase() == TYPE_VOICE_NOTE) {
      if (data.messageType.validate().toUpperCase() ==
          TYPE_VIDEO.toUpperCase()) {
        image = await File(image?.path ?? '');
        // image = await compressVideo(image);
      }
      if (data.messageType.validate().toUpperCase() ==
          TYPE_Image.toUpperCase()) {
        XFile? s1 = await imageCompress(filepath: image?.path ?? '');
        if (s1 != null) {
          image = File(s1.path);
        }
      }
      String originalFileName = path.basename(image?.path ?? '');
      String extension = path.extension(originalFileName);
      String nameWithoutExt = path.basenameWithoutExtension(originalFileName);
      String timestamp = DateTime.now().millisecondsSinceEpoch.toString();

      String fileName = "${nameWithoutExt}_$timestamp$extension";
      Reference storageRef = _storage
          .ref()
          .child("$CHAT_DATA_IMAGES/${getStringAsync(userId)}/$fileName");

      UploadTask uploadTask = storageRef.putFile(image!);

      // print("Before Upload Progress");
      // uploadTask.snapshotEvents.listen((TaskSnapshot snapshot) {
      //   double progress = snapshot.bytesTransferred / snapshot.totalBytes;
      //   print("Upload Progress: ${(progress * 100).toStringAsFixed(2)}%");
      // });

// // Listen to upload progress
//       uploadTask.snapshotEvents.listen((TaskSnapshot snapshot) {
//         double progress =
//             snapshot.bytesTransferred / snapshot.totalBytes;
//
//         print("Upload Progress: ${(progress * 100).toStringAsFixed(2)}%");
//       });
//
// // Handle completion
//       uploadTask.then((TaskSnapshot e) async {
//         print("UploadTask then called");
//         try {
//           String value = await e.ref.getDownloadURL();
//           imageUrl = value;
//
//           print("Image URL => ${imageUrl}");
//
//           fileList.removeWhere((element) => element.id == senderDoc.id);
//         } catch (err) {
//           toast(err.toString());
//         }
//       }).catchError((e) {
//         toast(e.toString());
//       });

      await uploadTask.then((e) async {
        await e.ref.getDownloadURL().then((value) async {
          imageUrl = value;
          print("Download URL => ${imageUrl}");
          fileList.removeWhere((element) => element.id == senderDoc.id);
        }).catchError((e) async {
          toast(e.toString());
        });
      }).catchError((e) {
        toast(e.toString());
      });
    }
    updateChatDocument(senderDoc, image: image, imageUrl: imageUrl);

    log(data.senderId.toString() +
        "  " +
        data.receiverId.toString() +
        " " +
        data.createdAt.toString());
    userRef.doc(data.senderId).update({"lastMessageTime": data.createdAt});
    userRef.doc(data.receiverId).update({"lastMessageTime": data.createdAt});

    addToContacts(
        senderId: data.senderId,
        receiverId: data.receiverId,
        isRequest: isRequest);

    DocumentReference receiverDoc = await ref!
        .doc(data.receiverId)
        .collection(data.senderId!)
        .add(data.toJson());

    updateChatDocument(receiverDoc, image: image, imageUrl: imageUrl);
    senderDoc.update({'id2': receiverDoc.id});
    receiverDoc.update({'id2': senderDoc.id});
  }

  Future<void> addMessageToDbForward(
      {required DocumentReference senderDoc,
      required ChatMessageModel data,
      UserModel? sender,
      List<UserModel>? user,
      File? image,
      bool isRequest = false}) async {
    String imageUrl = '';

    if (data.messageType == IMAGE ||
        data.messageType == VIDEO ||
        data.messageType == AUDIO ||
        data.messageType == VOICE_NOTE ||
        data.messageType == DOC) {
      imageUrl = image?.path ?? '';
      if (image != null) {
        String originalFileName = getFileNameFromUrl(data.photoUrl ?? '');
        String extension = path.extension(originalFileName);
        String nameWithoutExt = path.basenameWithoutExtension(originalFileName);
        String timestamp = DateTime.now().millisecondsSinceEpoch.toString();

        String fileName = "${nameWithoutExt}_$timestamp$extension";

        Reference storageRef = _storage
            .ref()
            .child("$CHAT_DATA_IMAGES/${getStringAsync(userId)}/${fileName}");
        print("--------------181>>>>>${image.path}");
        final response = await http.get(Uri.parse(image.path));
        final Uint8List datas = response.bodyBytes;
        try {
          print("-----------189>>${datas.toString()}");
          UploadTask uploadTask = storageRef.putData(datas);

          // UploadTask uploadTask = storageRef.putFile(fileToUpload);
          TaskSnapshot snapshot = await uploadTask;
          imageUrl = await snapshot.ref.getDownloadURL();
          fileList.removeWhere((element) => element.id == senderDoc.id);
        } catch (e, s) {
          print("File does not exist: ${e.toString()}");
          print("File does not exist: ${s.toString()}");
        }
      } else {
        print("File does not exist: ${image?.path}");
        // toast("File not found.");
      }
    }

    updateChatDocument(senderDoc, image: image, imageUrl: imageUrl);

    log(data.senderId.toString() +
        "  " +
        data.receiverId.toString() +
        " " +
        data.createdAt.toString());
    userRef.doc(data.senderId).update({"lastMessageTime": data.createdAt});
    userRef.doc(data.receiverId).update({"lastMessageTime": data.createdAt});

    addToContacts(
        senderId: data.senderId,
        receiverId: data.receiverId,
        isRequest: isRequest);

    DocumentReference receiverDoc = await ref!
        .doc(data.receiverId)
        .collection(data.senderId!)
        .add(data.toJson());

    updateChatDocument(receiverDoc, image: image, imageUrl: imageUrl);
    print('-----------216');
    senderDoc.update({'id2': receiverDoc.id});
    receiverDoc.update({'id2': senderDoc.id});
  }

  // ignore: body_might_complete_normally_nullable
  DocumentReference? updateChatDocument(DocumentReference data,
      {File? image, String? imageUrl}) {
    Map<String, dynamic> sendData = {'id': data.id};

    if (image != null || imageUrl != null) {
      sendData.putIfAbsent('photoUrl', () => imageUrl);
    }
    data.update(sendData);
  }

  addLatLong(ChatMessageModel data, {String? lat, String? long}) {
    Map<String, dynamic> sendData = {'id': data.id};

    ref!.doc(data.id).set({'currentLat': lat, 'currentLong': long},
        SetOptions(merge: true)).then((value) {
      //Do your stuff.
    });

    sendData.putIfAbsent('current_lat', () => lat);
    sendData.putIfAbsent('current_lat', () => long);
  }

  DocumentReference getContactsDocument({String? of, String? forContact}) {
    return userRef.doc(of).collection(CONTACT_COLLECTION).doc(forContact);
  }

  addToContacts(
      {String? senderId, String? receiverId, bool isRequest = false}) async {
    Timestamp currentTime = Timestamp.now();

    await addToSenderContacts(senderId, receiverId, currentTime);
    if (!isRequest) {
      await addToReceiverContacts(senderId, receiverId, currentTime);
    }
  }

  Future<bool> isUserInContacts({String? ownerId, String? contactId}) async {
    final doc =
        await getContactsDocument(of: ownerId, forContact: contactId).get();
    return doc.exists;
  }

  Future<void> addToSenderContacts(
      String? senderId, String? receiverId, currentTime) async {
    DocumentSnapshot senderSnapshot =
        await getContactsDocument(of: senderId, forContact: receiverId).get();

    if (!senderSnapshot.exists) {
      //does not exists
      ContactModel receiverContact =
          ContactModel(uid: receiverId, addedOn: currentTime);
      await getContactsDocument(of: senderId, forContact: receiverId)
          .set(receiverContact.toJson());
    }
  }

  Future<void> addToReceiverContacts(
      String? senderId, String? receiverId, currentTime) async {
    DocumentSnapshot receiverSnapshot =
        await getContactsDocument(of: receiverId, forContact: senderId).get();

    if (!receiverSnapshot.exists) {
      ContactModel senderContact =
          ContactModel(uid: senderId, addedOn: currentTime);
      await getContactsDocument(of: receiverId, forContact: senderId)
          .set(senderContact.toJson());
    }
  }

  // Stream<QuerySnapshot> fetchContacts({String? userId}) {
  //   return userRef
  //       .doc(userId)
  //       .collection(CONTACT_COLLECTION)
  //       .orderBy("lastMessageTime", descending: true) // Uncomment if needed
  //       .limit(50) // Apply limit here
  //       .snapshots();
  // }

  Stream<QuerySnapshot> fetchContacts({String? userId}) {
    // return userRef.doc(userId).collection(CONTACT_COLLECTION).orderBy("lastMessageTime", descending: true).snapshots();
    return userRef.doc(userId).collection(CONTACT_COLLECTION).snapshots();
  }

  Future<Map<String, dynamic>?> getAdminData(String senderId) async {
    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('admin') // 👈 your admin collection
          .doc(senderId)
          .get();

      if (snapshot.exists) {
        return snapshot.data(); // contains {name, photoUrl, ...}
      }
      return null;
    } catch (e) {
      print("❌ Error fetching user: $e");
      return null;
    }
  }

  /*Stream<QuerySnapshot> fetchContacts({String? userId}) {
    return userRef
        .doc(userId)
        .collection(CONTACT_COLLECTION)
        .orderBy("lastMessageTime", descending: true)
        .snapshots()
        .distinct(); // Ensures UI updates only when necessary
  }*/

  // Stream<QuerySnapshot> fetchPhoneNumbers({String? id,}) {
  //   print("Fetch NUmber Function called");
  //
  //   return userRef.doc(userId).collection(USER_COLLECTION).where('uid', isNotEqualTo: null).snapshots();
  // }

  Stream<List<UserModel>> getUserDetailsById({String? id, String? searchText}) {
    Query isNullQuery = userRef.where('uid', isEqualTo: id).where('caseSearch',
        arrayContains: searchText != null && searchText.isNotEmpty
            ? searchText.toLowerCase()
            : null);

    Query isFalseQuery = userRef.where('uid', isEqualTo: id).where('caseSearch',
        arrayContains: searchText != null && searchText.isNotEmpty
            ? searchText.toLowerCase()
            : null);

    Stream<List<UserModel>> stream1 = isNullQuery.snapshots().map((snapshot) =>
        snapshot.docs
            .map(
                (doc) => UserModel.fromJson(doc.data() as Map<String, dynamic>))
            .toList());

    return stream1;
  }

  Future<void> typingStatus(
      String senderId, String receiverId, bool isTyping) async {
    String chatDocId = senderId.compareTo(receiverId) < 0
        ? '${senderId}_$receiverId'
        : '${receiverId}_$senderId';

    await FirebaseFirestore.instance.collection('chats').doc(chatDocId).set({
      'typingStatus': {senderId: isTyping}
    }, SetOptions(merge: true));
  }

  Stream<DocumentSnapshot> typingGetStatus(String senderId, String receiverId) {
    String chatDocId = senderId.compareTo(receiverId) < 0
        ? '${senderId}_$receiverId'
        : '${receiverId}_$senderId';

    return FirebaseFirestore.instance
        .collection('chats')
        .doc(chatDocId)
        .snapshots();
  }

  Stream<List<UserModel>> getArchiveUserById(
      {required String id, String? searchText}) {
    Query query = userRef.where("uid", isEqualTo: id);

    if (searchText != null && searchText.trim().isNotEmpty) {
      query =
          query.where('caseSearch', arrayContains: searchText.toLowerCase());
    }

    return query.snapshots().map((event) {
      print(
          "Query returned ${event.docs.length} documents for uid: $id, searchText: $searchText");
      return event.docs
          .map((e) => UserModel.fromJson(e.data() as Map<String, dynamic>))
          .toList();
    });
  }

  Future<void> setArchive({
    required String senderId,
    required String receiverId,
    required Map<String, dynamic> data,
  }) async {
    try {
      final doc = userRef.doc(senderId).collection('archived').doc(receiverId);
      await doc.set(data);

      await userRef
          .doc(senderId)
          .collection('contact')
          .doc(receiverId)
          .delete();
      print("✅ Chat archived for $receiverId from $senderId");
    } catch (e, stack) {
      print("🔥 Failed to archive chat: $e");
      print(stack);
    }
  }

  Stream<QuerySnapshot> getArchive({String? userId}) {
    return userRef.doc(userId).collection('archived').snapshots();
  }

  Future<void> removeArchive({
    required String senderId,
    required String receiverId,
    required Map<String, dynamic> data,
  }) async {
    try {
      final doc = userRef.doc(senderId).collection('contact').doc(receiverId);
      await doc.set(data);

      await userRef
          .doc(senderId)
          .collection('archived')
          .doc(receiverId)
          .delete();

      print("✅ Chat archived for $receiverId from $senderId");
    } catch (e, stack) {
      print("🔥 Failed to archive chat: $e");
      print(stack);
    }
  }

  Stream<int> getArchivedCollectionLength(String senderId) {
    try {
      return userRef
          .doc(senderId)
          .collection('archived')
          .snapshots()
          .map((snapshot) => snapshot.docs.length);
    } catch (e) {
      print('Error getting collection length: $e');
      return Stream.value(0);
    }
  }

  Stream<QuerySnapshot> fetchLastMessageBetween(
      {required String senderId, required String receiverId}) {
    return ref!
        .doc(senderId)
        .collection(receiverId)
        .orderBy("createdAt", descending: false)
        .snapshots();
  }

  String _generateChatId(String user1, String user2) {
    return user1.compareTo(user2) < 0 ? '${user1}_$user2' : '${user2}_$user1';
  }

  Future<void> updateLastMessage({
    required String senderId,
    required String text,
    required bool isRequest,
    required FieldValue timestamp,
    required bool isGroupMessage,
    required bool isArchive,
    String? receiverId,
    String? groupId,
    String? groupName,
    List<String>? groupParticipants,
  }) async {
    try {
      final docRef =
          FirebaseFirestore.instance.collection(LAST_MESSAGE_COLLECTION);

      final chatId = isGroupMessage
          ? groupId ?? ''
          : _generateChatId(senderId, receiverId ?? '');

      print("ChatId => ${chatId}");

      // 🧩 Step 1: Fetch existing archive map to preserve all users’ states
      Map<String, dynamic> existingArchive = {};
      final docSnap = await docRef.doc(chatId).get();
      if (docSnap.exists) {
        final data = docSnap.data() as Map<String, dynamic>;
        if (data.containsKey('isArchive')) {
          existingArchive = Map<String, dynamic>.from(data['isArchive']);
        }
      }

      // 🧠 Step 2: Update sender’s archive flag (for both group or private)
      existingArchive[senderId] = isArchive;

      // 🗃 Step 3: Prepare common payload
      final data = <String, dynamic>{
        'chatId': chatId,
        'senderId': senderId,
        'lastMessage': text,
        'timestamp': timestamp,
        'isRequest': isRequest,
        'isGroupMessage': isGroupMessage,
        'isArchive': existingArchive, // 🔹 now shared across all chat types
      };

      // 🧑‍🤝‍🧑 Step 4: Add extra details based on chat type
      if (isGroupMessage) {
        data.addAll({
          'groupId': groupId,
          'groupName': groupName,
          'participants': groupParticipants ?? [],
          'unreadCounts':
              _buildGroupUnreadMap(groupParticipants ?? [], senderId),
        });
      } else {
        final participants = [senderId, receiverId];
        data.addAll({
          'receiverId': receiverId,
          'participants': participants,
          'isSeenBySender': true,
          'isSeenByReceiver': false,
          'unreadCountReceiver': FieldValue.increment(1),
          'unreadCountSender': 0,
        });
      }

      // 💾 Step 5: Save to Firestore
      await docRef.doc(chatId).set(data, SetOptions(merge: true));
    } catch (e) {
      print('Error updating last message: $e');
      rethrow;
    }
  }

  Map<String, dynamic> _buildGroupUnreadMap(
      List<String> participants, String senderId) {
    final Map<String, dynamic> unreadMap = {};
    for (final id in participants) {
      unreadMap[id] = id == senderId ? 0 : FieldValue.increment(1);
    }
    return unreadMap;
  }

  Future<void> updateStatusOfChatRequest({
    required String senderId,
    required String receiverId,
    required bool isRequest,
  }) async {
    try {
      final docRef =
          FirebaseFirestore.instance.collection(LAST_MESSAGE_COLLECTION);
      // Generate chatId exactly like your updateLastMessage function
      final chatId = _generateChatId(senderId, receiverId);
      print("ChatRequest Update ChatId => $chatId");
      final data = {
        'isRequest': isRequest,
      };
      await docRef.doc(chatId).set(
            data,
            SetOptions(merge: true),
          );
    } catch (e) {
      print("Error updating chat request status: $e");
      rethrow;
    }
  }

  /// Unarchive private chat
  /// ✅ Add private chat to archive
  Future<void> addPrivateChatToArchive({
    required String senderId,
    required String receiverId,
  }) async {
    final chatId = _generateChatId(senderId, receiverId);
    await _updateArchiveStatus(chatId, senderId, true);
  }

  /// ✅ Add group chat to archive
  Future<void> addGroupChatToArchive({
    required String groupId,
    required String userId,
  }) async {
    await _updateArchiveStatus(groupId, userId, true);
  }

  /// ✅ Remove private chat from archive
  Future<void> removePrivateChatFromArchive({
    required String senderId,
    required String receiverId,
  }) async {
    final chatId = _generateChatId(senderId, receiverId);
    await _updateArchiveStatus(chatId, senderId, false);
  }

  /// ✅ Remove group chat from archive
  Future<void> removeGroupChatFromArchive({
    required String groupId,
    required String userId,
  }) async {
    await _updateArchiveStatus(groupId, userId, false);
  }

  /// 🔁 Core updater (used by both add/remove functions)
  Future<void> _updateArchiveStatus(
    String chatId,
    String userId,
    bool isArchived,
  ) async {
    final docRef = FirebaseFirestore.instance
        .collection(LAST_MESSAGE_COLLECTION)
        .doc(chatId);

    try {
      final docSnap = await docRef.get();
      if (!docSnap.exists) return;

      final data = docSnap.data() as Map<String, dynamic>;
      Map<String, dynamic> existingArchive = {};

      if (data.containsKey('isArchive')) {
        existingArchive = Map<String, dynamic>.from(data['isArchive']);
      }

      existingArchive[userId] = isArchived;

      await docRef.set({'isArchive': existingArchive}, SetOptions(merge: true));
    } catch (e) {
      print('Error updating archive status: $e');
      rethrow;
    }
  }

  Future<void> deletePrivateChat({
    required String senderId,
    required String receiverId,
  }) async {
    try {
      final chatId = _generateChatId(senderId, receiverId);
      final docRef = FirebaseFirestore.instance
          .collection(LAST_MESSAGE_COLLECTION)
          .doc(chatId);

      final docSnap = await docRef.get();
      if (!docSnap.exists) return;

      final data = docSnap.data() as Map<String, dynamic>;

      // Get participants
      List<dynamic> participants = [];
      if (data.containsKey('participants')) {
        participants = List<dynamic>.from(data['participants']);
      }

      // Remove only the current user
      participants.remove(senderId);

      // Also clean up unread counts and archive state for that user
      Map<String, dynamic> unreadCounts = {};
      Map<String, dynamic> archiveMap = {};

      if (data.containsKey('unreadCounts')) {
        unreadCounts = Map<String, dynamic>.from(data['unreadCounts']);
        unreadCounts.remove(senderId);
      }

      if (data.containsKey('isArchive')) {
        archiveMap = Map<String, dynamic>.from(data['isArchive']);
        archiveMap.remove(senderId);
      }

      // Update Firestore document (without deleting it)
      await docRef.set({
        'participants': participants,
        'unreadCounts': unreadCounts,
        'isArchive': archiveMap,
      }, SetOptions(merge: true));

      print("✅ Removed user $senderId from private chat with $receiverId");
    } catch (e) {
      print('Error removing user from private chat: $e');
      rethrow;
    }
  }

  /// 🗑 Delete group chat (removes group doc from last message collection)
  Future<void> deleteGroupChat({
    required String groupId,
    required String userId,
  }) async {
    try {
      final docRef = FirebaseFirestore.instance
          .collection(LAST_MESSAGE_COLLECTION)
          .doc(groupId);

      final docSnap = await docRef.get();
      if (!docSnap.exists) return;

      final data = docSnap.data() as Map<String, dynamic>;
      List<dynamic> participants = [];

      // Get existing participants
      if (data.containsKey('participants')) {
        participants = List<dynamic>.from(data['participants']);
      }

      // Remove current user from the list
      participants.remove(userId);

      // If you also track unreadCounts or archive per user, clean them too
      Map<String, dynamic> unreadCounts = {};
      Map<String, dynamic> archiveMap = {};

      if (data.containsKey('unreadCounts')) {
        unreadCounts = Map<String, dynamic>.from(data['unreadCounts']);
        unreadCounts.remove(userId);
      }

      if (data.containsKey('isArchive')) {
        archiveMap = Map<String, dynamic>.from(data['isArchive']);
        archiveMap.remove(userId);
      }

      // Update Firestore
      await docRef.set({
        'participants': participants,
        'unreadCounts': unreadCounts,
        'isArchive': archiveMap,
      }, SetOptions(merge: true));

      print("✅ Removed user $userId from group $groupId successfully");
    } catch (e) {
      print('Error removing user from group: $e');
      rethrow;
    }
  }

  Stream<List<LastMessageModel>> getUserChatListByLastMessage(String userId) {
    return FirebaseFirestore.instance
        .collection(LAST_MESSAGE_COLLECTION)
        .where('participants', arrayContains: userId)
        .orderBy('timestamp', descending: true)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map((doc) => LastMessageModel.fromDoc(doc)).toList();
    });
  }

  String generateLastMessagePreview(MessageType type) {
    switch (type) {
      case MessageType.IMAGE:
        return '🖼️ Photo';
      case MessageType.VIDEO:
        return '🎬 Video';
      case MessageType.AUDIO:
        return '🎧 Audio';
      case MessageType.DOC:
        return '📄 Document';
      case MessageType.LOCATION:
        return '📍 Location';
      case MessageType.VOICE_NOTE:
        return '🎙️ Voice note';
      case MessageType.SHAREPROFILE:
        return '🔗 Profile';
      default:
        return '';
    }
  }

  Future<void> markAsSeen(String chatId, String userId, bool isGroup) async {
    final docRef = FirebaseFirestore.instance
        .collection(LAST_MESSAGE_COLLECTION)
        .doc(chatId);
    final snapshot = await docRef.get();
    if (!snapshot.exists) return;

    final data = snapshot.data()!;

    if (isGroup) {
      if (data.containsKey('unreadCounts')) {
        final Map<String, dynamic> unreadCounts =
            Map<String, dynamic>.from(data['unreadCounts']);
        if (unreadCounts.containsKey(userId)) {
          unreadCounts[userId] = 0;
          await docRef.update({
            'unreadCounts': unreadCounts,
          });
        }
      }
    } else {
      final senderId = data['senderId'];
      final receiverId = data['receiverId'];

      if (userId == receiverId) {
        await docRef.update({
          'isSeenByReceiver': true,
          'unreadCountReceiver': 0,
        });
      } else if (userId == senderId) {
        await docRef.update({
          'isSeenBySender': true,
          'unreadCountSender': 0,
        });
      }
    }
  }

  //// Get all users groups
  /// TODO

  Future<void> clearAllMessages(
      {String? senderId, required String receiverId}) async {
    final WriteBatch _batch = fireStore.batch();

    ref!.doc(senderId).collection(receiverId).get().then((value) async {
      value.docs.forEach((document) {
        _batch.delete(document.reference);
      });

      return _batch.commit();
    }).catchError(log);
  }

  Future<bool?> checkUserExistContact(
      {String? senderId, required String receiverId}) async {
    var contactDoc =
        await userRef.doc(senderId).collection('contact').doc(receiverId).get();

    if (contactDoc.exists) {
      return true;
    } else {
      return false;
    }
  }

  Future<void> deleteSingleMessageForAll({
    required String senderId,
    required String receiverId,
    required String documentId,
    required String doc2ID,
  }) async {
    try {
      // List of message IDs to update
      final docIds = [documentId, doc2ID];

      for (final docId in docIds) {
        // Update sender side
        await _deleteMessageWithImage(senderId, receiverId, docId);

        // Update receiver side
        await _deleteMessageWithImage(receiverId, senderId, docId);
      }
    } on Exception catch (e) {
      log('Error deleting message: $e');
      throw 'Something went wrong';
    }
  }

  Future<void> _deleteMessageWithImage(
      String user1, String user2, String docId) async {
    final docRef = ref!.doc(user1).collection(user2).doc(docId);
    final doc = await docRef.get();
    print("-------454>>>${user1}");

    if (doc.exists) {
      final data = doc.data();
      final imageUrl = data?['photoUrl'];

      if (imageUrl != null && imageUrl.toString().startsWith('https://')) {
        try {
          final imageRef = FirebaseStorage.instance.refFromURL(imageUrl);
          await imageRef.delete();
        } catch (e) {
          log('Failed to delete image: $e');
        }
      }

      await docRef.update({
        'photoUrl': null,
        'isDeleted': true,
        'catalogue': null,
        'shareUser': null,
        'deletedFor': FieldValue.delete(),
        'replyMessage': "",
        'replyMessageId': "",
        'replyMessageSenderName': "",
        'replyMessageType': "",
        'groupId': "",
        'groupName': "",
        'groupProfile': "",
      });

      // Delete the Firestore document
      //  await docRef.delete();
    }
  }

  editMessage(
      {required String senderId,
      required String receiverId,
      String? documentId,
      String? docId2,
      required String message}) async {
    try {
      print("JUSTCHECKING1");
      ref!.doc(senderId).collection(receiverId).doc(documentId).get().then(
        (value) {
          if (value.exists) {
            ref!.doc(senderId).collection(receiverId).doc(documentId).update({
              "message": message,
            });
          }
        },
      );
      print("JUSTCHECKING2");
      ref!.doc(senderId).collection(receiverId).doc(docId2).get().then(
        (value) {
          if (value.exists) {
            ref!.doc(senderId).collection(receiverId).doc(docId2).update({
              "message": message,
            });
          }
        },
      );
      print("JUSTCHECKING3");
      ref!.doc(receiverId).collection(senderId).doc(documentId).get().then(
        (value) {
          if (value.exists) {
            ref!.doc(receiverId).collection(senderId).doc(documentId).update({
              "message": message,
            });
          }
        },
      );
      print("JUSTCHECKING4");
      ref!.doc(receiverId).collection(senderId).doc(docId2).get().then(
        (value) {
          if (value.exists) {
            ref!.doc(receiverId).collection(senderId).doc(docId2).update({
              "message": message,
            });
          }
        },
      );
    } catch (e) {}
  }

  Future<void> addReaction({
    required String senderId,
    required String receiverId,
    required String documentId,
    required String docId2,
    required ReactionModel reaction,
  }) async {
    try {
      final senderRef1 =
          ref!.doc(senderId).collection(receiverId).doc(documentId);
      final senderRef2 = ref!.doc(senderId).collection(receiverId).doc(docId2);

      final receiverRef1 =
          ref!.doc(receiverId).collection(senderId).doc(documentId);
      final receiverRef2 =
          ref!.doc(receiverId).collection(senderId).doc(docId2);

      Future<void> _updateReaction(DocumentReference docRef) async {
        final snapshot = await docRef.get();
        if (!snapshot.exists) return;

        final data = snapshot.data() as Map<String, dynamic>?;

        List<dynamic> reactions = data?['groupReaction'] ?? [];

        // Convert list to ReactionModel
        List<ReactionModel> currentReactions = reactions
            .map((e) => ReactionModel.fromJson(Map<String, dynamic>.from(e)))
            .toList();

        // Check if this user already reacted
        int index = currentReactions.indexWhere((r) => r.uid == reaction.uid);

        if (index >= 0) {
          currentReactions[index] = reaction;
        } else {
          currentReactions.add(reaction);
        }

        await docRef.update({
          "groupReaction": currentReactions.map((r) => r.toJson()).toList(),
        });
      }

      // ✅ Update all four copies
      await _updateReaction(senderRef1);
      await _updateReaction(senderRef2);
      await _updateReaction(receiverRef1);
      await _updateReaction(receiverRef2);
    } catch (e) {
      print("Error adding reaction: $e");
    }
  }

  Future<void> removeReaction({
    required String senderId,
    required String receiverId,
    required String documentId,
    required String docId2,
  }) async {
    try {
      final senderRef1 =
          ref!.doc(senderId).collection(receiverId).doc(documentId);
      final senderRef2 = ref!.doc(senderId).collection(receiverId).doc(docId2);

      final receiverRef1 =
          ref!.doc(receiverId).collection(senderId).doc(documentId);
      final receiverRef2 =
          ref!.doc(receiverId).collection(senderId).doc(docId2);

      Future<void> _removeReaction(DocumentReference docRef) async {
        try {
          final snapshot = await docRef.get();
          if (!snapshot.exists) return;
          final data = snapshot.data() as Map<String, dynamic>;
          List<dynamic> reactions = List.from(data["groupReaction"] ?? []);

          // Remove only the object with matching uid
          reactions.removeWhere(
              (reaction) => reaction["uid"] == getStringAsync(userId));

          // Update Firestore with new filtered array
          await docRef.update({"groupReaction": reactions});
        } catch (e) {
          print("Error removing group reaction: $e");
        }
      }

      // ✅ Remove from all four copies
      await _removeReaction(senderRef1);
      await _removeReaction(senderRef2);
      await _removeReaction(receiverRef1);
      await _removeReaction(receiverRef2);
    } catch (e) {
      print("Error removing reaction: $e");
    }
  }

  Future<void> deleteChat(
      {String? senderId, required String receiverId}) async {
    final WriteBatch _batch = fireStore.batch();
    await ref!.doc(senderId).collection(receiverId).get().then((value) {
      value.docs.forEach((document) {
        _batch.delete(document.reference);
      });
    });
    userRef
        .doc(senderId)
        .collection(CONTACT_COLLECTION)
        .doc(receiverId)
        .delete();

    return await _batch.commit();
  }

  Future<void> deleteChatRequestChat(
      {String? senderId, required String receiverId}) async {
    await userRef
        .doc(senderId)
        .collection(CHAT_REQUEST)
        .doc(receiverId)
        .delete();
    await userRef
        .doc(receiverId)
        .collection(CHAT_REQUEST)
        .doc(senderId)
        .delete();
  }

  Future<void> deleteSingleMessage(
      {String? senderId,
      required String receiverId,
      String? documentId}) async {
    try {
      print("----------568>>${documentId}");

      final docRef = ref!.doc(senderId).collection(receiverId).doc(documentId);

      // Mark message as deleted for the current user
      await docRef.update({
        'deletedFor': FieldValue.arrayUnion([senderId]),
        'replyMessage': "",
      });

      // If you want to delete the message entirely:
      // await docRef.delete();
    } on Exception catch (e) {
      log(e.toString());
      throw 'Something went wrong';
    }
  }

  Stream<List<DocumentSnapshot>> getMessagesStream(
      String senderId, String receiverId) {
    return ref!
        .doc(senderId)
        .collection(receiverId)
        .orderBy("createdAt", descending: true)
        .snapshots()
        .map((query) => query.docs);
  }

  StreamSubscription<List<DocumentSnapshot<Object?>>> listenToUnreadMessages(
      String senderId, String receiverId) {
    return getMessagesStream(receiverId, senderId).listen((messageDocs) {
      for (var doc in messageDocs) {
        if (doc['isMessageRead'] == false &&
            doc['senderId'] != getStringAsync(userId)) {
          // Update the read flag
          doc.reference.update({'isMessageRead': true});
        }
      }
    });
  }

  Future<void> setUnReadStatusToTrue(
      {required String senderId,
      required String receiverId,
      String? documentId}) async {
    if (!(senderId == getStringAsync(userId))) {
      ref!
          .doc(senderId)
          .collection(receiverId)
          .where('isMessageRead', isEqualTo: false)
          .get()
          .then((value) {
        value.docs.forEach((element) {
          element.reference.update({'isMessageRead': true});
        });
      });
    } else {
      ref!
          .doc(receiverId)
          .collection(senderId)
          .where('isMessageRead', isEqualTo: false)
          .get()
          .then((value) {
        value.docs.forEach((element) {
          element.reference.update({'isMessageRead': true});
        });
      });
    }
  }

  /// set reply msg true
  Future<void> setReplyToTrue(
      {required String senderId,
      required String receiverId,
      String? documentId}) async {
    ref!
        .doc(senderId)
        .collection(receiverId)
        .doc(documentId)
        .update({"isFromReply": true});
  }

  Stream<int> getUnReadCount(
      {String? senderId, required String receiverId, String? documentId}) {
    print("Get UnReadCount Function Called ");
    if (!(senderId == getStringAsync(userId))) {
      return ref!
          .doc(senderId)
          .collection(receiverId)
          .where('isMessageRead', isEqualTo: false)
          .where('receiverId', isEqualTo: senderId)
          .snapshots()
          .map((event) => event.docs.length)
          .handleError((e) => 0);
    }
    return ref!
        .doc(receiverId)
        .collection(senderId ?? '')
        .where('isMessageRead', isEqualTo: false)
        .where('receiverId', isEqualTo: senderId)
        .snapshots()
        .map((event) => event.docs.length)
        .handleError((e) => 0);
  }

  int fetchForMessageCount(currentUserId) {
    List<ContactModel> contactList = [];
    appStore.chatNotificationCount = 0;
    Query query1 =
        userRef.doc(currentUserId.toString()).collection(CONTACT_COLLECTION);
    query1.get().then((value) {
      value.docs.forEach((element) {
        ContactModel contactData =
            ContactModel.fromJson(element.data() as Map<String, dynamic>);
        contactList.add(contactData);
      });
      contactList.forEach((e2) {
        Query query = ref!
            .doc(e2.uid.toString())
            .collection(currentUserId)
            .orderBy("createdAt", descending: true);
        query.get().then((value) {
          if (value.docs.first.data() != null) {
            ChatMessageModel data = ChatMessageModel.fromJson(
                value.docs.first.data() as Map<String, dynamic>);
            if (data.receiverId == loginStore.mId &&
                !data.isMessageRead.validate()) {
              appStore.chatNotificationCount =
                  appStore.chatNotificationCount + 1;
            }
          }
        }).catchError((e) {
          log(e.toString());
        });
      });
    }).catchError((e) {
      log(e);
    });

    return appStore.chatNotificationCount;
  }

  ChatMessageModel data = ChatMessageModel();

  Future<ChatMessageModel> fetchLastMessage(currentUserId, receiverID) async {
    Query query = ref!
        .doc(currentUserId)
        .collection(receiverID.toString())
        .orderBy("createdAt", descending: true);
    await query.get().then((value) {
      if (value.docs.isNotEmpty) {
        data = ChatMessageModel.fromJson(
            value.docs.first.data() as Map<String, dynamic>);
      }
    });

    return data;
  }

  Future<UserModel> getUserPlayerId({String? uid}) {
    print("data->>>" + uid.toString());
    return userRef.where("uid", isEqualTo: uid).limit(1).get().then((value) {
      if (value.docs.length == 1) {
        return UserModel.fromJson(
            value.docs.first.data() as Map<String, dynamic>);
      } else {
        throw 'User Not found';
      }
    });
  }

  Future<UserModel> getUserById({String? uid}) {
    print("data->>>" + uid.toString());
    return userRef.where("uid", isEqualTo: uid).limit(1).get().then((value) {
      if (value.docs.length == 1) {
        return UserModel.fromJson(
            value.docs.first.data() as Map<String, dynamic>);
      } else {
        throw 'User Not found';
      }
    });
  }

  ///

  Future<bool> hasPendingRequestFromUser({
    required String currentUserId,
    required String otherUserId,
  }) async {
    final querySnapshot = await fireStore
        .collection(USER_COLLECTION)
        .doc(otherUserId)
        .collection(CHAT_REQUEST)
        .where('uid', isEqualTo: currentUserId)
        .where('requestStatus', isEqualTo: RequestStatus.Pending.index)
        .limit(1)
        .get();

    return querySnapshot.docs.isNotEmpty;
  }

  Future<void> deleteGroupFromUserContacts({String? groupId}) async {
    await userRef
        .doc(getStringAsync(userId))
        .collection(CONTACT_COLLECTION)
        .doc(groupId)
        .delete()
        .onError((error, stackTrace) => debugPrint(error.toString()));
  }

  Future<String> uploadImageToFirebase(File file, String folder) async {
    String fileName = '${DateTime.now().millisecondsSinceEpoch}.jpg';
    final storageRef = FirebaseStorage.instance
        .ref()
        .child('$folder/${getStringAsync(userId)}/$fileName');

    await storageRef.putFile(file);
    String downloadUrl = await storageRef.getDownloadURL();
    return downloadUrl;
  }

  /* Future<String?> uploadCateImageToStorage(ImageFile imageFile) async {
    try {
      final fileName = '${DateTime.now().millisecondsSinceEpoch}_${imageFile.name}';
      final ref = FirebaseStorage.instance.ref().child('catalogue_images/$fileName');

      final uploadTask = await ref.putFile(File(imageFile.path??''));
      final downloadUrl = await uploadTask.ref.getDownloadURL();
      return downloadUrl;
    } catch (e) {
      print('Error uploading image: $e');
      return null;
    }
  }*/

  Future<String?> oldBusinessImageDeleteStorage(String? param) async {
    try {
      final doc = await userRef
          .doc(getStringAsync(userId))
          .collection('BusinessProfile')
          .doc('Profile')
          .get();
      print("---------680>>>${doc.toString()}");
      print("---------681>>>${param}");

      final oldCoverImageUrl = doc.data()?[param];
      print("---------682>>>${oldCoverImageUrl}");

      if (oldCoverImageUrl != null) {
        try {
          final oldRef = FirebaseStorage.instance.refFromURL(oldCoverImageUrl);
          await oldRef.delete();
        } catch (e) {
          print('Failed to delete old image: $e');
        }
      }
    } catch (e) {
      print('Error uploading compressed image: $e');
      return null;
    }
  }

  Future<String?> uploadCompressedImageToStorage(XFile compressedFile) async {
    try {
      final fileName =
          '${DateTime.now().millisecondsSinceEpoch}_${compressedFile.name}';
      final ref =
          FirebaseStorage.instance.ref().child('catalogue_images/$fileName');

      final uploadTask = await ref.putFile(File(compressedFile.path));
      final downloadUrl = await uploadTask.ref.getDownloadURL();
      return downloadUrl;
    } catch (e) {
      print('Error uploading compressed image: $e');
      return null;
    }
  }
}

String dummyContent = "11a1215l0119a140409p0919";

encryptData(String contentData) {
  try {
    // encrypt algoritham
    final key = encrypt.Key.fromUtf8(dummyContent);
    final iv = encrypt.IV.allZerosOfLength(16);
    final encrypter = encrypt.Encrypter(encrypt.AES(key));

    // encript file data to base64
    final encrypted = encrypter.encrypt(contentData, iv: iv);
    String encryptedData = encrypted.base64;

    return encryptedData;
  } catch (e, s) {
    print("-----------988>>${e.toString()}");
    print("-----------987>>${s.toString()}");
  }
}

decryptedData(String encryptedData) {
  try {
    print("EncryptedData:::${encryptedData}");
    final key = encrypt.Key.fromUtf8(dummyContent);
    final iv = encrypt.IV.allZerosOfLength(16);
    final encrypter = encrypt.Encrypter(encrypt.AES(key));

    String decrypted =
        encrypter.decrypt(Encrypted.fromBase64(encryptedData), iv: iv);
    print("EncryptedDataDecoded:::${decrypted}");
    return decrypted;
  } catch (e, s) {
    // return encryptedData;
    print("MessageDecodeHaving Issue::${e},-->$s");
    return "Invalid message format detected";
  }
}
