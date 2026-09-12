import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter_contacts/flutter_contacts.dart';
import 'package:flutter_vector_icons/flutter_vector_icons.dart';
import 'package:paginate_firestore/paginate_firestore.dart';
import 'package:receive_sharing_intent/receive_sharing_intent.dart';

import 'package:flutter/material.dart';
import 'package:nb_utils/nb_utils.dart';
import 'package:chat/centralized_import.dart';

import '../../utils/TextStyles.dart' as TS;
import 'package:path/path.dart' as path;

class NewChatScreen extends StatefulWidget {
  final bool? isCall;
  final bool? isSharing;
  final List<SharedMediaFile>? sharedMedia;

  NewChatScreen(
      {this.isCall = false, this.isSharing = false, this.sharedMedia});

  @override
  _NewChatScreenState createState() => _NewChatScreenState();
}

class _NewChatScreenState extends State<NewChatScreen> {
  bool isSearch = false;
  bool autoFocus = false;
  TextEditingController searchCont = TextEditingController();
  String search = '';
  bool isLast = true;
  List<UserModel> mUserList = [];
  List<UserModel> searchList = [];
  List<String> myCollectionContactNumbers = [];
  List<String> myDeviceContacts = [];
  bool _showLoader = false;
  String useridNew = "";
  bool? adminExist;
  Set<String> _selectedUserIds = {};

  String TYPE_IMAGE = 'TYPE_IMAGE';
  String TYPE_VIDEO = 'TYPE_VIDEO';
  String TYPE_TEXT = 'TYPE_TEXT';
  String TYPE_DOC = 'TYPE_DOC';

