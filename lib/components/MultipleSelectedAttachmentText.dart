import 'dart:io';

import 'package:chat/utils/TextStyles.dart';
import 'package:emoji_picker_flutter/emoji_picker_flutter.dart';
import 'package:flutter/material.dart';
import 'package:flutter_mobx/flutter_mobx.dart';
import 'package:nb_utils/nb_utils.dart' hide secondaryTextStyle;
import 'package:video_player/video_player.dart';

import 'package:chat/centralized_import.dart';


import '../../utils/TextStyles.dart' as TS;

class MultipleSelectedAttachmentText extends StatefulWidget {
  final List<File>? attachedFiles;
  final bool isImage;
  final bool isVideo;
  final bool isAudio;
  final UserModel? userModel;
  final bool isStory;

  MultipleSelectedAttachmentText({this.attachedFiles, this.isImage = false, this.isVideo = false, this.isAudio = false, this.userModel, this.isStory = false});

  @override
  _MultipleSelectedAttachmentTextState createState() => _MultipleSelectedAttachmentTextState();
}

class _MultipleSelectedAttachmentTextState extends State<MultipleSelectedAttachmentText> {
  PageController controller = PageController(initialPage: 0);
  PageController? videoPageController = PageController(initialPage: 0, keepPage: true);

  int videoIndex = 0;
  Duration pageTurnDuration = Duration(milliseconds: 500);
  Curve pageTurnCurve = Curves.ease;
  List<TextEditingController> messageCont = [];

  bool emojiShowing = false;
  bool emojiStickerShowing = false;

  VoidCallback? listener;
  VideoPlayerController? playerController;

  @override
  void initState() {
    super.initState();
    messageCont = List.generate(
      widget.attachedFiles?.length??0,
          (index) => TextEditingController(),
    );
    Future.delayed(Duration.zero).then((val) {
      init();
    });
  }

  init() async {
    afterBuildCreated(() async {
      if (widget.isVideo) {
        videoIndex = 0;
        await setupVideo(widget.attachedFiles![0]);
      } else if (widget.isAudio) {
        // uploadStory();
      }
    });
  }

  @override
  void setState(fn) {
    if (mounted) super.setState(fn);
  }

  Future<void> setupVideo(File file) async {
    if (file.existsSync()) {
      playerController = (VideoPlayerController.file(file)
        ..addListener(() => setState(() {}))
        ..setLooping(true)
        ..initialize().then((_) {
          log(playerController != null);
          playerController!.play();
        }));
      setState(() {});
    }
  }

