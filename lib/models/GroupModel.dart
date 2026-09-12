import 'package:cloud_firestore/cloud_firestore.dart';

class GroupModel {
  String? createdBy;
  DateTime? createdOn;
  String? descriptionId;
  String? adminId;
  String? fltrdId;
  String isTypingID;
  int? latestTimeStamp;
  List<String>? membersList;
  String? name;
  String? photoUrl;
  String? groupType;
  bool isEncrypt;
  List<String>? caseSearch;
  List<String>? adminIds;

  GroupModel({
    this.createdBy,
    this.createdOn,
    this.descriptionId,
    this.adminId,
    this.fltrdId,
    this.isTypingID = '',
    this.latestTimeStamp,
    this.membersList,
    this.name,
    this.photoUrl = '',
    this.groupType,
    this.isEncrypt = false,
    this.caseSearch,
    this.adminIds,
  });

  factory GroupModel.fromJson(Map<String, dynamic> json) {
    return GroupModel(
      createdBy: json['createdBy'],
      createdOn: json['createdOn'] is Timestamp
          ? (json['createdOn'] as Timestamp).toDate()
          : json['createdOn'],
      descriptionId: json['descriptionId'],
      fltrdId: json['fltrdId'],
      adminId: json['adminId'],
      isTypingID: json['isTypingID'] ?? '',
      latestTimeStamp: json['latestTimeStamp'],
      membersList:
          (json['membersList'] as List?)?.map((e) => e.toString()).toList() ??
              [],
      name: json['name'],
      photoUrl: json['photoUrl'] ?? '',
      groupType: json['groupType'],
      isEncrypt: json['isEncrypt'] ?? false,
      caseSearch:
          (json['searchCase'] as List?)?.map((e) => e.toString()).toList() ??
              [],
      adminIds:
          (json['adminIds'] as List?)?.map((e) => e.toString()).toList() ?? [],
    );
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = new Map<String, dynamic>();
    data['createdBy'] = this.createdBy;
    data['createdOn'] = this.createdOn;
    data['descriptionId'] = this.descriptionId;
    data['fltrdId'] = this.fltrdId;
    data['adminId'] = this.adminId;
    data['isTypingID'] = this.isTypingID;
    data['latestTimeStamp'] = this.latestTimeStamp;
    data['membersList'] = this.membersList;
    data['name'] = this.name;
    data['photoUrl'] = this.photoUrl;
    data['groupType'] = this.groupType;
    data['isEncrypt'] = this.isEncrypt;
    data['searchCase'] = this.caseSearch;
    data['adminIds'] = this.adminIds;
    return data;
  }
}