  @override
  void initState() {
    super.initState();
    init();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      print(
          "NewChatScreen postFrameCallback => sharedMedia: ${widget.sharedMedia?.map((m) => m.path).toList() ?? 'null'}");
      if (mounted) setState(() {});
    });
  }

  Future<void> init() async {
    await userService.getContact().then((value) async {
      mUserList.addAll(value);
      searchList.addAll(value);

      setState(() {});
    });
    useridNew = getStringAsync(userId);
  }

  adminAvailable({String? Id}) async {
    adminExist = await getAdminData(Id ?? '');
  }

  Future<bool?> getAdminData(String adminId) async {
    try {
      if (adminId.isEmpty) return false;
      final docSnapshot = await FirebaseFirestore.instance
          .collection('admin')
          .doc(adminId)
          .get();
      return docSnapshot.exists;
    } catch (e) {
      return false;
    }
  }

  Future<Set<String>> fetchExistingNumbers() async {
    Set<String> existingNumbers = Set<String>();
    try {
      QuerySnapshot querySnapshot = await FirebaseFirestore.instance
          .collection(USER_COLLECTION)
          .doc(useridNew)
          .collection(MY_CONTACTS_COLLECTION)
          .get();

      querySnapshot.docs.forEach((doc) {
        var data = doc.data() as Map<String, dynamic>;
        if (data.containsKey('phoneNumber')) {
          existingNumbers.add(data['phoneNumber'] as String);
        }
      });
    } catch (error) {}
    return existingNumbers;
  }

  void getMemberList() {
    FirebaseFirestore.instance
        .collection(USER_COLLECTION)
        .get()
        .then((querySnapshot) {
      querySnapshot.docs.forEach((doc) {
        var userData = doc.data();
        if (userData.containsKey('phoneNumber')) {
          var phoneNumber = userData['phoneNumber'] as String;
          myCollectionContactNumbers.add(phoneNumber);
        }
      });
    }).catchError((error) {});
  }

  void checkContacts() async {
    Set<String> addedNumbers = await fetchExistingNumbers();
    myDeviceContacts.forEach((deviceNumber) {
      if (myCollectionContactNumbers.contains(deviceNumber) &&
          !addedNumbers.contains(deviceNumber)) {
        FirebaseFirestore.instance
            .collection(USER_COLLECTION)
            .where('phoneNumber', isEqualTo: deviceNumber)
            .get()
            .then((querySnapshot) {
          if (querySnapshot.docs.isNotEmpty) {
            var userData = querySnapshot.docs.first.data();
            FirebaseFirestore.instance
                .collection(USER_COLLECTION)
                .doc(useridNew)
                .collection(MY_CONTACTS_COLLECTION)
                .add({
              'phoneNumber': deviceNumber,
              'userData': userData,
              'timestamp': DateTime.now(),
            }).then((value) {
              addedNumbers.add(deviceNumber);
              setState(() {});
            }).catchError((error) {});
          }
        }).catchError((error) {});
      }
    });
  }

  void sendMessage({
    FilePickerResult? result,
    String? stickerPath,
    File? filepath,
    String? type,
    String? withText,
    required String receiverId,
  }) async {
    print(
        "===================== Send Message Function Called =====================");
    bool userExist = await chatMessageService.checkUserStatus(
      senderId: getStringAsync(userId),
      receiverId: receiverId,
    );

    if (receiverId.isEmpty) {
      print("Error: No receiver ID provided");
      return;
    }

    // Fetch receiver user data for block status
    DocumentSnapshot userDoc = await FirebaseFirestore.instance
        .collection(USER_COLLECTION)
        .doc(receiverId)
        .get();
    if (!userDoc.exists) {
      print("Error: Receiver user not found");
      toast('User not found');
      return;
    }
    UserModel receiverUser =
        UserModel.fromJson(userDoc.data() as Map<String, dynamic>);
    bool isBlocked = await userService.isUserBlocked(receiverId);

    if (isBlocked) {
      print("User is blocked");
      unblockDialog(context, receiver: receiverUser);
      return;
    }

    ChatMessageModel data = ChatMessageModel();
    data.receiverId = receiverId;
    data.senderId = getStringAsync(userId);
    data.message = withText?.trim() ?? '';
    data.isMessageRead = false;
    data.stickerPath = stickerPath;
    data.createdAt = DateTime.now().millisecondsSinceEpoch;
    data.isEncrypt = type == TYPE_TEXT;
    data.isFromReply = false;
    data.isFromForward = false;

    print("SENDER ID IS => ${data.senderId}");
    print("RECEIVER ID IS => ${data.receiverId}");
    print("Message => ${data.message}");

    if (filepath != null && type != null) {
      if (type == TYPE_IMAGE) {
        data.messageType = MessageType.IMAGE.name;
      } else if (type == TYPE_VIDEO) {
        data.messageType = MessageType.VIDEO.name;
      } else if (type == TYPE_DOC) {
        data.messageType = MessageType.DOC.name;
        String originalFileName = path.basename(filepath.path ?? '');
        String extension = path.extension(originalFileName);
        String nameWithoutExt = path.basenameWithoutExtension(originalFileName);
        String timestamp = DateTime.now().millisecondsSinceEpoch.toString();
        String newFileName = "${nameWithoutExt}_$timestamp$extension";
        data.documentName = newFileName;
      } else {
        data.messageType = MessageType.TEXT.name;
        data.message = encryptData(data.message!);
        data.isEncrypt = true;
      }
    } else if (type == TYPE_TEXT) {
      data.messageType = MessageType.TEXT.name;
      data.message = encryptData(data.message!);
      data.isEncrypt = true;
    } else {
      data.messageType = MessageType.TEXT.name;
      data.message = encryptData(data.message!);
      data.isEncrypt = true;
    }

    List<DocumentReference>? blockedToList = receiverUser.blockedTo;
    if (blockedToList != null &&
        blockedToList.contains(
            userService.getUserReference(uid: getStringAsync(userId)))) {
      print("User is blocked by receiver");
      data.isMessageRead = true;
      await chatMessageService.addMessage(data);
      return;
    }

    String messageForNotification = '';
    if (data.messageType == MessageType.IMAGE.name) {
      messageForNotification = "Sent you an image";
    } else if (data.messageType == MessageType.VIDEO.name) {
      messageForNotification = "Sent you a video";
    } else if (data.messageType == MessageType.DOC.name) {
      messageForNotification = "Sent you a document";
    } else {
      messageForNotification = data.message!;
    }

    if (receiverUser.oneSignalPlayerId != null) {
      notificationService
          .sendPushNotifications(
        getStringAsync(userDisplayName),
        messageForNotification,
        recevierUid: receiverId,
        receiverPlayerId: receiverUser.oneSignalPlayerId,
      )
          .catchError((e) {
        print("Notification error: ${e.toString()}");
      });
    }

    if (await chatRequestService.isRequestsUserExist(receiverId)) {
      print("Sending normal message");
      await sendNormalMessages(data,
          filepath: filepath, receiverUser: receiverUser);
    } else {
      print("User exist: $userExist");
      if (!userExist) {
        await sendChatRequest(data, file: filepath, receiverUser: receiverUser);
      } else {
        await sendNormalMessages(data,
            filepath: filepath, receiverUser: receiverUser);
      }
    }

    await chatMessageService
        .getContactsDocument(
      of: getStringAsync(userId),
      forContact: receiverId,
    )
        .update(<String, dynamic>{
      "lastMessageTime": DateTime.now().millisecondsSinceEpoch,
    });
    await chatMessageService
        .getContactsDocument(
      of: receiverId,
      forContact: getStringAsync(userId),
    )
        .update(<String, dynamic>{
      "lastMessageTime": DateTime.now().millisecondsSinceEpoch,
    });

    print("Message sent successfully");
  }

  Future<void> sendNormalMessages(ChatMessageModel data,
      {File? filepath, required UserModel receiverUser}) async {
    DocumentReference senderDoc = await chatMessageService.addMessage(data);
    if (filepath != null) {
      FileModel fileModel = FileModel();
      fileModel.id = senderDoc.id;
      fileModel.file = filepath;
      fileList.add(fileModel);
    }
    await chatMessageService.addMessageToDb(
      senderDoc: senderDoc,
      data: data,
      sender: UserModel(
        uid: getStringAsync(userId),
        name: getStringAsync(userDisplayName),
        photoUrl: getStringAsync(userPhotoUrl),
      ),
      user: receiverUser,
      image: filepath != null ? File(filepath.path) : null,
      isRequest: false,
    );

    await userService.fireStore
        .collection(USER_COLLECTION)
        .doc(getStringAsync(userId))
        .collection(CONTACT_COLLECTION)
        .doc(receiverUser.uid)
        .update({
      'lastMessageTime': DateTime.now().millisecondsSinceEpoch,
    }).catchError((e) {
      print("Error updating sender contact: $e");
    });

    await userService.fireStore
        .collection(USER_COLLECTION)
        .doc(receiverUser.uid)
        .collection(CONTACT_COLLECTION)
        .doc(getStringAsync(userId))
        .update({
      'lastMessageTime': DateTime.now().millisecondsSinceEpoch,
    }).catchError((e) {
      print("Error updating receiver contact: $e");
    });
  }

  Future<void> sendChatRequest(ChatMessageModel data,
      {File? file, required UserModel receiverUser}) async {
    ChatRequestModel chatReq = ChatRequestModel();
    chatReq.uid = getStringAsync(userId);
    chatReq.requestStatus = RequestStatus.Pending.index;
    chatReq.senderIdRef = userService.ref!.doc(getStringAsync(userId));
    chatReq.createdAt = DateTime.now().millisecondsSinceEpoch;
    chatReq.updatedAt = DateTime.now().millisecondsSinceEpoch;

    await chatRequestService
        .addChatWithCustomId(
      getStringAsync(userId),
      chatReq.toJson(),
      receiverUser.uid ?? '',
    )
        .catchError((e) {
      print("Chat request error: $e");
    });

    DocumentReference senderDoc = await chatMessageService.addMessage(data);
    if (file != null) {
      FileModel fileModel = FileModel();
      fileModel.id = senderDoc.id;
      fileModel.file = file;
      fileList.add(fileModel);
    }

    await chatMessageService.addMessageToDb(
      senderDoc: senderDoc,
      data: data,
      sender: UserModel(
        uid: getStringAsync(userId),
        name: getStringAsync(userDisplayName),
        photoUrl: getStringAsync(userPhotoUrl),
      ),
      user: receiverUser,
      image: file != null ? File(file.path) : null,
      isRequest: true,
    );

    await chatMessageService.addToContacts(
      receiverId: receiverUser.uid!,
      senderId: getStringAsync(userId),
    );

    await userService.fireStore
        .collection(USER_COLLECTION)
        .doc(getStringAsync(userId))
        .collection(CONTACT_COLLECTION)
        .doc(receiverUser.uid)
        .update({
      'lastMessageTime': DateTime.now().millisecondsSinceEpoch,
    }).catchError((e) {
      print("Error updating sender contact: $e");
    });

    await userService.fireStore
        .collection(USER_COLLECTION)
        .doc(receiverUser.uid)
        .collection(CONTACT_COLLECTION)
        .doc(getStringAsync(userId))
        .update({
      'lastMessageTime': DateTime.now().millisecondsSinceEpoch,
    }).catchError((e) {
      print("Error updating receiver contact: $e");
    });
  }

  @override
  void setState(fn) {
    if (mounted) super.setState(fn);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // Replace your existing appBar in the build method with this:

      appBar: AppBar(
        title: Text(
          widget.isSharing!
              ? 'forward_to'.translate
              : widget.isCall!
                  ? 'new_call'.translate
                  : 'new_chat'.translate,
          style: TextStyle(
            color: Colors.white,
            fontSize: appStore.fontSize.toInt().toDouble(),
          ),
        ),
        backgroundColor: primaryColor,
        elevation: 0,
        iconTheme: IconThemeData(color: Colors.white),
        actions: [
          AnimatedContainer(
            duration: Duration(milliseconds: 200),
            curve: Curves.easeInOut,
            width: isSearch ? context.width() - 86 : 50,
            height: 48,
            alignment: Alignment.center,
            margin: EdgeInsets.symmetric(vertical: 8, horizontal: 8),
            child: isSearch
                ? Container(
                    padding: EdgeInsets.symmetric(horizontal: 12),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(24),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: TextField(
                            autofocus: true,
                            textAlignVertical: TextAlignVertical.center,
                            cursorColor: Colors.white,
                            controller: searchCont,
                            onChanged: (v) {
                              setState(() {
                                final query = v.trim().toLowerCase();
                                searchList = mUserList.where((u) {
                                  final name =
                                      (u.name ?? '').trim().toLowerCase();
                                  return name.contains(query);
                                }).toList();
                              });
                            },
                            onSubmitted: (c) {
                              setState(() {
                                final query = c.trim().toLowerCase();
                                searchList = mUserList.where((u) {
                                  final name =
                                      (u.name ?? '').trim().toLowerCase();
                                  return name.contains(query);
                                }).toList();
                              });
                            },
                            style: TS.boldTextStyle(color: Colors.white),
                            decoration: InputDecoration(
                              border: InputBorder.none,
                              hintText: 'search_here'.translate,
                              hintStyle: TS.secondaryTextStyle(
                                color: Colors.white.withOpacity(0.7),
                              ),
                              isDense: true,
                              contentPadding:
                                  EdgeInsets.symmetric(vertical: 12),
                            ),
                          ),
                        ),
                        IconButton(
                          icon: Icon(Icons.close, color: Colors.white),
                          onPressed: () {
                            isSearch = false;
                            searchCont.clear();
                            search = "";
                            setState(() {});
                          },
                          padding: EdgeInsets.zero,
                          constraints: BoxConstraints(),
                        ),
                      ],
                    ),
                  )
                : IconButton(
                    icon: Icon(Icons.search, color: Colors.white),
                    onPressed: () {
                      isSearch = true;
                      setState(() {});
                    },
                  ),
          ),
        ],
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SharedMediaPreview(
            sharedMedia: widget.sharedMedia ?? [],
            isSharing: widget.isSharing ?? false,
          ),
          if (widget.isSharing! && _selectedUserIds.isNotEmpty)
            Container(
              margin: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              padding: EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: primaryColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: primaryColor.withOpacity(0.2)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      '${mUserList.where((u) => _selectedUserIds.contains(u.uid)).map((u) => u.name.validate().capitalizeFirstLetter()).join(", ")}',
                      style: TS.primaryTextStyle(),
                      softWrap: true,
                    ),
                  ),
                  Container(
                    decoration: BoxDecoration(
                      color: primaryColor,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: IconButton(
                      onPressed: () async {
                        if (_selectedUserIds.isEmpty ||
                            widget.sharedMedia == null ||
                            widget.sharedMedia!.isEmpty) {
                          toast(
                              'Please select at least one user and ensure media is available');
                          return;
                        }

                        for (String receiverId in _selectedUserIds) {
                          for (SharedMediaFile media in widget.sharedMedia!) {
                            String type;
                            File? file;
                            String? messageText;

                            if (media.type == SharedMediaType.image) {
                              type = TYPE_IMAGE;
                              file = File(media.path);
                            } else if (media.type == SharedMediaType.video) {
                              type = TYPE_VIDEO;
                              file = File(media.path);
                            } else if (media.type == SharedMediaType.text) {
                              type = TYPE_TEXT;
                              messageText = media.path.validate();
                            } else {
                              type = TYPE_DOC;
                              file = File(media.path);
                            }
                            // Validate file existence and size for non-text types
                            if (file != null && type != TYPE_TEXT) {
                              if (!file.existsSync()) {
                                toast(
                                    "${media.type.toString().split('.').last.capitalizeFirstLetter()} ${path.basename(media.path)} does not exist");
                                continue;
                              }
                              double fileSizeMB =
                                  file.lengthSync() / (1024 * 1024);
                              if (fileSizeMB > 8) {
                                toast("media exceeds 8MB limit");
                                continue;
                              }
                            }
                            sendMessage(
                              filepath: file,
                              type: type,
                              withText: messageText,
                              receiverId: receiverId,
                            );
                          }
                        }
                        finish(context);
                      },
                      icon: Icon(Icons.send, color: Colors.white, size: 18),
                    ),
                  ),
                ],
              ),
            ),
          if (!widget.isSharing!) syncContactsRow(),
          if (!widget.isCall! && !widget.isSharing!)
            Row(
              children: [
                Container(
                  width: 50,
                  height: 50,
                  decoration: boxDecorationWithRoundedCorners(
                      boxShape: BoxShape.circle, backgroundColor: primaryColor),
                  child: Icon(Icons.people, color: Colors.white),
                ),
                12.width,
                Text('create_group'.translate, style: TS.primaryTextStyle()),
              ],
            ).paddingSymmetric(horizontal: 16, vertical: 16).onTap(() {
              NewGroupScreen().launch(context,
                  pageRouteAnimation: PageRouteAnimation.SlideBottomTop,
                  duration: 300.milliseconds);
            }),
          isSearch
              ? ListView.separated(
                  itemCount: searchList.length,
                  shrinkWrap: true,
                  padding: EdgeInsets.all(0),
                  physics: BouncingScrollPhysics(),
                  itemBuilder: (context, index) {
                    UserModel data = searchList[index];
                    if (data.uid == loginStore.mId) {
                      return 0.height;
                    }
                    return Container(
                      padding:
                          EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                      child: Row(
                        children: [
                          Stack(
                            children: [
                              data.photoUrl!.isEmpty
                                  ? Hero(
                                      tag: data.uid.validate(),
                                      child: Container(
                                        height: 50,
                                        width: 50,
                                        padding: EdgeInsets.all(10),
                                        decoration: BoxDecoration(
                                          color: getColorFromString(
                                              data.uid ?? data.name.validate()),
                                          borderRadius:
                                              BorderRadius.circular(25),
                                        ),
                                        child: Text(
                                          data.name.validate()[0].toUpperCase(),
                                          style: TS.secondaryTextStyle(
                                              color: Colors.white),
                                        ).center().fit(),
                                      ),
                                    )
                                  : Hero(
                                      tag: data.uid.validate(),
                                      child: ClipRRect(
                                        borderRadius: BorderRadius.circular(25),
                                        child: cachedImage(
                                          data.photoUrl.validate(),
                                          width: 50,
                                          height: 50,
                                          fit: BoxFit.cover,
                                        ),
                                      ),
                                    ),
                            ],
                          ),
                          12.width,
                          Column(
                            mainAxisAlignment: MainAxisAlignment.start,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    '${data.name.validate().capitalizeFirstLetter()}',
                                    style: TS.primaryTextStyle(),
                                  ).expand(),
                                ],
                              ),
                              Text(
                                '${data.userStatus.validate()}',
                                style: TS.secondaryTextStyle(),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ).expand(),
                          widget.isSharing!
                              ? Container(
                                  padding: EdgeInsets.all(6),
                                  decoration: BoxDecoration(
                                    color: _selectedUserIds.contains(data.uid)
                                        ? primaryColor
                                        : Colors.grey.shade300,
                                    shape: BoxShape.circle,
                                  ),
                                  child: Icon(
                                    _selectedUserIds.contains(data.uid)
                                        ? Icons.check
                                        : Icons.add,
                                    color: _selectedUserIds.contains(data.uid)
                                        ? Colors.white
                                        : Colors.grey.shade600,
                                    size: 18,
                                  ),
                                )
                              : widget.isCall!
                                  ? Row(
                                      children: [
                                        IconButton(
                                          icon: Icon(FontAwesome.phone,
                                              color: primaryColor, size: 18),
                                          onPressed: () async {
                                            UserModel receiverData = UserModel(
                                              uid: data.uid,
                                              name: data.name,
                                              photoUrl: data.photoUrl,
                                            );
                                            UserModel sender = UserModel(
                                              name: getStringAsync(
                                                  userDisplayName),
                                              photoUrl:
                                                  getStringAsync(userPhotoUrl),
                                              uid: getStringAsync(userId),
                                              oneSignalPlayerId:
                                                  getStringAsync(playerId),
                                            );
                                            return await Permissions
                                                    .cameraAndMicrophonePermissionsGranted()
                                                ? CallFunctions.voiceDial(
                                                    context: context,
                                                    from: sender,
                                                    to: receiverData)
                                                : {};
                                          },
                                        ),
                                      ],
                                    )
                                  : Offstage(),
                        ],
                      ),
                    ).onTap(() async {
                      if (widget.isSharing!) {
                        setState(() {
                          if (_selectedUserIds.contains(data.uid)) {
                            _selectedUserIds.remove(data.uid);
                          } else {
                            _selectedUserIds.add(data.uid.validate());
                          }
                        });
                      } else if (widget.isCall == false) {
                        await adminAvailable(Id: data.uid ?? '');
                        finish(context);
                        ChatScreen(data, isAdmin: adminExist).launch(context);
                      }
                    });
                  },
                  separatorBuilder: (BuildContext context, int index) {
                    if (searchList[index].uid == getStringAsync(userId)) {
                      return 0.height;
                    }
                    return Divider(indent: 80, height: 0.5);
                  },
                ).expand()
              : PaginateFirestore(
                  reverse: false,
                  isLive: true,
                  physics: BouncingScrollPhysics(),
                  query: userService.userWithPagination(
                      searchText: searchCont.text),
                  itemsPerPage: PER_PAGE_CHAT_COUNT,
                  shrinkWrap: true,
                  onEmpty: SizedBox(),
                  separator: Divider(indent: 80, height: 0.5),
                  itemBuilderType: PaginateBuilderType.listView,
                  bottomLoader: Loader(
                      valueColor: AlwaysStoppedAnimation<Color>(primaryColor)),
                  initialLoader: Loader(
                          valueColor:
                              AlwaysStoppedAnimation<Color>(primaryColor))
                      .center()
                      .paddingBottom(context.height() * 0.51),
                  itemBuilder: (context, snap, index) {
                    UserModel data = UserModel.fromJson(
                        snap[index].data() as Map<String, dynamic>);
                    String currentUserId = getStringAsync(userId);
                    if (data.uid == currentUserId) return SizedBox();
                    if (data.userRole == 'admin') return SizedBox();
                    return Container(
                      padding:
                          EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                      child: Row(
                        children: [
                          Stack(
                            children: [
                              data.photoUrl!.isEmpty
                                  ? Hero(
                                      tag: data.uid.validate(),
                                      child: Container(
                                        height: 50,
                                        width: 50,
                                        padding: EdgeInsets.all(10),
                                        decoration: BoxDecoration(
                                          color: getColorFromString(
                                              data.uid ?? data.name.validate()),
                                          borderRadius:
                                              BorderRadius.circular(25),
                                        ),
                                        child: Text(
                                          data.name.validate().isNotEmpty
                                              ? data.name
                                                  .validate()[0]
                                                  .toUpperCase()
                                              : '',
                                          style: TS.secondaryTextStyle(
                                              color: Colors.white),
                                        ).center().fit(),
                                      ),
                                    )
                                  : Hero(
                                      tag: data.uid.validate(),
                                      child: ClipRRect(
                                        borderRadius: BorderRadius.circular(25),
                                        child: cachedImage(
                                          data.photoUrl.validate(),
                                          width: 50,
                                          height: 50,
                                          fit: BoxFit.cover,
                                        ),
                                      ),
                                    ),
                            ],
                          ),
                          12.width,
                          Column(
                            mainAxisAlignment: MainAxisAlignment.start,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    '${data.name.validate().capitalizeFirstLetter()}',
                                    style: TS.primaryTextStyle(),
                                  ).expand(),
                                ],
                              ),
                              Text(
                                '${data.userStatus.validate()}',
                                style: TS.secondaryTextStyle(),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ).expand(),
                          widget.isSharing!
                              ? Container(
                                  padding: EdgeInsets.all(6),
                                  decoration: BoxDecoration(
                                    color: _selectedUserIds.contains(data.uid)
                                        ? primaryColor
                                        : Colors.grey.shade300,
                                    shape: BoxShape.circle,
                                  ),
                                  child: Icon(
                                    _selectedUserIds.contains(data.uid)
                                        ? Icons.check
                                        : Icons.add,
                                    color: _selectedUserIds.contains(data.uid)
                                        ? Colors.white
                                        : Colors.grey.shade600,
                                    size: 18,
                                  ),
                                )
                              : widget.isCall!
                                  ? Row(
                                      children: [
                                        IconButton(
                                          icon: Icon(FontAwesome.phone,
                                              color: primaryColor, size: 18),
                                          onPressed: () async {
                                            UserModel receiverData = UserModel(
                                              uid: data.uid,
                                              name: data.name,
                                              photoUrl: data.photoUrl,
                                            );
                                            UserModel sender = UserModel(
                                              name: getStringAsync(
                                                  userDisplayName),
                                              photoUrl:
                                                  getStringAsync(userPhotoUrl),
                                              uid: getStringAsync(userId),
                                              oneSignalPlayerId:
                                                  getStringAsync(playerId),
                                            );
                                            return await Permissions
                                                    .cameraAndMicrophonePermissionsGranted()
                                                ? CallFunctions.voiceDial(
                                                    context: context,
                                                    from: sender,
                                                    to: receiverData)
                                                : {};
                                          },
                                        ),
                                      ],
                                    )
                                  : Offstage(),
                        ],
                      ),
                    ).onTap(() async {
                      if (widget.isSharing!) {
                        setState(() {
                          if (_selectedUserIds.contains(data.uid)) {
                            _selectedUserIds.remove(data.uid);
                          } else {
                            _selectedUserIds.add(data.uid.validate());
                          }
                        });
                      } else if (widget.isCall == false) {
                        await adminAvailable(Id: data.uid ?? '');
                        finish(context);
                        ChatScreen(data, isAdmin: adminExist).launch(context);
                      }
                    });
                  },
                ).expand(),
        ],
      ),
    );
  }

  Widget syncContactsRow() {
    return Row(
      children: [
        Container(
          width: 50,
          height: 50,
          decoration: boxDecorationWithRoundedCorners(
              boxShape: BoxShape.circle, backgroundColor: primaryColor),
          child: Icon(Icons.sync, color: Colors.white),
        ),
        12.width,
        Flexible(
            child: Text(
          'sync_with_your_contacts'.translate,
          style: TS.primaryTextStyle(),
          overflow: TextOverflow.ellipsis,
          maxLines: 2,
        )),
      ],
    ).paddingOnly(left: 16, right: 16, top: 16).onTap(() async {
      _showLoader = true;
      fetchExistingNumbers();
      getMemberList();
      if (await Permissions.contactPermissionEnabled()) {
        try {
          List<Contact> contacts = await FlutterContacts.getContacts();
          List<String> phoneNumbers = [];
          for (Contact contact in contacts) {
            for (Phone phone in contact.phones) {
              phoneNumbers.add(phone.number);
            }
          }
          myDeviceContacts = phoneNumbers;
          if (myCollectionContactNumbers.isNotEmpty &&
              myDeviceContacts.isNotEmpty) {
            checkContacts();
          }
          _showLoader = false;
        } catch (e) {
          toast(e.toString());
        }
        setState(() {});
      }
    });
  }
}
