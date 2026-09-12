
import 'package:flutter/material.dart';
import 'package:nb_utils/nb_utils.dart';
import 'package:rxdart/rxdart.dart';
import '../../utils/TextStyles.dart' as TS;

import 'package:chat/centralized_import.dart';


class Shareprofilescreen extends StatefulWidget {
  final AsyncSnapshot<List<UserModel>>? snap;
  final bool isAddParticipant;
  final dynamic data;
  final UserModel? receiverUser;
  final String? messageId;
  final String? groupId;
  final String? groupName;
  final String? groupProfile;
  final bool? isFromGroup;

  Shareprofilescreen({this.snap, this.isAddParticipant = false,this.groupId,this.groupName,this.groupProfile, this.data, this.messageId, this.receiverUser, this.isFromGroup = false});

  @override
  State<Shareprofilescreen> createState() => _ShareprofilescreenState();
}

class _ShareprofilescreenState extends State<Shareprofilescreen> {
  bool isSearch = false;
  bool autoFocus = false;
  TextEditingController searchCont = TextEditingController();
  String search = '';
  List forwardUserList = [];

  List<UserModel> selectedList = [];
  List<UserModel> userList = [];
  List<UserModel> userModelList = [];
  bool isLoading = true;
  String useridNew = "";

  @override
  void initState() {
    super.initState();
    init();
  }

  init() async {
    useridNew = getStringAsync(userId);

    print("Init Time Is Group Or Not at Forward User List Screen ==> " + widget.isFromGroup.toString());
  }

  @override
  void setState(fn) {
    if (mounted) super.setState(fn);
  }

  // Group Stream
  Stream<List<dynamic>> group({String? searchText}) {
    return fireStore.collection('group').where('searchCase', arrayContains: searchText.validate().isEmpty ? null : searchText!.toLowerCase()).snapshots().map((x) {
      return x.docs.map((y) {
        return y.data();
      }).toList();
    });
  }

  // Merge Stream
  Stream<List<UserModel>> getUserStream(String searchText) {
    return userService.users(searchText: searchText);
  }

  Stream<List<dynamic>> getGroupStream(String searchText) {
    return group(searchText: searchText);
  }

  Stream<Map<String, dynamic>> getCombinedStream(String searchText) {
    return Rx.combineLatest2(
      getUserStream(searchText),
      getGroupStream(searchText),
      (List<UserModel> users, List<dynamic> group) {
        users = users.where((user) => user.userRole != 'admin').toList();
        return {
          'users': users,
          'group': group,
        };
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: appBarWidget(
        'forward_to'.translate,
        textColor: Colors.white,
        actions: [
          AnimatedContainer(
            margin: EdgeInsets.only(left: 8),
            duration: Duration(milliseconds: 100),
            curve: Curves.decelerate,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.start,
              children: [
                if (isSearch)
                  TextField(
                    autofocus: true,
                    textAlignVertical: TextAlignVertical.center,
                    cursorColor: Colors.white,
                    onChanged: (f) {
                      LiveStream().emit(SEARCH_KEY_FORWARD, f);
                      setState(() {});
                    },
                    style: TS.boldTextStyle(color: Colors.white),
                    controller: searchCont,
                    decoration: InputDecoration(
                      border: InputBorder.none,
                      hintText: "lblSearchHere".translate,
                      hintStyle:TS.secondaryTextStyle(color: Colors.white),
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
                ),
              ],
            ),
            width: isSearch ? context.width() - 86 : 50,
          ),
        ],
      ),
      body: StreamBuilder<Map<String, dynamic>>(
        stream: getCombinedStream(searchCont.text),
        builder: (_, snap) {
          print("--------------144>>>>${widget.receiverUser}");
          if (snap.hasData) {
            if (snap.data!.length == 0) {
              return noDataFound(text: 'no_user_found'.translate).withHeight(context.height()).center();
            }

            // Merge two streams
            List<UserModel> users = snap.data!['users'];
            List<dynamic> group = snap.data!['group'];
            final userSnap = AsyncSnapshot.withData(ConnectionState.done, users);
            final groupSnap = AsyncSnapshot.withData(ConnectionState.done, group);
            users.sort((a, b) => (a.name??"").toLowerCase().compareTo(b.name?.toLowerCase()??''));
            group.sort((a, b) => a['name'].toLowerCase().compareTo(b['name'].toLowerCase()));

            return Forwarduserlistshareprofilecomponent(
              isFromForward: true,
              snap: userSnap,
              groupDara: groupSnap,
              isGroupCreate: true,
              groupId: widget.groupId,
              groupName: widget.groupName,
              groupProfile: widget.groupProfile,
              shareUserData: widget.receiverUser,
              isAddParticipant: widget.isAddParticipant,
              isFromGroup: widget.isFromGroup,
            );
          }
          return snapWidgetHelper(snap);
        },
      ),
    );
  }
}
