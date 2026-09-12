import 'package:cloud_firestore/cloud_firestore.dart';
import '../utils/AppConstants.dart';

class LastMessageModel {
  final String chatId;
  final String senderId;
  final String receiverId;
  final String lastMessage;
  final String groupName;
  final String groupId;
  final List<String> participants;

  final bool isSeenBySender;
  final bool isSeenByReceiver;
  final bool isRequest;

  final Map<String, bool> isArchive;
  final bool isGroupMessage;

  final int unreadCountReceiver;
  final int unreadCountSender;
  final Map<String, dynamic>? unreadCounts;

  final MessageType messageType;
  final Timestamp timestamp;

  final String chatType; // NEW FIELD = "private" | "group" | "admin"

  LastMessageModel({
    required this.chatId,
    required this.senderId,
    required this.receiverId,
    required this.lastMessage,
    required this.groupName,
    required this.groupId,
    required this.participants,
    required this.isSeenBySender,
    required this.isSeenByReceiver,
    required this.isRequest,
    required this.isArchive,
    required this.isGroupMessage,
    required this.unreadCountReceiver,
    required this.unreadCountSender,
    required this.messageType,
    required this.timestamp,
    required this.chatType, // NEW REQUIRED FIELD
    this.unreadCounts,
  });

  factory LastMessageModel.fromDoc(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;

    // 🟩 AUTO-DETECT chatType IF missing
    String detectedChatType;

    if (data.containsKey('chatType')) {
      detectedChatType = data['chatType'] ?? 'private';
    } else {
      // OLD DATA fallback logic
      if (data['isGroupMessage'] == true) {
        detectedChatType = "group";
      } else if (data['chatId'] == "admin_global_chat" ||
          data['receiverId'] == "" ||
          data['senderId'] == "admin") {
        detectedChatType = "admin";
      } else {
        detectedChatType = "private";
      }
    }

    return LastMessageModel(
      chatId: data['chatId'] ?? '',
      senderId: data['senderId'] ?? '',
      receiverId: data['receiverId'] ?? '',
      lastMessage: data['lastMessage'] ?? '',
      groupName: data['groupName'] ?? '',
      groupId: data['groupId'] ?? '',
      participants: List<String>.from(data['participants'] ?? []),
      isSeenBySender: data['isSeenBySender'] ?? false,
      isSeenByReceiver: data['isSeenByReceiver'] ?? false,
      isRequest: data['isRequest'] ?? false,
      isArchive: Map<String, bool>.from(data['isArchive'] ?? {}),
      isGroupMessage: data['isGroupMessage'] ?? false,
      unreadCountReceiver: data['unreadCountReceiver'] ?? 0,
      unreadCountSender: data['unreadCountSender'] ?? 0,
      unreadCounts: data['unreadCounts'] != null
          ? Map<String, dynamic>.from(data['unreadCounts'])
          : null,
      messageType: _parseMessageType(data['messageType']),
      timestamp: data['timestamp'] ?? Timestamp.now(),
      chatType: detectedChatType, // SAFE
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'chatId': chatId,
      'senderId': senderId,
      'receiverId': receiverId,
      'lastMessage': lastMessage,
      'participants': participants,
      'isSeenBySender': isSeenBySender,
      'isSeenByReceiver': isSeenByReceiver,
      'isRequest': isRequest,
      'isArchive': isArchive,
      'isGroupMessage': isGroupMessage,
      'groupName': groupName,
      'groupId': groupId,
      'unreadCountSender': unreadCountSender,
      'unreadCountReceiver': unreadCountReceiver,
      'unreadCounts': unreadCounts,
      'messageType': messageType.name,
      'timestamp': timestamp,
      'chatType': chatType, // NEW FIELD STORED
    };
  }

  static MessageType _parseMessageType(String? raw) {
    if (raw == null) return MessageType.TEXT;
    return MessageType.values.firstWhere(
          (e) => e.name == raw,
      orElse: () => MessageType.TEXT,
    );
  }
}
