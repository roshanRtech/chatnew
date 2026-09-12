import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:flutter_mobx/flutter_mobx.dart';
import 'package:image_picker/image_picker.dart';
import 'package:nb_utils/nb_utils.dart';
import 'package:path/path.dart';

import 'package:chat/centralized_import.dart';

import '../../utils/TextStyles.dart' as TS;

class CreateGroupScreen1 extends StatefulWidget {
  @override
  CreateGroupScreen1State createState() => CreateGroupScreen1State();
}

class CreateGroupScreen1State extends State<CreateGroupScreen1> {
  final TextEditingController groupNameCont = TextEditingController();
  final TextEditingController groupDescCont = TextEditingController();

  XFile? image;
  String imageUrl = '';

  File? imageFile;
  XFile? pickedFile;

  List membersList = [];
  List<String> mPlayerIdsList = [];
  List<UserModel> userModelList = [];

  @override
  void initState() {
    super.initState();
    init();
  }

  Future<void> init() async {
    print('dfgdfgdfgdfgdf46');
    getMemberList();
  }

  getMemberList() {
    appStore.setLoading(false);
    userModelList.clear();
    List<String> data = getStringListAsync(selectedMember)!;
    data.forEach((element) async {
      UserModel userm = await userService.getUserById(val: element);
      userModelList.add(userm);
      if (userm.uid != getStringAsync(userId)) {
        if (!userm.oneSignalPlayerId.isEmptyOrNull) {
          mPlayerIdsList.add(userm.oneSignalPlayerId.toString());
          setState(() {});
        }
      }
      setState(() {});
    });
  }

  @override
  void setState(fn) {
    if (mounted) super.setState(fn);
  }

