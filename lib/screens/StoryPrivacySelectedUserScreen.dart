import 'package:chat/utils/AppCommon.dart';
import 'package:flutter/material.dart';
import 'package:nb_utils/nb_utils.dart';
import '../components/UserListComponent.dart';
import '../main.dart';
import '../models/UserModel.dart';
import '../utils/AppColors.dart';
import '../utils/AppConstants.dart';
import '../utils/Appwidgets.dart';

class StoryPrivacySelectedUserScreen extends StatefulWidget {
  final bool isOnlyShareWith;
  final Function(int excluded, int included, List<String>)? statusPrivacyValueLength;
  List<String>? excludedList;
  List<String>? includedList;

  StoryPrivacySelectedUserScreen({this.isOnlyShareWith = false, this.statusPrivacyValueLength, this.excludedList, this.includedList});

  @override
  State<StoryPrivacySelectedUserScreen> createState() => _StatusPrivacySelectedUserScreenState();
}

class _StatusPrivacySelectedUserScreenState extends State<StoryPrivacySelectedUserScreen> {
  bool isSearch = false;
  TextEditingController searchCont = TextEditingController();
  String search = '';
  int selectedExcludeContactLength = 0;
  int selectedIncludedContactLength = 0;

  bool isSelectAll = false;

  List<String> selectedUserIdList = [];
  String useridNew = "";

  @override
  void initState() {
    super.initState();
    init();
  }

  init() async {
    useridNew = getStringAsync(userId);

    if (widget.excludedList != null && widget.excludedList!.isNotEmpty) {
      selectedExcludeContactLength = widget.excludedList!.length;
    }

    if (widget.includedList != null && widget.includedList!.isNotEmpty) {
      selectedIncludedContactLength = widget.includedList!.length;
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (bool didPop, Object? result) async{
        if (didPop) return;
        widget.statusPrivacyValueLength?.call(
          selectedExcludeContactLength,
          selectedIncludedContactLength,
          selectedUserIdList,
        );

        if (widget.isOnlyShareWith) {
          for (String id in selectedUserIdList) {
            if (!appStore.excludedSelectedUserList.contains(id)) {
              appStore.excludedSelectedUserList.add(id);
            }
          }
        } else {
          for (String id in selectedUserIdList) {
            if (!appStore.includedSelectedUserList.contains(id)) {
              appStore.includedSelectedUserList.add(id);
            }
          }
        }

        toast('setting_saved'.translate);
        finish(context);
      },
      child: Scaffold(
          appBar: appBarWidget(
            "",
            textColor: Colors.white,
            titleWidget: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                Text(widget.isOnlyShareWith ? "hide_status_from".translate.capitalizeEachWord() : 'share_status_with'.translate.capitalizeEachWord(),
                    style: boldTextStyle(color: Colors.white, size: 18, letterSpacing: 0.5)),
                4.height,
                Text(
                    '${widget.isOnlyShareWith ? selectedExcludeContactLength.toString() : selectedIncludedContactLength.toString()}' +
                        " " +
                        'contact'.translate +
                        '${widget.isOnlyShareWith ? "excluded".translate : 'selected'.translate}',
                    style: secondaryTextStyle(color: Colors.white, letterSpacing: 0.5))
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
                        style: TextStyle(color: Colors.white, fontSize: 16),
                        controller: searchCont,
                        decoration: InputDecoration(
                          border: InputBorder.none,
                          hintText: 'lblSearchHere'.translate,
                          hintStyle: TextStyle(color: Colors.white, fontSize: 16),
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
                width: isSearch ? context.width() - 86 : 100,
              ),
            ],
          ),
          body: StreamBuilder<List<UserModel>>(
            stream: userService.users(searchText: searchCont.text),
            builder: (_, snap) {
              if (snap.hasData) {
                if (snap.data != null && snap.data!.isNotEmpty) snap.data!.sort((a, b) => a.name.validate().toLowerCase().compareTo(b.name.validate().toLowerCase()));
                if (snap.data!.length == 0) {
                  return noDataFound(text: 'no_user_found'.translate).withHeight(context.height()).center();
                }
                return UserListComponent(
                  // isAddParticipant: false,
                  snap: snap,
                  isGroupCreate: true,
                  isFromStatusPrivacy: true,
                  statusPrivacyValueLength: (excludedLengthValue, includedLengthValue, ids, selectedUList) {
                    selectedExcludeContactLength = excludedLengthValue;
                    selectedIncludedContactLength = includedLengthValue;
                    selectedUserIdList = ids;

                    setState(() {});
                  },
                  excludedSelectedUserList: widget.excludedList,
                  includedSelectedUserList: widget.includedList,
                  selectedUserIds: selectedUserIdList,
                  isSelectCall: isSelectAll,
                );
              }
              return snapWidgetHelper(snap);
            },
          ),
          // floatingActionButton: FloatingActionButton(
          //     onPressed: () {
          //       widget.statusPrivacyValueLength?.call(selectedExcludeContactLength, selectedIncludedContactLength, selectedUserIdList);
          //       finish(context);
          //       if (widget.isOnlyShareWith) {
          //         for (String id in selectedUserIdList) {
          //           if (appStore.excludedSelectedUserList.contains(id)) {
          //             appStore.excludedSelectedUserList.add(id);
          //           } else {
          //             appStore.excludedSelectedUserList.add(id);
          //           }
          //         }
          //       } else {
          //         for (String id in selectedUserIdList) {
          //           if (appStore.includedSelectedUserList.contains(id)) {
          //             appStore.includedSelectedUserList.add(id);
          //           } else {
          //             appStore.includedSelectedUserList.add(id);
          //           }
          //         }
          //       }
          //       toast('setting_saved'.translate);
          //       log( "--------------zzzz${appStore.excludedSelectedUserList}");
          //     },
          //     child: Icon(Icons.check, color: Colors.white),
          //     backgroundColor: primaryColor),
          floatingActionButton: FloatingActionButton(
            onPressed: () {
              widget.statusPrivacyValueLength?.call(selectedExcludeContactLength, selectedIncludedContactLength, selectedUserIdList);

              if (widget.isOnlyShareWith) {
                // Handle excluded users
                selectedUserIdList.forEach((id) {
                  if (!appStore.excludedSelectedUserList.contains(id)) {
                    appStore.excludedSelectedUserList.add(id);
                  }
                });
              } else {
                // Handle included users
                selectedUserIdList.forEach((id) {
                  if (!appStore.includedSelectedUserList.contains(id)) {
                    appStore.includedSelectedUserList.add(id);
                  }
                });
              }

              toast('setting_saved'.translate);
              log("--------------zzzz${appStore.excludedSelectedUserList}");
              finish(context);
            },
            child: Icon(Icons.check, color: Colors.white),
            backgroundColor: primaryColor),
      ),
    );
  }
}
