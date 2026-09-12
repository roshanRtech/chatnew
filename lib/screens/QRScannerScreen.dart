import 'dart:io';

import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/material.dart';
import 'package:nb_utils/nb_utils.dart';
import 'package:qr_code_scanner_plus/qr_code_scanner_plus.dart';
import 'package:chat/centralized_import.dart';
import 'package:permission_handler/permission_handler.dart';

import '../../utils/TextStyles.dart' as TS;

class QRScannerScreen extends StatefulWidget {
  @override
  State<StatefulWidget> createState() => _QRScannerScreenState();
}

class _QRScannerScreenState extends State<QRScannerScreen> {
  bool isScanned = false;
  Barcode? result;
  QRViewController? controller;
  final GlobalKey qrKey = GlobalKey(debugLabel: 'QR');
  String? deviceId;

  bool hasShownPermissionDialog = false;

  @override
  void reassemble() {
    super.reassemble();
    if (Platform.isAndroid) controller?.pauseCamera();
    controller?.resumeCamera();
  }

  @override
  void initState() {
    super.initState();
    init();
  }

  init() async {
    if (Platform.isIOS) {
      var iosDeviceInfo = await DeviceInfoPlugin().iosInfo;
      deviceId = iosDeviceInfo.identifierForVendor;
    } else if (Platform.isAndroid) {
      var androidDeviceInfo = await DeviceInfoPlugin().androidInfo;
      deviceId = androidDeviceInfo.id;
    }
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    if (result != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        showDialog(
          context: context,
          builder: (context) {
            return Dialog(
              elevation: 0,
              backgroundColor: white,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  8.height,
                  Text(
                    "device_login_code_detected".translate,
                    style: TS.boldTextStyle(color: Colors.black),
                  ),
                  16.height,
                  Text(
                    "if_you_want_to_log_in_to_mighty_chat_on_another_device_tap_continue_youll_need_to_scan_the_qr_code_again_to_link_device"
                        .translate,
                    style: secondaryTextStyle(),
                  ),
                  2.height,
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton(
                        onPressed: () {
                          Navigator.pop(context);
                          Navigator.pop(context);
                        },
                        child: Text("cancel".translate,
                            style: TS.primaryTextStyle()),
                      ),
                      6.width,
                      TextButton(
                        onPressed: () {
                          DeviceModel deviceModel = DeviceModel();
                          deviceModel.deviceId = deviceId.validate();
                          deviceModel.uid = loginStore.mId;
                          deviceModel.webDeviceId = result!.code!;
                          deviceModel.isOnWeb = true;

                          deviceService
                              .addDeviceData(deviceModel,
                                  userId: loginStore.mId)
                              .then((value) {
                            print("success".translate);
                            Navigator.pop(context);
                            Navigator.pop(context);
                          }).catchError((e) {
                            toast(e.toString());
                          }).whenComplete(() {
                            appStore.setLoading(false);
                          });
                        },
                        child: Text("continue".translate,
                            style: TS.primaryTextStyle(color: primaryColor)),
                      ),
                    ],
                  )
                ],
              ).paddingAll(16),
            );
          },
        );
      });
    }

    return Scaffold(
      appBar: appBarWidget("scan_code".translate, textColor: Colors.white),
      body: _buildQrView(context),
    );
  }

  Widget _buildQrView(BuildContext context) {
    var scanArea = !context.isDesktop() ? context.width() / 1 : 400.0;

    return QRView(
      key: qrKey,
      onQRViewCreated: _onQRViewCreated,
      overlay: QrScannerOverlayShape(
        borderColor: Colors.red,
        borderRadius: 10,
        borderLength: 30,
        borderWidth: 10,
        cutOutSize: scanArea,
      ),
      onPermissionSet: (ctrl, p) => _onPermissionSet(context, ctrl, p),
    );
  }

  void _onQRViewCreated(QRViewController qrController) {
    controller = qrController;
    if (mounted) controller?.resumeCamera();

    setState(() {});

    controller?.scannedDataStream.listen((scanData) async {
      if (!isScanned) {
        result = scanData;

        if (scanData.code.validate().isNotEmpty) {
          controller?.dispose();

          appStore.setLoading(true);
          isScanned = true;
        }
      }
    });
  }

  void _onPermissionSet(
      BuildContext context, QRViewController ctrl, bool p) async {
    log('${DateTime.now().toIso8601String()}_onPermissionSet $p');

    if (!p && !hasShownPermissionDialog) {
      hasShownPermissionDialog = true;
      ctrl.pauseCamera();

      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (_) {
          return AlertDialog(
            title: const Text("Camera permission needed"),
            content: const Text(
              "Please enable camera permission in settings to scan the QR code.",
            ),
            actions: [
              TextButton(
                onPressed: () async {
                  Navigator.pop(context); // close dialog

                  await openAppSettings(); // open device settings

                  // Wait a bit to let user return
                  await Future.delayed(const Duration(milliseconds: 500));

                  var status = await Permission.camera.status;

                  if (status.isGranted) {
                    hasShownPermissionDialog = false;
                    ctrl.resumeCamera();
                    setState(() {});
                  } else {
                    Navigator.pop(context); // close scanner screen
                  }
                },
                child: const Text("Open Settings"),
              ),
              TextButton(
                onPressed: () {
                  Navigator.pop(context); // close dialog
                  Navigator.pop(context); // close scanner screen
                },
                child: const Text("Cancel"),
              ),
            ],
          );
        },
      );
    }
  }

  @override
  void dispose() {
    controller?.dispose();
    super.dispose();
  }
}
