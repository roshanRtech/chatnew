import 'dart:async';

import 'package:agora_rtc_engine/agora_rtc_engine.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:nb_utils/nb_utils.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

import 'package:chat/centralized_import.dart';

import '../../utils/TextStyles.dart' as TS;

class AgoraGroupVideoCallScreen extends StatefulWidget {
  final CallModel? callModel;
  final bool isCaller;

  const AgoraGroupVideoCallScreen({
    Key? key,
    required this.callModel,
    required this.isCaller,
  }) : super(key: key);

  @override
  State<AgoraGroupVideoCallScreen> createState() =>
      _AgoraGroupVideoCallScreenState();
}

class _AgoraGroupVideoCallScreenState extends State<AgoraGroupVideoCallScreen>
    with TickerProviderStateMixin {
  RtcEngine? _engine;
  final String appId = appSettingStore.agoraCallId!;
  bool _localVideoEnabled = true;
  bool _localAudioEnabled = true;
  List<int> _remoteUids = [];
  Map<int, RemoteVideoState> _remoteVideoStates = {};
  bool _joined = false;
  bool _engineInitialized = false;
  Timer? _callTimer;
  bool _controlsVisible = true;
  Timer? _controlsTimer;
  late AnimationController _controlsAnimationController;
  late Animation<double> _controlsAnimation;
  int? _localUid;
  bool _isLeaving = false;
  StreamSubscription<DocumentSnapshot>? _callStreamSubscription;
  late final RtcEngineEventHandler _rtcEngineEventHandler;

  @override
  void initState() {
    super.initState();
    _controlsAnimationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _controlsAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
          parent: _controlsAnimationController, curve: Curves.easeInOut),
    );
    _controlsAnimationController.forward();
    _rtcEngineEventHandler = RtcEngineEventHandler(
      onJoinChannelSuccess: (RtcConnection connection, int elapsed) {
        debugPrint(
            "Local user ${connection.localUid} joined channel: ${connection.channelId}");
        setState(() {
          _joined = true;
          _localUid = connection.localUid;
        });
      },
      onUserJoined: (RtcConnection connection, int remoteUid, int elapsed) {
        debugPrint("Remote user $remoteUid joined channel");
        setState(() {
          if (!_remoteUids.contains(remoteUid)) {
            _remoteUids = [..._remoteUids, remoteUid];
            _remoteVideoStates[remoteUid] =
                RemoteVideoState.remoteVideoStateStopped;
          }
        });
        _engine?.stopEffect(RingingToneSoundId);
      },
      onUserOffline: (RtcConnection connection, int remoteUid,
          UserOfflineReasonType reason) {
        debugPrint("Remote user $remoteUid left channel, reason: $reason");
        setState(() {
          _remoteUids = _remoteUids.where((uid) => uid != remoteUid).toList();
          _remoteVideoStates.remove(remoteUid);
        });
        if (_remoteUids.isEmpty && mounted && !_isLeaving) {
          _leaveChannel();
        }
      },
      onRemoteVideoStateChanged: (
        RtcConnection connection,
        int remoteUid,
        RemoteVideoState state,
        RemoteVideoStateReason reason,
        int elapsed,
      ) {
        debugPrint(
            "Remote video state changed for $remoteUid: $state, reason: $reason");
        setState(() {
          _remoteVideoStates[remoteUid] = state;
        });
      },
      onRemoteAudioStateChanged: (
        RtcConnection connection,
        int remoteUid,
        RemoteAudioState state,
        RemoteAudioStateReason reason,
        int elapsed,
      ) {
        debugPrint(
            "Remote audio state changed for $remoteUid: $state, reason: $reason");
      },
      onError: (ErrorCodeType err, String msg) {
        debugPrint('Agora error: $err, $msg');
        _showErrorDialog('Error: $msg');
      },
      onLeaveChannel: (RtcConnection connection, RtcStats stats) {
        debugPrint('Left channel');
        setState(() {
          _joined = false;
          _remoteUids = [];
          _remoteVideoStates = {};
          _localUid = null;
        });
      },
    );
    _initAgora();
    WakelockPlus.enable();
  }

  void _startControlsTimer() {
    _controlsTimer?.cancel();
    _controlsTimer = Timer(const Duration(seconds: 5), () {
      if (mounted) {
        setState(() {
          _controlsVisible = false;
        });
        _controlsAnimationController.reverse();
      }
    });
  }

  void _showControls() {
    if (!_controlsVisible) {
      setState(() {
        _controlsVisible = true;
      });
      _controlsAnimationController.forward();
    }
    _startControlsTimer();
  }

  Future<void> _initAgora() async {
    try {
// Request permissions
      Map<Permission, PermissionStatus> statuses = await [
        Permission.microphone,
        Permission.camera,
      ].request();

      if (statuses[Permission.microphone] != PermissionStatus.granted ||
          statuses[Permission.camera] != PermissionStatus.granted) {
        _showErrorDialog('Camera and microphone permissions are required');
        return;
      }

// Initialize Agora engine
      _engine = createAgoraRtcEngine();
      await _engine!.initialize(
        RtcEngineContext(
          appId: appId,
          channelProfile: ChannelProfileType.channelProfileCommunication,
        ),
      );

      setState(() {
        _engineInitialized = true;
      });

// Register event handlers
      _engine!.registerEventHandler(_rtcEngineEventHandler);

// Enable video and audio
      await _engine!.enableVideo();
      await _engine!.enableAudio();

      await _engine!.setParameters(
          '{"che.audio.set.category":"AVAudioSessionCategoryPlayAndRecord"}');
      await _engine!
          .setParameters('{"che.audio.allow.background.playing":true}');
      await _engine!.setParameters('{"che.audio.enable.local.playback":true}');

      await _engine!.setAudioProfile(
          profile: AudioProfileType.audioProfileMusicHighQualityStereo,
          scenario: AudioScenarioType.audioScenarioChatroom);

// Set video encoder configuration (optimized for group calls)
      await _engine!.setVideoEncoderConfiguration(
        const VideoEncoderConfiguration(
          dimensions: VideoDimensions(width: 480, height: 360),
          frameRate: 15,
          bitrate: 300,
        ),
      );

// Enable local video preview
      await _engine!.startPreview();

      if (pathToRingingTone.isNotEmpty) {
        if (widget.isCaller) {
          await _engine!.preloadEffect(
              soundId: RingingToneSoundId, filePath: pathToRingingTone);
          await _engine!.playEffect(
            soundId: RingingToneSoundId,
            filePath: pathToRingingTone,
            loopCount: -1,
            pitch: 1,
            gain: 100,
            publish: false,
            pan: 1,
          );
        }
      }

// Join channel with a unique UID
      int uid = DateTime.now().millisecondsSinceEpoch % 1000000;
      await _engine!.joinChannel(
        token: '',
        channelId: widget.callModel?.channelId ?? '',
        uid: uid,
        options: const ChannelMediaOptions(
          channelProfile: ChannelProfileType.channelProfileCommunication,
          clientRoleType: ClientRoleType.clientRoleBroadcaster,
          autoSubscribeAudio: true,
          autoSubscribeVideo: true,
          publishCameraTrack: true,
          publishMicrophoneTrack: true,
        ),
      );

      debugPrint(
          'Joined channel ${widget.callModel?.channelId} with UID: $uid');
    } catch (e) {
      debugPrint('Error initializing Agora: $e');
      _showErrorDialog('Failed to initialize video call: $e');
    }
  }

  void _showErrorDialog(String message) {
    if (!mounted) return;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            gradient: const LinearGradient(
              colors: [Color(0xFFFF6B6B), Color(0xFFFF8E53)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline, size: 48, color: Colors.white),
              const SizedBox(height: 16),
              Text(
                'Error',
                style: TS.boldTextStyle(
                  weight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                message,
                style: TS.secondaryTextStyle(
                  color: Colors.white,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: () {
                  Navigator.of(context).pop();
                  _leaveChannel();
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: const Color(0xFFFF6B6B),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                ),
                child: Text(
                  'OK',
                  style: TS.boldTextStyle(weight: FontWeight.bold),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _leaveChannel() async {
    if (_isLeaving) return;
    _isLeaving = true;

    _engine?.stopEffect(RingingToneSoundId);

    // Navigate immediately for better UX
    if (mounted) {
      Navigator.of(context, rootNavigator: true).pop();
    }

    try {
      // Create a list of futures with explicit typing
      final List<Future<void>> cleanupFutures = [];

      // Add futures to the list
      if (widget.callModel != null) {
        cleanupFutures.add(callService
            .endGroupCall(userId: getStringAsync(userId))
            .catchError((e) => debugPrint('Error ending call: $e')));
      }

      if (_callStreamSubscription != null) {
        cleanupFutures.add(_callStreamSubscription!
            .cancel()
            .catchError((e) => debugPrint('Error canceling stream: $e')));
      }

      cleanupFutures.add(_cleanupEngine()
          .catchError((e) => debugPrint('Error cleaning engine: $e')));

      // Add timer cancellation as a microtask
      cleanupFutures.add(Future.microtask(() {
        _callTimer?.cancel();
        _controlsTimer?.cancel();
      }));

      // Wait for all cleanup operations with explicit type
      await Future.wait<void>(cleanupFutures, eagerError: false);
    } catch (e) {
      debugPrint('Error in background cleanup: $e');
    } finally {
      _isLeaving = false;
      WakelockPlus.disable();
    }
  }

  Future<void> _cleanupEngine() async {
    await _engine?.stopPreview();
    await _engine?.leaveChannel();
    await _engine?.release();
  }

  void _toggleLocalVideo() {
    if (_engine == null) return;
    setState(() {
      _localVideoEnabled = !_localVideoEnabled;
    });
    _engine!.muteLocalVideoStream(!_localVideoEnabled);
    if (_localVideoEnabled) {
      _engine!.startPreview();
    } else {
      _engine!.stopPreview();
    }
    _showControls();
  }

  void _toggleLocalAudio() {
    if (_engine == null) return;
    setState(() {
      _localAudioEnabled = !_localAudioEnabled;
    });
    _engine!.muteLocalAudioStream(!_localAudioEnabled);
    _showControls();
  }

  void _switchCamera() {
    if (_engine == null) return;
    _engine!.switchCamera();
    _showControls();
  }

  Widget _buildBottomControls() {
    return Container(
      margin: const EdgeInsets.only(bottom: 40),
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _buildControlButton(
            icon: _localVideoEnabled
                ? Icons.videocam_rounded
                : Icons.videocam_off_rounded,
            onPressed: _toggleLocalVideo,
            isActive: _localVideoEnabled,
            size: 56,
          ),
          _buildControlButton(
            icon:
                _localAudioEnabled ? Icons.mic_rounded : Icons.mic_off_rounded,
            onPressed: _toggleLocalAudio,
            isActive: _localAudioEnabled,
            size: 56,
          ),
          _buildControlButton(
            icon: Icons.flip_camera_ios_rounded,
            onPressed: _switchCamera,
            isActive: true,
            size: 56,
          ),
          _buildControlButton(
            icon: Icons.call_end_rounded,
            onPressed: _leaveChannel,
            isActive: false,
            isEndCall: true,
            size: 64,
          ),
        ],
      ),
    );
  }

  Widget _buildControlButton({
    required IconData icon,
    required VoidCallback onPressed,
    required bool isActive,
    bool isEndCall = false,
    double size = 56,
  }) {
    return GestureDetector(
      onTap: onPressed,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: size,
        height: size,
        decoration: BoxDecoration(
          gradient: isEndCall
              ? const LinearGradient(
                  colors: [Color(0xFFFF6B6B), Color(0xFFFF5252)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                )
              : isActive
                  ? LinearGradient(
                      colors: [
                        Colors.white.withOpacity(0.2),
                        Colors.white.withOpacity(0.1),
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    )
                  : LinearGradient(
                      colors: [
                        Colors.red.withOpacity(0.8),
                        Colors.red.withOpacity(0.6),
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: isEndCall
                  ? Colors.red.withOpacity(0.4)
                  : Colors.black.withOpacity(0.3),
              blurRadius: 15,
              offset: const Offset(0, 8),
            ),
          ],
          border: Border.all(
            color: Colors.white.withOpacity(0.2),
            width: 1,
          ),
        ),
        child: Icon(
          icon,
          color: Colors.white,
          size: size * 0.45,
        ),
      ),
    );
  }

  Widget _buildTopBar() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Colors.black.withOpacity(0.8),
            Colors.transparent,
          ],
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                widget.callModel!.receiverName!,
                style: TS.boldTextStyle(
                  color: Colors.white,
                  weight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
            ],
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Text(
              '${'lblParticipants'.translate}: ${_remoteUids.length + (_joined ? 1 : 0)}',
              style: TS.boldTextStyle(
                color: Colors.white,
                weight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildVideoWidget(int uid, bool isLocal) {
    final isVideoEnabled = isLocal
        ? _localVideoEnabled
        : (_remoteVideoStates[uid] ==
            RemoteVideoState.remoteVideoStateDecoding);

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.3),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Stack(
          children: [
            isVideoEnabled && _engine != null
                ? AgoraVideoView(
                    controller: isLocal
                        ? VideoViewController(
                            rtcEngine: _engine!,
                            canvas: const VideoCanvas(uid: 0),
                          )
                        : VideoViewController.remote(
                            rtcEngine: _engine!,
                            connection: RtcConnection(
                                channelId: widget.callModel?.channelId ?? ''),
                            canvas: VideoCanvas(uid: uid),
                          ),
                  )
                : Container(
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        colors: [Color(0xFF4A5568), Color(0xFF2D3748)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                    ),
                    child: const Center(
                      child: Icon(
                        Icons.videocam_off_rounded,
                        color: Colors.white,
                        size: 32,
                      ),
                    ),
                  ),
            // Positioned(
            //   bottom: 8,
            //   left: 8,
            //   child: isLocal
            //       ? Container(
            //     padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            //     decoration: BoxDecoration(
            //       color: Colors.black.withOpacity(0.6),
            //       borderRadius: BorderRadius.circular(10),
            //     ),
            //     child: Text(
            //       loginStore.mDisplayName.validate(),
            //       style:TS.boldTextStyle(
            //         color: Colors.white,
            //         weight: FontWeight.w500,
            //       ),
            //     ),
            //   )
            //       : FutureBuilder<UserModel>(
            //     future: UserService().getUserById(val: widget.callModel!.receiverId!),
            //     builder: (context, snapshot) {
            //       if (snapshot.connectionState == ConnectionState.waiting) {
            //         return Container(
            //           padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            //           decoration: BoxDecoration(
            //             color: Colors.black.withOpacity(0.6),
            //             borderRadius: BorderRadius.circular(10),
            //           ),
            //           child:SizedBox(),
            //         );
            //       }
            //
            //       if (snapshot.hasError || !snapshot.hasData) {
            //         return Container(
            //           padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            //           decoration: BoxDecoration(
            //             color: Colors.black.withOpacity(0.6),
            //             borderRadius: BorderRadius.circular(10),
            //           ),
            //           child: SizedBox(),
            //         );
            //       }
            //
            //       return Container(
            //         padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            //         decoration: BoxDecoration(
            //           color: Colors.black.withOpacity(0.6),
            //           borderRadius: BorderRadius.circular(10),
            //         ),
            //         child: Text(
            //           snapshot.data!.name ?? 'User',
            //           style: TS.boldTextStyle(
            //             color: Colors.white,
            //             weight: FontWeight.w500,
            //           ),
            //         ),
            //       );
            //     },
            //   ),
            // )
          ],
        ),
      ),
    );
  }

  Widget _buildVideoGrid() {
    if (!_joined || _engine == null) {
      return Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color(0xFF2D3748),
              Color(0xFF1A202C),
            ],
          ),
        ),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(32),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white.withOpacity(0.1),
                ),
                child: const Icon(
                  Icons.person_outline,
                  size: 80,
                  color: Colors.white54,
                ),
              ),
              const SizedBox(height: 32),
              Text(
                'Waiting for others to join...',
                style: TS.boldTextStyle(
                  color: Colors.white,
                  weight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 16),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(20),
                  color: _joined
                      ? Colors.green.withOpacity(0.2)
                      : Colors.orange.withOpacity(0.2),
                ),
                child: Text(
                  _joined ? 'Connected to channel' : 'Connecting...',
                  style: TS.secondaryTextStyle(
                    color: _joined
                        ? Colors.green.shade300
                        : Colors.orange.shade300,
                    weight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }

// Combine local and remote UIDs
    final allUids = [
      if (_joined && _localUid != null)
        _localUid!, // Include local UID if joined
      ..._remoteUids,
    ];

    if (allUids.isEmpty) {
      return Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color(0xFF2D3748),
              Color(0xFF1A202C),
            ],
          ),
        ),
        child: Center(
          child: Text(
            'No active video streams',
            style: TS.boldTextStyle(
              color: Colors.white70,
              weight: FontWeight.w500,
            ),
          ),
        ),
      );
    }

