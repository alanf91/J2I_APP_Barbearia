import 'package:flutter/material.dart';

class AppColors {
  AppColors._();

  // ============================================================
  // IDENTIDADE
  // ============================================================

  static const Color black = Color(0xFF171717);
  static const Color charcoal = Color(0xFF242321);
  static const Color graphite = Color(0xFF353330);

  static const Color gold = Color(0xFFB8894A);
  static const Color goldDark = Color(0xFF8F6634);
  static const Color goldSoft = Color(0xFFF1E4D2);

  // ============================================================
  // FUNDOS
  // ============================================================

  static const Color background = Color(0xFFF8F6F2);
  static const Color surface = Color(0xFFFFFDFC);
  static const Color surfaceSecondary = Color(0xFFF1EEE9);

  // ============================================================
  // TEXTO
  // ============================================================

  static const Color textPrimary = Color(0xFF1C1B19);
  static const Color textSecondary = Color(0xFF706C66);
  static const Color textLight = Color(0xFFFFFFFF);

  // ============================================================
  // ESTADOS
  // ============================================================

  static const Color success = Color(0xFF257A4B);
  static const Color successSoft = Color(0xFFE2F3E8);

  static const Color warning = Color(0xFFC47D20);
  static const Color warningSoft = Color(0xFFFFEFD8);

  static const Color error = Color(0xFFB63B3B);
  static const Color errorSoft = Color(0xFFFFE7E5);

  // ============================================================
  // BORDAS
  // ============================================================

  static const Color border = Color(0xFFE0DBD4);
}

class AppTheme {
  AppTheme._();

