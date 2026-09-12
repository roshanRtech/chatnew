import 'package:flutter/material.dart';
import 'package:agora_rtc_engine/agora_rtc_engine.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

import 'package:nb_utils/nb_utils.dart';
import 'dart:async';

import 'package:chat/centralized_import.dart';


class AgoraVideoCallScreen2 extends StatefulWidget {
  final CallModel? callModel;
  final bool isReceiver;
  final bool isCaller;

  const AgoraVideoCallScreen2({Key? key, this.callModel, required this.isReceiver, required this.isCaller}) : super(key: key);

  @override
  _AgoraVideoCallScreen2State createState() => _AgoraVideoCallScreen2State();
}

class _AgoraVideoCallScreen2State extends State<AgoraVideoCallScreen2> {
  RtcEngine? _engine;
  final String appId = appSettingStore.agoraCallId!;
  bool _localVideoEnabled = true;
  bool _localAudioEnabled = true;
  bool _remoteMuted = false;
  int? _remoteUid;
  bool _joined = false;
  bool _isEngineInitialized = false;
  StreamSubscription<DocumentSnapshot>? _callStreamSubscription;
  bool _isLeaving = false;

  late final RtcEngineEventHandler _rtcEngineEventHandler;

  @override
  void initState() {
    super.initState();
    _rtcEngineEventHandler = RtcEngineEventHandler(
      onJoinChannelSuccess: (RtcConnection connection, int elapsed) {
        debugPrint("Local user joined channel: ${connection.channelId}");
        setState(() {
          _joined = true;
        });
      },
      onUserJoined: (RtcConnection connection, int remoteUid, int elapsed) {
        debugPrint("Remote user $remoteUid joined channel");
        setState(() {
          _remoteUid = remoteUid;
        });

        _engine?.stopEffect(RingingToneSoundId);
      },
      onUserOffline: (RtcConnection connection, int remoteUid, UserOfflineReasonType reason) {
        debugPrint("Remote user $remoteUid left channel");
        setState(() {
          _remoteUid = null;
        });
        _leaveChannel();
      },
      onRemoteAudioStateChanged: (
          RtcConnection connection,
          int remoteUid,
          RemoteAudioState state,
          RemoteAudioStateReason reason,
          int elapsed,
          ) {
        debugPrint("Remote audio state changed: $state");
        setState(() {
          _remoteMuted = state == RemoteAudioState.remoteAudioStateStopped;
        });
      },
      onError: (ErrorCodeType err, String msg) {
        debugPrint('Agora error: $err, $msg');
        _showErrorDialog('Error: $msg');
      },
    );
    _initAgora();
    _initCallStream();

    // Init Wakelock Screen
    WakelockPlus.enable();
  }

  void _initCallStream() {
    String uid = getStringAsync(userId);
    if (uid.isNotEmpty) {
      _callStreamSubscription = callService.callStream(uid: uid).listen((DocumentSnapshot ds) {
        log('CallStream: data=${ds.data()}, mounted=$mounted, isLeaving=$_isLeaving');
        if (ds.data() == null && mounted && !_isLeaving) {
          _leaveChannel();
        }
      });
    }
  }

