import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/theme/banking_theme.dart';
import '../../core/widgets/glass_card.dart';
import 'auth_controller.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({Key? key}) : super(key: key);

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _companyController = TextEditingController();
  
  bool _isRegister = false;
  bool _obscurePassword = true;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _companyController.dispose();
    super.dispose();
  }

  void _submit() async {
    if (!_formKey.currentState!.validate()) return;

    final auth = Provider.of<AuthController>(context, listen: false);
    bool success;

    if (_isRegister) {
      success = await auth.register(
        _emailController.text.trim(),
        _passwordController.text,
        _companyController.text.trim(),
      );
    } else {
      success = await auth.login(
        _emailController.text.trim(),
        _passwordController.text,
      );
    }

    if (success && mounted) {
      Navigator.pushReplacementNamed(context, '/dashboard');
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = Provider.of<AuthController>(context);
    final size = MediaQuery.of(context).size;

    return Scaffold(
      body: Stack(
        children: [
          // Background graphic glow
          Positioned(
            top: -150,
            right: -100,
            child: Container(
              width: 350,
              height: 350,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: BankingTheme.primary.withOpacity(0.06),
                backdropFilter: null,
              ),
            ),
          ),
          Positioned(
            bottom: -200,
            left: -150,
            child: Container(
              width: 450,
              height: 450,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: BankingTheme.primary.withOpacity(0.04),
              ),
            ),
          ),

          // Scrollable login card layout
          SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  mainAxisAlignment: MainAxisSize.mainAxisAlignment ?? MainAxisSize.min,
                  children: [
                    // Brand Icon Header
                    Container(
                      width: 80,
                      height: 80,
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          // 1. Sparkles around
                          Positioned(
                            top: 4,
                            left: 4,
                            child: Icon(Icons.star_rounded, color: Colors.white.withOpacity(0.8), size: 12),
                          ),
                          Positioned(
                            bottom: 8,
                            right: 4,
                            child: Icon(Icons.star_rounded, color: BankingTheme.accentCyan.withOpacity(0.8), size: 10),
                          ),
                          // 2. Phone Outline (Cyan)
                          Transform.rotate(
                            angle: 0.15, // Tilted slightly to the right
                            child: Container(
                              width: 36,
                              height: 60,
                              decoration: BoxDecoration(
                                color: BankingTheme.cardBg,
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: BankingTheme.accentCyan, width: 2),
                                boxShadow: [
                                  BoxShadow(
                                    color: BankingTheme.accentCyan.withOpacity(0.2),
                                    blurRadius: 8,
                                    spreadRadius: 1,
                                  )
                                ]
                              ),
                              child: Stack(
                                children: [
                                  // Screen glass sheen
                                  Positioned.fill(
                                    child: Container(
                                      decoration: BoxDecoration(
                                        borderRadius: BorderRadius.circular(6),
                                        gradient: LinearGradient(
                                          begin: Alignment.topLeft,
                                          end: Alignment.bottomRight,
                                          colors: [
                                            Colors.white.withOpacity(0.05),
                                            Colors.transparent,
                                          ],
                                        ),
                                      ),
                                    ),
                                  ),
                                  // Envelope in phone
                                  const Center(
                                    child: Icon(
                                      Icons.mail_outline_rounded,
                                      color: Colors.blueAccent,
                                      size: 16,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          // 3. Typing message bubble (Cyan)
                          Positioned(
                            top: 4,
                            right: 4,
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                              decoration: BoxDecoration(
                                color: BankingTheme.accentCyan,
                                borderRadius: BorderRadius.circular(10).copyWith(bottomLeft: Radius.zero),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Container(width: 3, height: 3, decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle)),
                                  const SizedBox(width: 2),
                                  Container(width: 3, height: 3, decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle)),
                                  const SizedBox(width: 2),
                                  Container(width: 3, height: 3, decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle)),
                                ],
                              ),
                            ),
                          ),
                          // 4. Delivered bubble (Dark with checkmark)
                          Positioned(
                            top: 24,
                            right: 0,
                            child: Container(
                              padding: const EdgeInsets.all(3),
                              decoration: BoxDecoration(
                                color: const Color(0xFF0F172A),
                                shape: BoxShape.circle,
                                border: Border.all(color: Colors.white.withOpacity(0.1)),
                              ),
                              child: const Icon(
                                Icons.check_circle_rounded,
                                color: BankingTheme.primary,
                                size: 14,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      _isRegister ? 'Créer un compte' : 'SendReach',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            fontSize: 28,
                            fontWeight: FontWeight.w800,
                            letterSpacing: -0.8,
                          ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _isRegister 
                          ? 'Intégrez la première API d\'envoi de SMS professionnels' 
                          : 'Connectez-vous à votre plateforme d\'envoi',
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                    const SizedBox(height: 32),

                    // Translucent Login Card
                    GlassCard(
                      glowColor: auth.errorMessage != null ? Colors.red : BankingTheme.primary,
                      child: Form(
                        key: _formKey,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            // Show server errors if present
                            if (auth.errorMessage != null) ...[
                              Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: Colors.red.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(color: Colors.red.withOpacity(0.3), width: 1.0),
                                ),
                                child: Row(
                                  children: [
                                    const Icon(Icons.error_outline_rounded, color: Colors.redAccent, size: 20),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        auth.errorMessage!,
                                        style: const TextStyle(color: Colors.redAccent, fontSize: 13),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 16),
                            ],

                            // Company Name Input (Only on Register)
                            if (_isRegister) ...[
                              _buildTextField(
                                controller: _companyController,
                                label: 'Nom de l\'entreprise',
                                icon: Icons.business_rounded,
                                validator: (val) => val == null || val.isEmpty ? 'Champ requis' : null,
                              ),
                              const SizedBox(height: 16),
                            ],

                            // Email Input
                            _buildTextField(
                              controller: _emailController,
                              label: 'Adresse e-mail',
                              icon: Icons.email_outlined,
                              keyboardType: TextInputType.emailAddress,
                              validator: (val) {
                                if (val == null || val.isEmpty) return 'Champ requis';
                                if (!val.contains('@')) return 'Format e-mail invalide';
                                return null;
                              },
                            ),
                            const SizedBox(height: 16),

                            // Password Input
                            _buildTextField(
                              controller: _passwordController,
                              label: 'Mot de passe',
                              icon: Icons.lock_outline_rounded,
                              obscureText: _obscurePassword,
                              validator: (val) => val == null || val.length < 6 ? 'Minimum 6 caractères' : null,
                              suffixIcon: IconButton(
                                icon: Icon(
                                  _obscurePassword ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                                  color: BankingTheme.textSecondary,
                                  size: 20,
                                ),
                                onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                              ),
                            ),
                            const SizedBox(height: 24),

                            // Action Button
                            ElevatedButton(
                              onPressed: auth.isLoading ? null : _submit,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: BankingTheme.primary,
                                padding: const EdgeInsets.symmetric(vertical: 16),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                elevation: 5,
                              ),
                              child: auth.isLoading
                                  ? const SizedBox(
                                      height: 20,
                                      width: 20,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        valueColor: AlwaysStoppedAnimation(Color(0xFF0A0F1D)),
                                      ),
                                    )
                                  : Text(
                                      _isRegister ? 'CRÉER MON COMPTE' : 'CONNEXION SÉCURISÉE',
                                      style: GoogleFonts.poppins(
                                        color: const Color(0xFF0A0F1D),
                                        fontWeight: FontWeight.bold,
                                        fontSize: 15,
                                      ),
                                    ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Toggle Button Between Login & Register
                    TextButton(
                      onPressed: () {
                        auth.clearError();
                        setState(() {
                          _isRegister = !_isRegister;
                        });
                      },
                      child: Text(
                        _isRegister 
                            ? 'Déjà inscrit ? Connectez-vous' 
                            : 'Nouveau client ? Ouvrez un compte professionnel',
                        style: GoogleFonts.poppins(
                          color: BankingTheme.primary,
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    bool obscureText = false,
    TextInputType? keyboardType,
    String? Function(String?)? validator,
    Widget? suffixIcon,
  }) {
    return TextFormField(
      controller: controller,
      obscureText: obscureText,
      keyboardType: keyboardType,
      validator: validator,
      style: const TextStyle(color: Colors.white, fontSize: 15),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(color: BankingTheme.textSecondary, fontSize: 14),
        prefixIcon: Icon(icon, color: BankingTheme.primary, size: 20),
        suffixIcon: suffixIcon,
        filled: true,
        fillColor: BankingTheme.background.withOpacity(0.5),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.white.withOpacity(0.05)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.white.withOpacity(0.05)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: BankingTheme.primary, width: 1.0),
        ),
        errorStyle: const TextStyle(color: Colors.redAccent),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Colors.redAccent, width: 1.0),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Colors.redAccent, width: 1.2),
        ),
      ),
    );
  }
}
