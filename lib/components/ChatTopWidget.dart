import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_vector_icons/flutter_vector_icons.dart';
import 'package:intl/intl.dart';
import 'package:nb_utils/nb_utils.dart';

import '../../utils/TextStyles.dart' as TS;

import 'package:chat/centralized_import.dart';

typedef ScrollCallback = void Function(double position);

class ChatAppBarWidget extends StatefulWidget {
  final bool? isAdminAV;
  final UserModel? receiverUser;
  final bool? isFromRequest;
  final Function(String)? onSearchValueChanged;
  final ScrollCallback? onUpCall;
  final ScrollCallback? onDownCall;
  final bool? isFromArchive;
  final double? scrollUpPosition;
  final double? scrollDownPosition;
  final bool? isFromGroupChat;
  final bool? isFirstChat;
  final String? typingUserId;
  final String? groupChatId, groupName, imageUrl;
  final dynamic groupData;

  ChatAppBarWidget(
    this.groupChatId,
    this.groupName,
    this.groupData, {
    required this.receiverUser,
    this.isFromRequest,
    this.isAdminAV,
    this.onSearchValueChanged,
    this.onUpCall,
    this.onDownCall,
    this.isFromArchive,
    this.scrollUpPosition,
    this.scrollDownPosition,
    this.isFromGroupChat,
    this.isFirstChat,
    this.imageUrl,
    this.typingUserId,
  });

  @override
  ChatAppBarWidgetState createState() => ChatAppBarWidgetState();
}

class ChatAppBarWidgetState extends State<ChatAppBarWidget> {
  bool isRequestAccept = false;
  bool isBlocked = false;
  bool isSearch = false;
  TextEditingController searchCont = TextEditingController();
  List<ChatMessageModel> chats = [];
  List<ChatMessageModel> searchMessageChatList = [];
  List<ChatMessageModel> highlightedMessages = [];
  List membersList = [];
  List<UserModel> userModelList = [];
  List<UserModel> userList = [];
  List<String> mList = [];
  List<StickerModel> stickerList = [];
  String? name = '';
  String? imageUrl;
  String admin = '';
  int currentHighlightIndex = 0;
  bool requestAccepted = false;

  ChatMessageService chatMessageService = ChatMessageService();

  @override
  void initState() {
    super.initState();
    print("----------92>>>${widget.groupName}");
    imageUrl = widget.imageUrl.validate();
    init();
    checkUserRequest();
    if (!widget.groupName.isEmptyOrNull) {
      getGroupDetails();
    }
  }

  @override
  void didUpdateWidget(covariant ChatAppBarWidget oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (oldWidget.isFirstChat != widget.isFirstChat) {
      checkUserRequest();
    }
  }

  Future<void> checkUserRequest() async {
    if (widget.groupData != null) {
      return;
    }
    final currentUser = getStringAsync(userId);
    final otherUser = widget.receiverUser?.uid.toString();

    final isPending = await chatMessageService.hasPendingRequestFromUser(
      currentUserId: currentUser,
      otherUserId: otherUser ?? "",
    );

    final fromRequest = widget.isFromRequest ?? false;

    setState(() {
      requestAccepted = !(isPending || fromRequest);
    });
  }

  Future<void> init() async {
    isBlocked = !widget.isFromGroupChat!
        ? await userService.userByEmail(getStringAsync(userEmail)).then(
            (value) => value.blockedTo!
                .contains(userService.ref!.doc(widget.receiverUser!.uid)))
        : false;
    name = widget.groupName;
    fetchNewData();
    setState(() {});
  }

  fetchNewData() async {
    try {
      Query query = chatMessageService.chatMessagesWithPagination(
          currentUserId: getStringAsync(userId),
          receiverUserId: widget.receiverUser?.uid ?? '');
      await query.get().then((value) {
        if (value.docs.isNotEmpty) {
          chats.clear();
          for (var doc in value.docs) {
            var data = doc.data() as Map<String, dynamic>;
            var chatModel = ChatMessageModel.fromJson(data);
            if (!shouldSkipMessage(chatModel)) {
              chats.add(chatModel);
            }
          }
          setState(() {});
        }
      });
    } catch (e) {
      print("Error fetching data: $e");
    }
  }

