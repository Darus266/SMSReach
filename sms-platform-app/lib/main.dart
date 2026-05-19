import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'core/theme/banking_theme.dart';
import 'features/auth/auth_controller.dart';
import 'features/auth/splash_screen.dart';
import 'features/auth/login_screen.dart';
import 'features/dashboard/dashboard_controller.dart';
import 'features/dashboard/dashboard_screen.dart';
import 'features/sms/sms_screen.dart';
import 'features/wallet/wallet_screen.dart';
import 'features/settings/settings_screen.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider<AuthController>(
          create: (_) => AuthController(),
        ),
        ChangeNotifierProvider<DashboardController>(
          create: (_) => DashboardController(),
        ),
      ],
      child: MaterialApp(
        title: 'SaaS SMS',
        debugShowCheckedModeBanner: false,
        theme: BankingTheme.darkTheme,
        initialRoute: '/',
        routes: {
          '/': (context) => const SplashScreen(),
          '/login': (context) => const LoginScreen(),
          '/dashboard': (context) => const DashboardScreen(),
          '/sms': (context) => const SmsScreen(),
          '/wallet': (context) => const WalletScreen(),
          '/settings': (context) => const SettingsScreen(),
        },
      ),
    );
  }
}
