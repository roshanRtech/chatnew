import 'package:cached_network_image/cached_network_image.dart';
import 'package:chat/centralized_import.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:nb_utils/nb_utils.dart';
import '../models/LastMessageModel.dart';
import '../../utils/TextStyles.dart' as TS;
import 'package:http/http.dart' as http;

class OptimizedChatListScreen extends StatefulWidget {
  const OptimizedChatListScreen({super.key});

  @override
  State<OptimizedChatListScreen> createState() =>
      _OptimizedChatListScreenState();
}

class _OptimizedChatListScreenState extends State<OptimizedChatListScreen> {
  final ChatMessageService chatService = ChatMessageService();
  String currentUserId = "";

  String searchText = "";
  bool isLoadingContacts = false;

  List<GroupModel> myUserGroups = [];

  final Map<String, String> _userNameCache = {};

  final GlobalKey<ScaffoldMessengerState> _rootScaffoldKey =
      GlobalKey<ScaffoldMessengerState>();

  Future<void> initCurrentUser() async {
    String uid = await getStringAsync(userId);
    if (uid.isNotEmpty) {
      currentUserId = uid;
      setState(() {});
    }
  }

  @override
  void initState() {
    super.initState();
    initCurrentUser();

    print("OptimizedChatListScreen initialized");
  }

  @override
  void dispose() {
    super.dispose();
    LiveStream().dispose(SEARCH_KEY);
  }

