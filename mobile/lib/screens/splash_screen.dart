import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../core/app_colors.dart';
import '../providers/auth_provider.dart';
import 'login_screen.dart';
import 'main_shell.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _animController;
  late Animation<double> _fadeAnimation;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 3000),
    );

    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _animController, curve: Curves.easeIn));

    _scaleAnimation = Tween<double>(begin: 0.88, end: 1.0).animate(
      CurvedAnimation(parent: _animController, curve: Curves.easeOutBack),
    );

    _animController.forward();

    // Navigate after splash delay
    Timer(const Duration(milliseconds: 2200), _checkAuthAndNavigate);
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  void _checkAuthAndNavigate() {
    if (!mounted) return;
    final auth = context.read<AuthProvider>();

    if (auth.isLoggedIn) {
      Navigator.of(context).pushReplacement(
        PageRouteBuilder(
          transitionDuration: const Duration(milliseconds: 600),
          pageBuilder: (context, animation, secondaryAnimation) =>
              const MainShell(),
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            return FadeTransition(opacity: animation, child: child);
          },
        ),
      );
    } else {
      Navigator.of(context).pushReplacement(
        PageRouteBuilder(
          transitionDuration: const Duration(milliseconds: 600),
          pageBuilder: (context, animation, secondaryAnimation) =>
              const LoginScreen(),
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            return FadeTransition(opacity: animation, child: child);
          },
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Center(
          child: AnimatedBuilder(
            animation: _animController,
            builder: (context, child) {
              return FadeTransition(
                opacity: _fadeAnimation,
                child: ScaleTransition(scale: _scaleAnimation, child: child),
              );
            },
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Spacer(),

                // Horizone Energy Corporate Logo
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Image.asset(
                    'assets/branding/logo.png',
                    width: 280,
                    fit: BoxFit.contain,
                    errorBuilder: (_, error, stackTrace) {
                      return Column(
                        mainAxisSize: MainAxisSize.min,
                        children: const [
                          Icon(
                            Icons.solar_power_rounded,
                            size: 80,
                            color: AppColors.primaryBlue,
                          ),
                          SizedBox(height: 12),
                          Text(
                            'HORIZONE ENERGY',
                            style: TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.w800,
                              color: AppColors.primaryBlue,
                              letterSpacing: 1.5,
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                ),

                // Application Title & Subtitle
                const Spacer(),

                // Bottom Loader & Version Tag
                SizedBox(
                  width: 28,
                  height: 28,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.5,
                    valueColor: AlwaysStoppedAnimation<Color>(
                      AppColors.primaryBlue,
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                const Text(
                  'v1.0.0 • Horizone Energy',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textMuted,
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(height: 24),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
