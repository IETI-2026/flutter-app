import 'package:flutter/material.dart';
import 'package:flutter_app/core/constants/app_colors.dart';
import 'package:flutter_app/core/di/injection_container.dart';
import 'package:flutter_app/presentation/bloc/auth/auth_bloc.dart';
import 'package:flutter_app/presentation/pages/login_page.dart';
import 'package:flutter_app/presentation/pages/signup_page.dart';
import 'package:flutter_app/presentation/pages/splash_screen.dart';
import 'package:flutter_app/presentation/pages/client_home_page.dart';
import 'package:flutter_app/presentation/pages/provider_home_page.dart';
import 'package:flutter_app/presentation/pages/provider_onboarding_page.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_fonts/google_fonts.dart';

class CameYoApp extends StatelessWidget {
  const CameYoApp({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) => sl<AuthBloc>(),
      child: MaterialApp(
        title: 'CameYo - Servicios al Instante',
        debugShowCheckedModeBanner: false,
        theme: _buildTheme(),
        initialRoute: '/',
        routes: {
          '/': (context) => const SplashScreen(),
          '/login': (context) => const LoginPage(),
          '/signup': (context) => const SignUpPage(),
          '/client-home': (context) => const ClientHomePage(),
          '/provider-home': (context) => const ProviderHomePage(),
          '/provider-onboarding': (context) => const ProviderOnboardingPage(),
        },
      ),
    );
  }

  ThemeData _buildTheme() {
    return ThemeData(
      primaryColor: AppColors.primary,
      colorScheme: ColorScheme.fromSeed(
        seedColor: AppColors.primary,
        secondary: AppColors.secondary,
      ),
      scaffoldBackgroundColor: Colors.white,
      useMaterial3: true,

      textTheme: GoogleFonts.poppinsTextTheme(),

      appBarTheme: AppBarTheme(
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        iconTheme: const IconThemeData(color: AppColors.textPrimary),
        titleTextStyle: GoogleFonts.poppins(
          fontSize: 18,
          fontWeight: FontWeight.w600,
          color: AppColors.textPrimary,
        ),
      ),

      cardTheme: CardThemeData(
        elevation: 2,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),

      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        backgroundColor: Colors.white,
        selectedItemColor: AppColors.primary,
        unselectedItemColor: AppColors.grey,
        selectedLabelStyle: GoogleFonts.poppins(
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
        unselectedLabelStyle: GoogleFonts.poppins(
          fontSize: 12,
          fontWeight: FontWeight.w400,
        ),
        type: BottomNavigationBarType.fixed,
        elevation: 8,
      ),
    );
  }
}
