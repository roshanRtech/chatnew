import 'package:flutter/material.dart';
import 'package:nb_utils/nb_utils.dart';

import 'package:chat/centralized_import.dart';

class FontSelectionDialog extends StatefulWidget {
  static String tag = '/ThemeSelectionDialog';

  @override
  FontSelectionDialogState createState() => FontSelectionDialogState();
}

class FontSelectionDialogState extends State<FontSelectionDialog> {
  int? currentIndex = 0;

  @override
  void initState() {
    super.initState();
    init();
  }

  Future<void> init() async {
    currentIndex = await getIntAsync(FONT_SIZE_INDEX, defaultValue: 1);
    appStore.setFontSize(
        fontSizes()[currentIndex!].fontSize.validate(), currentIndex!);
    if (mounted) setState(() {});
  }

  @override
  void setState(fn) {
    if (mounted) super.setState(fn);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: context.width(),
      color: appStore.isDarkMode ? Colors.grey[900] : primaryColor,
      child: ListView.builder(
        shrinkWrap: true,
        padding: EdgeInsets.zero,
        itemCount: fontSizes().length,
        itemBuilder: (BuildContext context, int index) {
          return RadioListTile(
            activeColor: primaryColor,
            value: index,
            groupValue: currentIndex,
            fillColor: MaterialStateProperty.all(
              Colors.white,
            ),
            title: Text(fontSizes()[index].name.validate(),
                style: primaryTextStyle(color: Colors.white)),
            onChanged: (dynamic val) {
              setState(() {
                currentIndex = val;
                appStore.setFontSize(fontSizes()[val].fontSize.validate(), val);
                setValue(FONT_SIZE_PREF, fontSizes()[val].fontSize.validate());
                setValue(FONT_SIZE_INDEX, val);
              });
              finish(context);
            },
          );
        },
      ),
    );
  }
}
