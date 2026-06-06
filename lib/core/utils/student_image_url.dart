import '../api/api_client.dart';

/// Resolves student profile image URL from API payload (admin uploads).
abstract final class StudentImageUrl {
  static const _directKeys = [
    'image',
    'photo',
    'profile_image',
    'profile_photo',
    'avatar',
    'image_url',
    'profile_image_url',
    'photo_url',
    'student_image',
    'picture',
    'thumbnail',
    'profile_picture',
  ];

  static String? fromStudent(Map<String, dynamic> student) {
    for (final key in _directKeys) {
      final resolved = _resolveValue(student[key]);
      if (resolved != null) return resolved;
    }

    final media = student['media'];
    if (media is List && media.isNotEmpty) {
      final first = media.first;
      if (first is Map) {
        final resolved = _resolveValue(first['url'] ?? first['original_url']);
        if (resolved != null) return resolved;
      }
    }

    final profile = student['profile'];
    if (profile is Map) {
      for (final key in _directKeys) {
        final resolved = _resolveValue(profile[key]);
        if (resolved != null) return resolved;
      }
    }

    return null;
  }

  static String? _resolveValue(dynamic value) {
    if (value == null) return null;
    if (value is Map) {
      return _resolveValue(value['url'] ?? value['original_url'] ?? value['path']);
    }
    final raw = value.toString().trim();
    if (raw.isEmpty || raw == 'null') return null;
    return _toAbsoluteUrl(raw);
  }

  static String _toAbsoluteUrl(String raw) {
    if (raw.startsWith('http://') || raw.startsWith('https://')) {
      return raw;
    }

    var path = raw;
    if (!path.startsWith('/')) path = '/$path';
    if (path.startsWith('/storage/')) {
      return '${kAppBaseUrl}storage${path.substring('/storage'.length)}';
    }
    if (path.startsWith('/public/storage/')) {
      return '${kAppBaseUrl}storage${path.substring('/public/storage'.length)}';
    }
    return '${kAppBaseUrl}storage$path';
  }
}
