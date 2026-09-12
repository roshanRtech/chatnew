import 'package:flutter/material.dart';
import 'package:flutter_mobx/flutter_mobx.dart';
import 'package:nb_utils/nb_utils.dart' hide AnimatedTextKit;

import 'package:chat/centralized_import.dart';

import '../../utils/TextStyles.dart' as TS;

class MyStoryListScreen extends StatefulWidget {
  final List<StoryModel>? list;

  MyStoryListScreen({this.list});

  @override
  MyStoryListScreenState createState() => MyStoryListScreenState();
}

class MyStoryListScreenState extends State<MyStoryListScreen> {
  @override
  void initState() {
    super.initState();
  }

  Future<void> deletePost({String? id, String? url}) async {
    appStore.setLoading(true);
    print("------------33>>>>${url}");
    await storyService.deleteStory(id: id, url: url).then((value) {
      appStore.setLoading(false);
      toast('remove_successfully'.translate);
      finish(context, true);
    }).catchError((e, s) {
      appStore.setLoading(false);
      print("------------39>>>>${e.toString()}");
      print("------------40>>>>${s.toString()}");
      toast(e.toString(), print: true);
    });
  }

  Future<void> deletePostText({String? id}) async {
    appStore.setLoading(true);
    await storyService.deleteStoryText(id: id).then((value) {
      appStore.setLoading(false);
      toast('remove_successfully'.translate);
      finish(context, true);
    }).catchError((e, s) {
      appStore.setLoading(false);
      print("------------39>>>>${e.toString()}");
      print("------------40>>>>${s.toString()}");
      toast(e.toString(), print: true);
    });
  }


  @override
  void setState(fn) {
    if (mounted) super.setState(fn);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: appBarWidget('my_status'.translate, textColor: Colors.white),
      body: Stack(
        children: [
          SingleChildScrollView(
            child: Column(
              children: [
                ListView.builder(
                    itemCount: widget.list?.length,
                    shrinkWrap: true,
                    padding: EdgeInsets.all(8),
                    physics: NeverScrollableScrollPhysics(),
                    itemBuilder: (_, i) {
                      StoryModel data = widget.list![i];
                      return Row(
                        children: [
                          Container(
                            height: 55,
                            width: 55,
                            margin: EdgeInsets.only(top: 4, bottom: 4),
                            decoration: BoxDecoration(
                              border: Border.all(color: primaryColor, width: 2),
                              borderRadius: radius(30),
                            ),
                            child: cachedImage(data.imagePath.validate(),
                                    fit: BoxFit.cover)
                                .cornerRadiusWithClipRRect(50),
                          ).onTap(() {
                            print('ddfgdfgdfgdfgdf');
                          }),
                          16.width,
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('my_status'.translate,
                                  style: TS.boldTextStyle()),
                              4.height,
                              Text(
                                  formatTime(data
                                      .createAt!.millisecondsSinceEpoch
                                      .validate()),
                                  style: TS.secondaryTextStyle()),
                            ],
                          ).expand(),
                          Column(
                            children: [
                              Row(
                                children: [
                                  PopupMenuButton<int>(
                                    color: appStore.isDarkMode
                                        ? scaffoldSecondaryDark
                                        : white,
                                    itemBuilder: (context) {
                                      return <PopupMenuEntry<int>>[
                                        PopupMenuItem(
                                            child: Text('delete'.translate,
                                                style: TS.primaryTextStyle(
                                                    color: appStore.isDarkMode
                                                        ? white
                                                        : black)),
                                            value: 0),
                                      ];
                                    },
                                    onSelected: (v) async {
                                      if (v == 0) {
                                        await showConfirmDialogCustom(context,
                                            dialogAnimation:
                                                DialogAnimation.SCALE,
                                            title: 'remove_story_confirmation'
                                                .translate,
                                            positiveText: 'lbl_yes'.translate,
                                            negativeText: 'lbl_no'.translate,
                                            primaryColor: primaryColor,
                                            onAccept: (v) {
                                          if (data.type == 'text') {
                                            deletePostText(id: data.id);
                                          } else {
                                            deletePost(
                                                id: data.id,
                                                url: data.imagePath);
                                          }
                                        });
                                      }
                                    },
                                  ),
                                ],
                              )
                            ],
                          )
                        ],
                      );
                    }),
                16.height,
                Text(
                  'your_status_update_will_disappear_after_24_hour'.translate,
                  style: TS.boldTextStyle(
                      color: textSecondaryColor, letterSpacing: 0.5),
                  textAlign: TextAlign.center,
                ).paddingSymmetric(horizontal: 16)
              ],
            ),
          ),
          Observer(builder: (_) => Loader().visible(appStore.isLoading)),
        ],
      ),
    );
  }
}
