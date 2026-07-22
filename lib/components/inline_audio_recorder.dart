import 'dart:async';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';
import 'package:uuid/uuid.dart';

import 'package:morro_do_peo/theme.dart';

/// Compact record/stop/play control for attaching a short audio evidence
/// file, embeddable inline (e.g. one per checklist question) unlike
/// [ObservationRecordPage], which is a dedicated full-screen flow.
///
/// Records live audio via `record` instead of picking an existing file, so
/// it fits the same slot a `FilePicker` audio button used to occupy while
/// staying consistent with how the rest of the app captures audio.
class InlineAudioRecorder extends StatefulWidget {
  final XFile? value;
  final ValueChanged<XFile?> onChanged;
  final String idleLabel;

  const InlineAudioRecorder({
    super.key,
    required this.value,
    required this.onChanged,
    this.idleLabel = 'Gravar áudio',
  });

  @override
  State<InlineAudioRecorder> createState() => _InlineAudioRecorderState();
}

class _InlineAudioRecorderState extends State<InlineAudioRecorder> {
  final AudioRecorder _recorder = AudioRecorder();
  final AudioPlayer _player = AudioPlayer();
  StreamSubscription<PlayerState>? _playerSub;

  bool _recording = false;
  bool _playing = false;
  int _seconds = 0;
  Timer? _timer;

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
      _seconds = 0;
    });

    await _recorder.start(const RecordConfig(encoder: AudioEncoder.aacLc), path: path);

    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      setState(() => _seconds++);
    });
  }

  Future<void> _stop() async {
    _timer?.cancel();
    final path = await _recorder.stop();
    if (!mounted) return;
    setState(() => _recording = false);
    if (path != null) widget.onChanged(XFile(path));
  }

  Future<void> _togglePlayback() async {
    final file = widget.value;
    if (file == null) return;
    if (_playing) {
      await _player.stop();
    } else {
      await _player.play(DeviceFileSource(file.path));
    }
  }

  Future<void> _discard() async {
    await _player.stop();
    widget.onChanged(null);
    setState(() => _seconds = 0);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final recorded = widget.value != null;

    if (_recording) {
      return OutlinedButton.icon(
        onPressed: _stop,
        style: OutlinedButton.styleFrom(foregroundColor: AppColors.error, side: const BorderSide(color: AppColors.error, width: 2)),
        icon: const Icon(Icons.stop),
        label: Text('Gravando... ${_seconds}s — toque para parar', overflow: TextOverflow.ellipsis),
      );
    }

    if (!recorded) {
      return OutlinedButton.icon(
        onPressed: _start,
        icon: Icon(Icons.mic, color: theme.colorScheme.primary),
        label: Text(widget.idleLabel, overflow: TextOverflow.ellipsis),
      );
    }

    return Row(
      children: [
        Expanded(
          child: OutlinedButton.icon(
            onPressed: _togglePlayback,
            icon: Icon(_playing ? Icons.stop : Icons.play_arrow, color: theme.colorScheme.primary),
            label: Text(_playing ? 'Parar' : 'Ouvir áudio gravado', overflow: TextOverflow.ellipsis),
          ),
        ),
        const SizedBox(width: AppSpacing.sm),
        IconButton(
          onPressed: _discard,
          icon: Icon(Icons.refresh, color: theme.colorScheme.primary),
          tooltip: 'Gravar novamente',
        ),
      ],
    );
  }
}
