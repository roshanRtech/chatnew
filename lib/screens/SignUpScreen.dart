import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:country_code_picker/country_code_picker.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_mobx/flutter_mobx.dart';
import 'package:nb_utils/nb_utils.dart';
import 'package:onesignal_flutter/onesignal_flutter.dart';

import 'package:chat/centralized_import.dart';

import '../../utils/TextStyles.dart' as TS;

class SignUpScreen extends StatefulWidget {
  final bool? isOTP;
  final User? user;
  String? countryCode;

  SignUpScreen({this.isOTP, this.user, this.countryCode});

  @override
  _SignUpScreenState createState() => _SignUpScreenState();
}

class _SignUpScreenState extends State<SignUpScreen> {
  GlobalKey<FormState> formKey = GlobalKey<FormState>();

  AuthService authService = AuthService();

  TextEditingController nameCont = TextEditingController();
  TextEditingController emailCont = TextEditingController();
  TextEditingController passCont = TextEditingController();
  TextEditingController confirmPassCont = TextEditingController();
  TextEditingController mobileNumberCont = TextEditingController();

  FocusNode nameFocus = FocusNode();
  FocusNode emailFocus = FocusNode();
  FocusNode passFocus = FocusNode();
  FocusNode confirmPasswordFocus = FocusNode();
  FocusNode mobileNumberFocus = FocusNode();
  String? countryCode = defaultCountryCode;
  String? selectedCountry = "";

  String photo = '';

  FocusNode workAddressFocus = FocusNode();

  bool isTcChecked = false;

  @override
  void initState() {
    super.initState();
    print("--------54>>${widget.user?.phoneNumber}");
    init();
  }

  init() async {
    if (widget.isOTP!) {
      appStore.setLoading(false);
      mobileNumberCont.text = widget.user?.phoneNumber ?? '';
    }
    settingsService.getSettings().then((value) {
      appSettingStore.termsCond = value.termsCondition.validate();
      appSettingStore.privacyPolicy = value.privacyPolicy.validate();
      appStore.setLoading(false);
    });
  }

  @override
  void setState(fn) {
    if (mounted) super.setState(fn);
  }

  @override
  void dispose() {
    super.dispose();
  }

  void signUpWithEmail() async {
    appStore.setLoading(true);

    var phoneNumberExist = await userService.isPhoneNumberTaken(
        '${countryCode}${mobileNumberCont.text.trim()}',
        getStringAsync(userId));
    bool emailExists = await userService.isEmailTaken(
        emailCont.text.trim(), getStringAsync(userId));
    if (formKey.currentState!.validate()) {
      formKey.currentState!.save();
      if (!isTcChecked) {
        toast("accept_terms_and_conditions".translate);
        appStore.setLoading(false);
        return;
      }
      if (phoneNumberExist == true) {
        toast('lblExistPhoneMsg'.translate);
        appStore.setLoading(false);
        return;
      }
      if (emailExists) {
        toast('lblExistEmailMsg'.translate);
        appStore.setLoading(false);
        return;
      }

      if (selectedCountry.isEmptyOrNull) {
        toast('Please select your country');
        appStore.setLoading(false);
        return;
      }
      authService
          .signUpWithEmailPassword(
        name: nameCont.text.trim(),
        email: emailCont.text.trim(),
        password: passCont.text.trim(),
        countryCode: countryCode,
        mobileNumber: '${countryCode}${mobileNumberCont.text.trim()}',
      )
          .then((value) async {
        appStore.setLoading(false);
        await setValue(playerId, OneSignal.User.pushSubscription.id.validate());
        DashboardScreen().launch(context, isNewTask: true);
      }).catchError((e) {
        appStore.setLoading(true);
        toast(e.toString());
      }).whenComplete(() {
        appStore.setLoading(false);
      });
    } else {
      appStore.setLoading(false);
    }
  }