  bool shouldSkipMessage(ChatMessageModel chatItem) {
    if (chatItem.isDeleted == true) {
      return true;
    }
    if (chatItem.delete_for_sender == true &&
        chatItem.senderId == getStringAsync(userId)) {
      return true;
    }
    if (chatItem.deletedFor != null &&
        chatItem.deletedFor!.contains(getStringAsync(userId))) {
      return true;
    }

    return false;
  }

  void updateHighlightedMessages() {
    highlightedMessages.clear();
    currentHighlightIndex = 0;

    if (searchCont.text.isNotEmpty) {
      for (int i = 0; i < chats.length; i++) {
        ChatMessageModel chatItem = chats[i];
        if (shouldSkipMessage(chatItem)) {
          continue;
        }
        if (isHighlighted(chatItem)) {
          highlightedMessages.add(chatItem);
        }
      }
    }
    setState(() {});
  }

  double calculateScrollPositionForHighlightedItem({bool isNext = true}) {
    if (highlightedMessages.isEmpty) return 0.0;

    // Navigate through highlighted messages
    if (isNext) {
      if (currentHighlightIndex < highlightedMessages.length - 1) {
        currentHighlightIndex++;
      } else {
        currentHighlightIndex = 0; // Loop back to first
      }
    } else {
      if (currentHighlightIndex > 0) {
        currentHighlightIndex--;
      } else {
        currentHighlightIndex = highlightedMessages.length - 1; // Loop to last
      }
    }

    ChatMessageModel targetMessage = highlightedMessages[currentHighlightIndex];
    int visibleIndex = 0;
    for (int i = 0; i < chats.length; i++) {
      if (chats[i].id == targetMessage.id) {
        return visibleIndex.toDouble();
      }
      if (!shouldSkipMessage(chats[i])) {
        visibleIndex++;
      }
    }
    return 0.0;
  }

  bool isHighlighted(ChatMessageModel chatItem) {
    if (searchCont.text.isEmpty) return false;

    if (shouldSkipMessage(chatItem)) return false;

    bool isHighlighted = chatItem.messageType == TEXT
        ? decryptedData(chatItem.message.toString())
            .toLowerCase()
            .contains(searchCont.text.toLowerCase())
        : false;

    return isHighlighted;
  }

  bool hasHighlightedSearchValue() {
    return highlightedMessages.isNotEmpty;
  }

  // Method to create highlighted text widget
  Widget buildHighlightedText(String text, String searchQuery) {
    if (searchQuery.isEmpty) {
      return Text(text);
    }

    List<TextSpan> spans = [];
    String lowerText = text.toLowerCase();
    String lowerQuery = searchQuery.toLowerCase();

    int start = 0;
    int index = lowerText.indexOf(lowerQuery);

    while (index != -1) {
      // Add text before the match
      if (index > start) {
        spans.add(TextSpan(
          text: text.substring(start, index),
          style: TS.boldTextStyle(color: Colors.black),
        ));
      }

      // Add highlighted match
      spans.add(TextSpan(
        text: text.substring(index, index + searchQuery.length),
        style: TS.boldTextStyle(
          backgroundColor: Colors.yellow,
          color: Colors.black,
          weight: FontWeight.bold,
        ),
      ));

      start = index + searchQuery.length;
      index = lowerText.indexOf(lowerQuery, start);
    }

    // Add remaining text
    if (start < text.length) {
      spans.add(TextSpan(
        text: text.substring(start),
        style: TS.boldTextStyle(color: Colors.black),
      ));
    }

    return RichText(text: TextSpan(children: spans));
  }

