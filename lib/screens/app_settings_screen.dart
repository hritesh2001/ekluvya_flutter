import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

// ── Persistence keys ──────────────────────────────────────────────────────────

const _kAutoPlay   = 'settings_auto_play';
const _kEmailNotif = 'settings_email_notif';
const _kSmsNotif   = 'settings_sms_notif';
const _kPushNotif  = 'settings_push_notif';
const _kInAppNotif = 'settings_inapp_notif';

// ── Public helpers for other parts of the app ─────────────────────────────────

/// Returns the persisted auto-play preference (defaults to true).
Future<bool> getAutoPlayPref() async {
  final prefs = await SharedPreferences.getInstance();
  return prefs.getBool(_kAutoPlay) ?? true;
}

/// Returns the persisted in-app notifications preference (defaults to true).
Future<bool> getInAppNotifPref() async {
  final prefs = await SharedPreferences.getInstance();
  return prefs.getBool(_kInAppNotif) ?? true;
}

// ─────────────────────────────────────────────────────────────────────────────

class AppSettingsScreen extends StatefulWidget {
  const AppSettingsScreen({super.key});

  static Route<void> route() => MaterialPageRoute<void>(
        builder: (_) => const AppSettingsScreen(),
        settings: const RouteSettings(name: '/app-settings'),
      );

  @override
  State<AppSettingsScreen> createState() => _AppSettingsScreenState();
}

class _AppSettingsScreenState extends State<AppSettingsScreen> {
  bool _autoPlay   = true;
  bool _emailNotif = false;
  bool _smsNotif   = false;
  bool _pushNotif  = false;
  bool _inAppNotif = true;
  bool _loaded     = false;

  @override
  void initState() {
    super.initState();
    _loadPrefs();
  }

  Future<void> _loadPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    setState(() {
      _autoPlay   = prefs.getBool(_kAutoPlay)   ?? true;
      _emailNotif = prefs.getBool(_kEmailNotif) ?? false;
      _smsNotif   = prefs.getBool(_kSmsNotif)   ?? false;
      _pushNotif  = prefs.getBool(_kPushNotif)  ?? false;
      _inAppNotif = prefs.getBool(_kInAppNotif) ?? true;
      _loaded     = true;
    });
  }

  Future<void> _toggle(String key, bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(key, value);
  }

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.dark
          .copyWith(statusBarColor: Colors.transparent),
      child: Scaffold(
        backgroundColor: Colors.white,
        appBar: AppBar(
          backgroundColor: Colors.white,
          elevation: 0,
          scrolledUnderElevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back, color: Colors.black87),
            onPressed: () => Navigator.of(context).pop(),
          ),
          title: const Text(
            'App Settings',
            style: TextStyle(
              color: Colors.black87,
              fontSize: 18,
              fontWeight: FontWeight.w700,
            ),
          ),
          centerTitle: true,
        ),
        body: !_loaded
            ? const SizedBox.shrink()
            : _buildBody(),
      ),
    );
  }

  Widget _buildBody() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // ── VIDEO SETTINGS ─────────────────────────────────────────────
        const _SectionLabel('VIDEO SETTINGS'),
        _SettingsTile(
          title: 'Auto Play',
          value: _autoPlay,
          onChanged: (v) {
            setState(() => _autoPlay = v);
            _toggle(_kAutoPlay, v);
          },
        ),

        // ── Thick section separator ────────────────────────────────────
        Container(height: 8, color: const Color(0xFFF4F4F4)),

        // ── NOTIFICATION SETTINGS ──────────────────────────────────────
        const _SectionLabel('NOTIFICATION SETTINGS'),
        _SettingsTile(
          title: 'Email Notifications',
          value: _emailNotif,
          onChanged: (v) {
            setState(() => _emailNotif = v);
            _toggle(_kEmailNotif, v);
          },
        ),
        const _ThinDivider(),
        _SettingsTile(
          title: 'SMS Notifications',
          value: _smsNotif,
          onChanged: (v) {
            setState(() => _smsNotif = v);
            _toggle(_kSmsNotif, v);
          },
        ),
        const _ThinDivider(),
        _SettingsTile(
          title: 'Push Notifications',
          value: _pushNotif,
          onChanged: (v) {
            setState(() => _pushNotif = v);
            _toggle(_kPushNotif, v);
          },
        ),
        const _ThinDivider(),
        _SettingsTile(
          title: 'In-app Notifications',
          value: _inAppNotif,
          onChanged: (v) {
            setState(() => _inAppNotif = v);
            _toggle(_kInAppNotif, v);
          },
        ),
        const _ThinDivider(),
      ],
    );
  }
}

// ── Section label ─────────────────────────────────────────────────────────────

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.label);
  final String label;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
        child: Text(
          label,
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: Color(0xFF9E9E9E),
            letterSpacing: 0.6,
          ),
        ),
      );
}

// ── Settings row with switch ──────────────────────────────────────────────────

class _SettingsTile extends StatelessWidget {
  const _SettingsTile({
    required this.title,
    required this.value,
    required this.onChanged,
  });

  final String title;
  final bool value;
  final ValueChanged<bool> onChanged;

  static const _kGreen = Color(0xFF4CAF50);

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              title,
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w500,
                color: Color(0xFF1A1A1A),
              ),
            ),
            Switch(
              value: value,
              onChanged: onChanged,
              activeThumbColor: Colors.white,
              activeTrackColor: _kGreen,
              inactiveThumbColor: Colors.white,
              inactiveTrackColor: const Color(0xFFBDBDBD),
              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
          ],
        ),
      );
}

// ── Thin row divider ──────────────────────────────────────────────────────────

class _ThinDivider extends StatelessWidget {
  const _ThinDivider();

  @override
  Widget build(BuildContext context) => const Divider(
        height: 1,
        thickness: 0.8,
        indent: 16,
        endIndent: 0,
        color: Color(0xFFE0E0E0),
      );
}
