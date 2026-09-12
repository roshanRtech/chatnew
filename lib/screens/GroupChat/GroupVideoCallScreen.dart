import 'dart:async';
import 'package:chat/main.dart';
import 'package:chat/models/CallModel.dart';
import 'package:chat/utils/AppConstants.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:agora_rtc_engine/agora_rtc_engine.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:nb_utils/nb_utils.dart';

class GroupVideoCallScreen extends StatefulWidget {
  final CallModel? callModel;

  GroupVideoCallScreen({this.callModel});

  @override
  _GroupVideoCallScreenState createState() => _GroupVideoCallScreenState();
}

class _GroupVideoCallScreenState extends State<GroupVideoCallScreen> {
  // Map to store user IDs and their names/photos
  Map<int, UserInfo> _users = {};
  bool muted = false;
  bool videoDisabled = false;
  late RtcEngine _engine;
  String callStatus = "Connecting...";
  int currentPage = 0;
  int usersPerPage = 4; // Number of users to display per page
  bool isFullScreen = false;
  int? fullScreenUid;
  late final RtcEngineEventHandler _rtcEngineEventHandler;

  // To track users' speaking status
  Map<int, double> speakingUsers = {};
  Timer? speakingTimer;

  // Control panel visibility
  bool showControls = true;
  Timer? controlsTimer;

  @override
  void initState() {
    super.initState();
    init();
  }

  late StreamSubscription callStreamSubscription;

  init() async {
    addPostFrameCallback();
    initialize();

    // Set up timer to check speaking users and hide controls
    speakingTimer = Timer.periodic(Duration(milliseconds: 500), (timer) {
      updateSpeakingUsers();
    });

    // Initially show controls and hide after 5 seconds
    startControlsTimer();
  }

  void startControlsTimer() {
    controlsTimer?.cancel();
    setState(() {
      showControls = true;
    });
    controlsTimer = Timer(Duration(seconds: 5), () {
      if (mounted) {
        setState(() {
          showControls = false;
        });
      }
    });
  }

  void updateSpeakingUsers() {
    // In a real app, you would get audio volume info from Agora SDK
    // This is simulated here
    _users.keys.forEach((uid) {
      double volume = speakingUsers[uid] ?? 0;
      if (volume > 0) {
        speakingUsers[uid] = volume - 0.1;
        if (speakingUsers[uid]! < 0) speakingUsers[uid] = 0;
      }
    });
    setState(() {});
  }

  Future<void> initialize() async {
    await _initAgoraRtcEngine();
  }

