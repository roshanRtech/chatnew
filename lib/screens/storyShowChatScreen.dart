import 'package:chat/models/StoryModel.dart';
import 'package:chat/utils/AppColors.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:nb_utils/nb_utils.dart';
import 'package:story_view/story_view.dart';
import 'package:url_launcher/url_launcher.dart';

import '../utils/AppConstants.dart';

import '../../utils/TextStyles.dart' as TS;

class storyShowChatScreen extends StatefulWidget {
  final List<StoryModel>? list;
  final String? userName;
  final Timestamp? time;
  final String? userImg;

  storyShowChatScreen({this.list, this.userName, this.time, this.userImg});

  @override
  _storyShowChatScreenState createState() => _storyShowChatScreenState();
}

class _storyShowChatScreenState extends State<storyShowChatScreen> {
  final StoryController controller = StoryController();
  String userIdS = "";
  bool? currantUser = false;
  ValueNotifier<String?> statusTime = ValueNotifier(null);
  TextEditingController replyController = TextEditingController();

  List<StoryModel> storyItems = [];
  int currentStoryIndex = 0;
  int currentStatusIndex = 0;
  var receiverUserId = '';

  @override
  void initState() {
    super.initState();
    print("-----------37${widget.userName}");
    print("-----------37${widget.userImg}");
    init();
    receiverUserId = widget.list?.first.userId ?? '';
  }


  Future<void> init() async {
    userIdS = getStringAsync(userId);
    initializeStoryItems();
    setState(() {});
  }

  void initializeStoryItems() async {
    if (widget.list != null) {
      for (var e in widget.list ?? []) {
        if (e.userId == getStringAsync(userId)) {
          currantUser = true;
        }

        if (e.statusPrivacyIndex == 2 && e.includedUserList != null && e.includedUserList!.contains(userIdS)) {
          storyItems.add(e);
          continue;
        }

        if (e.statusPrivacyIndex == 1 && e.excludedUserList != null && e.excludedUserList!.contains(userIdS)) {
          continue;
        }

        if (e.userId == getStringAsync(userId)) {
          storyItems.add(e);
          continue;
        }

        if (e.excludedUserList!.isEmpty && e.includedUserList!.isEmpty) {
          storyItems.add(e);
          continue;
        }
      }
      buildStoryItemsFromModel(storyItems);
      //this.storyItems = storyItems;
      setState(() {});
    } else {
      storyItems = [];
    }
  }

  StoryModel? storyModel;

  @override
  void setState(fn) {
    if (mounted) super.setState(fn);
  }

  @override
  void dispose() {
    controller.dispose();
    replyController.dispose();
    super.dispose();
  }

  List<StoryItem> buildStoryItemsFromModel(List<StoryModel> storyItems) {
    return storyItems.map((story) {
      if (story.type == "text") {
        final text = story.caption ?? '';
        print("-------106>>${text}");

        final linkRegex = RegExp(r'(https?:\/\/[^\s]+)');
        final matches = linkRegex.allMatches(text);

        final spans = <TextSpan>[];
        int currentIndex = 0;

        for (final match in matches) {
          if (match.start > currentIndex) {
            spans.add(TextSpan(text: text.substring(currentIndex, match.start)));
          }

          final url = match.group(0)!;
          spans.add(
            TextSpan(
              text: url,
              style: TS.boldTextStyle(
                color: Colors.blue,
                decoration: TextDecoration.underline,
              ),
              recognizer: TapGestureRecognizer()
                ..onTap = () async {
                  final uri = Uri.parse(url);
                  if (await canLaunchUrl(uri)) {
                    await launchUrl(uri, mode: LaunchMode.externalApplication);
                  }
                },
            ),
          );

          currentIndex = match.end;
        }

        if (currentIndex < text.length) {
          spans.add(TextSpan(text: text.substring(currentIndex)));
        }

        return StoryItem.text(
          title: story.caption ?? '',
          backgroundColor: Color(story.backgroundColor ?? 0xFF9C27B0),
          textStyle: TS.secondaryTextStyle(),
        );
      } else if (story.type == "video") {
        var videoDuration = story.videoDuration.toInt();
        print("----112>>>${videoDuration}");
        return StoryItem.pageVideo(
          story.imagePath ?? '',
          imageFit: BoxFit.cover,
          controller: controller,
          duration: Duration(seconds: (videoDuration > 30 ? 30 : videoDuration)),
        );
      } else {
        return StoryItem.pageImage(
          url: story.imagePath ?? '',
          controller: controller,
        );
      }
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          StoryView(
            indicatorForegroundColor: primaryColor,
            indicatorHeight: IndicatorHeight.small,
            onComplete: () {
              finish(context);
            },
            onStoryShow: (v, index) async {

            },
            controller: controller,
            storyItems: buildStoryItemsFromModel(storyItems),
          ),
          Positioned(
              top: MediaQuery.of(context).size.height * 0.07,
              left: 10,
              child: Row(
                children: [
                  GestureDetector(
                      onTap: () {
                        finish(context);
                      },
                      child: Icon(Icons.arrow_back, color: Colors.white)),
                  15.width,
                  ClipRRect(
                    borderRadius: BorderRadius.circular(100),
                    child: Image.network(
                      !widget.userImg.isEmptyOrNull
                          ? widget.userImg ?? ''
                          : "https://www.fagerhult.com/cdn-cgi/image/width=525,quality=80,fit=scale-down,onerror=redirect/assets/images/no-image-available.jpg",
                      fit: BoxFit.cover,
                      width: 45,
                      height: 45,
                      loadingBuilder: (context, child, loadingProgress) {
                        if (loadingProgress == null) return child;
                        return Center(
                          child: CircularProgressIndicator(
                            color: primaryColor,
                            value: loadingProgress.expectedTotalBytes != null ? loadingProgress.cumulativeBytesLoaded / (loadingProgress.expectedTotalBytes ?? 1) : null,
                          ),
                        );
                      },
                      errorBuilder: (context, error, stackTrace) {
                        return Icon(Icons.error, color: Colors.red);
                      },
                    ),
                  ),
                  10.width,
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(widget.userName ?? '', style: TS.boldTextStyle(color: Colors.white)),
                      4.height,
                      ValueListenableBuilder<String?>(
                        valueListenable: statusTime,
                        builder: (context, value, _) {
                          return Text(
                            value ?? '',
                            style: TS.secondaryTextStyle(color: Colors.white),
                          );
                        },
                      ),
                    ],
                  ),
                ],
              )),
        ],
      ),
    );
  }


}
