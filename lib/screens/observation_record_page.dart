import 'dart:async';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';
import 'package:record/record.dart';
import 'package:uuid/uuid.dart';

import 'package:morro_do_peo/components/responsive_body.dart';
import 'package:morro_do_peo/state/app_session.dart';
import 'package:morro_do_peo/theme.dart';

class ObservationRecordPage extends StatefulWidget {
  const ObservationRecordPage({super.key});

  @override
  State<ObservationRecordPage> createState() => _ObservationRecordPageState();
}

class _ObservationRecordPageState extends State<ObservationRecordPage> {
  final AudioRecorder _recorder = AudioRecorder();
  final AudioPlayer _player = AudioPlayer();
  StreamSubscription<PlayerState>? _playerSub;

  bool _recording = false;
  bool _recorded = false;
  bool _playing = false;
  int _seconds = 0;
  Timer? _timer;
  String? _filePath;

  @override
  void initState() {
    super.initState();
    _playerSub = _player.onPlayerStateChanged.listen((state) {
      if (!mounted) return;
      setState(() => _playing = state == PlayerState.playing);
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _playerSub?.cancel();
    _recorder.dispose();
    _player.dispose();
    super.dispose();
  }

  Future<void> _start() async {
    final hasPermission = await _recorder.hasPermission();
    if (!hasPermission || !mounted) return;

    final dir = await getApplicationDocumentsDirectory();
    final path = '${dir.path}/${const Uuid().v4()}.m4a';

    _timer?.cancel();
    setState(() {
      _recording = true;
      _recorded = false;
      _seconds = 0;
      _filePath = null;
    });

    await _recorder.start(
      const RecordConfig(encoder: AudioEncoder.aacLc),
      path: path,
    );

    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      setState(() => _seconds++);
    });
  }

  Future<void> _stop() async {
    _timer?.cancel();
    final path = await _recorder.stop();
    if (!mounted) return;
    setState(() {
      _recording = false;
      _recorded = true;
      _filePath = path;
    });
    if (path != null) {
      context.read<AppSession>().setObservation(
            ObservationAudio(localFile: path, durationSeconds: _seconds.clamp(1, 3600)),
          );
    }
  }

  Future<void> _reset() async {
    _timer?.cancel();
    await _player.stop();
    if (_recording) await _recorder.stop();
    if (!mounted) return;
    context.read<AppSession>().setObservation(null);
    setState(() {
      _recording = false;
      _recorded = false;
      _seconds = 0;
      _filePath = null;
    });
  }

  Future<void> _togglePlayback() async {
    if (_playing) {
      await _player.stop();
    } else if (_filePath != null) {
      await _player.play(DeviceFileSource(_filePath!));
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, size: 28),
          onPressed: () => context.pop(),
        ),
        title: const Text('Gravar observação'),
      ),
      body: SafeArea(
        child: ResponsiveBody(
          maxWidth: 560,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Gravar observação',
                style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w900),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: AppSpacing.sm),
              Text(
                'Fale o que aconteceu no campo.',
                style: theme.textTheme.bodyLarge?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: AppSpacing.xl),
              _RecordingIndicator(recording: _recording, recorded: _recorded, seconds: _seconds),
              const Spacer(),
              if (!_recorded) ...[
                SizedBox(
                  height: 72,
                  child: FilledButton.icon(
                    onPressed: _recording ? _stop : _start,
                    style: FilledButton.styleFrom(
                      backgroundColor: theme.colorScheme.primary,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.xl)),
                    ),
                    icon: Icon(_recording ? Icons.stop : Icons.mic, color: theme.colorScheme.onPrimary, size: 28),
                    label: Text(
                      _recording ? 'Parar gravação' : 'Iniciar gravação',
                      style: theme.textTheme.titleMedium?.copyWith(color: theme.colorScheme.onPrimary, fontWeight: FontWeight.w900),
                    ),
                  ),
                ),
              ] else ...[
                SizedBox(
                  height: 64,
                  child: OutlinedButton.icon(
                    onPressed: _togglePlayback,
                    style: OutlinedButton.styleFrom(
                      foregroundColor: theme.colorScheme.primary,
                      side: BorderSide(color: theme.colorScheme.primary.withValues(alpha: 0.28), width: 2),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.xl)),
                    ),
                    icon: Icon(_playing ? Icons.stop : Icons.play_arrow, color: theme.colorScheme.primary, size: 28),
                    label: Text(
                      _playing ? 'Parar áudio' : 'Ouvir áudio',
                      style: theme.textTheme.titleMedium?.copyWith(color: theme.colorScheme.primary, fontWeight: FontWeight.w900),
                    ),
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
                SizedBox(
                  height: 64,
                  child: OutlinedButton.icon(
                    onPressed: _reset,
                    style: OutlinedButton.styleFrom(
                      foregroundColor: theme.colorScheme.primary,
                      side: BorderSide(color: theme.colorScheme.primary.withValues(alpha: 0.28), width: 2),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.xl)),
                    ),
                    icon: Icon(Icons.refresh, color: theme.colorScheme.primary, size: 24),
                    label: Text('Gravar novamente', style: theme.textTheme.titleMedium?.copyWith(color: theme.colorScheme.primary, fontWeight: FontWeight.w900)),
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
                SizedBox(
                  height: 72,
                  child: FilledButton.icon(
                    onPressed: () => context.go('/review'),
                    style: FilledButton.styleFrom(
                      backgroundColor: theme.colorScheme.primary,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.xl)),
                    ),
                    icon: Icon(Icons.arrow_forward, color: theme.colorScheme.onPrimary, size: 24),
                    label: Text('Continuar', style: theme.textTheme.titleMedium?.copyWith(color: theme.colorScheme.onPrimary, fontWeight: FontWeight.w900)),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _RecordingIndicator extends StatelessWidget {
  final bool recording;
  final bool recorded;
  final int seconds;

  const _RecordingIndicator({required this.recording, required this.recorded, required this.seconds});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final Color bg;
    final Color border;
    final Color iconColor;
    final IconData icon;
    final String label;

    if (recording) {
      bg = AppColors.errorLight;
      border = AppColors.error.withValues(alpha: 0.35);
      iconColor = AppColors.error;
      icon = Icons.mic;
      label = 'Gravando... ${seconds}s';
    } else if (recorded) {
      bg = AppColors.successLight;
      border = AppColors.success.withValues(alpha: 0.35);
      iconColor = AppColors.success;
      icon = Icons.check_circle;
      label = 'Gravado (${seconds}s)';
    } else {
      bg = theme.colorScheme.surface;
      border = theme.colorScheme.primary.withValues(alpha: 0.16);
      iconColor = theme.colorScheme.primary;
      icon = Icons.mic_none;
      label = 'Pronto para gravar';
    }

    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(AppRadius.xl),
        border: Border.all(color: border, width: 2),
      ),
      child: Row(
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: iconColor.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(AppRadius.xl),
            ),
            child: Icon(icon, color: iconColor, size: 30),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900)),
                if (!recording && !recorded)
                  const SizedBox(height: AppSpacing.xs),
                if (!recording && !recorded)
                  Text('Toque em "Iniciar gravação"', style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