  @override
  Widget build(BuildContext context) {
    if (currentUserId.isEmpty) {
      return Scaffold(
        backgroundColor: context.scaffoldBackgroundColor,
        body: Center(child: Loader()),
        floatingActionButton: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            15.height,
            FloatingActionButton(
              child: Image.asset(ic_messages,
                  width: 25, height: 25, color: Colors.white),
              backgroundColor: primaryColor,
              onPressed: () {
                NewChatScreen().launch(context,
                    pageRouteAnimation: PageRouteAnimation.SlideBottomTop,
                    duration: 250.milliseconds);
              },
            ),
          ],
        ),
      );
    }
    return ScaffoldMessenger(
      key: _rootScaffoldKey,
      child: Scaffold(
        backgroundColor: context.scaffoldBackgroundColor,
        body: StreamBuilder<List<LastMessageModel>>(
          stream: chatService.getUserChatListByLastMessage(currentUserId),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return Center(child: Loader());
            }
            if (!snapshot.hasData || snapshot.data!.isEmpty) {
              return _buildEmptyState();
            }

            final allChats = snapshot.data ?? [];

            return ValueListenableBuilder<String>(
              valueListenable: searchNotifier,
              builder: (context, searchText, _) {
                List<LastMessageModel> filteredChats;

                if (searchText.trim().isEmpty) {
                  filteredChats = allChats;
                } else {
                  final query = searchText.toLowerCase();
                  filteredChats = allChats.where((chat) {
                    final groupName = (chat.groupName ?? '').toLowerCase();
                    final receiverId = chat.senderId == currentUserId
                        ? chat.receiverId
                        : chat.senderId;
                    final cachedName =
                        (_userNameCache[receiverId] ?? '').toLowerCase();
                    return groupName.contains(query) ||
                        cachedName.contains(query);
                  }).toList();
                }

                return _buildChatList(filteredChats, searchText);
              },
            );
          },
        ),
        floatingActionButton: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            FloatingActionButton(
              child: Image.asset(ic_messages,
                  width: 25, height: 25, color: Colors.white),
              backgroundColor: primaryColor,
              onPressed: () {
                NewChatScreen().launch(context,
                    pageRouteAnimation: PageRouteAnimation.SlideBottomTop,
                    duration: 250.milliseconds);
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildChatList(
      List<LastMessageModel> filteredChats, String searchText) {
    final Map<String, int> groupUnread = {};

    final requestChats = filteredChats
        .where((chat) =>
            chat.isRequest &&
            chat.senderId != currentUserId &&
            !(chat.isArchive[currentUserId] ?? false))
        .toList();

    final archivedChats = filteredChats
        .where((chat) => (chat.isArchive[currentUserId] ?? false))
        .toList();

    final normalChats = filteredChats
        .where((chat) =>
            chat.chatType != "admin" && // 🔥 exclude admin
            (!chat.isRequest || chat.senderId == currentUserId) &&
            !(chat.isArchive[currentUserId] ?? false))
        .toList();

    for (var chat in filteredChats) {
      if (chat.isGroupMessage) {
        final count = chat.unreadCounts?[currentUserId] ?? 0;
        groupUnread[chat.groupId] = count;
      }
    }

    final requestCount = requestChats.length;
    final archiveCount = archivedChats.length;

    final displayChats = [
      if (requestCount > 0) _placeholderModel('request_tile', true),
      if (archiveCount > 0) _placeholderModel('archive_tile', false),
      ...normalChats,
    ];

    return Column(
      children: [
        // 🔥 Sticky "My Groups" section
        StreamBuilder<List<GroupModel>>(
          stream: GroupChatMessageService().userGroupsStream(currentUserId),
          builder: (context, groupSnap) {
            if (groupSnap.connectionState == ConnectionState.waiting) {
              return _buildStickyGroupsSection(
                  isLoading: true, groups: [], groupUnread: {});
            }

            final allGroups = groupSnap.data ?? [];

            final groups = searchText.isEmpty
                ? allGroups
                : allGroups
                    .where((g) =>
                        g.name
                            ?.toLowerCase()
                            .contains(searchText.toLowerCase()) ??
                        false)
                    .toList();
            return _buildStickyGroupsSection(
                isLoading: false, groups: groups, groupUnread: groupUnread);
          },
        ),

        // 📋 Main chat list
        Expanded(
          child: ListView.separated(
            itemCount: displayChats.length,
            cacheExtent: 800,
            separatorBuilder: (context, index) => Divider(
              height: 1,
              thickness: 0.5,
              indent: 80,
              endIndent: 16,
              color: context.dividerColor,
            ),
            itemBuilder: (context, index) {
              final chat = displayChats[index];
              if (chat.chatId == 'request_tile') {
                return _buildRequestTile(requestCount, requestChats);
              }
              if (chat.chatId == 'archive_tile') {
                return _buildArchiveTile(archiveCount, archivedChats);
              }

              final time = chat.timestamp.toDate();

              if (chat.isGroupMessage) {
                final unreadCount = chat.unreadCounts?[currentUserId] ?? 0;
                return _buildChatTile(
                  name: chat.groupName,
                  subtitle: decryptedData(chat.lastMessage),
                  time: time,
                  unreadCount: unreadCount,
                  avatarWidget: _buildGroupAvatar(chat.groupName),
                  isSentByCurrentUser: chat.senderId == currentUserId,
                  isSeenByReceiver: false,
                  onTap: () {
                    ChatMessageService()
                        .markAsSeen(chat.groupId, currentUserId, true);
                    GroupChatScreen(
                      groupChatId: chat.groupId,
                      groupName: chat.groupName,
                    ).launch(context);
                  },
                  isGroup: true,
                  groupId: chat.groupId,
                  receiverId: chat.receiverId,
                  isArchive: chat.isArchive[currentUserId] ?? false,
                  shouldEnableLongPress: true,
                );
              }

              final receiverId = chat.senderId == currentUserId
                  ? chat.receiverId
                  : chat.senderId;

              final unreadCount = chat.receiverId == currentUserId
                  ? chat.unreadCountReceiver
                  : chat.unreadCountSender;

              return FutureBuilder<UserModel?>(
                future: chatService.getUserById(uid: receiverId),
                builder: (context, userSnap) {
                  if (!userSnap.hasData) return _buildLoadingTile();
                  final user = userSnap.data!;
                  _userNameCache[receiverId] = user.name ?? '';

                  return _buildChatTile(
                    name: user.name ?? '',
                    subtitle: decryptedData(chat.lastMessage),
                    time: time,
                    unreadCount: unreadCount,
                    avatarWidget: _buildAvatar(user),
                    isSentByCurrentUser: chat.senderId == currentUserId,
                    isSeenByReceiver: chat.isSeenByReceiver,
                    shouldEnableLongPress: true,
                    onTap: () async {
                      UserModel receiver = user;
                      await ChatScreen(receiver,
                              isArchive: chat.isArchive[currentUserId] ?? false,
                              isAdmin: false,
                              isFromRequest: chat.isRequest)
                          .launch(context);
                      await chatService.markAsSeen(
                          chat.chatId, currentUserId, false);
                    },
                    isGroup: false,
                    groupId: chat.groupId,
                    receiverId: receiverId,
                    isArchive: chat.isArchive[currentUserId] ?? false,
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }

// 🔥 NEW: Sticky "My Groups" Section (Stream-compatible)
  Widget _buildStickyGroupsSection({
    required bool isLoading,
    required List<GroupModel> groups,
    required Map<String, int> groupUnread,
  }) {
    if (isLoading) {
      return Container(
        color: context.scaffoldBackgroundColor,
        padding: const EdgeInsets.only(top: 12, bottom: 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              height: 95,
              child: ListView.builder(
                cacheExtent: 800,
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: 5,
                itemBuilder: (context, index) => Container(
                  width: 72,
                  margin: EdgeInsets.only(right: index == 4 ? 0 : 12),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: const [
                      ShimmerBox(height: 56, width: 56, radius: 28),
                      SizedBox(height: 8),
                      ShimmerBox(height: 12, width: 60),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 8),
            Divider(height: 1, thickness: 0.5, color: context.dividerColor),
          ],
        ),
      );
    }

    if (groups.isEmpty) return const SizedBox.shrink();

    return Container(
      color: context.scaffoldBackgroundColor,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: Text(
              "MyGroups".translate,
              style: TS.boldTextStyle(size: 16, weight: FontWeight.w700),
            ),
          ),
          SizedBox(
            height: 95,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              cacheExtent: 800,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: groups.length,
              itemBuilder: (context, index) {
                final group = groups[index];
                final unread = groupUnread[group.fltrdId] ?? 0;

                return GestureDetector(
                  onTap: () {
                    ChatMessageService()
                        .markAsSeen(group.fltrdId ?? "", currentUserId, true);
                    GroupChatScreen(
                      groupChatId: group.fltrdId ?? '',
                      groupName: group.name ?? '',
                    ).launch(context);
                  },
                  child: Container(
                    width: 72,
                    margin: EdgeInsets.only(
                        right: index == groups.length - 1 ? 0 : 12),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Stack(
                          clipBehavior: Clip.none,
                          children: [
                            groupAvatar(
                              name: group.name ?? "",
                              imageUrl: group.photoUrl,
                            ),
                            if (unread > 0)
                              Positioned(
                                right: -4,
                                top: -4,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 6, vertical: 3),
                                  decoration: BoxDecoration(
                                    color: primaryColor,
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Text(
                                    unread > 99 ? "99+" : unread.toString(),
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          group.name ?? '',
                          style: TS.primaryTextStyle(size: 11),
                          maxLines: 2,
                          textAlign: TextAlign.center,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 8),
          Divider(height: 1, thickness: 0.5, color: context.dividerColor),
        ],
      ),
    );
  }

  // --- unchanged functions ---
  LastMessageModel _placeholderModel(String id, bool isRequest) =>
      LastMessageModel(
        chatId: id,
        senderId: '',
        receiverId: '',
        lastMessage: '',
        groupName: '',
        groupId: '',
        participants: const [],
        isSeenBySender: false,
        isSeenByReceiver: false,
        isRequest: isRequest,
        isArchive: const {},
        isGroupMessage: false,
        unreadCountReceiver: 0,
        unreadCountSender: 0,
        messageType: MessageType.TEXT,
        chatType: "",
        timestamp: Timestamp.now(),
      );

  Widget _buildArchiveTile(int count, List<LastMessageModel> archivedChats) {
    return _buildChatTile(
      name: "ArchivedChats".translate,
      subtitle: count == 1
          ? "ArchivedChatSingle".translate
          : "$count ${"ArchivedChatMultipleAfter".translate}",
      time: DateTime.now(),
      isGroup: false,
      isArchive: true,
      groupId: "",
      receiverId: "",
      unreadCount: count,
      shouldEnableLongPress: false,
      avatarWidget: CircleAvatar(
        radius: 28,
        backgroundColor: context.cardColor,
        child: Icon(Icons.archive_outlined, color: context.iconColor, size: 26),
      ),
      isSentByCurrentUser: false,
      isSeenByReceiver: false,
      onTap: () {
        ArchivedChatListScreen(
          currentUserId: currentUserId,
          archivedChats: archivedChats,
        ).launch(context);
      },
    );
  }

  Widget _buildRequestTile(int count, List<LastMessageModel> chatList) =>
      _buildChatTile(
        name: "ChatMessageRequests".translate,
        subtitle: count == 1
            ? "ChatRequestSingle".translate
            : "${"youHave".translate} $count ${"newChatRequest".translate}",
        time: DateTime.now(),
        unreadCount: count,
        shouldEnableLongPress: false,
        isGroup: false,
        receiverId: "",
        groupId: "",
        isArchive: false,
        avatarWidget: CircleAvatar(
          radius: 28,
          backgroundColor: context.cardColor,
          child: Icon(Icons.mail_outline, color: context.iconColor, size: 28),
        ),
        isSentByCurrentUser: false,
        isSeenByReceiver: false,
        onTap: () {
          ChatRequestListScreen(
            currentUserId: currentUserId,
            chatList: chatList,
          ).launch(context);
        },
      );

  Widget _buildChatTile({
    required String name,
    required String subtitle,
    required DateTime time,
    required int unreadCount,
    required Widget avatarWidget,
    required bool isSentByCurrentUser,
    required bool isSeenByReceiver,
    required VoidCallback onTap,
    required bool isGroup,
    required String groupId,
    required String receiverId,
    required bool isArchive,
    required shouldEnableLongPress,
  }) {
    return GestureDetector(
      onLongPress: !shouldEnableLongPress
          ? null
          : () async {
              ContactModel contact = ContactModel(uid: currentUserId);
              UserModel receiver = UserModel(uid: receiverId);
              await showInDialog(
                Navigator.of(context, rootNavigator: true).context,
                backgroundColor: context.cardColor,
                builder: (p0) {
                  return ChatOptionDialog(
                    isGroup: isGroup,
                    groupId: groupId,
                    receiverUser: receiver,
                    isFromArchive: isArchive,
                    data: contact,
                  );
                },
                contentPadding: EdgeInsets.zero,
                dialogAnimation: DialogAnimation.SLIDE_TOP_BOTTOM,
              );
            },
      child: Container(
        color: context.scaffoldBackgroundColor,
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  avatarWidget,
                  16.width,
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                              child: Text(
                                name,
                                style: TS.boldTextStyle(
                                  weight: unreadCount > 0
                                      ? FontWeight.w700
                                      : FontWeight.w600,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            8.width,
                            Text(_formatChatTime(time),
                                style: TS.primaryTextStyle(
                                  size: 12,
                                  weight: unreadCount > 0
                                      ? FontWeight.w600
                                      : FontWeight.normal,
                                )),
                          ],
                        ),
                        6.height,
                        Row(
                          children: [
                            if (isSentByCurrentUser)
                              Icon(Icons.done_all,
                                  size: 16,
                                  color: isSeenByReceiver
                                      ? primaryColor
                                      : Colors.grey),
                            4.width,
                            Expanded(
                              child: Text(
                                subtitle,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: TS.primaryTextStyle(
                                  weight: unreadCount > 0
                                      ? FontWeight.w500
                                      : FontWeight.normal,
                                  height: 1.3,
                                ),
                              ),
                            ),
                            if (unreadCount > 0)
                              Container(
                                constraints: const BoxConstraints(
                                    minWidth: 20, minHeight: 20),
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: primaryColor,
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Text(
                                  unreadCount > 99 ? '99+' : '$unreadCount',
                                  style: TS.boldTextStyle(
                                      size: 11,
                                      weight: FontWeight.bold,
                                      color: Colors.white),
                                  textAlign: TextAlign.center,
                                ),
                              ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget groupAvatar({
    required String name,
    required String? imageUrl,
    double radius = 28,
  }) {
    // Return initials if image is null or empty
    if (imageUrl == null || imageUrl.trim().isEmpty) {
      return _buildGroupAvatar(name, radius: radius);
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: CachedNetworkImage(
        imageUrl: imageUrl,
        width: radius * 2,
        height: radius * 2,
        fit: BoxFit.cover,
        placeholder: (context, url) => _buildGroupAvatar(name, radius: radius),
        errorWidget: (context, url, error) =>
            _buildGroupAvatar(name, radius: radius),
      ),
    );
  }

  Widget _buildGroupAvatar(String name, {double radius = 28}) {
    final initial = name.isNotEmpty ? name[0].toUpperCase() : '?';
    final color = _getColorFromString(name);

    return CircleAvatar(
      radius: radius,
      backgroundColor: color,
      child: Text(
        initial,
        style: TextStyle(
          color: Colors.white,
          fontSize: radius * 0.85,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  Widget _buildAvatar(UserModel user) {
    if (user.photoUrl != null && user.photoUrl!.isNotEmpty) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(28),
        child: cachedImage(user.photoUrl,
            height: 56, width: 56, fit: BoxFit.cover),
      );
    } else {
      final initial = user.name!.isNotEmpty ? user.name![0].toUpperCase() : '?';
      final color = _getColorFromString(user.name ?? '');
      return CircleAvatar(
        radius: 28,
        backgroundColor: color,
        child: Text(initial,
            style: const TextStyle(
                color: Colors.white,
                fontSize: 24,
                fontWeight: FontWeight.w600)),
      );
    }
  }

  Widget _buildLoadingTile() => Container(
        color: context.scaffoldBackgroundColor,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            CircleAvatar(radius: 28, backgroundColor: context.cardColor),
            16.width,
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(height: 16, width: 120, color: context.cardColor),
                  8.height,
                  Container(
                      height: 14,
                      width: 180,
                      color: context.cardColor.withOpacity(0.5)),
                ],
              ),
            ),
          ],
        ),
      );

  Widget _buildEmptyState() => Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.chat_bubble_outline,
                size: 80, color: context.iconColor.withOpacity(0.3)),
            16.height,
            Text('NoChatsYet'.translate,
                style: TextStyle(
                  fontSize: 18,
                  color: context.theme.textTheme.bodyLarge?.color
                      ?.withOpacity(0.6),
                  fontWeight: FontWeight.w500,
                )),
            8.height,
            Text('StartAConversation'.translate,
                style: TextStyle(
                  fontSize: 14,
                  color: context.theme.textTheme.bodySmall?.color
                      ?.withOpacity(0.4),
                )),
          ],
        ),
      );

  String _formatChatTime(DateTime time) {
    final now = DateTime.now();
    final difference = now.difference(time);
    if (difference.inDays == 0) {
      return TimeOfDay.fromDateTime(time).format(context);
    } else if (difference.inDays == 1) {
      return 'Yesterday';
    } else if (difference.inDays < 7) {
      final weekdays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
      return weekdays[time.weekday - 1];
    } else {
      return '${time.day}/${time.month}/${time.year}';
    }
  }

  Color _getColorFromString(String str) {
    final colors = [
      const Color(0xFF2196F3),
      const Color(0xFF4CAF50),
      const Color(0xFFFF9800),
      const Color(0xFF9C27B0),
      const Color(0xFFE91E63),
      const Color(0xFF00BCD4),
      const Color(0xFFFF5722),
      const Color(0xFF3F51B5),
      const Color(0xFF009688),
      const Color(0xFFCDDC39),
      const Color(0xFFFFC107),
      const Color(0xFF795548),
    ];
    int hash = 0;
    for (int i = 0; i < str.length; i++) {
      hash = str.codeUnitAt(i) + ((hash << 5) - hash);
    }
    return colors[hash.abs() % colors.length];
  }
}

class ArchivedChatListScreen extends StatefulWidget {
  final String currentUserId;
  final List<LastMessageModel> archivedChats;

  const ArchivedChatListScreen({
    super.key,
    required this.currentUserId,
    required this.archivedChats,
  });

  @override
  State<ArchivedChatListScreen> createState() => _ArchivedChatListScreenState();
}

class _ArchivedChatListScreenState extends State<ArchivedChatListScreen> {
  final ChatMessageService chatService = ChatMessageService();
  late List<LastMessageModel> _archivedChats;

  @override
  void initState() {
    super.initState();
    _archivedChats = List.from(widget.archivedChats);
  }

  void _removeLocally(LastMessageModel chat) {
    setState(() {
      _archivedChats.removeWhere((c) => c.chatId == chat.chatId);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.scaffoldBackgroundColor,
      appBar: appBarWidget(
        'archive_chat'.translate,
        textColor: Colors.white,
        backWidget: BackButton(
          color: white,
          onPressed: () {
            finish(context, true);
          },
        ),
      ),
      body: _archivedChats.isEmpty
          ? _buildEmptyState(context)
          : ListView.separated(
              itemCount: _archivedChats.length,
              cacheExtent: 800,
              separatorBuilder: (context, index) => Divider(
                height: 1,
                thickness: 0.5,
                indent: 80,
                endIndent: 16,
                color: context.dividerColor,
              ),
              itemBuilder: (context, index) {
                final chat = _archivedChats[index];
                final time = chat.timestamp.toDate();

                // 🟢 GROUP CHAT
                if (chat.isGroupMessage) {
                  final subtitle = decryptedData(chat.lastMessage);

                  return GestureDetector(
                    onLongPress: () async {
                      ContactModel contact =
                          ContactModel(uid: widget.currentUserId);
                      await showInDialog(
                        context,
                        backgroundColor: context.cardColor,
                        builder: (p0) {
                          return ChatOptionDialog(
                            isGroup: true,
                            groupId: chat.groupId,
                            receiverUser: null,
                            isFromArchive: true,
                            data: contact,
                          );
                        },
                        contentPadding: EdgeInsets.zero,
                        dialogAnimation: DialogAnimation.SLIDE_TOP_BOTTOM,
                      ).then((value) {
                        print("Value from Arch => ${value}");
                        if (value == 'unarchived') {
                          _removeLocally(chat);
                        }
                      });
                    },
                    onTap: () {
                      GroupChatScreen(
                        groupChatId: chat.groupId,
                        groupName: chat.groupName,
                      ).launch(context);
                    },
                    child: _buildChatTile(
                      avatarWidget: _buildGroupAvatar(chat.groupName),
                      name: chat.groupName,
                      subtitle: subtitle,
                      time: time,
                    ),
                  );
                }

                // 🔵 1-to-1 CHAT
                final receiverId = chat.senderId == widget.currentUserId
                    ? chat.receiverId
                    : chat.senderId;

                return FutureBuilder<UserModel?>(
                  future: chatService.getUserById(uid: receiverId),
                  builder: (context, snapshot) {
                    if (!snapshot.hasData) {
                      return _buildLoadingTile(context);
                    }

                    final user = snapshot.data!;
                    final subtitle = decryptedData(chat.lastMessage);

                    return GestureDetector(
                      onLongPress: () async {
                        ContactModel contact =
                            ContactModel(uid: widget.currentUserId);
                        await showInDialog(
                          context,
                          backgroundColor: context.cardColor,
                          builder: (p0) {
                            return ChatOptionDialog(
                              isGroup: false,
                              groupId: '',
                              receiverUser: user,
                              isFromArchive: true,
                              data: contact,
                            );
                          },
                          contentPadding: EdgeInsets.zero,
                          dialogAnimation: DialogAnimation.SLIDE_TOP_BOTTOM,
                        ).then((value) {
                          if (value == 'unarchived') {
                            _removeLocally(chat);
                          }
                        });
                      },
                      onTap: () async {
                        final receiverId =
                            chat.senderId == getStringAsync(userId)
                                ? chat.receiverId
                                : chat.senderId;
                        UserModel receiver = UserModel(uid: receiverId);
                        bool isFromRequest = chat.isRequest;
                        bool isAdmin = false;
                        bool isArchive =
                            chat.isArchive[widget.currentUserId] ?? false;

                        bool? res = await ChatScreen(
                          receiver,
                          isArchive: isArchive,
                          isAdmin: isAdmin,
                          isFromRequest: isFromRequest,
                        ).launch(context);

                        if (res != null || res == null) {
                          await chatMessageService
                              .setUnReadStatusToTrue(
                                senderId: sender.uid ?? '',
                                receiverId: receiver.uid ?? '',
                              )
                              .then((value) {});
                          await chatService.markAsSeen(
                              chat.chatId, widget.currentUserId, false);
                        }
                      },
                      child: _buildChatTile(
                        avatarWidget: _buildAvatar(user),
                        name: user.name ?? '',
                        subtitle: subtitle,
                        time: time,
                      ),
                    );
                  },
                );
              },
            ),
    );
  }

  /// ----- UI Helpers -----
  Widget _buildChatTile({
    required Widget avatarWidget,
    required String name,
    required String subtitle,
    required DateTime time,
  }) {
    return Container(
      key: ValueKey(name),
      color: context.scaffoldBackgroundColor,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          avatarWidget,
          16.width,
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        name,
                        style: TS.boldTextStyle(weight: FontWeight.w600),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    Text(
                      _formatChatTime(time, context),
                      style: TS.primaryTextStyle(
                        size: 12,
                        weight: FontWeight.normal,
                      ),
                    ),
                  ],
                ),
                6.height,
                Text(
                  subtitle,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TS.primaryTextStyle(
                      weight: FontWeight.normal, height: 1.3),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.archive_outlined,
              size: 80, color: context.iconColor.withOpacity(0.3)),
          16.height,
          Text(
            'NoArchivedChats'.translate,
            style: TextStyle(
              fontSize: 18,
              color: context.theme.textTheme.bodyLarge?.color?.withOpacity(0.6),
              fontWeight: FontWeight.w500,
            ),
          ),
          8.height,
          Text(
            'ArchivedEmptySubtitle'.translate,
            style: TextStyle(
              fontSize: 14,
              color: context.theme.textTheme.bodySmall?.color?.withOpacity(0.4),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGroupAvatar(String name) {
    final initial = name.isNotEmpty ? name[0].toUpperCase() : '?';
    final color = _getColorFromString(name);
    return CircleAvatar(
      radius: 28,
      backgroundColor: color,
      child: Text(
        initial,
        style: const TextStyle(
            color: Colors.white, fontSize: 24, fontWeight: FontWeight.w600),
      ),
    );
  }

  Widget _buildLoadingTile(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            CircleAvatar(
              radius: 28,
              backgroundColor: context.cardColor,
            ),
            16.width,
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(height: 16, width: 120, color: context.cardColor),
                  8.height,
                  Container(
                      height: 14,
                      width: 180,
                      color: context.cardColor.withOpacity(0.5)),
                ],
              ),
            ),
          ],
        ),
      );

  Widget _buildAvatar(UserModel user) {
    if (user.photoUrl != null && user.photoUrl!.isNotEmpty) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(28),
        child: cachedImage(user.photoUrl,
            height: 56, width: 56, fit: BoxFit.cover),
      );
    } else {
      final initial = user.name!.isNotEmpty ? user.name![0].toUpperCase() : '?';
      final color = _getColorFromString(user.name ?? '');
      return CircleAvatar(
        radius: 28,
        backgroundColor: color,
        child: Text(
          initial,
          style: const TextStyle(
              color: Colors.white, fontSize: 24, fontWeight: FontWeight.w600),
        ),
      );
    }
  }

  String _formatChatTime(DateTime time, BuildContext context) {
    final now = DateTime.now();
    final difference = now.difference(time);

    if (difference.inDays == 0) {
      return TimeOfDay.fromDateTime(time).format(context);
    } else if (difference.inDays == 1) {
      return 'Yesterday'.translate;
    } else if (difference.inDays < 7) {
      final weekdays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
      return weekdays[time.weekday - 1];
    } else {
      return '${time.day}/${time.month}/${time.year}';
    }
  }

  Color _getColorFromString(String str) {
    final colors = [
      const Color(0xFF2196F3),
      const Color(0xFF4CAF50),
      const Color(0xFFFF9800),
      const Color(0xFF9C27B0),
      const Color(0xFFE91E63),
      const Color(0xFF00BCD4),
      const Color(0xFFFF5722),
      const Color(0xFF3F51B5),
      const Color(0xFF009688),
      const Color(0xFFCDDC39),
      const Color(0xFFFFC107),
      const Color(0xFF795548),
    ];

    int hash = 0;
    for (int i = 0; i < str.length; i++) {
      hash = str.codeUnitAt(i) + ((hash << 5) - hash);
    }

    return colors[hash.abs() % colors.length];
  }
}

/// 🔆 Simple shimmer placeholder widget
class ShimmerBox extends StatefulWidget {
  final double height;
  final double width;
  final double radius;

  const ShimmerBox({
    super.key,
    required this.height,
    required this.width,
    this.radius = 4,
  });

  @override
  State<ShimmerBox> createState() => _ShimmerBoxState();
}

class _ShimmerBoxState extends State<ShimmerBox>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (_, __) {
        final shimmerPosition = _controller.value * 2 - 1; // -1 → +1
        return Container(
          width: widget.width,
          height: widget.height,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(widget.radius),
            gradient: LinearGradient(
              begin: Alignment(-1, 0),
              end: Alignment(1, 0),
              colors: [
                Colors.grey[300]!,
                Colors.grey[100]!,
                Colors.grey[300]!,
              ],
              stops: [
                shimmerPosition.clamp(0.0, 1.0),
                (shimmerPosition + 0.5).clamp(0.0, 1.0),
                (shimmerPosition + 1).clamp(0.0, 1.0),
              ],
            ),
          ),
        );
      },
    );
  }
}

class ChatRequestListScreen extends StatefulWidget {
  final String currentUserId;
  final List<LastMessageModel> chatList;

  const ChatRequestListScreen({
    super.key,
    required this.currentUserId,
    required this.chatList,
  });

  @override
  State<ChatRequestListScreen> createState() => _ChatRequestListScreenState();
}

class _ChatRequestListScreenState extends State<ChatRequestListScreen> {
  final ChatMessageService chatService = ChatMessageService();
  late List<LastMessageModel> _archivedChats;

  @override
  void initState() {
    super.initState();
    _archivedChats = List.from(widget.chatList);
  }

  void _removeLocally(LastMessageModel chat) {
    setState(() {
      _archivedChats.removeWhere((c) => c.chatId == chat.chatId);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.scaffoldBackgroundColor,
      appBar: appBarWidget(
        'ChatMessageRequests'.translate,
        textColor: Colors.white,
        backWidget: BackButton(
          color: white,
          onPressed: () {
            finish(context, true);
          },
        ),
      ),
      body: _archivedChats.isEmpty
          ? _buildEmptyState(context)
          : ListView.separated(
              itemCount: _archivedChats.length,
              cacheExtent: 800,
              separatorBuilder: (context, index) => Divider(
                height: 1,
                thickness: 0.5,
                indent: 80,
                endIndent: 16,
                color: context.dividerColor,
              ),
              itemBuilder: (context, index) {
                final chat = _archivedChats[index];
                final time = chat.timestamp.toDate();

                // 🔵 1-to-1 CHAT
                final receiverId = chat.senderId == widget.currentUserId
                    ? chat.receiverId
                    : chat.senderId;

                return FutureBuilder<UserModel?>(
                  future: chatService.getUserById(uid: receiverId),
                  builder: (context, snapshot) {
                    if (!snapshot.hasData) {
                      return _buildLoadingTile(context);
                    }

                    final user = snapshot.data!;
                    final subtitle = decryptedData(chat.lastMessage);

                    return GestureDetector(
                      onLongPress: () async {
                        ContactModel contact =
                            ContactModel(uid: widget.currentUserId);
                        await showInDialog(
                          context,
                          backgroundColor: context.cardColor,
                          builder: (p0) {
                            return ChatOptionDialog(
                              isGroup: false,
                              groupId: '',
                              receiverUser: user,
                              isFromArchive: true,
                              data: contact,
                            );
                          },
                          contentPadding: EdgeInsets.zero,
                          dialogAnimation: DialogAnimation.SLIDE_TOP_BOTTOM,
                        ).then((value) {
                          if (value == 'unarchived') {
                            _removeLocally(chat);
                          }
                        });
                      },
                      onTap: () async {
                        final receiverId =
                            chat.senderId == getStringAsync(userId)
                                ? chat.receiverId
                                : chat.senderId;
                        UserModel receiver = UserModel(uid: receiverId);
                        bool isFromRequest = chat.isRequest;
                        bool isAdmin = false;
                        bool isArchive =
                            chat.isArchive[widget.currentUserId] ?? false;
                        bool? res = await ChatScreen(
                          receiver,
                          isArchive: isArchive,
                          isAdmin: isAdmin,
                          isFromRequest: isFromRequest,
                        ).launch(context);
                        if (res != null || res == null) {
                          await chatMessageService
                              .setUnReadStatusToTrue(
                                senderId: sender.uid ?? '',
                                receiverId: receiver.uid ?? '',
                              )
                              .then((value) {});
                          await chatService.markAsSeen(
                              chat.chatId, widget.currentUserId, false);
                        }
                      },
                      child: _buildChatTile(
                        avatarWidget: _buildAvatar(user),
                        name: user.name ?? '',
                        subtitle: subtitle,
                        time: time,
                      ),
                    );
                  },
                );
              },
            ),
    );
  }

  /// ----- UI Helpers -----
  Widget _buildChatTile({
    required Widget avatarWidget,
    required String name,
    required String subtitle,
    required DateTime time,
  }) {
    return Container(
      key: ValueKey(name),
      color: context.scaffoldBackgroundColor,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          avatarWidget,
          16.width,
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        name,
                        style: TS.boldTextStyle(weight: FontWeight.w600),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    Text(
                      _formatChatTime(time, context),
                      style: TS.primaryTextStyle(
                        size: 12,
                        weight: FontWeight.normal,
                      ),
                    ),
                  ],
                ),
                6.height,
                Text(
                  subtitle,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TS.primaryTextStyle(
                      weight: FontWeight.normal, height: 1.3),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.archive_outlined,
              size: 80, color: context.iconColor.withOpacity(0.3)),
          16.height,
          Text(
            'NoArchivedChats'.translate,
            style: TextStyle(
              fontSize: 18,
              color: context.theme.textTheme.bodyLarge?.color?.withOpacity(0.6),
              fontWeight: FontWeight.w500,
            ),
          ),
          8.height,
          Text(
            'ArchivedEmptySubtitle'.translate,
            style: TextStyle(
              fontSize: 14,
              color: context.theme.textTheme.bodySmall?.color?.withOpacity(0.4),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLoadingTile(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            CircleAvatar(
              radius: 28,
              backgroundColor: context.cardColor,
            ),
            16.width,
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(height: 16, width: 120, color: context.cardColor),
                  8.height,
                  Container(
                      height: 14,
                      width: 180,
                      color: context.cardColor.withOpacity(0.5)),
                ],
              ),
            ),
          ],
        ),
      );

  Widget _buildAvatar(UserModel user) {
    if (user.photoUrl != null && user.photoUrl!.isNotEmpty) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(28),
        child: cachedImage(user.photoUrl,
            height: 56, width: 56, fit: BoxFit.cover),
      );
    } else {
      final initial = user.name!.isNotEmpty ? user.name![0].toUpperCase() : '?';
      final color = _getColorFromString(user.name ?? '');
      return CircleAvatar(
        radius: 28,
        backgroundColor: color,
        child: Text(
          initial,
          style: const TextStyle(
              color: Colors.white, fontSize: 24, fontWeight: FontWeight.w600),
        ),
      );
    }
  }

  String _formatChatTime(DateTime time, BuildContext context) {
    final now = DateTime.now();
    final difference = now.difference(time);

    if (difference.inDays == 0) {
      return TimeOfDay.fromDateTime(time).format(context);
    } else if (difference.inDays == 1) {
      return 'Yesterday'.translate;
    } else if (difference.inDays < 7) {
      final weekdays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
      return weekdays[time.weekday - 1];
    } else {
      return '${time.day}/${time.month}/${time.year}';
    }
  }

  Color _getColorFromString(String str) {
    final colors = [
      const Color(0xFF2196F3),
      const Color(0xFF4CAF50),
      const Color(0xFFFF9800),
      const Color(0xFF9C27B0),
      const Color(0xFFE91E63),
      const Color(0xFF00BCD4),
      const Color(0xFFFF5722),
      const Color(0xFF3F51B5),
      const Color(0xFF009688),
      const Color(0xFFCDDC39),
      const Color(0xFFFFC107),
      const Color(0xFF795548),
    ];

    int hash = 0;
    for (int i = 0; i < str.length; i++) {
      hash = str.codeUnitAt(i) + ((hash << 5) - hash);
    }

    return colors[hash.abs() % colors.length];
  }
}
