class GroupCallLogModel {
  final String callerId;
  final String callerName;
  final String callerPic;
  final String callStatus;
  final List<ParticipantLog> participants;
  final String callType;
  final String timestamp;

  GroupCallLogModel({
    required this.callerId,
    required this.callerName,
    required this.callerPic,
    required this.callStatus,
    required this.participants,
    required this.callType,
    required this.timestamp,
  });

  Map<String, dynamic> toJson() {
    return {
      'callerId': callerId,
      'callerName': callerName,
      'callerPic': callerPic,
      'callStatus': callStatus,
      'participants': participants.map((p) => p.toJson()).toList(),
      'callType': callType,
      'timestamp': timestamp,
    };
  }

  factory GroupCallLogModel.fromJson(Map<String, dynamic> json) {
    List<dynamic> participantsJson = json['participants'] ?? [];
    List<ParticipantLog> participantsList = participantsJson
        .map((p) => ParticipantLog.fromJson(p as Map<String, dynamic>))
        .toList();

    return GroupCallLogModel(
      callerId: json['callerId'] ?? '',
      callerName: json['callerName'] ?? '',
      callerPic: json['callerPic'] ?? '',
      callStatus: json['callStatus'] ?? '',
      participants: participantsList,
      callType: json['callType'] ?? '',
      timestamp: json['timestamp'] ?? '',
    );
  }
}

// Participant log for group calls
class ParticipantLog {
  final String userId;
  final String userName;
  final String userPic;
  final String joinStatus; // JOINED, DECLINED, MISSED

  ParticipantLog({
    required this.userId,
    required this.userName,
    required this.userPic,
    required this.joinStatus,
  });

  Map<String, dynamic> toJson() {
    return {
      'userId': userId,
      'userName': userName,
      'userPic': userPic,
      'joinStatus': joinStatus,
    };
  }

  factory ParticipantLog.fromJson(Map<String, dynamic> json) {
    return ParticipantLog(
      userId: json['userId'] ?? '',
      userName: json['userName'] ?? '',
      userPic: json['userPic'] ?? '',
      joinStatus: json['joinStatus'] ?? '',
    );
  }
}
