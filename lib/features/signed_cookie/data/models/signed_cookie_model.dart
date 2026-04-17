/// CloudFront signed-cookie bundle returned by the get-signed-cookies API.
///
/// Pass [headers] as HTTP request headers when streaming Tutorix CDN videos.
class SignedCookieModel {
  final String keyPairId;
  final String policy;
  final String signature;
  final DateTime expires;

  const SignedCookieModel({
    required this.keyPairId,
    required this.policy,
    required this.signature,
    required this.expires,
  });

  /// True when the cookies are still within their validity window.
  bool get isValid => DateTime.now().isBefore(expires);

  /// Ready-to-use map of CloudFront cookie name → value.
  Map<String, String> get cookieMap => {
        'CloudFront-Key-Pair-Id': keyPairId,
        'CloudFront-Policy': policy,
        'CloudFront-Signature': signature,
      };

  /// Single `Cookie` header string for HTTP requests.
  String get cookieHeader => cookieMap.entries
      .map((e) => '${e.key}=${e.value}')
      .join('; ');

  factory SignedCookieModel.fromJson(Map<String, dynamic> json) {
    final cookies = json['cookies'] as Map<String, dynamic>? ?? {};
    return SignedCookieModel(
      keyPairId: cookies['CloudFront-Key-Pair-Id']?.toString() ?? '',
      policy: cookies['CloudFront-Policy']?.toString() ?? '',
      signature: cookies['CloudFront-Signature']?.toString() ?? '',
      expires: DateTime.tryParse(json['expires']?.toString() ?? '') ??
          DateTime.now().add(const Duration(hours: 1)),
    );
  }
}
