import 'dart:io';

import 'package:chat/utils/AppCommon.dart';
import 'package:flutter/material.dart';
import 'package:nb_utils/nb_utils.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import 'package:chat/centralized_import.dart';

import '../../utils/TextStyles.dart' as TS;

import 'package:http/http.dart' as http;

import 'package:path/path.dart' as path;

class SelectedMessageComponentDialog extends StatefulWidget {
  final bool isGroup;

  final ChatMessageModel? data;
  final bool? isFromMe;
  final String? mId;
  final String? groupId;
  final String? senderId;
  final UserModel? userData;
  final bool? isAdminAV;
  final void Function()? onReply;
  final Function(String emoji, bool isGroup)? onReaction;

  SelectedMessageComponentDialog(this.isGroup, this.data, this.isFromMe,
      this.mId, this.senderId, this.isAdminAV, this.userData, this.onReply,
      {this.onReaction, super.key, this.groupId});

  @override
  State<SelectedMessageComponentDialog> createState() =>
      _SelectedMessageComponentDialogState();
}

class _SelectedMessageComponentDialogState
    extends State<SelectedMessageComponentDialog> {
  int currentIndex = 0;
  late List<Map<String, dynamic>> selectedMessageOptionList;

  @override
  void initState() {
    super.initState();
    init();
  }

  Future<void> init() async {
    print("----------40>>${widget.isAdminAV}");
    selectedMessageOptionList = [
      {'icon': Icons.forward_outlined, 'text': 'forward'.translate},
      {'icon': Icons.add_reaction, 'text': 'reaction'},
      {'icon': Icons.arrow_circle_right_outlined, 'text': 'reply'.translate},
      {'icon': Icons.share, 'text': 'share'},
      if (widget.data?.messageType == TEXT)
        {'icon': Icons.copy, 'text': 'copy'.translate},
      if (widget.data!.isMe! && widget.data?.messageType == TEXT)
        {'icon': Icons.edit, 'text': 'edit'.translate},
      if (widget.data!.isMe!)
        {'icon': Icons.delete, 'text': 'deleteForMe'.translate},
      if (widget.data!.isMe!)
        {
          'icon': Icons.delete_forever_rounded,
          'text': 'deleteForAll'.translate
        },
    ];
    currentIndex = getIntAsync(THEME_MODE_INDEX);
  }

  @override
  void setState(fn) {
    if (mounted) super.setState(fn);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: context.cardColor,
      width: context.width(),
      padding: EdgeInsets.symmetric(vertical: 8),
      child: ListView.builder(
        shrinkWrap: true,
        padding: EdgeInsets.all(0),
        itemCount: selectedMessageOptionList.length,
        itemBuilder: (BuildContext context, int index) {
          var item = selectedMessageOptionList[index];
          return ListTile(
            leading: item.containsKey('icon')
                ? Icon(item['icon'],
                    size: 22,
                    color: appStore.isDarkMode ? Colors.white : Colors.black)
                : Image.asset(
                    ic_forward,
                    color: appStore.isDarkMode ? Colors.white : Colors.black,
                    height: 18,
                    width: 18,
                  ),
            title: Text(selectedMessageOptionList[index]['text'],
                style: TS.primaryTextStyle()),

            // title: Text(selectedMessageOptionList[index], style: primaryTextStyle()),
            onTap: () async {
              if (selectedMessageOptionList[index]['text'] ==
                  'forward'.translate) {
                Navigator.pop(context);
                ForwardUserListScreen(
                  chatData: widget.data,
                  messageId: widget.data?.id,
                  receiverUser: widget.userData,
                ).launch(context);

                // finish(context);
              } else if (selectedMessageOptionList[index]['text'] ==
                  'reaction') {
                Navigator.pop(context);
                _showEmojiPicker(context, (emoji) {
                  widget.onReaction?.call(emoji ?? '', widget.isGroup);
                });
              } else if (selectedMessageOptionList[index]['text'] ==
                  'reply'.translate) {
                widget.onReply?.call();
                Navigator.pop(context);
              } else if (selectedMessageOptionList[index]['text'] ==
                  'deleteForMe'.translate) {
                await showConfirmDialogCustom(
                  context,
                  title: 'are_you_sure_want_to_delete_message'.translate,
                  positiveText: 'lbl_yes'.translate,
                  negativeText: 'lbl_no'.translate,
                  primaryColor: primaryColor,
                  onAccept: (v) {
                    hideKeyboard(context);
                    if (widget.isGroup) {
                      groupChatMessageService
                          .deleteGrpSingleMessageOnlyForMe(
                        groupDocId: widget.groupId,
                        messageDocId: widget.data?.id,
                      )
                          .then((value) {
                        //
                      }).catchError(
                        (e) {
                          log("Error:" + e.toString());
                        },
                      );
                    } else {
                      chatMessageService
                          .deleteSingleMessage(
                              senderId: widget.data?.senderId,
                              receiverId: widget.data!.receiverId!,
                              documentId: widget.data!.id)
                          .then((value) {
                        //
                      }).catchError(
                        (e) {
                          log(e.toString());
                        },
                      );
                    }
                  },
                );
                finish(context);
              } else if (selectedMessageOptionList[index]['text'] ==
                  'copy'.translate) {
                Navigator.pop(context);
                copyMessageFun(
                    msg: decryptedData(widget.data!.message.validate()));
              } else if (selectedMessageOptionList[index]['text'] ==
                  'deleteForAll'.translate) {
                await showConfirmDialogCustom(
                  context,
                  title: 'are_you_sure_want_to_delete_message'.translate,
                  positiveText: 'lbl_yes'.translate,
                  negativeText: 'lbl_no'.translate,
                  primaryColor: primaryColor,
                  onAccept: (v) {
                    if (widget.isGroup) {
                      groupChatMessageService
                          .deleteGrpSingleMessage(
                              groupDocId: widget.groupId,
                              messageDocId: widget.data!.id)
                          .then((value) {
                        //
                      }).catchError(
                        (e) {
                          log("Error:" + e.toString());
                        },
                      );
                    } else {
                      chatMessageService
                          .deleteSingleMessageForAll(
                              senderId: widget.data!.senderId!,
                              receiverId: widget.data!.receiverId!,
                              documentId: widget.data!.id.validate(),
                              doc2ID: widget.data!.id2.validate())
                          .then((value) {
                        //
                      }).catchError(
                        (e) {
                          log(e.toString());
                        },
                      );
                    }
                  },
                );
                finish(context);
              } else if (selectedMessageOptionList[index]['text'] ==
                  'edit'.translate) {
                Navigator.pop(context);
                showEditMessageDialog(
                  context,
                  decryptedData(widget.data!.message.validate()),
                  (p0) {
                    if (widget.isGroup) {
                      groupChatMessageService
                          .editMessage(
                              groupChatId: getStringAsync(CURRENT_GROUP_ID),
                              message: encryptData(p0),
                              documentId: widget.data!.id.validate())
                          .then((value) {
                        //
                      }).catchError(
                        (e) {
                          log("Error:" + e.toString());
                        },
                      );
                    } else {
                      chatMessageService
                          .editMessage(
                              message: encryptData(p0),
                              docId2: widget.data!.id2.validate(),
                              documentId: widget.data!.id.validate(),
                              senderId: widget.data!.senderId.validate(),
                              receiverId: widget.data!.receiverId!)
                          .then((value) {
                        //
                      }).catchError(
                        (e) {
                          log("Error:" + e.toString());
                        },
                      );
                    }
                  },
                );
              } else if (selectedMessageOptionList[index]['text'] == 'share') {
                Navigator.pop(context);
                try {
                  String shareText = '';
                  List<XFile> shareFiles = [];

                  print("Chat Model JSON ${widget.data?.toJson()}");

                  if (widget.data!.messageType == MessageType.TEXT.name) {
                    shareText = widget.data!.isEncrypt!
                        ? decryptedData(widget.data!.message.validate())
                        : widget.data!.message.validate();
                  } else if ([
                    MessageType.IMAGE.name,
                    MessageType.VIDEO.name,
                    MessageType.DOC.name
                  ].contains(widget.data!.messageType)) {
                    if (widget.data!.photoUrl.isEmptyOrNull) {
                      toast('No file available to share');
                      return;
                    }

                    final uri = Uri.parse(widget.data!.photoUrl.validate());
                    final fileName = path.basename(uri.path);

                    final response = await http.get(uri);
                    if (response.statusCode != 200) {
                      return;
                    }

                    // Save file to temporary directory
                    final tempDir = await getTemporaryDirectory();
                    final tempFile = File('${tempDir.path}/$fileName');
                    await tempFile.writeAsBytes(response.bodyBytes);
                    print(
                        "Temp file path: ${tempFile.path}, exists: ${await tempFile.exists()}");

                    if (!await tempFile.exists()) {
                      return;
                    }

                    final xFile = XFile(tempFile.path);
                    shareFiles = [xFile];

                    final shareResult = await Share.shareXFiles(
                      shareFiles,
                      subject: 'Shared from ${AppName}',
                    );

                    if (shareResult.status == ShareResultStatus.success) {
                      await tempFile.delete();
                    } else {
                      print("Share status: ${shareResult.status}");
                    }
                  } else {
                    return;
                  }

                  // Share text if no files
                  if (shareFiles.isEmpty && shareText.isNotEmpty) {
                    await Share.share(shareText,
                        subject: 'Shared from ${AppName}');
                  }
                } catch (e) {
                  print("Share error: $e");
                }
              }

              // else if (selectedMessageOptionList[index]['text'] == 'Search') {}
            },
          );
        },
      ),
    );
  }
}

