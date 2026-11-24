import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Paleta cromática definida en la ficha de recursos gráficos de PharmaLab.
class AppColors {
  const AppColors._();

  static const Color primary = Color(0xFF087F8C);
  static const Color primaryDark = Color(0xFF06626C);
  static const Color ink = Color(0xFF123C5A);
  static const Color background = Color(0xFFF5F8FA);
  static const Color surface = Color(0xFFFFFFFF);
  static const Color mint = Color(0xFFE5F4F2);
  static const Color brandGreenTint = Color(0xFFF0FAF0);
  static const Color muted = Color(0xFF526773);
  static const Color border = Color(0xFFDFE8ED);

  // Estados de pedido.
  static const Color pendingBackground = Color(0xFFFFF3E7);
  static const Color pendingText = Color(0xFFB37828);
  static const Color approvedBackground = Color(0xFFE7F1FA);
  static const Color approvedText = Color(0xFF2B6CB0);
  static const Color successBackground = Color(0xFFE8F5ED);
  static const Color successText = Color(0xFF2E7D5B);
  static const Color danger = Color(0xFFC0392B);
  static const Color dangerBackground = Color(0xFFFDECEA);

  // Acentos suaves para categorías.
  static const Color lavender = Color(0xFFEFEDFB);
  static const Color lavenderInk = Color(0xFF6B5DD3);
  static const Color peach = Color(0xFFFFF1E6);
  static const Color peachInk = Color(0xFFC97A2B);
}

/// Estilos de texto reutilizables. Heredan la familia tipográfica del tema.
class AppText {
  const AppText._();

  static const TextStyle eyebrow = TextStyle(
    fontSize: 10,
    height: 1.2,
    fontWeight: FontWeight.w700,
    letterSpacing: 1.6,
    color: AppColors.primary,
  );

  static const TextStyle h1 = TextStyle(
    fontSize: 27,
    height: 1.15,
    fontWeight: FontWeight.w700,
    letterSpacing: -0.4,
    color: AppColors.ink,
  );

  static const TextStyle h2 = TextStyle(
    fontSize: 21,
    height: 1.2,
    fontWeight: FontWeight.w700,
    letterSpacing: -0.2,
    color: AppColors.ink,
  );

  static const TextStyle h3 = TextStyle(
    fontSize: 16,
    height: 1.25,
    fontWeight: FontWeight.w700,
    color: AppColors.ink,
  );

  static const TextStyle body = TextStyle(
    fontSize: 13,
    height: 1.45,
    color: AppColors.ink,
  );

  static const TextStyle muted = TextStyle(
    fontSize: 12.5,
    height: 1.45,
    color: AppColors.muted,
  );

  static const TextStyle label = TextStyle(
    fontSize: 12,
    fontWeight: FontWeight.w600,
    color: AppColors.ink,
  );

  static const TextStyle meta = TextStyle(
    fontSize: 11,
    height: 1.35,
    color: AppColors.muted,
  );

  static const TextStyle price = TextStyle(
    fontSize: 16,
    fontWeight: FontWeight.w700,
    letterSpacing: -0.2,
    color: AppColors.ink,
  );
}

class AppTheme {
  const AppTheme._();

  static const formShadow = [
    BoxShadow(color: Color(0x0D0928A6), blurRadius: 24, offset: Offset(0, 8)),
  ];

  // Alias conservado para compatibilidad con pantallas existentes.
  static const Color primaryColor = AppColors.primary;
  static const Color darkText = AppColors.ink;
  static const Color lightGray = AppColors.background;
  static const Color inputFill = AppColors.surface;

  static ThemeData get lightTheme {
    final base = ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(
        seedColor: AppColors.primary,
        primary: AppColors.primary,
        surface: AppColors.surface,
        onSurface: AppColors.ink,
        error: AppColors.danger,
        outline: AppColors.border,
      ),
      scaffoldBackgroundColor: AppColors.background,
    );