  void signUpWithOtp() async {
    print("---------------->>>108");
    if (formKey.currentState!.validate()) {
      if (!isTcChecked) {
        toast('accept_terms_and_conditions'.translate);
        return;
      }
      var phoneNumberExist = await userService.isPhoneNumberTaken(
          widget.user?.phoneNumber ?? '', getStringAsync(userId));
      bool emailExists = await userService.isEmailTaken(
          emailCont.text.trim(), getStringAsync(userId));
      formKey.currentState!.save();
      if (phoneNumberExist == true) {
        toast('lblExistPhoneMsg'.translate);
        appStore.setLoading(false);
        return;
      }
      if (emailExists) {
        toast('lblExistEmailMsg'.translate);
        appStore.setLoading(false);
        return;
      }
      appStore.setLoading(true);
      if (await userService.isUserExist(emailCont.text)) {
        toast("already_registered".translate);
        appStore.setLoading(false);
      } else {
        UserModel userModel = UserModel();
        userModel.uid = widget.user!.uid.validate();
        userModel.email = emailCont.text.validate();
        userModel.name = nameCont.text.validate();
        userModel.phoneNumber = widget.user!.phoneNumber.validate();
        userModel.countryCode = (!widget.countryCode.isEmptyOrNull)
            ? widget.countryCode
            : countryCode;
        userModel.photoUrl = widget.user!.photoURL.validate();
        userModel.createdAt = Timestamp.now();
        userModel.updatedAt = Timestamp.now();
        userModel.isEmailLogin = true;
        userModel.isPresence = true;
        userModel.isActive = true;
        userModel.userStatus = "Hey there, I am using ${AppName}";
        userModel.lastSeen = DateTime.now().millisecondsSinceEpoch;
        userModel.caseSearch = setSearchParam(nameCont.text);
        userModel.oneSignalPlayerId = (!getStringAsync(playerId).isEmptyOrNull)
            ? getStringAsync(playerId)
            : OneSignal.User.pushSubscription.id.validate();
        await userService
            .addDocumentWithCustomId(widget.user?.uid ?? '', userModel.toJson())
            .then((value) async {
          UserModel user = await value.get().then((value) =>
              UserModel.fromJson(value.data() as Map<String, dynamic>));
          appStore.setLoading(false);
          await authService.updateUserData(user);
          await authService.setUserDetailPreference(user);
          await setValue(
              playerId, OneSignal.User.pushSubscription.id.validate());
          DashboardScreen().launch(context, isNewTask: true);
        }).catchError((e) {
          appStore.setLoading(false);
          throw e;
        }).whenComplete(() => appStore.setLoading(false));
      }
    } else {
      appStore.setLoading(false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(''),
        forceMaterialTransparency: true,
        elevation: 0,
        iconTheme: IconThemeData(color: context.iconColor),
        automaticallyImplyLeading: true,
      ),
      body: Stack(
        children: [
          body(),
          Observer(builder: (context) => Loader().visible(appStore.isLoading)),
        ],
      ),
      bottomNavigationBar: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          GestureDetector(
            onTap: () {
              hideKeyboard(context);
              finish(context);
            },
            child: RichText(
              text: TextSpan(
                children: [
                  TextSpan(
                      text: "already_account".translate,
                      style: TS.secondaryTextStyle()),
                  TextSpan(
                      text: "sign_in".translate,
                      style: TS.boldTextStyle(color: primaryColor)),
                ],
              ),
            ),
          ),
          16.height,
        ],
      ),
    );
  }

  Widget body() {
    return SingleChildScrollView(
      padding: EdgeInsets.all(16),
      child: Form(
        key: formKey,
        autovalidateMode: AutovalidateMode.onUserInteraction,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('create_account'.translate, style: TS.boldTextStyle()),
            8.height,
            Text('conect_with_friends'.translate,
                style: TS.secondaryTextStyle()),
            50.height,
            Text("name".translate, style: TS.primaryTextStyle()),
            8.height,
            AppTextField(
              focus: nameFocus,
              controller: nameCont,
              nextFocus: emailFocus,
              textFieldType: TextFieldType.NAME,
              textInputAction: TextInputAction.go,
              decoration: inputDecoration(context, labelText: ''),
            ),
            16.height,
            Text('email_address'.translate, style: TS.primaryTextStyle()),
            8.height,
            AppTextField(
              focus: emailFocus,
              controller: emailCont,
              nextFocus: mobileNumberFocus,
              textFieldType: TextFieldType.EMAIL,
              textInputAction: TextInputAction.go,
              decoration: inputDecoration(context, labelText: ''),
            ),
            16.height.visible(!widget.isOTP!),
            Text("mobile_number".translate, style: TS.primaryTextStyle())
                .visible(!widget.isOTP!),
            8.height.visible(!widget.isOTP!),
            AppTextField(
              focus: mobileNumberFocus,
              controller: mobileNumberCont,
              nextFocus: passFocus,
              textFieldType: TextFieldType.PHONE,
              textInputAction: TextInputAction.go,
              decoration: inputDecoration(
                context,
                labelText: '',
                prefix: CountryCodePicker(
                  padding: EdgeInsets.zero,
                  initialSelection: defaultCountry,
                  showCountryOnly: false,
                  showFlag: true,
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
                ).fit(fit: BoxFit.cover),
              ),
            ).visible(!(widget.isOTP ?? false)),
            16.height.visible(!(widget.isOTP ?? false)),
            Text("password".translate, style: TS.primaryTextStyle())
                .visible(!(widget.isOTP ?? false)),
            8.height.visible(!(widget.isOTP ?? false)),
            AppTextField(
              focus: passFocus,
              controller: passCont,
              nextFocus: confirmPasswordFocus,
              textFieldType: TextFieldType.PASSWORD,
              textInputAction: TextInputAction.go,
              decoration: inputDecoration(context, labelText: ''),
            ).visible(!(widget.isOTP ?? false)),
            16.height.visible(!(widget.isOTP ?? false)),
            Text('confirm_password'.translate, style: TS.primaryTextStyle())
                .visible(!(widget.isOTP ?? false)),
            8.height.visible(!(widget.isOTP ?? false)),
            AppTextField(
              controller: confirmPassCont,
              textFieldType: TextFieldType.PASSWORD,
              textInputAction: TextInputAction.go,
              focus: confirmPasswordFocus,
              decoration: inputDecoration(context, labelText: ''),
              validator: (value) {
                if (value!.trim().isEmpty) return errorThisFieldRequired;
                if (value.trim().length < passwordLengthGlobal)
                  return 'password_length_should_be_more_than_six'.translate;
                return passCont.text == value.trim()
                    ? null
                    : 'password_does_not_match'.translate;
              },
              autoFillHints: [AutofillHints.newPassword],
            ).visible(!widget.isOTP!),
            16.height,
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                4.width,
                SizedBox(
                  height: 16,
                  width: 16,
                  child: Checkbox(
                    side: BorderSide(color: primaryColor),
                    activeColor: primaryColor,
                    value: isTcChecked,
                    onChanged: (c) {
                      isTcChecked = c!;
                      setState(() {});
                    },
                  ),
                ),
                12.width,
                RichTextWidget(
                  textAlign: TextAlign.start,
                  list: [
                    TextSpan(
                        text: 'i_agree_to'.translate,
                        style: TS.primaryTextStyle()),
                    TextSpan(
                      text: 'terms_and_conditions'.translate,
                      style: TS.boldTextStyle(color: primaryColor),
                      recognizer: TapGestureRecognizer()
                        ..onTap = () {
                          appLaunchUrl(appSettingStore.termsCond.validate());
                        },
                    ),
                    TextSpan(text: " and ", style: TS.boldTextStyle()),
                    TextSpan(
                      text: "privacy_policy".translate,
                      style: TS.boldTextStyle(color: primaryColor),
                      recognizer: TapGestureRecognizer()
                        ..onTap = () {
                          appLaunchUrl(
                              appSettingStore.privacyPolicy.validate());
                        },
                    ),
                  ],
                ).expand(),
              ],
            ),
            40.height,
            AppButton(
              width: context.width(),
              color: primaryColor,
              text: "sign_up".translate,
              hoverColor: Colors.white,
              onTap: () {
                hideKeyboard(context);
                widget.isOTP! ? signUpWithOtp() : signUpWithEmail();
              },
            ),
            16.height,
          ],
        ),
      ),
    );
  }
}
