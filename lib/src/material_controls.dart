import 'dart:async';

import 'package:chewie/src/chewie_player.dart';
import 'package:chewie/src/chewie_progress_colors.dart';
import 'package:chewie/src/material_progress_bar.dart';
import 'package:chewie/src/utils.dart';
import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

class MaterialControls extends StatefulWidget {
  MaterialControls({Key key}) : super(key: key);
  @override
  State<StatefulWidget> createState() {
    return _MaterialControlsState();
  }
}

class _MaterialControlsState extends State<MaterialControls> {
  VideoPlayerValue _latestValue;
  double _latestVolume;
  bool _hideStuff = true;
  Timer _hideTimer;
  Timer _showTimer;
  Timer _showAfterExpandCollapseTimer;
  bool _dragging = false;

  final barHeight = 48.0;
  final marginSize = 5.0;

  VideoPlayerController controller;
  ChewieController chewieController;

  final lightColor = Color.fromRGBO(255, 255, 255, 0.85);
  final darkColor = Color.fromRGBO(1, 1, 1, 0.35);

  var _beginSecond = 0;
  var _beginX = 0;
  var _seekPostion = Duration();

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        _cancelAndRestartTimer();
      },
      child: AbsorbPointer(
        absorbing: false,
        child: Column(
          children: <Widget>[
            chewieController.isFullScreen ? _buildHeader(context, chewieController.title) : new Container(),
            _latestValue != null && !_latestValue.isPlaying && _latestValue.duration == null || _latestValue.isBuffering
                ? Expanded(
                    child: Center(
                      child: CircularProgressIndicator(),
                    ),
                  )
                : _buildHitArea(),
            _buildBottomBar(context),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _dispose();
    super.dispose();
  }

  void _dispose() {
    controller.removeListener(_updateState);
    _hideTimer?.cancel();
    _showTimer?.cancel();
    _showAfterExpandCollapseTimer?.cancel();
  }

  @override
  void didChangeDependencies() {
    final _oldController = chewieController;
    chewieController = ChewieController.of(context);
    controller = chewieController.videoPlayerController;

    if (_oldController != chewieController) {
      _dispose();
      _initialize();
    }

    super.didChangeDependencies();
  }

  AnimatedOpacity _buildHeader(BuildContext context, String title) {
    return new AnimatedOpacity(
      opacity: _hideStuff ? 0.0 : 1.0,
      duration: new Duration(milliseconds: 300),
      child: new Container(
        color: darkColor,
        height: barHeight,
        child: new Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: <Widget>[
            new IconButton(
              onPressed: _onExpandCollapse,
              color: lightColor,
              icon: new Icon(Icons.chevron_left),
            ),
            new Text(
              '$title',
              style: new TextStyle(
                color: lightColor,
                fontSize: 18.0,
              ),
            ),
          ],
        ),
      ),
    );
  }

  AnimatedOpacity _buildBottomBar(
    BuildContext context,
  ) {
    final iconColor = Theme.of(context).textTheme.button.color;

    return AnimatedOpacity(
      opacity: _hideStuff ? 0.0 : 1.0,
      duration: Duration(milliseconds: 300),
      child: Container(
        height: barHeight,
        color: darkColor,
        child: Row(
          children: <Widget>[
            _buildPlayPause(controller),
            chewieController.isLive ? Expanded(child: const Text('LIVE')) : _buildPosition(iconColor),
            chewieController.isLive ? const SizedBox() : _buildProgressBar(),
            // chewieController.allowMuting ? _buildMuteButton(controller) : Container(),
            chewieController.allowFullScreen ? _buildExpandButton() : Container(),
          ],
        ),
      ),
    );
  }

  GestureDetector _buildExpandButton() {
    return GestureDetector(
      onTap: _onExpandCollapse,
      child: AnimatedOpacity(
        opacity: _hideStuff ? 0.0 : 1.0,
        duration: Duration(milliseconds: 300),
        child: Container(
          height: barHeight,
          margin: EdgeInsets.only(right: 6.0),
          padding: EdgeInsets.only(
            left: 6.0,
            right: 5.0,
          ),
          child: Center(
            child: Icon(
              chewieController.isFullScreen ? Icons.fullscreen_exit : Icons.fullscreen,
              color: lightColor,
            ),
          ),
        ),
      ),
    );
  }

  Expanded _buildHitArea() {
    return Expanded(
      child: GestureDetector(
        onTap: _latestValue != null && _latestValue.isPlaying
            ? _cancelAndRestartTimer
            : () {
                _playPause();

                setState(() {
                  _hideStuff = true;
                });
              },
        onHorizontalDragStart: (details) {
          _dragging = true;
          _beginX = 0;
          _beginSecond = _latestValue.position.inSeconds;
          setState(() {});
        },
        onHorizontalDragUpdate: (details) {
          if (!_dragging) {
            return;
          }
          if (_beginX == 0) {
            _beginX = details.globalPosition.dx.toInt();
          }
          var _offsetX = details.globalPosition.dx.toInt() - _beginX;
          var _endSecd = _beginSecond + _offsetX;
          if (_endSecd < 0) {
            _endSecd = 0;
          } else if (_endSecd > _latestValue.duration.inSeconds) {
            _endSecd = _latestValue.duration.inSeconds;
          }
          setState(() {
            _seekPostion = Duration(seconds: _endSecd);
          });
        },
        onHorizontalDragEnd: (details) {
          if (!_dragging) {
            return;
          }
          _dragging = false;
          setState(() {
            controller.seekTo(_seekPostion);
          });
        },
        child: Container(
          color: Colors.transparent,
          child: Center(
            child: AnimatedOpacity(
              opacity: _latestValue != null && (!_latestValue.isPlaying || _dragging) ? 1.0 : 0.0,
              duration: Duration(milliseconds: 300),
              child: _dragging
                  ? Container(
                      width: 120,
                      height: 60,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: Colors.black54,
                        borderRadius: BorderRadius.circular(10.0),
                      ),
                      child: Text(
                        formatDuration(_seekPostion),
                        style: new TextStyle(
                          color: Color(0xFFFFFFFF),
                          fontSize: 26.0,
                        ),
                      ),
                    )
                  : GestureDetector(
                      child: Container(
                        decoration: BoxDecoration(
                          color: Colors.black54,
                          borderRadius: BorderRadius.circular(48.0),
                        ),
                        child: Padding(
                          padding: EdgeInsets.all(12.0),
                          child: Icon(
                            Icons.play_arrow,
                            size: 32.0,
                            color: lightColor,
                          ),
                        ),
                      ),
                    ),
            ),
          ),
        ),
      ),
    );
  }

  GestureDetector _buildMuteButton(
    VideoPlayerController controller,
  ) {
    return GestureDetector(
      onTap: () {
        _cancelAndRestartTimer();

        if (_latestValue.volume == 0) {
          controller.setVolume(_latestVolume ?? 0.5);
        } else {
          _latestVolume = controller.value.volume;
          controller.setVolume(0.0);
        }
      },
      child: AnimatedOpacity(
        opacity: _hideStuff ? 0.0 : 1.0,
        duration: Duration(milliseconds: 300),
        child: ClipRect(
          child: Container(
            child: Container(
              height: barHeight,
              padding: EdgeInsets.only(
                left: 8.0,
                right: 8.0,
              ),
              child: Icon(
                (_latestValue != null && _latestValue.volume > 0) ? Icons.volume_up : Icons.volume_off,
                color: lightColor,
              ),
            ),
          ),
        ),
      ),
    );
  }

  GestureDetector _buildPlayPause(VideoPlayerController controller) {
    return GestureDetector(
      onTap: _playPause,
      child: Container(
        height: barHeight,
        color: Colors.transparent,
        margin: EdgeInsets.only(left: 8.0, right: 4.0),
        padding: EdgeInsets.only(
          left: 6.0,
          right: 6.0,
        ),
        child: Icon(
          controller.value.isPlaying ? Icons.pause : Icons.play_arrow,
          color: lightColor,
        ),
      ),
    );
  }

  Widget _buildPosition(Color iconColor) {
    final position = _latestValue != null && _latestValue.position != null ? _latestValue.position : Duration.zero;
    final duration = _latestValue != null && _latestValue.duration != null ? _latestValue.duration : Duration.zero;

    return Padding(
      padding: EdgeInsets.only(right: 16.0),
      child: Text(
        '${formatDuration(position)} / ${formatDuration(duration)}',
        style: TextStyle(
          fontSize: 14.0,
          color: lightColor,
        ),
      ),
    );
  }

  void _cancelAndRestartTimer() {
    _hideTimer?.cancel();
    _startHideTimer();

    setState(() {
      _hideStuff = false;
    });
  }

  Future<Null> _initialize() async {
    controller.addListener(_updateState);

    _updateState();

    if ((controller.value != null && controller.value.isPlaying) || chewieController.autoPlay) {
      _startHideTimer();
    }

    _showTimer = Timer(Duration(milliseconds: 200), () {
      setState(() {
        _hideStuff = false;
      });
    });
  }

  void _onExpandCollapse() {
    setState(() {
      _hideStuff = true;

      chewieController.toggleFullScreen();
      _showAfterExpandCollapseTimer = Timer(Duration(milliseconds: 300), () {
        setState(() {
          _cancelAndRestartTimer();
        });
      });
    });
  }

  void _playPause() {
    setState(() {
      if (controller.value.isPlaying) {
        _hideStuff = false;
        _hideTimer?.cancel();
        controller.pause();
      } else {
        _cancelAndRestartTimer();

        if (!controller.value.initialized) {
          controller.initialize().then((_) {
            controller.play();
          });
        } else {
          controller.play();
        }
      }
    });
  }

  void _startHideTimer() {
    _hideTimer = Timer(const Duration(seconds: 3), () {
      setState(() {
        _hideStuff = true;
      });
    });
  }

  void _updateState() {
    setState(() {
      _latestValue = controller.value;
      if (!_latestValue.isPlaying) {
        _seekPostion = Duration(seconds: _latestValue.position.inSeconds);
      }
    });
  }

  Widget _buildProgressBar() {
    return Expanded(
      child: Padding(
        padding: EdgeInsets.only(right: 10.0),
        child: MaterialVideoProgressBar(
          controller,
          onDragStart: () {
            setState(() {
              _dragging = true;
            });

            _hideTimer?.cancel();
          },
          onDragEnd: () {
            setState(() {
              _dragging = false;
            });

            _startHideTimer();
          },
          colors: ChewieProgressColors(
            playedColor: lightColor,
            handleColor: lightColor,
            bufferedColor: Colors.white30,
            backgroundColor: darkColor,
          ),
        ),
      ),
    );
  }
}
