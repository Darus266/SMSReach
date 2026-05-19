import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/theme/banking_theme.dart';
import 'auth_controller.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({Key? key}) : super(key: key);

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> with SingleTickerProviderStateMixin {
  late AnimationController _animController;
  late Animation<double> _scaleAnimation;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    );

    _scaleAnimation = Tween<double>(begin: 0.85, end: 1.0).animate(
      CurvedAnimation(parent: _animController, curve: Curves.easeOutBack),
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animController, curve: Curves.easeIn),
    );

    _animController.forward();

    // Start background session check
    _checkSession();
  }

  Future<void> _checkSession() async {
    await Future.delayed(const Duration(seconds: 3));
    if (!mounted) return;

    final auth = Provider.of<AuthController>(context, listen: false);
    if (auth.isAuthenticated) {
      Navigator.pushReplacementNamed(context, '/dashboard');
    } else {
      Navigator.pushReplacementNamed(context, '/login');
    }
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          color: BankingTheme.background,
        ),
        child: Center(
          child: FadeTransition(
            opacity: _fadeAnimation,
            child: ScaleTransition(
              scale: _scaleAnimation,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Logo with glowing emerald shadow
                  Container(
                    width: 90,
                    height: 90,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(24),
                      color: BankingTheme.cardBg,
                      border: Border.all(color: BankingTheme.primary.withOpacity(0.4), width: 1.5),
                      boxShadow: [
                        BoxShadow(
                          color: BankingTheme.primary.withOpacity(0.15),
                          blurRadius: 30.0,
                          spreadRadius: 5.0,
                        )
                      ],
                    ),
                    child: const Icon(
                      Icons.electric_bolt_rounded,
                      color: BankingTheme.primary,
                      size: 48,
                    ),
                  ),
                  const SizedBox(height: 24),
                  // App text titles
                  Text(
                    'SaaS SMS',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontSize: 32,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                      letterSpacing: -1.0,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'PLATEFORME SMS INDUSTRIELLE',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      letterSpacing: 3.0,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: BankingTheme.primary,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
