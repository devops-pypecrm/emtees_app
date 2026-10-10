import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:jitsi_meet_flutter_sdk/jitsi_meet_flutter_sdk.dart';

import '../../core/config.dart';
import '../classes/classes_provider.dart';

/// Full-screen Jitsi call. Joins immediately on mount using the given room
/// name and JWT, and pops back to the caller once the meeting ends.
///
/// If [oneToOneSessionId] is set, a heartbeat is posted to the backend every
/// 60 seconds while the call is active, matching the web app's behavior for
/// 1:1 attendance/billing tracking.
class CallScreen extends ConsumerStatefulWidget {
  const CallScreen({
    super.key,
    required this.roomName,
    required this.jwt,
    required this.displayName,
    this.isModerator = false,
    this.oneToOneSessionId,
    this.classId,
  });

  final String roomName;
  final String? jwt;
  final String displayName;
  final bool isModerator;
  final String? oneToOneSessionId;
  final String? classId;

  @override
  ConsumerState<CallScreen> createState() => _CallScreenState();
}

class _CallScreenState extends ConsumerState<CallScreen>
    with WidgetsBindingObserver {
  final _jitsiMeet = JitsiMeet();
  Timer? _heartbeatTimer;
  bool _ended = false;
  bool _joined = false;
  String? _statusMessage = 'Connecting…';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) => _join());
  }

  /// Jitsi doesn't auto-enter Picture-in-Picture on its own when the app is
  /// backgrounded (opening another app, going home, etc) — the host app has
  /// to explicitly ask it to, at the moment the app becomes inactive. Once
  /// in PiP, tapping the floating window is handled entirely by the OS and
  /// brings the call back to full screen automatically.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.inactive && _joined && !_ended) {
      _jitsiMeet.enterPiP();
    }
  }

  Future<void> _join() async {
    final options = JitsiMeetConferenceOptions(
      serverURL: AppConfig.jitsiServerUrl,
      room: widget.roomName,
      token: widget.jwt,
      userInfo: JitsiMeetUserInfo(displayName: widget.displayName),
      featureFlags: const {
        'welcomepage.enabled': false,
        'invite.enabled': false,
        'lobby-mode.enabled': false,
        'pip.enabled': true,
        'chat.enabled': true,
        'raise-hand.enabled': true,
        'meeting-name.enabled': true,
        'video-share.enabled': true,
      },
      configOverrides: const {
        'startWithAudioMuted': false,
        'startWithVideoMuted': false,
        'subject': '',
      },
    );

    await _jitsiMeet.join(
      options,
      JitsiMeetEventListener(
        conferenceJoined: (url) {
          if (!mounted) return;
          setState(() {
            _statusMessage = null;
            _joined = true;
          });
          _reportPresence('join');
          _maybeStartHeartbeat();
        },
        conferenceTerminated: (url, error) {
          _handleEnd();
        },
        readyToClose: () {
          _handleEnd();
        },
      ),
    );
  }

  bool _presenceJoined = false;

  /// Tells the backend when this user enters/leaves the call; attendance,
  /// reports and salary are computed from these times. Never throws.
  void _reportPresence(String eventType) {
    if (eventType == 'join' && _presenceJoined) return;
    if (eventType == 'leave' && !_presenceJoined) return;
    if (widget.oneToOneSessionId == null && widget.classId == null) return;
    _presenceJoined = eventType == 'join';
    ref
        .read(classesRepositoryProvider)
        .reportPresence(
          classId: widget.classId,
          sessionId: widget.oneToOneSessionId,
          eventType: eventType,
        )
        .catchError((_) {});
  }

  void _maybeStartHeartbeat() {
    if (widget.oneToOneSessionId == null) return;
    _heartbeatTimer?.cancel();
    _heartbeatTimer = Timer.periodic(const Duration(seconds: 60), (_) {
      final repo = ref.read(classesRepositoryProvider);
      repo.sendHeartbeat(widget.oneToOneSessionId!, bothPresent: true);
    });
  }

  void _handleEnd() {
    if (_ended || !mounted) return;
    _ended = true;
    _reportPresence('leave');
    _heartbeatTimer?.cancel();
    ref.read(scheduleProvider.notifier).refresh();
    if (Navigator.of(context).canPop()) {
      Navigator.of(context).pop();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _reportPresence('leave');
    _heartbeatTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // The Jitsi SDK renders its own native call UI over this screen once
    // joined; this scaffold is only visible briefly while connecting.
    return Scaffold(
      backgroundColor: Colors.black,
      body: Center(
        child: _statusMessage == null
            ? const SizedBox.shrink()
            : Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const CircularProgressIndicator(color: Colors.white),
                  const SizedBox(height: 16),
                  Text(
                    _statusMessage!,
                    style: const TextStyle(color: Colors.white),
                  ),
                ],
              ),
      ),
    );
  }
}
