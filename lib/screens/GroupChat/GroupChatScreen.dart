import 'dart:async';
import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:emoji_picker_flutter/emoji_picker_flutter.dart';
import 'package:ffmpeg_kit_flutter_new/ffmpeg_kit.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:path/path.dart' as path;
import 'package:geolocator/geolocator.dart';
import 'package:image_picker/image_picker.dart';
import 'package:nb_utils/nb_utils.dart';
import '../../utils/TextStyles.dart' as TS;
import 'package:paginate_firestore/paginate_firestore.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';

import 'package:chat/centralized_import.dart';

class GroupChatScreen extends StatefulWidget {
  final String groupChatId, groupName;

  final dynamic groupData;
  final bool? isArchive;

  GroupChatScreen({
    required this.groupName,
    required this.groupChatId,
    this.groupData,
    this.isArchive,
  });

  @override
  State<GroupChatScreen> createState() => _GroupChatScreenState();
}

class _GroupChatScreenState extends State<GroupChatScreen> {
  //final TextEditingController messageCont = TextEditingController();
  final messageCont = HiddenTextController();

  bool emojiShowing = false;
  bool emojiStickerShowing = false;
  bool isStrickerShows = false;
  bool isFirstMsg = false;
  bool _isTapped = false;

  // String? imageUrl;
  String? name = '';
  StreamSubscription? messageSubscription;
  List membersList = [];
  List<UserModel> userModelList = [];
  List<UserModel> userList = [];
  List<String> mList = [];
  List<String> mList2 = [];
  List<StickerModel> stickerList = [];
  String admin = '';
  bool mentionShowing = false;

  String? currentLat;
  String? currentLong;
  String sendMessageCached = "";

  bool showPlayer = false;
  String? audioPath;
  Map<String, bool> readBy = {};
  Map<String, String> reactionGroup = {};
  String? searchValue;
  String replyMessage = "";
  UserModel? userShareData;
  String replyMessageType = "";
  bool isReplyFrom = false;
  String messageId = "";
  String receiverUserName = "";
  String rSenderId = "";
  String replyLatitude = "";
  String replyLongitude = "";
  String? groupName, groupId, groupProfile;

  /// NEW
  List<GlobalKey> _keys = [];
  double? scrollUpPosition;
  double? scrollDownPosition;

  final ValueNotifier<bool> isCompressingNotifier = ValueNotifier(false);
  final ValueNotifier<double> progressNotifier = ValueNotifier(0.0);
  final ValueNotifier<String> currentFileNameNotifier = ValueNotifier('');
  double videoDurationMs = 0.0;
  final ValueNotifier<List<File>> compressedVideosNotifier =
      ValueNotifier<List<File>>([]);
  final ValueNotifier<int> currentVideoIndexNotifier = ValueNotifier<int>(0);
  List<File> compressedImages = [];
  List<String> compressedSizes = [];

  @override
  void initState() {
    super.initState();
    groupIdRedirection = null;
    groupNameRedirection = null;
    name = widget.groupName;
    print("INIT TIME GROUP CHAT ID IS " + widget.groupChatId.toString());
    print("INIT TIME GROUP NAME IS " + widget.groupName.toString());
    messageSubscription =
        groupChatMessageService.listenForMessageUpdates(widget.groupChatId);
    getGroupDetails();
    mSelectedImage = getStringAsync(SELECTED_WALLPAPER,
        defaultValue: appStore.isDarkMode
            ? mSelectedImageDark
            : "assets/default_wallpaper.png");
  }

  Future<void> pickAndSendDocuments() async {
    FilePickerResult? result = await FilePicker.platform.pickFiles(
      type: FileType.any,
      allowCompression: true,
      allowMultiple: true,
    );

    if (result != null) {
      List<File> docs = [];

      for (var file in result.files) {
        if (file.path != null) {
          File pickedFile = File(file.path ?? '');
          double fileSizeInMB = pickedFile.lengthSync() / (1024 * 1024);

          if (fileSizeInMB <= 8) {
            docs.add(pickedFile);
            sendGroupMessage(
                result: result, filepath: pickedFile, type: TYPE_DOC);
          } else {
            Fluttertoast.showToast(
              msg:
                  "${'lblFile'.translate} ${file.name} ${'8MBUpMsgDoc'.translate}",
              toastLength: Toast.LENGTH_LONG,
              gravity: ToastGravity.BOTTOM,
            );
          }
        }
      }

      finish(context);
    } else {
      // User canceled the picker
    }
  }

  Future<void> pickAndSendAudio() async {
    FilePickerResult? result = await FilePicker.platform.pickFiles(
      type: FileType.audio,
      allowCompression: false,
      allowMultiple: false,
    );

    if (result != null && result.files.single.path != null) {
      String inputPath = result.files.single.path!;
      File inputFile = File(inputPath);
      double originalSize = inputFile.lengthSync() / (1024 * 1024);

      final tempDir = await getTemporaryDirectory();
      String outputPath =
          '${tempDir.path}/${DateTime.now().millisecondsSinceEpoch}_compressed.mp3';

      await FFmpegKit.executeAsync(
          '-i "$inputPath" -acodec libmp3lame -b:a 64k -ac 1 -ar 44100 "$outputPath"',
          (session) async {
        File compressedFile = File(outputPath);
        double compressedSizeMB = compressedFile.lengthSync() / (1024 * 1024);

        print("Original: ${originalSize.toStringAsFixed(2)} MB");
        print("Compressed: ${compressedSizeMB.toStringAsFixed(2)} MB");

        if (compressedSizeMB <= 8) {
          sendGroupMessage(
              result: result, filepath: compressedFile, type: TYPE_AUDIO);
        } else {
          if (await compressedFile.exists()) await compressedFile.delete();
          Fluttertoast.showToast(
            msg:
                "${'lblFile'.translate} ${result.files.single.name} ${'8MBUpMsgDoc'.translate}",
            toastLength: Toast.LENGTH_LONG,
            gravity: ToastGravity.BOTTOM,
          );
        }

        finish(context);
      });
    }
  }

