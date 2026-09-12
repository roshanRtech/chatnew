import 'package:flutter/material.dart';
import 'package:nb_utils/nb_utils.dart';

import 'package:chat/centralized_import.dart';

import '../../utils/TextStyles.dart' as TS;

class ChatOptionDialog extends StatefulWidget {
  final bool isGroup;
  final UserModel? receiverUser;
  final bool? isFromArchive;
  final String? groupId;
  final ContactModel? data;

  ChatOptionDialog(
      {this.receiverUser,
      this.isGroup = false,
      this.isFromArchive,
      this.groupId,
      this.data});

  @override
  ChatOptionDialogState createState() => ChatOptionDialogState();
}

class ChatOptionDialogState extends State<ChatOptionDialog> {
  List<String> chatOptionList = [];

  int currentIndex = 0;

  UserModel sender = UserModel(
    name: getStringAsync(userDisplayName),
    photoUrl: getStringAsync(userPhotoUrl),
    uid: getStringAsync(userId),
    oneSignalPlayerId: getStringAsync(playerId),
  );

  @override
  void initState() {
    super.initState();
    init();
  }

  Future<void> init() async {
    currentIndex = getIntAsync(THEME_MODE_INDEX);
    chatOptionList = [
      'clear_chat'.translate,
      'delete_chat'.translate,
      !(widget.isFromArchive ?? false)
          ? 'archive_chat'.translate
          : 'un_archive_chat'.translate
    ];
    setState(() {});
  }

  @override
  void setState(fn) {
    if (mounted) super.setState(fn);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: context.width(),
      padding: EdgeInsets.symmetric(vertical: 8),
      child: ListView.builder(
        shrinkWrap: true,
        padding: EdgeInsets.all(0),
        itemCount: chatOptionList.length,
        itemBuilder: (BuildContext context, int index) {
          return ListTile(
            onTap: () async {
              if (chatOptionList[index] == 'clear_chat'.translate) {
                await showConfirmDialogCustom(context,
                    dialogAnimation: DialogAnimation.SCALE,
                    title: "chat_cleared".translate,
                    positiveText: 'lbl_yes'.translate,
                    negativeText: 'lbl_no'.translate,
                    primaryColor: primaryColor, onAccept: (v) {
                  appStore.setLoading(true);
                  if (widget.isGroup) {
                    groupChatMessageService
                        .clearAllMessages(
                            groupDocId: widget.groupId,
                            deleteForUser: getStringAsync(userId))
                        .then((value) {
                      chatMessageService
                          .deleteGroupChat(
                              groupId: widget.groupId!,
                              userId: getStringAsync(userId))
                          .then(
                        (value) {
                          hideKeyboard(context);
                          appStore.setLoading(false);
                          toast("chat_clear".translate);
                          setValue(CURRENT_GROUP_ID, '');
                          finish(context);
                        },
                      );
                    }).catchError((e) {
                      toast(e);
                    });
                  } else {
                    chatMessageService
                        .clearAllMessages(
                            senderId: sender.uid,
                            receiverId: widget.receiverUser!.uid!)
                        .then((value) {
                      chatMessageService
                          .deletePrivateChat(
                              senderId: sender.uid!,
                              receiverId: widget.receiverUser!.uid!)
                          .then(
                        (value) {
                          hideKeyboard(context);
                          appStore.setLoading(false);
                          toast("chat_clear".translate);
                          finish(context);
                        },
                      );
                    }).catchError((e) {
                      toast(e);
                    });
                  }
                });
              } else if (chatOptionList[index] == 'delete_chat'.translate) {
                await showConfirmDialogCustom(context,
                    dialogAnimation: DialogAnimation.SCALE,
                    title: "chat_cleared_deleted".translate,
                    positiveText: 'lbl_yes'.translate,
                    negativeText: 'lbl_no'.translate,
                    primaryColor: primaryColor, onAccept: (v) {
                  if (widget.isGroup) {
                    groupChatMessageService
                        .deleteChat(groupDocId: widget.groupId)
                        .then((value) {
                      toast("chat_deleted".translate);
                      hideKeyboard(context);
                      appStore.setLoading(false);
                      setValue(CURRENT_GROUP_ID, '');
                      chatMessageService.deleteGroupChat(
                          groupId: widget.groupId!,
                          userId: getStringAsync(userId));
                      finish(context);
                    }).catchError((e) {
                      toast(e);
                    });
                  } else {
                    chatMessageService
                        .deleteChat(
                            senderId: sender.uid,
                            receiverId: widget.receiverUser!.uid!)
                        .then((value) {
                      toast("chat_deleted".translate);
                      chatMessageService
                          .clearAllMessages(
                              senderId: sender.uid,
                              receiverId: widget.receiverUser!.uid!)
                          .then((value) {
                        chatMessageService.deletePrivateChat(
                            senderId: sender.uid!,
                            receiverId: widget.receiverUser!.uid!);
                      }).catchError((e) {
                        toast(e.toString());
                      });
                      hideKeyboard(context);
                      appStore.setLoading(false);
                      finish(context);
                    }).catchError((e) {
                      toast(e);
                    });
                  }
                });
              } else if (chatOptionList[index] == 'archive_chat'.translate) {
                UserModel userModel = UserModel();
                userModel.isArchive = false;

                if (widget.isGroup) {
                  chatMessageService.addGroupChatToArchive(
                      groupId: widget.groupId!, userId: getStringAsync(userId));
                } else {
                  chatMessageService.addPrivateChatToArchive(
                      senderId: sender.uid!,
                      receiverId: widget.receiverUser!.uid!);
                }
                finish(context);
              } else if (chatOptionList[index] == 'un_archive_chat'.translate) {
                if (widget.isGroup) {
                  chatMessageService.removeGroupChatFromArchive(
                      groupId: widget.groupId!, userId: getStringAsync(userId));
                } else {
                  chatMessageService.removePrivateChatFromArchive(
                      senderId: sender.uid!,
                      receiverId: widget.receiverUser!.uid!);
                }
                finish(context, 'unarchived');
              } else {}
            },
            title: Text(chatOptionList[index], style: TS.primaryTextStyle()),
          );
        },
      ),
    );
  }
}
