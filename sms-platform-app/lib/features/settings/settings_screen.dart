import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/theme/banking_theme.dart';
import '../../core/widgets/glass_card.dart';
import '../dashboard/dashboard_controller.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({Key? key}) : super(key: key);

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final _senderIdController = TextEditingController();
  final _webhookUrlController = TextEditingController(text: 'https://monentreprise.com/api/v1/sms/callback');
  
  bool _hideApiKey = true;
  final String _apiKey = 'live_key_sms_981ab28dfc90234e12e1092abf48';

  @override
  void dispose() {
    _senderIdController.dispose();
    _webhookUrlController.dispose();
    super.dispose();
  }

  void _copyApiKey() {
    Clipboard.setData(ClipboardData(text: _apiKey));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('Clé d\'API copiée dans le presse-papiers !',
            style: TextStyle(color: Color(0xFF0A0F1D), fontWeight: FontWeight.bold)),
        backgroundColor: BankingTheme.primary,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _submitSenderIdRequest() {
    final name = _senderIdController.text.trim().toUpperCase();
    if (name.isEmpty) return;

    // Local validation for alphanumeric Sender ID
    final regex = RegExp(r'^[A-Z0-9]{3,11}$');
    if (!regex.hasMatch(name)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Le Sender ID doit faire entre 3 et 11 caractères alphanumériques.', 
              style: TextStyle(color: Color(0xFF0A0F1D), fontWeight: FontWeight.bold)),
          backgroundColor: Colors.orange,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Demande d\'expéditeur "$name" soumise avec succès !',
            style: const TextStyle(color: Color(0xFF0A0F1D), fontWeight: FontWeight.bold)),
        backgroundColor: BankingTheme.primary,
        behavior: SnackBarBehavior.floating,
      ),
    );
    _senderIdController.clear();
  }

  @override
  Widget build(BuildContext context) {
    final dash = Provider.of<DashboardController>(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Administration & API',
          style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 20),
        ),
        backgroundColor: BankingTheme.background,
        elevation: 0,
      ),
      body: Container(
        decoration: const BoxDecoration(color: BankingTheme.background),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // 1. DEVELOPER CREDENTIALS CARD (API KEYS)
              GlassCard(
                glowColor: Colors.purpleAccent,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'CLÉ D\'API DEVELOPPEUR (LIVE)',
                          style: GoogleFonts.poppins(
                            color: BankingTheme.textSecondary,
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 1.5,
                          ),
                        ),
                        const Icon(Icons.code_rounded, color: Colors.purpleAccent, size: 18),
                      ],
                    ),
                    const SizedBox(height: 16),
                    // Masked API Key view
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: BankingTheme.background.withOpacity(0.5),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: Colors.white.withOpacity(0.04)),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Text(
                              _hideApiKey ? '••••••••••••••••••••••••••••••••••••••••' : _apiKey,
                              style: GoogleFonts.sourceCodePro(
                                color: Colors.white70,
                                fontSize: 13,
                                letterSpacing: 0.5,
                              ),
                            ),
                          ),
                          Row(
                            children: [
                              IconButton(
                                icon: Icon(
                                  _hideApiKey ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                                  color: BankingTheme.textSecondary,
                                  size: 18,
                                ),
                                onPressed: () => setState(() => _hideApiKey = !_hideApiKey),
                              ),
                              IconButton(
                                icon: const Icon(Icons.copy_rounded, color: BankingTheme.primary, size: 18),
                                onPressed: _copyApiKey,
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // 2. SENDER ID REGISTRY APPLICATIONS
              GlassCard(
                glowColor: BankingTheme.primary,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      'SOUMETTRE UN SENDER ID ALPHANUMÉRIQUE',
                      style: GoogleFonts.poppins(
                        color: BankingTheme.textSecondary,
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1.5,
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _senderIdController,
                      style: const TextStyle(color: Colors.white, fontSize: 15),
                      maxLength: 11,
                      decoration: InputDecoration(
                        labelText: 'Nom de l\'Expéditeur (ex: MYCOMPANY)',
                        labelStyle: const TextStyle(color: BankingTheme.textSecondary, fontSize: 13),
                        prefixIcon: const Icon(Icons.verified_user_outlined, color: BankingTheme.primary, size: 20),
                        filled: true,
                        fillColor: BankingTheme.background.withOpacity(0.5),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: Colors.white.withOpacity(0.05)),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    ElevatedButton.icon(
                      onPressed: _submitSenderIdRequest,
                      icon: const Icon(Icons.add_task_rounded, size: 18),
                      label: const Text('ENREGISTRER L\'EXPÉDITEUR'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: BankingTheme.primary,
                        foregroundColor: BankingTheme.background,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // Approved List
              Text(
                'REGISTRE DES EXPÉDITEURS',
                style: GoogleFonts.poppins(
                  color: BankingTheme.textSecondary,
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.5,
                ),
              ),
              const SizedBox(height: 12),
              ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: dash.senderIds.length,
                separatorBuilder: (context, index) => const SizedBox(height: 8),
                itemBuilder: (context, index) {
                  final s = dash.senderIds[index];
                  final status = s['status']?.toString().toUpperCase() ?? 'APPROVED';
                  return GlassCard(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.verified_rounded, color: BankingTheme.primary, size: 18),
                            const SizedBox(width: 12),
                            Text(
                              s['name']?.toString() ?? '',
                              style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white, fontSize: 14),
                            ),
                          ],
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                          decoration: BoxDecoration(
                            color: BankingTheme.primary.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            status,
                            style: const TextStyle(color: BankingTheme.primary, fontSize: 9, fontWeight: FontWeight.bold),
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
              const SizedBox(height: 24),

              // 3. OUTWARD WEBHOOK CONFIGURATION
              GlassCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      'URL DU WEBHOOK DE NOTIFICATION (DLR)',
                      style: GoogleFonts.poppins(
                        color: BankingTheme.textSecondary,
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1.5,
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _webhookUrlController,
                      style: const TextStyle(color: Colors.white, fontSize: 14),
                      decoration: InputDecoration(
                        labelText: 'Webhook Callback Endpoint',
                        labelStyle: const TextStyle(color: BankingTheme.textSecondary, fontSize: 13),
                        prefixIcon: const Icon(Icons.webhook_outlined, color: Colors.blueAccent, size: 20),
                        filled: true,
                        fillColor: BankingTheme.background.withOpacity(0.5),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton.icon(
                      onPressed: () {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: const Text('Configuration du Webhook enregistrée !', 
                                style: TextStyle(color: Color(0xFF0A0F1D), fontWeight: FontWeight.bold)),
                            backgroundColor: BankingTheme.primary,
                            behavior: SnackBarBehavior.floating,
                          ),
                        );
                      },
                      icon: const Icon(Icons.save_rounded, size: 18),
                      label: const Text('METTRE À JOUR LE CALLBACK'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.white.withOpacity(0.1),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
