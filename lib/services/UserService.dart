import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:nb_utils/nb_utils.dart';
import 'package:path/path.dart';

import 'package:chat/centralized_import.dart';

class UserService extends BaseService {
  FirebaseFirestore fireStore = FirebaseFirestore.instance;
  FirebaseStorage _storage = FirebaseStorage.instance;
  late CollectionReference myContactRef;

  UserService() {
    ref = fireStore.collection(USER_COLLECTION);
    myContactRef = fireStore.collection(MY_CONTACTS_COLLECTION);
  }

  Future<bool> isPhoneNumberTaken(
      String phoneNumber, String currentUserId) async {
    print("------------24>>>${phoneNumber}");
    final query = await FirebaseFirestore.instance
        .collection('users')
        .where('phoneNumber', isEqualTo: phoneNumber)
        .limit(1)
        .get();

    if (query.docs.isNotEmpty) {
      final docId = query.docs.first.id;
      return docId != currentUserId;
    }

    return false;
  }

  Future<bool> isEmailTaken(String email, String currentUserId) async {
    final query = await FirebaseFirestore.instance
        .collection('users')
        .where('email', isEqualTo: email)
        .limit(1)
        .get();

    if (query.docs.isNotEmpty) {
      final docId = query.docs.first.id;
      return docId != currentUserId;
    }

    return false;
  }

  Future<void> updateUserInfo(Map data, String id, {File? profileImage}) async {
    if (profileImage != null) {
      String fileName = basename(profileImage.path);
      Reference storageRef =
          _storage.ref().child("$USER_PROFILE_IMAGE/$fileName");
      UploadTask uploadTask = storageRef.putFile(profileImage);
      await uploadTask.then((e) async {
        await e.ref.getDownloadURL().then((value) {
          loginStore.setPhotoUrl(aPhotoUrl: value);
          setValue(userPhotoUrl, value);

          data.putIfAbsent("photoUrl", () => value);
        });
      });
    }

    print("Update profile called");

    return ref!.doc(id).update(data as Map<String, Object?>);
  }

  Future<void> updateUserStatus(Map data, String id) async {
    return ref!.doc(id).update(data as Map<String, Object?>);
  }

  Future<UserModel> getUser({String? email}) {
    return ref!.where("email", isEqualTo: email).limit(1).get().then((value) {
      if (value.docs.length == 1) {
        return UserModel.fromJson(
            value.docs.first.data() as Map<String, dynamic>);
      } else {
        throw 'User Not found';
      }
    });
  }

  Future<UserModel> getUserById({String? val}) {
    return ref!.where("uid", isEqualTo: val).limit(1).get().then((value) {
      if (value.docs.length == 1) {
        return UserModel.fromJson(
            value.docs.first.data() as Map<String, dynamic>);
      } else {
        throw 'User Not found';
      }
    });
  }

  Future<UserModel> getUserByPhoneNumber({String? phoneNumber}) {
    return ref!
        .where("phoneNumber", isEqualTo: '+${phoneNumber}')
        .limit(1)
        .get()
        .then((value) {
      if (value.docs.isNotEmpty) {
        return UserModel.fromJson(
          value.docs.first.data() as Map<String, dynamic>,
        );
      } else {
        throw 'User not found';
      }
    });
  }

  Stream<List<UserModel>> users({String? searchText}) {
    print("get user Datatata");

    return ref!
        .where('caseSearch',
            arrayContains: searchText.validate().isEmpty
                ? null
                : searchText!.toLowerCase())
        .snapshots()
        .map((snapshot) {
      List<UserModel> userList = [];

      for (var doc in snapshot.docs) {
        userList.add(UserModel.fromJson(doc.data() as Map<String, dynamic>));
      }
      return userList;
    });
  }

/*  Stream<List<UserModel>> usersForward({String? searchText}) {
    print("get user Datatata");

    Query query = ref!
        .where('userRole', isNotEqualTo: 'admin');

    if (searchText.validate().isNotEmpty) {
      query = query.where('caseSearch', arrayContains: searchText!.toLowerCase());
    }

    return query.snapshots().map((snapshot) {
      return snapshot.docs
          .map((doc) => UserModel.fromJson(doc.data() as Map<String, dynamic>))
          .where((user) => user.userRole != 'admin')
          .toList();
    });
  }*/

