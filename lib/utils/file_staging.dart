import 'dart:io';

import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';

/// Copies a picker/recorder temp file path into a permanent staging
/// directory (`<app_docs>/queue_staged/`) so it survives past the original
/// temp file's lifetime and across app restarts while a queue item is
/// pending. Returns the new stable path.
Future<String> stageFileForQueue(String sourcePath) async {
  final dir = await getApplicationDocumentsDirectory();
  final stagingDir = Directory('${dir.path}/queue_staged');
  if (!await stagingDir.exists()) await stagingDir.create(recursive: true);

  final ext = sourcePath.contains('.') ? sourcePath.split('.').last : 'bin';
  final stagedPath = '${stagingDir.path}/${const Uuid().v4()}.$ext';
  await File(sourcePath).copy(stagedPath);
  return stagedPath;
}

/// Deletes a previously staged file after a successful send (or a
/// permanently-failed/cancelled queue item).
Future<void> deleteStagedFile(String stagedPath) async {
  try {
    final f = File(stagedPath);
    if (await f.exists()) await f.delete();
  } catch (_) {
    // Best-effort cleanup; a leftover staged file is harmless.
  }
}
