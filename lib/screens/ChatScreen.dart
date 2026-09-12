import 'dart:async';
import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:emoji_picker_flutter/emoji_picker_flutter.dart';
import 'package:ffmpeg_kit_flutter_new/ffmpeg_kit.dart';
import 'package:ffmpeg_kit_flutter_new/ffmpeg_kit_config.dart';
import 'package:path/path.dart' as path;
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:image_picker/image_picker.dart';
import 'package:nb_utils/nb_utils.dart';
import 'package:onesignal_flutter/onesignal_flutter.dart';
import 'package:paginate_firestore/paginate_firestore.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:chat/centralized_import.dart';

import '../../utils/TextStyles.dart' as TS;

class ChatScreen extends StatefulWidget {
  final UserModel? receiverUser;
  final bool isFromRequest;
  bool? isAdmin = false;
  final Function(String)? onUpdate;
  final bool? isArchive;

  ChatScreen(this.receiverUser,
      {this.isFromRequest = false,
      this.onUpdate,
      this.isArchive,
      this.isAdmin});

  @override
  ChatScreenState createState() => ChatScreenState();
}

class ChatScreenState extends State<ChatScreen>
    with WidgetsBindingObserver, AutomaticKeepAliveClientMixin {
  late ChatMessageService chatMessageService;
  InterstitialAd? myInterstitial;
  TextEditingController messageCont = TextEditingController();
  FocusNode messageFocus = FocusNode();

  List<StickerModel> stickerList = [];

  bool emojiShowing = false;
  bool emojiStickerShowing = false;

  bool isStickerShows = false;
  bool isFirstMsg = false;
  bool isBlocked = false;
  bool showPlayer = false;
  Future<bool>? requestData;
  String id = '';
  String? currentLat;
  String? currentLong;
  String? audioPath;
  String? currentlyUploadedAudioPath;
  String? searchValue;
  String replyMessage = "";
  String replyMessageType = "";
  String sendMessageCached = "";
  bool isReplyFrom = false;
  String messageId = "";
  String replyLatitude = "";
  String replyLongitude = "";

  // ScrollController _scrollController = ScrollController();

  /// HighLighted
  int highlightStartIndex = 0;
  double? oldScrollUpPosition;
  double? oldScrollDownPosition;
  double? scrollUpPosition;
  double? scrollDownPosition;
  String? messageText;
  UserModel? userShareData;
  String? senderIdPassble;
  String? groupName, groupId, groupProfile;
  String receiverUserName = "";
  List<ChatMessageModel> newList = [];
  ScrollController _scrollController = ScrollController();

  List<GlobalKey> _keys = [];
  List<ChatMessageModel> chatMessages = [];

  List<ChatMessageModel> chats = [];
  ChatMessageModel? chatModelNewData;
  StreamSubscription? messageSubscription;
  bool _isSending = false;
  XFile? pickedFile;
  Timer? _typingTimer;
  bool _isTyping = false;
  bool userExist = false;
  File? imageFile;

  UserModel? chatMessageToReceiver;

  final ValueNotifier<bool> isCompressingNotifier = ValueNotifier(false);
  final ValueNotifier<double> progressNotifier = ValueNotifier(0.0);
  final ValueNotifier<String> currentFileNameNotifier = ValueNotifier('');
  double videoDurationMs = 0.0;
  final ValueNotifier<List<File>> compressedVideosNotifier =
      ValueNotifier<List<File>>([]);
  final ValueNotifier<int> currentVideoIndexNotifier = ValueNotifier<int>(0);

  List<File> compressedImages = [];
  List<String> compressedSizes = [];
  bool requestAccepted = false;

  @override
  bool get wantKeepAlive => true;

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
          "-preset photo "
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
        userModel: widget.receiverUser,
        isImage: true,
      ).launch(context);

      if (texts != null) {
        for (int i = 0; i < attachedFiles.length; i++) {
          print("Image: ${attachedFiles[i].path}, Text: ${texts[i]}");
          sendMessage(
              filepath: attachedFiles[i], type: TYPE_Image, withText: texts[i]);
          //compressedFile?.deleteSync();
        }
      } else {
        // compressedFile?.deleteSync();
        Navigator.of(context).pop();
      }
    }
    setState(() {});
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
            sendMessage(result: result, filepath: pickedFile, type: TYPE_DOC);
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
          sendMessage(
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

  Future<void> checkUserRequest() async {
    bool isPending = await chatMessageService.hasPendingRequestFromUser(
      currentUserId: getStringAsync(userId),
      otherUserId: widget.receiverUser!.uid.toString(),
    );
    if (isPending) {
      setState(() {
        requestAccepted = false;
      });
    } else {
      setState(() {
        requestAccepted = true;
      });
    }
  }

  void _showPermissionPermanentlyDeniedDialog(String? Lbltitle) async {
    await showConfirmDialogCustom(context,
        dialogAnimation: DialogAnimation.SCALE,
        title: "${'lbl_permission_denied'.translate} ${Lbltitle}.",
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

  @override
  void initState() {
    super.initState();
    chatMessageService = ChatMessageService();
    Future.delayed(Duration.zero).then((val) {
      init();
    });
    checkUserRequest();
    getReceiverById();
  }

  ///
  // Get receiver by id
  Future<void> getReceiverById() async {
    final receiver =
        await chatMessageService.getUserById(uid: widget.receiverUser!.uid!);
    if (mounted) {
      setState(() {
        chatMessageToReceiver = receiver;
      });
    }
  }

  init() async {
    WidgetsBinding.instance.addObserver(this);
    OneSignal.User.pushSubscription.optIn();
    id = getStringAsync(userId);
    getValues();
    if (mAdShowCount < 5) {
      mAdShowCount++;
    } else {
      mAdShowCount = 0;
      buildInterstitialAd();
    }

    setState(() {});
  }

  getValues() async {
    print("Get values Called----------------");
    mIsEnterKey = getBoolAsync(IS_ENTER_KEY, defaultValue: false);
    mSelectedImage = getStringAsync(SELECTED_WALLPAPER,
        defaultValue: appStore.isDarkMode
            ? mSelectedImageDark
            : "assets/default_wallpaper.png");

    messageSubscription = chatMessageService.listenToUnreadMessages(
        getStringAsync(userId), widget.receiverUser?.uid.toString() ?? '');
    try {
      isBlocked =
          await userService.isUserBlocked(widget.receiverUser?.uid ?? '');
    } catch (e) {
      print("Error ========");
    }
    chatMessageService
        .fetchLastMessage(loginStore.mId, widget.receiverUser?.uid)
        .then((value) {
      if (loginStore.mId == value.receiverId.validate())
        chatMessageService.setUnReadStatusToTrue(
            senderId: sender.uid ?? '', receiverId: widget.receiverUser!.uid!);
      chatMessageService.fetchForMessageCount(loginStore.mId);
    });
    print("show ========");
    requestData =
        chatRequestService.isRequestsUserExist(widget.receiverUser?.uid);
    setState(() {});
  }

  void getLocation() async {
    Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high);

    currentLat = position.latitude.toString();
    currentLong = position.longitude.toString();

    sendMessage(type: TYPE_LOCATION);
    if (messageCont.text.trim().isEmpty) {
      return;
    }
  }

  getSticker() {
    stickerService.getAllSticker().then((value) {
      stickerList = value;
      log(stickerList.length);
      setState(() {});
    });
  }

  void updateValue(String value) async {
    searchValue = value;
    scrollUpPosition = oldScrollUpPosition;
    scrollDownPosition = oldScrollUpPosition;

    print("Scroll Up Position Is==> " + scrollUpPosition.toString());
    print("Scroll Down Position Is==> " + scrollDownPosition.toString());
    setState(() {});
    return;
  }

  updateReplyStatus() async {
    if (replyMessage.isNotEmpty ||
        replyLatitude.isNotEmpty ||
        replyLongitude.isNotEmpty) {
      chatMessageService.setReplyToTrue(
          senderId: sender.uid ?? '',
          receiverId: widget.receiverUser?.uid ?? '',
          documentId: messageId);
    } else {}
    return;
  }

  nullUpdateReplyStatus() async {
    print("--------------194");
    if (replyMessage.isNotEmpty ||
        replyLatitude.isNotEmpty ||
        replyLongitude.isNotEmpty) {
      print("--------------196");

      chatMessageService.setReplyToTrue(
          senderId: sender.uid ?? '',
          receiverId: widget.receiverUser?.uid ?? '',
          documentId: null);
    } else {
      print("--------------200");
    }
    print("--------------203");
    clearReplyMessage();
    return;
  }

  void _animateToIndex(int index) {
    if (index < 0 || index >= _keys.length) {
      print("Index out of bounds: $index");
      return;
    }

    final keyContext = _keys[index].currentContext;
    if (keyContext != null) {
      // Try to scroll to the widget
      try {
        Scrollable.ensureVisible(
          keyContext,
          duration: Duration(milliseconds: 500),
          curve: Curves.easeInOut,
          alignment: 0.1,
        );
      } catch (e) {
        _fallbackScrollToIndex(index);
      }
    } else {
      _fallbackScrollToIndex(index);
    }
  }

  void _fallbackScrollToIndex(int index) {
    if (_scrollController.hasClients) {
      // Estimate item height and scroll position
      double estimatedItemHeight =
          80.0; // Adjust based on your ChatItemWidget height
      double targetOffset = index * estimatedItemHeight;

      _scrollController.animateTo(
        targetOffset,
        duration: Duration(milliseconds: 500),
        curve: Curves.easeInOut,
      );
    }
  }

  void handleNewMessages(List<ChatMessageModel> newMessages) {
    setState(() {
      chatMessages.addAll(newMessages);
    });
  }

  void clearReplyMessage() {
    replyMessage = "";
    replyLatitude = "";
    replyLongitude = "";
    userShareData = null;
    senderIdPassble = '';
    setState(() {});
  }

  @override
  void setState(fn) {
    if (mounted) super.setState(fn);
  }

  @override
  void dispose() async {
    WidgetsBinding.instance.removeObserver(this);
    try {
      isCompressingNotifier.dispose();
      progressNotifier.dispose();
      currentFileNameNotifier.dispose();
      compressedVideosNotifier.dispose();
      currentVideoIndexNotifier.dispose();
      messageSubscription?.cancel();
    } catch (e) {}
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    Widget buildChatRequestWidget(AsyncSnapshot<bool> snap) {
      if (snap.hasData) {
        return getRequestedWidget(snap.data ?? false);
      } else if (snap.hasError) {
        return getRequestedWidget(false);
      } else {
        return getRequestedWidget(false);
      }
    }

    if (chatMessageToReceiver == null) {
      return Scaffold(
        body: Center(child: Loader()),
      );
    }

    return PickupLayout(
      child: PopScope(
        canPop: true,
        onPopInvoked: (bool value) async {
          Navigator.of(context).popUntil((route) => route.isFirst);
          return Future.value(false);
        },
        child: StreamBuilder<Object>(
            stream: chatMessageService.typingGetStatus(
                getStringAsync(userId), widget.receiverUser?.uid ?? ''),
            builder: (context, snapshot) {
              String? typingUserId;
              if (snapshot.hasData && snapshot.data != null) {
                final data = (snapshot.data as DocumentSnapshot).data()
                    as Map<String, dynamic>?;
                final typingMap =
                    data?['typingStatus'] as Map<String, dynamic>?;
                if (typingMap != null &&
                    typingMap[widget.receiverUser?.uid] == true) {
                  typingUserId = widget.receiverUser?.uid;
                }
              }
              return Scaffold(
                  backgroundColor: context.scaffoldBackgroundColor,
                  appBar: PreferredSize(
                    preferredSize: Size(context.width(), kToolbarHeight),
                    child: ChatAppBarWidget(
                      isAdminAV: widget.isAdmin,
                      receiverUser: chatMessageToReceiver,
                      isFromRequest: widget.isFromRequest,
                      onSearchValueChanged: updateValue,
                      onUpCall: (position) => _animateToIndex(position.toInt()),
                      onDownCall: (position) =>
                          _animateToIndex(position.toInt()),
                      isFromArchive: widget.isArchive,
                      scrollUpPosition: scrollUpPosition,
                      scrollDownPosition: scrollDownPosition,
                      typingUserId: typingUserId,
                      isFromGroupChat: false,
                      isFirstChat: isFirstMsg,
                      null,
                      null,
                      null,
                    ),
                  ),
                  body: SafeArea(
                    child: FutureBuilder<bool>(
                      future: requestData,
                      builder: (context, snap) {
                        //if (!snap.hasData) return const SizedBox();
                        if (snap.hasData) {
                          return Stack(
                            fit: StackFit.expand,
                            children: [
                              backgroundImage(),
                              PaginateFirestore(
                                scrollController: _scrollController,
                                reverse: true,
                                isLive: true,
                                padding: EdgeInsets.only(
                                    left: 8, top: 8, right: 8, bottom: 0),
                                physics: AlwaysScrollableScrollPhysics(),
                                query: chatMessageService
                                    .chatMessagesWithPagination(
                                        currentUserId: getStringAsync(userId),
                                        receiverUserId:
                                            widget.receiverUser!.uid!),
                                itemsPerPage: PER_PAGE_CHAT_COUNT,
                                shrinkWrap: true,
                                onLoaded: (page) {
                                  bool firstChat =
                                      page.documentSnapshots.isEmpty;
                                  if (firstChat != isFirstMsg) {
                                    WidgetsBinding.instance
                                        .addPostFrameCallback((_) {
                                      if (mounted) {
                                        setState(() {
                                          isFirstMsg = firstChat;
                                        });
                                      }
                                    });
                                  }
                                  while (_keys.length <
                                      page.documentSnapshots.length) {
                                    _keys.add(GlobalKey());
                                  }
                                },
                                onEmpty: SizedBox(),
                                itemBuilderType: PaginateBuilderType.listView,
                                itemBuilder: (context, snap, index) {
                                  while (_keys.length <= index) {
                                    _keys.add(GlobalKey());
                                  }
                                  ChatMessageModel data =
                                      ChatMessageModel.fromJson(snap[index]
                                          .data() as Map<String, dynamic>);
                                  data.isMe = data.senderId == id;
                                  return Container(
                                    // key: _keys[index],
                                    key: ValueKey(snap[index].id),
                                    child: ChatItemWidget(
                                      receiverName: chatMessageToReceiver?.name!
                                          .toString(),
                                      data: data,
                                      onSearchValueChanged: searchValue,
                                      messageId: messageId,
                                      isAdminAV: widget.isAdmin,
                                      onArrowSearch: (p0,
                                          replyMsg,
                                          replyMsgType,
                                          isChatFrom,
                                          mID,
                                          rName,
                                          senderId,
                                          rLatitude,
                                          rLongitude,
                                          userData,
                                          groupNames,
                                          groupIds,
                                          groupProfiles) {
                                        if (replyMsg != null &&
                                            replyMsg.isNotEmpty) {
                                          replyMessage = replyMsg;
                                          if (replyMsgType != null &&
                                              replyMsgType.isNotEmpty) {
                                            replyMessageType = replyMsgType;
                                            senderIdPassble = senderId;
                                            receiverUserName = rName ?? '';
                                            userShareData = userData;
                                            groupName = groupNames;
                                            groupId = groupIds;
                                            groupProfile = groupProfiles;
                                          }
                                          setState(() {});
                                        }
                                        if (!rLatitude.isEmptyOrNull &&
                                            !rLongitude.isEmptyOrNull) {
                                          replyLatitude = rLatitude ?? '';
                                          replyLongitude = rLongitude ?? '';
                                          replyMessageType = replyMsgType ?? '';
                                          setState(() {});
                                        } else {}

                                        isReplyFrom = isChatFrom ?? false;
                                        messageId = mID ?? '';
                                        updateReplyStatus();
                                        setState(() {});
                                      },
                                    ),
                                  );
                                },
                              ).paddingBottom((widget.isAdmin == true)
                                  ? 0
                                  : !emojiStickerShowing
                                      ? snap.hasData
                                          ? (snap.data! ? 176 : 76)
                                          : 76
                                      : 320),
                              buildChatRequestWidget(snap),
                              if (isBlocked)
                                Positioned(
                                  top: 16,
                                  left: 32,
                                  right: 32,
                                  child: Container(
                                    decoration: boxDecorationDefault(
                                        color: Colors.red.shade100),
                                    child: TextButton(
                                      onPressed: () {
                                        unblockDialog(context,
                                            receiver: chatMessageToReceiver!);
                                      },
                                      child: Text(
                                          'you_blocked_this_contact'.translate,
                                          style: TS.secondaryTextStyle(
                                              color: Colors.red)),
                                    ),
                                  ),
                                ),
                            ],
                          ).onTap(() {
                            hideKeyboard(context);
                          });
                        }
                        //   return snapWidgetHelper(snap, loadingWidget: Loader());
                        return SizedBox();
                      },
                    ),
                  ));
            }),
      ),
    );
  }

  void handleTap() {
    checkUserRequest().then((val) {
      if (requestAccepted) {
        sendMessageCached = messageCont.text;
        messageCont.clear();
        if (!_isSending) {
          setState(() {
            _isSending = true;
          });
          sendMessage();
          Future.delayed(Duration(milliseconds: 300), () {
            setState(() {
              _isSending = false;
            });
          });
        }
      } else {
        sendMessageCached = messageCont.text;
        messageCont.clear();
        toast('requestPendingMsg'.translate);
      }
    });
  }

  //region send Message
  void sendMessage(
      {FilePickerResult? result,
      String? stickerPath,
      File? filepath,
      String? type,
      String? withText}) async {
    print("Type => ${type}");
    userExist = await chatMessageService.checkUserStatus(
        senderId: getStringAsync(userId),
        receiverId: widget.receiverUser?.uid ?? '');

    isReplyFrom = false;
    if (isBlocked.validate(value: false)) {
      unblockDialog(context, receiver: widget.receiverUser!);
      return;
    }

    ChatMessageModel data = ChatMessageModel();
    data.receiverId = widget.receiverUser?.uid;
    data.senderId = sender.uid;
    MessageType selectedMessageType = MessageType.TEXT;

    if (withText.isEmptyOrNull) {
      // data.message = messageCont.text.trim();
      data.message = sendMessageCached.trim();
    } else {
      data.message = withText;
    }

    data.isMessageRead = false;
    data.stickerPath = stickerPath;
    data.createdAt = DateTime.now().millisecondsSinceEpoch;
    data.isEncrypt = false;
    data.isFromReply = false;
    data.isFromForward = false;
    data.replyMessage = replyMessage;
    data.replyMessageId = messageId;
    data.replyMessageType = replyMessageType;
    if (userShareData?.name?.isNotEmpty ?? false) {
      data.shareUser = userShareData;
    }

    data.groupName = groupName;
    data.groupProfile = groupProfile;
    data.groupId = groupId;
    if (senderIdPassble != getStringAsync(userId)) {
      data.replyMessageSenderName = receiverUserName.toString();
    } else {
      data.replyMessageSenderName = loginStore.mDisplayName;
    }
    if (replyMessageType == LOCATION) {
      data.currentLat = replyLatitude;
      data.currentLong = replyLongitude;
      data.replyLocation = true;
    }
    if (filepath != null) {
      if (type == TYPE_Image) {
        data.messageType = MessageType.IMAGE.name;
        selectedMessageType = MessageType.IMAGE;
      } else if (type == TYPE_VIDEO) {
        data.messageType = MessageType.VIDEO.name;
        selectedMessageType = MessageType.VIDEO;
      } else if (type == TYPE_AUDIO) {
        data.messageType = MessageType.AUDIO.name;
        selectedMessageType = MessageType.AUDIO;
      } else if (type == TYPE_DOC) {
        selectedMessageType = MessageType.DOC;
        data.messageType = MessageType.DOC.name;
        String originalFileName = path.basename(filepath.path ?? '');
        String extension = path.extension(originalFileName);
        String nameWithoutExt = path.basenameWithoutExtension(originalFileName);
        String timestamp = DateTime.now().millisecondsSinceEpoch.toString();
        String newFileName = "${nameWithoutExt}_$timestamp$extension";
        data.documentName = newFileName;
      } else if (type == TYPE_VOICE_NOTE) {
        data.messageType = MessageType.VOICE_NOTE.name;
        selectedMessageType = MessageType.VOICE_NOTE;
      } else if (type == SHAREPROFILE) {
        data.messageType = MessageType.SHAREPROFILE.name;
        selectedMessageType = MessageType.SHAREPROFILE;
      } else {
        data.messageType = MessageType.TEXT.name;
        data.message = encryptData(sendMessageCached.trim());
        data.isEncrypt = true;
      }
    } else if (stickerPath.validate().isNotEmpty) {
      data.messageType = MessageType.STICKER.name;
      selectedMessageType = MessageType.STICKER;
    } else if (type == TYPE_Image) {
      data.messageType = MessageType.IMAGE.name;
      selectedMessageType = MessageType.IMAGE;
    } else {
      if (type == CURRENT_LOCATION) {
        data.messageType = MessageType.LOCATION.name;
        data.currentLat = currentLat;
        data.currentLong = currentLong;
        selectedMessageType = MessageType.LOCATION;
      } else if (type == TYPE_VOICE_NOTE) {
        data.messageType = MessageType.VOICE_NOTE.name;
        selectedMessageType = MessageType.VOICE_NOTE;
      } else {
        data.messageType = MessageType.TEXT.name;
        data.message = encryptData(sendMessageCached.trim());
        data.isEncrypt = true;
      }
    }

    if (widget.receiverUser != null) {
      List<DocumentReference>? blockedToList = widget.receiverUser?.blockedTo;

      if (blockedToList != null &&
          blockedToList.contains(
              userService.getUserReference(uid: getStringAsync(userId)))) {
        print("Main Else");
        data.isMessageRead = true;
        chatMessageService.addMessage(data).then((value) {
          messageCont.clear();
          setState(() {});
        });
      } else {
        if (await chatRequestService
            .isRequestsUserExist(widget.receiverUser?.uid ?? '')) {
          sendNormalMessages(data,
              result: result != null ? result : null, filepath: filepath);
        } else {
          if (userExist == false) {
            sendChatRequest(data,
                result: result != null ? result : null, file: filepath);
          } else {
            sendNormalMessages(data,
                result: result != null ? result : null, filepath: filepath);
          }
        }
        chatMessageService
            .getContactsDocument(
                of: getStringAsync(userId),
                forContact: widget.receiverUser?.uid)
            .update(<String, dynamic>{
          "lastMessageTime": DateTime.now().millisecondsSinceEpoch,
        });
        chatMessageService
            .getContactsDocument(
                of: widget.receiverUser?.uid,
                forContact: getStringAsync(userId))
            .update(<String, dynamic>{
          "lastMessageTime": DateTime.now().millisecondsSinceEpoch,
        });
      }

      final previewText = sendMessageCached.trim().isNotEmpty
          ? sendMessageCached.trim()
          : chatMessageService.generateLastMessagePreview(selectedMessageType);

      /// TODO
      /// ADD THE ARHIVE FROM WIDGET.

      chatMessageService.updateLastMessage(
          senderId: getStringAsync(userId),
          receiverId: widget.receiverUser!.uid!,
          text: encryptData(previewText),
          isRequest: userExist ? false : true,
          isGroupMessage: false,
          isArchive: widget.isArchive ?? false,
          groupName: "",
          groupId: "",
          timestamp: FieldValue.serverTimestamp());

      sendMessageCached = "";
    }

    clearReplyMessage();
  }

  void sendNormalMessages(ChatMessageModel data,
      {FilePickerResult? result, File? filepath}) async {
    if (isFirstMsg) {
      ContactModel data = ContactModel();
      data.uid = widget.receiverUser?.uid;
      data.addedOn = Timestamp.now();
      data.lastMessageTime = DateTime.now().millisecondsSinceEpoch;
      print("------554s>>${getStringAsync(userId)}");

      chatMessageService
          .getContactsDocument(
              of: getStringAsync(userId), forContact: widget.receiverUser?.uid)
          .set(data.toJson())
          .then((value) {
        //
      }).catchError((e, s) {
        log(e);
      });
    }

    String? message = '';
    //data.receiverId = widget.receiverUser?.uid;
    if (data.messageType == TYPE_Image) {
      message = " Sent you " + MessageType.IMAGE.name.capitalizeFirstLetter();
    } else if (data.messageType == TYPE_VIDEO.toUpperCase()) {
      message = " Sent You " + MessageType.VIDEO.name.capitalizeFirstLetter();
    } else if (data.messageType == TYPE_AUDIO) {
      message = " Sent you " + MessageType.AUDIO.name.capitalizeFirstLetter();
    } else if (data.messageType == TYPE_DOC) {
      message = " Sent you " + MessageType.DOC.name.capitalizeFirstLetter();
    } else if (data.messageType == TYPE_VOICE_NOTE) {
      message =
          " Sent you" + MessageType.VOICE_NOTE.name.capitalizeFirstLetter();
      ;
    } else if (data.messageType == TYPE_LOCATION) {
      message =
          " Sent you " + MessageType.LOCATION.name.capitalizeFirstLetter();
    } else if (data.messageType == TYPE_STICKER) {
      message = " Sent you " + MessageType.STICKER.name.capitalizeFirstLetter();
    } else {
      message = sendMessageCached.trim().validate();
    }

    print(
        "Send Notification To User Id===> ${widget.receiverUser?.uid.validate()}");

    if (!(widget.receiverUser?.oneSignalPlayerId.isEmptyOrNull ?? false)) {
      notificationService
          .sendPushNotifications(getStringAsync(userDisplayName), message,
              recevierUid: widget.receiverUser?.uid.validate(),
              receiverPlayerId: widget.receiverUser?.oneSignalPlayerId)
          .catchError((e) {
        print("erooor============${e.toString()}");
      });
    }

    if (data.messageType == MessageType.LOCATION.name) {
      chatMessageService.addLatLong(data, lat: currentLat, long: currentLong);
    }
    await chatMessageService.addMessage(data).then((value) async {
      if (result != null) {
        FileModel fileModel = FileModel();
        result.files.forEach((data) {
          fileModel.id = value.id;
          fileModel.file = File(data.path ?? '');
          fileList.add(fileModel);
        });
      }
      if (filepath != null && result == null) {
        FileModel fileModel = FileModel();
        fileModel.id = value.id;
        fileModel.file = File(filepath.path ?? '');
        fileList.add(fileModel);
        //  setState(() {});
      }

      // ignore: unnecessary_null_comparison
      print("-----------809>>${!(filepath?.path.isEmptyOrNull ?? false)}");
      //// This holds the upload where the image is uploading with the progress callback....
      await chatMessageService
          .addMessageToDb(
              senderDoc: value,
              data: data,
              sender: sender,
              user: widget.receiverUser,
              image: !(filepath?.path.isEmptyOrNull ?? false)
                  ? File(filepath?.path ?? '')
                  : null,
              isRequest: false)
          .then((value) {
        //
      });
    }).catchError((e, s) {
      print("-----------817${e.toString()}");
      print("-----------818${s.toString()}");
    });

    userService.fireStore
        .collection(USER_COLLECTION)
        .doc(getStringAsync(userId))
        .collection(CONTACT_COLLECTION)
        .doc(widget.receiverUser?.uid)
        .update({
      'lastMessageTime': DateTime.now().millisecondsSinceEpoch
    }).catchError((e) {});
    print("-----------669${widget.receiverUser?.uid}");

    userService.fireStore
        .collection(USER_COLLECTION)
        .doc(widget.receiverUser?.uid)
        .collection(CONTACT_COLLECTION)
        .doc(getStringAsync(userId))
        .update({
      'lastMessageTime': DateTime.now().millisecondsSinceEpoch
    }).catchError((e) {
      print("-----------674>>${e}");
    });
  }

  //endregion

  //region Emoji
  showEmojiBottomsheet() {
    return Stack(
      alignment: Alignment.bottomCenter,
      children: [
        Container(
          child: emojiShowing == true
              ? Container(
                  height: 255,
                  width: context.width(),
                  color: context.cardColor,
                  constraints: BoxConstraints(maxHeight: 500),
                  child: Stack(
                    alignment: Alignment.bottomCenter,
                    children: [
                      Container(
                        height: 255,
                        child: EmojiPicker(
                          onEmojiSelected: (Category? category, Emoji emoji) {
                            messageCont.text = messageCont.text + emoji.emoji;
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
              : isStickerShows == true
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
                                  sendMessage(
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
                  isStickerShows = false;
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
                  isStickerShows = true;
                  getSticker();
                  emojiShowing = false;
                  setState(() {});
                },
                icon: Icon(Icons.face,
                    size: 28,
                    color: isStickerShows
                        ? primaryColor
                        : textSecondaryColorGlobal.withOpacity(0.7)),
              ),
            ],
          ),
        )
      ],
    );
  }

  //endregion

  //region Attchment dialog
  showAttachmentDialog() {
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
                borderRadius: BorderRadius.circular(12)),
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
                      List<String>? texts =
                          await MultipleSelectedAttachmentText(
                        attachedFiles: image,
                        userModel: widget.receiverUser,
                        isImage: true,
                      ).launch(context);

                      if (texts != null) {
                        for (int i = 0; i < image.length; i++) {
                          finish(context);
                          sendMessage(
                              filepath: image[i],
                              type: TYPE_Image,
                              withText: texts[i]);
                          //compressedFile?.deleteSync();
                        }
                      } else {
                        // compressedFile?.deleteSync();
                        Navigator.of(context).pop();
                      }
                    } else {
                      // User canceled the picker
                    }
                  }),
                  iconsBackgroundWidget(context,
                          name: "lblGallery".translate,
                          image: ic_wallpaper,
                          color: Colors.purple.shade400)
                      .onTap(() async {
                    pickAndCompressImage();
                  }),
                  iconsBackgroundWidget(context,
                          name: "lblVideo".translate,
                          image: ic_video_call,
                          color: Colors.pink[400])
                      .onTap(() async {
                    pickAndSendVideos(widget.receiverUser, context,
                        (file, text) {
                      sendMessage(
                          filepath: file, type: TYPE_VIDEO, withText: text);
                    });
                  }),
                  iconsBackgroundWidget(context,
                          name: "lblAudio".translate,
                          image: ic_audio,
                          color: Colors.blue[700])
                      .onTap(() async {
                    pickAndSendAudio();
                  }),
                  iconsBackgroundWidget(context,
                          name: "lblDocument".translate,
                          image: ic_term_condition,
                          color: Colors.blue[700])
                      .onTap(() async {
                    pickAndSendDocuments();
                  }),
                  iconsBackgroundWidget(context,
                          name: "lblLocation".translate,
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
                            "are_you_sure_you_want_to_share_your_current_location"
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

  //endregion

  //region chat request
  void sendChatRequest(ChatMessageModel data,
      {FilePickerResult? result, File? file}) async {
    String? message = '';
    print("Data=================${data.messageType}");
    if (data.messageType == TYPE_Image.toUpperCase()) {
      message = " Sent you " + MessageType.IMAGE.name.capitalizeFirstLetter();
    } else if (data.messageType == TYPE_VIDEO.toUpperCase()) {
      message = " Sent You " + MessageType.VIDEO.name.capitalizeFirstLetter();
    } else if (data.messageType == TYPE_AUDIO.toUpperCase()) {
      message = " Sent you " + MessageType.AUDIO.name.capitalizeFirstLetter();
    } else if (data.messageType == TYPE_DOC.toUpperCase()) {
      message = " Sent you " + MessageType.DOC.name.capitalizeFirstLetter();
    } else if (data.messageType == TYPE_VOICE_NOTE) {
      message =
          " Sent you " + MessageType.VOICE_NOTE.name.capitalizeFirstLetter();
    } else if (data.messageType == "LOCATION") {
      message =
          " Sent you " + MessageType.LOCATION.name.capitalizeFirstLetter();
    } else if (data.messageType == TYPE_STICKER) {
      message = " Sent you " + MessageType.STICKER.name.capitalizeFirstLetter();
    } else {
      message = messageCont.text.trim().validate();
    }

    messageCont.clear();

    if (!(widget.receiverUser?.oneSignalPlayerId.isEmptyOrNull ?? false)) {
      notificationService
          .sendPushNotifications(getStringAsync(userDisplayName), message,
              recevierUid: widget.receiverUser?.uid.validate(),
              receiverPlayerId: widget.receiverUser!.oneSignalPlayerId)
          .catchError((e, s) {
        print("--------------933>>>>${e.toString()}");
        print("--------------934>>>>${s.toString()}");
      });
    }

    ChatRequestModel chatReq = ChatRequestModel();
    chatReq.uid = getStringAsync(userId);
    // chatReq.profilePic = data.photoUrl;
    chatReq.requestStatus = RequestStatus.Pending.index;
    chatReq.senderIdRef = userService.ref!.doc(sender.uid);
    chatReq.createdAt = DateTime.now().millisecondsSinceEpoch;
    chatReq.updatedAt = DateTime.now().millisecondsSinceEpoch;

    if (await chatRequestService.isRequestUserExist(
        sender.uid ?? "", widget.receiverUser?.uid ?? '')) {
      chatMessageService.addMessage(data).then((value) async {
        if (result != null) {
          FileModel fileModel = FileModel();
          fileModel.id = value.id;
          fileModel.file = file;
          fileList.add(fileModel);
        }
        if (file != null && result == null) {
          FileModel fileModel = FileModel();
          fileModel.id = value.id;
          fileModel.file = file;
          fileList.add(fileModel);
        }
        print("ghfghfghfghfghfgh");
        await chatMessageService
            .addMessageToDb(
                senderDoc: value,
                data: data,
                sender: sender,
                user: widget.receiverUser,
                image: !(file?.path.isEmptyOrNull ?? false)
                    ? File(file?.path ?? '')
                    : null,
                isRequest: true)
            .then((value) {
          chatMessageService.addToContacts(
              receiverId: widget.receiverUser!.uid,
              senderId: getStringAsync(userId));
          setState(() {});
          print("ghfghfghfghfghfgh967");
        });
      });
    } else {
      //contact ma availble no hoy chatrequest ma availble no hoy
      chatRequestService
          .addChatWithCustomId(getStringAsync(userId), chatReq.toJson(),
              widget.receiverUser?.uid ?? '')
          .then((value) {})
          .catchError((e) {
        print("Chat Request Calling");
      });

      chatMessageService.addMessage(data).then((value) async {
        if (result != null) {
          FileModel fileModel = FileModel();
          fileModel.id = value.id;
          fileModel.file = File(result.files.single.path!);
          fileList.add(fileModel);
        }
        if (file != null && result == null) {
          FileModel fileModel = FileModel();
          fileModel.id = value.id;
          fileModel.file = file;
          fileList.add(fileModel);
        }

        await chatMessageService
            .addMessageToDb(
                senderDoc: value,
                data: data,
                sender: sender,
                user: widget.receiverUser,
                image: !(file?.path.isEmptyOrNull ?? false)
                    ? File(file?.path ?? '')
                    : null,
                isRequest: true)
            .then((value) {
          audioPath = null;
        });

        userService.fireStore
            .collection(USER_COLLECTION)
            .doc(getStringAsync(userId))
            .collection(CONTACT_COLLECTION)
            .doc(widget.receiverUser?.uid)
            .update({
          'lastMessageTime': DateTime.now().millisecondsSinceEpoch
        }).catchError((e) {
          setState(() {});
        });
        userService.fireStore
            .collection(USER_COLLECTION)
            .doc(widget.receiverUser?.uid)
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

  Widget getRequestedWidget(bool isRequested) {
    if (isRequested) {
      return Positioned(
        bottom: 0,
        left: 0,
        right: 0,
        child: Container(
          decoration: BoxDecoration(
              color: context.primaryColor,
              borderRadius:
                  radiusOnly(topLeft: defaultRadius, topRight: defaultRadius)),
          padding: EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('message_request'.translate,
                  style: TS.boldTextStyle(color: Colors.white)),
              8.height,
              Text(
                  'if_you_accept_the_invite'.translate +
                      " ${widget.receiverUser!.name.validate()}" +
                      " " +
                      'can_message_you'.translate,
                  style: TS.primaryTextStyle(color: Colors.white70)),
              16.height,
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  AppButton(
                    text: "cancel".translate,
                    color: context.primaryColor,
                    shapeBorder: OutlineInputBorder(
                        borderRadius: radius(),
                        borderSide: BorderSide(color: Colors.white)),
                    onTap: () {
                      chatRequestService
                          .removeDocument(widget.receiverUser?.uid ?? '')
                          .then((value) {
                        chatMessageService
                            .deleteChat(
                                senderId: getStringAsync(userId),
                                receiverId: widget.receiverUser?.uid ?? '')
                            .then((value) {
                          finish(context);
                          finish(context);
                        }).catchError((e) {
                          log(e.toString());
                        });
                      }).catchError(
                        (e) {
                          log(e.toString());
                        },
                      );
                    },
                  ),
                  16.width,
                  AppButton(
                    text: "accept".translate,
                    textStyle: TS.boldTextStyle(),
                    shapeBorder: OutlineInputBorder(
                        borderRadius: radius(),
                        borderSide: BorderSide(color: Colors.white)),
                    onTap: () async {
                      ContactModel data = ContactModel();
                      data.uid = widget.receiverUser?.uid;
                      data.addedOn = Timestamp.now();
                      data.lastMessageTime =
                          DateTime.now().millisecondsSinceEpoch;
                      chatMessageService
                          .getContactsDocument(
                              of: getStringAsync(userId),
                              forContact: widget.receiverUser?.uid)
                          .set(data.toJson())
                          .then((value) async {
                        await chatMessageService.deleteChatRequestChat(
                            senderId: getStringAsync(userId),
                            receiverId: widget.receiverUser?.uid ?? '');
                        ////  Set Last Message isRequest as false
                        await chatMessageService.updateStatusOfChatRequest(
                            senderId: getStringAsync(userId),
                            receiverId: widget.receiverUser?.uid ?? '',
                            isRequest: false);
                        init();
                        toast("invitation_accepted".translate);
                      }).catchError((e, s) {
                        log('-------------1083>>>>${e.toString()}');
                        log('-------------1084>>>>${s.toString()}');
                      });
                      log('-------------1180>>>>${RequestStatus.Accepted.index}');
                      log('-------------1181>>>>${widget.receiverUser?.uid}');
                      chatRequestService
                          .updateDocument(
                              {"requestStatus": RequestStatus.Accepted.index},
                              widget.receiverUser?.uid)
                          .then((value) => null)
                          .catchError(
                            (e, s) {
                              print("-------1182>>>${e.toString()}");
                              print("-------1183>>>${s.toString()}");
                            },
                          );
                      print("-------1186>>>${isRequested}");
                      isRequested = false;
                      if (mounted) setState(() {});
                    },
                  ),
                  8.width,
                ],
              )
            ],
          ),
        ),
      );
    }

    return Positioned(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          Stack(
            alignment: Alignment.bottomLeft,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                // mainAxisAlignment: MainAxisAlignment.start,
                children: [
                  // Reply Container
                  if (replyMessage.isNotEmpty ||
                      replyLatitude.isNotEmpty ||
                      replyLongitude.isNotEmpty && isReplyFrom)
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
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
                                          senderIdPassble ==
                                                  getStringAsync(userId)
                                              ? 'you'.translate
                                              : widget.receiverUser?.name
                                                      .toString() ??
                                                  '',
                                          style: TS.primaryTextStyle(
                                              color: primaryColor,
                                              weight: FontWeight.bold,
                                              size: 12),
                                        ),
                                        4.height,
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
                                                    decryptedData(replyMessage
                                                            .toString() ??
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
                                                        !groupProfile
                                                                .isEmptyOrNull
                                                            ? groupProfile ?? ''
                                                            : userShareData
                                                                ?.photoUrl
                                                                .validate(),
                                                        height: 35,
                                                        width: 35,
                                                        fit: BoxFit.cover)
                                                    .cornerRadiusWithClipRRect(
                                                        50),
                                                5.width,
                                                Text(
                                                  !groupName.isEmptyOrNull
                                                      ? groupName ?? ''
                                                      : userShareData?.name ??
                                                          '',
                                                  style:
                                                      TS.secondaryTextStyle(),
                                                ).expand(),
                                              ],
                                            ),
                                          ),
                                      ],
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
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
                                            print('----------1199');
                                            isReplyFrom = false;
                                            nullUpdateReplyStatus();
                                            setState(() {});
                                          }),
                                        ),
                                      ],
                                    ),
                                  ],
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                ),
                              ],
                            ).paddingOnly(
                              left: 8,
                              right: 4,
                            ),
                          ).paddingOnly(top: 8, left: 8, right: 4),
                          decoration: boxDecorationWithRoundedCorners(
                              backgroundColor: context.cardColor,
                              borderRadius: !isReplyFrom
                                  ? BorderRadius.circular(20)
                                  : BorderRadius.only(
                                      topLeft: Radius.circular(14),
                                      topRight: Radius.circular(14))),
                        ).paddingOnly(left: 8, right: 8).expand(),
                        58.width
                      ],
                    ),
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
                        child: Row(
                          children: [
                            IconButton(
                              icon:
                                  Icon(LineIcons.smiling_face_with_heart_eyes),
                              iconSize: 24.0,
                              padding: EdgeInsets.all(2),
                              color: Colors.grey,
                              onPressed: () {
                                if (isBlocked) {
                                  unblockDialog(context,
                                      receiver: widget.receiverUser!);
                                  return;
                                }
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
                              focus: messageFocus,
                              textCapitalization: TextCapitalization.sentences,
                              keyboardType: TextInputType.multiline,
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
                                if (!_isSending) {
                                  setState(() {
                                    _isSending = true;
                                  });
                                  sendMessage();
                                  Future.delayed(Duration(milliseconds: 300),
                                      () {
                                    setState(() {
                                      _isSending = false;
                                    });
                                  });
                                }
                              },
                              onChanged: (s) {
                                emojiStickerShowing = false;
                                setState(() {});
                                if (!_isTyping) {
                                  _isTyping = true;

                                  chatMessageService.typingStatus(
                                      getStringAsync(userId),
                                      widget.receiverUser?.uid ?? '',
                                      true);
                                }

                                // Reset timer on each keystroke
                                _typingTimer?.cancel();
                                _typingTimer = Timer(Duration(seconds: 2), () {
                                  _isTyping = false;
                                  chatMessageService.typingStatus(
                                      getStringAsync(userId),
                                      widget.receiverUser?.uid ?? '',
                                      false);
                                });
                              },
                              decoration: InputDecoration(
                                border: InputBorder.none,
                                hintText: 'lblMessage'.translate,
                                hintStyle: TS.secondaryTextStyle(),
                                labelStyle: TS.secondaryTextStyle(),
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
                                if (isBlocked.validate(value: false)) {
                                  unblockDialog(context,
                                      receiver: widget.receiverUser!);
                                  return;
                                }

                                print("requestAccepted = ${requestAccepted}");

                                if (!requestAccepted) {
                                  toast('requestPendingMsg'.translate);
                                  return;
                                }
                                showAttachmentDialog();
                                hideKeyboard(context);
                                emojiStickerShowing = false;
                              },
                            ),
                          ],
                        ),
                        width: context.width(),
                      ).expand(),
                      8.width,
                      if (messageCont.text.isNotEmpty || emojiStickerShowing)
                        GestureDetector(
                          onTap: handleTap,
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
                        SizedBox(width: 50)
                    ],
                  ).paddingOnly(bottom: 8, left: 8, right: 8),
                ],
              ),
              if (messageCont.text.isEmpty && !emojiStickerShowing)
                AudioRecorder(
                  onStop: (path) async {
                    File file = File(path);
                    int fileSize = await file.length();
                    if (fileSize > 8 * 1024 * 1024) {
                      Fluttertoast.showToast(
                        msg:
                            "${'lblFile'.translate} ${'8MBUpMsgDoc'.translate}",
                        toastLength: Toast.LENGTH_LONG,
                        gravity: ToastGravity.BOTTOM,
                      );
                      return;
                    }

                    setState(() {
                      audioPath = path;
                    });
                    sendMessage(
                        result: null,
                        filepath: File.fromUri(Uri.parse(audioPath ?? '')),
                        type: TYPE_VOICE_NOTE);
                  },
                ).paddingOnly(bottom: 8, left: 8, right: 8),
            ],
          ),
          if (emojiStickerShowing) showEmojiBottomsheet(),
        ],
      ),
    ).visible(widget.isAdmin == false);
  }
//endregion
}
