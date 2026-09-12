import 'package:chat/models/StoryModel.dart';
import 'package:chat/models/UserModel.dart';

class ChatMessageModel {
  String? id;
  String? id2;
  String? senderId;
  String? receiverId;
  String? photoUrl;
  String? messageType;
  bool? isMe;
  bool? isMessageRead;

  bool? isDeleted=false;
  String? message;
  String? stickerPath;
  int? status;
  int? createdAt;
  String? currentLat;
  String? currentLong;
  bool? isEncrypt;
  bool? isFromForward;
  bool? isFromReply;
  String? replyMessageId;
  String? replyMessage;
  String? replyMessageType;
  String? documentName;
  String? addRemoveStatus;
  String? replyMessageSenderName;
  bool? replyLocation;
  bool? delete_for_sender;
  UserModel? shareUser;
  String? groupId;
  String? groupName;
  String? groupProfile;
  StoryModel? storyModel;
  List<String>? deletedFor;
  // bool? isHighlighted;

  Map<String, dynamic>? readBy = {};
  List<ReactionModel>? groupReaction;

  ChatMessageModel({
    this.id,
    this.senderId,
    this.id2,
    this.delete_for_sender,
    this.deletedFor,
    this.groupReaction,
    this.receiverId,
    this.createdAt,
    this.message,
    this.isMessageRead,
    this.isDeleted=false,
    this.photoUrl,
    this.status,
    this.messageType,
    this.stickerPath,
    this.currentLat,
    this.documentName,
    this.addRemoveStatus,
    this.currentLong,
    this.isEncrypt,
    this.readBy,
    this.isFromForward,
    this.isFromReply,
    this.replyMessageId,
    this.replyMessage,
    this.replyMessageType,
    this.replyMessageSenderName,
    this.replyLocation,
    this.shareUser,
    this.groupId,
    this.groupName,
    this.groupProfile,
    this.storyModel,
    // this.isHighlighted
  });

  factory ChatMessageModel.fromJson(Map<String, dynamic> json) {
    return ChatMessageModel(
      id: json['id'],
      id2: json['id2'],
      documentName: json['documentName'],
      addRemoveStatus: json['addRemoveStatus'],
      delete_for_sender: json['delete_for_sender'],
      senderId: json['senderId'],
      receiverId: json['receiverId'],
      message: json['message'],
      isMessageRead: json['isMessageRead'],
      storyModel: json['storyModel'] != null
          ? StoryModel.fromJson(json['storyModel'])
          : null,
       isDeleted: json['isDeleted']??false,
       deletedFor: json['deletedFor'] != null ? List<String>.from(json['deletedFor']) : [],
      groupReaction: json['groupReaction'] != null
          ? (json['groupReaction'] as List)
          .map((e) => ReactionModel.fromJson(e as Map<String, dynamic>))
          .toList()
          : [],
      photoUrl: json['photoUrl'],
      messageType: json['messageType'],
      stickerPath: json['stickerPath'],
      status: json['status'],
      createdAt: json['createdAt'],
      currentLat: json['currentLat'],
      currentLong: json['currentLong'],
      isEncrypt: json['isEncrypt'],
      readBy: json['readBy'],
      isFromForward: json['isFromForward'],
      isFromReply: json['isFromReply'],
      replyMessageId: json['replyMessageId'],
      replyMessage: json['replyMessage'],
      replyMessageType: json['replyMessageType'],
      replyMessageSenderName: json['replyMessageSenderName'],
      replyLocation: json['replyLocation'],
      groupId: json['groupId'],
      groupName: json['groupName'],
      groupProfile: json['groupProfile'],
      shareUser: json['shareUser'] != null ? UserModel.fromJson(json['shareUser']) : null,
    );
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = new Map<String, dynamic>();
    data['id'] = this.id;
    data['id2'] = this.id2;
    data['documentName'] = this.documentName;
    data['addRemoveStatus'] = this.addRemoveStatus;
    data['delete_for_sender'] = this.delete_for_sender;
    data['createdAt'] = this.createdAt;
    data['message'] = this.message;
    data['senderId'] = this.senderId;
    data['isMessageRead'] = this.isMessageRead;
     data['isDeleted'] = this.isDeleted??false;
    data['receiverId'] = this.receiverId;
    data['photoUrl'] = this.photoUrl;
    data['stickerPath'] = this.stickerPath;
    data['status'] = this.status;
    data['messageType'] = this.messageType;
    data['currentLat'] = this.currentLat;
    data['currentLong'] = this.currentLong;
    data['isEncrypt'] = this.isEncrypt;
    data['readBy'] = this.readBy;
    if (storyModel != null) {
      data['storyModel'] = storyModel?.toJson();
    }
    data['isFromForward'] = this.isFromForward;
    data['isFromReply'] = this.isFromReply;
    data['replyMessageId'] = this.replyMessageId;
    data['replyMessage'] = this.replyMessage;
    data['replyMessageType'] = this.replyMessageType;
    data['replyMessageSenderName'] = this.replyMessageSenderName;
    data['replyLocation'] = this.replyLocation;
    data['shareUser'] = this.shareUser?.toJson();
    data['groupId'] = this.groupId;
    data['groupName'] = this.groupName;
    data['groupProfile'] = this.groupProfile;
     data['deletedFor'] = this.deletedFor;
    data['groupReaction'] = this.groupReaction?.map((e) => e.toJson()).toList();

    // data['isHighlighted'] = this.isHighlighted;
    return data;
  }
}


class ReactionModel {
  String? uid;
  String? userName;
  String? reaction;
  String? image;
  int? createdAt;

  ReactionModel({
    this.uid,
    this.userName,
    this.reaction,
    this.image,
    this.createdAt,
  });

  factory ReactionModel.fromJson(Map<String, dynamic> json) {
    return ReactionModel(
      uid: json['uid'],
      userName: json['userName'],
      reaction: json['reaction'],
      image: json['image'],
      createdAt: json['createdAt'],
    );
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = new Map<String, dynamic>();
    data['uid'] = this.uid;
    data['userName'] = this.userName;
    data['reaction'] = this.reaction;
    data['image'] = this.image;
    data['createdAt'] = this.createdAt;
    return data;
  }
}
