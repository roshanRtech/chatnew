import 'package:chat/screens/StoryPrivacySelectedUserScreen.dart';
import 'package:chat/utils/AppCommon.dart';
import 'package:flutter/material.dart';
import 'package:nb_utils/nb_utils.dart';

import '../main.dart';
import '../models/StoryModel.dart';
import '../utils/AppColors.dart';
import '../utils/AppConstants.dart';
import 'PickupLayout.dart';

class StoryPrivacySettingScreen extends StatefulWidget {
  const StoryPrivacySettingScreen({super.key});

  @override
  State<StoryPrivacySettingScreen> createState() => _StoryPrivacySettingScreenState();
}

class _StoryPrivacySettingScreenState extends State<StoryPrivacySettingScreen> {
  List<String> statusPrivacyList = ['my_contacts'.translate, 'my_contacts_except'.translate, 'only_share_with'.translate];
  List<String> contactList = ['', 'excluded'.translate, 'included'.translate];

  int? currentIndex = 0;
  int? selectedIncludedValue;
  int? selectedExcludedValue;

  List<String> excludedList = [];
  List<String> includedList = [];
  List<String> selectedExcludedList = [];
  List<String> selectedIncludedList = [];
  StoryModel data = StoryModel();
  // int groupValue = 0;

  @override
  void initState() {
    super.initState();
    init();
  }

  init() async {
    getStoryData();
    currentIndex = getIntAsync(STATUS_PRIVACY_INDEX);
  }

  getStoryData() async {
    List<StoryModel> stories = await storyService.getStoriesData();

    for (int i = 0; i < stories.length; i++) {
      if (getStringAsync(userId) == stories[i].userId) {
        excludedList.addAll(stories[i].excludedUserList!);
        includedList.addAll(stories[i].includedUserList!);
      }
    }
    if (excludedList.isNotEmpty) {
      selectedExcludedValue = excludedList.length;
    }
    if (includedList.isNotEmpty) {
      selectedIncludedValue = includedList.length;
    }
    setState(() {});
  }

  void _onChanged(int value) {
    setState(() {
      currentIndex = value;
    });
  }

  @override
  void setState(fn) {
    if (mounted) super.setState(fn);
  }

  @override
  Widget build(BuildContext context) {
    return PickupLayout(
      child: Scaffold(
        appBar: appBarWidget("status_privacy".translate, textColor: Colors.white),
        body: Column(mainAxisAlignment: MainAxisAlignment.start, crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(
            "who_can_see_my_status_updates".translate,
            style: secondaryTextStyle(
              color: appStore.isDarkMode ? white : black,
            ),
          ).paddingOnly(left: 12, top: 12),
          Container(
            width: context.width(),
            child: ListView.builder(
              shrinkWrap: true,
              padding: EdgeInsets.zero,
              itemCount: statusPrivacyList.length,
              itemBuilder: (BuildContext context, int index) {
                return RadioListTile(
                  value: index,
                  groupValue: currentIndex,
                  activeColor: primaryColor,
                  fillColor: WidgetStateProperty.all(
                    appStore.isDarkMode ? white : primaryColor,
                  ),
                  title: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(statusPrivacyList[index], style: primaryTextStyle(color: appStore.isDarkMode ? white : black, size: 16)),
                      Text(
                              '${contactList[index] == "excluded".translate || contactList[index] == "included".translate ? contactList[index] == "excluded".translate ? selectedExcludedValue.validate() : " " + selectedIncludedValue.validate().toString() : ''}' +
                                  " " +
                                  contactList[index],
                              style: secondaryTextStyle(color: primaryColor, size: 12, weight: FontWeight.bold))
                          .onTap(() {
                        if (contactList[index] == "excluded".translate) {
                          StoryPrivacySelectedUserScreen(
                            isOnlyShareWith: true,
                            statusPrivacyValueLength: (excludedValue, includedValue, selectedEList) {
                              setState(() {
                                selectedExcludedValue = excludedValue;
                                selectedExcludedList = selectedEList;
                              });
                              // selectedExcludedValue = excludedValue;
                              print("Selected Excluded Length Value " + selectedExcludedValue.toString());

                              selectedEList.forEach((user) {
                                if (!selectedExcludedList.contains(user)) {
                                  selectedExcludedList.add(user);
                                }
                              });
                              setState(() {});
                            },
                            excludedList: excludedList.isNotEmpty ? excludedList : selectedExcludedList,
                          ).launch(context);
                        } else if (contactList[index] == "included".translate) {
                          StoryPrivacySelectedUserScreen(
                            isOnlyShareWith: false,
                            statusPrivacyValueLength: (excludedValue, includedValue, selectedIList) {
                              selectedIncludedValue = includedValue;
                              print("Selected Include Length Value " + selectedIncludedValue.toString());
                              selectedIList.forEach((user) {
                                if (!selectedIncludedList.contains(user)) {
                                  selectedIncludedList.add(user);
                                }
                              });
                              setState(() {});
                            },
                            includedList: includedList.isNotEmpty ? includedList : selectedIncludedList,
                          ).launch(context);
                        } else {}
                      }),
                    ],
                  ).onTap(() {
                    _onChanged(index);
                  }),
                  onChanged: (dynamic val) {
                    setState(() {
                      _onChanged(val);
                      currentIndex = val;

                      if (val == StatusPrivacyMyContacts) {
                      } else if (val == StatusPrivacyMyContactsExcept) {
                        appStore.setStatusPrivacyValue(EXCLUDED);
                      } else if (val == StatusPrivacyOnlyShareWith) {
                        appStore.setStatusPrivacyValue(INCLUDED);
                      }

                      setValue(STATUS_PRIVACY_INDEX, val);

                    });

                    // finish(context);
                  },
                );
              },
            ),
          )
        ]),
      ),
    );
  }
}