  Future<void> _initAgoraRtcEngine() async {
    _engine = createAgoraRtcEngine();
    await _engine.initialize(RtcEngineContext(
      appId: appSettingStore.agoraCallId,
      channelProfile: ChannelProfileType.channelProfileLiveBroadcasting,
    ));

    _rtcEngineEventHandler = RtcEngineEventHandler(
      onJoinChannelSuccess: (RtcConnection connection, int elapsed) {
        debugPrint("local user ${connection.localUid} joined");
        setState(() {
          callStatus = "Connected";

          // Add local user to the users list
          _users[0] = UserInfo(
              uid: 0,
              name: "You",
              photoUrl: getStringAsync(userPhotoUrl),
              isLocal: true
          );
        });
      },
      onUserJoined: (RtcConnection connection, int remoteUid, int elapsed) {
        debugPrint("remote user $remoteUid joined");
        setState(() {
          // Get user info from participants list (in a real app)
          _users[remoteUid] = UserInfo(
              uid: remoteUid,
              name: "User $remoteUid", // Replace with actual name lookup
              photoUrl: "", // Replace with actual photo lookup
              isLocal: false
          );

          // Simulate speaking
          speakingUsers[remoteUid] = 0.8;
        });
      },
      onUserOffline: (RtcConnection connection, int remoteUid, UserOfflineReasonType reason) {
        debugPrint("remote user $remoteUid left channel");
        setState(() {
          _users.remove(remoteUid);
          speakingUsers.remove(remoteUid);

          // If the full screen user left, exit full screen mode
          if (fullScreenUid == remoteUid) {
            isFullScreen = false;
            fullScreenUid = null;
          }
        });
      },
      onLeaveChannel: (RtcConnection connection, RtcStats stats) {
        setState(() {
          _users.clear();
          speakingUsers.clear();
        });
      },
      onTokenPrivilegeWillExpire: (RtcConnection connection, String token) {
        debugPrint('[onTokenPrivilegeWillExpire] connection: ${connection.toJson()}, token: $token');
        // Here you should implement token refresh
      },
      onAudioVolumeIndication: (RtcConnection connection, List<AudioVolumeInfo> speakers, int totalVolume, int totalVolumeWithNoiseReduction) {
        setState(() {
          for (var speaker in speakers) {
            if ((speaker.volume??0) > 50) {
              speakingUsers[speaker.uid??0] = (speaker.volume??0) / 100;
            }
          }
        });
      },
      onError: (ErrorCodeType err, String msg) {
        debugPrint('[onError] err: $err, msg: $msg');
        setState(() {
          callStatus = "Error: $msg";
        });
      },
    );

    _engine.registerEventHandler(_rtcEngineEventHandler);

    await _engine.setClientRole(role: ClientRoleType.clientRoleBroadcaster);
    await _engine.enableVideo();
    await _engine.enableAudio();
    await _engine.enableAudioVolumeIndication(interval: 500, smooth: 3, reportVad: true);
    await _engine.startPreview();

    // Join the channel
    await _engine.joinChannel(
      token: "",
      channelId: widget.callModel!.channelId!,
      uid: 0,
      options: const ChannelMediaOptions(
        clientRoleType: ClientRoleType.clientRoleBroadcaster,
        publishMicrophoneTrack: true,
        publishCameraTrack: true,
        autoSubscribeAudio: true,
        autoSubscribeVideo: true,
      ),
    );
  }

  void addPostFrameCallback() {
    SchedulerBinding.instance.addPostFrameCallback((_) {
      callStreamSubscription = callService.callStream(uid: getStringAsync(userId)).listen((DocumentSnapshot ds) {
        switch (ds.data()) {
          case null:
            finish(context);
            break;
          default:
          // Handle call updates
            final callData = ds.data() as Map<String, dynamic>;
            if (callData['status'] == 'ended') {
              finish(context);
            }
            break;
        }
      });
    });
  }

  @override
  void setState(fn) {
    if (mounted) super.setState(fn);
  }

  @override
  void dispose() {
    _dispose();
    speakingTimer?.cancel();
    controlsTimer?.cancel();
    super.dispose();
  }

  Future<void> _dispose() async {
    _users.clear();
    _engine.unregisterEventHandler(_rtcEngineEventHandler);
    await _engine.leaveChannel();
    await _engine.release();
    callStreamSubscription.cancel();
  }