  Future<void> updateGroupProfileImg({File? profileImage}) async {
    appStore.isLoading = true;
    if (profileImage != null) {
      String fileName = basename(profileImage.path);
      Reference storageRef = FirebaseStorage.instance
          .ref()
          .child("$GROUP_PROFILE_IMAGE/$fileName");
      UploadTask uploadTask = storageRef.putFile(profileImage);
      await uploadTask.then((e) async {
        await e.ref.getDownloadURL().then((value) {
          imageUrl = value;
          setState(() {});
          log(value);
          appStore.isLoading = false;
        });
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.cardColor,
      appBar: appBarWidget(
        "",
        color: primaryColor,
        textColor: Colors.white,
        titleWidget: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            Text('lblNewgroup'.translate,
                style: TS.boldTextStyle(
                    color: Colors.white, size: 18, letterSpacing: 0.5)),
            4.height,
            Text('lblAddsubject'.translate,
                style: TS.secondaryTextStyle(
                    color: Colors.white, letterSpacing: 0.5)),
          ],
        ),
      ),
      body: Stack(
        children: [
          SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          imageFile != null
                              ? Image.file(File(imageFile!.path),
                                      height: 50,
                                      width: 50,
                                      fit: BoxFit.cover,
                                      alignment: Alignment.center)
                                  .cornerRadiusWithClipRRect(25)
                              : Container(
                                  height: 50,
                                  width: 50,
                                  decoration: boxDecorationDefault(
                                      shape: BoxShape.circle,
                                      color: Colors.grey.shade400),
                                  child: Icon(Icons.camera_alt,
                                      color: Colors.white, size: 20),
                                ).onTap(() {
                                  showBottomSheet(context);
                                }),
                          8.width,
                          Container(
                            padding: EdgeInsets.only(top: 8),
                            width: context.width() / 1.5,
                            child: AppTextField(
                              controller: groupNameCont,
                              textStyle: TS.primaryTextStyle(),
                              decoration: InputDecoration(
                                  labelStyle: TS.secondaryTextStyle(),
                                  labelText:
                                      'lblTypegroupsubjecthere'.translate),
                              textFieldType: TextFieldType.NAME,
                              maxLength: 25,
                            ),
                          ),
                        ],
                      ),
                      4.height,
                      Text(
                          'lblProvideaGroupsubjectAndOptionalGroupicon'
                              .translate,
                          style: TS.secondaryTextStyle()),
                    ],
                  ),
                ),
                16.height,
                Text(
                        'lblMembers'.translate +
                            ': ${userModelList.length.toString()}',
                        style: TS.secondaryTextStyle())
                    .paddingSymmetric(horizontal: 16),
                8.height,
                SingleChildScrollView(
                  child: Wrap(
                    runSpacing: 16,
                    spacing: 16,
                    children: List.generate(userModelList.length, (index) {
                      UserModel data = userModelList[index];
                      return SizedBox(
                          width: context.width() / 4 - 32,
                          child: Column(
                            children: [
                              data.photoUrl.isEmptyOrNull
                                  ? Container(
                                      height: 55,
                                      width: 55,
                                      padding: EdgeInsets.all(10),
                                      color: getColorFromString(
                                          data.uid.validate()),
                                      child: Text(
                                              data.name
                                                  .validate()[0]
                                                  .toUpperCase(),
                                              style: TS.secondaryTextStyle(
                                                  color: Colors.white))
                                          .center()
                                          .fit(),
                                    ).cornerRadiusWithClipRRect(50)
                                  : cachedImage(data.photoUrl.validate(),
                                          width: 55,
                                          height: 55,
                                          fit: BoxFit.cover)
                                      .cornerRadiusWithClipRRect(30)
                                      .center(),
                              4.height,
                              Text(data.name.validate(),
                                  overflow: TextOverflow.ellipsis,
                                  style: TS.secondaryTextStyle(size: 12))
                            ],
                          ));
                    }),
                  ).paddingSymmetric(horizontal: 16, vertical: 8),
                ),
                100.height,
              ],
            ),
          ),
          Observer(
              builder: (_) => Loader().center().visible(appStore.isLoading)),
        ],
      ),
      floatingActionButton: FloatingActionButton(
          child: Icon(Icons.check, color: Colors.white),
          backgroundColor: primaryColor,
          onPressed: () async {
            if (groupNameCont.text.isNotEmpty && !appStore.isLoading) {
              appStore.isLoading = true;
              List<String> listusers = [getStringAsync(userId)];
              List<String> listmembers = [getStringAsync(userId)];
              userModelList.forEach((element) {
                log(element.uid);
                print("--------194>>${element.name}");
                listusers.add(element.uid.toString());
                listmembers.add(element.uid.toString());
              });
              GroupModel groupModel = GroupModel();
              DateTime time = DateTime.now();
              String groupID =
                  '${getStringAsync(userId).toString()}--${time.millisecondsSinceEpoch.toString()}';
              log(groupID);

              List<String> mGrpId = [getStringAsync(userId).toString()];
              groupModel.createdBy = getStringAsync(userId).toString();
              groupModel.createdOn = time;
              groupModel.adminId = getStringAsync(userId).toString();
              groupModel.adminIds = mGrpId;
              groupModel.name = groupNameCont.text.isEmpty
                  ? 'Unnamed Group'
                  : groupNameCont.text.trim();
              groupModel.fltrdId = groupID
                  .replaceAll(RegExp('-'), '')
                  .substring(
                      1, groupID.replaceAll(RegExp('-'), '').toString().length);
              groupModel.photoUrl = imageUrl != null ? imageUrl : null;
              groupModel.membersList = listmembers;
              groupModel.latestTimeStamp = time.millisecondsSinceEpoch;
              groupModel.groupType =
                  GroupDbkeys.groupTYPEallusersmessageallowed;
              groupModel.caseSearch = setSearchParam(groupNameCont.text);
              ContactModel data = ContactModel();
              await groupChatMessageService
                  .addGroup(groupModel, userModelList,
                      getStringAsync(userDisplayName).toString())
                  .then((value) async {
                data.uid = value.id;
                data.addedOn = Timestamp.now();
                data.lastMessageTime = DateTime.now().millisecondsSinceEpoch;
                data.groupRefUrl = value.id;
                userModelList.map((e) {
                  chatMessageService
                      .getContactsDocument(of: e.uid, forContact: value.id)
                      .set(data.toJson())
                      .then((value) {})
                      .catchError((e) {
                    log(e);
                    appStore.isLoading = false;
                  });
                }).toList();
                chatMessageService
                    .getContactsDocument(
                        of: getStringAsync(userId), forContact: value.id)
                    .set(data.toJson())
                    .then((value) {})
                    .catchError((e) {
                  log(e);
                  appStore.isLoading = false;
                });
              }).whenComplete(() {
                appStore.isLoading = false;
                finish(context);
                finish(context);
                finish(context);
              });
              // UserModel user = await userService.getUserById(val: getStringAsync(userId));

              await notificationService
                  .sendPushNotifications(
                      'new_group'.translate, 'created'.translate,
                      isGrp: true,
                      recevierUid: data.uid,
                      mPlayerIds: mPlayerIdsList)
                  .catchError((e) {
                log('error' + e.toString());
                appStore.isLoading = false;
              }).then((value) async {});
            } else {
              appStore.isLoading = false;
              if (groupNameCont.text.isEmpty)
                toast('lblPleaseaddsubject'.translate);
              else if (appStore.isLoading) {
                toast('please_wait'.translate);
              }
            }
          }),
    );
  }

  void getFromGallery() async {
    pickedFile = await ImagePicker().pickImage(
        source: ImageSource.gallery, maxWidth: 1800, maxHeight: 1800);
    if (pickedFile != null) {
      imageFile = File(pickedFile!.path);
      setState(() {});
      updateGroupProfileImg(profileImage: File(imageFile!.path));
    }
  }

  getFromCamera() async {
    pickedFile = await ImagePicker()
        .pickImage(source: ImageSource.camera, maxWidth: 1800, maxHeight: 1800);
    if (pickedFile != null) {
      imageFile = File(pickedFile!.path);
      setState(() {});
      updateGroupProfileImg(profileImage: File(imageFile!.path));
    }
  }

  void showBottomSheet(BuildContext context) {
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
                getFromGallery();
                finish(context);
              },
            ),
            Divider(
              color: context.dividerColor,
            ),
            SettingItemWidget(
              title: 'camera'.translate,
              titleTextStyle: TS.boldTextStyle(),
              leading: Icon(Icons.camera, color: primaryColor),
              onTap: () {
                getFromCamera();
                finish(context);
              },
            ),
          ],
        ).paddingAll(16.0);
      },
    );
  }
}
