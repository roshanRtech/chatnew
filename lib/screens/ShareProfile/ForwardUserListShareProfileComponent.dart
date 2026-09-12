import 'dart:io';

import 'package:chat/centralized_import.dart';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_keyboard_visibility/flutter_keyboard_visibility.dart';
import 'package:flutter_vector_icons/flutter_vector_icons.dart';
import 'package:nb_utils/nb_utils.dart';

import '../../utils/TextStyles.dart' as TS;

class Forwarduserlistshareprofilecomponent extends StatefulWidget {
  final AsyncSnapshot<List<UserModel>>? snap;
  final AsyncSnapshot<List<dynamic>>? groupDara;
  final UserModel? shareUserData;
  final bool isGroupCreate;
  final bool isAddParticipant;
  final List<dynamic>? data;
  final bool? isCall;
  final bool isFromForward;
  final String? messageId;
  final bool? isFromGroup;
  final String? groupId;
  final String? groupName;
  final String? groupProfile;

  Forwarduserlistshareprofilecomponent(
      {this.snap,
      this.groupDara,
      this.shareUserData,
      this.isGroupCreate = false,
      this.isAddParticipant = false,
      this.data,
      this.groupId,
      this.groupName,
      this.groupProfile,
      this.isCall = false,
      this.isFromForward = false,
      this.messageId,
      this.isFromGroup});

  @override
  State<Forwarduserlistshareprofilecomponent> createState() =>
      _ForwarduserlistshareprofilecomponentState();
}