  // Control buttons for the call
  Widget _buildControlBar() {
    return AnimatedOpacity(
      opacity: showControls ? 1.0 : 0.0,
      duration: Duration(milliseconds: 300),
      child: Container(
        alignment: Alignment.bottomCenter,
        padding: const EdgeInsets.symmetric(vertical: 16),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            RawMaterialButton(
              onPressed: _onToggleMute,
              child: Icon(
                  muted ? Icons.mic_off : Icons.mic,
                  color: muted ? Colors.white : Colors.blueAccent,
                  size: 20.0
              ),
              shape: CircleBorder(),
              elevation: 2.0,
              fillColor: muted ? Colors.blueAccent : Colors.white,
              padding: const EdgeInsets.all(12.0),
            ),
            16.width,
            RawMaterialButton(
              onPressed: _onToggleVideo,
              child: Icon(
                  videoDisabled ? Icons.videocam_off : Icons.videocam,
                  color: videoDisabled ? Colors.white : Colors.blueAccent,
                  size: 20.0
              ),
              shape: CircleBorder(),
              elevation: 2.0,
              fillColor: videoDisabled ? Colors.blueAccent : Colors.white,
              padding: const EdgeInsets.all(12.0),
            ),
            16.width,
            RawMaterialButton(
              onPressed: () => callService.endCall(callModel: widget.callModel!),
              child: Icon(Icons.call_end, color: Colors.white, size: 25.0),
              shape: CircleBorder(),
              elevation: 2.0,
              fillColor: Colors.redAccent,
              padding: const EdgeInsets.all(15.0),
            ),
            16.width,
            RawMaterialButton(
              onPressed: _onSwitchCamera,
              child: Icon(Icons.switch_camera, color: Colors.blueAccent, size: 20.0),
              shape: CircleBorder(),
              elevation: 2.0,
              fillColor: Colors.white,
              padding: const EdgeInsets.all(12.0),
            ),
            16.width,
            RawMaterialButton(
              onPressed: _togglePageView,
              child: Icon(Icons.people, color: Colors.blueAccent, size: 20.0),
              shape: CircleBorder(),
              elevation: 2.0,
              fillColor: Colors.white,
              padding: const EdgeInsets.all(12.0),
            ),
          ],
        ),
      ),
    );
  }

  void _onToggleMute() {
    setState(() {
      muted = !muted;
    });
    _engine.muteLocalAudioStream(muted);
    startControlsTimer();
  }

  void _onToggleVideo() {
    setState(() {
      videoDisabled = !videoDisabled;
    });
    _engine.muteLocalVideoStream(videoDisabled);
    startControlsTimer();
  }

  void _onSwitchCamera() {
    _engine.switchCamera();
    startControlsTimer();
  }

  void _togglePageView() {
    setState(() {
      if (_users.length > usersPerPage) {
        currentPage = (currentPage + 1) % ((_users.length / usersPerPage).ceil());
      }
    });
    startControlsTimer();
  }

  void _toggleFullScreenMode(int uid) {
    setState(() {
      if (isFullScreen && fullScreenUid == uid) {
        // Exit full screen if tapping the same user
        isFullScreen = false;
        fullScreenUid = null;
      } else {
        // Enter full screen for this user
        isFullScreen = true;
        fullScreenUid = uid;
      }
    });
    startControlsTimer();
  }

  // Build the grid of video views
  Widget _buildVideoGrid() {
    // If in full screen mode, show only the selected user
    if (isFullScreen && fullScreenUid != null) {
      return _buildSingleVideoView(fullScreenUid!);
    }

    // Calculate which users to show on current page
    final startIndex = currentPage * usersPerPage;
    final endIndex = min(startIndex + usersPerPage, _users.length);

    // Get the list of users for the current page
    final List<int> pageUsers = _users.keys.toList().sublist(
        startIndex,
        min(endIndex, _users.length)
    );

    // Determine grid dimensions based on number of users
    int crossAxisCount;
    if (pageUsers.length <= 1) {
      crossAxisCount = 1;
    } else if (pageUsers.length <= 4) {
      crossAxisCount = 2;
    } else {
      crossAxisCount = 3; // For 5+ users
    }

    return GestureDetector(
      onTap: () {
        startControlsTimer();
      },
      child: GridView.builder(
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: crossAxisCount,
          childAspectRatio: 3/4, // Adjusted for portrait mode devices
        ),
        itemCount: pageUsers.length,
        itemBuilder: (context, index) {
          final uid = pageUsers[index];
          final userInfo = _users[uid]!;

          return GestureDetector(
            onDoubleTap: () => _toggleFullScreenMode(uid),
            child: Container(
              margin: EdgeInsets.all(2),
              decoration: BoxDecoration(
                color: Colors.black,
                border: Border.all(
                  color: (speakingUsers[uid] ?? 0) > 0 ? Colors.green : Colors.transparent,
                  width: 2,
                ),
              ),
              child: Stack(
                children: [
                  // Video view
                  Positioned.fill(
                    child: uid == 0
                        ? AgoraVideoView(
                      controller: VideoViewController(
                        rtcEngine: _engine,
                        canvas: const VideoCanvas(uid: 0),
                      ),
                    )
                        : AgoraVideoView(
                      controller: VideoViewController.remote(
                        rtcEngine: _engine,
                        canvas: VideoCanvas(uid: uid),
                        connection: RtcConnection(channelId: widget.callModel!.channelId!),
                      ),
                    ),
                  ),

                  // Video muted indicator
                  if ((uid == 0 && videoDisabled) || (uid != 0 && userInfo.videoMuted))
                    Positioned.fill(
                      child: Container(
                        color: Colors.black54,
                        child: Center(
                          child: CircleAvatar(
                            radius: 40,
                            backgroundImage: userInfo.photoUrl.isNotEmpty
                                ? NetworkImage(userInfo.photoUrl) as ImageProvider
                                : AssetImage('assets/default_avatar.png') as ImageProvider,
                          ),
                        ),
                      ),
                    ),

                  // User name and mute indicator
                  Positioned(
                    bottom: 8,
                    left: 8,
                    right: 8,
                    child: Container(
                      padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.black45,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if ((uid == 0 && muted) || (uid != 0 && userInfo.audioMuted))
                            Icon(Icons.mic_off, color: Colors.white, size: 16),
                          if ((uid == 0 && muted) || (uid != 0 && userInfo.audioMuted))
                            SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              userInfo.name,
                              style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  // Build a single full-screen video view
  Widget _buildSingleVideoView(int uid) {
    final userInfo = _users[uid]!;

    return GestureDetector(
      onTap: () {
        startControlsTimer();
      },
      onDoubleTap: () => _toggleFullScreenMode(uid),
      child: Stack(
        children: [
          // Video view
          Positioned.fill(
            child: uid == 0
                ? AgoraVideoView(
              controller: VideoViewController(
                rtcEngine: _engine,
                canvas: const VideoCanvas(uid: 0),
              ),
            )
                : AgoraVideoView(
              controller: VideoViewController.remote(
                rtcEngine: _engine,
                canvas: VideoCanvas(uid: uid),
                connection: RtcConnection(channelId: widget.callModel!.channelId!),
              ),
            ),
          ),

          // Video muted indicator
          if ((uid == 0 && videoDisabled) || (uid != 0 && userInfo.videoMuted))
            Positioned.fill(
              child: Container(
                color: Colors.black54,
                child: Center(
                  child: CircleAvatar(
                    radius: 80,
                    backgroundImage: userInfo.photoUrl.isNotEmpty
                        ? NetworkImage(userInfo.photoUrl) as ImageProvider
                        : AssetImage('assets/default_avatar.png') as ImageProvider,
                  ),
                ),
              ),
            ),

          // User info overlay
          Positioned(
            bottom: 20,
            left: 20,
            child: Container(
              padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.black45,
                borderRadius: BorderRadius.circular(24),
              ),
              child: Row(
                children: [
                  if ((uid == 0 && muted) || (uid != 0 && userInfo.audioMuted))
                    Icon(Icons.mic_off, color: Colors.white, size: 24),
                  if ((uid == 0 && muted) || (uid != 0 && userInfo.audioMuted))
                    SizedBox(width: 8),
                  Text(
                    userInfo.name,
                    style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18),
                  ),
                ],
              ),
            ),
          ),

          // Back button from fullscreen
          Positioned(
            top: 16,
            left: 16,
            child: AnimatedOpacity(
              opacity: showControls ? 1.0 : 0.0,
              duration: Duration(milliseconds: 300),
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.black45,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: IconButton(
                  icon: Icon(Icons.arrow_back, color: Colors.white),
                  onPressed: () {
                    setState(() {
                      isFullScreen = false;
                      fullScreenUid = null;
                    });
                    startControlsTimer();
                  },
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Participants panel
  Widget _buildParticipantsPanel() {
    return AnimatedOpacity(
      opacity: showControls ? 1.0 : 0.0,
      duration: Duration(milliseconds: 300),
      child: Positioned(
        top: 16,
        right: 16,
        child: Container(
          width: 160,
          padding: EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Colors.black45,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    "Participants (${_users.length})",
                    style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                  ),
                  IconButton(
                    icon: Icon(Icons.close, color: Colors.white, size: 16),
                    padding: EdgeInsets.all(0),
                    constraints: BoxConstraints(),
                    onPressed: () {
                      setState(() {
                        // Hide participants panel
                      });
                    },
                  )
                ],
              ),
              Divider(color: Colors.white30),
              ..._users.entries.map((entry) {
                final userInfo = entry.value;
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Row(
                    children: [
                      CircleAvatar(
                        radius: 12,
                        backgroundImage: userInfo.photoUrl.isNotEmpty
                            ? NetworkImage(userInfo.photoUrl) as ImageProvider
                            : AssetImage('assets/default_avatar.png') as ImageProvider,
                      ),
                      SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          userInfo.name,
                          style: TextStyle(color: Colors.white),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (userInfo.audioMuted)
                        Icon(Icons.mic_off, color: Colors.white, size: 16),
                    ],
                  ),
                );
              }).toList(),
            ],
          ),
        ),
      ),
    );
  }

  // Call information overlay
  Widget _buildCallInfo() {
    final callDuration = "00:00"; // Replace with actual call duration

    return AnimatedOpacity(
      opacity: showControls ? 1.0 : 0.0,
      duration: Duration(milliseconds: 300),
      child: Positioned(
        top: 16,
        left: 0,
        right: 0,
        child: Center(
          child: Container(
            padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.black45,
              borderRadius: BorderRadius.circular(24),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  widget.callModel?.callerName ?? "Group Call",
                  style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                ),
                SizedBox(width: 8),
                Container(
                  width: 4,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                  ),
                ),
                SizedBox(width: 8),
                Text(
                  callDuration,
                  style: TextStyle(color: Colors.white),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // Page indicator
  Widget _buildPageIndicator() {
    final totalPages = (_users.length / usersPerPage).ceil();

    return AnimatedOpacity(
      opacity: showControls && totalPages > 1 ? 1.0 : 0.0,
      duration: Duration(milliseconds: 300),
      child: Positioned(
        bottom: 80,
        left: 0,
        right: 0,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(totalPages, (index) {
            return Container(
              width: 8,
              height: 8,
              margin: EdgeInsets.symmetric(horizontal: 4),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: currentPage == index ? Colors.white : Colors.white30,
              ),
            );
          }),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: GestureDetector(
          onTap: () {
            startControlsTimer();
          },
          child: Stack(
            children: [
              // Main video grid
              _buildVideoGrid(),

              // Controls
              _buildControlBar(),

              // Call info at the top
              _buildCallInfo(),

              // Page indicator (if multiple pages)
              if (_users.length > usersPerPage)
                _buildPageIndicator(),

              // Waiting screen when no participants
              if (_users.isEmpty)
                Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      CircularProgressIndicator(color: Colors.white),
                      SizedBox(height: 16),
                      Text(
                        callStatus,
                        style: TextStyle(color: Colors.white, fontSize: 18),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

// Model class to store user information
class UserInfo {
  final int uid;
  final String name;
  final String photoUrl;
  final bool isLocal;
  bool audioMuted = false;
  bool videoMuted = false;

  UserInfo({
    required this.uid,
    required this.name,
    required this.photoUrl,
    required this.isLocal
  });
}

// Helper function to limit max value
int min(int a, int b) {
  return a < b ? a : b;
}