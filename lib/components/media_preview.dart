import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

import 'package:morro_do_peo/theme.dart';

/// Resolves a possibly-relative media URL (relative to `origin`) into an
/// absolute one, the same way audio/photo/video evidence URLs are served.
String absoluteMediaUrl({required String origin, required String url}) {
  final u = url.trim();
  if (u.startsWith('http://') || u.startsWith('https://')) return u;
  final o = origin.trim();
  if (o.isEmpty) return u;
  return o.endsWith('/') ? '${o.substring(0, o.length - 1)}${u.startsWith('/') ? u : '/$u'}' : '$o${u.startsWith('/') ? u : '/$u'}';
}

/// Shows a full-screen, pinch-to-zoom preview of a (possibly authenticated)
/// image URL.
void showFullscreenImage(BuildContext context, {required String url, required Map<String, String> headers}) {
  showDialog<void>(
    context: context,
    barrierColor: Colors.black87,
    builder: (context) => Dialog(
      insetPadding: EdgeInsets.zero,
      backgroundColor: Colors.transparent,
      child: Stack(
        children: [
          Positioned.fill(
            child: InteractiveViewer(
              child: Center(
                child: Image.network(
                  url,
                  headers: headers,
                  errorBuilder: (context, error, stack) => const Icon(Icons.broken_image, color: Colors.white, size: 64),
                ),
              ),
            ),
          ),
          Positioned(
            top: AppSpacing.lg,
            right: AppSpacing.lg,
            child: IconButton(
              onPressed: () => Navigator.of(context).pop(),
              icon: const Icon(Icons.close, color: Colors.white, size: 32),
            ),
          ),
        ],
      ),
    ),
  );
}

/// Inline, tap-to-play/pause video preview for a (possibly authenticated)
/// network video URL.
class EvidenceVideoPlayer extends StatefulWidget {
  final String url;
  final Map<String, String> headers;
  const EvidenceVideoPlayer({super.key, required this.url, required this.headers});

  @override
  State<EvidenceVideoPlayer> createState() => _EvidenceVideoPlayerState();
}

class _EvidenceVideoPlayerState extends State<EvidenceVideoPlayer> {
  VideoPlayerController? _controller;
  bool _initializing = true;
  bool _failed = false;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    try {
      final controller = VideoPlayerController.networkUrl(Uri.parse(widget.url), httpHeaders: widget.headers);
      await controller.initialize();
      if (!mounted) {
        controller.dispose();
        return;
      }
      setState(() {
        _controller = controller;
        _initializing = false;
      });
    } catch (e) {
      debugPrint('Video init failed: $e');
      if (!mounted) return;
      setState(() {
        _failed = true;
        _initializing = false;
      });
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    if (_initializing) {
      return Container(height: 160, alignment: Alignment.center, child: const CircularProgressIndicator());
    }
    final controller = _controller;
    if (_failed || controller == null) {
      return Container(
        height: 80,
        alignment: Alignment.center,
        decoration: BoxDecoration(color: theme.colorScheme.surfaceContainerHighest, borderRadius: BorderRadius.circular(AppRadius.lg)),
        child: Text('Não foi possível carregar o vídeo.', style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
      );
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(AppRadius.lg),
      child: AspectRatio(
        aspectRatio: controller.value.aspectRatio == 0 ? 16 / 9 : controller.value.aspectRatio,
        child: GestureDetector(
          onTap: () => setState(() => controller.value.isPlaying ? controller.pause() : controller.play()),
          child: Stack(
            alignment: Alignment.center,
            children: [
              VideoPlayer(controller),
              ValueListenableBuilder<VideoPlayerValue>(
                valueListenable: controller,
                builder: (context, value, _) => value.isPlaying
                    ? const SizedBox.shrink()
                    : Container(
                        decoration: const BoxDecoration(color: Colors.black45, shape: BoxShape.circle),
                        child: const Icon(Icons.play_arrow, color: Colors.white, size: 48),
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
