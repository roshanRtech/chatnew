import 'dart:async';
import 'dart:math';

import 'package:agora_rtc_engine/agora_rtc_engine.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:nb_utils/nb_utils.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

import 'package:chat/centralized_import.dart';


import '../../utils/TextStyles.dart' as TS;

class AgoraGroupVoiceCallScreen extends StatefulWidget {
  final CallModel? callModel;
  final bool isCaller;

  const AgoraGroupVoiceCallScreen({
    Key? key,
    required this.callModel, required this.isCaller,
  }) : super(key: key);

  @override
  State<AgoraGroupVoiceCallScreen> createState() =>
      _AgoraGroupVoiceCallScreenState();
}

class _AgoraGroupVoiceCallScreenState extends State<AgoraGroupVoiceCallScreen>
    with TickerProviderStateMixin {
  RtcEngine? _engine;
  final String appId = appSettingStore.agoraCallId!;
  bool _localAudioEnabled = true;
  List<int> _remoteUids = [];
  bool _joined = false;
  bool _engineInitialized = false;
  bool _controlsVisible = true;
  Timer? _controlsTimer;
  late AnimationController _controlsAnimationController;
  late Animation<double> _controlsAnimation;
  late AnimationController _pulseAnimationController;
  late Animation<double> _pulseAnimation;
  late AnimationController _waveAnimationController;
  late Animation<double> _waveAnimation;
  int? _localUid;
  bool _isLeaving = false;
  StreamSubscription<DocumentSnapshot>? _callStreamSubscription;
  late final RtcEngineEventHandler _rtcEngineEventHandler;
  bool _speakerOn = false;


  ChatMessageService chatMessageService = ChatMessageService();

  @override
  void initState() {
    super.initState();
    _initAnimations();
    _setupRtcEngineEventHandler();
    _initAgora();
    WakelockPlus.enable();
  }



  void _initAnimations() {
    _controlsAnimationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _controlsAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
          parent: _controlsAnimationController, curve: Curves.easeInOut),
    );
    _controlsAnimationController.forward();

    _pulseAnimationController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );
    _pulseAnimation = Tween<double>(begin: 0.8, end: 1.2).animate(
      CurvedAnimation(
          parent: _pulseAnimationController, curve: Curves.easeInOut),
    );
    _pulseAnimationController.repeat(reverse: true);

    _waveAnimationController = AnimationController(
      duration: const Duration(milliseconds: 2000),
      vsync: this,
    );
    _waveAnimation = Tween<double>(begin: 0.0, end: 2 * pi).animate(
      CurvedAnimation(parent: _waveAnimationController, curve: Curves.linear),
    );
    _waveAnimationController.repeat();
  }

  void _setupRtcEngineEventHandler() {
    _rtcEngineEventHandler = RtcEngineEventHandler(
      onJoinChannelSuccess: (RtcConnection connection, int elapsed) {
        debugPrint(
            "Local user ${connection.localUid} joined channel: ${connection.channelId}");
        setState(() {
          _joined = true;
          _localUid = connection.localUid;
        });

        addParticipantOnJoin();
      },
      onUserJoined: (RtcConnection connection, int remoteUid, int elapsed) {
        debugPrint("Remote user $remoteUid joined channel");
        setState(() {
          if (!_remoteUids.contains(remoteUid)) {
            _remoteUids = [..._remoteUids, remoteUid];
          }
        });
        //// TODO End Sound effect
        _engine?.stopEffect(RingingToneSoundId);
      },
      onUserOffline: (RtcConnection connection, int remoteUid,
          UserOfflineReasonType reason) {
        debugPrint("Remote user $remoteUid left channel, reason: $reason");
        setState(() {
          _remoteUids = _remoteUids.where((uid) => uid != remoteUid).toList();
        });
        if (_remoteUids.isEmpty && mounted && !_isLeaving) {
          _leaveChannel();
        }
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
          _localUid = null;
        });
      },
    );
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
      Map<Permission, PermissionStatus> statuses = await [
        Permission.microphone,
      ].request();

      if (statuses[Permission.microphone] != PermissionStatus.granted) {
        _showErrorDialog('Microphone permission is required');
        return;
      }

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

      // _startRinging();

      _engine!.registerEventHandler(_rtcEngineEventHandler);
      await _engine!.enableAudio();


      await _engine!.setParameters('{"che.audio.set.category":"AVAudioSessionCategoryPlayAndRecord"}');
      await _engine!
          .setParameters('{"che.audio.allow.background.playing":true}');
      await _engine!.setParameters('{"che.audio.enable.local.playback":true}');

      await _engine!.setAudioProfile(profile: AudioProfileType.audioProfileMusicHighQualityStereo, scenario: AudioScenarioType.audioScenarioChatroom);


      if (pathToRingingTone.isNotEmpty) {
        if (widget.isCaller) {
          print("Is called");
          await _engine!.preloadEffect(soundId: RingingToneSoundId, filePath: pathToRingingTone);
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

      int uid = DateTime.now().millisecondsSinceEpoch % 1000000;
      await _engine!.joinChannel(
        token: '',
        channelId: widget.callModel?.channelId ?? '',
        uid: uid,
        options: const ChannelMediaOptions(
          channelProfile: ChannelProfileType.channelProfileCommunication,
          clientRoleType: ClientRoleType.clientRoleBroadcaster,
          autoSubscribeAudio: true,
          publishMicrophoneTrack: true,
        ),
      );

      debugPrint(
          'Joined channel ${widget.callModel?.channelId} with UID: $uid');
    } catch (e) {
      debugPrint('Error initializing Agora: $e');
      _showErrorDialog('Failed to initialize voice call: $e');
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
                'lblError'.translate,
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
                  'lblOK'.translate,
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
    /// TODO stop sound effect
    _engine?.stopEffect(RingingToneSoundId);

    if (mounted) {
      Navigator.of(context, rootNavigator: true).pop();
    }

    await removeParticipantOnLeave();

    try {
      final List<Future<void>> cleanupFutures = [];

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

      cleanupFutures.add(Future.microtask(() {
        _controlsTimer?.cancel();
      }));

      await Future.wait<void>(cleanupFutures, eagerError: false);
    } catch (e) {
      debugPrint('Error in background cleanup: $e');
    } finally {
      _isLeaving = false;
      WakelockPlus.disable();
    }
  }

  Future<void> _cleanupEngine() async {
    await _engine?.leaveChannel();
    await _engine?.release();
  }

  void _toggleLocalAudio() {
    if (_engine == null) return;
    setState(() {
      _localAudioEnabled = !_localAudioEnabled;
    });
    _engine!.muteLocalAudioStream(!_localAudioEnabled);
    _showControls();
  }

  void _toggleSpeaker() {
    if (_engine == null) return;
    setState(() {
      _speakerOn = !_speakerOn;
    });
    _engine!.setEnableSpeakerphone(_speakerOn);
    _showControls();
  }

  Future<void> _showParticipantsDialog() async {
    if (widget.callModel?.channelId == null) return;
    final doc = await FirebaseFirestore.instance
        .collection('groupCall')
        .doc(widget.callModel!.channelId!)
        .get();
    List<String> participantIds =
        List<String>.from(doc.data()?['participants'] ?? []);
    if (participantIds.isEmpty) {
      toast("No participants joined yet");
      return;
    }
    showDialog(
      context: context,
      builder: (context) {
        return Dialog(
          backgroundColor: context.cardColor,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          child: FutureBuilder<List<UserModel>>(
            future: _fetchParticipantUsers(participantIds),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Padding(
                  padding: EdgeInsets.all(20),
                  child: Center(child: CircularProgressIndicator()),
                );
              }
              if (!snapshot.hasData || snapshot.data!.isEmpty) {
                return Padding(
                  padding: EdgeInsets.all(20),
                  child: Center(child: Text("noParticipantFound".translate)),
                );
              }
              final users = snapshot.data!;
              return Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Text(
                      'participants'.translate,
                      style: TS.boldTextStyle(
                        size: 18,
                        weight: FontWeight.bold,
                      ),
                    ),
                  ),
                  const Divider(height: 1),
                  Flexible(
                    child: ListView.builder(
                      shrinkWrap: true,
                      itemCount: users.length,
                      itemBuilder: (context, index) {
                        final user = users[index];
                        return Padding(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 10),
                          child: Text(
                            user.name!,
                            style: TS.boldTextStyle(size: 16),
                          ),
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 12),
                ],
              );
            },
          ),
        );
      },
    );
  }

  Future<List<UserModel>> _fetchParticipantUsers(List<String> ids) async {
    List<UserModel> users = [];
    for (String id in ids) {
      try {
        final user = await chatMessageService.getUserById(uid: id);
        users.add(user);
      } catch (e) {
        debugPrint("Error fetching user $id: $e");
      }
    }
    return users;
  }

  Widget _buildGradientBackground() {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Color(0xFF075E54), // primaryColor
            Color(0xFF128C7E), // secondaryColor
            Color(0xFF075E54), // primaryColor
          ],
          stops: [0.0, 0.5, 1.0],
        ),
      ),
    );
  }

  Widget _buildAnimatedWaves() {
    return AnimatedBuilder(
      animation: _waveAnimation,
      builder: (context, child) {
        return CustomPaint(
          painter: WavePainter(_waveAnimation.value, _localAudioEnabled),
          size: Size.infinite,
        );
      },
    );
  }

  Widget _buildMainCallInterface() {
    final participantCount = _remoteUids.length + (_joined ? 1 : 0);

    return Column(
      children: [
        // Top status bar
        _buildTopStatusBar(),

        // Main call content
        Expanded(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Central call info
              _buildCentralCallInfo(),

              const SizedBox(height: 60),

              if (participantCount <= 1) _buildWaitingIndicator(),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildTopStatusBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Call duration
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: const Color(0xFF1E1E1E)
                  .withOpacity(0.8), // scaffoldSecondaryDark
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                  color: const Color(0xFF25D366).withOpacity(0.3)), // chatColor
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: _joined
                        ? const Color(0xFF25D366)
                        : const Color(0xFFFFC800), // chatColor : yellowColor
                    shape: BoxShape.circle,
                  ),
                ),
              ],
            ),
          ),

          // Participants count - clickable
          GestureDetector(
            onTap: _showParticipantsDialog,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: const Color(0xFF1E1E1E)
                    .withOpacity(0.8), // scaffoldSecondaryDark
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                    color:
                        const Color(0xFF25D366).withOpacity(0.3)), // chatColor
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.people_outline,
                    color: Colors.white,
                    size: 16,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    '${_remoteUids.length + (_joined ? 1 : 0)}',
                    style: TS.boldTextStyle(
                      color: Colors.white,
                      weight: FontWeight.w500,
                      size: 14,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCentralCallInfo() {
    return Column(
      children: [
        Stack(
          alignment: Alignment.center,
          children: [
            // Pulsing rings
            AnimatedBuilder(
              animation: _pulseAnimation,
              builder: (context, child) {
                return Transform.scale(
                  scale: _pulseAnimation.value,
                  child: Container(
                    width: 200,
                    height: 200,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: Colors.white.withOpacity(0.3),
                        width: 2,
                      ),
                    ),
                  ),
                );
              },
            ),

            // Main avatar
            Container(
              width: 160,
              height: 160,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: const LinearGradient(
                  colors: [
                    Color(0xFF1E1E1E),
                    Color(0xFF282828)
                  ], // scaffoldSecondaryDark, appButtonColorDark
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                border: Border.all(
                    color: const Color(0xFF25D366).withOpacity(0.5),
                    width: 3), // chatColor
                boxShadow: [
                  BoxShadow(
                    color:
                        const Color(0xFF25D366).withOpacity(0.3), // chatColor
                    blurRadius: 20,
                    spreadRadius: 5,
                  ),
                ],
              ),
              child: const Icon(
                Icons.group,
                color: Colors.white,
                size: 80,
              ),
            ),

            // Audio indicator
            if (_localAudioEnabled)
              Positioned(
                bottom: 10,
                right: 10,
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFF25D366), // chatColor
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 2),
                  ),
                  child: const Icon(
                    Icons.mic,
                    color: Colors.white,
                    size: 16,
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 24),
        // Caller name
        Text(
          widget.callModel?.receiverName ?? 'groupCall'.translate,
          style: TS.boldTextStyle(
            color: Colors.white,
            weight: FontWeight.bold,
            size: 24,
          ),
        ),
        const SizedBox(height: 8),

        // Call status
        Text(
          _joined ? 'connected'.translate : 'lblConnecting'.translate,
          style: TS.secondaryTextStyle(
            color: const Color(0xFF25D366), // chatColor
            size: 16,
          ),
        ),
      ],
    );
  }

  Widget _buildWaitingIndicator() {
    return Column(
      children: [
        Text(
          'waitingForOthersToJoin'.translate,
          style: TS.boldTextStyle(
            color: const Color(0xFF25D366), // chatColor
            weight: FontWeight.w500,
            size: 16,
          ),
        ),
        const SizedBox(height: 20),
        const SizedBox(
          width: 20,
          height: 20,
          child: CircularProgressIndicator(
            strokeWidth: 2,
            valueColor:
                AlwaysStoppedAnimation<Color>(Color(0xFF25D366)), // chatColor
          ),
        ),
      ],
    );
  }

  Future<void> addParticipantOnJoin() async {
    final uid = getStringAsync(userId);
    if (uid.isNotEmpty && widget.callModel?.channelId != null) {
      await FirebaseFirestore.instance
          .collection('groupCall')
          .doc(widget.callModel!.channelId!)
          .update({
        'participants': FieldValue.arrayUnion([uid]),
      });
    }
  }

  Future<void> removeParticipantOnLeave() async {
    final uid = getStringAsync(userId);
    if (uid.isNotEmpty && widget.callModel?.channelId != null) {
      await FirebaseFirestore.instance
          .collection('groupCall')
          .doc(widget.callModel!.channelId!)
          .update({
        'participants': FieldValue.arrayRemove([uid]),
      });
    }
  }

  Widget _buildBottomControls() {
    return Container(
      margin: const EdgeInsets.only(bottom: 40),
      padding: const EdgeInsets.symmetric(horizontal: 40),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _buildControlButton(
            icon: _localAudioEnabled ? Icons.mic : Icons.mic_off,
            onPressed: _toggleLocalAudio,
            isActive: _localAudioEnabled,
            activeColor: const Color(0xFF25D366).withOpacity(0.8), // chatColor
            inactiveColor: Colors.red.withOpacity(0.8),
          ),
          _buildControlButton(
            icon: _speakerOn ? Icons.volume_up : Icons.volume_down,
            onPressed: _toggleSpeaker,
            isActive: _speakerOn,
            activeColor:
                const Color(0xFF128C7E).withOpacity(0.8), // secondaryColor
            inactiveColor:
                const Color(0xFF757575).withOpacity(0.8), // grayColor
          ),
          _buildControlButton(
            icon: Icons.call_end,
            onPressed: _leaveChannel,
            isActive: false,
            isEndCall: true,
            size: 70,
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
    Color? activeColor,
    Color? inactiveColor,
  }) {
    Color backgroundColor;
    if (isEndCall) {
      backgroundColor = Colors.red.shade600;
    } else if (isActive) {
      backgroundColor = activeColor ?? Colors.white.withOpacity(0.2);
    } else {
      backgroundColor = inactiveColor ?? Colors.red.withOpacity(0.8);
    }

    return GestureDetector(
      onTap: onPressed,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: backgroundColor,
          shape: BoxShape.circle,
          border: Border.all(
            color: const Color(0xFF25D366).withOpacity(0.5), // chatColor
            width: 2,
          ),
          boxShadow: [
            BoxShadow(
              color: isEndCall
                  ? Colors.red.withOpacity(0.5)
                  : Colors.black.withOpacity(0.3),
              blurRadius: 15,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Icon(
          icon,
          color: Colors.white,
          size: size * 0.4,
        ),
      ),
    );
  }

  @override
  void dispose() {
    _controlsAnimationController.dispose();
    _pulseAnimationController.dispose();
    _waveAnimationController.dispose();
    _controlsTimer?.cancel();
    _callStreamSubscription?.cancel();
    _engine?.stopEffect(RingingToneSoundId);
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
                    // Background gradient
                    _buildGradientBackground(),

                    // Animated waves
                    _buildAnimatedWaves(),

                    // Main interface
                    _buildMainCallInterface(),

                    // Controls overlay
                    AnimatedBuilder(
                      animation: _controlsAnimation,
                      builder: (context, child) {
                        return Opacity(
                          opacity: _controlsAnimation.value,
                          child: Align(
                            alignment: Alignment.bottomCenter,
                            child: _buildBottomControls(),
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
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Color(0xFF075E54), // primaryColor
            Color(0xFF128C7E), // secondaryColor
          ],
        ),
      ),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(
              valueColor:
                  AlwaysStoppedAnimation<Color>(Color(0xFF25D366)), // chatColor
              strokeWidth: 3,
            ),
            SizedBox(height: 24),
            Text(
              'initializingCall'.translate,
              style: TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// Custom painter for animated waves
class WavePainter extends CustomPainter {
  final double animationValue;
  final bool isActive;

  WavePainter(this.animationValue, this.isActive);

  @override
  void paint(Canvas canvas, Size size) {
    if (!isActive) return;

    final paint = Paint()
      ..color = const Color(0xFF25D366).withOpacity(0.2) // chatColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;

    final center = Offset(size.width / 2, size.height / 2);

    for (int i = 0; i < 3; i++) {
      final radius = (50 + i * 30) * (1 + sin(animationValue + i * 0.5) * 0.3);
      canvas.drawCircle(center, radius, paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
