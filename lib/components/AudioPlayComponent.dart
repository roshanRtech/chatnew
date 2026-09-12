import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart' as ja;
import 'package:nb_utils/nb_utils.dart';

import 'package:chat/centralized_import.dart';

import '../../utils/TextStyles.dart' as TS;

class AudioPlayComponent extends StatefulWidget {
  final ChatMessageModel? data;
  final String? time;
  final bool? isDeletedForMe;

  AudioPlayComponent({this.data, this.time, this.isDeletedForMe});

  @override
  _AudioPlayComponentState createState() => _AudioPlayComponentState();
}

class _AudioPlayComponentState extends State<AudioPlayComponent> {
  ja.AudioPlayer _player = ja.AudioPlayer();
  Duration duration = Duration();
  Duration position = Duration();
  bool isPlaying = false;

  @override
  void initState() {
    super.initState();
    initAudioPlayer();
  }

  Future<void> initAudioPlayer() async {
    try {
      await _player.setUrl(widget.data?.photoUrl ?? '', preload: true);
      _player.processingStateStream.listen((state) {
        if (state == ja.ProcessingState.completed) {
          _player.seek(Duration.zero);
          setState(() async {
            isPlaying = false;
            await _player.pause();
          });
        }
      });
    } catch (e) {
      log("Error loading audio: $e");
    }
  }

  @override
  void didUpdateWidget(covariant AudioPlayComponent oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.data?.photoUrl != oldWidget.data?.photoUrl) {
      initAudioPlayer();
    }
  }

  @override
  void setState(fn) {
    if (mounted) super.setState(fn);
  }

  @override
  void dispose() {
    _player.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.isDeletedForMe == true) {
      return Padding(
        padding: const EdgeInsets.all(6),
        child: Text('you_delete_msg'.translate,
            style: TS.primaryTextStyle(color: Colors.grey)),
      );
    }

    if (widget.data?.isDeleted == true) {
      return Padding(
        padding: const EdgeInsets.all(6),
        child: Text('this_delete_msg'.translate,
            style: TS.primaryTextStyle(color: Colors.grey)),
      );
    }

    return Container(
      padding: EdgeInsets.symmetric(horizontal: 4),
      child: Column(
        children: [
          Row(
            mainAxisSize: MainAxisSize.max,
            children: [
              Container(
                height: 50,
                width: 50,
                margin: EdgeInsets.all(2),
                decoration: boxDecorationWithShadow(
                  backgroundColor: widget.data?.messageType == AUDIO
                      ? yellowColor
                      : Colors.grey.shade400,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  widget.data?.messageType == AUDIO
                      ? Icons.headset_outlined
                      : Icons.mic,
                  color: Colors.white,
                ),
              ),
              4.width,
              Expanded(
                child: StreamBuilder<Duration?>(
                  stream: _player.durationStream,
                  builder: (context, snapshot) {
                    final duration = snapshot.data ?? Duration.zero;
                    return StreamBuilder<Duration>(
                      stream: _player.positionStream,
                      builder: (context, snap) {
                        position = snap.data ?? Duration.zero;

                        if (position > duration) {
                          _player.seek(Duration.zero);
                          _player.pause().whenComplete(() => isPlaying = false);
                        }

                        return Row(
                          children: [
                            widget.data?.photoUrl.isEmptyOrNull ?? false
                                ? CircularProgressIndicator()
                                    .withHeight(25)
                                    .withWidth(25)
                                    .paddingAll(2)
                                : Icon(
                                    isPlaying ? Icons.pause : Icons.play_arrow,
                                    color: appStore.isDarkMode
                                        ? Colors.white
                                        : scaffoldDarkColor.withOpacity(0.5),
                                  ).onTap(() async {
                                    if (isPlaying) {
                                      isPlaying = false;
                                      await _player.pause().catchError((e) {
                                        toast(e.toString());
                                      });
                                    } else {
                                      isPlaying = true;
                                      await _player.play().catchError((e) {
                                        toast(e.toString());
                                      });
                                    }
                                    setState(() {});
                                  }),
                            SizedBox(width: 8),
                            Flexible(
                              child: SliderTheme(
                                data: SliderThemeData(
                                  trackHeight: 3.0,
                                  thumbColor: widget.data?.messageType == AUDIO
                                      ? yellowColor
                                      : Colors.grey.shade400,
                                  inactiveTrackColor:
                                      widget.data?.messageType == AUDIO
                                          ? Colors.grey.shade200
                                          : Colors.grey.shade300,
                                  thumbShape: RoundSliderThumbShape(
                                      enabledThumbRadius: 8.0),
                                  overlayColor: Colors.purple.withAlpha(32),
                                  overlayShape: RoundSliderOverlayShape(
                                      overlayRadius: 14.0),
                                ),
                                child: Slider(
                                  min: 0.0,
                                  max: duration.inSeconds.toDouble(),
                                  value: position.inSeconds.toDouble().clamp(
                                      0.0, duration.inSeconds.toDouble()),
                                  onChanged: (value) {
                                    _player
                                        .seek(Duration(seconds: value.toInt()));
                                  },
                                ),
                              ),
                            ),
                          ],
                        );
                      },
                    );
                  },
                ),
              ),
            ],
          ),
          Align(
            alignment: isRTL ? Alignment.bottomLeft : Alignment.bottomRight,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  widget.time ?? '',
                  style: TS.primaryTextStyle(
                      color: Colors.blueGrey,
                      size: (appStore.fontSize - 4).toInt()),
                ),
                2.width,
                if (widget.data?.isMe ?? false)
                  widget.data?.isMessageRead ?? false
                      ? Icon(Icons.done_all,
                          size: 16,
                          color: appStore.isDarkMode
                              ? textPrimaryColor
                              : primaryColor)
                      : Icon(Icons.done,
                          size: 16, color: Colors.blueGrey.withOpacity(0.6)),
              ],
            ),
          ),
          if (widget.data?.groupReaction != null &&
              widget.data!.groupReaction!.isNotEmpty)
            Align(
              alignment: Alignment.bottomLeft,
              child: Padding(
                padding: const EdgeInsets.only(left: 5),
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: widget.data!.groupReaction!.map((entry) {
                      return !entry.reaction.isEmptyOrNull
                          ? Container(
                              margin: const EdgeInsets.only(top: 4, right: 6),
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: Colors.grey.shade100,
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(
                                    color: Colors.grey.shade300, width: 1),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withOpacity(0.05),
                                    blurRadius: 2,
                                    offset: Offset(0, 1),
                                  ),
                                ],
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    entry.reaction ?? '',
                                    style: TS.boldTextStyle(),
                                  ),
                                ],
                              ),
                            )
                          : SizedBox.shrink();
                    }).toList(),
                  ),
                ),
              ),
            ).onTap(() {
              showReactionBottomSheet(context, widget.data?.groupReaction);
            }),
        ],
      ),
    );
  }
}
