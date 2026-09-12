import 'package:flutter/material.dart';
import 'package:nb_utils/nb_utils.dart';

import 'package:chat/centralized_import.dart';

import '../../utils/TextStyles.dart' as TS;

class ThemeSelectionDialog extends StatefulWidget {
  static String tag = '/ThemeSelectionDialog';

  @override
  ThemeSelectionDialogState createState() => ThemeSelectionDialogState();
}

class ThemeSelectionDialogState extends State<ThemeSelectionDialog> {
  List<String> themeModeList = [
    'light'.translate,
    'dark'.translate,
    'system_default'.translate
  ];

  int? currentIndex = 0;

  @override
  void initState() {
    super.initState();
    init();
  }

  Future<void> init() async {
    currentIndex = getIntAsync(THEME_MODE_INDEX);
  }

  @override
  void setState(fn) {
    if (mounted) super.setState(fn);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: context.width(),
      color: appStore.isDarkMode ? Colors.black : Colors.white,
      child: ListView.builder(
        shrinkWrap: true,
        padding: EdgeInsets.zero,
        itemCount: themeModeList.length,
        itemBuilder: (BuildContext context, int index) {
          return RadioListTile(
            value: index,
            groupValue: currentIndex,
            activeColor: primaryColor,
            fillColor: MaterialStateProperty.all(
              appStore.isDarkMode ? white : primaryColor,
            ),
            title: Text(themeModeList[index], style: TS.primaryTextStyle()),
            onChanged: (dynamic val) {
              setState(() {
                currentIndex = val;

                if (val == ThemeModeSystem) {
                  appStore.setDarkMode(
                      MediaQuery.of(context).platformBrightness ==
                          Brightness.dark);
                } else if (val == ThemeModeLight) {
                  appStore.setDarkMode(false);
                } else if (val == ThemeModeDark) {
                  appStore.setDarkMode(true);
                }

                setValue(THEME_MODE_INDEX, val);
              });

              finish(context);
            },
          );
        },
      ),
    );
  }
}
