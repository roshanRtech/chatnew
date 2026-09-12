import 'package:agora_rtc_engine/agora_rtc_engine.dart';
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';

import 'package:chat/centralized_import.dart';

class CallPage extends StatefulWidget {
  final String? channelName;
  final String? groupName;

  CallPage({this.channelName, this.groupName});

  @override
  _CallPageState createState() => _CallPageState();
}

class _CallPageState extends State<CallPage> {
  final List<int> _users = [];
  final List<String> _infoStrings = [];
  bool muted = false;
  bool cameraEnabled = true;
  late RtcEngine _engine;
  bool _isEngineInitialized = false;

  @override
  void initState() {
    super.initState();
    initializeAgora();
  }

  @override
  void dispose() {
    _users.clear();
    _engine.leaveChannel();
    _engine.release();
    super.dispose();
  }

  Future<void> initializeAgora() async {
    // Request permissions
    await [Permission.camera, Permission.microphone].request();

    _engine = createAgoraRtcEngine();
    await _engine.initialize(RtcEngineContext(
      appId: appSettingStore.agoraCallId,
      channelProfile: ChannelProfileType.channelProfileCommunication,
    ));

    _engine.registerEventHandler(
      RtcEngineEventHandler(
        onJoinChannelSuccess: (RtcConnection connection, int elapsed) {
          setState(() {
            _infoStrings.add(
                "Join channel: ${connection.channelId}, uid: ${connection.localUid}");
          });
        },
        onUserJoined: (RtcConnection connection, int remoteUid, int elapsed) {
          setState(() {
            _infoStrings.add("User joined: $remoteUid");
            _users.add(remoteUid);
          });
        },
        onUserOffline: (RtcConnection connection, int remoteUid,
            UserOfflineReasonType reason) {
          setState(() {
            _infoStrings.add("User offline: $remoteUid");
            _users.remove(remoteUid);
          });
        },
        onAudioVolumeIndication: (RtcConnection connection,
            List<AudioVolumeInfo> speakers,
            int totalVolume,
            int totalVolumeWithNoiseReduction) {
          if (speakers.isNotEmpty) {
            final activeSpeaker = speakers.first.uid;
            if (activeSpeaker != 0 && _users.contains(activeSpeaker)) {
              setState(() {
                _users.remove(activeSpeaker);
                _users.insert(0, activeSpeaker ?? 0);
              });
            }
          }
        },
      ),
    );

    await _engine.enableVideo();
    await _engine.startPreview();

    // Enable active speaker detection
    await _engine.enableAudioVolumeIndication(
      interval: 1000, // check every 1 second
      smooth: 3,
      reportVad: true,
    );

    await _engine.joinChannel(
      token: "", // If using token, put it here
      channelId: widget.channelName ?? "",
      uid: 0,
      options: const ChannelMediaOptions(
        clientRoleType: ClientRoleType.clientRoleBroadcaster,
        publishCameraTrack: true,
        publishMicrophoneTrack: true,
        autoSubscribeAudio: true,
        autoSubscribeVideo: true,
      ),
    );

    setState(() {
      _isEngineInitialized = true;
    });
  }

  List<Widget> _getRenderViews() {
    final List<Widget> list = [];
    if (_isEngineInitialized) {
      list.add(AgoraVideoView(
        controller: VideoViewController(
          rtcEngine: _engine,
          canvas: const VideoCanvas(uid: 0),
        ),
      ));
      _users.forEach((int id) {
        list.add(AgoraVideoView(
          controller: VideoViewController(
            rtcEngine: _engine,
            canvas: VideoCanvas(uid: id),
          ),
        ));
      });
    }
    return list;
  }

  Widget _videoView(Widget view) {
    return Container(
      margin: const EdgeInsets.all(2),
      decoration:
          BoxDecoration(border: Border.all(color: Colors.white, width: 1)),
      child: view,
    );
  }

  Widget _viewRows() {
    final views = _getRenderViews();
    if (views.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    return GridView.builder(
      itemCount: views.length,
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2, // show 2 per row
        childAspectRatio: 1,
      ),
      itemBuilder: (context, index) {
        return _videoView(views[index]);
      },
    );
  }

  Widget _toolbar() {
    return Container(
      alignment: Alignment.bottomCenter,
      padding: const EdgeInsets.symmetric(vertical: 48),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          RawMaterialButton(
            onPressed: _onToggleMute,
            shape: const CircleBorder(),
            elevation: 2.0,
            fillColor: muted ? Colors.blueAccent : Colors.white,
            padding: const EdgeInsets.all(12.0),
            child: Icon(
              muted ? Icons.mic_off : Icons.mic,
              color: muted ? Colors.white : Colors.blueAccent,
              size: 20.0,
            ),
          ),
          RawMaterialButton(
            onPressed: () => _onCallEnd(context),
            shape: const CircleBorder(),
            elevation: 2.0,
            fillColor: Colors.redAccent,
            padding: const EdgeInsets.all(15.0),
            child: const Icon(
              Icons.call_end,
              color: Colors.white,
              size: 35.0,
            ),
          ),
          RawMaterialButton(
            onPressed: _onToggleCamera,
            shape: const CircleBorder(),
            elevation: 2.0,
            fillColor: cameraEnabled ? Colors.white : Colors.blueAccent,
            padding: const EdgeInsets.all(12.0),
            child: Icon(
              cameraEnabled ? Icons.videocam : Icons.videocam_off,
              color: cameraEnabled ? Colors.blueAccent : Colors.white,
              size: 20.0,
            ),
          ),
          RawMaterialButton(
            onPressed: _onSwitchCamera,
            shape: const CircleBorder(),
            elevation: 2.0,
            fillColor: Colors.white,
            padding: const EdgeInsets.all(12.0),
            child: const Icon(
              Icons.switch_camera,
              color: Colors.blueAccent,
              size: 20.0,
            ),
          ),
        ],
      ),
    );
  }

  void _onCallEnd(BuildContext context) {
    Navigator.pop(context);
  }

  void _onToggleMute() {
    setState(() {
      muted = !muted;
    });
    _engine.muteLocalAudioStream(muted);
  }

  void _onToggleCamera() {
    setState(() {
      cameraEnabled = !cameraEnabled;
    });
    _engine.muteLocalVideoStream(!cameraEnabled);
  }

  void _onSwitchCamera() {
    _engine.switchCamera();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.groupName ?? '',
            style: const TextStyle(fontWeight: FontWeight.bold)),
      ),
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          _viewRows(),
          _toolbar(),
          Positioned(
            top: 10,
            left: 10,
            child: Container(
              constraints: BoxConstraints(
                  maxWidth: MediaQuery.of(context).size.width * 0.8),
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.black54,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                _infoStrings.join('\n'),
                style: const TextStyle(color: Colors.white, fontSize: 12),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