  Future<List<UserModel>> userss({String? searchText}) async {
    var snapshot = await ref!
        .where(
          'caseSearch',
          arrayContains:
              searchText.validate().isEmpty ? null : searchText!.toLowerCase(),
        )
        .get();

    return snapshot.docs
        .map((doc) => UserModel.fromJson(doc.data() as Map<String, dynamic>))
        .toList();
  }

  /* return ref!.where('caseSearch', arrayContains: searchText.validate().isEmpty ? null : searchText!.toLowerCase()).snapshots().map((x) {
      return x.docs.map((y) {
        return UserModel.fromJson(y.data() as Map<String, dynamic>);
      }).toList();
    });*/

  // get myContacts user Display
  Stream<List<UserModel>> getAllUserDataAsStream(String id,
      {String? searchText}) {
    Query query = ref!.doc(id).collection(CONTACT_COLLECTION);

    return query.snapshots().asyncMap((querySnapshot) async {
      Set<String> seenPhoneNumbers = Set<String>();
      List<UserModel> userList = [];

      for (var doc in querySnapshot.docs) {
        Map<String, dynamic>? userDataMap =
            doc['userData'] as Map<String, dynamic>?;

        if (userDataMap != null) {
          String phoneNumber = userDataMap['phoneNumber'];
          var userSnapshot =
              await ref!.where('phoneNumber', isEqualTo: phoneNumber).get();

          if (userSnapshot.docs.isEmpty) {
            await doc.reference.delete();
            continue;
          }

          if (searchText != null && searchText.isNotEmpty) {
            List<String> caseSearch =
                List<String>.from(userDataMap['caseSearch'] ?? []);

            if (caseSearch.contains(searchText.toLowerCase())) {
            } else {
              continue;
            }
          }

          if (!seenPhoneNumbers.contains(phoneNumber)) {
            seenPhoneNumbers.add(phoneNumber);

            userList.add(UserModel(
              blockedTo: userDataMap['blockedTo'],
              caseSearch: List<String>.from(userDataMap['caseSearch'] ?? []),
              createdAt: userDataMap['createdAt'],
              deviceId: userDataMap['deviceId'],
              email: userDataMap['email'],
              isActive: userDataMap['isActive'],
              isArchive: userDataMap['isArchive'],
              isEmailLogin: userDataMap['isEmailLogin'],
              isPresence: userDataMap['isPresence'],
              lastMessageTime: userDataMap['lastMessageTime'] ??
                  DateTime.now().millisecondsSinceEpoch,
              lastSeen: userDataMap['lastSeen'],
              name: userDataMap['name'],
              oneSignalPlayerId: userDataMap['oneSignalPlayerId'],
              phoneNumber: phoneNumber,
              photoUrl: userDataMap['photoUrl'],
              reportUserCount: userDataMap['reportUserCount'],
              reportedBy: userDataMap['reportedBy'],
              uid: userDataMap['uid'],
              updatedAt: userDataMap['updatedAt'],
              userStatus: userDataMap['userStatus'],
            ));
          }
        } else {}
      }
      return userList;
    }).handleError((e) {
      return [];
    });
  }

  Query userWithPagination({String? searchText}) {
    return ref!
        .where('caseSearch',
            arrayContains: searchText.validate().isEmpty
                ? null
                : searchText!.toLowerCase())
        .orderBy('createdAt', descending: true);
  }

  Future<UserModel> userByEmail(String? email) async {
    return await ref!
        .where('email', isEqualTo: email)
        .limit(1)
        .get()
        .then((value) {
      if (value.docs.isNotEmpty) {
        return UserModel.fromJson(
            value.docs.first.data() as Map<String, dynamic>);
      } else {
        throw 'No User Found';
      }
    });
  }

