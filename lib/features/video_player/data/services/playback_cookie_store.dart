import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../../../../core/utils/logger.dart';
import '../../../signed_cookie/data/models/signed_cookie_model.dart';

/// Syncs protected playback cookies to the native HTTP stack when needed.
///
/// Android ExoPlayer uses the platform HTTP stack for HLS requests, so storing
/// CloudFront cookies natively improves reliability for master playlists and
/// nested chunk/audio requests.
class PlaybackCookieStore {
  static const _tag = 'PlaybackCookieStore';
  static const _channel = MethodChannel('ekluvya/video_player/cookies');

  Future<void> syncCloudFrontCookies({
    required String playbackUrl,
    required SignedCookieModel signedCookies,
  }) async {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) {
      return;
    }

    if (!signedCookies.hasRequiredCookies) {
      return;
    }

    try {
      await _channel
          .invokeMethod<void>('setCloudFrontCookies', <String, dynamic>{
            'url': playbackUrl,
            'cookies': signedCookies.cookieMap,
            'expiresAtMs': signedCookies.expires.toUtc().millisecondsSinceEpoch,
          });
      AppLogger.info(_tag, 'Synced CloudFront cookies for $playbackUrl');
    } on PlatformException catch (error, stackTrace) {
      AppLogger.warning(
        _tag,
        'Platform cookie sync failed: ${error.message ?? error.code}',
      );
      AppLogger.error(
        _tag,
        'Platform cookie sync stack trace',
        error,
        stackTrace,
      );
    } catch (error, stackTrace) {
      AppLogger.warning(
        _tag,
        'Unexpected platform cookie sync failure: $error',
      );
      AppLogger.error(
        _tag,
        'Platform cookie sync stack trace',
        error,
        stackTrace,
      );
    }
  }
}
