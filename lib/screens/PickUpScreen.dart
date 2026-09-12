import 'package:flutter/material.dart';
import 'package:nb_utils/nb_utils.dart';
import 'package:onesignal_flutter/onesignal_flutter.dart';


import '../../utils/TextStyles.dart' as TS;
import 'package:chat/centralized_import.dart';

class PickUpScreen extends StatefulWidget {
  final CallModel? callModel;

  const PickUpScreen({Key? key, this.callModel}) : super(key: key);

  @override
  _PickUpScreenState createState() => _PickUpScreenState();
}

class _PickUpScreenState extends State<PickUpScreen>
    with TickerProviderStateMixin {
  bool isCalledMissed = true;
  late AnimationController _pulseController;
  late AnimationController _slideController;
  late Animation<double> _pulseAnimation;
  late Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();

    print("Call flow => ${widget.callModel?.flow}");

    // Animation controllers
    _pulseController = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    )..repeat();

    _slideController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );

    _pulseAnimation = Tween<double>(
      begin: 1.0,
      end: 1.2,
    ).animate(CurvedAnimation(
      parent: _pulseController,
      curve: Curves.easeInOut,
    ));

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 1),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _slideController,
      curve: Curves.elasticOut,
    ));

    _slideController.forward();
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _slideController.dispose();
    if (isCalledMissed) {
      addToLocalStorage(status: CALLED_STATUS_MISSED);
    }
    super.dispose();
  }

  void addToLocalStorage({String? status}) {
    LogModel callLog = LogModel(
      callerName: widget.callModel?.callerName,
      callerPic: widget.callModel?.callerPhotoUrl,
      callStatus: status,
      callerId: widget.callModel?.callerId,
      receiverId: widget.callModel?.receiverId,
      receiverName: widget.callModel?.receiverName,
      receiverPic: widget.callModel?.receiverPhotoUrl,
      timestamp: DateTime.now().toString(),
      callType: widget.callModel!.callType,
    );
    LogRepository.addLogs(callLog);
  }

  Future<void> _handleAcceptCall() async {
    // Ensure permissions are granted before navigating
    bool permissionsGranted =
        await Permissions.cameraAndMicrophonePermissionsGranted();
    if (!permissionsGranted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Camera and microphone permissions are required')),
      );
      return;
    }

    isCalledMissed = false;
    addToLocalStorage(status: CALLED_STATUS_RECEIVED);
    OneSignal.Notifications.clearAll();

    // Navigate to the appropriate screen based on call type
    if (widget.callModel?.flow == 'GroupCall') {
      if (widget.callModel?.callType == CALL_TYPE_GROUP_VIDEO_CALL) {
        AgoraGroupVideoCallScreen(
          callModel: widget.callModel,
          isCaller: false,
        ).launch(context);
      } else {
        AgoraGroupVoiceCallScreen(
          callModel: widget.callModel,
          isCaller: false,
        ).launch(context);
      }
    } else if (widget.callModel!.isVoice!) {
      print("Accept call clicked");
      AgoraVoiceCallScreen(callModel: widget.callModel, isCaller: true).launch(context);
    } else {
      AgoraVideoCallScreen2(
        callModel: widget.callModel,
        isReceiver: true,
        isCaller: false,
      ).launch(context);
    }
  }

  Future<void> _handleDeclineCall() async {
    isCalledMissed = false;
    addToLocalStorage(status: CALLED_STATUS_RECEIVED);
    OneSignal.Notifications.clearAll();
    await callService.endCall(callModel: widget.callModel!);
    // Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              primaryColor,
              primaryColor.withOpacity(0.8),
              primaryColor.withOpacity(0.6),
            ],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              // Top section with caller info
              Expanded(
                flex: 3,
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const SizedBox(height: 40),

                      // Animated avatar with glow effect
                      AnimatedBuilder(
                        animation: _pulseAnimation,
                        builder: (context, child) {
                          return Transform.scale(
                            scale: _pulseAnimation.value,
                            child: Container(
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.white.withOpacity(0.3),
                                    blurRadius: 20,
                                    spreadRadius: 5,
                                  ),
                                ],
                              ),
                              child: widget
                                      .callModel!.callerPhotoUrl.isEmptyOrNull
                                  ? Container(
                                      decoration: BoxDecoration(
                                        shape: BoxShape.circle,
                                        border: Border.all(
                                          color: whiteColor.withOpacity(0.3),
                                          width: 4,
                                        ),
                                      ),
                                      child: CircleAvatar(
                                        backgroundColor: whiteColor,
                                        radius: 70,
                                        child: Text(
                                          widget.callModel!.callerName
                                              .validate()[0],
                                          style: TS.primaryTextStyle(
                                            color: primaryColor,
                                            size: 40,
                                            weight: FontWeight.bold,
                                          ),
                                        ),
                                      ),
                                    )
                                  : Container(
                                      decoration: BoxDecoration(
                                        shape: BoxShape.circle,
                                        border: Border.all(
                                          color: whiteColor.withOpacity(0.3),
                                          width: 4,
                                        ),
                                      ),
                                      child: cachedImage(
                                        widget.callModel!.callerPhotoUrl,
                                        height: 140,
                                        width: 140,
                                        fit: BoxFit.cover,
                                        radius: 70,
                                      ).cornerRadiusWithClipRRect(70),
                                    ),
                            ),
                          );
                        },
                      ),

                      const SizedBox(height: 30),

                      // Caller name with better typography
                      widget.callModel?.flow == 'GroupCall'
                          ? Text(
                              widget.callModel!.groupName.validate(),
                              style: TS.primaryTextStyle(
                                color: Colors.white,
                                size: 28,
                                weight: FontWeight.w600,
                              ),
                              textAlign: TextAlign.center,
                            )
                          : Text(
                              widget.callModel!.callerName.validate(),
                              style: TS.primaryTextStyle(
                                color: Colors.white,
                                size: 28,
                                weight: FontWeight.w600,
                              ),
                              textAlign: TextAlign.center,
                            ),

                      const SizedBox(height: 12),

                      // Incoming call indicator with animation
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Container(
                            width: 8,
                            height: 8,
                            decoration: BoxDecoration(
                              color: Colors.greenAccent,
                              shape: BoxShape.circle,
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.greenAccent.withOpacity(0.5),
                                  blurRadius: 8,
                                  spreadRadius: 2,
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            widget.callModel?.flow == "GroupCall"
                                ? 'Incoming Group call...'
                                : 'Incoming call...',
                            style: TS.secondaryTextStyle(
                              color: Colors.white70,
                              size: 16,
                              weight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),

              // Bottom section with action buttons
              Expanded(
                flex: 2,
                child: SlideTransition(
                  position: _slideAnimation,
                  child: Container(
                    padding: const EdgeInsets.all(40),
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.1),
                      borderRadius: const BorderRadius.only(
                        topLeft: Radius.circular(40),
                        topRight: Radius.circular(40),
                      ),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        // Action buttons
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                          children: [
                            // Decline button
                            GestureDetector(
                              onTap: _handleDeclineCall,
                              child: Container(
                                width: 80,
                                height: 80,
                                decoration: BoxDecoration(
                                  color: Colors.white.withOpacity(0.15),
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: Colors.white.withOpacity(0.3),
                                    width: 2,
                                  ),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withOpacity(0.1),
                                      blurRadius: 15,
                                      spreadRadius: 2,
                                    ),
                                  ],
                                ),
                                child: const Icon(
                                  Icons.call_end_rounded,
                                  color: Colors.redAccent,
                                  size: 35,
                                ),
                              ),
                            ),

                            // Accept button
                            GestureDetector(
                              onTap: _handleAcceptCall,
                              child: Container(
                                width: 80,
                                height: 80,
                                decoration: BoxDecoration(
                                  color: Colors.white.withOpacity(0.15),
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: Colors.white.withOpacity(0.3),
                                    width: 2,
                                  ),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.green.withOpacity(0.3),
                                      blurRadius: 20,
                                      spreadRadius: 3,
                                    ),
                                    BoxShadow(
                                      color: Colors.black.withOpacity(0.1),
                                      blurRadius: 15,
                                      spreadRadius: 2,
                                    ),
                                  ],
                                ),
                                child: const Icon(
                                  Icons.call_rounded,
                                  color: Colors.green,
                                  size: 35,
                                ),
                              ),
                            ),
                          ],
                        ),

                        const SizedBox(height: 40),

                        // Swipe indication
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 20,
                            vertical: 8,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            'Tap to answer or decline',
                            style: TS.secondaryTextStyle(
                              color: Colors.white60,
                              size: 14,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
