import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Full-screen "incoming call" prompt shown to a student when their teacher
/// starts a session. Rings (haptics + system alert sound) until answered,
/// declined, or [ringDuration] elapses. Resolves to true when the student
/// taps Join.
Future<bool> showIncomingCallDialog(
  BuildContext context, {
  required String title,
  required String callerName,
  Duration ringDuration = const Duration(seconds: 45),
}) async {
  final joined = await showGeneralDialog<bool>(
    context: context,
    barrierDismissible: false,
    barrierLabel: 'Incoming call',
    barrierColor: Colors.black87,
    pageBuilder: (_, _, _) => _IncomingCallView(
      title: title,
      callerName: callerName,
      ringDuration: ringDuration,
    ),
  );
  return joined ?? false;
}

class _IncomingCallView extends StatefulWidget {
  const _IncomingCallView({
    required this.title,
    required this.callerName,
    required this.ringDuration,
  });

  final String title;
  final String callerName;
  final Duration ringDuration;

  @override
  State<_IncomingCallView> createState() => _IncomingCallViewState();
}

class _IncomingCallViewState extends State<_IncomingCallView> {
  Timer? _ringTimer;
  Timer? _timeout;

  @override
  void initState() {
    super.initState();
    _ring();
    _ringTimer = Timer.periodic(const Duration(milliseconds: 1500), (_) => _ring());
    _timeout = Timer(widget.ringDuration, () => _close(false));
  }

  void _ring() {
    HapticFeedback.heavyImpact();
    SystemSound.play(SystemSoundType.alert);
  }

  void _close(bool joined) {
    _ringTimer?.cancel();
    _timeout?.cancel();
    if (mounted && Navigator.of(context).canPop()) {
      Navigator.of(context).pop(joined);
    }
  }

  @override
  void dispose() {
    _ringTimer?.cancel();
    _timeout?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      child: Scaffold(
        backgroundColor: const Color(0xFF101418),
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 40),
            child: Column(
              children: [
                const Spacer(),
                const Text('Incoming class call',
                    style: TextStyle(color: Colors.white70, fontSize: 16)),
                const SizedBox(height: 24),
                const CircleAvatar(
                  radius: 52,
                  backgroundColor: Color(0xFF1E88E5),
                  child: Icon(Icons.person, size: 56, color: Colors.white),
                ),
                const SizedBox(height: 24),
                Text(widget.callerName,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 26,
                        fontWeight: FontWeight.w600)),
                const SizedBox(height: 8),
                Text('started "${widget.title}"',
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: Colors.white70, fontSize: 16)),
                const Spacer(),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    _CallButton(
                      color: Colors.red,
                      icon: Icons.call_end,
                      label: 'Decline',
                      onTap: () => _close(false),
                    ),
                    _CallButton(
                      color: Colors.green,
                      icon: Icons.videocam,
                      label: 'Join',
                      onTap: () => _close(true),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _CallButton extends StatelessWidget {
  const _CallButton({
    required this.color,
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final Color color;
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Material(
          color: color,
          shape: const CircleBorder(),
          child: InkWell(
            customBorder: const CircleBorder(),
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.all(22),
              child: Icon(icon, color: Colors.white, size: 32),
            ),
          ),
        ),
        const SizedBox(height: 8),
        Text(label, style: const TextStyle(color: Colors.white)),
      ],
    );
  }
}