void _showEmojiPicker(
    BuildContext context, Function(String? emoji) onSelected) {
  final overlay = Overlay.of(context);
  OverlayEntry? entry;
  String? selectedEmoji;
  bool expanded = false;
  entry = OverlayEntry(
    builder: (context) => GestureDetector(
      behavior: HitTestBehavior.translucent,
      onTap: () {
        entry?.remove();
      },
      child: Stack(
        children: [
          StatefulBuilder(
            builder: (context, setState) => Positioned(
              bottom: 120,
              left: 40,
              right: 40,
              child: Material(
                color: Colors.transparent,
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    maxHeight: MediaQuery.of(context).size.height * 0.3,
                  ),
                  child: SingleChildScrollView(
                    child: Container(
                      padding: EdgeInsets.all(5),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(30),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black26,
                            blurRadius: 8,
                            spreadRadius: 2,
                          )
                        ],
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          /// Main Row (Quick Reactions + Plus)
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              ...["👍", "❤️", "😂", "😮"].map((emoji) {
                                final isSelected = selectedEmoji == emoji;
                                return GestureDetector(
                                  onTap: () {
                                    setState(() {
                                      if (isSelected) {
                                        selectedEmoji = null;
                                      } else {
                                        selectedEmoji = emoji;
                                      }
                                    });
                                    onSelected(selectedEmoji);
                                    entry?.remove();
                                  },
                                  child: Container(
                                    margin: EdgeInsets.symmetric(horizontal: 5),
                                    padding: EdgeInsets.all(5),
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      color: isSelected
                                          ? Colors.blue.withOpacity(0.2)
                                          : Colors.transparent,
                                    ),
                                    child:
                                        Text(emoji, style: TS.boldTextStyle()),
                                  ),
                                );
                              }).toList(),

                              /// ➕ button at the end
                              GestureDetector(
                                onTap: () {
                                  setState(() {
                                    expanded = !expanded;
                                  });
                                },
                                child: Container(
                                  margin: EdgeInsets.only(left: 6),
                                  padding: EdgeInsets.all(6),
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: Colors.grey.shade200,
                                  ),
                                  child: Icon(
                                    expanded ? Icons.close : Icons.add,
                                    size: 22,
                                    color: Colors.black54,
                                  ),
                                ),
                              ),
                              GestureDetector(
                                onTap: () {
                                  onSelected(null);
                                  entry?.remove();
                                },
                                child: Container(
                                  margin: EdgeInsets.only(left: 5),
                                  padding: EdgeInsets.all(5),
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: Colors.grey.shade200,
                                  ),
                                  child: Icon(
                                    Icons.delete,
                                    size: 22,
                                    color: Colors.black54,
                                  ),
                                ),
                              ),
                            ],
                          ),

                          /// Expanded Grid of All Emojis
                          if (expanded)
                            Container(
                              margin: EdgeInsets.only(top: 10),
                              height: 150, // fixed height for grid
                              child: GridView.count(
                                crossAxisCount: 6,
                                shrinkWrap: true,
                                physics: AlwaysScrollableScrollPhysics(),
                                children: [
                                  "😀",
                                  "😁",
                                  "😂",
                                  "🤣",
                                  "😅",
                                  "😊",
                                  "😍",
                                  "😘",
                                  "😎",
                                  "😢",
                                  "😭",
                                  "😡",
                                  "👍",
                                  "👎",
                                  "👏",
                                  "🙏",
                                  "🔥",
                                  "❤️",
                                ].map((emoji) {
                                  final isSelected = selectedEmoji == emoji;
                                  return GestureDetector(
                                    onTap: () {
                                      setState(() {
                                        if (isSelected) {
                                          selectedEmoji = null;
                                        } else {
                                          selectedEmoji = emoji;
                                        }
                                      });
                                      onSelected(selectedEmoji);
                                      entry?.remove();
                                    },
                                    child: Container(
                                      margin: EdgeInsets.all(4),
                                      decoration: BoxDecoration(
                                        shape: BoxShape.circle,
                                        color: isSelected
                                            ? Colors.blue.withOpacity(0.2)
                                            : Colors.transparent,
                                      ),
                                      alignment: Alignment.center,
                                      child: Text(emoji,
                                          style: TS.boldTextStyle()),
                                    ),
                                  );
                                }).toList(),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    ),
  );

  overlay.insert(entry);
}

Future<void> showEditMessageDialog(BuildContext context, String initialMessage,
    Function(String) onEdit) async {
  TextEditingController _controller =
      TextEditingController(text: initialMessage);
  return showDialog<void>(
    context: context,
    builder: (BuildContext context) {
      return AlertDialog(
        title: Text(
          'editMessage'.translate,
          style: TS.secondaryTextStyle(),
        ),
        content: AppTextField(
          controller: _controller,
          decoration: InputDecoration(
              labelStyle: TS.secondaryTextStyle(), hintText: ''),
          textFieldType: TextFieldType.MULTILINE,
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () {
              Navigator.of(context).pop(); // Close dialog
            },
            child: Text(
              'cancel'.translate,
              style: TS.boldTextStyle(color: primaryColor),
            ),
          ),
          MaterialButton(
            onPressed: () {
              onEdit(_controller.text); // Pass new text to callback
              Navigator.of(context).pop(); // Close dialog
            },
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            color: primaryColor,
            child: Text('edit'.translate,
                style: TS.boldTextStyle(color: Colors.white)),
          ),
        ],
      );
    },
  );
}