  double upPosition() {
    if (hasHighlightedSearchValue()) {
      double position =
          calculateScrollPositionForHighlightedItem(isNext: false);
      print(
          "Up Position: $position, Current Index: $currentHighlightIndex/${highlightedMessages.length}");
      return position;
    } else {
      return 0.0;
    }
  }

  double downPosition() {
    if (hasHighlightedSearchValue()) {
      double position = calculateScrollPositionForHighlightedItem(isNext: true);
      print(
          "Down Position: $position, Current Index: $currentHighlightIndex/${highlightedMessages.length}");
      return position;
    } else {
      return 0.0;
    }
  }

  void handleOnChanged(String value) {
    print("Handle On Changed Called with value: $value");
    widget.onSearchValueChanged?.call(value);
    updateHighlightedMessages();
    setState(() {});
  }

  void clearSearch() {
    searchCont.clear();
    isSearch = false;
    highlightedMessages.clear();
    currentHighlightIndex = 0;
    widget.onSearchValueChanged?.call("");
    setState(() {});
  }

  Future<void> handleOnTap() async {
    bool res = await GroupInfoScreen(
      groupName: name.validate(),
      groupId: widget.groupChatId.validate(),
      data: widget.groupData,
      isSearch: (p0) {
        isSearch = p0;
        setState(() {});
      },
    ).launch(context,
        pageRouteAnimation: PageRouteAnimation.Scale,
        duration: 300.milliseconds);

    if (res == true) {
      getGroupDetails();
      setState(() {});
    }
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
        }
      }
      setState(() {});
    });
  }

  Future getGroupDetails() async {
    await groupChatMessageService.grpRef
        .doc(widget.groupChatId)
        .get()
        .then((chatMap) async {
      membersList = chatMap['membersList'] ?? [];
      getMemberList();
      imageUrl = chatMap['photoUrl'] ?? '';
      name = chatMap['name'];
      admin = chatMap['adminId'];
      if (getStringAsync(userId) == admin) {
        if (chatMap['adminIds'] == null) {
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

  @override
  void setState(fn) {
    if (mounted) super.setState(fn);
  }

  @override
  Widget build(BuildContext context) {
    String getTime(int val) {
      String? time;
      DateTime date = DateTime.fromMicrosecondsSinceEpoch(val * 1000);
      if (date.day == DateTime.now().day) {
        time = "at ${DateFormat('hh:mm a').format(date)}";
      } else {
        time = date.timeAgo;
      }
      return time;
    }

    return AppBar(
      titleSpacing: !(widget.isFromGroupChat ?? false) ? 16 : 0,
      automaticallyImplyLeading: false,
      titleTextStyle: TS.primaryTextStyle(),
      title: !(widget.isFromGroupChat ?? false)
          ? StreamBuilder<UserModel>(
              stream: userService.singleUser(widget.receiverUser?.uid),
              builder: (context, snap) {
                if (snap.hasError) {
                  return Container();
                }
                if (snap.hasData) {
                  UserModel data = snap.data!;
                  return LayoutBuilder(builder: (context, constraints) {
                    bool isSmallScreen = constraints.maxWidth < 600;

                    return Row(
                      children: [
                        InkWell(
                          splashColor: Colors.transparent,
                          hoverColor: Colors.transparent,
                          highlightColor: Colors.transparent,
                          onTap: () {
                            if (isSearch) {
                              clearSearch();
                              return;
                            }
                            if (widget.isFromArchive.validate()) {
                              finish(context, true);
                            } else {
                              if (widget.isFromRequest.validate()) {
                                finish(context, true);
                              } else {
                                Navigator.of(context)
                                    .popUntil((route) => route.isFirst);
                              }
                            }
                          },
                          child: Icon(
                            isSearch ? Icons.arrow_back : Icons.arrow_back,
                            color: whiteColor,
                            size: isSmallScreen ? 24 : 28,
                          ),
                        ),
                        if (!isSearch) SizedBox(width: isSmallScreen ? 6 : 8),
                        if (!isSearch)
                          InkWell(
                            splashColor: Colors.transparent,
                            hoverColor: Colors.transparent,
                            highlightColor: Colors.transparent,
                            onTap: () {
                              FullScreenImageWidget(
                                photoUrl: data.photoUrl,
                                heroId: data.uid,
                                name: data.name,
                              ).launch(context);
                            },
                            child: Row(
                              children: [
                                data.photoUrl.validate().isEmptyOrNull
                                    ? Hero(
                                        tag: data.uid.validate(),
                                        child: Container(
                                          height: isSmallScreen ? 30 : 35,
                                          width: isSmallScreen ? 30 : 35,
                                          color: getColorFromString(
                                              data.uid.validate()),
                                          child: Text(
                                            data.name
                                                .validate()[0]
                                                .toUpperCase(),
                                            style: TS.secondaryTextStyle(
                                                color: Colors.white),
                                          ).center().fit(),
                                        ).cornerRadiusWithClipRRect(
                                            (isSmallScreen ? 30 : 35) / 2))
                                    : Hero(
                                        tag: data.uid ?? '',
                                        child: cachedImage(
                                          data.photoUrl.validate(),
                                          height: isSmallScreen ? 30 : 35,
                                          width: isSmallScreen ? 30 : 35,
                                          fit: BoxFit.cover,
                                        ).cornerRadiusWithClipRRect(50)),
                              ],
                            ).paddingSymmetric(
                                vertical: isSmallScreen ? 12 : 16),
                          ),
                        if (!isSearch) SizedBox(width: isSmallScreen ? 6 : 8),
                        if (!isSearch)
                          InkWell(
                            splashColor: Colors.transparent,
                            hoverColor: Colors.transparent,
                            highlightColor: Colors.transparent,
                            onTap: () {
                              if (widget.isAdminAV == false ||
                                  widget.isAdminAV == null) {
                                UserProfileScreen(
                                  uid: data.uid.validate(),
                                  receiverUser: data,
                                ).launch(context,
                                    pageRouteAnimation:
                                        PageRouteAnimation.Scale,
                                    duration: 300.milliseconds);
                              }
                            },
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Flexible(
                                  child: Text(
                                    data.name.validate(),
                                    style: TS.boldTextStyle(color: whiteColor),
                                    overflow: TextOverflow.ellipsis,
                                    maxLines: 1,
                                  ),
                                ),
                                SizedBox(height: isSmallScreen ? 2 : 4),
                                if (widget.typingUserId ==
                                    widget.receiverUser?.uid) ...[
                                  Text(
                                    'typing'.translate,
                                    style: TS
                                        .secondaryTextStyle(
                                            color: Colors.white70)
                                        .copyWith(
                                          fontSize: isSmallScreen ? 11 : 12,
                                        ),
                                  ).visible(widget.isAdminAV == false ||
                                      widget.isAdminAV == null)
                                ] else ...[
                                  data.isPresence.validate()
                                      ? Text(
                                          'online'.translate,
                                          style: TS
                                              .secondaryTextStyle(
                                                  color: Colors.white70)
                                              .copyWith(
                                                fontSize:
                                                    isSmallScreen ? 11 : 12,
                                              ),
                                        )
                                      : SizedBox(
                                          width: constraints.maxWidth * 0.5,
                                          child: Marquee(
                                            direction: Axis.horizontal,
                                            child: Text(
                                              'last_seen'.translate +
                                                  " ${getTime(data.lastSeen.validate())}",
                                              style: secondaryTextStyle(
                                                  size: isSmallScreen ? 10 : 12,
                                                  color: Colors.white70),
                                            ),
                                          ),
                                        ).visible(widget.isAdminAV == false ||
                                          widget.isAdminAV == null),
                                ],
                              ],
                            ).paddingSymmetric(
                                vertical: isSmallScreen ? 12 : 16),
                          ).expand(),
                      ],
                    );
                  });
                }
                return snapWidgetHelper(snap, loadingWidget: Container());
              },
            )
          : LayoutBuilder(builder: (context, constraints) {
              bool isSmallScreen = constraints.maxWidth < 600;

              return Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                mainAxisAlignment: MainAxisAlignment.start,
                children: [
                  IconButton(
                      splashColor: Colors.transparent,
                      hoverColor: Colors.transparent,
                      highlightColor: Colors.transparent,
                      constraints: BoxConstraints(
                        minWidth: isSmallScreen ? 36 : 48,
                        minHeight: isSmallScreen ? 36 : 48,
                      ),
                      onPressed: () {
                        if (isSearch) {
                          clearSearch();
                          return;
                        }
                        finish(context);
                      },
                      icon: Icon(
                        Icons.arrow_back,
                        color: whiteColor,
                        size: isSmallScreen ? 20 : 24,
                      )),
                  if (!isSearch) SizedBox(width: isSmallScreen ? 2 : 4),
                  if (!isSearch)
                    Expanded(
                      child: InkWell(
                        splashColor: Colors.transparent,
                        hoverColor: Colors.transparent,
                        highlightColor: Colors.transparent,
                        onTap: () {
                          handleOnTap();
                        },
                        child: Row(
                          children: [
                            !imageUrl.isEmptyOrNull
                                ? Hero(
                                    tag: 'profile',
                                    child: cachedImage(
                                      imageUrl ?? '',
                                      width: isSmallScreen ? 30 : 35,
                                      height: isSmallScreen ? 30 : 35,
                                      fit: BoxFit.cover,
                                    ).cornerRadiusWithClipRRect(25),
                                  )
                                : noProfileImageFound(
                                    height: isSmallScreen ? 30 : 35,
                                    width: isSmallScreen ? 30 : 35,
                                  ),
                            SizedBox(width: isSmallScreen ? 8 : 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    name.validate(),
                                    style: TextStyle(
                                      color: whiteColor,
                                      overflow: TextOverflow.ellipsis,
                                      fontSize: appStore.fontSize,
                                      fontWeight: FontWeight.w500,
                                    ),
                                    maxLines: 1,
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
              );
            }),
      actions: [
        if (widget.isAdminAV == false || widget.isAdminAV == null) ...[
          if (!isSearch)
            widget.isFromGroupChat ?? false
                ? LayoutBuilder(builder: (context, constraints) {
                    bool isSmallScreen =
                        MediaQuery.of(context).size.width < 600;
                    return IconButton(
                        padding: EdgeInsets.zero,
                        constraints: BoxConstraints(
                          minWidth: isSmallScreen ? 36 : 48,
                          minHeight: isSmallScreen ? 36 : 48,
                        ),
                        icon: Icon(
                          FontAwesome.video_camera,
                          size: isSmallScreen ? 16 : 20,
                          color: whiteColor,
                        ),
                        onPressed: () async {
                          await groupCallFunctions.dialGroup(
                              context: context,
                              from: sender,
                              toUsers: userModelList,
                              groupId: widget.groupChatId,
                              groupName: widget.groupName,
                              callType: CALL_TYPE_GROUP_VIDEO_CALL);
                        });
                  })
                : (!requestAccepted || widget.isFirstChat.validate() == true)
                    ? SizedBox()
                    : LayoutBuilder(builder: (context, constraints) {
                        bool isSmallScreen =
                            MediaQuery.of(context).size.width < 600;
                        return IconButton(
                            padding: EdgeInsets.zero,
                            constraints: BoxConstraints(
                              minWidth: isSmallScreen ? 36 : 48,
                              minHeight: isSmallScreen ? 36 : 48,
                            ),
                            icon: Icon(
                              FontAwesome.video_camera,
                              size: isSmallScreen ? 16 : 20,
                              color: whiteColor,
                            ),
                            onPressed: () async {
                              if (isBlocked) {
                                unblockDialog(context,
                                    receiver: widget.receiverUser!);
                                return;
                              }
                              return await Permissions
                                      .cameraAndMicrophonePermissionsGranted()
                                  ? CallFunctions.dial(
                                      context: context,
                                      from: sender,
                                      to: widget.receiverUser!)
                                  : {};
                            });
                      }),
          if (!isSearch)
            widget.isFromGroupChat!
                ? LayoutBuilder(builder: (context, constraints) {
                    bool isSmallScreen =
                        MediaQuery.of(context).size.width < 600;
                    return IconButton(
                        padding: EdgeInsets.zero,
                        constraints: BoxConstraints(
                          minWidth: isSmallScreen ? 36 : 48,
                          minHeight: isSmallScreen ? 36 : 48,
                        ),
                        icon: Icon(
                          FontAwesome.phone,
                          size: isSmallScreen ? 16 : 20,
                          color: whiteColor,
                        ),
                        onPressed: () async {
                          await groupCallFunctions.dialGroup(
                              context: context,
                              from: sender,
                              toUsers: userModelList,
                              groupId: widget.groupChatId,
                              groupName: widget.groupName,
                              callType: CALL_TYPE_GROUP_AUDIO_CALL);
                        });
                  })
                : (!requestAccepted || widget.isFirstChat.validate() == true)
                    ? SizedBox()
                    : LayoutBuilder(builder: (context, constraints) {
                        bool isSmallScreen =
                            MediaQuery.of(context).size.width < 600;
                        return IconButton(
                            padding: EdgeInsets.zero,
                            constraints: BoxConstraints(
                              minWidth: isSmallScreen ? 36 : 48,
                              minHeight: isSmallScreen ? 36 : 48,
                            ),
                            icon: Icon(
                              FontAwesome.phone,
                              size: isSmallScreen ? 16 : 20,
                              color: whiteColor,
                            ),
                            onPressed: () async {
                              if (isBlocked) {
                                unblockDialog(context,
                                    receiver: widget.receiverUser!);
                                return;
                              }
                              return await Permissions
                                      .cameraAndMicrophonePermissionsGranted()
                                  ? CallFunctions.voiceDial(
                                      context: context,
                                      from: sender,
                                      to: widget.receiverUser!)
                                  : {};
                            });
                      }),
          if (!isSearch)
            widget.isFromGroupChat!
                ? SizedBox()
                : LayoutBuilder(builder: (context, constraints) {
                    bool isSmallScreen =
                        MediaQuery.of(context).size.width < 600;
                    return PopupMenuButton(
                      padding: EdgeInsets.zero,
                      offset: Offset(10, -40),
                      constraints: BoxConstraints(
                        minWidth: isSmallScreen ? 36 : 48,
                        minHeight: isSmallScreen ? 36 : 48,
                      ),
                      icon: Icon(
                        Icons.more_vert,
                        color: whiteColor,
                        size: isSmallScreen ? 20 : 24,
                      ),
                      color:
                          appStore.isDarkMode ? scaffoldSecondaryDark : white,
                      onSelected: (dynamic value) async {
                        if (value == 1) {
                          UserProfileScreen(uid: widget.receiverUser?.uid ?? '')
                              .launch(
                            context,
                            pageRouteAnimation: PageRouteAnimation.Scale,
                            duration: 300.milliseconds,
                          );
                        } else if (value == 2) {
                          showConfirmDialogCustom(
                            context,
                            dialogAnimation: DialogAnimation.SCALE,
                            title: "report".translate +
                                " ${widget.receiverUser?.name.validate()} ?",
                            negativeText: "cancel".translate,
                            positiveText: "report".translate,
                            primaryColor: primaryColor,
                            onAccept: (V) {
                              reportBy();
                            },
                          );
                        } else if (value == 3) {
                          if (isBlocked) {
                            unblockDialog(context,
                                receiver: widget.receiverUser!);
                          } else {
                            showConfirmDialogCustom(
                              context,
                              dialogAnimation: DialogAnimation.SCALE,
                              title: "block".translate +
                                  " ${widget.receiverUser!.name.validate()}?",
                              subTitle:
                                  "blocked_contact_will_no_longer_be_able_to_call_you_or_send_you_message"
                                      .translate,
                              onAccept: (v) {
                                blockMessage();
                              },
                              positiveText: "block".translate,
                              negativeText: "cancel".translate,
                              primaryColor: primaryColor,
                            );
                          }
                        } else if (value == 4) {
                          showConfirmDialogCustom(context,
                              dialogAnimation: DialogAnimation.SCALE,
                              title: "clear_chats".translate + '?',
                              positiveText: 'lbl_yes'.translate,
                              negativeText: 'lbl_no'.translate,
                              primaryColor: primaryColor, onAccept: (v) {
                            chatMessageService
                                .clearAllMessages(
                                    senderId: sender.uid,
                                    receiverId: widget.receiverUser!.uid!)
                                .then((value) {
                              toast("chat_clear".translate);
                              hideKeyboard(context);
                            }).catchError((e) {
                              toast(e);
                            });
                          });
                        } else if (value == 5) {
                          isSearch = true;
                          await fetchNewData();
                          setState(() {});
                        }
                      },
                      itemBuilder: (context) {
                        List<PopupMenuItem> list = [];
                        list.add(PopupMenuItem(
                            value: 1,
                            child: Text('view_Contact'.translate,
                                style: TS.primaryTextStyle())));
                        list.add(PopupMenuItem(
                            value: 2,
                            child: Text('report'.translate,
                                style: TS.primaryTextStyle())));
                        list.add(PopupMenuItem(
                            value: 3,
                            child: Text(
                                isBlocked
                                    ? 'unblock'.translate
                                    : 'block'.translate,
                                style: TS.primaryTextStyle())));
                        list.add(PopupMenuItem(
                            value: 4,
                            child: Text('clear_Chat'.translate,
                                style: TS.primaryTextStyle())));
                        list.add(PopupMenuItem(
                            value: 5,
                            child: Text('search'.translate,
                                style: TS.primaryTextStyle())));
                        return list;
                      },
                    );
                  }),
          if (isSearch)
            LayoutBuilder(builder: (context, constraints) {
              bool isSmallScreen = MediaQuery.of(context).size.width < 600;
              double searchWidth = isSmallScreen
                  ? MediaQuery.of(context).size.width - 80
                  : MediaQuery.of(context).size.width - 60;

              return AnimatedContainer(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.all(Radius.circular(40)),
                  color: Colors.white.withOpacity(0.1),
                ),
                duration: Duration(milliseconds: 300),
                curve: Curves.decelerate,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  mainAxisAlignment: MainAxisAlignment.start,
                  children: [
                    Expanded(
                      child: TextField(
                        autofocus: true,
                        textAlignVertical: TextAlignVertical.center,
                        cursorColor: Colors.white,
                        onChanged: handleOnChanged,
                        style: TS.boldTextStyle(color: Colors.white).copyWith(
                              fontSize: isSmallScreen ? 14 : 16,
                            ),
                        controller: searchCont,
                        decoration: InputDecoration(
                          border: InputBorder.none,
                          hintText: "search".translate,
                          hintStyle: TS
                              .secondaryTextStyle(color: Colors.white70)
                              .copyWith(
                                fontSize: isSmallScreen ? 14 : 16,
                              ),
                          contentPadding: EdgeInsets.symmetric(
                            horizontal: isSmallScreen ? 12 : 16,
                            vertical: isSmallScreen ? 8 : 12,
                          ),
                        ),
                      ),
                    ),
                    if (hasHighlightedSearchValue()) ...[
                      Container(
                        padding: EdgeInsets.symmetric(
                          horizontal: isSmallScreen ? 6 : 8,
                          vertical: isSmallScreen ? 2 : 4,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          "${currentHighlightIndex + 1}/${highlightedMessages.length}",
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: isSmallScreen ? 10 : 12,
                          ),
                        ),
                      ),
                      SizedBox(width: isSmallScreen ? 4 : 8),
                    ],
                    IconButton(
                      constraints: BoxConstraints(
                        minWidth: isSmallScreen ? 32 : 36,
                        minHeight: isSmallScreen ? 32 : 36,
                      ),
                      padding: EdgeInsets.all(isSmallScreen ? 4 : 8),
                      icon: Icon(
                        Icons.keyboard_arrow_up_rounded,
                        color: white,
                        size: isSmallScreen ? 18 : 20,
                      ),
                      onPressed: () {
                        if (searchCont.text.isNotEmpty &&
                            hasHighlightedSearchValue()) {
                          double position = upPosition();
                          if (widget.onUpCall != null) {
                            widget.onUpCall!(position);
                          }
                        }
                      },
                    ),
                    IconButton(
                      constraints: BoxConstraints(
                        minWidth: isSmallScreen ? 32 : 36,
                        minHeight: isSmallScreen ? 32 : 36,
                      ),
                      padding: EdgeInsets.all(isSmallScreen ? 4 : 8),
                      icon: Icon(
                        Icons.keyboard_arrow_down_rounded,
                        color: white,
                        size: isSmallScreen ? 18 : 20,
                      ),
                      onPressed: () {
                        if (searchCont.text.isNotEmpty &&
                            hasHighlightedSearchValue()) {
                          double position = downPosition();
                          if (widget.onDownCall != null) {
                            widget.onDownCall!(position);
                          }
                        }
                      },
                    ),
                    IconButton(
                      constraints: BoxConstraints(
                        minWidth: isSmallScreen ? 32 : 36,
                        minHeight: isSmallScreen ? 32 : 36,
                      ),
                      padding: EdgeInsets.all(isSmallScreen ? 4 : 8),
                      icon: Icon(
                        Icons.close,
                        color: white,
                        size: isSmallScreen ? 18 : 20,
                      ),
                      onPressed: clearSearch,
                    ),
                  ],
                ),
                width: isSearch ? searchWidth : 50,
              );
            }),
        ]
      ],
      backgroundColor: context.primaryColor,
    );
  }

  void blockMessage() async {
    List<DocumentReference> temp = [];
    await userService.userByEmail(getStringAsync(userEmail)).then((value) {
      temp = value.blockedTo!;
    });
    if (!temp.contains(userService.ref!.doc(widget.receiverUser!.uid))) {
      temp.add(userService.getUserReference(
          uid: widget.receiverUser!.uid.validate()));
    }
    userService.blockUser({"blockedTo": temp}).then((value) {
      finish(context);
      finish(context);
      finish(context);
    }).catchError((e) {
      //
    });
  }

  void reportBy() async {
    List<DocumentReference> temp = [];
    temp = await userService
        .userByEmail(widget.receiverUser!.email)
        .then((value) => value.reportedBy!);
    if (!temp.contains(userService.ref!.doc(getStringAsync(userId)))) {
      temp.add(userService.getUserReference(uid: getStringAsync(userId)));
    }
    if (temp.length >= appSettingStore.mReportCount) {
      userService.reportUser({"isActive": false},
          widget.receiverUser!.uid.validate()).then((value) {
        finish(context);
        finish(context);
        finish(context);
        toast("UserAccountIsDeactivatedByAdminToRestorePleaseContactAdmin"
            .translate);
        toast(value.toString());
      }).catchError((e) {
        //
      });
    } else {
      userService.reportUser({"reportedBy": temp},
          widget.receiverUser!.uid.validate()).then((value) {
        finish(context);
        finish(context);
        finish(context);
        toast(value.toString());
      }).catchError((e) {
        //
      });
    }
  }
}
