import 'package:flutter/material.dart';

/// لوحة الهوية البصرية للتطبيق.
///
/// ألوان أساسية تمثل العلامة التجارية، وألوان تمييزية للتركيز،
/// ومحايدات للخلفيات والنصوص، وألوان دلالية للحالات (نجاح، خطر، معلومات، إلخ).
/// يمكن تخصيص هذه القيم لتناسب هوية تطبيقك.
class AppColors {
  const AppColors._();

  // الأساسية — اللون الرئيسي للعلامة التجارية
  static const Color deepForest = Color(0xFF073A2C);
  static const Color forest = Color(0xFF0E5A45);
  static const Color emerald = Color(0xFF17805F);
  static const Color mint = Color(0xFF2AA57C);
  static const Color mintSoft = Color(0xFFD9F0E6);

  // التمييز — لون التركيز والثانوي
  static const Color gold = Color(0xFFE3A83F);
  static const Color goldSoft = Color(0xFFF6CE74);
  static const Color goldDeep = Color(0xFFB9771A);
  static const Color goldWash = Color(0xFFFCF1DA);

  // المحايدات
  static const Color ink = Color(0xFF0F241C);
  static const Color slate = Color(0xFF586761);
  static const Color mist = Color(0xFF8B9A93);
  static const Color line = Color(0xFFE0E7E1);
  static const Color canvas = Color(0xFFF5F7F4);
  static const Color card = Color(0xFFFFFFFF);
  static const Color cardInk = Color(0xFF131C18);

  // الألوان الدلالية
  static const Color info = Color(0xFF1F5FA8);
  static const Color violet = Color(0xFF6B5B95);
  static const Color teal = Color(0xFF177A60);
  static const Color amber = Color(0xFFB3741A);
  static const Color danger = Color(0xFFB3261E);
  static const Color success = Color(0xFF1B7F5A);

  // الوضع الليلي
  static const Color nightCanvas = Color(0xFF0A1310);
  static const Color nightSurface = Color(0xFF111C17);
  static const Color nightCard = Color(0xFF16231D);
  static const Color nightLine = Color(0xFF25352D);
  static const Color nightInk = Color(0xFFE8F1EB);
  static const Color nightMuted = Color(0xFF9DB0A6);

  // التدرجات
  static const List<Color> brandGradient = <Color>[
    deepForest,
    forest,
    emerald,
  ];

  static const List<Color> headerGradient = <Color>[
    Color(0xFF08382A),
    Color(0xFF0E5A45),
    Color(0xFF15795D),
  ];

  static const List<Color> goldGradient = <Color>[
    goldSoft,
    gold,
    goldDeep,
  ];

  static const List<Color> canvasGradient = <Color>[
    Color(0xFFF8FAF6),
    Color(0xFFEFF4EE),
  ];

  static const List<Color> nightGradient = <Color>[
    Color(0xFF07110D),
    Color(0xFF0D1F18),
    Color(0xFF113026),
  ];

  static LinearGradient brand({double begin = -1, double end = 1}) =>
      LinearGradient(
        begin: Alignment(begin, begin),
        end: Alignment(end, end),
        colors: brandGradient,
      );
}
