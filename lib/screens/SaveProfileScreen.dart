import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:country_code_picker/country_code_picker.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_mobx/flutter_mobx.dart';
import 'package:image_picker/image_picker.dart';
import 'package:nb_utils/nb_utils.dart';

import 'package:chat/centralized_import.dart';

import '../../utils/TextStyles.dart' as TS;

// ignore: must_be_immutable
class SaveProfileScreen extends StatefulWidget {
  bool? mIsShowBack = true;
  bool? mIsFromLogin = false;

  SaveProfileScreen({this.mIsShowBack, this.mIsFromLogin});

  @override
  SaveProfileScreenState createState() => SaveProfileScreenState();
}

class SaveProfileScreenState extends State<SaveProfileScreen> {
  var formKey = GlobalKey<FormState>();

  bool phoneAuth = false;
  String? countryCode = '';
  String? selectedCountries = "";
  // var cropKey = GlobalKey<CropState>();

  File? imageFile;
  XFile? pickedFile;

  TextEditingController nameCont = TextEditingController();
  TextEditingController emailCont = TextEditingController();
  TextEditingController mobileNumberCont = TextEditingController();
  TextEditingController statusCont = TextEditingController();

  @override
  void initState() {
    super.initState();
    checkLoginMethod();
    init();
  }

  Future init() async {
    appStore.setLoading(true);
    await userService.getUser(email: getStringAsync(userEmail)).then((value) {
      nameCont.text = value.name ?? '';
      emailCont.text = value.email ?? '';
      String? localNumber =
          value.phoneNumber?.replaceFirst(value.countryCode ?? '', '');
      mobileNumberCont.text = localNumber ?? '';
      statusCont.text = value.userStatus ?? '';
      countryCode = value.countryCode;
      loginStore.setDisplayName(aDisplayName: value.name);
      loginStore.setStatus(aStatus: value.userStatus);
      loginStore.setPhotoUrl(aPhotoUrl: value.photoUrl.validate());
      loginStore.setCurrentUser(value);
      setState(() {});
    }).catchError((error) {
      toast(error.toString());
    }).whenComplete(() {
      appStore.setLoading(false);
    });
  }

  void validate() async {
    print('dffgjhgfjhsdgjhsgdf');
    print('-----------76-->${countryCode}');
    print('-----------77-->${mobileNumberCont.text.trim()}');
    print('-----------78-->${defaultCountryCode}');
    hideKeyboard(context);
    var phoneNumberExist = await userService.isPhoneNumberTaken(
        '${(!countryCode.isEmptyOrNull) ? countryCode : defaultCountryCode}${mobileNumberCont.text.trim()}',
        getStringAsync(userId));
    //  bool emailExists = await userService.isEmailTaken(emailCont.text.trim(), getStringAsync(userId));

    if (formKey.currentState!.validate()) {
      appStore.isLoading = true;
      if (phoneNumberExist == true) {
        toast('lblExistPhoneMsg'.translate);
        appStore.setLoading(false);
        return;
      }
      /* if (emailExists) {
        toast("Email already exists.");
        appStore.setLoading(false);
        return;
      }
*/
      formKey.currentState!.save();
      Map<String, dynamic> data = {
        'name': nameCont.text.trim(),
        'updatedAt': Timestamp.now(),
        'countryCode':
            '${(!countryCode.isEmptyOrNull) ? countryCode : defaultCountryCode}',
        'phoneNumber':
            '${(!countryCode.isEmptyOrNull) ? countryCode : defaultCountryCode}${mobileNumberCont.text.trim()}',
        "userStatus": statusCont.text.trim(),
        'caseSearch': setSearchParam(nameCont.text.trim()),
      };
      if (imageFile != null) {
        XFile? fileVal = await imageCompress(filepath: imageFile!.path);
        if (fileVal != null) {
          imageFile = File(fileVal.path);
        }
      }
      userService
          .updateUserInfo(data, getStringAsync(userId),
              profileImage: imageFile != null ? File(imageFile!.path) : null)
          .then((value) {
        toast('profile_updated'.translate);
        setValue(isCountryCode, countryCode);
        loginStore.setDisplayName(aDisplayName: nameCont.text.trim());
        loginStore.setMobileNumber(aMobileNumber: mobileNumberCont.text.trim());
        loginStore.setStatus(aStatus: statusCont.text.trim().validate());
        if (widget.mIsFromLogin!) {
          setValue(userMobileNumber, mobileNumberCont.text.trim());
          DashboardScreen().launch(context, isNewTask: true);
        } else {
          finish(context);
        }
      }).catchError((e) {
        log(e.toString());
        toast(e.toString());
      }).whenComplete(() {
        appStore.isLoading = false;
      });
    }
  }

