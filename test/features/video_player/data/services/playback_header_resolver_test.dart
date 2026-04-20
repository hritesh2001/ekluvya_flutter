import 'package:ekluvya_app/features/signed_cookie/data/models/signed_cookie_model.dart';
import 'package:ekluvya_app/features/signed_cookie/domain/repositories/signed_cookie_repository.dart';
import 'package:ekluvya_app/features/video_player/data/services/playback_header_resolver.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('PlaybackHeaderResolver', () {
    test('normalize converts CloudFront headers into a Cookie header', () {
      final headers = PlaybackHeaderResolver.normalize({
        'Authorization': 'Bearer token',
        'CloudFront-Key-Pair-Id': 'key-pair',
        'CloudFront-Policy': 'policy',
        'CloudFront-Signature': 'signature',
      });

      expect(headers['Authorization'], 'Bearer token');
      expect(_cookieParts(headers['Cookie']), {
        'CloudFront-Key-Pair-Id': 'key-pair',
        'CloudFront-Policy': 'policy',
        'CloudFront-Signature': 'signature',
      });
      expect(headers.containsKey('CloudFront-Key-Pair-Id'), isFalse);
      expect(headers.containsKey('CloudFront-Policy'), isFalse);
      expect(headers.containsKey('CloudFront-Signature'), isFalse);
    });

    test('resolve injects fresh cookies for protected playback URLs', () async {
      final repository = _FakeSignedCookieRepository(
        result: SignedCookieModel(
          keyPairId: 'fresh-key',
          policy: 'fresh-policy',
          signature: 'fresh-signature',
          expires: DateTime.now().add(const Duration(minutes: 30)),
        ),
      );
      final resolver = PlaybackHeaderResolver(
        signedCookieRepository: repository,
      );

      final headers = await resolver.resolve(
        playbackUrl: 'https://cdn.ekluvya.guru/tutorix/demo/playlist.m3u8',
        initialHeaders: const {
          'CloudFront-Key-Pair-Id': 'stale-key',
          'CloudFront-Policy': 'stale-policy',
          'CloudFront-Signature': 'stale-signature',
        },
      );

      expect(repository.callCount, 1);
      expect(_cookieParts(headers['Cookie']), {
        'CloudFront-Key-Pair-Id': 'fresh-key',
        'CloudFront-Policy': 'fresh-policy',
        'CloudFront-Signature': 'fresh-signature',
      });
    });

    test(
      'resolve skips signed-cookie refresh for non-protected hosts',
      () async {
        final repository = _FakeSignedCookieRepository(
          result: SignedCookieModel(
            keyPairId: 'unused-key',
            policy: 'unused-policy',
            signature: 'unused-signature',
            expires: DateTime.now().add(const Duration(minutes: 30)),
          ),
        );
        final resolver = PlaybackHeaderResolver(
          signedCookieRepository: repository,
        );

        final headers = await resolver.resolve(
          playbackUrl: 'https://example.com/public/playlist.m3u8',
          initialHeaders: const {'Authorization': 'Bearer token'},
        );

        expect(repository.callCount, 0);
        expect(headers, {'Authorization': 'Bearer token'});
      },
    );
  });
}

Map<String, String> _cookieParts(String? header) {
  if (header == null || header.trim().isEmpty) {
    return const {};
  }

  final cookies = <String, String>{};
  for (final segment in header.split(';')) {
    final trimmed = segment.trim();
    if (trimmed.isEmpty) {
      continue;
    }

    final separatorIndex = trimmed.indexOf('=');
    if (separatorIndex <= 0) {
      continue;
    }

    final key = trimmed.substring(0, separatorIndex).trim();
    final value = trimmed.substring(separatorIndex + 1).trim();
    if (key.isEmpty || value.isEmpty) {
      continue;
    }

    cookies[key] = value;
  }

  return cookies;
}

class _FakeSignedCookieRepository implements SignedCookieRepository {
  _FakeSignedCookieRepository({required this.result});

  final SignedCookieModel result;
  int callCount = 0;

  @override
  Future<SignedCookieModel> getSignedCookies() async {
    callCount++;
    return result;
  }
}
