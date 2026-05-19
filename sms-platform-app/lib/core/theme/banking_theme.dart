import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class BankingTheme {
  // Brand Colors (Fintech Deep Blue, Success Green & SendReach Cyan)
  static const Color background = Color(0xFF0A0F1D);
  static const Color cardBg = Color(0xFF0D1527);
  static const Color primary = Color(0xFF10B981); // Success Green
  static const Color secondary = Color(0xFF059669); // Darker Green
  static const Color accentCyan = Color(0xFF38BDF8); // SendReach Cyan
  static const Color textPrimary = Colors.white;
  static const Color textSecondary = Color(0xFF94A3B8); // Slate grey
  static const Color borderLight = Color(0xFF1E293B);
  static const Color borderGlow = Color(0x2210B981); // Subtle neon glow

  static const Gradient sendReachGradient = LinearGradient(
    colors: [accentCyan, primary],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static ThemeData get darkTheme {
    return ThemeData.dark().copyWith(
      primaryColor: primary,
      scaffoldBackgroundColor: background,
      cardColor: cardBg,
      dividerColor: borderLight,
      textTheme: GoogleFonts.interTextTheme(ThemeData.dark().textTheme).copyWith(
        titleLarge: GoogleFonts.poppins(
          fontSize: 24,
          fontWeight: FontWeight.bold,
          color: textPrimary,
          letterSpacing: -0.8,
        ),
        titleMedium: GoogleFonts.poppins(
          fontSize: 18,
          fontWeight: FontWeight.w600,
          color: textPrimary,
        ),
        bodyLarge: GoogleFonts.inter(
          fontSize: 15,
          fontWeight: FontWeight.normal,
          color: textPrimary,
        ),
        bodyMedium: GoogleFonts.inter(
          fontSize: 13,
          color: textSecondary,
        ),
      ),
      colorScheme: const ColorScheme.dark(
        primary: primary,
        secondary: secondary,
        surface: cardBg,
        background: background,
      ),
    );
  }

  // Gradients for premium Cards and UI highlights (Stripe / Revolut inspired)
  static const Gradient bankingCardGradient = LinearGradient(
    colors: [Color(0xFF050811), Color(0xFF0D1527)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const Gradient goldGradient = LinearGradient(
    colors: [Color(0xFF1E293B), Color(0xFF0F172A)], // Luxury Slate Dark Card
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const Gradient glassGradient = LinearGradient(
    colors: [Color(0x13FFFFFF), Color(0x04FFFFFF)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const Gradient emeraldGradient = LinearGradient(
    colors: [primary, Color(0xFF0D9488)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
}

