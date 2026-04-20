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

  /// True when the API returned all mandatory CloudFront cookie values.
  bool get hasRequiredCookies =>
      keyPairId.trim().isNotEmpty &&
      policy.trim().isNotEmpty &&
      signature.trim().isNotEmpty;

  /// True when the cookies are still within their validity window.
  bool get isValid => hasRequiredCookies && DateTime.now().isBefore(expires);

  /// Ready-to-use map of CloudFront cookie name to value.
  Map<String, String> get cookieMap => hasRequiredCookies
      ? {
          'CloudFront-Key-Pair-Id': keyPairId,
          'CloudFront-Policy': policy,
          'CloudFront-Signature': signature,
        }
      : const {};

  /// Single `Cookie` header string for HTTP requests.
  String get cookieHeader => cookieMap.entries
      .map((entry) => '${entry.key}=${entry.value}')
      .join('; ');

  factory SignedCookieModel.fromJson(Map<String, dynamic> json) {
    final cookies = json['cookies'] as Map<String, dynamic>? ?? const {};
    return SignedCookieModel(
      keyPairId: cookies['CloudFront-Key-Pair-Id']?.toString().trim() ?? '',
      policy: cookies['CloudFront-Policy']?.toString().trim() ?? '',
      signature: cookies['CloudFront-Signature']?.toString().trim() ?? '',
      expires:
          DateTime.tryParse(json['expires']?.toString() ?? '') ??
          DateTime.now().add(const Duration(hours: 1)),
    );
  }
}
