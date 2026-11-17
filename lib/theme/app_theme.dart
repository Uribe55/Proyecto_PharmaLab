import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppTheme {
  // Colores de la app (sacados de tu mockup)
  static const Color primaryColor = Color(0xFF008080); // El turquesa oscuro
  static const Color darkText = Color(0xFF1E293B); // Azul muy oscuro para textos
  static const Color lightGray = Color(0xFFF8F9FA); // Gris claro de fondo
  static const Color inputFill = Colors.white; 

  static ThemeData get lightTheme {
    return ThemeData(
      primaryColor: primaryColor,
      scaffoldBackgroundColor: lightGray,
      // Usamos Google Fonts (Poppins suele parecerse a tu diseño)
      textTheme: GoogleFonts.poppinsTextTheme().apply(
        bodyColor: darkText,
        displayColor: darkText,
      ),
      colorScheme: ColorScheme.fromSeed(
        seedColor: primaryColor,
        primary: primaryColor,
      ),
    );
  }
}