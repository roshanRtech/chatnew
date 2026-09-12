import 'dart:async';
import 'package:agora_rtc_engine/agora_rtc_engine.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_vector_icons/flutter_vector_icons.dart';
import 'package:nb_utils/nb_utils.dart';
import 'package:chat/centralized_import.dart';


// ignore: must_be_immutable
class AgoraVoiceCallScreen extends StatefulWidget {
  final CallModel? callModel;
  final bool isCaller;

  const AgoraVoiceCallScreen({this.callModel, required this.isCaller});

  @override
  State<StatefulWidget> createState() => _State();
}

class _State extends State<AgoraVoiceCallScreen> with TickerProviderStateMixin {
  bool isJoined = false;
  bool openMicrophone = false;
  bool enableSpeakerphone = false;
  String callStatus = 'calling...';
  RtcEngine? _engine;

  final _infoStrings = <String>[];
  final _users = <int>[];
  late final RtcEngineEventHandler _rtcEngineEventHandler;

  // Animation controllers for better UI
  late AnimationController _pulseController;
  late AnimationController _fadeController;
  late Animation<double> _pulseAnimation;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _initAnimations();
    init();
  }

  void _initAnimations() {
    _pulseController = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    );
    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );

    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.1).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _fadeController, curve: Curves.easeIn),
    );

    _pulseController.repeat(reverse: true);
    _fadeController.forward();
  }

  late StreamSubscription callStreamSubcription;
  init() async {
    addPostFrameCallBack();
    initialize();
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _fadeController.dispose();
    _engine?.stopEffect(RingingToneSoundId);
    super.dispose();
    _dispose();
  }

  Future<void> _dispose() async {
    _users.clear();
    _engine?.unregisterEventHandler(_rtcEngineEventHandler);
    await _engine?.leaveChannel();
    await _engine?.release();
    callStreamSubcription.cancel();
  }

  Future<void> initialize() async {
    if (appSettingStore.agoraCallId.isEmptyOrNull) {
      setState(() {
        _infoStrings.add(
            'videoAppId missing, please provide your videoAppId in settings.dart');
        _infoStrings.add('Agora Engine is not starting');
      });
      return;
    }

    await _initAgoraRtcEngine();
  }

  Future<void> _initAgoraRtcEngine() async {
    _engine = createAgoraRtcEngine();
    await _engine?.initialize(RtcEngineContext(
      appId: appSettingStore.agoraCallId,
      channelProfile: ChannelProfileType.channelProfileLiveBroadcasting,
    ));
    await _engine?.joinChannel(
      token: "", // TODO: need to pass token as currently not available
      channelId: widget.callModel!.channelId!,
      uid: 0,
      options: const ChannelMediaOptions(),
    );
    _rtcEngineEventHandler = RtcEngineEventHandler(
      onJoinChannelSuccess: (RtcConnection connection, int elapsed) {
        setState(() {
          final info =
              'onJoinChannel: ${connection.toJson()}, elapsed: $elapsed';
          _infoStrings.add(info);
          isJoined = true;
        });
      },
      onUserJoined: (RtcConnection connection, int remoteUid, int elapsed) {
        setState(() {
          final info = 'userJoined: $remoteUid';
          _infoStrings.add(info);
          callStatus = 'Connected';
          _users.add(remoteUid);
        });

        _engine?.stopEffect(RingingToneSoundId);
      },
      onError: (ErrorCodeType err, String msg) {
        debugPrint('[onError] err: $err, msg: $msg');
      },
      onUserOffline: (RtcConnection connection, int remoteUid,
          UserOfflineReasonType reason) {
        callService.endCall(callModel: widget.callModel!);
        setState(() {
          final info = 'userOffline: $remoteUid';
          _infoStrings.add(info);
          _users.remove(remoteUid);
        });
      },
      onLeaveChannel: (RtcConnection connection, RtcStats stats) {
        setState(() {
          _infoStrings.add('onLeaveChannel');
          _users.clear();
        });
      },
      onTokenPrivilegeWillExpire: (RtcConnection connection, String token) {
        debugPrint(
            '[onTokenPrivilegeWillExpire] connection: ${connection.toJson()}, token: $token');
      },
    );
    _engine?.registerEventHandler(_rtcEngineEventHandler);

    await _engine?.setClientRole(role: ClientRoleType.clientRoleBroadcaster);
    await _engine?.enableVideo();
    await _engine?.startPreview();

    await _engine!.setParameters(
        '{"che.audio.set.category":"AVAudioSessionCategoryPlayAndRecord"}');
    await _engine!.setParameters('{"che.audio.allow.background.playing":true}');
    await _engine!.setParameters('{"che.audio.enable.local.playback":true}');

    await _engine!.setAudioProfile(profile: AudioProfileType.audioProfileMusicHighQualityStereo, scenario: AudioScenarioType.audioScenarioChatroom);

    if (pathToRingingTone.isNotEmpty) {
      if (widget.isCaller) {
        print("Is called");
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
  }

  void addPostFrameCallBack() {
    SchedulerBinding.instance.addPostFrameCallback((_) {
      callStreamSubcription = callService
          .callStream(uid: getStringAsync(userId))
          .listen((DocumentSnapshot ds) {
        switch (ds.data()) {
          case null:
            Navigator.pop(context);
            break;
          default:
            break;
        }
      });
    });
  }

  _switchMicrophone() {
    _engine?.enableLocalAudio(!openMicrophone).then((value) {
      setState(() {
        openMicrophone = !openMicrophone;
      });
    }).catchError((err) {
      log('enableLocalAudio $err');
    });
  }

  _switchSpeakerphone() {
    _engine?.setEnableSpeakerphone(!enableSpeakerphone).then((value) {
      log("enableSpeakerphone $enableSpeakerphone");
      setState(() {
        enableSpeakerphone = !enableSpeakerphone;
      });
    }).catchError((err) {
      log('setEnableSpeakerphone $err');
    });
  }

  Widget _buildControlButton({
    required IconData icon,
    required VoidCallback onPressed,
    required bool isActive,
    Color? activeColor,
    Color? inactiveColor,
    double? size,
  }) {
    return Container(
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: isActive
              ? [
                  activeColor?.withOpacity(0.8) ??
                      Colors.white.withOpacity(0.3),
                  activeColor?.withOpacity(0.6) ??
                      Colors.white.withOpacity(0.1),
                ]
              : [
                  Colors.white.withOpacity(0.1),
                  Colors.white.withOpacity(0.05),
                ],
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.2),
            blurRadius: 10,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(50),
          child: Container(
            padding: EdgeInsets.all(size ?? 16),
            child: Icon(
              icon,
              color: Colors.white,
              size: size ?? 24,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildEndCallButton(VoidCallback onPressed) {
    return Container(
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFFFF416C),
            Color(0xFFFF4B2B),
          ],
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.red.withOpacity(0.4),
            blurRadius: 15,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(50),
          child: Container(
            padding: const EdgeInsets.all(20),
            child: const Icon(
              Icons.call_end,
              color: Colors.white,
              size: 32,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildUserAvatar({
    required String? photoUrl,
    required String name,
    required double size,
    bool showPulse = false,
  }) {
    Widget avatarWidget = photoUrl.isEmptyOrNull
        ? Container(
            width: size,
            height: size,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  primaryColor.withOpacity(0.8),
                  primaryColor.withOpacity(0.6),
                ],
              ),
              boxShadow: [
                BoxShadow(
                  color: primaryColor.withOpacity(0.3),
                  blurRadius: 20,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: Center(
              child: Text(
                name.validate()[0].toUpperCase(),
                style: boldTextStyle(
                  color: Colors.white,
                  weight: FontWeight.bold,
                ),
              ),
            ),
          )
        : Container(
            width: size,
            height: size,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.3),
                  blurRadius: 20,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(size / 2),
              child: cachedImage(
                photoUrl,
                width: size,
                height: size,
                fit: BoxFit.cover,
              ),
            ),
          );

    if (showPulse && callStatus == 'calling...') {
      return AnimatedBuilder(
        animation: _pulseAnimation,
        builder: (context, child) {
          return Transform.scale(
            scale: _pulseAnimation.value,
            child: avatarWidget,
          );
        },
      );
    }

    return avatarWidget;
  }

  @override
  Widget build(BuildContext context) {
    Widget getCallScreen({required bool value}) {
      final String displayName = value
          ? widget.callModel!.receiverName!
          : widget.callModel!.callerName!;
      final String? displayPhoto = value
          ? widget.callModel!.receiverPhotoUrl
          : widget.callModel!.callerPhotoUrl;

      return Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color(0xFF667eea),
              Color(0xFF764ba2),
              Color(0xFF434C5E),
            ],
          ),
        ),
        child: FadeTransition(
          opacity: _fadeAnimation,
          child: Column(
            children: [
              // Top section with user info
              Expanded(
                flex: 3,
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 24, vertical: 60),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      _buildUserAvatar(
                        photoUrl: displayPhoto,
                        name: displayName,
                        size: 160,
                        showPulse: true,
                      ),
                      const SizedBox(height: 32),
                      Text(
                        displayName,
                        style: boldTextStyle(
                          color: Colors.white,
                          weight: FontWeight.w600,
                          letterSpacing: 0.5,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 8),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: Colors.white.withOpacity(0.3),
                            width: 1,
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              width: 8,
                              height: 8,
                              decoration: BoxDecoration(
                                color: callStatus == 'Connected'
                                    ? Colors.green
                                    : Colors.orange,
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              callStatus,
                              style: secondaryTextStyle(
                                color: Colors.white,
                                weight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              // Middle section - decorative elements
              Expanded(
                flex: 2,
                child: Container(
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      // Animated circles
                      ...List.generate(3, (index) {
                        return AnimatedBuilder(
                          animation: _pulseController,
                          builder: (context, child) {
                            return Container(
                              width:
                                  200 + (index * 40.0) * _pulseAnimation.value,
                              height:
                                  200 + (index * 40.0) * _pulseAnimation.value,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: Colors.white
                                      .withOpacity(0.1 - (index * 0.03)),
                                  width: 2,
                                ),
                              ),
                            );
                          },
                        );
                      }),
                      // Sound waves
                      Icon(
                        Icons.graphic_eq,
                        size: 60,
                        color: Colors.white.withOpacity(0.3),
                      ),
                    ],
                  ),
                ),
              ),
              // Bottom section with controls
              Container(
                padding: const EdgeInsets.all(32),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.3),
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(30),
                    topRight: Radius.circular(30),
                  ),
                  border: Border(
                    top: BorderSide(
                      color: Colors.white.withOpacity(0.1),
                      width: 1,
                    ),
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    _buildControlButton(
                      icon:
                          enableSpeakerphone ? Octicons.unmute : Octicons.mute,
                      onPressed: _switchSpeakerphone,
                      isActive: enableSpeakerphone,
                      activeColor: Colors.blue,
                    ),
                    _buildEndCallButton(
                      () {
                        callService.endCall(callModel: widget.callModel!);
                        _engine?.stopEffect(RingingToneSoundId);
                      },
                    ),
                    _buildControlButton(
                      icon: openMicrophone
                          ? MaterialIcons.mic
                          : MaterialIcons.mic_off,
                      onPressed: _switchMicrophone,
                      isActive: openMicrophone,
                      activeColor: Colors.green,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      body: getCallScreen(
          value: widget.callModel?.callerId == getStringAsync(userId)),
    );
  }
}
