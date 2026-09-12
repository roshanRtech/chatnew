import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_mobx/flutter_mobx.dart';
import 'package:nb_utils/nb_utils.dart';
import 'package:onesignal_flutter/onesignal_flutter.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';
import 'package:chat/centralized_import.dart';

import '../../utils/TextStyles.dart' as TS;

class SignInScreen extends StatefulWidget {
  @override
  _SignInScreenState createState() => _SignInScreenState();
}

class _SignInScreenState extends State<SignInScreen> {
  GlobalKey<FormState> formKey = GlobalKey<FormState>();

  AuthService authService = AuthService();
  TextEditingController emailCont = TextEditingController();
  TextEditingController passCont = TextEditingController();

  FocusNode emailFocus = FocusNode();
  FocusNode passFocus = FocusNode();

  @override
  void initState() {
    super.initState();
    SystemChrome.setSystemUIOverlayStyle(SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
      statusBarBrightness: Brightness.light,
    ));
    init();
  }

  init() async {
    if (isIOS) {
      /*TheAppleSignIn.onCredentialRevoked!.listen((_) {
        log("Credentials revoked");
      });*/
      try {
        final userId = getStringAsync('appleUserId');
        if (userId.isNotEmpty) {
          final credentialState =
              await SignInWithApple.getCredentialState(userId);

          if (credentialState == CredentialState.revoked) {
            log("Apple credentials revoked");
          }
        }
      } catch (e) {
        log("Error checking Apple credential state: $e");
      }
    }
    if (getBoolAsync(isRemember)) {
      log(emailCont.text.toString());
      emailCont.text = getStringAsync(userEmail);
      passCont.text = getStringAsync(userPassword);
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

  void loginWithEmail() {
    if (formKey.currentState!.validate()) {
      formKey.currentState!.save();
      appStore.setLoading(true);
      authService
          .signInWithEmailPassword(
              email: emailCont.text, password: passCont.text)
          .then((value) async {
        appStore.setLoading(false);
        appSetting();
        setValue(userPassword, passCont.text);
        await setValue(playerId, OneSignal.User.pushSubscription.id.validate());
        DashboardScreen().launch(context, isNewTask: true);
      }).catchError((e) {
        toast(e.toString());
      }).whenComplete(
        () {
          appStore.setLoading(false);
        },
      );
    } else {
      appStore.setLoading(false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          SingleChildScrollView(
            child: Form(
              key: formKey,
              autovalidateMode: AutovalidateMode.onUserInteraction,
              child: Column(
                mainAxisSize: MainAxisSize.max,
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  SizedBox(height: context.height() * 0.12),
                  Text("login".translate, style: TS.boldTextStyle()),
                  8.height,
                  Text("welcome_back".translate + ' 👋',
                      style: TS.boldTextStyle()),
                  4.height,
                  Text("hello_again".translate, style: TS.secondaryTextStyle()),
                  30.height,
                  SizedBox(height: context.height() * 0.03),
                  Text('email_address'.translate, style: TS.primaryTextStyle()),
                  8.height,
                  AppTextField(
                    controller: emailCont,
                    textInputAction: TextInputAction.go,
                    nextFocus: passFocus,
                    focus: emailFocus,
                    textFieldType: TextFieldType.EMAIL,
                    decoration: inputDecoration(context,
                        labelText: '', hintText: 'enter_your_email'.translate),
                  ),
                  16.height,
                  Text('password'.translate, style: TS.primaryTextStyle()),
                  8.height,
                  AppTextField(
                    controller: passCont,
                    focus: passFocus,
                    textInputAction: TextInputAction.go,
                    textFieldType: TextFieldType.PASSWORD,
                    decoration: inputDecoration(context,
                        labelText: '',
                        hintText: 'enter_your_password'.translate),
                  ),
                  8.height,
                  Row(
                    children: [
                      Theme(
                        data: appStore.isDarkMode
                            ? ThemeData.dark().copyWith(
                                colorScheme: ColorScheme.fromSwatch()
                                    .copyWith(secondary: primaryColor)
                                    .copyWith(
                                      background:
                                          context.scaffoldBackgroundColor,
                                    ),
                              )
                            : ThemeData.light(),
                        child: SizedBox(
                          height: 20,
                          width: 25,
                          child: Checkbox(
                            focusColor: primaryColor,
                            side: BorderSide(color: primaryColor),
                            activeColor: primaryColor,
                            value: getBoolAsync(isRemember),
                            onChanged: (bool? value) async {
                              await setValue(isRemember, value);
                              setState(() {});
                            },
                          ),
                        ),
                      ),
                      4.width,
                      Text("remember_me".translate,
                              style: TS.primaryTextStyle())
                          .expand(),
                      Text('forgot_password'.translate,
                              style: TS.primaryTextStyle(),
                              textAlign: TextAlign.end)
                          .paddingSymmetric(vertical: 8, horizontal: 4)
                          .onTap(() {
                        return showInDialog(
                          context,
                          builder: (_) {
                            return ForgotPasswordScreen();
                          },
                          backgroundColor: context.cardColor,
                          dialogAnimation: DialogAnimation.SCALE,
                          contentPadding: EdgeInsets.zero,
                        );
                      }),
                    ],
                  ),
                  40.height,
                  AppButton(
                    text: 'sign_in'.translate,
                    textStyle: TS.boldTextStyle(color: CupertinoColors.white),
                    color: primaryColor,
                    width: context.width(),
                    onTap: () {
                      loginWithEmail();
                      hideKeyboard(context);
                    },
                  ),
                  22.height,
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    mainAxisSize: MainAxisSize.min,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Divider(
                        color: context.dividerColor,
                      ).expand(),
                      Text(
                          " " +
                              'or'.translate +
                              " " +
                              'login_with'.translate +
                              " ",
                          style: TS.secondaryTextStyle(),
                          textAlign: TextAlign.center),
                      Divider(
                        color: context.dividerColor,
                      ).expand(),
                    ],
                  ),
                  22.height,
                  SocialLoginWidget(
                    voidCallback: () async {
                      appSetting();
                      if (getStringAsync(userMobileNumber).isEmpty ||
                          getStringAsync(userMobileNumber).isEmpty) {
                        SaveProfileScreen(
                                mIsShowBack: false, mIsFromLogin: true)
                            .launch(context, isNewTask: true);
                      } else {
                        await setValue(playerId,
                            OneSignal.User.pushSubscription.id.validate());
                        DashboardScreen().launch(context, isNewTask: true);
                      }
                    },
                  ),
                  16.height,
                ],
              ).paddingSymmetric(horizontal: 16, vertical: 8),
            ),
          ),
          Observer(
              builder: (_) => Loader().visible(appStore.isLoading).center()),
        ],
      ),
      bottomNavigationBar: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          RichText(
            text: TextSpan(
              children: [
                TextSpan(
                    text: "dont_have_an_account".translate + ' ',
                    style: TS.secondaryTextStyle()),
                TextSpan(
                    text: "sign_up".translate,
                    style: boldTextStyle(color: primaryColor)),
              ],
            ),
          ).onTap(() {
            SignUpScreen(isOTP: false).launch(context);
            hideKeyboard(context);
          },
              splashColor: Colors.transparent,
              hoverColor: Colors.transparent,
              highlightColor: Colors.transparent),
          16.height,
        ],
      ),
    );
  }
}
