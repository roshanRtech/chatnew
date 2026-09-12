import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_vector_icons/flutter_vector_icons.dart';
import 'package:nb_utils/nb_utils.dart';

import 'package:chat/centralized_import.dart';

import '../../utils/TextStyles.dart' as TS;

class UserListComponent extends StatefulWidget {
  final AsyncSnapshot<List<UserModel>>? snap;
  final bool isGroupCreate;
  final bool isAddParticipant;
  final List<dynamic>? data;
  final bool? isCall;
  final bool? isFromStatusPrivacy;
  final Function(int excluded, int included, List<String>, List<UserModel>)?
      statusPrivacyValueLength;
  final List<String>? excludedSelectedUserList;
  final List<String>? includedSelectedUserList;
  final bool? isSelectCall;
  final List<String>? selectedUserIds;

  UserListComponent({
    this.snap,
    this.isGroupCreate = false,
    this.isAddParticipant = false,
    this.data,
    this.isCall = false,
    this.isFromStatusPrivacy = false,
    this.statusPrivacyValueLength,
    this.includedSelectedUserList,
    this.excludedSelectedUserList,
    this.isSelectCall,
    this.selectedUserIds,
  });

  @override
  UserListComponentState createState() => UserListComponentState();
}

class UserListComponentState extends State<UserListComponent> {
  List<UserModel> selectedList = [];
  List<String> selected = [];
  List<dynamic> existingMembersList = [];
  List<String> existingExcludedList = [];
  List<String> existingIncludedList = [];
  List<String> userIds = [];

  @override
  void initState() {
    super.initState();
    Future.delayed(Duration.zero).then((val) {
      init();
      fetchUserIds();
    });
  }

  Future<void> fetchUserIds() async {
    try {
      QuerySnapshot snapshot = await chatMessageService
          .fetchContacts(userId: getStringAsync(userId))
          .first;

      List<ContactModel> contacts = snapshot.docs
          .map((e) => ContactModel.fromJson(e.data() as Map<String, dynamic>))
          .toList();

      setState(() {
        userIds = contacts.map((c) => c.uid.validate()).toList();
      });
    } catch (e) {
      print("Error fetching user IDs: $e");
    }
  }

  Future<bool> checkUserRequest(String id) async {
    bool isPending = await chatMessageService.hasPendingRequestFromUser(
      currentUserId: getStringAsync(userId),
      otherUserId: id,
    );
    if (isPending) {
      print("===> --- > This user already has a pending request!");
      return false;
    } else {
      print("===> --- > No pending request from this user.");
      return true;
    }
  }

  Future<void> init() async {
    print("User List Components Screen ");
    if (widget.excludedSelectedUserList != null &&
        widget.excludedSelectedUserList!.isNotEmpty) {
      existingExcludedList = widget.excludedSelectedUserList!;
    }
    if (widget.includedSelectedUserList != null &&
        widget.includedSelectedUserList!.isNotEmpty) {
      existingIncludedList = widget.includedSelectedUserList!;
    }

    if (existingExcludedList.isNotEmpty) {
      selected = existingExcludedList;
      addToSelectedList(selected);
    }

    if (existingIncludedList.isNotEmpty) {
      selected = existingIncludedList;
      addToSelectedList(selected);
    }
  }

  Future<List<UserModel>> getUsers(List<String> selectedIds) async {
    List<UserModel> users = [];
    for (String id in selectedIds) {
      try {
        UserModel user = await userService.getUserById(val: id);
        users.add(user);
      } catch (e) {
        print('Error fetching user with ID $id: $e');
      }
    }
    return users;
  }

  Future<void> addToSelectedList(List<String> selected) async {
    print("Add Selected List Called");
    List<UserModel> selectedUsers = await getUsers(selected);
    selectedList.addAll(selectedUsers);
    setState(() {});
  }