  Stream<UserModel> singleUser(String? id, {String? searchText}) {
    return ref!.where('uid', isEqualTo: id).limit(1).snapshots().map((event) {
      return UserModel.fromJson(
          event.docs.first.data() as Map<String, dynamic>);
    });
  }

  Future<UserModel> getUserByUserId({String? id}) {
    return ref!.where('uid', isEqualTo: id).get().then((value) {
      log(value.docs);
      return UserModel.fromJson(
          value.docs.first.data() as Map<String, dynamic>);
    });
  }

  Future<UserModel> userByMobileNumber(String? phone) async {
    return await ref!
        .where('phoneNumber', isEqualTo: phone)
        .limit(1)
        .get()
        .then((value) {
      if (value.docs.isNotEmpty) {
        return UserModel.fromJson(
            value.docs.first.data() as Map<String, dynamic>);
      } else {
        throw EXCEPTION_NO_USER_FOUND;
      }
    });
  }

  bool getPreviouslyChat(String uid) {
    return messageRequestStore.userContactList
            .where((element) => element.uid == uid)
            .length !=
        0;
  }

  Future<String> blockUser(Map<String, dynamic> data) async {
    return await ref!.doc(getStringAsync(userId)).update(data).then((value) {
      return "User Blocked";
    }).catchError((e) {
      toast(e.toString());
      throw errorSomethingWentWrong;
    });
  }

  Future<String> unBlockUser(Map<String, dynamic> data) async {
    return await ref!.doc(getStringAsync(userId)).update(data).then((value) {
      return "User Blocked";
    }).catchError((e) {
      toast(e.toString());
      throw errorSomethingWentWrong;
    });
  }

  // Get Already register All users from Users Collection

  // Future<String> getAllUsers(Map<String, dynamic> data) async {
  //   try {
  //     QuerySnapshot querySnapshot = await ref!.get();
  //
  //     for (var doc in querySnapshot.docs) {
  //       var userData = doc.data() as Map<String, dynamic>;
  //       print(userData.toString());
  //
  //       if (userData.containsKey('phoneNumber')) {
  //         var phoneNumber = userData['phoneNumber'] as String;
  //         myCollectionContactNumbers.add(phoneNumber);
  //       }
  //     }
  //     return "All users fetched successfully";
  //   } catch (e) {
  //     toast(e.toString());
  //     throw errorSomethingWentWrong;
  //   }
  // }

  Future<String> reportUser(
      Map<String, dynamic> data, String reportUserId) async {
    return await ref!.doc(reportUserId).update(data).then((value) {
      return "Account Reported to ${AppName} Team";
    }).catchError((e) {
      toast(e.toString());
      throw errorSomethingWentWrong;
    });
  }

  DocumentReference getUserReference({required String uid}) {
    return userService.ref!.doc(uid);
  }

  Future<void> removeDocument(String? id) => userService.ref!.doc(id).delete();

  Future<bool> isUserBlocked(String uid) async {
    return await userService
        .userByEmail(getStringAsync(userEmail))
        .then((value) {
      return value.blockedTo!.contains(getUserReference(uid: uid));
    });
  }

  Future isBlockUser({String? id}) {
    bool? isBlock = false;
    return ref!.doc(loginStore.mId).get().then((value1) {
      UserModel user =
          UserModel.fromJson(value1.data() as Map<String, dynamic>);
      user.blockedTo!.forEach((element) async {
        if (element.id == id) {
          isBlock = true;
        }
      });

      return isBlock;
    });
  }

  Future<List<String>> blockUserList() {
    List<String> blockList = [];
    return ref!.doc(loginStore.mId).get().then((value1) {
      UserModel user =
          UserModel.fromJson(value1.data() as Map<String, dynamic>);
      user.blockedTo!.forEach((element) async {
        blockList.add(element.id);
      });
      log(blockList);
      //blockUserData(blockList);
      return blockList;
    });
  }

  Future<List<UserModel>> getContact() async {
    return await ref!.where("isActive", isEqualTo: true).get().then((x) => x
        .docs
        .map((y) => UserModel.fromJson(y.data() as Map<String, dynamic>))
        .toList());
  }
}
