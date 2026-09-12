import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:nb_utils/nb_utils.dart';

import 'package:chat/centralized_import.dart';

import '../../utils/TextStyles.dart' as TS;

class NewGroupScreen extends StatefulWidget {
  final AsyncSnapshot<List<UserModel>>? snap;
  final bool isAddParticipant;
  final String? groupId;
  final dynamic data;

  NewGroupScreen(
      {this.snap, this.isAddParticipant = false, this.groupId, this.data});

  @override
  NewGroupScreenState createState() => NewGroupScreenState();
}

class NewGroupScreenState extends State<NewGroupScreen> {
  bool isSearch = false;
  bool autoFocus = false;
  TextEditingController searchCont = TextEditingController();
  String search = '';
  bool isFirst = false;

  List<UserModel> selectedList = [];
  List<UserModel> userList = [];

  List membersList = [];
  List existingMembersList = [];
  List<UserModel> userModelList = [];
  String admin = '';
  FirebaseFirestore _firestore = FirebaseFirestore.instance;
  String useridNew = "";

  @override
  void initState() {
    super.initState();
    init();
  }

  Future<void> init() async {
    useridNew = getStringAsync(userId);
    print("Init time calling ===>" + widget.snap.toString());
    getGroupDetails();
  }

  @override
  void setState(fn) {
    if (mounted) super.setState(fn);
  }

  Future getGroupDetails() async {
    await _firestore
        .collection(GROUPS_COLLECTION)
        .doc(widget.groupId)
        .get()
        .then((chatMap) {
      admin = chatMap['createdBy'];
      membersList = chatMap['membersList'];
      if (widget.isAddParticipant) {
        existingMembersList.addAll(membersList);
      }
      appStore.isLoading = false;
      getMemberList();
    }).catchError((e) {
      log(e.toString());
    });
  }

  getMemberList() {
    membersList.forEach((element) async {
      UserModel userm = await userService.getUserById(val: element);
      userModelList.add(userm);
      setState(() {});
    });
  }