    final textTheme = GoogleFonts.interTextTheme(base.textTheme)
        .apply(bodyColor: AppColors.ink, displayColor: AppColors.ink);

    final inputBorder = OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: const BorderSide(color: AppColors.border),
    );

    return base.copyWith(
      textTheme: textTheme,
      primaryColor: AppColors.primary,
      appBarTheme: const AppBarTheme(
        backgroundColor: AppColors.surface,
        foregroundColor: AppColors.ink,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: true,
        titleTextStyle: TextStyle(
          fontSize: 17,
          fontWeight: FontWeight.w700,
          color: AppColors.ink,
          letterSpacing: -0.2,
        ),
        iconTheme: IconThemeData(color: AppColors.ink),
      ),
      inputDecorationTheme: InputDecorationThemeData(
        filled: true,
        fillColor: AppColors.surface,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 15,
          vertical: 15,
        ),
        hintStyle: TextStyle(
          fontSize: 13,
          color: AppColors.muted.withValues(alpha: 0.75),
        ),
        helperStyle: AppText.meta,
        errorStyle: const TextStyle(
          fontSize: 11,
          color: AppColors.danger,
          height: 1.3,
        ),
        border: inputBorder,
        enabledBorder: inputBorder,
        disabledBorder: inputBorder,
        focusedBorder: inputBorder.copyWith(
          borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
        ),
        errorBorder: inputBorder.copyWith(
          borderSide: const BorderSide(color: AppColors.danger),
        ),
        focusedErrorBorder: inputBorder.copyWith(
          borderSide: const BorderSide(color: AppColors.danger, width: 1.5),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
          disabledBackgroundColor: AppColors.primary.withValues(alpha: 0.35),
          disabledForegroundColor: Colors.white,
          elevation: 0,
          minimumSize: const Size.fromHeight(52),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          textStyle: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.1,
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.primary,
          backgroundColor: AppColors.surface,
          minimumSize: const Size.fromHeight(50),
          side: const BorderSide(color: AppColors.border),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          textStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: AppColors.primary,
          textStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
        ),
      ),
      cardTheme: CardThemeData(
        color: AppColors.surface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: AppColors.border),
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: AppColors.surface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        indicatorColor: AppColors.mint,
        height: 68,
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          final selected = states.contains(WidgetState.selected);
          return TextStyle(
            fontSize: 10.5,
            fontWeight: FontWeight.w600,
            color: selected ? AppColors.primary : AppColors.muted,
          );
        }),
        iconTheme: WidgetStateProperty.resolveWith((states) {
          final selected = states.contains(WidgetState.selected);
          return IconThemeData(
            size: 23,
            color: selected ? AppColors.primary : AppColors.muted,
          );
        }),
      ),
      dividerTheme: const DividerThemeData(
        color: AppColors.border,
        thickness: 1,
        space: 1,
      ),
      checkboxTheme: CheckboxThemeData(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(5)),
        side: const BorderSide(color: AppColors.border, width: 1.4),
        fillColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return AppColors.primary;
          }
          return AppColors.surface;
        }),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: AppColors.ink,
        contentTextStyle: const TextStyle(color: Colors.white, fontSize: 13),
        actionTextColor: AppColors.mint,
        elevation: 2,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        insetPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: AppColors.surface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        titleTextStyle: AppText.h3,
        contentTextStyle: AppText.body,
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: AppColors.surface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        showDragHandle: false,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
      ),
      progressIndicatorTheme: const ProgressIndicatorThemeData(
        color: AppColors.primary,
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return AppColors.surface;
          }
          return AppColors.surface;
        }),
        trackColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return AppColors.primary;
          }
          return AppColors.border;
        }),
        trackOutlineColor: const WidgetStatePropertyAll(Colors.transparent),
      ),
      listTileTheme: const ListTileThemeData(
        iconColor: AppColors.primary,
        textColor: AppColors.ink,
        contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 2),
      ),
      splashFactory: InkSparkle.splashFactory,
    );
  }
}
