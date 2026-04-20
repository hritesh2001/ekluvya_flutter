import 'package:flutter/foundation.dart';

import '../../../../core/utils/logger.dart';
import '../../../signed_cookie/data/models/signed_cookie_model.dart';
import '../../../signed_cookie/domain/repositories/signed_cookie_repository.dart';
import 'playback_cookie_store.dart';

/// Resolves the final HTTP headers required for a playback session.
///
/// Responsibilities:
/// - Normalize incoming headers from different navigation flows.
/// - Convert CloudFront cookie key/value pairs into a valid `Cookie` header.
/// - Refresh signed cookies on demand for protected CDN playback URLs.
class PlaybackHeaderResolver {
  static const _tag = 'PlaybackHeaderResolver';
  static const _cookieHeaderName = 'Cookie';
  static const _cloudFrontKeyPairId = 'CloudFront-Key-Pair-Id';
  static const _cloudFrontPolicy = 'CloudFront-Policy';
  static const _cloudFrontSignature = 'CloudFront-Signature';

  static const Set<String> _protectedHosts = {'cdn.ekluvya.guru'};

  PlaybackHeaderResolver({
    SignedCookieRepository? signedCookieRepository,
    PlaybackCookieStore? playbackCookieStore,
  }) : _signedCookieRepository = signedCookieRepository,
       _playbackCookieStore = playbackCookieStore;

  final SignedCookieRepository? _signedCookieRepository;
  final PlaybackCookieStore? _playbackCookieStore;

  Future<Map<String, String>> resolve({
    required String playbackUrl,
    Map<String, String> initialHeaders = const {},
  }) async {
    final normalizedHeaders = normalize(initialHeaders);
    if (!requiresSignedCookies(playbackUrl)) {
      return normalizedHeaders;
    }

    final repository = _signedCookieRepository;
    if (repository == null) {
      if (normalizedHeaders.containsKey(_cookieHeaderName)) {
        return normalizedHeaders;
      }
      throw const PlaybackAuthorizationException(
        'Unable to authorize video playback right now. Please try again.',
      );
    }

    try {
      final signedCookies = await repository.getSignedCookies();
      if (!_hasUsableSignedCookies(signedCookies)) {
        if (normalizedHeaders.containsKey(_cookieHeaderName)) {
          return normalizedHeaders;
        }
        throw const PlaybackAuthorizationException(
          'Video authorization is temporarily unavailable. Please try again.',
        );
      }

      await _playbackCookieStore?.syncCloudFrontCookies(
        playbackUrl: playbackUrl,
        signedCookies: signedCookies,
      );

      return normalize(
        initialHeaders,
        overrideCookieHeader: signedCookies.cookieHeader,
      );
    } catch (error, stackTrace) {
      AppLogger.warning(
        _tag,
        'Signed cookie refresh failed for $playbackUrl: $error',
      );
      AppLogger.error(
        _tag,
        'Signed cookie refresh stack trace',
        error,
        stackTrace,
      );

      if (normalizedHeaders.containsKey(_cookieHeaderName)) {
        return normalizedHeaders;
      }

      if (error is PlaybackAuthorizationException) {
        rethrow;
      }

      throw const PlaybackAuthorizationException(
        'Unable to authorize video playback right now. Please try again.',
      );
    }
  }

  static bool requiresSignedCookies(String playbackUrl) {
    final uri = Uri.tryParse(playbackUrl);
    final host = uri?.host.toLowerCase() ?? '';
    if (host.isEmpty) {
      return false;
    }

    for (final protectedHost in _protectedHosts) {
      if (host == protectedHost || host.endsWith('.$protectedHost')) {
        return true;
      }
    }

    return false;
  }

  @visibleForTesting
  static Map<String, String> normalize(
    Map<String, String> headers, {
    String? overrideCookieHeader,
  }) {
    final normalizedHeaders = <String, String>{};
    String? cookieHeader;
    final cloudFrontCookies = <String, String>{};

    for (final entry in headers.entries) {
      final key = entry.key.trim();
      final value = entry.value.trim();
      if (key.isEmpty || value.isEmpty) {
        continue;
      }

      if (_matchesHeaderName(key, _cookieHeaderName)) {
        cookieHeader = value;
        continue;
      }

      if (_isCloudFrontCookieKey(key)) {
        cloudFrontCookies[key] = value;
        continue;
      }

      normalizedHeaders[key] = value;
    }

    final mergedCookieHeader = _mergeCookieHeaders(
      cookieHeader,
      _buildCookieHeader(cloudFrontCookies),
      overrideCookieHeader,
    );

    if (mergedCookieHeader != null && mergedCookieHeader.isNotEmpty) {
      normalizedHeaders[_cookieHeaderName] = mergedCookieHeader;
    }

    return normalizedHeaders;
  }

  static bool _hasUsableSignedCookies(SignedCookieModel model) =>
      model.isValid &&
      model.keyPairId.trim().isNotEmpty &&
      model.policy.trim().isNotEmpty &&
      model.signature.trim().isNotEmpty;

  static bool _isCloudFrontCookieKey(String key) =>
      _matchesHeaderName(key, _cloudFrontKeyPairId) ||
      _matchesHeaderName(key, _cloudFrontPolicy) ||
      _matchesHeaderName(key, _cloudFrontSignature);

  static bool _matchesHeaderName(String value, String expected) =>
      value.toLowerCase() == expected.toLowerCase();

  static String? _buildCookieHeader(Map<String, String> cookies) {
    if (cookies.isEmpty) {
      return null;
    }

    final parts = <String>[];
    for (final entry in cookies.entries) {
      final key = entry.key.trim();
      final value = entry.value.trim();
      if (key.isEmpty || value.isEmpty) {
        continue;
      }
      parts.add('$key=$value');
    }

    if (parts.isEmpty) {
      return null;
    }

    return parts.join('; ');
  }

  static String? _mergeCookieHeaders(
    String? currentHeader,
    String? cloudFrontHeader,
    String? overrideHeader,
  ) {
    final mergedCookies = <String, String>{};

    for (final header in [currentHeader, cloudFrontHeader, overrideHeader]) {
      if (header == null || header.trim().isEmpty) {
        continue;
      }

      final segments = header.split(';');
      for (final segment in segments) {
        final part = segment.trim();
        if (part.isEmpty) {
          continue;
        }

        final separatorIndex = part.indexOf('=');
        if (separatorIndex <= 0) {
          continue;
        }

        final key = part.substring(0, separatorIndex).trim();
        final value = part.substring(separatorIndex + 1).trim();
        if (key.isEmpty || value.isEmpty) {
          continue;
        }

        mergedCookies[key] = value;
      }
    }

    if (mergedCookies.isEmpty) {
      return null;
    }

    return mergedCookies.entries
        .map((entry) => '${entry.key}=${entry.value}')
        .join('; ');
  }
}

class PlaybackAuthorizationException implements Exception {
  const PlaybackAuthorizationException(this.message);

  final String message;

  @override
  String toString() => message;
}
