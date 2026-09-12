import 'dart:async';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_mobx/flutter_mobx.dart';
import 'package:image_picker/image_picker.dart';
import 'package:nb_utils/nb_utils.dart' hide AnimatedTextKit;
import 'package:permission_handler/permission_handler.dart';
import 'package:video_player/video_player.dart';

import 'package:chat/centralized_import.dart';

import '../../utils/TextStyles.dart' as TS;

class StoriesScreen extends StatefulWidget {
  @override
  StoriesScreenState createState() => StoriesScreenState();
}

class StoriesScreenState extends State<StoriesScreen> {
  List<RecentStoryModel> recentStoryList = [];

  bool _isLoading = true;
  String? _error;

  File? imageFile;
  XFile? pickedFile;
  String? userImg;

  List<StoryModel> myStoryList = [];
  DateTime currentDate = DateTime.now();
  final ValueNotifier<bool> isCompressingNotifier = ValueNotifier(false);
  final ValueNotifier<double> progressNotifier = ValueNotifier(0.0);
  final ValueNotifier<String> currentFileNameNotifier = ValueNotifier('');
  double videoDurationMs = 0.0;
  final ValueNotifier<List<File>> compressedVideosNotifier =
      ValueNotifier<List<File>>([]);
  final ValueNotifier<int> currentVideoIndexNotifier = ValueNotifier<int>(0);