  static ThemeData get lightTheme {
    const colorScheme = ColorScheme(
      brightness: Brightness.light,

      primary: AppColors.black,
      onPrimary: AppColors.textLight,

      primaryContainer: AppColors.goldSoft,
      onPrimaryContainer: AppColors.black,

      secondary: AppColors.gold,
      onSecondary: AppColors.black,

      secondaryContainer: Color(0xFFF4E9DB),
      onSecondaryContainer: AppColors.charcoal,

      tertiary: AppColors.success,
      onTertiary: Colors.white,

      tertiaryContainer: AppColors.successSoft,
      onTertiaryContainer: Color(0xFF163C27),

      error: AppColors.error,
      onError: Colors.white,

      errorContainer: AppColors.errorSoft,
      onErrorContainer: Color(0xFF521B1B),

      surface: AppColors.surface,
      onSurface: AppColors.textPrimary,

      onSurfaceVariant: AppColors.textSecondary,

      outline: Color(0xFF918B84),
      outlineVariant: AppColors.border,

      shadow: Color(0x33000000),
      scrim: Color(0x99000000),

      inverseSurface: AppColors.charcoal,
      onInverseSurface: Colors.white,

      inversePrimary: Color(0xFFD8B27A),

      surfaceTint: Colors.transparent,
    );

    final baseTextTheme =
        ThemeData.light(
          useMaterial3: true,
        ).textTheme;

    final textTheme = baseTextTheme.copyWith(
      displayLarge: baseTextTheme.displayLarge?.copyWith(
        color: AppColors.textPrimary,
        fontWeight: FontWeight.w700,
      ),

      displayMedium: baseTextTheme.displayMedium?.copyWith(
        color: AppColors.textPrimary,
        fontWeight: FontWeight.w700,
      ),

      headlineLarge: baseTextTheme.headlineLarge?.copyWith(
        color: AppColors.textPrimary,
        fontWeight: FontWeight.w700,
        letterSpacing: -0.5,
      ),

      headlineMedium: baseTextTheme.headlineMedium?.copyWith(
        color: AppColors.textPrimary,
        fontWeight: FontWeight.w700,
        letterSpacing: -0.3,
      ),

      headlineSmall: baseTextTheme.headlineSmall?.copyWith(
        color: AppColors.textPrimary,
        fontWeight: FontWeight.w700,
      ),

      titleLarge: baseTextTheme.titleLarge?.copyWith(
        color: AppColors.textPrimary,
        fontWeight: FontWeight.w700,
      ),

      titleMedium: baseTextTheme.titleMedium?.copyWith(
        color: AppColors.textPrimary,
        fontWeight: FontWeight.w600,
      ),

      titleSmall: baseTextTheme.titleSmall?.copyWith(
        color: AppColors.textPrimary,
        fontWeight: FontWeight.w600,
      ),

      bodyLarge: baseTextTheme.bodyLarge?.copyWith(
        color: AppColors.textPrimary,
        height: 1.4,
      ),

      bodyMedium: baseTextTheme.bodyMedium?.copyWith(
        color: AppColors.textPrimary,
        height: 1.4,
      ),

      bodySmall: baseTextTheme.bodySmall?.copyWith(
        color: AppColors.textSecondary,
        height: 1.35,
      ),

      labelLarge: baseTextTheme.labelLarge?.copyWith(
        fontWeight: FontWeight.w700,
        letterSpacing: 0.2,
      ),

      labelMedium: baseTextTheme.labelMedium?.copyWith(
        fontWeight: FontWeight.w600,
      ),
    );

    return ThemeData(
      useMaterial3: true,

      brightness: Brightness.light,

      colorScheme: colorScheme,

      scaffoldBackgroundColor:
          AppColors.background,

      textTheme: textTheme,

      // ========================================================
      // APP BAR
      // ========================================================

      appBarTheme: const AppBarTheme(
        backgroundColor: AppColors.background,
        foregroundColor: AppColors.textPrimary,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        centerTitle: false,
        scrolledUnderElevation: 0,
        titleTextStyle: TextStyle(
          color: AppColors.textPrimary,
          fontSize: 20,
          fontWeight: FontWeight.w700,
        ),
        iconTheme: IconThemeData(
          color: AppColors.textPrimary,
        ),
        actionsIconTheme: IconThemeData(
          color: AppColors.textPrimary,
        ),
      ),

      // ========================================================
      // BOTÃO PRINCIPAL
      // ========================================================

      filledButtonTheme: FilledButtonThemeData(
        style: ButtonStyle(
          minimumSize: const WidgetStatePropertyAll(
            Size(double.infinity, 54),
          ),

          padding: const WidgetStatePropertyAll(
            EdgeInsets.symmetric(
              horizontal: 20,
              vertical: 15,
            ),
          ),

          backgroundColor:
              const WidgetStatePropertyAll(
            AppColors.black,
          ),

          foregroundColor:
              const WidgetStatePropertyAll(
            Colors.white,
          ),

          textStyle:
              const WidgetStatePropertyAll(
            TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.2,
            ),
          ),

          shape: WidgetStatePropertyAll(
            RoundedRectangleBorder(
              borderRadius:
                  BorderRadius.circular(14),
            ),
          ),

          elevation:
              const WidgetStatePropertyAll(
            0,
          ),
        ),
      ),

      // ========================================================
      // BOTÃO ELEVATED
      // ========================================================

      elevatedButtonTheme:
          ElevatedButtonThemeData(
        style: ButtonStyle(
          minimumSize:
              const WidgetStatePropertyAll(
            Size(double.infinity, 54),
          ),

          backgroundColor:
              const WidgetStatePropertyAll(
            AppColors.black,
          ),

          foregroundColor:
              const WidgetStatePropertyAll(
            Colors.white,
          ),

          elevation:
              const WidgetStatePropertyAll(
            0,
          ),

          padding:
              const WidgetStatePropertyAll(
            EdgeInsets.symmetric(
              horizontal: 20,
              vertical: 15,
            ),
          ),

          shape:
              WidgetStatePropertyAll(
            RoundedRectangleBorder(
              borderRadius:
                  BorderRadius.circular(14),
            ),
          ),

          textStyle:
              const WidgetStatePropertyAll(
            TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ),

      // ========================================================
      // BOTÃO SECUNDÁRIO
      // ========================================================

      outlinedButtonTheme:
          OutlinedButtonThemeData(
        style: ButtonStyle(
          minimumSize:
              const WidgetStatePropertyAll(
            Size(double.infinity, 52),
          ),

          foregroundColor:
              const WidgetStatePropertyAll(
            AppColors.charcoal,
          ),

          padding:
              const WidgetStatePropertyAll(
            EdgeInsets.symmetric(
              horizontal: 20,
              vertical: 14,
            ),
          ),

          side:
              const WidgetStatePropertyAll(
            BorderSide(
              color: AppColors.border,
              width: 1.2,
            ),
          ),

          shape:
              WidgetStatePropertyAll(
            RoundedRectangleBorder(
              borderRadius:
                  BorderRadius.circular(14),
            ),
          ),

          textStyle:
              const WidgetStatePropertyAll(
            TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ),

      // ========================================================
      // TEXT BUTTON
      // ========================================================

      textButtonTheme: TextButtonThemeData(
        style: ButtonStyle(
          foregroundColor:
              const WidgetStatePropertyAll(
            AppColors.goldDark,
          ),

          textStyle:
              const WidgetStatePropertyAll(
            TextStyle(
              fontWeight: FontWeight.w700,
            ),
          ),

          shape:
              WidgetStatePropertyAll(
            RoundedRectangleBorder(
              borderRadius:
                  BorderRadius.circular(10),
            ),
          ),
        ),
      ),

      // ========================================================
      // CAMPOS
      // ========================================================

      inputDecorationTheme:
          InputDecorationTheme(
        filled: true,

        fillColor: AppColors.surface,

        contentPadding:
            const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 16,
        ),

        hintStyle: const TextStyle(
          color: Color(0xFF9A958E),
          fontWeight: FontWeight.w400,
        ),

        labelStyle: const TextStyle(
          color: AppColors.textSecondary,
        ),

        floatingLabelStyle:
            const TextStyle(
          color: AppColors.black,
          fontWeight: FontWeight.w600,
        ),

        prefixIconColor:
            AppColors.textSecondary,

        suffixIconColor:
            AppColors.textSecondary,

        border: OutlineInputBorder(
          borderRadius:
              BorderRadius.circular(14),

          borderSide:
              const BorderSide(
            color: AppColors.border,
          ),
        ),

        enabledBorder:
            OutlineInputBorder(
          borderRadius:
              BorderRadius.circular(14),

          borderSide:
              const BorderSide(
            color: AppColors.border,
          ),
        ),

        focusedBorder:
            OutlineInputBorder(
          borderRadius:
              BorderRadius.circular(14),

          borderSide:
              const BorderSide(
            color: AppColors.gold,
            width: 1.7,
          ),
        ),

        errorBorder:
            OutlineInputBorder(
          borderRadius:
              BorderRadius.circular(14),

          borderSide:
              const BorderSide(
            color: AppColors.error,
          ),
        ),

        focusedErrorBorder:
            OutlineInputBorder(
          borderRadius:
              BorderRadius.circular(14),

          borderSide:
              const BorderSide(
            color: AppColors.error,
            width: 1.7,
          ),
        ),
      ),

      // ========================================================
      // NAVEGAÇÃO INFERIOR
      // ========================================================

      navigationBarTheme:
          NavigationBarThemeData(
        height: 70,

        backgroundColor:
            AppColors.surface,

        surfaceTintColor:
            Colors.transparent,

        indicatorColor:
            AppColors.goldSoft,

        elevation: 4,

        labelTextStyle:
            WidgetStateProperty.resolveWith(
          (states) {
            final selected =
                states.contains(
              WidgetState.selected,
            );

            return TextStyle(
              color:
                  selected
                      ? AppColors.black
                      : AppColors
                          .textSecondary,

              fontSize: 12,

              fontWeight:
                  selected
                      ? FontWeight.w700
                      : FontWeight.w500,
            );
          },
        ),

        iconTheme:
            WidgetStateProperty.resolveWith(
          (states) {
            final selected =
                states.contains(
              WidgetState.selected,
            );

            return IconThemeData(
              color:
                  selected
                      ? AppColors.black
                      : AppColors
                          .textSecondary,

              size: 24,
            );
          },
        ),
      ),

      // ========================================================
      // CHIPS
      // ========================================================

      chipTheme: ChipThemeData(
        backgroundColor:
            AppColors.surface,

        selectedColor:
            AppColors.goldSoft,

        disabledColor:
            AppColors.surfaceSecondary,

        labelStyle:
            const TextStyle(
          color:
              AppColors.textPrimary,

          fontWeight:
              FontWeight.w600,
        ),

        side:
            const BorderSide(
          color:
              AppColors.border,
        ),

        padding:
            const EdgeInsets.symmetric(
          horizontal: 10,
          vertical: 8,
        ),

        shape:
            RoundedRectangleBorder(
          borderRadius:
              BorderRadius.circular(12),
        ),
      ),

      // ========================================================
      // DIVISOR
      // ========================================================

      dividerTheme:
          const DividerThemeData(
        color:
            AppColors.border,

        thickness:
            1,

        space:
            1,
      ),

      // ========================================================
      // SNACKBAR
      // ========================================================

      snackBarTheme:
          SnackBarThemeData(
        backgroundColor:
            AppColors.charcoal,

        contentTextStyle:
            const TextStyle(
          color: Colors.white,
          fontWeight:
              FontWeight.w500,
        ),

        behavior:
            SnackBarBehavior.floating,

        elevation:
            4,

        shape:
            RoundedRectangleBorder(
          borderRadius:
              BorderRadius.circular(14),
        ),
      ),

      // ========================================================
      // PROGRESS
      // ========================================================

      progressIndicatorTheme:
          const ProgressIndicatorThemeData(
        color:
            AppColors.gold,
      ),

      // ========================================================
      // ÍCONES
      // ========================================================

      iconTheme:
          const IconThemeData(
        color:
            AppColors.charcoal,
      ),

     
    );
  }
}