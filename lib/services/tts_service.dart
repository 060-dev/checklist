import 'package:flutter/foundation.dart';
import 'package:flutter_tts/flutter_tts.dart';

class TtsService {
  TtsService._();

  static final TtsService instance = TtsService._();

  final FlutterTts _tts = FlutterTts();
  bool _configured = false;

  Future<void> _ensureConfigured() async {
    if (_configured) return;
    try {
      await _tts.setLanguage('pt-BR');
      await _tts.setSpeechRate(0.48);
      await _tts.setPitch(1.0);
      // We avoid calling awaitSpeakCompletion here for broader compatibility.
      _configured = true;
    } catch (e) {
      debugPrint('TTS configure failed: $e');
    }
  }

  Future<void> speak(String text) async {
    final clean = text.trim();
    if (clean.isEmpty) return;
    try {
      await _ensureConfigured();
      await _tts.stop();
      await _tts.speak(clean);
    } catch (e) {
      debugPrint('TTS speak failed: $e');
    }
  }

  Future<void> stop() async {
    try {
      await _tts.stop();
    } catch (e) {
      debugPrint('TTS stop failed: $e');
    }
  }
}