class _ForwarduserlistshareprofilecomponentState
    extends State<Forwarduserlistshareprofilecomponent> {
  List<UserModel> selectedList = [];
  List<dynamic> selectedGroupList = [];
  List<dynamic> mergedList = [];

  List<String> selected = [];
  List<String> selectedMPlayersId = [];
  List<dynamic> existingMembersList = [];
  bool isSending = false;
  bool isBlocked = false;
  bool isFirstMsg = false;
  String? currentLat;
  String? currentLong;

  // ScrollController scrollController = ScrollController();
  String searchCont = "";
  String groupChatId = "";
  List<String> receiverIds = [];

  String? groupName = '';
  bool userExist = false;

  // For Group
  List<UserModel> userModelList = [];
  List membersList = [];
  List<UserModel> userList = [];
  List<String> mList = [];
  String admin = '';

  String? groupCurrentLat;
  String? groupCurrentLong;
  Map<String, bool> readBy = {};

  @override
  void initState() {
    super.initState();
    init();
    print("Forward message");
  }

  init() async {
    print("---------93>>${widget.shareUserData?.toJson()}");
    if (widget.data != null) {
      existingMembersList = widget.data!;
    }
    LiveStream().on(SEARCH_KEY_FORWARD, (f) {
      searchCont = f as String;
      setState(() {});
    });
    getMemberList();

    setState(() {});
  }

  getMemberList() {
    userModelList.clear();
    membersList.forEach((element) async {
      UserModel userm = await userService.getUserById(val: element);

      userModelList.add(userm);
      userList.add(userm);
      if (userm.uid != getStringAsync(userId)) {
        if (!userm.oneSignalPlayerId.isEmptyOrNull) {
          mList.add(userm.oneSignalPlayerId.toString());
          setState(() {});
          print(userm.uid.toString() +
              "----------------------------------------" +
              userm.oneSignalPlayerId.toString());
        }
      }

      setState(() {});
    });
  }

  @override
  void setState(fn) {
    if (mounted) super.setState(fn);
  }

  // For Normal Message start

  // region send Message
  void sendMessage(
      {String? stickerPath,
      File? filepath,
      String? type,
      String? receiverId}) async {
    print("--------141>>${receiverId}");
    userExist = await chatMessageService.checkUserStatus(
        senderId: getStringAsync(userId), receiverId: receiverId ?? '');

    print(" ===================== SEND MESSAGE CALLING =================== ");

    print(" Send Message Time ==> " + receiverId.toString());

    if (widget.isFromGroup == true) {
      ChatMessageModel data = ChatMessageModel();
      for (String receiverUid in selected) {
        data.receiverId = receiverUid;

        print("Data Receiver Id is ==> " + data.receiverId.toString());
        print("----------------146>>>${widget.shareUserData?.toJson()}");

        data.senderId = getStringAsync(userId);
        data.messageType = SHAREPROFILE;
        data.shareUser = widget.shareUserData;
        data.isMessageRead = false;
        data.stickerPath = stickerPath;
        data.createdAt = DateTime.now().millisecondsSinceEpoch;
        data.groupId = widget.groupId;
        data.groupName = widget.groupName;
        data.groupProfile = widget.groupProfile;

        data.isFromForward = widget.isFromForward ? true : false;

        for (String receiverUid in selected) {
          if (await chatRequestService.isRequestsUserExist(receiverUid)) {
            print("send normal message forward ================");
            sendNormalMessages(data, filepath: filepath, receiverId ?? '');
          } else {
            print("send chatRequest forward ================");
            if (userExist == false) {
              sendChatRequest(data, file: filepath, receiverId);
            } else {
              sendNormalMessages(data, filepath: filepath, receiverId ?? '');
            }
          }
          chatMessageService
              .getContactsDocument(
                  of: getStringAsync(userId), forContact: receiverUid)
              .update(<String, dynamic>{
            "lastMessageTime": DateTime.now().millisecondsSinceEpoch,
          });
          chatMessageService
              .getContactsDocument(
                  of: receiverUid, forContact: getStringAsync(userId))
              .update(<String, dynamic>{
            "lastMessageTime": DateTime.now().millisecondsSinceEpoch,
          });

          final previewText = chatMessageService
              .generateLastMessagePreview(MessageType.SHAREPROFILE);

          ///// TODO
          ///// ADD GROUP DETAILS

          chatMessageService.updateLastMessage(
              senderId: getStringAsync(userId),
              receiverId: receiverId,
              text: encryptData(previewText),
              isRequest: userExist ? false : true,
              isGroupMessage: true,
              isArchive: false,
              groupName: widget.groupName,
              groupId: widget.groupId,
              timestamp: FieldValue.serverTimestamp());
        }
      }
    } else {
      ChatMessageModel data = ChatMessageModel();
      for (String receiverUid in selected) {
        data.receiverId = receiverUid;
        data.senderId = sender.uid;
        data.messageType = SHAREPROFILE;
        print("----------184>>${widget.shareUserData}");
        data.shareUser = widget.shareUserData;
        data.isMessageRead = false;
        data.groupId = widget.groupId;
        data.groupName = widget.groupName;
        data.groupProfile = widget.groupProfile;

        data.stickerPath = stickerPath;
        data.createdAt = DateTime.now().millisecondsSinceEpoch;

        data.isEncrypt = false;
        data.isFromForward = widget.isFromForward ? true : false;

        for (String receiverUid in selected) {
          if (await chatRequestService.isRequestsUserExist(receiverUid)) {
            print("send normal message forward ================");
            sendNormalMessages(data, filepath: filepath, receiverId!);
          } else {
            print("send chatRequest forward ================");
            print("-----------213>>${userExist}");
            if (userExist == false) {
              sendChatRequest(data, file: filepath, receiverId);
            } else {
              sendNormalMessages(data, filepath: filepath, receiverId!);
            }
          }
          chatMessageService
              .getContactsDocument(
                  of: getStringAsync(userId), forContact: receiverUid)
              .update(<String, dynamic>{
            "lastMessageTime": DateTime.now().millisecondsSinceEpoch,
          });
          chatMessageService
              .getContactsDocument(
                  of: receiverUid, forContact: getStringAsync(userId))
              .update(<String, dynamic>{
            "lastMessageTime": DateTime.now().millisecondsSinceEpoch,
          });

          final previewText = chatMessageService
              .generateLastMessagePreview(MessageType.SHAREPROFILE);

          chatMessageService.updateLastMessage(
              senderId: getStringAsync(userId),
              receiverId: receiverId,
              text: encryptData(previewText),
              isRequest: userExist ? false : true,
              isGroupMessage: false,
              isArchive: false,
              groupName: "",
              groupId: "",
              timestamp: FieldValue.serverTimestamp());
        }
      }
    }
  }

  void sendNormalMessages(ChatMessageModel data, String receiverId,
      {File? filepath}) async {
    print(" ================= SEND NORMAL MSG =====================");
    if (widget.isFromGroup == true) {
      for (String userId in selected) {
        if (isFirstMsg) {
          ContactModel data = ContactModel();
          data.uid = userId;
          data.addedOn = Timestamp.now();
          data.lastMessageTime = DateTime.now().millisecondsSinceEpoch;

          chatMessageService
              .getContactsDocument(
                  of: getStringAsync('userId'), forContact: userId)
              .set(data.toJson())
              .then((value) {
            //
          }).catchError((e) {
            log(e);
          });
        }
        String? message = '';
        message = getStringAsync(userDisplayName) +
            " Sent you " +
            SHAREPROFILE.capitalizeFirstLetter();
        selectedMPlayersId.map((e) {
          if (!e.isEmptyOrNull) {
            notificationService
                .sendPushNotifications(
                    getStringAsync(userDisplayName), message ?? '',
                    receivierUids: selected, mPlayerIds: selectedMPlayersId)
                .catchError((e) {
              print("erooor============${e.toString()}");
            });
          }
        });
        setState(() {});

        await chatMessageService.addMessage(data).then((value) async {
          print("sendNormalMessages  Photo Url Is ==>" +
              data.photoUrl.toString());
          // ignore: unnecessary_null_comparison
          await chatMessageService
              .addMessageToDbForward(
                  senderDoc: value,
                  data: data,
                  sender: sender,
                  user: widget.snap!.data,
                  image: File(data.photoUrl!),
                  isRequest: false)
              .then((value) {
            //
          });
        });

        userService.fireStore
            .collection(USER_COLLECTION)
            .doc(getStringAsync('userId'))
            .collection(CONTACT_COLLECTION)
            .doc(userId)
            .update({
          'lastMessageTime': DateTime.now().millisecondsSinceEpoch
        }).catchError((e) {
          log(e);
        });
        userService.fireStore
            .collection(USER_COLLECTION)
            .doc(userId)
            .collection(CONTACT_COLLECTION)
            .doc(getStringAsync('userId'))
            .update({
          'lastMessageTime': DateTime.now().millisecondsSinceEpoch
        }).catchError((e) {
          log(e);
        });
      }
    } else {
      for (String userId in selected) {
        if (isFirstMsg) {
          ContactModel data = ContactModel();
          data.uid = userId;
          data.addedOn = Timestamp.now();
          data.lastMessageTime = DateTime.now().millisecondsSinceEpoch;

          chatMessageService
              .getContactsDocument(
                  of: getStringAsync('userId'), forContact: userId)
              .set(data.toJson())
              .then((value) {
            //
          }).catchError((e) {
            log(e);
          });
        }
        String? message = '';
        message = getStringAsync(userDisplayName) +
            " Sent you " +
            SHAREPROFILE.capitalizeFirstLetter();

        selectedMPlayersId.map((e) {
          if (!e.isEmptyOrNull) {
            notificationService
                .sendPushNotifications(
                    getStringAsync(userDisplayName), message ?? '',
                    receivierUids: selected, mPlayerIds: selectedMPlayersId)
                .catchError((e) {
              print("erooor============${e.toString()}");
            });
          }
        });
        setState(() {});

        await chatMessageService.addMessage(data).then((value) async {
          // ignore: unnecessary_null_comparison
          print('gfdfgdfgdfgdfg');
          await chatMessageService
              .addMessageToDbForward(
                  senderDoc: value,
                  data: data,
                  sender: sender,
                  user: widget.snap!.data,
                  image: File(data.photoUrl ?? ""),
                  isRequest: false)
              .then((value) {
            //
          });
        });

        print('=====> -------> ${userId} === ${getStringAsync('userId')}');

        userService.fireStore
            .collection(USER_COLLECTION)
            .doc(getStringAsync('userId'))
            .collection(CONTACT_COLLECTION)
            .doc(userId)
            .update({
          'lastMessageTime': DateTime.now().millisecondsSinceEpoch
        }).catchError((e) {
          log(e);
        });
        userService.fireStore
            .collection(USER_COLLECTION)
            .doc(userId)
            .collection(CONTACT_COLLECTION)
            .doc(getStringAsync('userId'))
            .update({
          'lastMessageTime': DateTime.now().millisecondsSinceEpoch
        }).catchError((e) {
          log(e);
        });
      }
    }
  }

  //endregion

  // region chat request
  void sendChatRequest(ChatMessageModel data, String? receiverId,
      {File? file}) async {
    print(
        "=================== Into Send Chat request ==============================");

    if (widget.isFromGroup == true) {
      for (String receiverUid in selected) {
        String? message;
        data.isFromForward = widget.isFromForward ? true : false;

        message = getStringAsync(userDisplayName) +
            " Sent you " +
            SHAREPROFILE.capitalizeFirstLetter();

        if (!selectedMPlayersId.isNotEmpty) {
          notificationService
              .sendPushNotifications(getStringAsync(userDisplayName), message,
                  receivierUids: selected.validate(),
                  mPlayerIds: selectedMPlayersId)
              .catchError((e) {});
        }

        ChatRequestModel chatReq = ChatRequestModel();
        chatReq.uid = data.senderId;
        chatReq.profilePic = data.photoUrl;
        chatReq.requestStatus = RequestStatus.Pending.index;
        chatReq.senderIdRef = userService.ref!.doc(sender.uid);
        chatReq.createdAt = DateTime.now().millisecondsSinceEpoch;
        chatReq.updatedAt = DateTime.now().millisecondsSinceEpoch;

        if (await chatRequestService.isRequestUserExist(
            sender.uid!, receiverUid.validate())) {
          chatMessageService.addMessage(data).then((value) async {
            await chatMessageService
                .addMessageToDbForward(
                    senderDoc: value,
                    data: data,
                    sender: sender,
                    user: widget.snap!.data,
                    image: File(data.photoUrl.toString()),
                    isRequest: true)
                .then((value) {
              //  setState(() {});
            });
          });
        } else {
          chatRequestService
              .addChatWithCustomId(
                  sender.uid!, chatReq.toJson(), receiverUid.validate())
              .then((value) {})
              .catchError((e) {});

          chatMessageService.addMessage(data).then((value) async {
            await chatMessageService
                .addMessageToDbForward(
                    senderDoc: value,
                    data: data,
                    sender: sender,
                    user: widget.snap!.data,
                    image: File(data.photoUrl.toString()),
                    isRequest: true)
                .then((value) {
              // audioPath = null;
            });
            userService.fireStore
                .collection(USER_COLLECTION)
                .doc(getStringAsync(userId))
                .collection(CONTACT_COLLECTION)
                .doc(receiverUid)
                .update({
              'lastMessageTime': DateTime.now().millisecondsSinceEpoch
            }).catchError((e) {
              setState(() {});
            });
            userService.fireStore
                .collection(USER_COLLECTION)
                .doc(receiverUid)
                .collection(CONTACT_COLLECTION)
                .doc(getStringAsync(userId))
                .update({
              'lastMessageTime': DateTime.now().millisecondsSinceEpoch
            }).catchError((e) {
              setState(() {});
            });
          });
        }
      }
    } else {
      for (String receiverUid in selected) {
        String? message;

        message = getStringAsync(userDisplayName) +
            " Sent you " +
            SHAREPROFILE.capitalizeFirstLetter();

        if (!selectedMPlayersId.isNotEmpty) {
          notificationService
              .sendPushNotifications(getStringAsync(userDisplayName), message,
                  receivierUids: selected.validate(),
                  mPlayerIds: selectedMPlayersId)
              .catchError((e) {});
        }

        ChatRequestModel chatReq = ChatRequestModel();
        chatReq.uid = data.senderId;
        chatReq.profilePic = data.photoUrl;
        chatReq.requestStatus = RequestStatus.Pending.index;
        chatReq.senderIdRef = userService.ref!.doc(sender.uid);
        chatReq.createdAt = DateTime.now().millisecondsSinceEpoch;
        chatReq.updatedAt = DateTime.now().millisecondsSinceEpoch;

        if (await chatRequestService.isRequestUserExist(
            sender.uid!, receiverUid.validate())) {
          chatMessageService.addMessage(data).then((value) async {
            await chatMessageService
                .addMessageToDbForward(
                    senderDoc: value,
                    data: data,
                    sender: sender,
                    user: widget.snap!.data,
                    image: File(data.photoUrl.toString()),
                    isRequest: true)
                .then((value) {});
          });
        } else {
          chatRequestService
              .addChatWithCustomId(
                  sender.uid!, chatReq.toJson(), receiverUid.validate())
              .then((value) {})
              .catchError((e) {});

          chatMessageService.addMessage(data).then((value) async {
            await chatMessageService
                .addMessageToDbForward(
                    senderDoc: value,
                    data: data,
                    sender: sender,
                    user: widget.snap!.data,
                    image: File(data.photoUrl.toString()),
                    isRequest: true)
                .then((value) {});
            userService.fireStore
                .collection(USER_COLLECTION)
                .doc(getStringAsync(userId))
                .collection(CONTACT_COLLECTION)
                .doc(receiverUid)
                .update({
              'lastMessageTime': DateTime.now().millisecondsSinceEpoch
            }).catchError((e) {
              setState(() {});
            });
            userService.fireStore
                .collection(USER_COLLECTION)
                .doc(receiverUid)
                .collection(CONTACT_COLLECTION)
                .doc(getStringAsync(userId))
                .update({
              'lastMessageTime': DateTime.now().millisecondsSinceEpoch
            }).catchError((e) {
              setState(() {});
            });
          });
        }
      }
    }
  }

  // For Normal Message End
  //
  // For Group Message  Start

  void sendGroupMessage(
      {String? stickerPath, File? filepath, String? type}) async {
    print("Send Group Message calling");
    addReadBy();

    ChatMessageModel chatMessageModel = ChatMessageModel();
    chatMessageModel.senderId = sender.uid;
    chatMessageModel.isMessageRead = false;
    chatMessageModel.isEncrypt = false;
    chatMessageModel.shareUser = widget.shareUserData;
    chatMessageModel.createdAt = DateTime.now().millisecondsSinceEpoch;
    chatMessageModel.messageType = SHAREPROFILE;
    chatMessageModel.readBy = readBy;
    chatMessageModel.groupId = widget.groupId;
    chatMessageModel.groupName = widget.groupName;
    chatMessageModel.groupProfile = widget.groupProfile;
    chatMessageModel.isFromForward = widget.isFromForward ? true : false;

    //  sendNormalGroupMessages(chatMessageModel, result: result != null ? result : null, filepath: filepath);
    sendNormalGroupMessages(chatMessageModel, type: type, filepath: filepath);
  }

  void sendNormalGroupMessages(ChatMessageModel data,
      {String? type, File? filepath}) async {
    ContactModel contactModel = ContactModel();
    contactModel.uid = groupChatId;
    contactModel.addedOn = Timestamp.now();
    contactModel.lastMessageTime = DateTime.now().millisecondsSinceEpoch;
    contactModel.groupRefUrl = groupChatId;
    data.photoUrl = data.photoUrl.toString();
    data.isFromForward = widget.isFromForward ? true : false;

    String? message = '';

    message = getStringAsync(userDisplayName) +
        " Sent you " +
        SHAREPROFILE.capitalizeFirstLetter();

    await notificationService
        .sendPushNotifications(groupName.validate() + " ", message,
            isGrp: true, recevierUid: groupChatId, mPlayerIds: mList)
        .catchError((e) {
      log('error' + e.toString());
    }).then((value) async {
      await chatMessageService
          .getContactsDocument(
              of: getStringAsync(userId), forContact: groupChatId)
          .update(<String, dynamic>{
        "lastMessageTime": DateTime.now().millisecondsSinceEpoch,
      }).catchError((e) {
        log(e);
      }).then((value) {
        userModelList.forEach((element) async {
          log(element.oneSignalPlayerId);
          await chatMessageService
              .getContactsDocument(
                  of: element.uid.validate(), forContact: groupChatId)
              .update(<String, dynamic>{
            "lastMessageTime": DateTime.now().millisecondsSinceEpoch,
          });
        });
      });
    });

    setState(() {});

    if (data.messageType == MessageType.LOCATION.name) {
      groupChatMessageService.addLatLong(data,
          groupId: groupChatId, lat: currentLat, long: currentLong);
    }

    groupChatMessageService.addIsEncrypt(data);
    await groupChatMessageService
        .addMessage(data, groupChatId)
        .then((value) async {
      await groupChatMessageService
          .addMessageToDbForward(
              senderDoc: value,
              data: data,
              sender: sender,
              image: data.photoUrl!.toString().isNotEmpty
                  ? File(data.photoUrl!.toString())
                  : null,
              isRequest: false)
          .then((value) {});
    }).catchError((e) {
      log("message send:$e");
    });
  }

  void addReadBy() {
    readBy.clear();
    membersList.forEach((element) {
      if (element == getStringAsync(userId)) {
        readBy[element] = true;
      } else {
        readBy[element] = false;
      }
    });
  }

  // For Group Message  End

  Stream<List<dynamic>> group({String? searchText}) {
    return fireStore
        .collection('group')
        .where('searchCase',
            arrayContains: searchText.validate().isEmpty
                ? null
                : searchText!.toLowerCase())
        .snapshots()
        .map((x) {
      return x.docs.map((y) {
        return y.data();
      }).toList();
    });
  }

  StreamBuilder<List<dynamic>> buildGroupItemWidget() {
    return StreamBuilder(
      stream: group(searchText: searchCont),
      builder: (_, snap) {
        if (snap.hasData) {
          return snap.data != null
              ? ListView.builder(
                  physics: NeverScrollableScrollPhysics(),
                  shrinkWrap: true,
                  padding: EdgeInsets.all(0),
                  itemCount: snap.data!.length,
                  itemBuilder: (BuildContext context, int index) {
                    var members = snap.data![index]['membersList'];
                    var data;
                    if (members != null)
                      members.map((e) {
                        if (e.contains(getStringAsync(userId))) {
                          if (snap.data != null) data = snap.data![index];
                        }
                      }).toList();
                    return data != null
                        ? Container(
                            padding: EdgeInsets.symmetric(
                                horizontal: 16, vertical: 8),
                            child: Row(
                              children: [
                                Stack(
                                  children: [
                                    noProfileImageFound(
                                            height: 45,
                                            width: 45,
                                            isGroup: true)
                                        .cornerRadiusWithClipRRect(50),
                                    data['photoUrl'] == null
                                        ? noProfileImageFound(
                                                height: 45,
                                                width: 45,
                                                isGroup: true)
                                            .cornerRadiusWithClipRRect(50)
                                            .onTap(() {
                                            showDialog(
                                              context: context,
                                              builder: (context) {
                                                return GroupProfileImageDailog(
                                                    data: data);
                                              },
                                            );
                                          })
                                        : Hero(
                                            tag: data['photoUrl'],
                                            child: Image.network(
                                              data['photoUrl'],
                                              height: 50,
                                              width: 50,
                                              fit: BoxFit.cover,
                                              errorBuilder: (_, __, ___) {
                                                return noProfileImageFound(
                                                    height: 45,
                                                    width: 45,
                                                    isGroup: true);
                                              },
                                            ).cornerRadiusWithClipRRect(50),
                                          ).onTap(() {
                                            showDialog(
                                              context: context,
                                              builder: (context) {
                                                return GroupProfileImageDailog(
                                                    data: data);
                                              },
                                            );
                                          }),
                                  ],
                                ),
                                10.width,
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Text(
                                          data['name']
                                              .toString()
                                              .capitalizeFirstLetter(),
                                          style: TS.primaryTextStyle(),
                                          maxLines: 1,
                                          textAlign: TextAlign.start,
                                          overflow: TextOverflow.ellipsis,
                                        ).expand(),
                                        2.width,
                                        if (selected.contains(data['id']))
                                          Icon(Icons.check_circle_outlined,
                                              color: primaryColor)
                                      ],
                                    ),
                                    2.height,
                                  ],
                                ).expand(),
                              ],
                            ),
                          ).onTap(() async {
                            groupChatId = data['id'].toString();
                            groupName = data['name'].toString();

                            if (widget.isGroupCreate) {
                              if (!selected.contains(data['id'])) {
                                if (widget.isAddParticipant) {
                                  log(existingMembersList);
                                  if (existingMembersList
                                      .contains(data['id'])) {
                                    toast('lblAlreadyExist'.translate);
                                  } else {
                                    // if (mergedList.length <= 4) {
                                    selected.add(data['id'].toString());
                                    selectedGroupList.add(data);

                                    mergedList.add(data);
                                    //   }
                                    // }
                                  }
                                } else {
                                  selected.add(data['id'].toString());
                                  selectedGroupList.add(data);

                                  mergedList.add(data);

                                  setState(() {});
                                }
                              } else {
                                selected.remove(data['id'].toString());
                                selectedList.removeWhere(
                                    (user) => user.uid == data.uid);
                                mergedList.removeWhere(
                                    (user) => user.uid == data.uid);
                                setState(() {});
                              }
                              setState(() {});
                              setValue(selectedGroup, selected);
                            } else {
                              if (widget.isCall == false) {
                                finish(context);
                              }
                            }
                          })
                        : SizedBox();
                  },
                )
              : noDataFound();
        }
        return snapWidgetHelper(snap, loadingWidget: Offstage());
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              physics: const ScrollPhysics(),
              child: Column(
                children: [
                  if (widget.snap!.data!.isNotEmpty)
                    ListView.builder(
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: widget.snap!.data!.length,
                      shrinkWrap: true,
                      itemBuilder: (context, index) {
                        UserModel data = widget.snap!.data![index];
                        if (data.uid == loginStore.mId) {
                          return const SizedBox.shrink();
                        }
                        return Container(
                          padding: const EdgeInsets.symmetric(
                              vertical: 8, horizontal: 16),
                          child: Row(
                            children: [
                              (data.photoUrl.isEmptyOrNull)
                                  ? Hero(
                                      tag: data.uid.validate(),
                                      child: Container(
                                        height: 40,
                                        width: 40,
                                        padding: const EdgeInsets.all(8),
                                        color: getColorFromString(
                                            data.uid ?? data.name.validate()),
                                        child: Text(
                                          data.name.validate()[0].toUpperCase(),
                                          style: TS.secondaryTextStyle(
                                              color: Colors.white),
                                        ).center().fit(),
                                      ).cornerRadiusWithClipRRect(50),
                                    )
                                  : cachedImage(
                                      data.photoUrl.validate(),
                                      width: 40,
                                      height: 40,
                                      fit: BoxFit.cover,
                                    ).cornerRadiusWithClipRRect(80),
                              const SizedBox(width: 8),
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
                                      if (selected.contains(data.uid))
                                        Icon(Icons.check_circle_outlined,
                                            color: primaryColor, size: 20),
                                    ],
                                  ),
                                  Text(
                                    '${data.userStatus.validate()}',
                                    style: TS.secondaryTextStyle(),
                                  ),
                                ],
                              ).expand(),
                              widget.isCall!
                                  ? Row(
                                      children: [
                                        IconButton(
                                          icon: Icon(FontAwesome.phone,
                                              color: secondaryColor, size: 18),
                                          onPressed: () async {
                                            UserModel receiverData = UserModel(
                                              name: data.name,
                                              uid: data.uid,
                                              oneSignalPlayerId:
                                                  data.oneSignalPlayerId,
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
                                        IconButton(
                                          icon: Icon(FontAwesome.video_camera,
                                              color: secondaryColor, size: 18),
                                          onPressed: () async {
                                            UserModel receiverData = UserModel(
                                              name: data.name,
                                              uid: data.uid,
                                              oneSignalPlayerId:
                                                  data.oneSignalPlayerId,
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
                                                ? CallFunctions.dial(
                                                    context: context,
                                                    from: sender,
                                                    to: receiverData)
                                                : {};
                                          },
                                        ),
                                      ],
                                    )
                                  : widget.isAddParticipant
                                      ? existingMembersList
                                              .contains(data.uid.toString())
                                          ? const Icon(
                                              Icons.check_circle_outline,
                                              size: 20)
                                          : const Offstage()
                                      : const Offstage(),
                            ],
                          ),
                        ).onTap(() async {
                          if (widget.isGroupCreate) {
                            if (!selected.contains(data.uid.toString())) {
                              if (widget.isAddParticipant) {
                                if (existingMembersList
                                    .contains(data.uid.toString())) {
                                  toast('lblAlreadyExist'.translate);
                                } else {
                                  selected.add(data.uid.toString());
                                  selectedMPlayersId
                                      .add(data.oneSignalPlayerId.toString());
                                  selectedList.add(data);
                                  mergedList.add(data);
                                }
                              } else {
                                selected.add(data.uid.toString());
                                selectedMPlayersId
                                    .add(data.oneSignalPlayerId.toString());
                                selectedList.add(data);
                                mergedList.add(data);
                              }
                              setState(() {});
                            } else {
                              selected.remove(data.uid.toString());
                              selectedMPlayersId
                                  .remove(data.oneSignalPlayerId.toString());
                              selectedList
                                  .removeWhere((user) => user.uid == data.uid);
                              mergedList.remove(data);
                              setState(() {});
                            }
                            setValue(selectedMember, selected);
                            setState(() {});
                          } else {
                            if (widget.isCall == false) {
                              finish(context);
                            }
                          }
                        });
                      },
                    ),
                  buildGroupItemWidget(),
                  const SizedBox(height: 80), // Space for bottom bar
                ],
              ),
            ),
          ),
          // Bottom bar with original styling
          if (mergedList.isNotEmpty && widget.isFromForward)
            SafeArea(
              child: KeyboardVisibilityBuilder(
                builder: (context, isKeyboardVisible) {
                  return Container(
                    padding: EdgeInsets.only(
                      left: 12,
                      right: 12,
                      top: 8,
                      bottom: isKeyboardVisible
                          ? MediaQuery.of(context).viewInsets.bottom + 10
                          : 8,
                    ),
                    color: primaryColor,
                    child: Row(
                      children: [
                        Expanded(
                          child: Container(
                            height: 40,
                            child: ListView.builder(
                              scrollDirection: Axis.horizontal,
                              itemCount: mergedList.length,
                              itemBuilder: (context, index) {
                                var item = mergedList[index];
                                var name = item is Map<String, dynamic>
                                    ? item['name']?.toString() ?? 'Unknown'
                                    : (item as UserModel).name.toString();
                                return Container(
                                  margin: const EdgeInsets.only(right: 8),
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 12, vertical: 8),
                                  decoration: BoxDecoration(
                                    color: Colors.white.withOpacity(0.2),
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                  child: Text(
                                    name,
                                    style: TS.secondaryTextStyle(
                                        color: Colors.white),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                );
                              },
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Container(
                          width: 40,
                          height: 40,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: secondaryColor,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.send,
                              color: Colors.white, size: 20),
                        ).onTap(() async {
                          if (isSending) return;
                          setState(() => isSending = true);
                          if (selectedList.isNotEmpty) {
                            sendMessage(
                                receiverId: selectedList.first.uid.toString());
                          }
                          if (selectedGroupList.isNotEmpty) {
                            sendGroupMessage();
                          }
                          finish(context);
                          hideKeyboard(context);
                          setState(() {});
                        }),
                      ],
                    ),
                  );
                },
              ),
            ),
        ],
      ),
    );
  }
}