  Future<void> pickAndCompressImage() async {
    List<File> attachedFiles = [];
    FilePickerResult? result = await FilePicker.platform.pickFiles(
      type: FileType.image,
      allowMultiple: true,
    );

    if (result == null) return;

    compressedImages.clear();
    compressedSizes.clear();

    final tempDir = await getTemporaryDirectory();

    for (var file in result.files) {
      final inputPath = file.path ?? '';
      final fileName = path.basenameWithoutExtension(inputPath);
      final extension = path.extension(inputPath);
      final outputPath =
          path.join(tempDir.path, '${fileName}_compressed$extension');
      String cmd = "-i \"$inputPath\" "
          "-vf \"scale='if(gt(iw,ih),min(800,iw),-1)':'if(gt(iw,ih),-1,min(800,ih))'\" "
          "-c:v libwebp "
          "-quality 95 "
          "-compression_level 6 "
          "-method 6 "
          "-f webp "
          "\"$outputPath\"";
      await FFmpegKit.execute(cmd);

      var compressedFile = File(outputPath);
      if (await compressedFile.exists()) {
        double compressedSizeMB = compressedFile.lengthSync() / (1024 * 1024);
        if (compressedSizeMB <= 5) {
          attachedFiles.add(compressedFile);
        } else {
          Fluttertoast.showToast(
              msg: "${'image'.translate} ${file.name} ${'5MBUpMsg'.translate}");
        }
      }
    }
    if (attachedFiles.isNotEmpty) {
      Navigator.pop(context);
      List<String>? texts = await MultipleSelectedAttachmentText(
        attachedFiles: attachedFiles,
        userModel: null,
        isImage: true,
      ).launch(context);

      if (texts != null) {
        for (int i = 0; i < attachedFiles.length; i++) {
          print("Image: ${attachedFiles[i].path}, Text: ${texts[i]}");
          sendGroupMessage(
              result: result,
              filepath: attachedFiles[i],
              type: TYPE_Image,
              withText: texts[i]);
          //compressedFile?.deleteSync();
        }
      } else {
        // compressedFile?.deleteSync();
        Navigator.of(context).pop();
      }
    }
    setState(() {});
  }

  void updateValue(String value) async {
    searchValue = value;
    print("SEARCH VALUE IS " + searchValue.toString());
    setState(() {});
    return;
  }

  updateReplyStatus() async {
    print("Update use status start =====");

    print("UPdate Time Sender id ==> " + sender.uid.toString());
    print("UPdate Time Message id ==> " + messageId.toString());
    print("UPdate Time Group id ==> " + widget.groupChatId.toString());

    if (replyMessage.isNotEmpty) {
      print("Reply Message IN IF");
      groupChatMessageService.setReplyToTrueGroupChat(
          userId: sender.uid!,
          documentId: messageId,
          groupId: widget.groupChatId);
    } else {
      print(" Reply Message IN ELSE");
    }

    return;
  }

  nullUpdateReplyStatus() async {
    if (replyMessage.isNotEmpty) {
      groupChatMessageService.setReplyToTrueGroupChat(
          userId: sender.uid!, groupId: widget.groupChatId, documentId: null);
    } else {
      print("IN ELSE");
    }
    clearReplyMessage();
    return;
  }

  void _showPermissionPermanentlyDeniedDialog(String? Lbltitle) async {
    await showConfirmDialogCustom(context,
        dialogAnimation: DialogAnimation.SCALE,
        title: "${'lblPermissionText'.translate} ${Lbltitle}.",
        positiveText: 'lbl_yes'.translate,
        negativeText: 'lbl_no'.translate,
        primaryColor: primaryColor, onAccept: (v) async {
      Navigator.of(context).pop();
      openAppSettings();
    });
  }

  Future<bool> _checkAndRequestCameraPermission(String? title) async {
    PermissionStatus cameraStatus = await Permission.camera.status;

    if (cameraStatus.isGranted) {
      return true;
    }

    if (cameraStatus.isDenied) {
      final result = await Permission.camera.request();
      return result.isGranted;
    }

    if (cameraStatus.isPermanentlyDenied) {
      _showPermissionPermanentlyDeniedDialog(title);
      return false;
    }

    return false;
  }

  void clearReplyMessage() {
    replyMessage = "";
    receiverUserName = "";
    replyMessage = "";
    replyLatitude = "";
    replyLongitude = "";
    userShareData = null;
    setState(() {});
    print("Reply Message Cleared");
  }

  Future getGroupDetails() async {
    await groupChatMessageService.grpRef
        .doc(widget.groupChatId)
        .get()
        .then((chatMap) async {
      // imageUrl = chatMap['photoUrl'];
      membersList = chatMap['membersList'];
      getMemberList();
      name = chatMap['name'];
      admin = chatMap['adminId'];
      if (getStringAsync(userId) == admin) {
        if (chatMap['adminIds'] == null) {
          print("Group chat empty");
          await groupChatMessageService.grpRef
              .doc(getStringAsync(userId))
              .update({
            'adminIds': [getStringAsync(userId)],
          });
        }
      }

      setState(() {});
    });
  }

