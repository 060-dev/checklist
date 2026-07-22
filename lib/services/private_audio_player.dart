import 'dart:io';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

import 'package:morro_do_peo/services/mobile_api_client.dart';

@immutable
class PrivateAudioRef {
  final String sha256;

  /// Relative URL to ORIGIN, e.g. `/api/mobile/v1/.../audio`.
  final String url;
  const PrivateAudioRef({required this.sha256, required this.url});
}

/// Downloads and plays *private* audios that require `Authorization`.
///
/// - Downloads bytes via [MobileApiClient] so the header is included.
/// - Caches audio on disk by `sha256`.
/// - Ensures only one audio plays at a time.
class PrivateAudioPlayer {
  static final PrivateAudioPlayer instance = PrivateAudioPlayer._();
  PrivateAudioPlayer._();

  final AudioPlayer _player = AudioPlayer();

  // Web can't reliably play files from `path_provider`, so we keep a small
  // in-memory cache.
  final Map<String, Uint8List> _webCache = <String, Uint8List>{};

  Future<void> stop() async {
    try {
      await _player.stop();
    } catch (e) {
      debugPrint('Audio stop failed: $e');
    }
  }

  Future<void> dispose() async {
    await stop();
    await _player.dispose();
  }

  String _extensionFromUrl(String url) {
    try {
      final u = Uri.parse(url);
      final seg = u.pathSegments.isEmpty ? '' : u.pathSegments.last;
      final dot = seg.lastIndexOf('.');
      if (dot <= 0 || dot == seg.length - 1) return 'audio';
      final ext = seg.substring(dot + 1).toLowerCase();
      // Basic allowlist; unknown types still use a generic extension.
      const ok = {'mp3', 'wav', 'ogg', 'm4a', 'webm', 'aac', 'flac'};
      return ok.contains(ext) ? ext : 'audio';
    } catch (_) {
      return 'audio';
    }
  }

  Future<File> _cacheFileForSha(String sha256, {required String url}) async {
    final dir = await getApplicationDocumentsDirectory();
    final cacheDir = Directory('${dir.path}/private_audio_cache_v1');
    if (!await cacheDir.exists()) await cacheDir.create(recursive: true);
    final ext = _extensionFromUrl(url);
    return File('${cacheDir.path}/$sha256.$ext');
  }

  String _toAbsoluteUrl({required String origin, required String url}) {
    final u = url.trim();
    if (u.startsWith('http://') || u.startsWith('https://')) return u;
    final o = origin.trim();
    if (o.isEmpty) return u;
    return o.endsWith('/')
        ? '${o.substring(0, o.length - 1)}${u.startsWith('/') ? u : '/$u'}'
        : '$o${u.startsWith('/') ? u : '/$u'}';
  }

  Future<Uint8List?> _ensureCachedWeb({
    required MobileApiClient client,
    required String origin,
    required PrivateAudioRef ref,
  }) async {
    try {
      final sha = ref.sha256.trim();
      final url = ref.url.trim();
      if (sha.isEmpty || url.isEmpty) return null;

      final cached = _webCache[sha];
      if (cached != null) return cached;

      final abs = _toAbsoluteUrl(origin: origin, url: url);
      final Uint8List bytes = await client.getBinaryAbsoluteUrl(abs);
      _webCache[sha] = bytes;
      return bytes;
    } catch (e) {
      debugPrint('Audio cache/download failed (web): $e');
      return null;
    }
  }

  Future<File?> _ensureCachedIo({
    required MobileApiClient client,
    required String origin,
    required PrivateAudioRef ref,
  }) async {
    try {
      final sha = ref.sha256.trim();
      final url = ref.url.trim();
      if (sha.isEmpty || url.isEmpty) return null;

      final f = await _cacheFileForSha(sha, url: url);
      if (await f.exists()) return f;

      final abs = _toAbsoluteUrl(origin: origin, url: url);
      final Uint8List bytes = await client.getBinaryAbsoluteUrl(abs);
      await f.writeAsBytes(bytes, flush: true);
      return f;
    } catch (e) {
      debugPrint('Audio cache/download failed (io): $e');
      return null;
    }
  }

  Future<bool> play({
    required MobileApiClient client,
    required String origin,
    required PrivateAudioRef ref,
  }) async {
    try {
      // Never overlap audios.
      await stop();

      if (kIsWeb) {
        final bytes = await _ensureCachedWeb(
          client: client,
          origin: origin,
          ref: ref,
        );
        if (bytes == null || bytes.isEmpty) return false;
        await _player.play(BytesSource(bytes));
      } else {
        final f = await _ensureCachedIo(
          client: client,
          origin: origin,
          ref: ref,
        );
        if (f == null || !await f.exists()) return false;
        await _player.play(DeviceFileSource(f.path));
      }
      return true;
    } catch (e) {
      debugPrint('Audio play failed: $e');
      return false;
    }
  }
}
