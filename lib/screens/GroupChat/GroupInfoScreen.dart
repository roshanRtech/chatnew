import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:flutter_mobx/flutter_mobx.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:nb_utils/nb_utils.dart';
import 'package:path/path.dart' as path;
import 'package:share_plus/share_plus.dart';

import 'package:chat/centralized_import.dart';

import '../../utils/TextStyles.dart' as TS;

class GroupInfoScreen extends StatefulWidget {
  final String groupId, groupName;
  final dynamic data;
  final Function(bool)? isSearch;

  GroupInfoScreen(
      {required this.groupId,
      required this.groupName,
      this.data,
      this.isSearch});

  @override
  State<GroupInfoScreen> createState() => _GroupInfoScreenState();
}

class _GroupInfoScreenState extends State<GroupInfoScreen>
    with TickerProviderStateMixin {
  List membersList = [];
  List<UserModel> userModelList = [];
  List<UserModel> filteredUserList = [];
  bool isProfileChange = false;
  bool isDeleteGroup = false;
  FirebaseAuth auth = FirebaseAuth.instance;
  File? imageFile;
  XFile? pickedFile;

  String createdBy = '';
  String? groupName;
  String? imageUrl;
  bool? adminExist;
  DateTime? createdDate = DateTime.now();

  bool isChangeAdmin = false;
  int counter = 0;
  List<dynamic> adminIds = [];

  // Search related variables
  bool isSearchVisible = false;
  TextEditingController searchController = TextEditingController();
  late AnimationController animationController;
  late Animation<double> searchAnimation;

  ScrollController scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    getGroupDetails();

    // Initialize animation controller
    animationController = AnimationController(
      duration: Duration(milliseconds: 300),
      vsync: this,
    );

    searchAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: animationController,
      curve: Curves.easeInOut,
    ));

    // Listen to search text changes
    searchController.addListener(() {
      filterMembers(searchController.text);
    });
  }

  @override
  void dispose() {
    animationController.dispose();
    searchController.dispose();
    scrollController.dispose();
    super.dispose();
  }

  void toggleSearch() {
    setState(() {
      isSearchVisible = !isSearchVisible;
      if (isSearchVisible) {
        animationController.forward();
        // Wait for keyboard to appear, then scroll
        Future.delayed(Duration(milliseconds: 600), () {
          if (scrollController.hasClients) {
            scrollController.animateTo(
              200.0, // Scroll past the header to show search field
              duration: Duration(milliseconds: 400),
              curve: Curves.easeInOut,
            );
          }
        });
      } else {
        animationController.reverse();
        searchController.clear();
        filteredUserList = List.from(userModelList);
      }
    });
  }

  void filterMembers(String query) {
    setState(() {
      if (query.isEmpty) {
        filteredUserList = List.from(userModelList);
      } else {
        filteredUserList = userModelList.where((user) {
          return user.name
                  .validate()
                  .toLowerCase()
                  .contains(query.toLowerCase()) ||
              user.userStatus
                  .validate()
                  .toLowerCase()
                  .contains(query.toLowerCase());
        }).toList();
      }
    });
  }

  Future getGroupDetails() async {
    await groupChatMessageService.grpRef
        .doc(widget.groupId)
        .get()
        .then((chatMap) {
      createdBy = chatMap['createdBy'];
      createdDate = (chatMap['createdOn'] as Timestamp).toDate();
      //admin = chatMap['adminId'];
      membersList = chatMap['membersList'];
      adminIds = chatMap['adminIds'];
      checkAdmin();
      groupName = chatMap['name'];
      imageUrl = chatMap['photoUrl'];
      getMemberList();
      appStore.isLoading = false;
      setState(() {});
    });
  }

  getMemberList() {
    userModelList.clear();
    filteredUserList.clear();
    membersList.forEach((element) async {
      print("---------82>>${element}");
      UserModel userm = await userService.getUserById(val: element);
      userModelList.add(userm);
      filteredUserList.add(userm);
      setState(() {});
    });
  }

  adminAvailable({String? Id}) async {
    print('-----------115->>>${Id}');
    adminExist = await getAdminData(Id ?? '');
  }

  Future<bool?> getAdminData(String adminId) async {
    try {
      print("---------961>>${adminId}");
      if (adminId.isEmpty) return false;
      final docSnapshot = await FirebaseFirestore.instance
          .collection('admin')
          .doc(adminId)
          .get();
      return docSnapshot.exists;
    } catch (e) {
      print("Error fetching admin data: $e");
      return false;
    }
  }

  void checkAdmin() {
    if (adminIds.contains(getStringAsync(userId))) {
      setState(() {});
    } else {
      userService
          .singleUser(getStringAsync(userId))
          .first
          .then((value) => log("success"))
          .catchError((e) {
        if (counter == 0) {
          isChangeAdmin = true;
          setState(() {});
          removeMembers(
              0, getStringAsync(userId), getStringAsync(userDisplayName));
        }
      });
    }
  }

  Future makeUserAdmin(String? userId, String? groupId) async {
    await groupChatMessageService.makeUserAdmin(
        userId: userId.toString(), groupId: groupId.toString());
    setState(() {
      getGroupDetails();
    });
  }

  Future removeUserAsAdmin(String? userId, String? groupId) async {
    await groupChatMessageService.removeUserAsAdmin(
        userId: userId.toString(), groupId: groupId.toString());
    setState(() {
      getGroupDetails();
    });
  }

  Future removeMembers(int index, String? uid, String? personName) async {
    print("----------134>>>${index}");
    print("----------135>>>${uid}");
    print("----------136>>>${personName}");
    List newMembers = [];
    appStore.isLoading = true;
    membersList.map((e) {
      if (e.toString().contains(uid.toString())) {
      } else {
        newMembers.add(e);
      }
    }).toList();

    if (adminIds.contains(uid)) {
      adminIds.remove(uid);
    }
    await groupChatMessageService.grpRef.doc(widget.groupId).update({
      "membersList": newMembers,
      "createdBy": createdBy,
      "adminIds": adminIds,
      "adminId": isChangeAdmin ? newMembers[0] : getStringAsync(userId)
    }).then((value) async {
      await userService.ref!
          .doc(widget.data['uid'])
          .collection('group')
          .doc(widget.groupId)
          .delete();
      await groupChatMessageService.removeUserFromReadyByOnLeavingGroup(
          userId: uid.toString(), groupId: widget.groupId);
      var chatRef = groupChatMessageService.grpRef
          .doc(widget.groupId)
          .collection(GROUP_CHATS)
          .doc();
      await chatRef.set({
        "id": chatRef.id,
        "addRemoveStatus":
            "${getStringAsync(userDisplayName)} removed ${personName}",
        "messageType": ADD_REMOVE_GROUP,
        "createdAt": DateTime.now().millisecondsSinceEpoch,
      });
      counter = 1;
      getGroupDetails();
      appStore.isLoading = false;
    });
  }

  void showDialogBox(int index) {
    // Find the original user from userModelList using filtered user's uid
    UserModel selectedUser = filteredUserList[index];
    int originalIndex =
        userModelList.indexWhere((user) => user.uid == selectedUser.uid);

    showDialog(
        context: context,
        builder: (context) {
          return AlertDialog(
            backgroundColor: context.cardColor,
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ListTile(
                  onTap: () async {
                    await adminAvailable(Id: selectedUser.uid ?? '');
                    finish(context);
                    print("-------------180>>>${selectedUser.toJson()}");
                    ChatScreen(
                      selectedUser,
                      isArchive: false,
                      isAdmin: adminExist,
                    ).launch(context);
                  },
                  title: Text("message".translate + " ${selectedUser.name}",
                      style: TS.primaryTextStyle()),
                ),
                if (adminIds.contains(getStringAsync(userId)))
                  ListTile(
                    onTap: () {
                      finish(context);
                      removeMembers(
                          originalIndex, selectedUser.uid, selectedUser.name);
                    },
                    title: Text("lblRemove".translate + " ${selectedUser.name}",
                        style: TS.primaryTextStyle()),
                  ),
                if (adminIds.contains(getStringAsync(userId)))
                  ListTile(
                    onTap: () {
                      finish(context);
                      adminIds.contains(selectedUser.uid)
                          ? removeUserAsAdmin(selectedUser.uid, widget.groupId)
                          : makeUserAdmin(selectedUser.uid, widget.groupId);
                    },
                    title: Text(
                        adminIds.contains(selectedUser.uid)
                            ? "lblRemove".translate +
                                "  ${selectedUser.name} " +
                                'as_admin'.translate
                            : "make".translate +
                                "  ${selectedUser.name}" +
                                " " +
                                "admin".translate,
                        style: TS.primaryTextStyle()),
                  ),
              ],
            ),
          );
        });
  }

  Future onDeleteGroup() async {
    await showConfirmDialogCustom(context,
        dialogAnimation: DialogAnimation.SCALE,
        title: 'are_you_sure_you_want_to_delete'.translate,
        positiveText: 'lbl_yes'.translate,
        negativeText: 'lbl_no'.translate,
        primaryColor: primaryColor, onAccept: (v) async {
      await groupChatMessageService.deleteGroup(groupDocId: widget.groupId);
      finish(context);
      finish(context);
      finish(context);
    });
  }

  Future onLeaveGroup() async {
    var currentUserId = getStringAsync(userId);
    await showConfirmDialogCustom(context,
        dialogAnimation: DialogAnimation.SCALE,
        title: 'lblLeave'.translate +
            ' ${widget.groupName} ' +
            'lblgroup'.translate +
            '?',
        positiveText: 'lbl_yes'.translate,
        negativeText: 'lbl_no'.translate, onAccept: (v) async {
      appStore.isLoading = true;

      membersList.removeWhere((id) => id == currentUserId);
      adminIds.removeWhere((id) => id == currentUserId);

      if (adminIds.isEmpty && membersList.isNotEmpty) {
        adminIds.add(membersList.first);
      }

      await groupChatMessageService.grpRef.doc(widget.groupId).update({
        "membersList": membersList,
        "adminIds": adminIds,
        "adminId": adminIds.isNotEmpty ? adminIds.first : null,
      });

      await chatMessageService.deleteGroupFromUserContacts(
          groupId: widget.groupId);
      await groupChatMessageService.removeUserFromReadyByOnLeavingGroup(
        userId: currentUserId,
        groupId: widget.groupId,
      );

      var chatRef = groupChatMessageService.grpRef
          .doc(widget.groupId)
          .collection(GROUP_CHATS)
          .doc();
      await chatRef.set({
        "id": chatRef.id,
        "addRemoveStatus": "${getStringAsync(userDisplayName)} left the group",
        "messageType": ADD_REMOVE_GROUP,
        "createdAt": DateTime.now().millisecondsSinceEpoch,
      });

      appStore.isLoading = false;
      finish(context);
      finish(context);
    }, primaryColor: primaryColor);
  }

  Future<void> updateGroupProfileImg({File? profileImage}) async {
    appStore.isLoading = true;
    if (profileImage != null) {
      String fileName = path.basename(profileImage.path);
      Reference storageRef = FirebaseStorage.instance
          .ref()
          .child("$GROUP_PROFILE_IMAGE/$fileName");
      UploadTask uploadTask = storageRef.putFile(profileImage);
      await uploadTask.then((e) async {
        await e.ref.getDownloadURL().then((value) async {
          imageUrl = value;
          await groupChatMessageService.grpRef.doc(widget.groupId).update({
            "photoUrl": imageUrl,
          });
          isProfileChange = true;
          setState(() {});
          getGroupDetails();
          appStore.isLoading = false;
        });
      });
    }
  }

  Widget profileImage() {
    if (imageFile != null) {
      return Stack(
        alignment: Alignment.center,
        children: [
          Image.file(
            File(imageFile?.path ?? ''),
            height: 100,
            width: 100,
            fit: BoxFit.cover,
          ).cornerRadiusWithClipRRect(50).onTap(() {
            _showBottomSheet(context);
          }),
          Loader().visible(appStore.isLoading)
        ],
      );
    } else if (imageUrl != null) {
      return Stack(
        alignment: Alignment.bottomRight,
        children: [
          cachedImage(imageUrl.validate(),
                  height: 100,
                  width: 100,
                  fit: BoxFit.cover,
                  alignment: Alignment.center)
              .cornerRadiusWithClipRRect(50)
              .onTap(() {
            FullScreenImageWidget(
              photoUrl: imageUrl,
              isFromChat: true,
              name: widget.groupName,
            ).launch(context);
          }),
          Container(
            padding: EdgeInsets.all(6),
            decoration: boxDecorationWithRoundedCorners(
                boxShape: BoxShape.circle, backgroundColor: primaryColor),
            child: Icon(Icons.camera, color: Colors.white),
          ).onTap(() {
            _showBottomSheet(context);
          })
        ],
      );
    } else {
      return noProfileImageFound(height: 100, width: 100).onTap(() {
        _showBottomSheet(context);
      });
    }
  }

  Widget buildMembersSection() {
    return Container(
      padding: EdgeInsets.all(16),
      decoration: appStore.isDarkMode
          ? boxDecorationWithRoundedCorners(
              borderRadius: radius(0), backgroundColor: context.cardColor)
          : boxDecorationWithShadow(
              borderRadius: radius(0), backgroundColor: context.cardColor),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Members header with search icon
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text("${membersList.length} " + 'lblMembers'.translate,
                  style: TS.secondaryTextStyle()),
              IconButton(
                icon: Icon(
                  isSearchVisible ? Icons.close : Icons.search,
                  color: primaryColor,
                ),
                onPressed: toggleSearch,
              ),
            ],
          ),

          // Animated search bar
          AnimatedBuilder(
            animation: searchAnimation,
            builder: (context, child) {
              return SizeTransition(
                sizeFactor: searchAnimation,
                child: Container(
                  margin: EdgeInsets.only(bottom: 16),
                  child: TextField(
                    controller: searchController,
                    decoration: InputDecoration(
                      hintText: 'Search members...',
                      prefixIcon: Icon(Icons.search, color: primaryColor),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide(color: primaryColor),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide(color: primaryColor),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide(color: primaryColor, width: 2),
                      ),
                      contentPadding:
                          EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    ),
                    autofocus: isSearchVisible,
                  ),
                ),
              );
            },
          ),

          // Add participants button (only for admins)
          adminIds.contains(getStringAsync(userId)) ? 16.height : 0.height,
          adminIds.contains(getStringAsync(userId))
              ? InkWell(
                  onTap: () async {
                    bool? res = await NewGroupScreen(
                            isAddParticipant: true,
                            groupId: widget.groupId,
                            data: widget.data)
                        .launch(context);
                    if (res ?? true) {
                      getGroupDetails();
                      setState(() {});
                    }
                  },
                  child: Row(
                    children: [
                      Container(
                        height: 45,
                        width: 45,
                        decoration: boxDecorationDefault(
                            shape: BoxShape.circle, color: primaryColor),
                        child: Icon(Icons.person_add,
                            color: Colors.white.withValues(alpha: 0.9),
                            size: 25),
                      ),
                      16.width,
                      Text('lblAddparticipants'.translate.capitalizeEachWord(),
                          style: TS.primaryTextStyle())
                    ],
                  ),
                )
              : SizedBox(),

          // Members list
          ListView.builder(
            itemCount: filteredUserList.length,
            shrinkWrap: true,
            padding: EdgeInsets.fromLTRB(0, 8, 0, 0),
            physics: NeverScrollableScrollPhysics(),
            itemBuilder: (context, index) {
              return Row(
                children: [
                  filteredUserList[index].photoUrl.isEmptyOrNull
                      ? Hero(
                          tag: filteredUserList[index].uid.validate(),
                          child: Container(
                            height: 45,
                            width: 45,
                            color: getColorFromString(
                                filteredUserList[index].uid.validate()),
                            child: Text(
                                    filteredUserList[index]
                                        .name
                                        .validate()[0]
                                        .toUpperCase(),
                                    style: TS.secondaryTextStyle(
                                        color: Colors.white))
                                .center()
                                .fit(),
                          ).cornerRadiusWithClipRRect(45 / 2))
                      : cachedImage(filteredUserList[index].photoUrl.validate(),
                              width: 45, height: 45, fit: BoxFit.cover)
                          .cornerRadiusWithClipRRect(25),
                  16.width,
                  Column(
                    mainAxisAlignment: MainAxisAlignment.start,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Text(
                              filteredUserList[index].uid ==
                                      getStringAsync(userId)
                                  ? 'you'.translate
                                  : filteredUserList[index]
                                      .name
                                      .validate()
                                      .capitalizeFirstLetter(),
                              style: TS.primaryTextStyle(),
                              softWrap: true,
                              overflow: TextOverflow.visible,
                            ),
                          ),
                          8.width,
                          Container(
                            decoration: boxDecorationWithRoundedCorners(
                              border: Border.all(color: primaryColor),
                              borderRadius: radius(4),
                              backgroundColor:
                                  appStore.isDarkMode ? cardDarkColor : white,
                            ),
                            padding: EdgeInsets.all(2),
                            child: Text(
                              'lblGroupAdmin'.translate,
                              style: TS.primaryTextStyle(
                                color: appStore.isDarkMode
                                    ? textPrimaryColorGlobal
                                    : primaryColor,
                              ),
                            ),
                          ).visible(
                              adminIds.contains(filteredUserList[index].uid)),
                        ],
                      ),
                      4.height,
                      Text('${filteredUserList[index].userStatus.validate()}',
                          style: TS.secondaryTextStyle()),
                    ],
                  ).expand(),
                ],
              ).paddingSymmetric(vertical: 8).onTap(() {
                if ((filteredUserList[index].uid != getStringAsync(userId)))
                  showDialogBox(index);
                setState(() {});
              });
            },
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () {
        if (isSearchVisible) {
          toggleSearch();
          return Future.value(false);
        }
        finish(context, isProfileChange);
        return Future.value(false);
      },
      child: Scaffold(
        body: Stack(
          children: [
            CustomScrollView(
              controller: scrollController,
              slivers: [
                SliverAppBar(
                  expandedHeight: 210.0,
                  backgroundColor: context.scaffoldBackgroundColor,
                  floating: true,
                  pinned: false,
                  snap: false,
                  stretch: true,
                  actions: [
                    SizedBox(
                      child: PopupMenuButton(
                        icon: Icon(Icons.more_vert,
                            color: textPrimaryColorGlobal),
                        color: context.cardColor,
                        onSelected: (value) async {
                          if (value == 1) {
                            bool? res = await ChangeSubjectScreen(
                                    groupName: widget.groupName,
                                    groupId: widget.groupId)
                                .launch(context);
                            if (res ?? true) {
                              isProfileChange = true;
                              getGroupDetails();
                              setState(() {});
                            }
                          } else if (value == 2) {
                            finish(context);
                            widget.isSearch!(true);
                            setState(() {});
                          }
                        },
                        padding: EdgeInsets.zero,
                        itemBuilder: (context) {
                          List<PopupMenuItem> list = [];
                          list.add(PopupMenuItem(
                              value: 1,
                              child: Text('lblChangesubject'.translate,
                                  style: TS.primaryTextStyle())));
                          list.add(PopupMenuItem(
                              value: 2,
                              child: Text('search'.translate,
                                  style: TS.primaryTextStyle())));
                          return list;
                        },
                      ),
                    ),
                  ],
                  leading: BackButton(color: textPrimaryColorGlobal).onTap(() {
                    if (isSearchVisible) {
                      toggleSearch();
                    } else {
                      finish(context, isProfileChange);
                    }
                  }),
                  stretchTriggerOffset: 120.0,
                  flexibleSpace: FlexibleSpaceBar(
                    collapseMode: CollapseMode.parallax,
                    stretchModes: [StretchMode.zoomBackground],
                    titlePadding:
                        EdgeInsetsDirectional.only(start: 50.0, bottom: 20.0),
                    background: Container(
                      margin: EdgeInsets.only(bottom: 3),
                      padding: EdgeInsets.only(
                          left: 16, bottom: 16, right: 16, top: 30),
                      decoration: appStore.isDarkMode
                          ? boxDecorationWithRoundedCorners(
                              borderRadius: radius(0),
                              backgroundColor: context.cardColor)
                          : boxDecorationWithShadow(
                              borderRadius: radius(0),
                              backgroundColor: context.cardColor),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          32.height,
                          profileImage(),
                          8.height,
                          Text(
                              groupName.isEmptyOrNull
                                  ? ""
                                  : groupName!.validate(),
                              overflow: TextOverflow.ellipsis,
                              style: TS.primaryTextStyle()),
                          4.height,
                          Text(
                            'lblGroup'.translate +
                                ' : ${membersList.length} ' +
                                'lblMembers'.translate,
                            overflow: TextOverflow.ellipsis,
                            style: TS.secondaryTextStyle(),
                          ).expand(),
                        ],
                      ),
                    ),
                  ),
                ),
                SliverList(
                  delegate: SliverChildBuilderDelegate(
                      (BuildContext context, int index) {
                    return SingleChildScrollView(
                      physics: NeverScrollableScrollPhysics(),
                      child: Column(
                        children: [
                          16.height,
                          Container(
                            width: context.width(),
                            padding: EdgeInsets.all(16),
                            decoration: appStore.isDarkMode
                                ? boxDecorationWithRoundedCorners(
                                    borderRadius: radius(0),
                                    backgroundColor: context.cardColor,
                                  )
                                : boxDecorationWithShadow(
                                    borderRadius: radius(0),
                                    backgroundColor: context.cardColor,
                                  ),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(
                                  child: Wrap(
                                    spacing: 4,
                                    runSpacing: 4,
                                    children: [
                                      Text('created'.translate,
                                          style: TS.secondaryTextStyle()),
                                      FutureBuilder<UserModel>(
                                        future: userService.getUserById(
                                            val: createdBy),
                                        builder: (c, snap) {
                                          if (snap.hasData &&
                                              snap.data != null &&
                                              snap.data!.name !=
                                                  'User Not found') {
                                            return Text(
                                              "by".translate +
                                                  " " +
                                                  snap.data!.name.validate() +
                                                  ', ',
                                              style: TS.secondaryTextStyle(
                                                  weight: FontWeight.bold),
                                            );
                                          }
                                          return snapWidgetHelper(
                                            snap,
                                            loadingWidget: SizedBox(),
                                            errorWidget: Text("on ",
                                                    style:
                                                        TS.secondaryTextStyle())
                                                .paddingBottom(1),
                                          );
                                        },
                                      ),
                                      Text(
                                        DateFormat('dd/MM/yy')
                                            .format(createdDate!),
                                        style: TS.secondaryTextStyle(),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                          16.height,
                          buildMembersSection(),
                          16.height,
                          Container(
                            padding: EdgeInsets.all(16),
                            width: context.width(),
                            decoration: appStore.isDarkMode
                                ? boxDecorationWithRoundedCorners(
                                    borderRadius: radius(0),
                                    backgroundColor: context.cardColor)
                                : boxDecorationWithShadow(
                                    borderRadius: radius(0),
                                    backgroundColor: context.cardColor),
                            child: Row(
                              children: [
                                Icon(Icons.exit_to_app, color: Colors.red),
                                8.width,
                                Text(
                                  'lblLeaveGroup'.translate,
                                  style: TS.primaryTextStyle(
                                    color: Colors.red,
                                  ),
                                ),
                              ],
                            ),
                          ).onTap(() {
                            if (adminIds.length == 1 &&
                                adminIds.contains(getStringAsync(userId)) &&
                                membersList.length == 1 &&
                                membersList.contains(getStringAsync(userId))) {
                              onDeleteGroup();
                            } else {
                              onLeaveGroup();
                            }
                          }),
                          16.height,
                          Container(
                            padding: EdgeInsets.all(16),
                            width: context.width(),
                            decoration: appStore.isDarkMode
                                ? boxDecorationWithRoundedCorners(
                                    borderRadius: radius(0),
                                    backgroundColor: context.cardColor)
                                : boxDecorationWithShadow(
                                    borderRadius: radius(0),
                                    backgroundColor: context.cardColor),
                            child: Row(
                              children: [
                                Icon(Icons.share,
                                    color: appStore.isDarkMode
                                        ? Colors.white
                                        : Colors.black),
                                8.width,
                                Text(
                                  'lblShareGroup'.translate,
                                  style: TS.primaryTextStyle(
                                      color: appStore.isDarkMode
                                          ? Colors.white
                                          : Colors.black),
                                ),
                              ],
                            ),
                          ).onTap(() {
                            _showVideoBottomSheet(context);
                          }),
                          70.height,
                        ],
                      ),
                    );
                  }, childCount: 1),
                )
              ],
            ),
            Observer(
                builder: (_) => Loader().center().visible(appStore.isLoading)),
          ],
        ),
      ),
    );
  }

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
              title: 'lblInApp'.translate,
              leading: Image.asset(inapp,
                  height: 25, width: 25, color: primaryColor),
              onTap: () {
                Shareprofilescreen(
                  groupId: widget.groupId,
                  groupName: widget.groupName,
                  groupProfile: imageUrl,
                  data: widget.data,
                ).launch(context);
              },
            ),
            Divider(color: context.dividerColor),
            SettingItemWidget(
              title: 'lblChooser'.translate,
              leading: Image.asset(statusIcon,
                  height: 25, width: 25, color: primaryColor),
              onTap: () {
                String encodedGroupId = Uri.encodeComponent(widget.groupId);
                String encodedGroupName = Uri.encodeComponent(widget.groupName);
                String groupLink =
                    '${CHAT_WEB_DOAMAIN_URL}join?group=$encodedGroupId&name=$encodedGroupName';
                Share.share('Join our group: $groupLink');
              },
            ),
          ],
        ).paddingAll(16.0);
      },
    );
  }

  void _getFromGallery() async {
    pickedFile = await ImagePicker().pickImage(
        source: ImageSource.gallery, maxWidth: 1800, maxHeight: 1800);
    if (pickedFile != null) {
      imageFile = File(pickedFile!.path);
      setState(() {});
      updateGroupProfileImg(profileImage: File(imageFile!.path));
    }
  }

  _getFromCamera() async {
    pickedFile = await ImagePicker()
        .pickImage(source: ImageSource.camera, maxWidth: 1800, maxHeight: 1800);
    if (pickedFile != null) {
      imageFile = File(pickedFile!.path);
      setState(() {});
      updateGroupProfileImg(profileImage: File(imageFile!.path));
    }
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
                _getFromGallery();
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
