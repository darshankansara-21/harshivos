import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';

/// Helper the Life Skills Builder uses so parents can attach their own photos
/// (bathroom, bedroom, temple, restaurant…) to routine steps.
///
/// Picked files are copied into an app-owned folder so the path survives
/// restarts and cache clears. Fully offline — no network involved.
class RoutinePhotoStore {
  const RoutinePhotoStore._();

  static final ImagePicker _picker = ImagePicker();
  static const Uuid _uuid = Uuid();

  /// Picks an image from the given [source] and returns a stable, app-owned
  /// path. Returns `null` if the parent cancels or picking is unavailable.
  static Future<String?> pick(ImageSource source) async {
    if (kIsWeb) {
      // On web there is no persistent file path; return the picker path as-is
      // (blob URL) so at least the preview works within the session.
      final picked = await _picker.pickImage(source: source, maxWidth: 1600);
      return picked?.path;
    }
    final XFile? picked = await _picker.pickImage(
      source: source,
      maxWidth: 1600,
      imageQuality: 85,
    );
    if (picked == null) return null;
    return _copyToAppDir(picked);
  }

  static Future<String> _copyToAppDir(XFile picked) async {
    final Directory docs = await getApplicationDocumentsDirectory();
    final Directory photos = Directory('${docs.path}/routine_photos');
    if (!photos.existsSync()) {
      photos.createSync(recursive: true);
    }
    final String ext = _extensionOf(picked.path);
    final String dest = '${photos.path}/${_uuid.v4()}$ext';
    await File(picked.path).copy(dest);
    return dest;
  }

  static String _extensionOf(String path) {
    final int dot = path.lastIndexOf('.');
    if (dot == -1 || dot < path.length - 6) return '.jpg';
    return path.substring(dot);
  }
}
