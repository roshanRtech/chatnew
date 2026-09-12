import 'package:chat/utils/AppCommon.dart';
import 'package:flutter/material.dart';
import 'package:nb_utils/nb_utils.dart';

import '../../models/StoryModel.dart';
import '../../screens/StoryListScreen.dart';
import '../../utils/AppColors.dart';
import '../../utils/Appwidgets.dart';
import '../main.dart';
import '../models/UserModel.dart';
import '../utils/AppConstants.dart';

class StoryListWidget extends StatefulWidget {
  static String tag = '/StoryListWidget';
  final List<RecentStoryModel> list;

  StoryListWidget(
    this.list,
  );

  @override
  State<StoryListWidget> createState() => _StoryListWidgetState();
}

class _StoryListWidgetState extends State<StoryListWidget> {
  String name = '';
  String userImage = '';

  @override
  void initState() {
    init();
    super.initState();
  }

  init() async {
    widget.list.sort((a, b) => a.createAt!.compareTo(b.createAt!));
    setState(() {});
  }

  @override
  void setState(fn) {
    if (mounted) super.setState(fn);
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      alignment: Alignment.center,
      children: [
        ListView.builder(
            itemCount: widget.list.length,
            shrinkWrap: true,
            itemBuilder: (_, i) {
              RecentStoryModel data = widget.list[i];

              // Safely checking if included and excluded lists contain userId and if they are not null
              final isUserIdIncluded = data.includedUserList?.contains(getStringAsync(userId)) ?? false;
              final isUserIdExcluded = data.excludedUserList?.contains(getStringAsync(userId)) ?? false;

              final isExcludedContainsLength = data.excludedUserList?.isNotEmpty ?? false;
              final isIncludedContainsLength = data.includedUserList?.isNotEmpty ?? false;

              print("============ Story List widget starts  =============");
              print("Is USER ID INCLUDED ===> " + isUserIdIncluded.toString());
              print("Is USER ID EXCLUDED ===> " + isUserIdExcluded.toString());
              print("Excluded List is =====> " + data.excludedUserList.toString());
              print("Included List is =====> " + data.includedUserList.toString());
              print("============ Story List widget Ends  =============");

              // Adjusting visibility logic based on included and excluded conditions
              bool isVisible = false;

              // Show only if the story is included or there is no exclusion condition
              if (isIncludedContainsLength && !isExcludedContainsLength) {
                isVisible = true;
              } else if (!isIncludedContainsLength && !isExcludedContainsLength) {
                // Optionally, you can add this condition to make it visible when both lists are empty
                isVisible = true;
              }

              return Row(
                children: [
                  Container(
                    height: 55,
                    width: 55,
                    decoration: BoxDecoration(
                      color: getColorFromString(data.list?.first.userId ?? ''),
                      shape: BoxShape.circle,
                      border: Border.all(color: primaryColor, width: 1.5),
                    ),
                    child: Text(
                      data.list?.first.userName.validate()[0].toUpperCase()??'',
                      style: secondaryTextStyle(color: Colors.white),
                    ).center().fit(),
                  ).cornerRadiusWithClipRRect(55 / 2),
                 /* Container(
                    height: 55,
                    width: 55,
                    margin: EdgeInsets.only(top: 4, bottom: 4),
                    decoration: BoxDecoration(border: Border.all(color: primaryColor, width: 2), borderRadius: radius(30)),
                    child: cachedImage(isUserIdIncluded || isUserIdExcluded ? data.list!.first.imagePath.validate() : data.list!.last.imagePath.validate(), height: context.height(), fit: BoxFit.cover)
                        .cornerRadiusWithClipRRect(50),
                  ),*/
                  16.width,
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      data.userName.isEmptyOrNull
                          ? FutureBuilder<UserModel>(
                              future: userService.getUserById(val: data.userId),
                              builder: (c, n) {
                                if (n.hasData && n.data != null) {
                                  name = n.data!.name.validate();
                                  userImage = n.data!.photoUrl.validate();
                                  return Text(n.data!.name.validate().capitalizeEachWord(), style: boldTextStyle(size: 18));
                                }
                                return snapWidgetHelper(n, loadingWidget: Loader());
                              })
                          : Text(data.userName.validate().capitalizeEachWord(), style: boldTextStyle(size: 18)),
                      Text(formatTime(data.createAt!.millisecondsSinceEpoch.validate()), style: secondaryTextStyle()),
                    ],
                  )
                ],
              ).paddingSymmetric(horizontal: 16, vertical: 4).onTap(() async {
                if (data.list?.isNotEmpty ?? false) {
                  StoryListScreen(
                    list: data.list,
                    userName: data.userName,
                    time: data.createAt,
                    userImg: data.userImgPath,
                    isStoryItemShow: false,
                  ).launch(context);
                }
              }).visible(isVisible);
            }).visible(widget.list.isNotEmpty),
      ],
    );
  }


}
