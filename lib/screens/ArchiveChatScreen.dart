import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:nb_utils/nb_utils.dart';

import 'package:chat/centralized_import.dart';

import '../../utils/TextStyles.dart' as TS;

class ArchiveChatScreen extends StatefulWidget {
  ArchiveChatScreen({super.key});

  @override
  State<ArchiveChatScreen> createState() => _ArchiveChatScreenState();
}

class _ArchiveChatScreenState extends State<ArchiveChatScreen> {
  String searchCont = "";
  bool? adminExist;

  @override
  void initState() {
    super.initState();
    init();
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

  void init() async {
    LiveStream().on(SEARCH_KEY, (s) {
      searchCont = s as String;
      setState(() {});
    });
  }

  @override
  void setState(fn) {
    if (mounted) super.setState(fn);
  }

  Stream<List<dynamic>> group({String? searchText}) {
    return fireStore
        .collection('group')
        .where('searchCase',
            arrayContains: searchText.validate().isEmpty
                ? null
                : searchText!.toLowerCase())
        .snapshots()
        .map((x) {
      return x.docs.map((y) {
        return y.data();
      }).toList();
    });
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () {
        finish(context, true);
        return Future.value(true);
      },
      child: Scaffold(
        appBar: appBarWidget('archived'.translate,
            textColor: Colors.white,
            backWidget: BackButton(
              color: white,
              onPressed: () {
                finish(context, true);
              },
            )),
        body: StreamBuilder<QuerySnapshot>(
          stream: chatMessageService.getArchive(userId: getStringAsync(userId)),
          builder: (context, snapshot) {
            print("------98>>${snapshot.data?.size}");
            if (snapshot.hasError)
              return Text(snapshot.error.toString(), style: TS.boldTextStyle())
                  .center();
            if (snapshot.hasData) {
              messageRequestStore.addContactData(
                data: snapshot.data!.docs
                    .map((e) =>
                        ContactModel.fromJson(e.data() as Map<String, dynamic>))
                    .toList(),
                isClear: true,
              );
              if (snapshot.data!.docs.isNotEmpty) {
                print("----------91>>>${snapshot.data?.docs.length}");
                return ListView.builder(
                  itemCount: snapshot.data?.docs.length,
                  shrinkWrap: true,
                  padding: EdgeInsets.only(bottom: 65, top: 8),
                  itemBuilder: (context, index) {
                    ContactModel contact = ContactModel.fromJson(
                        snapshot.data?.docs[index].data()
                            as Map<String, dynamic>);

                    print("--------99>>>${contact.toJson()}");
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        buildGroupItemArchiveWidget(contact: contact)
                            .visible(contact.groupRefUrl != null),
                        buildChatItemArchiveWidget(contact: contact),
                      ],
                    );
                  },
                );
              } else {
                return noDataFound();
              }
            }
            return snapWidgetHelper(snapshot, loadingWidget: Loader().center());
          },
        ),
      ),
    );
  }

  StreamBuilder<List<UserModel>> buildChatItemArchiveWidget(
      {required ContactModel contact}) {
    return StreamBuilder(
      stream: chatMessageService.getArchiveUserById(
          id: contact.uid ?? '', searchText: searchCont),
      builder: (context, snap) {
        if (snap.hasData) {
          print("--------247>>>${snap.data?.length}");
          return ListView.builder(
            physics: NeverScrollableScrollPhysics(),
            padding: EdgeInsets.all(0),
            itemCount: snap.data!.length,
            shrinkWrap: true,
            itemBuilder: (context, index) {
              UserModel data = snap.data![index];

              if (snap.data!.length == 0) {
                return noDataFound().center();
              }
              return InkWell(
                onTap: () async {
                  await adminAvailable(Id: data.uid ?? '');
                  if (getStringAsync(userId) != data.uid) {
                    hideKeyboard(context);

                    bool? res = await ChatScreen(
                      data,
                      isArchive: true,
                      isAdmin: adminExist,
                    ).launch(context);
                    if (res != null || res == null) {
                      await chatMessageService
                          .setUnReadStatusToTrue(
                              senderId: sender.uid!, receiverId: data.uid!)
                          .then((value) {});
                      setState(() {});
                    }
                  }
                },
                onLongPress: () async {
                  await showInDialog(context,
                      backgroundColor: context.cardColor, builder: (p0) {
                    return ChatOptionDialog(
                      receiverUser: data,
                      isFromArchive: true,
                    );
                  },
                      contentPadding: EdgeInsets.zero,
                      dialogAnimation: DialogAnimation.SLIDE_TOP_BOTTOM);
                  setState(() {});
                },
                child: Row(
                  children: [
                    data.photoUrl.isEmptyOrNull
                        ? Container(
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
                          ).cornerRadiusWithClipRRect(50).onTap(() async {
                            await adminAvailable(Id: data.uid ?? '');

                            showDialog(
                              context: context,
                              builder: (context) {
                                return UserProfileImageDialog(
                                    data: data, isAdmin: adminExist);
                              },
                            );
                          })
                        : Hero(
                            tag: data.uid.validate(),
                            child: cachedImage(data.photoUrl.validate(),
                                    height: 45, width: 45, fit: BoxFit.cover)
                                .cornerRadiusWithClipRRect(50),
                          ).onTap(() async {
                            await adminAvailable(Id: data.uid ?? '');

                            showDialog(
                              context: context,
                              builder: (context) {
                                return UserProfileImageDialog(
                                    data: data, isAdmin: adminExist);
                              },
                            );
                          }),
                    10.width,
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(data.name.validate().capitalizeFirstLetter(),
                                    style: TS.primaryTextStyle(),
                                    maxLines: 1,
                                    textAlign: TextAlign.start,
                                    overflow: TextOverflow.ellipsis)
                                .expand(),
                            StreamBuilder<int>(
                              stream: chatMessageService.getUnReadCount(
                                  senderId: getStringAsync(userId),
                                  receiverId: contact.uid.validate()),
                              builder: (context, snap) {
                                if (snap.hasData) {
                                  // print("snapdata${snap.data}");
                                  if (snap.data != 0) {
                                    //chatMessageService.fetchForMessageCount(loginStore.mId);
                                    return Container(
                                      height: 18,
                                      width: 18,
                                      decoration: BoxDecoration(
                                          borderRadius:
                                              BorderRadius.circular(20),
                                          color: primaryColor),
                                      child: Text(
                                              snap.data.validate().toString(),
                                              style: TS.secondaryTextStyle(
                                                  color: Colors.white))
                                          .center(),
                                    );
                                  }
                                }
                                return Offstage();
                              },
                            ),
                          ],
                        ),
                        2.height,
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            LastMessageContainer(
                              stream:
                                  chatMessageService.fetchLastMessageBetween(
                                      senderId: getStringAsync(userId),
                                      receiverId: contact.uid!),
                            ),
                          ],
                        ),
                      ],
                    ).expand(),
                  ],
                ).paddingSymmetric(horizontal: 16, vertical: 8),
              );
            },
          );
        }
        return snapWidgetHelper(snap, loadingWidget: Offstage()).center();
      },
    );
  }

  StreamBuilder<List<dynamic>> buildGroupItemArchiveWidget(
      {required ContactModel contact}) {
    return StreamBuilder(
      stream: group(searchText: searchCont),
      builder: (_, snap) {
        if (snap.hasData) {
          return snap.data != null
              ? ListView.builder(
                  physics: NeverScrollableScrollPhysics(),
                  shrinkWrap: true,
                  padding: EdgeInsets.all(0),
                  itemCount: snap.data!.length,
                  itemBuilder: (BuildContext context, int index) {
                    var members = snap.data![index]['membersList'];
                    var data;
                    if (members != null)
                      members.map((e) {
                        if (e.contains(getStringAsync(userId)) &&
                            contact.groupRefUrl == snap.data![index]['id']) {
                          if (snap.data != null) data = snap.data![index];
                          print("--------377773>>>${snap.data![index]}");
                        }
                      }).toList();
                    return data != null
                        ? InkWell(
                            onTap: () async {
                              setValue(CURRENT_GROUP_ID, data['id']);

                              //  bool? res = await GroupChatScreen(groupChatId: data['id'], groupName: data['name'], groupData: data).launch(context);
                              GroupChatScreen(
                                groupChatId: data['id'],
                                groupName: data['name'],
                                groupData: data,
                                isArchive: true,
                              ).launch(context);
                              await groupChatMessageService
                                  .setUnReadStatusToTrue(groupDocId: data['id'])
                                  .then((value) {});
                              // if (res != null || res == null) {
                              //
                              //   setState(() {});
                              // }
                            },
                            onLongPress: () async {
                              setValue(CURRENT_GROUP_ID, data['id']);
                              await showInDialog(
                                context,
                                builder: (p0) {
                                  return ChatOptionDialog(
                                    groupId: data['id'],
                                    data: contact,
                                    isGroup: true,
                                    isFromArchive: true,
                                  );
                                },
                                contentPadding: EdgeInsets.zero,
                                dialogAnimation:
                                    DialogAnimation.SLIDE_TOP_BOTTOM,
                              );
                              setState(() {});
                            },
                            child: Container(
                              padding: EdgeInsets.symmetric(
                                  horizontal: 16, vertical: 8),
                              child: Row(
                                children: [
                                  Stack(
                                    children: [
                                      noProfileImageFound(
                                              height: 45,
                                              width: 45,
                                              isGroup: true)
                                          .cornerRadiusWithClipRRect(50),
                                      data['photoUrl'] == null
                                          ? noProfileImageFound(
                                                  height: 45,
                                                  width: 45,
                                                  isGroup: true)
                                              .cornerRadiusWithClipRRect(50)
                                              .onTap(() {
                                              showDialog(
                                                context: context,
                                                builder: (context) {
                                                  return GroupProfileImageDailog(
                                                      data: data);
                                                },
                                              );
                                            })
                                          : Hero(
                                              tag: data['photoUrl'],
                                              child: Image.network(
                                                data['photoUrl'],
                                                height: 50,
                                                width: 50,
                                                fit: BoxFit.cover,
                                                errorBuilder: (_, __, ___) {
                                                  return noProfileImageFound(
                                                      height: 45,
                                                      width: 45,
                                                      isGroup: true);
                                                },
                                              ).cornerRadiusWithClipRRect(50),
                                            ).onTap(() {
                                              showDialog(
                                                context: context,
                                                builder: (context) {
                                                  return GroupProfileImageDailog(
                                                      data: data);
                                                },
                                              );
                                            }),
                                    ],
                                  ),
                                  10.width,
                                  Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          Text(
                                            data['name']
                                                .toString()
                                                .capitalizeFirstLetter(),
                                            style: TS.primaryTextStyle(),
                                            maxLines: 1,
                                            textAlign: TextAlign.start,
                                            overflow: TextOverflow.ellipsis,
                                          ).expand(),
                                          2.width,
                                          StreamBuilder<int>(
                                            stream: groupChatMessageService
                                                .getUnReadCount(
                                                    currentUser:
                                                        getStringAsync(userId),
                                                    groupDocId: data['id']),
                                            builder: (context, snap) {
                                              if (snap.hasData) {
                                                print(
                                                    "unread count for groups====== ${snap.data}");
                                                if (snap.data != 0) {
                                                  //chatMessageService.fetchForMessageCount(loginStore.mId);
                                                  return Container(
                                                    height: 18,
                                                    width: 18,
                                                    decoration: BoxDecoration(
                                                        borderRadius:
                                                            BorderRadius
                                                                .circular(20),
                                                        color: primaryColor),
                                                    child: Text(
                                                            snap.data
                                                                .validate()
                                                                .toString(),
                                                            style: TS
                                                                .secondaryTextStyle(
                                                                    color: Colors
                                                                        .white))
                                                        .center(),
                                                  );
                                                }
                                              }
                                              return Offstage();
                                            },
                                          ),
                                        ],
                                      ),
                                      2.height,
                                      Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          LastMessageContainer(
                                            stream: groupChatMessageService
                                                .fetchLastMessageBetween(
                                              groupDocId: data['id'],
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ).expand(),
                                ],
                              ),
                            ),
                          )
                        : SizedBox();
                  },
                )
              : noDataFound();
        }
        return snapWidgetHelper(snap, loadingWidget: Offstage());
      },
    );
  }

  Future<UserModel?> getUser(DocumentReference data) async {
    return await data
        .get()
        .then(
            (value) => UserModel.fromJson(value.data() as Map<String, dynamic>))
        .catchError((e) {
      log(e);
      return e;
    });
  }
}
