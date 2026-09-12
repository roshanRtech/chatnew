import 'dart:io';
import 'dart:math';

import 'package:chat/components/Permissions.dart';
import 'package:chat/models/StoryModel.dart';
import 'package:chat/services/ChatMessageService.dart';
import 'package:chat/utils/AppCommon.dart';
import 'package:chat/utils/AppImages.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_mobx/flutter_mobx.dart';
import 'package:flutter_vector_icons/flutter_vector_icons.dart';
import 'package:nb_utils/nb_utils.dart';
import 'package:video_player/video_player.dart';

import '../main.dart';
import '../models/ChatMessageModel.dart';
import '../models/ChatRequestModel.dart';
import '../models/ContactModel.dart';
import '../models/UserModel.dart';
import '../screens/GroupChat/GroupProfileImageDailog.dart';
import '../utils/AppColors.dart';
import '../utils/AppConstants.dart';
import '../utils/Appwidgets.dart';
import '../utils/CallFunctions.dart';
import '../utils/providers/ChatRequestProvider.dart';

class ForwardUserListComponent extends StatefulWidget {
  final AsyncSnapshot<List<UserModel>>? snap;
  final AsyncSnapshot<List<dynamic>>? groupDara;
  final bool isGroupCreate;
  final bool isAddParticipant;
  final List<dynamic>? data;
  final bool? isCall;
  final bool isFromForward;
  final String? messageId;
  final ChatMessageModel? chatData;
  final bool? isFromGroup;

  ForwardUserListComponent(
      {this.snap,
      this.groupDara,
      this.isGroupCreate = false,
      this.isAddParticipant = false,
      this.data,
      this.isCall = false,
      this.isFromForward = false,
      this.messageId,
      this.chatData,
      this.isFromGroup});

  @override
  State<ForwardUserListComponent> createState() => _ForwardUserListComponentState();
}

class _ForwardUserListComponentState extends State<ForwardUserListComponent> {
  List<UserModel> selectedList = [];
  List<dynamic> selectedGroupList = [];
  List<dynamic> mergedList = [];

  List<String> selected = [];
  List<String> selectedMPlayersId = [];
  List<dynamic> existingMembersList = [];
  UserModel? receiverUser;
  bool statusUpload = false;
  bool isBlocked = false;
  bool isFirstMsg = false;
  String? currentLat;
  String? currentLong;

  // ScrollController scrollController = ScrollController();
  String searchCont = "";
  String groupChatId = "";
  List<String> receiverIds = [];

  String? groupName = '';

  // For Group
  List<UserModel> userModelList = [];
  List membersList = [];
  List<UserModel> userList = [];
  List<String> mList = [];
  String admin = '';
  VideoPlayerController? controller;
  String? groupCurrentLat;
  String? groupCurrentLong;
  Map<String, bool> readBy = {};
  int? videoSeconds = 0;
  int backgroundColor = 0xFF9C27B0;
  bool userExist = false;

  @override
  void initState() {
    super.initState();
    print("------------97>>${widget.chatData?.toJson()}");
    init();
  }