  @override
  void dispose() {
    controller.dispose();
    videoPageController?.dispose();
    for (var c in messageCont) {
      c.dispose();
    }
    if (widget.isVideo) {
      playerController?.dispose();
      finish(context, <String>[]);
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    Widget showWidget() {
      return widget.isImage
          ? PageView.builder(
              itemCount: widget.attachedFiles?.length,
              onPageChanged: (pageIndex){
                hideKeyboard(context);
              },
              itemBuilder: (_, i) {
                return Container(
                  height: context.height(),
                  width: context.width(),
                  child: Stack(
                    children: [
                      Image.file(
                        widget.attachedFiles![i],
                        width: context.width(),
                        height: context.height(),
                      ),
                      SizedBox(height: 10),
                    Positioned(
                      bottom: emojiStickerShowing ? MediaQuery.of(context).size.height * 0.3 : 60,
                      left: 5,
                      right: 20,
                      child: Container(
                        height: 50,
                        alignment: Alignment.bottomCenter,
                        decoration: boxDecorationWithShadow(
                          borderRadius: BorderRadius.circular(20),
                          spreadRadius: 0,
                          blurRadius: 0,
                          backgroundColor: context.cardColor,
                        ),
                        padding: EdgeInsets.only(left: 0, right: 8),
                        child: Row(
                          children: [
                            IconButton(
                              icon: Icon(LineIcons.smiling_face_with_heart_eyes),
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
                              controller: messageCont[i],
                              textFieldType: TextFieldType.OTHER,
                              cursorColor: appStore.isDarkMode ? Colors.white : Colors.black,
                              textCapitalization: TextCapitalization.sentences,
                              keyboardType: TextInputType.multiline,
                              minLines: 1,
                              maxLines: 5,
                              onTap: () {
                                emojiStickerShowing = false;
                                setState(() {});
                              },
                              textInputAction: mIsEnterKey ? TextInputAction.send : TextInputAction.newline,
                              decoration: InputDecoration(
                                border: InputBorder.none,
                                hintText: 'lblMessage'.translate,
                                hintStyle: TS.secondaryTextStyle(),
                                isDense: true,
                              ),
                            ).expand(),
                          ],
                        ),
                        width: context.width(),
                      ), // Removed .expand() here
                    ),
                      if (emojiStickerShowing)
                        Positioned(
                          bottom: 0,
                          left: 0,
                          right: 0,
                          child: showEmojiBottomsheet(i),
                        ),
                    ],
                  ),
                );
              })
          : widget.isVideo
              ? PageView.builder(
                  controller: videoPageController,
                  itemCount: widget.attachedFiles?.length,
                  itemBuilder: (_, index) {
                    return playerController != null ? Stack(
                      children: [
                        VideoPlayer(playerController!),
                        Positioned(
                          bottom: emojiStickerShowing ? MediaQuery.of(context).size.height * 0.3 : 60,
                          left: 5,
                          right: 20,
                          child: Container(
                            height: 50,
                            alignment: Alignment.bottomCenter,
                            decoration: boxDecorationWithShadow(
                              borderRadius: BorderRadius.circular(20),
                              spreadRadius: 0,
                              blurRadius: 0,
                              backgroundColor: context.cardColor,
                            ),
                            padding: EdgeInsets.only(left: 0, right: 8),
                            child: Row(
                              children: [
                                IconButton(
                                  icon: Icon(LineIcons.smiling_face_with_heart_eyes),
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
                                  controller: messageCont[index],
                                  textFieldType: TextFieldType.OTHER,
                                  cursorColor: appStore.isDarkMode ? Colors.white : Colors.black,
                                  textCapitalization: TextCapitalization.sentences,
                                  keyboardType: TextInputType.multiline,
                                  minLines: 1,
                                  maxLines: 5,
                                  onTap: () {
                                    emojiStickerShowing = false;
                                    setState(() {});
                                  },
                                  textInputAction: mIsEnterKey ? TextInputAction.send : TextInputAction.newline,
                                  decoration: InputDecoration(
                                    border: InputBorder.none,
                                    hintText: 'lblMessage'.translate,
                                    hintStyle: secondaryTextStyle(size: 16),
                                    isDense: true,
                                  ),
                                ).expand(),
                              ],
                            ),
                            width: context.width(),
                          ), // Removed .expand() here
                        ),
                        if (emojiStickerShowing)
                          Positioned(
                            bottom: 0,
                            left: 0,
                            right: 0,
                            child: showEmojiBottomsheet(index),
                          ),
                      ],
                    ) : Offstage();
                  },
                  onPageChanged: (index) async {
                    setState(() {
                      playerController?.dispose();
                      videoIndex = index;
                    });
                    //
                    await Future.delayed(Duration(milliseconds: 500), () {
                      setupVideo(widget.attachedFiles![videoIndex]);
                    });
                  },
                )
              : widget.isAudio
                  ? CircularProgressIndicator(
                      color: primaryColor,
                    ).center()
                  : SizedBox();
    }

    return WillPopScope(
      onWillPop: () {
        return Future.value(true);
      },
      child: Scaffold(
        backgroundColor: Colors.black,
        appBar: !widget.isStory
            ? appBarWidget("${widget.userModel != null ? "sent_to".translate + " " + widget.userModel!.name.validate() : ''}",
                textColor: Colors.white,
                backWidget: Icon(Icons.arrow_back, color: Colors.white).onTap(() {
                  finish(context, <String>[]);
                }))
            : null,
        body: Container(
          height: context.height(),
          child: Stack(
            children: [
              showWidget(),
              Observer(builder: (_) => Loader().visible(appStore.isLoading)),
              if (widget.isStory)
                Positioned(
                  child: IconButton(
                    icon: Icon(Icons.close),
                    onPressed: () {
                      finish(context, <String>[]);
                    },
                  ),
                ),
              Align(
                alignment: isRTL ? Alignment.bottomLeft : Alignment.bottomRight,
                child: Container(
                  height: 55,
                  width: 55,
                  margin: EdgeInsets.only(right: 10),
                  padding: EdgeInsets.all(8),
                  decoration: BoxDecoration(shape: BoxShape.circle, color: primaryColor),
                  child: Icon(Icons.send, color: Colors.white),
                ).onTap(() {
                  print("--------45>>${widget.isStory}");
                  finish(context, messageCont.map((c) => c.text).toList());
      
                  /*if(widget.isStory==true){
                   uploadStory();
      
                  }*/
                }, borderRadius: BorderRadius.circular(50)),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget showEmojiBottomsheet(int index) {
    return Stack(
      alignment: Alignment.bottomCenter,
      children: [
        Container(
            child: Container(
          height: 255,
          width: context.width(),
          color: context.cardColor,
          constraints: BoxConstraints(maxHeight: 500),
          child: EmojiPicker(
            onEmojiSelected: (Category? category, Emoji emoji) {
              messageCont[index].text = messageCont[index].text + emoji.emoji;
            },
            config: Config(
              emojiViewConfig: EmojiViewConfig(columns: 8),
              categoryViewConfig: const CategoryViewConfig(),
            ),
          ),
        )),
      ],
    );
  }
}