  Widget profileImage() {
    if (imageFile != null) {
      return Hero(
          tag: 'profile_image',
          child: Image.file(File(imageFile?.path ?? ''),
                  height: 140,
                  width: 140,
                  fit: BoxFit.cover,
                  alignment: Alignment.center)
              .cornerRadiusWithClipRRect(90));
    } else {
      if (loginStore.mPhotoUrl.isEmptyOrNull) {
        return Hero(
            tag: 'profile_image',
            child: Image.asset('assets/user.jpg',
                    height: 140,
                    width: 140,
                    fit: BoxFit.cover,
                    alignment: Alignment.center)
                .cornerRadiusWithClipRRect(90));
      } else {
        return Hero(
            tag: 'profile_image',
            child: cachedImage(loginStore.mPhotoUrl.validate(),
                    height: 140,
                    width: 140,
                    fit: BoxFit.cover,
                    alignment: Alignment.center)
                .cornerRadiusWithClipRRect(90));
      }
    }
  }

  @override
  void setState(fn) {
    if (mounted) super.setState(fn);
  }

  @override
  void dispose() {
    super.dispose();
  }

  void checkLoginMethod() {
    User? user = FirebaseAuth.instance.currentUser;

    if (user != null) {
      for (final info in user.providerData) {
        print('Provider ID: ${info.providerId}');
        if (info.providerId == 'phone') {
          phoneAuth = true;
          setState(() {});
          print('User logged in using Phone Authentication');
        } else if (info.providerId == 'google.com') {
          print('User logged in using Google Sign-In');
        } else if (info.providerId == 'password') {
          print('User logged in using Email & Password');
        } else {
          print('Other login method: ${info.providerId}');
        }
      }
    } else {
      print('No user is currently signed in.');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: appBarWidget('save_profile'.translate,
          textColor: Colors.white, showBack: widget.mIsShowBack!),
      body: Stack(
        children: [
          SingleChildScrollView(
            child: Form(
              key: formKey,
              autovalidateMode: AutovalidateMode.onUserInteraction,
              child: Column(
                children: [
                  Stack(
                    children: [
                      profileImage(),
                      /*.onTap(
                        () {
                         // getBoolAsync(isEmailLogin) ? showBottomSheet(context) : Offstage();
                        },
                        highlightColor: Colors.transparent,
                        hoverColor: Colors.transparent,
                        splashColor: Colors.transparent,
                      ),*/
                      // getBoolAsync(isEmailLogin) ?
                      AnimatedPositioned(
                        bottom: 8,
                        right: 0,
                        duration: 2.milliseconds,
                        child: Container(
                          height: 45,
                          width: 45,
                          decoration: boxDecorationWithShadow(
                              boxShape: BoxShape.circle,
                              backgroundColor: primaryColor),
                          child: IconButton(
                            padding: EdgeInsets.zero,
                            icon: Icon(Icons.camera_alt, color: Colors.white),
                            onPressed: () {
                              showBottomSheet(context);
                            },
                          ),
                        ),
                      )
                      //  : Offstage(),
                    ],
                  ),
                  32.height,
                  AppTextField(
                    controller: nameCont,
                    textFieldType: TextFieldType.NAME,
                    textStyle: TS.primaryTextStyle(),
                    // enabled: getBoolAsync(isEmailLogin) ? true : false,
                    //  readOnly: getBoolAsync(isEmailLogin) ? false : true,
                    decoration: inputDecoration(context,
                            labelText: "full_name".translate)
                        .copyWith(
                      suffixIcon:
                          Icon(Icons.person_outline, color: secondaryColor),
                    ),
                  ),
                  16.height,
                  AppTextField(
                    controller: emailCont,
                    textFieldType: TextFieldType.EMAIL,
                    textStyle: TS.primaryTextStyle(),
                    decoration:
                        inputDecoration(context, labelText: "email".translate)
                            .copyWith(
                      suffixIcon:
                          Icon(Icons.email_outlined, color: secondaryColor),
                    ),
                    enabled: false,
                    readOnly: true,
                  ),
                  16.height,
                  /* AppTextField(
                    enabled: !phoneAuth,
                    readOnly: phoneAuth,
                    controller: mobileNumberCont,
                    textFieldType: TextFieldType.PHONE,
                    decoration: inputDecoration(context, labelText: "mobile_number".translate).copyWith(
                      suffixIcon: Icon(Icons.phone, color: secondaryColor),
                    ),
                  ),*/
                  AppTextField(
                    controller: mobileNumberCont,
                    enabled: !phoneAuth,
                    readOnly: phoneAuth,
                    textFieldType: TextFieldType.PHONE,
                    textStyle: TS.primaryTextStyle(),
                    decoration: inputDecoration(
                      context,
                      labelText: "mobile_number".translate,
                      prefix: SizedBox(
                        width: 65,
                        child: CountryCodePicker(
                          padding: EdgeInsets.zero,
                          initialSelection:
                              getStringAsync(isCountryCode).isEmptyOrNull
                                  ? defaultCountryCode
                                  : getStringAsync(isCountryCode),
                          //   initialSelection: countryCode.isEmptyOrNull?defaultCountry:countryCode,
                          showCountryOnly: false,
                          enabled: !phoneAuth,
                          showFlag: false,
                          showFlagDialog: true,
                          showOnlyCountryWhenClosed: false,
                          alignLeft: false,
                          dialogTextStyle: TS.primaryTextStyle(),
                          showDropDownButton: true,
                          dialogBackgroundColor: context.cardColor,
                          textStyle: TS.primaryTextStyle(),
                          onInit: (c) {
                            countryCode = c?.dialCode;
                          },
                          onChanged: (c) {
                            countryCode = c.dialCode;
                          },
                        ).fit(),
                      ),
                    ),
                  ),
                  16.height,
                  AppTextField(
                    controller: statusCont,
                    textFieldType: TextFieldType.OTHER,
                    minLines: 1,
                    maxLines: 4,
                    maxLength: 130,
                    keyboardType: TextInputType.multiline,
                    textStyle: TS.primaryTextStyle(),
                    textInputAction: TextInputAction.newline,
                    decoration:
                        inputDecoration(context, labelText: "status".translate)
                            .copyWith(
                      suffixIcon:
                          Icon(Icons.star_border, color: secondaryColor),
                    ),
                  ),
                  16.height,
                  AppButton(
                    width: context.width(),
                    color: context.primaryColor,
                    text: "save_profile".translate,
                    hoverColor: Colors.white,
                    onTap: () {
                      validate();
                    },
                  ),
                ],
              ).paddingAll(16),
            ),
          ),
          Observer(builder: (context) => Loader().visible(appStore.isLoading)),
        ],
      ),
    );
  }

