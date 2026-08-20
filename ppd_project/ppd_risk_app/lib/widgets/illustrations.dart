import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

/// Small hand-authored flat-style vector illustrations used across the app.
/// Kept as raw SVG strings (no network/asset files) so the app has zero
/// external image dependencies.
class AppIllustration extends StatelessWidget {
  final String svg;
  final double size;

  const AppIllustration._(this.svg, {required this.size});

  Widget _build() => SvgPicture.string(svg, width: size, height: size);

  @override
  Widget build(BuildContext context) => _build();

  // ---- Backdrop helper -----------------------------------------------
  static String _blob(String hex, {double opacity = 0.14}) => '''
    <circle cx="100" cy="100" r="92" fill="$hex" fill-opacity="$opacity"/>
    <circle cx="150" cy="55" r="26" fill="$hex" fill-opacity="${opacity + 0.08}"/>
  ''';

  static String _frame(String inner) => '''
    <svg viewBox="0 0 200 200" xmlns="http://www.w3.org/2000/svg">
      $inner
    </svg>
  ''';

  // ---- Illustrations ----------------------------------------------------

  /// Mother cradling baby, used on splash / welcome / home hero.
  static AppIllustration motherAndBaby({double size = 220}) => AppIllustration._(
        _frame('''
          ${_blob('#7C5CBF')}
          <circle cx="40" cy="150" r="6" fill="#3FCDC7" fill-opacity="0.5"/>
          <circle cx="165" cy="150" r="4" fill="#FF9AAE" fill-opacity="0.6"/>
          <circle cx="30" cy="60" r="4" fill="#FF9AAE" fill-opacity="0.6"/>
          <path d="M60 175 C60 130 78 108 108 108 C138 108 156 130 156 175 Z" fill="#7C5CBF"/>
          <circle cx="108" cy="82" r="30" fill="#F4C9A8"/>
          <path d="M78 78 C76 48 140 48 138 78 C138 55 76 55 78 78 Z" fill="#5B3E96"/>
          <path d="M92 150 C92 120 100 108 118 112 C136 116 138 140 132 158 Z" fill="#3FCDC7"/>
          <circle cx="112" cy="126" r="15" fill="#F9D8BC"/>
          <path d="M104 122 C103 112 121 112 120 122 C120 116 104 116 104 122 Z" fill="#5B3E96"/>
          <path d="M126 96 C126 90 134 90 134 96 C138 96 138 102 134 102 C134 108 126 108 126 102 C122 102 122 96 126 96 Z" fill="#FF9AAE"/>
        '''),
        size: size,
      );

  /// Heart with a pulse line — "track your wellbeing".
  static AppIllustration heartPulse({double size = 200}) => AppIllustration._(
        _frame('''
          ${_blob('#7C5CBF')}
          <path d="M100 150 C40 112 46 66 82 62 C96 60 100 74 100 74 C100 74 104 60 118 62 C154 66 160 112 100 150 Z" fill="#FF9AAE"/>
          <polyline points="55,100 80,100 90,80 105,118 115,95 145,95" fill="none" stroke="#FFFFFF" stroke-width="5" stroke-linecap="round" stroke-linejoin="round"/>
        '''),
        size: size,
      );

  /// Magnifying glass over rising bars — "understand your results".
  static AppIllustration insight({double size = 200}) => AppIllustration._(
        _frame('''
          ${_blob('#3FCDC7')}
          <rect x="70" y="105" width="14" height="35" rx="3" fill="#7C5CBF"/>
          <rect x="90" y="90" width="14" height="50" rx="3" fill="#3FCDC7"/>
          <rect x="110" y="75" width="14" height="65" rx="3" fill="#FF9AAE"/>
          <circle cx="100" cy="95" r="42" fill="none" stroke="#5B3E96" stroke-width="6"/>
          <line x1="131" y1="126" x2="152" y2="147" stroke="#5B3E96" stroke-width="7" stroke-linecap="round"/>
        '''),
        size: size,
      );

  /// Shield with lock — "private & secure".
  static AppIllustration privacyShield({double size = 200}) => AppIllustration._(
        _frame('''
          ${_blob('#FF9AAE')}
          <path d="M100 45 L145 62 C145 108 128 138 100 155 C72 138 55 108 55 62 Z" fill="#7C5CBF"/>
          <rect x="84" y="90" width="32" height="26" rx="6" fill="#FFFFFF"/>
          <path d="M90 90 V78 a10 10 0 0 1 20 0 V90" fill="none" stroke="#FFFFFF" stroke-width="5"/>
          <circle cx="100" cy="103" r="4" fill="#7C5CBF"/>
        '''),
        size: size,
      );

