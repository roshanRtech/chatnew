import 'package:flutter/material.dart';
import 'package:nb_utils/nb_utils.dart';

import 'package:chat/centralized_import.dart';

import '../../utils/TextStyles.dart' as TS;

class AppLanguageDialog extends StatefulWidget {
  static String tag = '/ThemeSelectionDialog';

  @override
  AppLanguageDialogState createState() => AppLanguageDialogState();
}

class AppLanguageDialogState extends State<AppLanguageDialog> {
  int? currentIndex = 0;

  @override
  void initState() {
    super.initState();
    init();
  }

  Future<void> init() async {
    currentIndex = getIntAsync(SELECTED_LANGUAGE, defaultValue: 0);
    setState(() {});
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
        itemCount: Language.getLanguages().length,
        itemBuilder: (BuildContext context, int index) {
          Language data = Language.getLanguages()[index];
          return RadioListTile(
            value: index,
            groupValue: currentIndex,
            activeColor: primaryColor,
            title: Text(data.name.validate(),
                style: TS.primaryTextStyle(color: Colors.white)),
            secondary: Image.asset(data.flag.validate(), width: 30, height: 30),
            fillColor: MaterialStateProperty.all(
              Colors.white,
            ),
            onChanged: (dynamic val) async {
              hideKeyboard(context);
              currentIndex = val;
              setValue(SELECTED_LANGUAGE, val);
              appStore.setLanguage(Language.getLanguages()[index].languageCode,
                  context: context);
              finish(context);
            },
          );
        },
      ),
    );
  }
}
