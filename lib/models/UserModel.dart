import 'package:cloud_firestore/cloud_firestore.dart';

class UserModel {
  String? uid;
  String? name;
  String? email;
  String? photoUrl;
  String? userStatus;
  String? deviceId;
  bool? isPresence;
  List<String>? caseSearch;
  String? phoneNumber;
  String? countryCode;
  Timestamp? createdAt;
  Timestamp? updatedAt;
  int? lastSeen;
  bool? isEmailLogin;
  bool? typingStatus;
  String? oneSignalPlayerId;
  String? userRole;
  bool? isActive;
  int? reportUserCount;
  int? lastMessageTime;
  List<DocumentReference>? blockedTo;
  List<DocumentReference>? reportedBy;
  bool? isArchive;

  UserModel({
    this.uid,
    this.name,
    this.email,
    this.photoUrl,
    this.userStatus,
    this.phoneNumber,
    this.countryCode,
    this.createdAt,
    this.updatedAt,
    this.isEmailLogin,
    this.typingStatus,
    this.caseSearch,
    this.isPresence,
    this.lastSeen,
    this.oneSignalPlayerId,
    this.blockedTo,
    this.reportedBy,
    this.isActive,
    this.reportUserCount,
    this.deviceId,
    this.isArchive,
    this.lastMessageTime,
    this.userRole,
  });

  factory UserModel.fromJson(Map<String, dynamic> json) {
    return UserModel(
      uid: json['uid'],
      name: json['name'],
      email: json['email'],
      userStatus: json['userStatus'],
      phoneNumber: json['phoneNumber'],
      countryCode: json['countryCode'],
      photoUrl: json['photoUrl'],
      isEmailLogin: json['isEmailLogin'],
      typingStatus: json['typingStatus'],
      createdAt: json['createdAt'],
      updatedAt: json['updatedAt'],
      isPresence: json['isPresence'],
      isActive: json['isActive'],
      reportUserCount: json['reportUserCount'],
      lastSeen: json['lastSeen'],
      userRole: json['userRole'],
      oneSignalPlayerId: json['oneSignalPlayerId'],
      deviceId: json['deviceId'],
      lastMessageTime: json['lastMessageTime'],
      caseSearch: json['caseSearch'] != null ? List<String>.from(json['caseSearch']) : [],
      blockedTo: json['blockedTo'] != null ? List<DocumentReference>.from(json['blockedTo']) : [],
      reportedBy: json['reportedBy'] != null ? List<DocumentReference>.from(json['reportedBy']) : [],
      isArchive: json['isArchive'],

      // != null ? json['isArchive']: false,
    );
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = new Map<String, dynamic>();
    data['uid'] = this.uid;
    data['name'] = this.name;
    data['email'] = this.email;
    data['userStatus'] = this.userStatus;
    data['phoneNumber'] = this.phoneNumber;
    data['countryCode'] = this.countryCode;
    data['photoUrl'] = this.photoUrl;
    data['createdAt'] = this.createdAt;
    data['updatedAt'] = this.updatedAt;
    data['isEmailLogin'] = this.isEmailLogin;
    data['typingStatus'] = this.typingStatus;
    data['isActive'] = this.isActive;
    data['caseSearch'] = this.caseSearch;
    data['blockedTo'] = this.blockedTo;
    data['reportedBy'] = this.reportedBy;
    data['isPresence'] = this.isPresence;
    data['reportUserCount'] = this.reportUserCount;
    data['lastSeen'] = this.lastSeen;
    data['oneSignalPlayerId'] = this.oneSignalPlayerId;
    data['deviceId'] = this.deviceId;
    data['isArchive'] = this.isArchive;
    data['userRole'] = this.userRole;
    data['lastMessageTime'] = this.lastMessageTime;

    return data;
  }
}

class MemberModel {
  String? uid;
  String? role;
}