  void getFromGallery() async {
    pickedFile = await ImagePicker().pickImage(
        source: ImageSource.gallery, maxWidth: 1800, maxHeight: 1800);
    if (pickedFile != null) {
      imageFile = File(pickedFile!.path);
      setState(() {});
    }
  }

  getFromCamera() async {
    pickedFile = await ImagePicker()
        .pickImage(source: ImageSource.camera, maxWidth: 1800, maxHeight: 1800);
    if (pickedFile != null) {
      imageFile = File(pickedFile!.path);
      setState(() {});
    }
  }

  void showBottomSheet(BuildContext context) {
    showModalBottomSheet<void>(
      backgroundColor: context.cardColor,
      context: context,
      builder: (BuildContext context) {
        return Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            SettingItemWidget(
              title: 'lblGallery'.translate,
              titleTextStyle: TS.boldTextStyle(),
              leading: Icon(Icons.image, color: primaryColor),
              onTap: () {
                getFromGallery();
                finish(context);
              },
            ),
            Divider(
              color: context.dividerColor,
            ),
            SettingItemWidget(
              title: 'camera'.translate,
              titleTextStyle: TS.boldTextStyle(),
              leading: Icon(Icons.camera, color: primaryColor),
              onTap: () {
                getFromCamera();
                finish(context);
              },
            ),
          ],
        ).paddingAll(16.0);
      },
    );
  }
}