  @override
  void setState(fn) {
    if (mounted) super.setState(fn);
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      alignment: Alignment.topCenter,
      children: [
        if (widget.snap!.data!.isNotEmpty)
          ListView.builder(
            physics: widget.isGroupCreate
                ? AlwaysScrollableScrollPhysics()
                : NeverScrollableScrollPhysics(),
            itemCount: widget.snap?.data?.length,
            shrinkWrap: true,
            itemBuilder: (context, index) {
              UserModel data = widget.snap!.data![index];
              if (data.uid == loginStore.mId) {
                return 0.height;
              }
              if (data.userRole == 'admin') return SizedBox();
              return Container(
                padding: EdgeInsets.symmetric(vertical: 8, horizontal: 16),
                child: Row(
                  children: [
                    data.photoUrl.isEmptyOrNull
                        ? Hero(
                            tag: data.uid.validate(),
                            child: Container(
                              height: 50,
                              width: 50,
                              padding: EdgeInsets.all(10),
                              color: getColorFromString(
                                  data.uid ?? data.name.validate()),
                              child: Text(data.name.validate()[0].toUpperCase(),
                                      style: TS.secondaryTextStyle(
                                          color: Colors.white))
                                  .center()
                                  .fit(),
                            ).cornerRadiusWithClipRRect(50),
                          )
                        : cachedImage(data.photoUrl.validate(),
                                width: 50, height: 50, fit: BoxFit.cover)
                            .cornerRadiusWithClipRRect(80),
                    12.width,
                    Column(
                      mainAxisAlignment: MainAxisAlignment.start,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text('${data.name.validate().capitalizeFirstLetter()}',
                                    style: TS.primaryTextStyle())
                                .expand(),
                            if (selected.contains(data.uid))
                              Icon(Icons.check_circle_outlined,
                                  color: primaryColor)
                          ],
                        ),
                        Text('${data.userStatus.validate()}',
                            style: TS.secondaryTextStyle()),
                      ],
                    ).expand(),
                    widget.isCall!
                        ? Row(
                            children: [
                              IconButton(
                                icon: Icon(FontAwesome.phone,
                                    color: secondaryColor, size: 18),
                                onPressed: () async {
                                  UserModel receiverData = UserModel(
                                    name: data.name,
                                    uid: data.uid,
                                    oneSignalPlayerId: data.oneSignalPlayerId,
                                    photoUrl: data.photoUrl,
                                  );
                                  UserModel sender = UserModel(
                                    name: getStringAsync(userDisplayName),
                                    photoUrl: getStringAsync(userPhotoUrl),
                                    uid: getStringAsync(userId),
                                    oneSignalPlayerId: getStringAsync(playerId),
                                  );
                                  return await Permissions
                                          .cameraAndMicrophonePermissionsGranted()
                                      ? CallFunctions.voiceDial(
                                          context: context,
                                          from: sender,
                                          to: receiverData)
                                      : {};
                                },
                              ),
                              IconButton(
                                icon: Icon(FontAwesome.video_camera,
                                    color: secondaryColor, size: 18),
                                onPressed: () async {
                                  UserModel receiverData = UserModel(
                                    name: data.name,
                                    uid: data.uid,
                                    oneSignalPlayerId: data.oneSignalPlayerId,
                                    photoUrl: data.photoUrl,
                                  );
                                  UserModel sender = UserModel(
                                    name: getStringAsync(userDisplayName),
                                    photoUrl: getStringAsync(userPhotoUrl),
                                    uid: getStringAsync(userId),
                                    oneSignalPlayerId: getStringAsync(playerId),
                                  );
                                  return await Permissions
                                          .cameraAndMicrophonePermissionsGranted()
                                      ? CallFunctions.dial(
                                          context: context,
                                          from: sender,
                                          to: receiverData)
                                      : {};
                                },
                              ),
                            ],
                          )
                        : widget.isAddParticipant
                            ? existingMembersList.contains(data.uid.toString())
                                ? Icon(Icons.check_circle_outline)
                                : Offstage()
                            : Offstage()
                  ],
                ),
              ).onTap(() async {
                if (widget.isGroupCreate) {
                  if (!selected.contains(data.uid.toString())) {
                    if (widget.isAddParticipant) {
                      log(existingMembersList);
                      if (existingMembersList.contains(data.uid.toString())) {
                        toast('lblAlreadyExist'.translate);
                      } else {
                        if (!userIds.contains(data.uid)) {
                          toast('startChatBeforeAddInGrp'.translate);
                        } else {
                          await checkUserRequest(data.uid.validate())
                              .then((val) {
                            if (!val) {
                              toast('requestPendingMsg'.translate);
                            } else {
                              selected.add(data.uid.toString());
                              selectedList.add(data);
                            }
                          });
                        }
                      }
                    } else {
                      if (!userIds.contains(data.uid)) {
                        toast('startChatBeforeAddInGrp'.translate);
                      } else {
                        await checkUserRequest(data.uid.validate()).then((val) {
                          if (!val) {
                            toast('requestPendingMsg'.translate);
                          } else {
                            selected.add(data.uid.toString());
                            selectedList.add(data);
                          }
                        });
                      }
                    }
                  } else {
                    selected.remove(data.uid.toString());
                    selectedList.removeWhere((user) => user.uid == data.uid);

                    // selectedList.remove(data);

                    // selectedList.remove(data.uid.toString());

                    print("Selected Remove Data Json => " +
                        data.toJson().toString());

                    print("Select Remove Tapped");
                    print("Selected " + selected.toString());
                    print("Selected List At Remove Time ==> " +
                        selectedList.toString());
                    print("Selected Remove Time Data " + data.name.toString());
                  }
//For Member list to add
                  setValue(selectedMember, selected);
                  setState(() {});
                } else {
                  if (widget.isCall == false) {
                    finish(context);

                    print("At UserListComponent Tapped");
                    print(
                        "Data is At SUerListComponent ==> " + data.toString());
                    ChatScreen(
                      data,
                      isArchive: false,
                    ).launch(context);
                  }
                }
                widget.statusPrivacyValueLength?.call(
                  selected.length,
                  selected.length,
                  selected,
                  selectedList,
                );

                print("Selected List is ==>" + selectedList.toString());
                // setState(() { });
              });
            },
          ).paddingTop(selectedList.isNotEmpty ? 100 : 0),
        if (widget.snap!.data == null)
          noDataFound(text: 'no_user_found'.translate),
        if (widget.isGroupCreate && selected.isNotEmpty)
          Container(
            height: 80,
            width: context.width(),
            decoration: BoxDecoration(
              color: context.scaffoldBackgroundColor,
              borderRadius: BorderRadius.circular(0),
              boxShadow: <BoxShadow>[
                BoxShadow(
                  color: Colors.black26,
                  blurRadius: 0.0,
                  offset: Offset(0.0, 0.0),
                ),
              ],
            ),
            child: HorizontalList(
              reverse: selectedList.length > 5 ? true : false,
              itemCount: selectedList.length,
              itemBuilder: (_, i) {
                return Stack(
                  clipBehavior: Clip.none,
                  alignment: Alignment.topRight,
                  children: [
                    selectedList[i].photoUrl.isEmptyOrNull
                        ? Container(
                            height: 50,
                            width: 50,
                            padding: EdgeInsets.all(10),
                            color: getColorFromString(selectedList[i].uid ??
                                selectedList[i].name.validate()),
                            child: Text(
                                    selectedList[i]
                                        .name
                                        .validate()[0]
                                        .toUpperCase(),
                                    style: TS.secondaryTextStyle(
                                        color: Colors.white))
                                .center()
                                .fit(),
                          ).cornerRadiusWithClipRRect(50)
                        : cachedImage(selectedList[i].photoUrl.validate(),
                                height: 50, width: 50, fit: BoxFit.cover)
                            .cornerRadiusWithClipRRect(25),
                    Positioned(
                      top: -3,
                      child: Icon(Icons.cancel_rounded,
                              size: 20, color: context.iconColor)
                          .onTap(() {
                        selected.remove(selectedList[i].uid.toString());
                        selectedList.remove(selectedList[i]);
                        setValue(selectedMember, selected);
                        setState(() {});
                      }),
                    )
                  ],
                ).paddingAll(6);
              },
            ),
          ),
      ],
    );
  }
}