  Future<File> selectImages() async {
    FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.image, allowCompression: true, compressionQuality: 70);
    return File(result?.files.single.path ?? '');
  }

  Future<void> fetchStoriesOnce() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      storyService.getAllStory().listen((stories) {
        _processStories(stories);
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _processStories(List<StoryModel> stories) {
  if (!mounted) return;

  setState(() {
    myStoryList.clear();
    recentStoryList.clear();

    final currentUserId = getStringAsync(userId);
    final now = DateTime.now();

    // Grouping map: userId → RecentStoryModel
    final Map<String, RecentStoryModel> groupedStories = {};

    for (final element in stories) {
      final storyDate = element.createAt?.toDate();

      // Remove expired stories (not from today)
      if (storyDate == null ||
          storyDate.day != now.day ||
          storyDate.month != now.month ||
          storyDate.year != now.year) {
        if (element.id != null) {
          storyService.removeDocument(element.id!);
          storyService.deleteStory(id: element.id!, url: element.imagePath);
        }
        continue;
      }

      // Stories of the current user
      if (element.userId == currentUserId) {
        element.includedUserList =
            List<String>.from(appStore.includedSelectedUserList);
        element.excludedUserList =
            List<String>.from(appStore.excludedSelectedUserList);

        myStoryList.add(element);
        continue;
      }

      // Stories of other users → group by userId
      if (!groupedStories.containsKey(element.userId)) {
        groupedStories[element.userId!] = RecentStoryModel(
          userId: element.userId,
          userName: element.userName,
          userImgPath: element.userImgPath,
          createAt: element.createAt,
          updatedAt: element.updatedAt,
          excludedUserList: element.excludedUserList,
          includedUserList: element.includedUserList,
          list: [],
        );
      }

      // Add story to that user's list
      groupedStories[element.userId]!.list!.add(element);
    }

    // Convert map to list
    recentStoryList = groupedStories.values.toList();
  });
}

 
  @override
  void initState() {
    super.initState();
    fetchStoriesOnce();
  }

  @override
  void setState(fn) {
    if (mounted) super.setState(fn);
  }

  Widget buildStoryContent() {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          myStatusWidget(data: myStoryList),
          16.height,
          if (recentStoryList.isNotEmpty) ...[
            Text('recent_stories'.translate, style: TS.secondaryTextStyle())
                .paddingSymmetric(horizontal: 16),
            16.height,
            StoryListWidget(recentStoryList),
          ] else
            noDataFound(text: 'no_story_available'.translate),
        ],
      ),
    );
  }

  Widget myStatusWidget({List<StoryModel>? data}) {
    return Stack(
      children: [
        Row(
          children: [
            data!.isNotEmpty
                ? Container(
                    height: 55,
                    width: 55,
                    margin: EdgeInsets.only(top: 4, bottom: 4),
                    decoration: BoxDecoration(
                      border: Border.all(color: primaryColor, width: 2),
                      borderRadius: radius(30),
                    ),
                    child: cachedImage(data.first.imagePath.validate(),
                            fit: BoxFit.cover)
                        .cornerRadiusWithClipRRect(50),
                  )
                : SizedBox(
                    height: 55,
                    width: 55,
                    child: Stack(
                      alignment: Alignment.bottomRight,
                      children: [
                        !loginStore.mPhotoUrl.validate().isEmptyOrNull
                            ? cachedImage(loginStore.mPhotoUrl.validate(),
                                    height: 55, width: 55, fit: BoxFit.cover)
                                .cornerRadiusWithClipRRect(50)
                            : CircleAvatar(
                                backgroundColor:
                                    getColorFromString(getStringAsync(userId)),
                                radius: 28,
                                child: Text(
                                    loginStore.mDisplayName.validate()[0],
                                    style: TS.primaryTextStyle(
                                        color: Colors.white)),
                              ),
                        Container(
                          height: 20,
                          width: 20,
                          decoration: boxDecorationWithShadow(
                              boxShape: BoxShape.circle,
                              backgroundColor: whiteColor),
                          child: Icon(Icons.add, size: 18, color: Colors.black),
                        )
                      ],
                    ),
                  ),
            16.width,
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('my_status'.translate, style: TS.boldTextStyle()),
                4.height,
                Text(
                    data.isEmpty
                        ? 'add_Story'.translate
                        : formatTime(data.first.createAt!.millisecondsSinceEpoch
                            .validate()),
                    style: TS.secondaryTextStyle()),
              ],
            ).expand(),
            if (data.isNotEmpty) ...[
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      IconButton(
                          icon: Icon(Icons.more_vert),
                          padding: EdgeInsets.zero,
                          onPressed: () async {
                            bool? res = await MyStoryListScreen(list: data)
                                .launch(context);
                            if (res != null) {
                              setState(() {});
                            }
                          }),
                    ],
                  ),
                ],
              ),
            ]
          ],
        ).paddingAll(16).onTap(() async {
          if (data.isNotEmpty) {
            for (var story in data) {
              String? image = await story.userImgPath;
              if (!image.isEmptyOrNull) {
                userImg = image;
                break;
              }
            }

            final sortedList = [...data]..sort(
                (a, b) => a.createAt!.compareTo(b.createAt!),
              );

            StoryListScreen(
              list: sortedList,
              userName: data.first.userName,
              time: data.first.createAt,
              userImg: userImg,
              oneSignalkey: data.first.oneSignalKey,
              isStoryItemShow: false,
            ).launch(context);
          } else {
            _showBottomSheet(context);
          }
        }),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Observer(
      builder: (context) {
        appLocalizations = AppLocalizations.of(context);
        return Scaffold(
          body: Column(
            children: [
              if (_isLoading)
                Loader().center().expand()
              else if (_error != null)
                Text('Error: $_error', style: TS.boldTextStyle()).center()
              else
                buildStoryContent(),
            ],
          ),
          floatingActionButton: Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  SizedBox(
                    height: 50,
                    width: 50,
                    child: FloatingActionButton(
                      backgroundColor: primaryColor,
                      child: Image.asset('assets/Icons/pen.png',
                          height: 20, width: 20, color: Colors.white),
                      onPressed: () async {
                        StatusEditorScreen().launch(context,
                            pageRouteAnimation:
                                PageRouteAnimation.SlideBottomTop,
                            duration: 250.milliseconds);
                      },
                    ),
                  ),
                  15.height,
                  FloatingActionButton(
                    backgroundColor: primaryColor,
                    child: Image.asset('assets/Icons/video.png',
                        height: 25, width: 25, color: Colors.white),
                    onPressed: () async {
                      _showVideoBottomSheet(context);
                    },
                  ),
                  15.height,
                  FloatingActionButton(
                    backgroundColor: primaryColor,
                    child: Image.asset('assets/Icons/ic_camera.png',
                        height: 25, width: 25, color: Colors.white),
                    onPressed: () async {
                      _showBottomSheet(context);
                    },
                  ),
                ],
              )
            ],
          ),
        );
      },
    );
  }

  Future<void> pickVideoOnly() async {
    FilePickerResult? result = await FilePicker.platform.pickFiles(
      type: FileType.video,
      allowMultiple: false,
    );

    if (result == null || result.files.isEmpty) return;

    final file = result.files.first;
    final inputPath = file.path ?? '';
    final selectedFile = File(inputPath);

    if (!await selectedFile.exists()) {
      Fluttertoast.showToast(msg: 'Selected video file not found.');
      return;
    }

    print("Selected video: ${selectedFile.path}");

    // Example: directly launch video attachment or handle next step
    bool? res = await (SelectedAttachmentComponent(
      file: selectedFile,
      statusType: 'video',
      isStory: true,
      isVideo: true,
    ).launch(context));

    if (res == true) {
      print("Video selected successfully.");
    } else {
      print("Video selection canceled or failed.");
    }
  }

  Future<void> pickImageOnly() async {
    FilePickerResult? result = await FilePicker.platform.pickFiles(
      type: FileType.image,
      allowMultiple: false,
    );

    if (result == null || result.files.isEmpty) return;

    final file = result.files.first;
    final inputPath = file.path ?? '';
    final selectedFile = File(inputPath);

    if (!await selectedFile.exists()) {
      Fluttertoast.showToast(msg: 'Selected image file not found.');
      return;
    }

    print("Selected image: ${selectedFile.path}");

    bool? res = await (SelectedAttachmentComponent(
      file: selectedFile,
      statusType: 'image',
      isStory: true,
    ).launch(context));

    if (res == true) {
      setState(() {});
    } else {
      print("Image selection canceled or failed.");
    }
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

  Future<void> _getVideoFromCamera() async {
    final cameraPermission =
        await _checkAndRequestCameraPermission('lblVideo'.translate);
    if (!cameraPermission) {
      _showPermissionPermanentlyDeniedDialog('lblVideo'.translate);
      return;
    }

    final pickedFile =
        await ImagePicker().pickVideo(source: ImageSource.camera);
    if (pickedFile == null) return;

    final inputPath = pickedFile.path;
    final videoFile = File(inputPath);

    if (!await videoFile.exists()) {
      Fluttertoast.showToast(msg: 'Video file not found.');
      return;
    }

    final controller = VideoPlayerController.file(videoFile);
    await controller.initialize();

    controller.dispose();

    print("Selected video from camera: ${videoFile.path}");

    bool? res = await (SelectedAttachmentComponent(
      file: videoFile,
      statusType: 'video',
      isStory: true,
      isVideo: true,
    ).launch(context));

    if (res == true) {
      print("Video successfully captured and selected.");
    } else {
      print("Video capture canceled or failed.");
    }
  }

  Future<void> _getFromCamera() async {
    final cameraPermission =
        await _checkAndRequestCameraPermission('camera'.translate);
    if (!cameraPermission) {
      _showPermissionPermanentlyDeniedDialog('camera'.translate);
      return;
    }

    pickedFile = await ImagePicker().pickImage(
      source: ImageSource.camera,
      maxWidth: 1800,
      maxHeight: 1800,
      imageQuality: 100,
    );

    if (pickedFile == null) return;

    File capturedImage = File(pickedFile!.path);

    if (!await capturedImage.exists()) {
      Fluttertoast.showToast(msg: 'Captured image not found.');
      return;
    }

    print("Captured image from camera: ${capturedImage.path}");

    bool? res = await SelectedAttachmentComponent(
      file: capturedImage,
      statusType: 'image',
      isStory: true,
    ).launch(context);

    if (res == true) {
      setState(() {});
    } else {
      print("Image capture canceled or failed.");
    }
  }

  // _getFromCamera() async {
  //   final cameraPermission =
  //       await _checkAndRequestCameraPermission('camera'.translate);
  //   if (!cameraPermission) {
  //     _showPermissionPermanentlyDeniedDialog('camera'.translate);
  //     return;
  //   }
  //
  //   pickedFile = await ImagePicker().pickImage(
  //     source: ImageSource.camera,
  //     maxWidth: 1800,
  //     maxHeight: 1800,
  //     imageQuality: 100,
  //   );
  //
  //   if (pickedFile != null) {
  //     File originalFile = File(pickedFile?.path ?? '');
  //     String fileName = path.basenameWithoutExtension(originalFile.path);
  //     String extension = path.extension(originalFile.path);
  //
  //     Directory tempDir = await getTemporaryDirectory();
  //     String outputPath =
  //         path.join(tempDir.path, '${fileName}_compressed.${extension}');
  //     showDialog(
  //       context: context,
  //       barrierDismissible: false,
  //       builder: (_) => const Center(child: CircularProgressIndicator()),
  //     );
  //
  //     String ffmpegCmd =
  //         '-i "${originalFile.path}" -vf "scale=iw*0.5:ih*0.5" -qscale:v 5 "$outputPath"';
  //
  //     await FFmpegKit.executeAsync(ffmpegCmd, (session) async {
  //       final returnCode = await session.getReturnCode();
  //
  //       Navigator.pop(context);
  //
  //       if (ReturnCode.isSuccess(returnCode)) {
  //         imageFile = File(outputPath);
  //         bool? res = await SelectedAttachmentComponent(
  //           file: imageFile,
  //           statusType: 'image',
  //           isStory: true,
  //         ).launch(context);
  //
  //         if (res == true) {
  //           setState(() {});
  //         }
  //       } else {
  //         print('Compression failed: ${await session.getOutput()}');
  //         ScaffoldMessenger.of(context).showSnackBar(
  //           const SnackBar(content: Text('Image compression failed')),
  //         );
  //       }
  //     });
  //   }
  // }

  void _showVideoBottomSheet(BuildContext context) {
    showModalBottomSheet<void>(
      backgroundColor: context.cardColor,
      context: context,
      builder: (BuildContext context) {
        return Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            SettingItemWidget(
              title: 'lblGallery'.translate,
              titleTextStyle: TS.boldTextStyle(),
              leading: Icon(Icons.image, color: primaryColor),
              onTap: () {
                // pickAndCompressVideos();
                pickVideoOnly();
                finish(context);
              },
            ),
            Divider(color: context.dividerColor),
            SettingItemWidget(
              title: 'camera'.translate,
              titleTextStyle: TS.boldTextStyle(),
              leading: Icon(Icons.camera, color: primaryColor),
              onTap: () {
                _getVideoFromCamera();
                finish(context);
              },
            ),
          ],
        ).paddingAll(16.0);
      },
    );
  }

  void _showBottomSheet(BuildContext context) {
    showModalBottomSheet<void>(
      backgroundColor: context.cardColor,
      context: context,
      builder: (BuildContext context) {
        return Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            SettingItemWidget(
              title: 'lblGallery'.translate,
              titleTextStyle: TS.boldTextStyle(),
              leading: Icon(Icons.image, color: primaryColor),
              onTap: () {
                // // _getFromGallery();
                // pickAndCompressImage();
                pickImageOnly();
                finish(context);
              },
            ),
            Divider(color: context.dividerColor),
            SettingItemWidget(
              title: 'camera'.translate,
              titleTextStyle: TS.boldTextStyle(),
              leading: Icon(Icons.camera, color: primaryColor),
              onTap: () {
                _getFromCamera();
                finish(context);
              },
            ),
          ],
        ).paddingAll(16.0);
      },
    );
  }
}