  init() async {
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
          print(userm.uid.toString() + "----------------------------------------" + userm.oneSignalPlayerId.toString());
        }
      }

      setState(() {});
    });
  }

  @override
  void setState(fn) {
    if (mounted) super.setState(fn);
  }

  final List<int> colorList = [
    0xFF9C27B0,
    0xFFF44336,
    0xFF4CAF50,
    0xFFFF9800,
    0xFF2196F3,
    0xFF000000,
  ];

  final random = Random();

  void getRandomColor() {
    backgroundColor = (colorList..shuffle()).first ?? 0;
    setState(() {});
  }

  Future<void> uploadStory({String? photoUrl}) async {
    if (widget.chatData?.messageType == VIDEO) {
      controller = VideoPlayerController.networkUrl(Uri.parse(photoUrl ?? ''));
      await controller!.initialize();
      videoSeconds = await controller?.value.duration.inSeconds;
    }

    File imageFile = await storyService.urlToFile(photoUrl ?? '');
    String filePath = 'storyImages/${DateTime.now().millisecondsSinceEpoch}.jpg';
    await storyService.uploadImage(imageFile,filePath).then((value) async {
      StoryModel data = StoryModel();
      data.userId = getStringAsync(userId);
      data.createAt = Timestamp.now();
      data.updatedAt = Timestamp.now();
      data.imagePath = value;
      if (widget.chatData?.messageType == VIDEO) {
        data.videoDuration = videoSeconds.toString();
      }
      data.type = widget.chatData?.messageType == IMAGE ? 'image' : 'video';
      data.userImgPath = loginStore.mPhotoUrl;
      data.userName = loginStore.mDisplayName;
      data.excludedUserList = appStore.excludedSelectedUserList;
      data.includedUserList = appStore.includedSelectedUserList;
      data.statusPrivacyIndex = getIntAsync(STATUS_PRIVACY_INDEX);

      await storyService.addStory(data, userId: getStringAsync(userId)).then((value) {
        log('status_uploaded'.translate);
      }).catchError((e) {
        log('error' + e.toString());
      });
    }).catchError((e) {
      log('error' + e.toString());
    });
  }

  Future<void> uploadStoryText() async {
    if (widget.chatData?.messageType == TEXT) {
      getRandomColor();
    }
    StoryModel data = StoryModel();
    data.userId = getStringAsync(userId);
    data.createAt = Timestamp.now();
    data.updatedAt = Timestamp.now();
    print("--------198>>${widget.chatData?.isEncrypt ?? ''}");
    if(widget.chatData?.isEncrypt==false){
      data.caption = widget.chatData?.message ?? '';
    }else{
      data.caption = await decryptedData(widget.chatData?.message ?? '');
    }
    data.backgroundColor = backgroundColor;
    data.type = 'text';
    data.userImgPath = loginStore.mPhotoUrl;
    data.userName = loginStore.mDisplayName;
    data.excludedUserList = appStore.excludedSelectedUserList;
    data.includedUserList = appStore.includedSelectedUserList;
    data.statusPrivacyIndex = getIntAsync(STATUS_PRIVACY_INDEX);

    await storyService.addStory(data, userId: getStringAsync(userId)).then((value) {
      log('status_uploaded'.translate);
    }).catchError((e) {
      log('error' + e.toString());
    });
  }

  @override
  void dispose() {
    if (controller != null && controller!.value.isInitialized) {
      controller?.dispose();
    }
    super.dispose();
  }

  // For Normal Message start

  // region send Message
  Future<void> sendMessage({String? stickerPath, File? filepath, String? type, String? receiverId}) async {
    userExist = await chatMessageService.checkUserStatus(senderId: getStringAsync(userId), receiverId: receiverId ?? '');
    print(" ===================== SEND MESSAGE CALLING =================== ");

    print(" Send Message Time ==> " + receiverId.toString());

    if (widget.isFromGroup == true) {
      await chatMessageService.forwardGetMessage(widget.chatData!, receiverId).then((value) async {
        type = widget.chatData?.messageType.toString();

        currentLat = value.currentLat.toString();
        currentLong = value.currentLong.toString();

        // if (isBlocked.validate(value: false)) {
        //   unblockDialog(context, receiver: widget.receiverUser!);
        //   return
        // }

        ChatMessageModel data = ChatMessageModel();
        for (String receiverUid in selected) {
          data.receiverId = receiverUid;

          //  print("Data Receiver Id is ==> " + data.receiverId.toString());
          // print("receiverUid is ==> " + receiverUid.toString());

          print("-----------158>>>${value.shareUser?.name}");


          data.senderId = getStringAsync(userId);
          data.messageType = value.messageType;
          data.message = value.message;
          data.photoUrl = value.photoUrl;
          data.isMessageRead = false;
          data.stickerPath = stickerPath;
          data.createdAt = DateTime.now().millisecondsSinceEpoch;

          data.isFromForward = widget.isFromForward ? true : false;

          if (!(value.shareUser?.name.isEmptyOrNull ?? false)) {
            data.shareUser = value.shareUser;
          }

          data.groupId = value.groupId;
          data.groupName = value.groupName;
          data.groupProfile = value.groupProfile;

          data.isEncrypt = false;

          if (type == IMAGE) {
            data.messageType = MessageType.IMAGE.name;
            data.isEncrypt = true;
          } else if (type == VIDEO) {
            data.messageType = MessageType.VIDEO.name;
          } else if (type == AUDIO) {
            data.messageType = MessageType.AUDIO.name;
          } else if (type == DOC) {
            data.messageType = MessageType.DOC.name;
            data.documentName = value.documentName;
          } else if (type == VOICE_NOTE) {
            data.messageType = MessageType.VOICE_NOTE.name;
          } else if (stickerPath.validate().isNotEmpty) {
            data.messageType = MessageType.STICKER.name;
          } else {
            if (type == LOCATION) {
              data.messageType = MessageType.LOCATION.name;
              data.currentLat = currentLat;
              data.currentLong = currentLong;
            } else if (type == TYPE_VOICE_NOTE) {
              data.messageType = MessageType.VOICE_NOTE.name;
              log(data.messageType);
              log(MessageType.VOICE_NOTE.name);
            } else {
              data.messageType = MessageType.TEXT.name;

              data.isEncrypt = true;
            }
          }
          for (String receiverUid in selected) {
            // if (!receiverUid.blockedTo!.contains(userService.getUserReference(uid: getStringAsync(userId)))) {
            if (await chatRequestService.isRequestsUserExist(receiverUid)) {
              print("send normal message forward ================");
              sendNormalMessages(data, filepath: filepath, receiverId ?? "");
            } else {
              print("send chatRequest forward ================");
              if (userExist == false) {
                sendChatRequest(data, file: filepath, receiverId);
              } else {
                sendNormalMessages(data, filepath: filepath, receiverId ?? "");
              }
            }
            chatMessageService.getContactsDocument(of: getStringAsync(userId), forContact: receiverUid).update(<String, dynamic>{
              "lastMessageTime": DateTime.now().millisecondsSinceEpoch,
            });
            chatMessageService.getContactsDocument(of: receiverUid, forContact: getStringAsync(userId)).update(<String, dynamic>{
              "lastMessageTime": DateTime.now().millisecondsSinceEpoch,
            });

            // } else {
            //   data.isMessageRead = true;
            //   chatMessageService.addMessage(data).then((value) {
            //     // messageCont.clear();
            //     setState(() {});
            //   });
            // }
          }
        }
      }).catchError((e) {
        log(e.toString());
      });
    } else {
      await chatMessageService.getMessage(widget.chatData!).then((value) async {
        print(" ##############3 Inside Get Message ##########");
        print("sendMessage Time Message is =====> " + value.message.toString());
        print("sendMessage Time Photo Url is =====> " + value.photoUrl.toString());
        print("sendMessage Time Latitude is =====> " + value.currentLat.toString());
        print("sendMessage Time Longitude  is =====> " + value.currentLong.toString());
        type = widget.chatData!.messageType.toString();
        print(" Current Message Type Is =====> " + type.toString());

        currentLat = value.currentLat.toString();
        currentLong = value.currentLong.toString();

        // if (isBlocked.validate(value: false)) {
        //   unblockDialog(context, receiver: widget.receiverUser!);
        //   return
        // }

        ChatMessageModel data = ChatMessageModel();
        for (String receiverUid in selected) {
          data.receiverId = receiverUid;
          data.senderId = sender.uid;
          data.messageType = value.messageType;
          data.message = value.message;
          data.photoUrl = value.photoUrl;
          data.isMessageRead = false;
          if (!(value.shareUser?.name.isEmptyOrNull ?? false)) {
            data.shareUser = value.shareUser;
          }
          data.groupId = value.groupId;
          data.groupName = value.groupName;
          data.groupProfile = value.groupProfile;
          data.stickerPath = stickerPath;
          data.createdAt = DateTime.now().millisecondsSinceEpoch;

          data.isEncrypt = false;
          data.isFromForward = widget.isFromForward ? true : false;

          if (type == IMAGE) {
            data.messageType = MessageType.IMAGE.name;
            data.isEncrypt = true;
          } else if (type == VIDEO) {
            data.messageType = MessageType.VIDEO.name;
          } else if (type == AUDIO) {
            data.messageType = MessageType.AUDIO.name;
          } else if (type == DOC) {
            data.messageType = MessageType.DOC.name;
            data.documentName = value.documentName;
          } else if (type == VOICE_NOTE) {
            data.messageType = MessageType.VOICE_NOTE.name;
          } else if (stickerPath.validate().isNotEmpty) {
            data.messageType = MessageType.STICKER.name;
          } else {
            if (type == LOCATION) {
              data.messageType = MessageType.LOCATION.name;
              data.currentLat = currentLat;
              data.currentLong = currentLong;
            } else if (type == TYPE_VOICE_NOTE) {
              data.messageType = MessageType.VOICE_NOTE.name;
              log(data.messageType);
              log(MessageType.VOICE_NOTE.name);
            } else {
              data.messageType = MessageType.TEXT.name;

              data.isEncrypt = true;
            }
          }
          for (String receiverUid in selected) {
            // if (!receiverUid.blockedTo!.contains(userService.getUserReference(uid: getStringAsync(userId)))) {
            if (await chatRequestService.isRequestsUserExist(receiverUid)) {
              print("send normal message forward ================");
              sendNormalMessages(data, filepath: filepath, receiverId!);
            } else {
              print("send chatRequest forward ================");
              if (userExist == false) {
                sendChatRequest(data, file: filepath, receiverId);
              } else {
                sendChatRequest(data, file: filepath, receiverId);
              }
            }
            chatMessageService.getContactsDocument(of: getStringAsync(userId), forContact: receiverUid).update(<String, dynamic>{
              "lastMessageTime": DateTime.now().millisecondsSinceEpoch,
            });
            chatMessageService.getContactsDocument(of: receiverUid, forContact: getStringAsync(userId)).update(<String, dynamic>{
              "lastMessageTime": DateTime.now().millisecondsSinceEpoch,
            });

            // } else {
            //   data.isMessageRead = true;
            //   chatMessageService.addMessage(data).then((value) {
            //     // messageCont.clear();
            //     setState(() {});
            //   });
            // }
          }
        }
      }).catchError((e) {
        log(e.toString());
      });
    }

    // log(type == TYPE_VOICE_NOTE);
  }

  void sendNormalMessages(ChatMessageModel data, String receiverId, {File? filepath}) async {
    print(" ================= SEND NORMAL MSG =====================");
    if (widget.isFromGroup == true) {
      await chatMessageService
          .forwardGetMessage(
        widget.chatData!,
        receiverId,
      )
          .then((value) async {
        for (String userId in selected) {
          if (isFirstMsg) {
            ContactModel data = ContactModel();
            data.uid = userId;
            data.addedOn = Timestamp.now();
            data.lastMessageTime = DateTime.now().millisecondsSinceEpoch;

            chatMessageService.getContactsDocument(of: getStringAsync(userId), forContact: userId).set(data.toJson()).then((value) {
              //
            }).catchError((e) {
              log(e);
            });
          }
          String? message = '';
          if (data.messageType == IMAGE) {
            message = " Sent you " + MessageType.IMAGE.name.capitalizeFirstLetter();
          } else if (data.messageType == VIDEO) {
            message = " Sent You " + MessageType.VIDEO.name.capitalizeFirstLetter();
          } else if (data.messageType == AUDIO) {
            message = " Sent you " + MessageType.AUDIO.name.capitalizeFirstLetter();
          } else if (data.messageType == DOC) {
            message = " Sent you " + MessageType.DOC.name.capitalizeFirstLetter();
          } else if (data.messageType == VOICE_NOTE) {
            message = " Sent you";
          } else if (data.messageType == LOCATION) {
            message = " Sent you " + MessageType.LOCATION.name.capitalizeFirstLetter();
          } else if (data.messageType == STICKER) {
            message = " Sent you " + MessageType.STICKER.name.capitalizeFirstLetter();
          } else {
            message = value.message.validate();
          }

          selectedMPlayersId.map((e) {
            if (!e.isEmptyOrNull) {
              notificationService.sendPushNotifications(getStringAsync(userDisplayName), message ?? '', receivierUids: selected, mPlayerIds: selectedMPlayersId).catchError((e) {
                print("erooor============${e.toString()}");
              });
            }
          });

          setState(() {});

          if (data.messageType == MessageType.LOCATION.name) {
            chatMessageService.addLatLong(data, lat: currentLat, long: currentLong);
          }
          await chatMessageService.addMessage(data).then((value) async {
            print("sendNormalMessages  Photo Url Is ==>" + data.photoUrl.toString());
            // ignore: unnecessary_null_comparison
            await chatMessageService.addMessageToDbForward(senderDoc: value, data: data, sender: sender, user: widget.snap!.data, image: File(data.photoUrl!), isRequest: false).then((value) {
              //
            });
          });

          userService.fireStore
              .collection(USER_COLLECTION)
              .doc(data.senderId)
              .collection(CONTACT_COLLECTION)
              .doc(userId)
              .update({'lastMessageTime': DateTime.now().millisecondsSinceEpoch}).catchError((e) {
            log(e);
          });
          userService.fireStore
              .collection(USER_COLLECTION)
              .doc(userId)
              .collection(CONTACT_COLLECTION)
              .doc(data.senderId)
              .update({'lastMessageTime': DateTime.now().millisecondsSinceEpoch}).catchError((e) {
            log(e);
          });
        }
      }).catchError((e) {
        log(e.toString());
      });
    } else {
      await chatMessageService.getMessage(widget.chatData!).then((value) async {
        for (String userId in selected) {
          if (isFirstMsg) {
            ContactModel data = ContactModel();
            data.uid = userId;
            data.addedOn = Timestamp.now();
            data.lastMessageTime = DateTime.now().millisecondsSinceEpoch;

            chatMessageService.getContactsDocument(of: getStringAsync(userId), forContact: userId).set(data.toJson()).then((value) {
              //
            }).catchError((e) {
              log(e);
            });
          }
          String? message = '';
          if (data.messageType == IMAGE) {
            message = " Sent you " + MessageType.IMAGE.name.capitalizeFirstLetter();
          } else if (data.messageType == VIDEO) {
            message = " Sent You " + MessageType.VIDEO.name.capitalizeFirstLetter();
          } else if (data.messageType == AUDIO) {
            message = " Sent you " + MessageType.AUDIO.name.capitalizeFirstLetter();
          } else if (data.messageType == DOC) {
            message = " Sent you " + MessageType.DOC.name.capitalizeFirstLetter();
            data.documentName = data.documentName;
          } else if (data.messageType == VOICE_NOTE) {
            message = " Sent you";
          } else if (data.messageType == LOCATION) {
            message = " Sent you " + MessageType.LOCATION.name.capitalizeFirstLetter();
          } else if (data.messageType == STICKER) {
            message = " Sent you " + MessageType.STICKER.name.capitalizeFirstLetter();
          } else {
            message = value.message.validate();
          }
          //   notificationService.sendPushNotifications(getStringAsync(userDisplayName), messageCont.text.trim(), receiverPlayerId: widget.receiverUser!.oneSignalPlayerId).catchError(log);
          notificationService.sendPushNotifications(getStringAsync(userDisplayName), message, receivierUids: selected, mPlayerIds: selectedMPlayersId).catchError((e) {
            print("erooor============${e.toString()}");
          });
          setState(() {});

          if (data.messageType == MessageType.LOCATION.name) {
            chatMessageService.addLatLong(data, lat: currentLat, long: currentLong);
          }

          await chatMessageService.addMessage(data).then((value) async {
            // ignore: unnecessary_null_comparison
            await chatMessageService.addMessageToDbForward(senderDoc: value, data: data, sender: sender, user: widget.snap!.data, image: File(data.photoUrl!), isRequest: false).then((value) {
              //
            });
          });

          userService.fireStore
              .collection(USER_COLLECTION)
              .doc(data.senderId)
              .collection(CONTACT_COLLECTION)
              .doc(userId)
              .update({'lastMessageTime': DateTime.now().millisecondsSinceEpoch}).catchError((e) {
            log(e);
          });
          userService.fireStore
              .collection(USER_COLLECTION)
              .doc(userId)
              .collection(CONTACT_COLLECTION)
              .doc(data.senderId)
              .update({'lastMessageTime': DateTime.now().millisecondsSinceEpoch}).catchError((e) {
            log(e);
          });
        }
      }).catchError((e) {
        log(e.toString());
      });
    }
  }

  //endregion

  // region chat request
  void sendChatRequest(ChatMessageModel data, String? receiverId, {File? file}) async {
    print("=================== Into Send Chat request ==============================");

    if (widget.isFromGroup == true) {
      await chatMessageService.forwardGetMessage(widget.chatData!, receiverId!).then((value) async {
        for (String receiverUid in selected) {
          String? message = value.message;
          data.messageType = value.messageType;
          data.isFromForward = widget.isFromForward ? true : false;

          // print("Data=================${data.messageType}");
          if (data.messageType == IMAGE) {
            message = " Sent you " + MessageType.IMAGE.name.capitalizeFirstLetter();
          } else if (data.messageType == VIDEO) {
            message = " Sent You " + MessageType.VIDEO.name.capitalizeFirstLetter();
          } else if (data.messageType == DOC) {
            message = " Sent you " + MessageType.AUDIO.name.capitalizeFirstLetter();
          } else if (data.messageType == DOC) {
            message = " Sent you " + MessageType.DOC.name.capitalizeFirstLetter();
          } else if (data.messageType == VOICE_NOTE) {
            message = " Sent you " + MessageType.VOICE_NOTE.name.capitalizeFirstLetter();
          } else if (data.messageType == LOCATION) {
            message = " Sent you " + MessageType.LOCATION.name.capitalizeFirstLetter();
          } else if (data.messageType == STICKER) {
            message = " Sent you " + MessageType.STICKER.name.capitalizeFirstLetter();
          } else {
            message = value.message.validate();
          }

          if (!selectedMPlayersId.isNotEmpty) {
            notificationService.sendPushNotifications(getStringAsync(userDisplayName), message, receivierUids: selected.validate(), mPlayerIds: selectedMPlayersId).catchError((e) {});
            //  notificationService.sendPushNotifications(getStringAsync(userDisplayName), messageCont.text.trim(), receiverPlayerId: widget.receiverUser!.oneSignalPlayerId).catchError(log);
          }

          ChatRequestModel chatReq = ChatRequestModel();
          chatReq.uid = data.senderId;
          chatReq.profilePic = data.photoUrl;
          chatReq.requestStatus = RequestStatus.Pending.index;
          chatReq.senderIdRef = userService.ref!.doc(sender.uid);
          chatReq.createdAt = DateTime.now().millisecondsSinceEpoch;
          chatReq.updatedAt = DateTime.now().millisecondsSinceEpoch;

          if (await chatRequestService.isRequestUserExist(sender.uid!, receiverUid.validate())) {
            chatMessageService.addMessage(data).then((value) async {
              await chatMessageService
                  .addMessageToDbForward(senderDoc: value, data: data, sender: sender, user: widget.snap!.data, image: File(data.photoUrl.toString()), isRequest: true)
                  .then((value) {
                //  setState(() {});
              });
            });
          } else {
            chatRequestService.addChatWithCustomId(sender.uid!, chatReq.toJson(), receiverUid.validate()).then((value) {}).catchError((e) {});

            chatMessageService.addMessage(data).then((value) async {
              await chatMessageService
                  .addMessageToDbForward(senderDoc: value, data: data, sender: sender, user: widget.snap!.data, image: File(data.photoUrl.toString()), isRequest: true)
                  .then((value) {
                // audioPath = null;
              });
              userService.fireStore
                  .collection(USER_COLLECTION)
                  .doc(data.senderId)
                  .collection(CONTACT_COLLECTION)
                  .doc(receiverUid)
                  .update({'lastMessageTime': DateTime.now().millisecondsSinceEpoch}).catchError((e) {
                setState(() {});
              });
              userService.fireStore
                  .collection(USER_COLLECTION)
                  .doc(receiverUid)
                  .collection(CONTACT_COLLECTION)
                  .doc(data.senderId)
                  .update({'lastMessageTime': DateTime.now().millisecondsSinceEpoch}).catchError((e) {
                setState(() {});
              });
            });
          }
        }
      });
    } else {
      await chatMessageService.getMessage(widget.chatData!).then((value) async {
        print("Selecetd List Member ==> " + selected.toString());
        for (String receiverUid in selected) {
          String? message = value.message;
          data.messageType = value.messageType;

          // print("Data=================${data.messageType}");
          if (data.messageType == IMAGE) {
            message = " Sent you " + MessageType.IMAGE.name.capitalizeFirstLetter();
          } else if (data.messageType == VIDEO) {
            message = " Sent You " + MessageType.VIDEO.name.capitalizeFirstLetter();
          } else if (data.messageType == DOC) {
            message = " Sent you " + MessageType.AUDIO.name.capitalizeFirstLetter();
          } else if (data.messageType == DOC) {
            message = " Sent you " + MessageType.DOC.name.capitalizeFirstLetter();
            data.documentName = data.documentName;
          } else if (data.messageType == VOICE_NOTE) {
            message = " Sent you " + MessageType.VOICE_NOTE.name.capitalizeFirstLetter();
          } else if (data.messageType == LOCATION) {
            message = " Sent you " + MessageType.LOCATION.name.capitalizeFirstLetter();
          } else if (data.messageType == STICKER) {
            message = " Sent you " + MessageType.STICKER.name.capitalizeFirstLetter();
          } else {
            message = value.message.validate();
          }

          if (!selectedMPlayersId.isNotEmpty) {
            notificationService.sendPushNotifications(getStringAsync(userDisplayName), message, receivierUids: selected.validate(), mPlayerIds: selectedMPlayersId).catchError((e) {});
            //  notificationService.sendPushNotifications(getStringAsync(userDisplayName), messageCont.text.trim(), receiverPlayerId: widget.receiverUser!.oneSignalPlayerId).catchError(log);
          }

          ChatRequestModel chatReq = ChatRequestModel();
          chatReq.uid = data.senderId;
          chatReq.profilePic = data.photoUrl;
          chatReq.requestStatus = RequestStatus.Pending.index;
          chatReq.senderIdRef = userService.ref!.doc(sender.uid);
          chatReq.createdAt = DateTime.now().millisecondsSinceEpoch;
          chatReq.updatedAt = DateTime.now().millisecondsSinceEpoch;

          if (await chatRequestService.isRequestUserExist(sender.uid!, receiverUid.validate())) {
            chatMessageService.addMessage(data).then((value) async {
              await chatMessageService
                  .addMessageToDbForward(senderDoc: value, data: data, sender: sender, user: widget.snap!.data, image: File(data.photoUrl.toString()), isRequest: true)
                  .then((value) {
                //  setState(() {});
              });
            });
          } else {
            chatRequestService.addChatWithCustomId(sender.uid!, chatReq.toJson(), receiverUid.validate()).then((value) {}).catchError((e) {});

            chatMessageService.addMessage(data).then((value) async {
              await chatMessageService
                  .addMessageToDbForward(senderDoc: value, data: data, sender: sender, user: widget.snap!.data, image: File(data.photoUrl.toString()), isRequest: true)
                  .then((value) {
                // audioPath = null;
              });
              userService.fireStore
                  .collection(USER_COLLECTION)
                  .doc(getStringAsync(userId))
                  .collection(CONTACT_COLLECTION)
                  .doc(receiverUid)
                  .update({'lastMessageTime': DateTime.now().millisecondsSinceEpoch}).catchError((e) {
                setState(() {});
              });
              userService.fireStore
                  .collection(USER_COLLECTION)
                  .doc(receiverUid)
                  .collection(CONTACT_COLLECTION)
                  .doc(getStringAsync(userId))
                  .update({'lastMessageTime': DateTime.now().millisecondsSinceEpoch}).catchError((e) {
                setState(() {});
              });
            });
          }
        }
      });
    }
  }

  // For Normal Message End
  //
  // For Group Message  Start

  Future<void> sendGroupMessage({String? stickerPath, File? filepath, String? type}) async {
    print("Send Group Message calling");
    addReadBy();

    print("--------------653>>>${sender.uid}");
    print("--------------654>>>${getStringAsync(userId)}");
    ChatMessageModel chatMessageModel = ChatMessageModel();
    chatMessageModel.senderId = getStringAsync(userId);
    chatMessageModel.message = widget.chatData?.message;
    chatMessageModel.isMessageRead = false;
    chatMessageModel.stickerPath = stickerPath;
    chatMessageModel.isEncrypt = false;
    chatMessageModel.createdAt = DateTime.now().millisecondsSinceEpoch;
    chatMessageModel.messageType = widget.chatData!.messageType.toString();
    chatMessageModel.photoUrl = widget.chatData!.photoUrl.toString();
    chatMessageModel.readBy = readBy;
    chatMessageModel.isFromForward = widget.isFromForward ? true : false;

    groupCurrentLat = widget.chatData!.currentLat.toString();
    groupCurrentLong = widget.chatData!.currentLong.toString();

    type = chatMessageModel.messageType;
    if (stickerPath.validate().isNotEmpty) {
      chatMessageModel.messageType = MessageType.STICKER.name;
    } else {
      if (type == LOCATION) {
        chatMessageModel.messageType = MessageType.LOCATION.name;
        chatMessageModel.currentLat = groupCurrentLat;
        chatMessageModel.currentLong = groupCurrentLong;
      } else if (type == IMAGE) {
        chatMessageModel.messageType = MessageType.IMAGE.name;
      } else if (type == DOC) {
        chatMessageModel.messageType = MessageType.DOC.name;
        chatMessageModel.documentName = widget.chatData?.documentName;
      } else if (type == VOICE_NOTE) {
        chatMessageModel.messageType = MessageType.VOICE_NOTE.name;
        log(chatMessageModel.messageType);
        log(MessageType.VOICE_NOTE.name);
      } else {
        chatMessageModel.messageType = MessageType.TEXT.name;
        chatMessageModel.message = widget.chatData?.message;
        chatMessageModel.isEncrypt = true;
      }
    }

    //  sendNormalGroupMessages(chatMessageModel, result: result != null ? result : null, filepath: filepath);
    sendNormalGroupMessages(chatMessageModel, type: type, filepath: filepath);
  }

  void sendNormalGroupMessages(ChatMessageModel data, {String? type, File? filepath}) async {
    String? msgValue = widget.chatData!.message.toString();
    ContactModel contactModel = ContactModel();
    contactModel.uid = groupChatId;
    contactModel.addedOn = Timestamp.now();
    contactModel.lastMessageTime = DateTime.now().millisecondsSinceEpoch;
    contactModel.groupRefUrl = groupChatId;
    data.photoUrl = data.photoUrl.toString();
    data.isFromForward = widget.isFromForward ? true : false;

    String? message = '';
    if (type == TYPE_Image) {
      message = getStringAsync(userDisplayName) + " Sent you " + MessageType.IMAGE.name.capitalizeFirstLetter();
    } else if (type == TYPE_VIDEO) {
      message = getStringAsync(userDisplayName) + " sent you " + MessageType.VIDEO.name.capitalizeFirstLetter();
    } else if (type == TYPE_AUDIO) {
      message = getStringAsync(userDisplayName) + " Sent you " + MessageType.AUDIO.name.capitalizeFirstLetter();
    } else if (type == TYPE_DOC) {
      message = getStringAsync(userDisplayName) + " Sent you " + MessageType.DOC.name.capitalizeFirstLetter();
    } else if (type == TYPE_VOICE_NOTE) {
      message = getStringAsync(userDisplayName) + " Sent you " + MessageType.VOICE_NOTE.name.capitalizeFirstLetter();
    } else if (type == TYPE_LOCATION) {
      message = getStringAsync(userDisplayName) + " Sent you " + MessageType.LOCATION.name.capitalizeFirstLetter();
    } else if (type == TYPE_STICKER) {
      message = getStringAsync(userDisplayName) + " Sent you " + MessageType.STICKER.name.capitalizeFirstLetter();
    } else {
      message = getStringAsync(userDisplayName) + " Sent you " + msgValue.validate();
    }

    mList.map((e) async{
      if(!e.isEmptyOrNull){
        await notificationService.sendPushNotifications(groupName.validate() + " ", message??'', isGrp: true, recevierUid: groupChatId, mPlayerIds: mList).catchError((e) {
          log('error' + e.toString());
        });
      }
    });


    await chatMessageService.getContactsDocument(of: getStringAsync(userId), forContact: groupChatId).update(<String, dynamic>{
      "lastMessageTime": DateTime.now().millisecondsSinceEpoch,
    }).catchError((e,s) {
      print("----------856>>${e.toString()}");
      print("----------857>>${s.toString()}");
    }).then((value) {
      userModelList.forEach((element) async {
        log(element.oneSignalPlayerId);
        await chatMessageService.getContactsDocument(of: element.uid.validate(), forContact: groupChatId).update(<String, dynamic>{
          "lastMessageTime": DateTime.now().millisecondsSinceEpoch,
        });
      });
    });

  /*  await notificationService.sendPushNotifications(groupName.validate() + " ", message, isGrp: true, recevierUid: groupChatId, mPlayerIds: mList).catchError((e) {
      log('error' + e.toString());
    }).then((value) async {
      await chatMessageService.getContactsDocument(of: getStringAsync(userId), forContact: groupChatId).update(<String, dynamic>{
        "lastMessageTime": DateTime.now().millisecondsSinceEpoch,
      }).catchError((e) {
        log(e);
      }).then((value) {
        userModelList.forEach((element) async {
          log(element.oneSignalPlayerId);
          await chatMessageService.getContactsDocument(of: element.uid.validate(), forContact: groupChatId).update(<String, dynamic>{
            "lastMessageTime": DateTime.now().millisecondsSinceEpoch,
          });
          // if (element.uid != getStringAsync(userId)) {
          //   notificationService.sendPushNotifications(getStringAsync(userDisplayName), messageCont.text, receiverPlayerId: element.oneSignalPlayerId).catchError((e) {
          //     log('error' + e);
          //   });
          // }
        });
      });
    });*/

    setState(() {});

    if (data.messageType == MessageType.LOCATION.name) {
      groupChatMessageService.addLatLong(data, groupId: groupChatId, lat: currentLat, long: currentLong);
    }

    groupChatMessageService.addIsEncrypt(data);
    await groupChatMessageService.addMessage(data, groupChatId).then((value) async {
      await groupChatMessageService
          .addMessageToDbForward(senderDoc: value, data: data, image: data.photoUrl!.toString().isNotEmpty ? File(data.photoUrl!.toString()) : null, isRequest: false)
          .then((value) {});
    }).catchError((e,s) {
      print("--------899>>${e.toString()}");
      print("--------900>>${s.toString()}");
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
    return fireStore.collection('group').where('searchCase', arrayContains: searchText.validate().isEmpty ? null : searchText!.toLowerCase()).snapshots().map((x) {
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
                            padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                            child: Row(
                              children: [
                                Stack(
                                  children: [
                                    noProfileImageFound(height: 45, width: 45, isGroup: true).cornerRadiusWithClipRRect(50),
                                    data['photoUrl'] == null
                                        ? noProfileImageFound(height: 45, width: 45, isGroup: true).cornerRadiusWithClipRRect(50).onTap(() {
                                            showDialog(
                                              context: context,
                                              builder: (context) {
                                                return GroupProfileImageDailog(data: data);
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
                                                return noProfileImageFound(height: 45, width: 45, isGroup: true);
                                              },
                                            ).cornerRadiusWithClipRRect(50),
                                          ).onTap(() {
                                            showDialog(
                                              context: context,
                                              builder: (context) {
                                                return GroupProfileImageDailog(data: data);
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
                                          data['name'].toString().capitalizeFirstLetter(),
                                          style: primaryTextStyle(),
                                          maxLines: 1,
                                          textAlign: TextAlign.start,
                                          overflow: TextOverflow.ellipsis,
                                        ).expand(),
                                        2.width,

                                        if (selected.contains(data['id'])) Icon(Icons.check_circle_outlined, color: primaryColor)

                                        // StreamBuilder<int>(
                                        //   stream: groupChatMessageService.getUnReadCount(currentUser: getStringAsync(userId), groupDocId: data['id']),
                                        //   builder: (context, snap) {
                                        //     if (snap.hasData) {
                                        //       print("unread count for groups====== ${snap.data}");
                                        //       if (snap.data != 0) {
                                        //         //chatMessageService.fetchForMessageCount(loginStore.mId);
                                        //         return Container(
                                        //           height: 18,
                                        //           width: 18,
                                        //           decoration: BoxDecoration(borderRadius: BorderRadius.circular(20), color: primaryColor),
                                        //           child: Text(snap.data.validate().toString(), style: secondaryTextStyle(size: 12, color: Colors.white)).center(),
                                        //         );
                                        //       }
                                        //     }
                                        //     return Offstage();
                                        //   },
                                        // ),
                                        //
                                      ],
                                    ),
                                    2.height,
                                    // Row(
                                    //   mainAxisSize: MainAxisSize.min,
                                    //   children: [
                                    //     LastMessageContainer(
                                    //       stream: groupChatMessageService.fetchLastMessageBetween(
                                    //         groupDocId: data['id'],
                                    //       ),
                                    //     ),
                                    //   ],
                                    // ),
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
                                  if (existingMembersList.contains(data['id'])) {
                                    toast('lblAlreadyExist'.translate);
                                  } else {
                                    // if (mergedList.length <= 4) {
                                    selected.add(data['id'].toString());
                                    selectedGroupList.add(data);
                                    // }
                                    // if (mergedList.length >= 5) {
                                    //   await showConfirmDialogCustom(context,

                                    //       dialogAnimation: DialogAnimation.SCALE,
                                    //       title: "You can only share with up to 5 chats",
                                    //       positiveText: 'OK',
                                    //       primaryColor: primaryColor, onAccept: (v) {
                                    //     // finish(context);
                                    //     // context,
                                    //     // builder: (p0) {
                                    //     //   return ForwardValidationDialog();
                                    //     // },
                                    //     // contentPadding: EdgeInsets.zero,
                                    //     // dialogAnimation: DialogAnimation.SLIDE_TOP_BOTTOM,
                                    //   });
                                    //   // toast(value)
                                    // } else {
                                    //   if (mergedList.length <= 4) {
                                    mergedList.add(data);
                                    //   }
                                    // }
                                  }
                                } else {
                                  // if (mergedList.length <= 4) {
                                  selected.add(data['id'].toString());
                                  selectedGroupList.add(data);
                                  // }

                                  // if (mergedList.length >= 4) {
                                  //   await showConfirmDialogCustom(context,
                                  //       dialogAnimation: DialogAnimation.SCALE, title: "You can only share with up to 5 chats", positiveText: 'OK', primaryColor: primaryColor, onAccept: (v) {
                                  //     // finish(context);
                                  //     // context,
                                  //     // builder: (p0) {
                                  //     //   return ForwardValidationDialog();
                                  //     // },
                                  //     // contentPadding: EdgeInsets.zero,
                                  //     // dialogAnimation: DialogAnimation.SLIDE_TOP_BOTTOM,
                                  //   });
                                  // toast(value)
                                  // } else {
                                  //   if (mergedList.length <= 4) {
                                  mergedList.add(data);
                                  // }
                                  // }

                                  // mergedList.addAll(selectedGroupList);

                                  setState(() {});
                                }
                                // mergedList.addAll(selectedGroupList);
                              } else {
                                selected.remove(data['id'].toString());
                                selectedList.removeWhere((user) => user.uid == data.uid);
                                mergedList.removeWhere((user) => user.uid == data.uid);
                                // selectedGroupList.remove(data);
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
      body: Stack(
        alignment: Alignment.bottomCenter,
        children: [
          SingleChildScrollView(
            physics: ScrollPhysics(),
            child: Column(
              children: [
                Padding(
                  padding: EdgeInsets.symmetric(vertical: 8, horizontal: 16),
                  child: GestureDetector(
                    onTap: () {
                      setState(() {
                        statusUpload = !statusUpload;
                      });
                    },
                    child: Row(
                      children: [
                        Container(
                          height: 50,
                          width: 50,
                          padding: EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: primaryColor,
                            borderRadius: BorderRadius.circular(50),
                          ),
                          child: Center(
                            child: Image.asset(
                              statusIcon,
                              width: 20,
                              height: 20,
                              color: Colors.white,
                              fit: BoxFit.cover,
                            ),
                          ),
                        ),
                        10.width,
                        Text('my_status'.translate, style: boldTextStyle()).expand(),
                        if (statusUpload == true) Icon(Icons.check_circle_outlined, color: primaryColor)
                      ],
                    ),
                  ),
                ).visible(widget.chatData?.messageType == TEXT || widget.chatData?.messageType == VIDEO || widget.chatData?.messageType == IMAGE),
                Container(
                  color: Colors.grey,
                  width: double.infinity,
                  height: 0.5,
                ),
                if (widget.snap!.data!.isNotEmpty)
                  ListView.builder(
                    physics: ScrollPhysics(),
                    itemCount: widget.snap!.data!.length,
                    shrinkWrap: true,
                    itemBuilder: (context, index) {
                      UserModel data = widget.snap!.data![index];

                      if (data.uid == loginStore.mId) {
                        return 0.height;
                      }
                      return Container(
                        padding: EdgeInsets.symmetric(vertical: 8, horizontal: 16),
                        child: Row(
                          children: [
                            (data.photoUrl.isEmptyOrNull)
                                ? Hero(
                                    tag: data.uid.validate(),
                                    child: Container(
                                      height: 50,
                                      width: 50,
                                      padding: EdgeInsets.all(10),
                                      color: getColorFromString(data.uid ?? data.name.validate()),
                                      child: Text(data.name.validate()[0].toUpperCase(), style: secondaryTextStyle(color: Colors.white)).center().fit(),
                                    ).cornerRadiusWithClipRRect(50),
                                  )
                                : cachedImage(data.photoUrl.validate(), width: 50, height: 50, fit: BoxFit.cover).cornerRadiusWithClipRRect(80),
                            12.width,
                            Column(
                              mainAxisAlignment: MainAxisAlignment.start,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text('${data.name.validate().capitalizeFirstLetter()}', style: primaryTextStyle()).expand(),
                                    if (selected.contains(data.uid)) Icon(Icons.check_circle_outlined, color: primaryColor)
                                  ],
                                ),
                                Text('${data.userStatus.validate()}', style: secondaryTextStyle()),
                              ],
                            ).expand(),
                            widget.isCall!
                                ? Row(
                                    children: [
                                      IconButton(
                                        icon: Icon(FontAwesome.phone, color: secondaryColor, size: 18),
                                        onPressed: () async {
                                          UserModel receiverData = UserModel(
                                            name: data.name,
                                            uid: data.uid,
                                            oneSignalPlayerId: data.oneSignalPlayerId,
                                            photoUrl: data.photoUrl,
                                          );
                                          UserModel sender = UserModel(
                                            name: getStringAsync(userDisplayName),
                                            photoUrl: getStringAsync(userPhotoUrl),
                                            uid: getStringAsync(userId),
                                            oneSignalPlayerId: getStringAsync(playerId),
                                          );
                                          return await Permissions.cameraAndMicrophonePermissionsGranted() ? CallFunctions.voiceDial(context: context, from: sender, to: receiverData) : {};
                                        },
                                      ),
                                      IconButton(
                                        icon: Icon(FontAwesome.video_camera, color: secondaryColor, size: 18),
                                        onPressed: () async {
                                          UserModel receiverData = UserModel(
                                            name: data.name,
                                            uid: data.uid,
                                            oneSignalPlayerId: data.oneSignalPlayerId,
                                            photoUrl: data.photoUrl,
                                          );
                                          UserModel sender = UserModel(
                                            name: getStringAsync(userDisplayName),
                                            photoUrl: getStringAsync(userPhotoUrl),
                                            uid: getStringAsync(userId),
                                            oneSignalPlayerId: getStringAsync(playerId),
                                          );
                                          return await Permissions.cameraAndMicrophonePermissionsGranted() ? CallFunctions.dial(context: context, from: sender, to: receiverData) : {};
                                        },
                                      ),
                                    ],
                                  )
                                : widget.isAddParticipant
                                    ? existingMembersList.contains(data.uid.toString())
                                        ? Icon(Icons.check_circle_outline)
                                        : Offstage()
                                    : Offstage()
                          ],
                        ),
                      ).onTap(() async {
                        if (widget.isGroupCreate) {
                          if (!selected.contains(data.uid.toString())) {
                            if (widget.isAddParticipant) {
                              log(existingMembersList);
                              if (existingMembersList.contains(data.uid.toString())) {
                                toast('lblAlreadyExist'.translate);
                              } else {
                                selected.add(data.uid.toString());
                                selectedMPlayersId.add(data.oneSignalPlayerId.toString());
                                selectedList.add(data);
                                mergedList.add(data);
                              }
                            } else {
                              selected.add(data.uid.toString());
                              selectedMPlayersId.add(data.oneSignalPlayerId.toString());
                              selectedList.add(data);
                              mergedList.add(data);

                              setState(() {});
                            }
                          } else {
                            print('dfgdfgdfgdfg');
                            selected.remove(data.uid.toString());
                            selectedMPlayersId.add(data.oneSignalPlayerId.toString());
                            selectedList.removeWhere((user) => user.uid == data.uid);
                            mergedList.remove(data);

                            setState(() {});
                          }
                          print("Selected LIst is ==> " + selectedList.toString());

                          // mergedList.removeWhere((user) => user.uid == data.uid);
                          // mergedList.addAll(selectedList);
                          // if (selectedList.isEmpty ) {
                          //   mergedList.clear();
                          // } else {
                          //   print("================== Selected List Is Not Empty");
                          //
                          //
                          // }
                          print("Merge LIst is ==>  2" + mergedList.toString());
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
                // if (widget.snap!.data!.isEmpty)

                buildGroupItemWidget(),

                // if (widget.snap!.data == null) noDataFound(text: 'no_user_found'.translate),
              ],
            ),
          ),

          ///FOR FORWARDED VIEW SEND ICON
          if (mergedList.isNotEmpty && widget.isFromForward || statusUpload == true)
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: Container(
                color: primaryColor,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Container(
                      child: HorizontalList(
                        reverse: mergedList.length > 5 ? true : false,
                        itemCount: mergedList.length,
                        itemBuilder: (_, i) {
                          var name;
                          if (mergedList[i] is Map<String, dynamic>) {
                            var map = mergedList[i] as Map<String, dynamic>;
                            if (map.containsKey('name')) {
                              name = map['name'].toString();
                            }
                          } else if (mergedList[i] is UserModel) {
                            name = (mergedList[i] as UserModel).name.toString();
                          }
                          return Stack(
                            clipBehavior: Clip.none,
                            alignment: Alignment.topRight,
                            children: [
                              Text(name.toString() + ",", style: secondaryTextStyle(color: Colors.white)).center().fit(),
                            ],
                          );
                        },
                      ),
                      width: 290,
                    ),
                    Container(
                      width: 50,
                      height: 50,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: secondaryColor, shape: BoxShape.circle,

                        // boxShadow: defaultBoxShadow(offset: Offset(-12, 0), shadowColor: secondaryColor.withValues(alpha:0.3))
                      ),
                      child: Icon(Icons.send, color: Colors.white, size: 22),
                    ).onTap(() async {
                      appStore.setLoading(true);
                      if (selectedList.isNotEmpty) {
                        await sendMessage(receiverId: selectedList.first.uid.toString());
                      }
                      if (selectedGroupList.isNotEmpty) {
                        await sendGroupMessage();
                      }

                      if (statusUpload == true) {
                        if (widget.chatData?.messageType == TEXT) {
                          await uploadStoryText();
                        } else {
                          await uploadStory(photoUrl: widget.chatData?.photoUrl ?? '');
                        }
                      }

                      hideKeyboard(context);
                      appStore.setLoading(false);
                      finish(context);
                      setState(() {});
                    }).paddingAll(10),
                  ],
                ),
              ).paddingOnly(top: 100),
            ),

          Observer(builder: (context) {
            return Positioned.fill(child: Container(color: Colors.transparent, child: Loader(valueColor: AlwaysStoppedAnimation<Color>(primaryColor)))).visible(appStore.isLoading);
          })
        ],
      ),
    );
  }
}
