import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../widgets/app_toast.dart';

// ── Constants ─────────────────────────────────────────────────────────────────

const _kPink = Color(0xFFE91E63);

/// Shown after the user taps "Pay ... to Subscribe" on the plans screen.
///
/// Instructs the user to copy the subscription URL and complete payment
/// in their browser (OTT web portal).
class SubscriptionRedirectScreen extends StatelessWidget {
  const SubscriptionRedirectScreen({
    super.key,
    this.subscriptionUrl = 'https://ott.ekluvya.guru/subscription',
  });

  final String subscriptionUrl;

  static Route<void> route({String? url}) => MaterialPageRoute<void>(
        fullscreenDialog: true,
        builder: (_) => SubscriptionRedirectScreen(
          subscriptionUrl:
              url ?? 'https://ott.ekluvya.guru/subscription',
        ),
      );

  @override
  Widget build(BuildContext context) {
    final topPad    = MediaQuery.paddingOf(context).top;
    final bottomPad = MediaQuery.paddingOf(context).bottom;

    return Scaffold(
      backgroundColor: Colors.white,
      body: Stack(
        children: [
          // ── Close button ─────────────────────────────────────────────
          Positioned(
            top: topPad + 8,
            right: 8,
            child: IconButton(
              icon: const Icon(Icons.close_rounded,
                  size: 24, color: Color(0xFF333333)),
              onPressed: () => Navigator.of(context).pop(),
            ),
          ),

          // ── Scrollable content ───────────────────────────────────────
          SingleChildScrollView(
            padding: EdgeInsets.fromLTRB(
                24, topPad + 56, 24, bottomPad + 32),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Logo
                Center(
                  child: _EkluvyaLogo(),
                ),
                const SizedBox(height: 40),

                // Title
                RichText(
                  text: const TextSpan(
                    style: TextStyle(
                      color: Color(0xFF0D0D0D),
                      fontSize: 28,
                      fontWeight: FontWeight.w800,
                      height: 1.25,
                    ),
                    children: [
                      TextSpan(text: 'One More Step to '),
                      TextSpan(
                        text: 'Watch',
                        style: TextStyle(color: _kPink),
                      ),
                      TextSpan(text: '\nEkluvya anywhere'),
                    ],
                  ),
                ),
                const SizedBox(height: 20),

                // Description
                const Text(
                  "You're almost there! Just a few more steps and you'll "
                  'be ready to dive into a world of entertainment.',
                  style: TextStyle(
                    color: Color(0xFF555555),
                    fontSize: 15,
                    height: 1.6,
                  ),
                ),
                const SizedBox(height: 16),
                const Text(
                  ' Use the link below to complete the process and start '
                  'streaming your favourite TV shows and films in no time!',
                  style: TextStyle(
                    color: Color(0xFF555555),
                    fontSize: 15,
                    height: 1.6,
                  ),
                ),
                const SizedBox(height: 32),

                // URL + Copy button
                const Text(
                  'Paste in browser to continue:',
                  style: TextStyle(
                    color: Color(0xFF0D0D0D),
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 10),
                _CopyLinkRow(url: subscriptionUrl),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Ekluvya logo ──────────────────────────────────────────────────────────────

class _EkluvyaLogo extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Image.asset(
          'assets/icons/app-logo.png',
          height: 48,
          errorBuilder: (_, err, st) => const SizedBox(width: 48, height: 48),
        ),
        const SizedBox(width: 10),
        RichText(
          text: const TextSpan(
            style: TextStyle(
              fontSize: 26,
              fontWeight: FontWeight.w800,
              letterSpacing: 1.5,
            ),
            children: [
              TextSpan(
                  text: 'E',
                  style: TextStyle(color: Color(0xFFE91E63))),
              TextSpan(
                  text: 'K',
                  style: TextStyle(color: Color(0xFFFF5722))),
              TextSpan(
                  text: 'L',
                  style: TextStyle(color: Color(0xFFE91E63))),
              TextSpan(
                  text: 'U',
                  style: TextStyle(color: Color(0xFFFF5722))),
              TextSpan(
                  text: 'V',
                  style: TextStyle(color: Color(0xFFE91E63))),
              TextSpan(
                  text: 'Y',
                  style: TextStyle(color: Color(0xFFFF5722))),
              TextSpan(
                  text: 'A',
                  style: TextStyle(color: Color(0xFFE91E63))),
            ],
          ),
        ),
      ],
    );
  }
}

// ── Copy link row ─────────────────────────────────────────────────────────────

class _CopyLinkRow extends StatelessWidget {
  const _CopyLinkRow({required this.url});
  final String url;

  Future<void> _copy(BuildContext context) async {
    await Clipboard.setData(ClipboardData(text: url));
    if (!context.mounted) return;
    AppToast.show(context, message: 'Link copied successfully');
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: const Color(0xFFE0E0E0)),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          // URL text
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
              child: Text(
                url,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: _kPink,
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ),
          // Copy button
          GestureDetector(
            onTap: () => _copy(context),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
              decoration: const BoxDecoration(
                color: _kPink,
                borderRadius: BorderRadius.only(
                  topRight: Radius.circular(7),
                  bottomRight: Radius.circular(7),
                ),
              ),
              child: const Text(
                'COPY LINK',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.8,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