  Future addMember() async {
    print("---------101>>>");

    List<String> selectedNewMember = getStringListAsync(selectedMember)!;
    List<UserModel> newUserList = [];

    for (String uid in selectedNewMember) {
      UserModel user = await userService.getUserById(val: uid);
      newUserList.add(user);
    }

    await _firestore.collection(GROUPS_COLLECTION).doc(widget.groupId).update({
      "membersList": FieldValue.arrayUnion(selectedNewMember),
    }).then((value) async {
      ContactModel data = ContactModel();
      data.uid = widget.groupId;
      data.addedOn = Timestamp.now();
      data.lastMessageTime = DateTime.now().millisecondsSinceEpoch;
      data.groupRefUrl = widget.groupId;
      for (var e in selectedNewMember) {
        chatMessageService
            .getContactsDocument(of: e, forContact: widget.groupId)
            .set(data.toJson())
            .catchError((e) {
          log(e);
        });
      }

      // Add contact for current user
      chatMessageService
          .getContactsDocument(
              of: getStringAsync(userId), forContact: widget.groupId)
          .set(data.toJson())
          .catchError((e) {
        log(e);
      });

      // Update readBy field
      groupChatMessageService.addNewParticipantToReadyBy(
          groupDocId: widget.groupId.toString(),
          newParticipantsUserIds: selectedNewMember,
          userModelList: newUserList,
          adminName: getStringAsync(userDisplayName).toString());

      appStore.isLoading = false;
      isFirst = false;
      finish(context, true);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: appBarWidget(
        "",
        textColor: Colors.white,
        titleWidget: widget.isAddParticipant
            ? Text('lblAddparticipants'.translate.capitalizeEachWord(),
                style:
                    TS.boldTextStyle(color: Colors.white, letterSpacing: 0.5))
            : Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Text('create_group'.translate.capitalizeEachWord(),
                      style: TS.boldTextStyle(
                          color: Colors.white, letterSpacing: 0.5)),
                  4.height,
                  Text('lblAddparticipants'.translate.capitalizeEachWord(),
                      style: TS.secondaryTextStyle(
                          color: Colors.white, letterSpacing: 0.5))
                ],
              ),
        actions: [
          AnimatedContainer(
            duration: Duration(milliseconds: 100),
            curve: Curves.decelerate,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                if (isSearch)
                  TextField(
                    autofocus: true,
                    textAlignVertical: TextAlignVertical.center,
                    cursorColor: Colors.white,
                    onChanged: (s) {
                      setState(() {});
                    },
                    style: TS.secondaryTextStyle(color: Colors.white),
                    controller: searchCont,
                    decoration: InputDecoration(
                      border: InputBorder.none,
                      hintText: 'lblSearchHere'.translate,
                      hintStyle: TS.secondaryTextStyle(color: Colors.white),
                    ),
                  ).expand(),
                IconButton(
                  icon: isSearch ? Icon(Icons.close) : Icon(Icons.search),
                  onPressed: () async {
                    isSearch = !isSearch;
                    searchCont.clear();
                    search = "";
                    setState(() {});
                  },
                  color: Colors.white,
                )
              ],
            ),
            width: isSearch ? context.width() - 86 : 50,
          ),
        ],
      ),
      body: Stack(
        children: [
          StreamBuilder<List<UserModel>>(
            stream: userService.users(searchText: searchCont.text),
            builder: (_, snap) {
              if (snap.hasData) {
                if (snap.data != null && snap.data!.isNotEmpty)
                  snap.data!.sort((a, b) => a.name
                      .validate()
                      .toLowerCase()
                      .compareTo(b.name.validate().toLowerCase()));
                if (snap.data!.length == 0) {
                  return noDataFound(text: 'no_user_found'.translate)
                      .withHeight(context.height())
                      .center();
                }
                return UserListComponent(
                  snap: snap,
                  isGroupCreate: true,
                  isAddParticipant: widget.isAddParticipant,
                  data: existingMembersList,
                );
              }
              return snapWidgetHelper(snap);
            },
          ),
          Loader().center().visible(appStore.isLoading),
        ],
      ),
      floatingActionButton: widget.isAddParticipant
          ? FloatingActionButton(
              onPressed: () {
                appStore.isLoading = true;
                List<String> data = getStringListAsync(selectedMember)!;
                print("Selected Member ===>" + data.toString());
                setState(() {});
                appStore.isLoading = false;
                if (data.isNotEmpty) {
                  if (isFirst == false) {
                    if (widget.isAddParticipant) {
                      isFirst = true;
                      print("---------206>>>${widget.isAddParticipant}");
                      addMember();
                    } else {
                      CreateGroupScreen1().launch(context,
                          pageRouteAnimation: PageRouteAnimation.SlideBottomTop,
                          duration: 300.milliseconds);
                      isFirst = false;
                    }
                  }
                } else {
                  toast(
                      'lblPleaseSelectMembers'.translate.capitalizeEachWord());
                }
              },
              child: Icon(Icons.check, color: Colors.white),
              backgroundColor: primaryColor)
          : FloatingActionButton(
              onPressed: () {
                print(getStringListAsync(selectedMember).toString());

                if (getStringListAsync(selectedMember) != null &&
                    getStringListAsync(selectedMember)!.isNotEmpty) {
                  print("---------224>>>${widget.isAddParticipant}");

                  if (widget.isAddParticipant) {
                    //
                    addMember();
                  } else {
                    CreateGroupScreen1().launch(context,
                        pageRouteAnimation: PageRouteAnimation.SlideBottomTop,
                        duration: 300.milliseconds);
                  }
                } else {
                  print("Else ");
                  toast(
                      'lblPleaseSelectMembers'.translate.capitalizeEachWord());
                }
                setState(() {});
              },
              child: Icon(Icons.arrow_forward_outlined, color: Colors.white),
              backgroundColor: primaryColor),
    );
  }
}
