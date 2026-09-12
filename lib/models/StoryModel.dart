import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class RecentStoryModel {
  List<StoryModel>? list;
  String? userName;
  String? userId;
  String? userImgPath;
  Timestamp? createAt;
  Timestamp? updatedAt;
  List<SeenUser>? seenUserList;
  List<String>? excludedUserList;
  List<String>? includedUserList;
  String? caption;
  String? statusPrivacyIndex;
  String? visibilityType;
  List<String>? selectedCountries;

  RecentStoryModel(
      {this.list,
      this.userId,
      this.userName,
      this.userImgPath,
      this.caption,
      this.createAt,
      this.updatedAt,
      this.seenUserList,
      this.excludedUserList,
      this.includedUserList,
      this.statusPrivacyIndex,
      this.visibilityType,
      this.selectedCountries});
}

class StoryModel {
  String? userId;
  String? userName;
  String? userImgPath;
  String? id;
  String? caption;
  String? extraCaption;
  Timestamp? createAt;
  Timestamp? updatedAt;
  List<SeenUser>? seenUserList;
  List<String>? excludedUserList;
  List<String>? includedUserList;
  String? imagePath;
  String? videoDuration;
  String? extension;
  String? filePath;
  bool? shown;
  int? backgroundColor;
  int? statusPrivacyIndex;
  String? type;
  String? oneSignalKey;

  StoryModel({
    this.userId,
    this.userName,
    this.userImgPath,
    this.id,
    this.caption,
    this.extraCaption,
    this.createAt,
    this.updatedAt,
    this.seenUserList,
    this.imagePath,
    this.videoDuration,
    this.extension,
    this.backgroundColor,
    this.shown,
    this.filePath,
    this.includedUserList,
    this.excludedUserList,
    this.statusPrivacyIndex,
    this.type,
    this.oneSignalKey,
  });

  StoryModel.fromJson(dynamic json) {
    userId = json['userId'];
    userName = json['userName'];
    userImgPath = json['userImgPath'];
    id = json['id'];
    caption = json['caption'];
    extraCaption = json['extraCaption'];
    createAt = json['createAt'];
    updatedAt = json['updatedAt'];
    filePath = json['filePath'];
    if (json['seenUserList'] != null) {
      seenUserList = (json['seenUserList'] as List)
          .map((e) => SeenUser.fromJson(e))
          .toList();
    }
    excludedUserList = json['excludedUserList'] != null
        ? json['excludedUserList'].cast<String>()
        : [];
    includedUserList = json['includedUserList'] != null
        ? json['includedUserList'].cast<String>()
        : [];
    imagePath = json['imagePath'];
    videoDuration = json['videoDuration'];
    extension = json['extension'];
    backgroundColor = json['backgroundColor'];
    shown = json['shown'] ?? false;
    statusPrivacyIndex = json['statusPrivacyIndex'];
    type = json['type'];
    oneSignalKey = json['oneSignalKey'];
  }

  Map<String, dynamic> toJson() {
    final map = <String, dynamic>{};
    map['userId'] = userId;
    map['userImgPath'] = userImgPath;
    map['userName'] = userName;
    map['id'] = id;
    map['caption'] = caption;
    map['extraCaption'] = extraCaption;
    map['createAt'] = createAt;
    map['updatedAt'] = updatedAt;
    map['filePath'] = filePath;
    if (seenUserList != null) {
      map['seenUserList'] = seenUserList!.map((e) => e.toJson()).toList();
    }
    map['excludedUserList'] = excludedUserList;
    map['includedUserList'] = includedUserList;
    map['imagePath'] = imagePath;
    map['videoDuration'] = videoDuration;
    map['extension'] = extension;
    map['backgroundColor'] = backgroundColor;
    map['shown'] = shown;
    map['statusPrivacyIndex'] = statusPrivacyIndex;
    map['type'] = type;
    map['oneSignalKey'] = oneSignalKey;
    return map;
  }
}

class SeenUser {
  String? userId;
  String? userName;
  String? userImgPath;

  SeenUser({this.userId, this.userName, this.userImgPath});

  SeenUser.fromJson(dynamic json) {
    userId = json['userId'];
    userName = json['userName'];
    userImgPath = json['imagePath'];
  }

  Map<String, dynamic> toJson() {
    final map = <String, dynamic>{};
    map['userId'] = userId;
    map['userName'] = userName;
    map['imagePath'] = userImgPath;
    return map;
  }
}