// Build layout based on number of participants
    Widget videoLayout;
    switch (allUids.length) {
      case 1:
// Single participant: Full screen
        videoLayout = _buildVideoWidget(allUids[0], allUids[0] == _localUid);
        break;
      case 2:
// Two participants: Top and bottom
        videoLayout = Column(
          children: [
            Expanded(
              child: _buildVideoWidget(allUids[0], allUids[0] == _localUid),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: _buildVideoWidget(allUids[1], allUids[1] == _localUid),
            ),
          ],
        );
        break;
      case 3:
// Three participants: Two on top, one below
        videoLayout = Column(
          children: [
            Expanded(
              child: Row(
                children: [
                  Expanded(
                    child:
                        _buildVideoWidget(allUids[0], allUids[0] == _localUid),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child:
                        _buildVideoWidget(allUids[1], allUids[1] == _localUid),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: _buildVideoWidget(allUids[2], allUids[2] == _localUid),
            ),
          ],
        );
        break;
      case 4:
// Four participants: 2x2 grid
        videoLayout = Column(
          children: [
            Expanded(
              child: Row(
                children: [
                  Expanded(
                    child:
                        _buildVideoWidget(allUids[0], allUids[0] == _localUid),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child:
                        _buildVideoWidget(allUids[1], allUids[1] == _localUid),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: Row(
                children: [
                  Expanded(
                    child:
                        _buildVideoWidget(allUids[2], allUids[2] == _localUid),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child:
                        _buildVideoWidget(allUids[3], allUids[3] == _localUid),
                  ),
                ],
              ),
            ),
          ],
        );
        break;
      case 5:
// Five participants: Two rows of two, one below
        videoLayout = Column(
          children: [
            Expanded(
              flex: 2, // Give more space to rows to balance with single video
              child: Row(
                children: [
                  Expanded(
                    child:
                        _buildVideoWidget(allUids[0], allUids[0] == _localUid),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child:
                        _buildVideoWidget(allUids[1], allUids[1] == _localUid),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            Expanded(
              flex: 2,
              child: Row(
                children: [
                  Expanded(
                    child:
                        _buildVideoWidget(allUids[2], allUids[2] == _localUid),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child:
                        _buildVideoWidget(allUids[3], allUids[3] == _localUid),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            Expanded(
              flex: 1, // Smaller space for the single video
              child: _buildVideoWidget(allUids[4], allUids[4] == _localUid),
            ),
          ],
        );
        break;
      default:
// Fallback for more than 5 participants (same as 4 for simplicity)
        videoLayout = Column(
          children: [
            Expanded(
              child: Row(
                children: [
                  Expanded(
                    child:
                        _buildVideoWidget(allUids[0], allUids[0] == _localUid),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: allUids.length > 1
                        ? _buildVideoWidget(allUids[1], allUids[1] == _localUid)
                        : Container(),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: Row(
                children: [
                  Expanded(
                    child: allUids.length > 2
                        ? _buildVideoWidget(allUids[2], allUids[2] == _localUid)
                        : Container(),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: allUids.length > 3
                        ? _buildVideoWidget(allUids[3], allUids[3] == _localUid)
                        : Container(),
                  ),
                ],
              ),
            ),
          ],
        );
    }

    return Padding(
      padding: const EdgeInsets.all(8.0),
      child: videoLayout,
    );
  }

  @override
  void dispose() {
    _controlsAnimationController.dispose();
    _callTimer?.cancel();
    _controlsTimer?.cancel();
    _engine?.stopEffect(RingingToneSoundId);
    _callStreamSubscription?.cancel();
    if (_engine != null) {
      _engine!.unregisterEventHandler(_rtcEngineEventHandler);
      _engine!.leaveChannel();
      _engine!.release();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: GestureDetector(
          onTap: _showControls,
          child: _engineInitialized
              ? Stack(
                  children: [
                    _buildVideoGrid(),
                    AnimatedBuilder(
                      animation: _controlsAnimation,
                      builder: (context, child) {
                        return Opacity(
                          opacity: _controlsAnimation.value,
                          child: Column(
                            children: [
                              _buildTopBar(),
                              const Spacer(),
                              _buildBottomControls(),
                            ],
                          ),
                        );
                      },
                    ),
                  ],
                )
              : _buildLoadingScreen(),
        ),
      ),
    );
  }

  Widget _buildLoadingScreen() {
    return Container(
      color: Colors.black,
      child: const Center(
        child: CircularProgressIndicator(
          valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
          strokeWidth: 3,
        ),
      ),
    );
  }
}