  Future<void> _initAgora() async {
    try {
      Map<Permission, PermissionStatus> statuses = await [
        Permission.camera,
        Permission.microphone,
      ].request();

      if (statuses[Permission.camera] != PermissionStatus.granted ||
          statuses[Permission.microphone] != PermissionStatus.granted) {
        _showErrorDialog('Camera and microphone permissions are required');
        return;
      }

      _engine = createAgoraRtcEngine();
      await _engine!.initialize(
        RtcEngineContext(
          appId: appId,
          channelProfile: ChannelProfileType.channelProfileCommunication,
        ),
      );

      _engine!.registerEventHandler(_rtcEngineEventHandler);

      await _engine!.setAudioProfile(profile: AudioProfileType.audioProfileMusicHighQualityStereo, scenario: AudioScenarioType.audioScenarioChatroom);

      await _engine!.enableVideo();
      await _engine!.enableAudio();



      await _engine!.setParameters('{"che.audio.set.category":"AVAudioSessionCategoryPlayAndRecord"}');
      await _engine!
          .setParameters('{"che.audio.allow.background.playing":true}');
      await _engine!.setParameters('{"che.audio.enable.local.playback":true}');


      if (pathToRingingTone.isNotEmpty) {
        if (widget.isCaller) {
          // print("Is called");
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


      await _engine!.setVideoEncoderConfiguration(
        const VideoEncoderConfiguration(
          dimensions: VideoDimensions(width: 640, height: 480),
          frameRate: 15,
          bitrate: 400,
        ),
      );

      await _engine!.joinChannel(
        token: '',
        channelId: widget.callModel?.channelId ?? '',
        uid: 0,
        options: const ChannelMediaOptions(
          channelProfile: ChannelProfileType.channelProfileCommunication,
          clientRoleType: ClientRoleType.clientRoleBroadcaster,
          autoSubscribeAudio: true,
          autoSubscribeVideo: true,
          publishCameraTrack: true,
          publishMicrophoneTrack: true,
        ),
      );

      if (mounted) {
        setState(() {
          _isEngineInitialized = true;
        });
      }
    } catch (e) {
      debugPrint('Error initializing Agora: $e');
      _showErrorDialog('Failed to initialize video call');
    }
  }

  void _showErrorDialog(String message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Error'),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              _leaveChannel();
            },
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  Future<void> _leaveChannel() async {
    if (_isLeaving) return;
    _isLeaving = true;

    _engine?.stopEffect(RingingToneSoundId);

    try {
      // End the call first to update Firestore
      if (widget.callModel != null) {
        await callService.endCall(callModel: widget.callModel!);
      }
      // Cancel stream subscription to prevent further events
      await _callStreamSubscription?.cancel();
      // Clean up Agora engine
      await _engine?.leaveChannel();
      await _engine?.release();
      // Navigate back
      if (mounted) {
        Navigator.of(context, rootNavigator: true).pop();
      }
    } catch (e) {
      debugPrint('Error leaving channel: $e');
    } finally {
      _isLeaving = false;
    }

    WakelockPlus.disable();
  }

  void _toggleLocalVideo() {
    if (!_isEngineInitialized) return;
    setState(() {
      _localVideoEnabled = !_localVideoEnabled;
    });
    _engine?.muteLocalVideoStream(!_localVideoEnabled);
  }

  void _toggleLocalAudio() {
    if (!_isEngineInitialized) return;
    setState(() {
      _localAudioEnabled = !_localAudioEnabled;
    });
    _engine?.muteLocalAudioStream(!_localAudioEnabled);
  }

  void _switchCamera() {
    if (!_isEngineInitialized) return;
    _engine?.switchCamera();
  }

  @override
  void dispose() {
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
      backgroundColor: Colors.black, // Change to Colors.blue for debugging if needed
      body: SafeArea(
        child: Stack(
          children: [
            _buildRemoteVideo(),
            _buildLocalVideo(),
            _buildTopBar(),
            _buildBottomControls(),
          ],
        ),
      ),
    );
  }

  Widget _buildRemoteVideo() {
    if (!_isEngineInitialized || _engine == null) {
      return Container(
        width: double.infinity,
        height: double.infinity,
        color: Colors.grey.shade900,
        child: const Center(
          child: CircularProgressIndicator(color: Colors.white),
        ),
      );
    }
    if (_remoteUid != null) {
      return AgoraVideoView(
        controller: VideoViewController.remote(
          rtcEngine: _engine!,
          connection: RtcConnection(channelId: widget.callModel?.channelId ?? ''),
          canvas: VideoCanvas(uid: _remoteUid!),
        ),
      );
    } else {
      return Container(
        width: double.infinity,
        height: double.infinity,
        color: Colors.grey.shade900,
        child: const Center(
          child: SizedBox(),
        ),
      );
    }
  }

  Widget _buildLocalVideo() {
    return Positioned(
      top: 80,
      right: 20,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Container(
          width: 120,
          height: 160,
          decoration: BoxDecoration(
            border: Border.all(color: Colors.white, width: 2),
            borderRadius: BorderRadius.circular(12),
          ),
          child: _isEngineInitialized && _engine != null && _localVideoEnabled
              ? AgoraVideoView(
            controller: VideoViewController(
              rtcEngine: _engine!,
              canvas: const VideoCanvas(uid: 0),
            ),
          )
              : Container(
            color: Colors.black,
            child: Center(
              child: _isEngineInitialized
                  ? const Icon(
                Icons.videocam_off,
                color: Colors.white,
                size: 30,
              )
                  : const CircularProgressIndicator(color: Colors.white),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTopBar() {
    return Positioned(
      top: 0,
      left: 0,
      right: 0,
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Colors.black.withOpacity(0.7), Colors.transparent],
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.isReceiver ? widget.callModel!.callerName! : widget.callModel!.receiverName!,
                  style: boldTextStyle(color: Colors.white),
                ),
              ],
            ),
            if (_remoteMuted)
              const Icon(Icons.mic_off, color: Colors.red, size: 24),
          ],
        ),
      ),
    );
  }

  Widget _buildBottomControls() {
    return Positioned(
      bottom: 50,
      left: 0,
      right: 0,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 40),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            _buildControlButton(
              icon: _localVideoEnabled ? Icons.videocam : Icons.videocam_off,
              onPressed: _toggleLocalVideo,
              backgroundColor: _localVideoEnabled ? Colors.white24 : Colors.red,
            ),
            _buildControlButton(
              icon: _localAudioEnabled ? Icons.mic : Icons.mic_off,
              onPressed: _toggleLocalAudio,
              backgroundColor: _localAudioEnabled ? Colors.white24 : Colors.red,
            ),
            _buildControlButton(
              icon: Icons.flip_camera_ios,
              onPressed: _switchCamera,
              backgroundColor: Colors.white24,
            ),
            _buildControlButton(
              icon: Icons.call_end,
              onPressed: _leaveChannel,
              backgroundColor: Colors.red,
              size: 60,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildControlButton({
    required IconData icon,
    required VoidCallback onPressed,
    required Color backgroundColor,
    double size = 50,
  }) {
    return GestureDetector(
      onTap: onPressed,
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: backgroundColor,
          shape: BoxShape.circle,
        ),
        child: Icon(icon, color: Colors.white, size: size * 0.5),
      ),
    );
  }
}