  getMemberList() {
    userModelList.clear();
    membersList.forEach((element) async {
      UserModel userm = await userService.getUserById(val: element);

      userModelList.add(userm);
      userList.add(userm);
      mList2.add(userm.uid.toString());
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

  void reactionBy(String? raction) {
    membersList.forEach((element) {
      if (element == getStringAsync(userId)) {
        reactionGroup[element] = raction ?? '';
      }
    });
  }

  void onSendMessageToGroup() {
    print("onSendMessageToGroup called");
    sendMessageCached = messageCont.text;
    messageCont.clear();
    addReadBy();
    ChatMessageModel chatMessageModel = ChatMessageModel();
    chatMessageModel.senderId = getStringAsync(userId);
    chatMessageModel.message = encryptData(sendMessageCached);
    chatMessageModel.isMessageRead = false;
    chatMessageModel.stickerPath = null;
    chatMessageModel.isEncrypt = true;
    chatMessageModel.createdAt = DateTime.now().millisecondsSinceEpoch;
    chatMessageModel.messageType = MessageType.TEXT.name;
    chatMessageModel.readBy = readBy;
    chatMessageModel.isFromReply = false;
    chatMessageModel.isFromForward = false;
    chatMessageModel.replyMessage = replyMessage;
    if (userShareData?.name?.isNotEmpty ?? false) {
      chatMessageModel.shareUser = userShareData;
    }
    chatMessageModel.groupName = groupName;
    chatMessageModel.groupProfile = groupProfile;
    chatMessageModel.groupId = groupId;

    chatMessageModel.replyMessageId = messageId;
    chatMessageModel.replyMessageType = replyMessageType;

    if (rSenderId != getStringAsync(userId)) {
      chatMessageModel.replyMessageSenderName = receiverUserName.toString();
    } else {
      chatMessageModel.replyMessageSenderName = loginStore.mDisplayName;
    }
    sendNormalGroupMessages(chatMessageModel, result: null);
    chatMessageService.updateLastMessage(
        senderId: sender.uid!,
        receiverId: "",
        text: encryptData(sendMessageCached),
        isRequest: false,
        isArchive: widget.isArchive ?? false,
        isGroupMessage: true,
        groupName: name.validate(),
        groupId: widget.groupChatId,
        groupParticipants: mList2,
        timestamp: FieldValue.serverTimestamp());
    isReplyFrom = false;
    clearReplyMessage();
  }

  void getLocation() async {
    Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high);

    currentLat = position.latitude.toString();
    currentLong = position.longitude.toString();

    sendGroupMessage(type: TYPE_LOCATION);
  }

  getSticker() {
    stickerService.getAllSticker().then((value) {
      stickerList = value;
      log(stickerList.length);
      setState(() {});
    });
  }

  void sendGroupMessage(
      {FilePickerResult? result,
      String? stickerPath,
      File? filepath,
      String? type,
      String? withText}) async {
    addReadBy();
    ChatMessageModel chatMessageModel = ChatMessageModel();
    MessageType selectedMessageType = MessageType.TEXT;
    chatMessageModel.senderId = sender.uid;
    if (withText.isEmptyOrNull) {
      chatMessageModel.message = messageCont.text.trim();
    } else {
      chatMessageModel.message = withText;
    }
    chatMessageModel.isMessageRead = false;
    chatMessageModel.stickerPath = stickerPath;
    chatMessageModel.isEncrypt = false;
    chatMessageModel.createdAt = DateTime.now().millisecondsSinceEpoch;
    chatMessageModel.readBy = readBy;
    if (filepath != null) {
      if (type == TYPE_Image) {
        chatMessageModel.messageType = MessageType.IMAGE.name;
        selectedMessageType = MessageType.IMAGE;
      } else if (type == TYPE_VIDEO) {
        chatMessageModel.messageType = MessageType.VIDEO.name;
        selectedMessageType = MessageType.VIDEO;
      } else if (type == TYPE_AUDIO) {
        chatMessageModel.messageType = MessageType.AUDIO.name;
        selectedMessageType = MessageType.AUDIO;
      } else if (type == TYPE_DOC) {
        chatMessageModel.messageType = MessageType.DOC.name;
        selectedMessageType = MessageType.DOC;
        String originalFileName = path.basename(filepath.path ?? '');
        String extension = path.extension(originalFileName);
        String nameWithoutExt = path.basenameWithoutExtension(originalFileName);
        String timestamp = DateTime.now().millisecondsSinceEpoch.toString();
        String newFileName = "${nameWithoutExt}_$timestamp$extension";
        chatMessageModel.documentName = newFileName;
      } else if (type == TYPE_VOICE_NOTE) {
        chatMessageModel.messageType = MessageType.VOICE_NOTE.name;
        selectedMessageType = MessageType.VOICE_NOTE;
      } else {
        chatMessageModel.messageType = MessageType.TEXT.name;
        messageCont.text = encryptData(messageCont.text);
        chatMessageModel.message = messageCont.text;
        chatMessageModel.isEncrypt = true;
      }
    } else if (stickerPath.validate().isNotEmpty) {
      chatMessageModel.messageType = MessageType.STICKER.name;
    } else {
      if (type == TYPE_LOCATION) {
        chatMessageModel.messageType = MessageType.LOCATION.name;
        selectedMessageType = MessageType.LOCATION;
        chatMessageModel.currentLat = currentLat;
        chatMessageModel.currentLong = currentLong;
      } else if (type == TYPE_Image) {
        chatMessageModel.messageType = MessageType.IMAGE.name;
        selectedMessageType = MessageType.IMAGE;
      } else if (type == TYPE_VOICE_NOTE) {
        chatMessageModel.messageType = MessageType.VOICE_NOTE.name;
        selectedMessageType = MessageType.VOICE_NOTE;
      } else {
        chatMessageModel.messageType = MessageType.TEXT.name;
        messageCont.text = encryptData(messageCont.text);
        chatMessageModel.message = messageCont.text;
        chatMessageModel.isEncrypt = true;
      }
    }

    sendNormalGroupMessages(chatMessageModel,
        type: type, result: result != null ? result : null, filepath: filepath);

    final previewText = sendMessageCached.trim().isNotEmpty
        ? sendMessageCached.trim()
        : chatMessageService.generateLastMessagePreview(selectedMessageType);

    chatMessageService.updateLastMessage(
        senderId: sender.uid!,
        receiverId: "",
        text: encryptData(previewText),
        isRequest: false,
        isGroupMessage: true,
        groupName: name.validate(),
        groupId: widget.groupChatId,
        groupParticipants: mList2,
        timestamp: FieldValue.serverTimestamp(),
        isArchive: widget.isArchive ?? false);
  }

  List<String> getAllTaggedUsernames(String text) {
    final regex = RegExp(r'@(\w+)');
    return regex.allMatches(text).map((match) => match.group(1)!).toList();
  }

  Future<String?> getUserIDFromUsername(String taggedUsername) async {
    try {
      // Split PascalCase username into separate words (e.g., "SamirRathod" -> "Samir Rathod")
      String originalName = splitPascalCase(taggedUsername);

      QuerySnapshot snapshot = await FirebaseFirestore.instance
          .collection(USER_COLLECTION)
          .where('name', isEqualTo: originalName)
          .limit(1)
          .get();

      if (snapshot.docs.isNotEmpty) {
        return snapshot.docs.first.id;
      }
      return null;
    } catch (e) {
      print('Error getting user ID from username: $e');
      return null;
    }
  }

  String splitPascalCase(String pascalCaseString) {
    String result = pascalCaseString.replaceAllMapped(
      RegExp(r'(?<!^)([A-Z])'),
      (Match m) => ' ${m[1]}',
    );

    return result;
  }

  Future<String?> getUserPlayerId({required String uid}) async {
    try {
      DocumentSnapshot snapshot = await FirebaseFirestore.instance
          .collection(USER_COLLECTION)
          .doc(uid)
          .get();

      if (snapshot.exists) {
        return (snapshot.data() as Map<String, dynamic>)['oneSignalPlayerId']
            as String?;
      }
      return null;
    } catch (e) {
      print('Error getting player ID: $e');
      return null;
    }
  }

  void sendNormalGroupMessages(ChatMessageModel data,
      {String? type, FilePickerResult? result, File? filepath}) async {
    userList.clear();

    String? msgValue = sendMessageCached.trim();
    ContactModel contactModel = ContactModel();
    contactModel.uid = widget.groupChatId;
    contactModel.addedOn = Timestamp.now();
    contactModel.lastMessageTime = DateTime.now().millisecondsSinceEpoch;
    contactModel.groupRefUrl = widget.groupChatId;

    // Extract tagged usernames from the message
    List<String> taggedUsernames =
        getAllTaggedUsernames(decryptedData(data.message!));
    print("Tagged Users: $taggedUsernames");

    String? message = '';
    if (type == TYPE_Image) {
      message = getStringAsync(userDisplayName) +
          " Sent you " +
          MessageType.IMAGE.name.capitalizeFirstLetter();
    } else if (type == TYPE_VIDEO) {
      message = getStringAsync(userDisplayName) +
          " sent you " +
          MessageType.VIDEO.name.capitalizeFirstLetter();
    } else if (type == TYPE_AUDIO) {
      message = getStringAsync(userDisplayName) +
          " Sent you " +
          MessageType.AUDIO.name.capitalizeFirstLetter();
    } else if (type == TYPE_DOC) {
      message = getStringAsync(userDisplayName) +
          " Sent you " +
          MessageType.DOC.name.capitalizeFirstLetter();
    } else if (type == TYPE_VOICE_NOTE) {
      message = getStringAsync(userDisplayName) +
          " Sent you " +
          MessageType.VOICE_NOTE.name.capitalizeFirstLetter();
    } else if (type == TYPE_LOCATION) {
      message = getStringAsync(userDisplayName) +
          " Sent you " +
          MessageType.LOCATION.name.capitalizeFirstLetter();
    } else if (type == TYPE_STICKER) {
      message = getStringAsync(userDisplayName) +
          " Sent you " +
          MessageType.STICKER.name.capitalizeFirstLetter();
    } else {
      message = getStringAsync(userDisplayName) + " Sent you a message";
    }

    List<String> targetPlayerIds = [];

    if (taggedUsernames.isNotEmpty) {
      for (String username in taggedUsernames) {
        String? userId = await getUserIDFromUsername(username);
        if (userId != null) {
          String? playerId = await getUserPlayerId(uid: userId);
          if (playerId != null && playerId.isNotEmpty) {
            targetPlayerIds.add(playerId);
          }
        }
      }
    } else {
      targetPlayerIds = mList;
    }

    targetPlayerIds = targetPlayerIds.toSet().toList();
    targetPlayerIds.removeWhere((id) => id == getStringAsync(playerId));

    print("Targeted ids => ${targetPlayerIds}");

    await notificationService
        .sendPushNotifications(name.validate() + " ", message,
            isGrp: true,
            recevierUid: widget.groupChatId,
            mPlayerIds: targetPlayerIds.isNotEmpty ? targetPlayerIds : null)
        .catchError((e) {
      log('error' + e.toString());
    }).then((value) async {
      // Rest of your existing code for updating contact timestamps...
      await chatMessageService
          .getContactsDocument(
              of: getStringAsync(userId), forContact: widget.groupChatId)
          .update(<String, dynamic>{
        "lastMessageTime": DateTime.now().millisecondsSinceEpoch,
      }).catchError((e) {
        log(e);
      }).then((value) {
        userModelList.forEach((element) async {
          log(element.oneSignalPlayerId);
          await chatMessageService
              .getContactsDocument(
                  of: element.uid.validate(), forContact: widget.groupChatId)
              .update(<String, dynamic>{
            "lastMessageTime": DateTime.now().millisecondsSinceEpoch,
          });
        });
      });
    });

    // Rest of your existing function remains the same...
    setState(() {});

    groupChatMessageService.addIsEncrypt(data);

    await groupChatMessageService
        .addMessage(data, widget.groupChatId)
        .then((value) async {
      if (result != null) {
        FileModel fileModel = FileModel();
        result.files.forEach((data) {
          fileModel.id = value.id;
          fileModel.file = File(data.path ?? '');
          fileList.add(fileModel);
        });

        setState(() {});

        await groupChatMessageService
            .addMessageToDb(
                senderDoc: value,
                data: data,
                image: !(filepath?.path.isEmptyOrNull ?? false)
                    ? File(filepath?.path ?? '')
                    : null,
                isRequest: false)
            .then((value) {});
      }
      if (filepath != null && result == null) {
        FileModel fileModel = FileModel();
        fileModel.id = value.id;
        fileModel.file = File(filepath.path ?? '');
        fileList.add(fileModel);

        setState(() {});

        await groupChatMessageService
            .addMessageToDb(
                senderDoc: value,
                data: data,
                image: !(filepath.path.isEmptyOrNull ?? false)
                    ? File(filepath.path ?? '')
                    : null,
                isRequest: false)
            .then((value) {});
      }
    }).catchError((e) {
      log("message send:$e");
    });
  }

  _showAttachmentDialog() {
    return showDialog(
      barrierColor: Colors.transparent,
      context: context,
      builder: (context) {
        return Align(
          alignment: Alignment.bottomCenter,
          child: Container(
            padding: EdgeInsets.only(top: 16, bottom: 16, left: 12, right: 12),
            margin: EdgeInsets.only(bottom: 78, left: 12, right: 12),
            decoration: BoxDecoration(
              color: context.scaffoldBackgroundColor,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Material(
              color: context.scaffoldBackgroundColor,
              child: Wrap(
                spacing: 16,
                runSpacing: 16,
                children: [
                  iconsBackgroundWidget(context,
                          name: "camera".translate,
                          image: ic_camera,
                          color: Colors.purple.shade400)
                      .onTap(() async {
                    final cameraPermission =
                        await _checkAndRequestCameraPermission(
                            'camera'.translate);
                    if (!cameraPermission) {
                      _showPermissionPermanentlyDeniedDialog(
                          'camera'.translate);
                      return;
                    }
                    var result = await ImagePicker().pickImage(
                        source: ImageSource.camera, imageQuality: 50);
                    if (result != null) {
                      List<File> image = [];
                      image.add(File(result.path.validate()));
                      // finish(context);
                      List<String>? texts =
                          await MultipleSelectedAttachmentText(
                        attachedFiles: image,
                        userModel: null,
                        isImage: true,
                      ).launch(context);

                      if (texts != null) {
                        for (int i = 0; i < image.length; i++) {
                          finish(context);
                          sendGroupMessage(
                              result: null,
                              filepath: image[i],
                              type: TYPE_Image,
                              withText: texts[i]);
                        }
                      } else {
                        Navigator.of(context).pop();
                      }
                    } else {
                      // User canceled the picker
                    }
                  }),
                  iconsBackgroundWidget(context,
                          name: 'lblGallery'.translate,
                          image: ic_wallpaper,
                          color: Colors.purple.shade400)
                      .onTap(() async {
                    pickAndCompressImage();
                  }),
                  iconsBackgroundWidget(context,
                          name: 'lblVideo'.translate,
                          image: ic_video_call,
                          color: Colors.pink[400])
                      .onTap(() async {
                    pickAndSendVideos(null, context, (file, text) {
                      sendGroupMessage(
                          filepath: file, type: TYPE_VIDEO, withText: text);
                    });
                  }),
                  iconsBackgroundWidget(context,
                          name: 'lblAudio'.translate,
                          image: ic_audio,
                          color: Colors.blue[700])
                      .onTap(() async {
                    pickAndSendAudio();
                  }),
                  iconsBackgroundWidget(context,
                          name: 'lblDocument'.translate,
                          image: ic_term_condition,
                          color: Colors.blue[700])
                      .onTap(() async {
                    pickAndSendDocuments();
                  }),
                  iconsBackgroundWidget(context,
                          name: 'lblLocation'.translate,
                          image: ic_location,
                          color: Colors.green.shade500)
                      .onTap(
                    () async {
                      determinePosition();

                      showConfirmDialogCustom(
                        context,
                        dialogAnimation: DialogAnimation.SCALE,
                        positiveText: 'lbl_yes'.translate,
                        negativeText: 'lbl_no'.translate,
                        title:
                            'are_you_sure_you_want_to_share_your_current_location'
                                .translate,
                        primaryColor: primaryColor,
                        onAccept: (v) async {
                          bool? isEnable = await checkPermission();

                          log(isEnable);
                          if (isEnable == true) {
                            getLocation();
                            finish(context);
                          } else {
                            toast('lblPleaseEnableLocation'.translate);
                          }
                        },
                      );
                    },
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Future<void> handleOnTap() async {
    bool res = await GroupInfoScreen(
            groupName: name.validate(),
            groupId: widget.groupChatId,
            data: widget.groupData)
        .launch(context,
            pageRouteAnimation: PageRouteAnimation.Scale,
            duration: 300.milliseconds);
    print(res.toString());
    if (res == true) {
      getGroupDetails();
      setState(() {});
    }
  }

  ///For Highlighting and scroll with index Search Filter
  void _animateToIndex(int index) {
    // Ensure the index is within bounds
    if (index < 0 || index >= _keys.length) return;
    // Get the position of the item
    final keyContext = _keys[index].currentContext;
    if (keyContext != null) {
      // Scroll to the position of the item
      Scrollable.ensureVisible(
        keyContext,
        duration: Duration(seconds: 2),
        curve: Curves.fastOutSlowIn,
      );
    }
  }

  @override
  void dispose() {
    setValue(CURRENT_GROUP_ID, '');
    try {
      messageSubscription?.cancel();
    } catch (e) {}
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    print("-------577>>${widget.groupData}");
    return Scaffold(
      appBar: PreferredSize(
        preferredSize: Size(context.width(), kToolbarHeight),
        child: ChatAppBarWidget(
          isAdminAV: null,
          receiverUser: null,
          isFromRequest: null,
          onSearchValueChanged: updateValue,
          onUpCall: (position) => _animateToIndex(position.toInt()),
          onDownCall: (position) => _animateToIndex(position.toInt()),
          isFromArchive: widget.isArchive,
          scrollUpPosition: scrollUpPosition,
          scrollDownPosition: scrollDownPosition,
          isFromGroupChat: true,
          widget.groupChatId,
          imageUrl:
              widget.groupData != null ? widget.groupData['photoUrl'] : '',
          widget.groupName,
          widget.groupData,
        ),
      ),
      body: SafeArea(
        child: Stack(
          fit: StackFit.expand,
          children: [
            backgroundImage(),
            FutureBuilder(
              future: groupChatMessageService.getGroupDetails(
                  groupDocId: widget.groupChatId,
                  currentUserId: getStringAsync(userId)),
              builder: (context, snap1) {
                var ffg = snap1.data;
                if (snap1.hasData) {
                  return Stack(
                    children: [
                      Align(
                        alignment: Alignment.bottomCenter,
                        child: PaginateFirestore(
                          reverse: true,
                          isLive: true,
                          padding: EdgeInsets.only(
                              left: 8, top: 8, right: 8, bottom: 0),
                          physics: BouncingScrollPhysics(),
                          query: groupChatMessageService
                              .chatMessagesWithPagination(
                                  currentUserId: getStringAsync(userId),
                                  groupDocId: widget.groupChatId,
                                  user_clear_chat_time: snap1.data),
                          itemsPerPage: PER_PAGE_CHAT_COUNT,
                          shrinkWrap: true,
                          onLoaded: (page) {
                            isFirstMsg = page.documentSnapshots.isEmpty;
                          },
                          onEmpty: SizedBox(),
                          itemBuilderType: PaginateBuilderType.listView,
                          itemBuilder: (context, snap, index) {
                            ChatMessageModel data = ChatMessageModel.fromJson(
                                snap[index].data() as Map<String, dynamic>);

                            data.isMe = data.senderId == getStringAsync(userId);
                            if (data.isMe == true) {}
                            return ChatItemWidget(
                              groupId: widget.groupChatId,
                              data: data,
                              isGroup: true,
                              onArrowSearch: (p0,
                                  replyMsg,
                                  replyMsgType,
                                  isChatFrom,
                                  mID,
                                  rName,
                                  senderID,
                                  rLatitude,
                                  rLongitude,
                                  userShareDatas,
                                  groupNames,
                                  groupIds,
                                  groupProfiles) {
                                if (replyMsg != null && replyMsg.isNotEmpty) {
                                  replyMessage = replyMsg;
                                  if (replyMsgType != null &&
                                      replyMsgType.isNotEmpty) {
                                    replyMessageType = replyMsgType;
                                    userShareData = userShareDatas;
                                    groupName = groupNames;
                                    groupId = groupIds;
                                    groupProfile = groupProfiles;
                                  }
                                }
                                if (rLatitude != null &&
                                    rLatitude.isNotEmpty &&
                                    rLongitude != null &&
                                    rLongitude.isNotEmpty) {
                                  replyLatitude = rLatitude;
                                  replyLongitude = rLongitude;
                                  setState(() {});
                                }
                                isReplyFrom = isChatFrom!;
                                messageId = mID!;
                                receiverUserName = rName!;
                                rSenderId = senderID!;
                                print(
                                    "SENDER ID IS ==>" + rSenderId.toString());
                                print("RECEIVER USER NAME IS ==>" +
                                    receiverUserName.toString());

                                updateReplyStatus();
                                setState(() {});
                              },
                              onSearchValueChanged: searchValue,
                              messageId: messageId,
                              // receiverName: userm,
                            );
                          },
                        ).paddingBottom(emojiStickerShowing ? 320 : 75),
                      ),
                      getRequestedWidget(),
                    ],
                  );
                }
                return SizedBox();
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget getRequestedWidget() {
    return Positioned(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          Stack(
            alignment: Alignment.bottomLeft,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (replyMessage.isNotEmpty && isReplyFrom)
                    Container(
                      child: Container(
                        decoration: boxDecorationWithRoundedCorners(
                          backgroundColor: appStore.isDarkMode
                              ? Colors.transparent.withOpacity(0.2)
                              : Colors.transparent.withOpacity(0.1),
                        ),
                        child: Column(
                          children: [
                            Row(
                              children: [
                                Column(
                                  children: [
                                    Text(
                                      isReplyFrom &&
                                              rSenderId !=
                                                  getStringAsync(userId)
                                          ? receiverUserName.toString()
                                          : 'you'.translate,
                                      style: TS.primaryTextStyle(
                                          color: primaryColor,
                                          weight: FontWeight.bold,
                                          size: 12),
                                    ),
                                    if (replyMessageType != TEXT &&
                                        replyMessageType != SHAREPROFILE)
                                      Row(
                                        children: [
                                          getIconForMessageType(
                                              replyMessageType),
                                          Text(
                                            ' ${replyMessageType.capitalizeEachWord().toString()} ',
                                            style: TS.secondaryTextStyle(),
                                          ),
                                        ],
                                      ),
                                    if (replyMessageType == TEXT)
                                      Row(
                                        children: [
                                          RichText(
                                            text: buildMessageLastMsg(
                                                decryptedData(
                                                    replyMessage.toString() ??
                                                        '')),
                                          ).expand(),
                                        ],
                                      ),
                                    if (replyMessageType == SHAREPROFILE)
                                      Padding(
                                        padding: const EdgeInsets.symmetric(
                                            vertical: 2),
                                        child: Row(
                                          children: [
                                            cachedImage(
                                                    !groupProfile.isEmptyOrNull
                                                        ? groupProfile ?? ''
                                                        : userShareData
                                                            ?.photoUrl
                                                            .validate(),
                                                    height: 35,
                                                    width: 35,
                                                    fit: BoxFit.cover)
                                                .cornerRadiusWithClipRRect(50),
                                            5.width,
                                            Text(
                                              !groupName.isEmptyOrNull
                                                  ? groupName ?? ''
                                                  : userShareData?.name ?? '',
                                              style: TS.secondaryTextStyle(),
                                            ).expand(),
                                          ],
                                        ),
                                      ),
                                  ],
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                ).expand(),
                                Stack(
                                  alignment: Alignment.topRight,
                                  children: [
                                    getViewForMessageType(
                                      replyMessageType,
                                      replyMessage,
                                    ).cornerRadiusWithClipRRectOnly(
                                        topRight: 8, bottomRight: 8),
                                    Container(
                                      decoration:
                                          boxDecorationWithRoundedCorners(),
                                      child: Icon(
                                        Icons.close,
                                        color: appStore.isDarkMode
                                            ? grey
                                            : black.withOpacity(0.4),
                                        size: 16,
                                      ).onTap(() {
                                        isReplyFrom = false;
                                        nullUpdateReplyStatus();
                                        setState(() {});
                                      }),
                                    ),
                                  ],
                                ),
                              ],
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              crossAxisAlignment: CrossAxisAlignment.start,
                            ),
                          ],
                        ).paddingOnly(
                          left: 8,
                          right: 4,
                        ),
                      ).paddingOnly(top: 8, left: 8, right: 4),
                      width: 288,
                      decoration: boxDecorationWithRoundedCorners(
                          backgroundColor: context.cardColor,
                          borderRadius: !isReplyFrom
                              ? BorderRadius.circular(20)
                              : BorderRadius.only(
                                  topLeft: Radius.circular(14),
                                  topRight: Radius.circular(14))),
                    ).paddingOnly(left: 8, right: 8),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Container(
                        decoration: boxDecorationWithShadow(
                            borderRadius: !isReplyFrom
                                ? BorderRadius.circular(20)
                                : BorderRadius.only(
                                    bottomLeft: Radius.circular(20),
                                    bottomRight: Radius.circular(20)),
                            spreadRadius: 0,
                            blurRadius: 0,
                            backgroundColor: context.cardColor),
                        padding: EdgeInsets.only(left: 0, right: 8),
                        child: Column(
                          children: [
                            AnimatedSize(
                              duration: Duration(milliseconds: 300),
                              curve: Curves.easeInOut,
                              child: mentionShowing
                                  ? Container(
                                      height: 200,
                                      decoration: boxDecorationWithShadow(
                                        borderRadius: BorderRadius.circular(20),
                                        spreadRadius: 0,
                                        blurRadius: 0,
                                        backgroundColor: context.cardColor,
                                      ),
                                      child: ListView.builder(
                                        physics: ScrollPhysics(),
                                        itemCount: userList.length,
                                        shrinkWrap: true,
                                        itemBuilder: (context, index) {
                                          UserModel data = userList[index];

                                          if (data.uid == loginStore.mId) {
                                            return 0.height;
                                          }
                                          return Column(
                                            children: [
                                              Container(
                                                padding: EdgeInsets.symmetric(
                                                    vertical: 8,
                                                    horizontal: 16),
                                                child: Row(
                                                  children: [
                                                    (data.photoUrl
                                                            .isEmptyOrNull)
                                                        ? Hero(
                                                            tag: data.uid
                                                                .validate(),
                                                            child: Container(
                                                              height: 40,
                                                              width: 40,
                                                              padding:
                                                                  EdgeInsets
                                                                      .all(10),
                                                              color: getColorFromString(
                                                                  data.uid ??
                                                                      data.name
                                                                          .validate()),
                                                              child: Text(
                                                                      data.name
                                                                          .validate()[
                                                                              0]
                                                                          .toUpperCase(),
                                                                      style: TS.secondaryTextStyle(
                                                                          color:
                                                                              Colors.white))
                                                                  .center()
                                                                  .fit(),
                                                            ).cornerRadiusWithClipRRect(
                                                                50),
                                                          )
                                                        : cachedImage(
                                                                data.photoUrl
                                                                    .validate(),
                                                                width: 40,
                                                                height: 40,
                                                                fit: BoxFit
                                                                    .cover)
                                                            .cornerRadiusWithClipRRect(
                                                                80),
                                                    12.width,
                                                    Text('${data.name.validate().capitalizeFirstLetter()}',
                                                            style: TS
                                                                .primaryTextStyle())
                                                        .expand(),
                                                  ],
                                                ),
                                              ).onTap(() async {
                                                print(
                                                    "---------1416>>${data.name?.trim()}");
                                                messageCont.text +=
                                                    '${data.name?.trim().replaceAll(' ', '')} ----userId>${data.uid}<userId----';
                                                mentionShowing = false;
                                                setState(() {});
                                              }),
                                              if (index != userList.length - 1)
                                                Divider(
                                                  color: Colors.grey
                                                      .withValues(alpha: 0.3),
                                                  thickness: 1,
                                                  height: 1,
                                                ),
                                            ],
                                          );
                                        },
                                      ),
                                    )
                                  : SizedBox.shrink(),
                            ),
                            Row(
                              children: [
                                IconButton(
                                  icon: Icon(
                                      LineIcons.smiling_face_with_heart_eyes),
                                  iconSize: 24.0,
                                  padding: EdgeInsets.all(2),
                                  color: Colors.grey,
                                  onPressed: () {
                                    hideKeyboard(context);
                                    emojiStickerShowing = !emojiStickerShowing;
                                    emojiShowing = true;
                                    setState(() {});
                                  },
                                ),
                                AppTextField(
                                  controller: messageCont,
                                  textFieldType: TextFieldType.OTHER,
                                  textStyle: TS.primaryTextStyle(),
                                  cursorColor: appStore.isDarkMode
                                      ? Colors.white
                                      : Colors.black,
                                  textCapitalization:
                                      TextCapitalization.sentences,
                                  keyboardType: TextInputType.multiline,
                                  inputFormatters: [HiddenIdFormatter()],
                                  minLines: 1,
                                  maxLines: 5,
                                  onTap: () {
                                    emojiStickerShowing = false;
                                    setState(() {});
                                  },
                                  textInputAction: mIsEnterKey
                                      ? TextInputAction.send
                                      : TextInputAction.newline,
                                  onFieldSubmitted: (p0) {
                                    onSendMessageToGroup();
                                  },
                                  onChanged: (s) {
                                    emojiStickerShowing = false;
                                    if (s.contains('@')) {
                                      String query = s
                                          .split('@')
                                          .last
                                          .trim()
                                          .toLowerCase();
                                      bool hasMatch = userList.any((user) =>
                                          user.name
                                              .validate()
                                              .toLowerCase()
                                              .startsWith(query));

                                      mentionShowing = hasMatch;
                                    } else {
                                      mentionShowing = false;
                                    }
                                    setState(() {});
                                  },
                                  decoration: InputDecoration(
                                    border: InputBorder.none,
                                    hintText: 'lblMessage'.translate,
                                    hintStyle: TS.secondaryTextStyle(),
                                    isDense: true,
                                  ),
                                ).expand(),
                                IconButton(
                                  visualDensity:
                                      VisualDensity(horizontal: 0, vertical: 1),
                                  icon: Icon(Icons.attach_file),
                                  iconSize: 25.0,
                                  padding: EdgeInsets.all(2),
                                  color: Colors.grey,
                                  onPressed: () {
                                    _showAttachmentDialog();
                                    hideKeyboard(context);
                                    emojiStickerShowing = false;
                                  },
                                ),
                              ],
                            ),
                          ],
                        ),
                        width: context.width(),
                      ).expand(),
                      8.width,
                      if (messageCont.text.isNotEmpty || emojiStickerShowing)
                        GestureDetector(
                          onTap: () {
                            if (_isTapped == true) {
                              return;
                            }
                            _isTapped = true;
                            Future.delayed(
                              Duration(seconds: 2),
                              () {
                                _isTapped = false;
                              },
                            );
                            onSendMessageToGroup();
                          },
                          child: Container(
                            width: 50,
                            height: 50,
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                                color: primaryColor, shape: BoxShape.circle),
                            child:
                                Icon(Icons.send, color: Colors.white, size: 22),
                          ),
                        ),
                      if (messageCont.text.isEmpty && !emojiStickerShowing)
                        SizedBox(width: 48)
                    ],
                  ).paddingOnly(bottom: 8, left: 8, right: 8),
                ],
              ),
              if (messageCont.text.isEmpty && !emojiStickerShowing)
                AudioRecorder(
                  onStop: (path) {
                    setState(() {
                      audioPath = path;
                    });
                    sendGroupMessage(
                        result: null,
                        filepath: File(path),
                        type: TYPE_VOICE_NOTE);
                  },
                ).paddingOnly(bottom: 8, left: 8, right: 8),
            ],
          ),
          if (emojiStickerShowing) showEmojiBottomsheet(),
        ],
      ),
    );
  }

  showEmojiBottomsheet() {
    return Stack(
      alignment: Alignment.bottomCenter,
      children: [
        Container(
          child: emojiShowing == true
              ? ConstrainedBox(
                  constraints: BoxConstraints(maxHeight: 500),
                  child: Stack(
                    alignment: Alignment.bottomCenter,
                    children: [
                      SizedBox(
                        height: 255,
                        child: EmojiPicker(
                          onEmojiSelected: (Category? category, Emoji emoji) {
                            messageCont.text = messageCont.text + emoji.emoji;
                            //  setState(() {});
                          },
                          config: Config(
                            checkPlatformCompatibility: true,
                            emojiViewConfig: EmojiViewConfig(
                              columns: 8,
                              emojiSizeMax: 32 * (Platform.isIOS ? 1.30 : 1.0),
                              verticalSpacing: 0,
                              horizontalSpacing: 0,
                              gridPadding: EdgeInsets.only(bottom: 50),
                              recentsLimit: 28,
                              replaceEmojiOnLimitExceed: false,
                              noRecents: Text('no_recent'.translate,
                                  style:
                                      TS.boldTextStyle(color: Colors.black26),
                                  textAlign: TextAlign.center),
                              buttonMode: ButtonMode.MATERIAL,
                            ),
                            skinToneConfig: SkinToneConfig(
                                indicatorColor: Colors.grey,
                                enabled: true,
                                dialogBackgroundColor: context.cardColor),
                            categoryViewConfig: const CategoryViewConfig(
                              categoryIcons: CategoryIcons(),
                              tabIndicatorAnimDuration: kTabScrollDuration,
                              recentTabBehavior: RecentTabBehavior.RECENT,
                              backspaceColor: primaryColor,
                              indicatorColor: primaryColor,
                              initCategory: Category.RECENT,
                              iconColorSelected: primaryColor,
                              iconColor: Colors.grey,
                            ),
                            searchViewConfig: SearchViewConfig(),
                            bottomActionBarConfig: BottomActionBarConfig(
                                enabled: true,
                                backgroundColor: context.cardColor,
                                showSearchViewButton: false),
                          ),
                        ),
                      ),
                    ],
                  ),
                )
              : isStrickerShows == true
                  ? Container(
                      height: 255,
                      width: context.width(),
                      color: context.cardColor,
                      constraints: BoxConstraints(maxHeight: 500),
                      child: GridView.count(
                          padding: EdgeInsets.only(top: 8, bottom: 50),
                          crossAxisCount: 4,
                          crossAxisSpacing: 4.0,
                          mainAxisSpacing: 8.0,
                          children: stickerList.map((e) {
                            return Stack(
                              children: [
                                Container(
                                    height: 100,
                                    width: 100,
                                    child: Loader().center()),
                                cachedImage(e.stickerPath.validate(),
                                        height: 100,
                                        width: 100,
                                        fit: BoxFit.cover)
                                    .onTap(() {
                                  hideKeyboard(context);
                                  sendGroupMessage(
                                      stickerPath: e.stickerPath,
                                      type: TYPE_STICKER);
                                }),
                              ],
                            );
                          }).toList()),
                    )
                  : SizedBox(),
        ),
        Container(
          height: 40,
          alignment: Alignment.center,
          width: context.width(),
          color: context.cardColor,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              IconButton(
                onPressed: () {
                  emojiShowing = true;
                  isStrickerShows = false;
                  setState(() {});
                },
                icon: Icon(Icons.emoji_emotions_outlined,
                    size: 28,
                    color: emojiShowing
                        ? primaryColor
                        : textSecondaryColorGlobal.withOpacity(0.7)),
              ),
              IconButton(
                onPressed: () {
                  isStrickerShows = true;
                  getSticker();
                  emojiShowing = false;
                  setState(() {});
                },
                icon: Icon(Icons.face,
                    size: 28,
                    color: isStrickerShows
                        ? primaryColor
                        : textSecondaryColorGlobal.withOpacity(0.7)),
              ),
            ],
          ),
        )
      ],
    );
  }
}
