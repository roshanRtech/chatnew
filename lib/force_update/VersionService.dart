import 'dart:io';
import 'package:chat/force_update/UpdateAvailable.dart';
import 'package:chat/utils/AppConstants.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';

class VersionService {
  FirebaseFirestore fireStore = FirebaseFirestore.instance;

  getVersionData(context) async {
    print("In version service");
    PackageInfo packageInfo = await PackageInfo.fromPlatform();
    String currentVersion = packageInfo.version;
    String currentBuildNumber = packageInfo.buildNumber;

    // Firebase Get Version Data
    return await fireStore
        .collection("app_version")
        .doc('might_chat')
        .get()
        .then((value) async {
      String updateDescription =
          value.data()?['newFeatures']?.toString() ?? AppName;
      if (Platform.isAndroid) {
        print("Value Data => ${value.data()}");

        String liveVersion =
            value.data()?['android_version_code']?.toString() ?? '';
        bool forceUpdate = value.data()?['android_force_update'] == true;
        String playstoreUrl = value.data()?['playstore_url']?.toString() ?? '';

        print("liveVersion => $liveVersion");
        print("currentVersion => $currentVersion");
        print("currentBuildNumber => $currentBuildNumber");

        if (isVersionGreater(liveVersion, currentVersion)) {
          // update is available
          if (forceUpdate) {
            // update force
            showDialog(
              context: context,
              builder: (context) => UpdateAvailable(
                  force: true,
                  storeUrl: playstoreUrl,
                  updateDescription: updateDescription),
              barrierDismissible: false,
            );
          } else {
            // optional update suggest only skip-able
            showDialog(
              context: context,
              builder: (context) => UpdateAvailable(
                  storeUrl: playstoreUrl, updateDescription: updateDescription),
            );
          }
        } else {
          // no update available
          print("No update available for Android");
        }
      } else if (Platform.isIOS) {
        String liveVersion = value.data()?['ios_version']?.toString() ?? '';
        bool forceUpdate = value.data()?['ios_force_update'] == true;
        String appstoreUrl = value.data()?['appstore_url']?.toString() ?? '';

        print("LIVE-VERSION: $liveVersion  LOCAL-VERSION: $currentVersion");

        if (isVersionGreater(liveVersion, currentVersion)) {
          print("IOS_UPDATE_DETECTED");
          // update is available
          if (forceUpdate) {
            // update force
            showDialog(
              context: context,
              builder: (context) => UpdateAvailable(
                  force: true,
                  storeUrl: appstoreUrl,
                  updateDescription: updateDescription),
              barrierDismissible: false,
            );
          } else {
            // optional update suggest only skip-able
            showDialog(
              context: context,
              builder: (context) => UpdateAvailable(
                  storeUrl: appstoreUrl, updateDescription: updateDescription),
            );
          }
        } else {
          print("IOS_NO_UPDATE");
          // no update available
        }
      }
    }).catchError((e) {
      print("error---->" + e.toString());
      throw e;
    });
  }

  bool isVersionGreater(String version1, String version2) {
    if (version1.isEmpty || version2.isEmpty) return false;

    // Split the version strings into parts
    List<String> versionParts1 = version1.split('.');
    List<String> versionParts2 = version2.split('.');

    // Determine the maximum length of the version parts
    int maxLength = versionParts1.length > versionParts2.length
        ? versionParts1.length
        : versionParts2.length;

    // Pad shorter version with zeros
    while (versionParts1.length < maxLength) {
      versionParts1.add('0');
    }
    while (versionParts2.length < maxLength) {
      versionParts2.add('0');
    }

    // Compare each part of the version
    for (int i = 0; i < maxLength; i++) {
      // Parse each part as an integer
      int part1 = int.tryParse(versionParts1[i]) ?? 0;
      int part2 = int.tryParse(versionParts2[i]) ?? 0;

      // Compare the parts
      if (part1 > part2) return true;
      if (part1 < part2) return false;
    }

    // If all parts are equal, the versions are the same
    return false;
  }
}