  /// Simple lock/key figure for the login screen.
  static AppIllustration login({double size = 200}) => AppIllustration._(
        _frame('''
          ${_blob('#7C5CBF')}
          <circle cx="100" cy="80" r="34" fill="#7C5CBF"/>
          <rect x="82" y="118" width="36" height="14" rx="7" fill="#7C5CBF"/>
          <rect x="70" y="120" width="60" height="45" rx="18" fill="#3FCDC7"/>
          <circle cx="100" cy="140" r="9" fill="#FFFFFF"/>
          <rect x="97" y="140" width="6" height="14" rx="3" fill="#FFFFFF"/>
        '''),
        size: size,
      );

  /// Person with a checklist/plus — for the register screen.
  static AppIllustration register({double size = 200}) => AppIllustration._(
        _frame('''
          ${_blob('#3FCDC7')}
          <circle cx="80" cy="75" r="28" fill="#F4C9A8"/>
          <path d="M50 155 C50 118 65 105 80 105 C95 105 110 118 110 155 Z" fill="#7C5CBF"/>
          <circle cx="140" cy="120" r="26" fill="#FF9AAE"/>
          <line x1="140" y1="108" x2="140" y2="132" stroke="#FFFFFF" stroke-width="6" stroke-linecap="round"/>
          <line x1="128" y1="120" x2="152" y2="120" stroke="#FFFFFF" stroke-width="6" stroke-linecap="round"/>
        '''),
        size: size,
      );

  /// Calendar with a sparkle — empty-state for history.
  static AppIllustration calendarSparkle({double size = 200}) => AppIllustration._(
        _frame('''
          ${_blob('#7C5CBF', opacity: 0.10)}
          <rect x="55" y="70" width="90" height="80" rx="12" fill="#EDE7F9"/>
          <rect x="55" y="70" width="90" height="26" rx="12" fill="#7C5CBF"/>
          <rect x="70" y="58" width="8" height="20" rx="4" fill="#5B3E96"/>
          <rect x="122" y="58" width="8" height="20" rx="4" fill="#5B3E96"/>
          <rect x="70" y="108" width="16" height="14" rx="3" fill="#3FCDC7"/>
          <rect x="92" y="108" width="16" height="14" rx="3" fill="#FF9AAE"/>
          <rect x="114" y="108" width="16" height="14" rx="3" fill="#D9CFF0"/>
          <rect x="70" y="128" width="16" height="14" rx="3" fill="#D9CFF0"/>
          <rect x="92" y="128" width="16" height="14" rx="3" fill="#3FCDC7"/>
          <path d="M150 55 L154 65 L164 69 L154 73 L150 83 L146 73 L136 69 L146 65 Z" fill="#FF9AAE"/>
        '''),
        size: size,
      );

  /// Open book with heart — resources / self-care.
  static AppIllustration book({double size = 200}) => AppIllustration._(
        _frame('''
          ${_blob('#FF9AAE', opacity: 0.12)}
          <path d="M100 70 C88 60 60 58 45 64 V138 C60 132 88 134 100 144 Z" fill="#7C5CBF"/>
          <path d="M100 70 C112 60 140 58 155 64 V138 C140 132 112 134 100 144 Z" fill="#8A6BD1"/>
          <path d="M100 100 C93 90 78 90 78 100 C78 108 90 116 100 122 C110 116 122 108 122 100 C122 90 107 90 100 100 Z" fill="#FF9AAE"/>
        '''),
        size: size,
      );

  /// Phone with heart — help & crisis support.
  static AppIllustration supportCall({double size = 200}) => AppIllustration._(
        _frame('''
          ${_blob('#3FCDC7', opacity: 0.14)}
          <rect x="72" y="50" width="56" height="100" rx="14" fill="#7C5CBF"/>
          <rect x="80" y="64" width="40" height="60" rx="6" fill="#FFFFFF"/>
          <circle cx="100" cy="136" r="5" fill="#EDE7F9"/>
          <path d="M100 100 C92 92 80 92 80 102 C80 110 90 117 100 123 C110 117 120 110 120 102 C120 92 108 92 100 100 Z" fill="#FF9AAE"/>
        '''),
        size: size,
      );

  /// Checkmark ribbon badge — used for success states.
  static AppIllustration successBadge({double size = 160}) => AppIllustration._(
        _frame('''
          ${_blob('#3FB68B', opacity: 0.16)}
          <circle cx="100" cy="95" r="46" fill="#3FB68B"/>
          <path d="M78 96 L94 112 L124 78" fill="none" stroke="#FFFFFF" stroke-width="8" stroke-linecap="round" stroke-linejoin="round"/>
        '''),
        size: size,
      );
}
