import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/theme/banking_theme.dart';
import '../../core/widgets/glass_card.dart';
import '../dashboard/dashboard_controller.dart';

class WalletScreen extends StatefulWidget {
  const WalletScreen({Key? key}) : super(key: key);

  @override
  State<WalletScreen> createState() => _WalletScreenState();
}

class _WalletScreenState extends State<WalletScreen> {
  final _amountController = TextEditingController();
  double? _selectedAmount;

  // Payments & Auto-Recharge parameters
  String _paymentMethod = 'MOBILE_MONEY'; // 'CARD' or 'MOBILE_MONEY'
  String _mmProvider = 'WAVE'; // 'WAVE', 'ORANGE', 'MTN'
  final _mmPhoneController = TextEditingController(text: '+225 0708091011');

  bool _autoRechargeEnabled = false;
  double _autoRechargeThreshold = 10.0;
  double _autoRechargeAmount = 50.0;
  String _autoRechargeProvider = 'WAVE';
  final _autoRechargePhoneController = TextEditingController(text: '+225 0708091011');

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final dash = Provider.of<DashboardController>(context, listen: false);
      dash.fetchDashboardData();
      final settings = dash.autoRechargeSetting;
      setState(() {
        _autoRechargeEnabled = settings['enabled'] ?? false;
        _autoRechargeThreshold = double.tryParse(settings['threshold']?.toString() ?? '10.0') ?? 10.0;
        _autoRechargeAmount = double.tryParse(settings['rechargeAmount']?.toString() ?? '50.0') ?? 50.0;
        _autoRechargeProvider = settings['provider'] ?? 'WAVE';
        if (settings['phoneNumber'] != null && settings['phoneNumber'].toString().isNotEmpty) {
          _autoRechargePhoneController.text = settings['phoneNumber'];
        }
      });
    });
  }

  @override
  void dispose() {
    _amountController.dispose();
    _mmPhoneController.dispose();
    _autoRechargePhoneController.dispose();
    super.dispose();
  }

  void _triggerDeposit(double amount) async {
    final dash = Provider.of<DashboardController>(context, listen: false);
    final success = await dash.deposit(amount);

    if (success && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Crédit de $amount € déposé avec succès !', 
              style: const TextStyle(color: Color(0xFF0A0F1D), fontWeight: FontWeight.bold)),
          backgroundColor: BankingTheme.primary,
          behavior: SnackBarBehavior.floating,
        ),
      );
      _amountController.clear();
      setState(() {
        _selectedAmount = null;
      });
    }
  }

  void _triggerMobileMoneyPayment(double amount, String provider, String phone) async {
    final dash = Provider.of<DashboardController>(context, listen: false);
    
    // Display loading / USSD push dialogue
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            bool approvalInFlight = false;
            return AlertDialog(
              backgroundColor: BankingTheme.cardBg,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: const BorderSide(color: BankingTheme.borderLight),
              ),
              title: Row(
                children: [
                  const Icon(Icons.phonelink_ring_rounded, color: BankingTheme.accentCyan),
                  const SizedBox(width: 10),
                  Text('Push USSD $provider', style: GoogleFonts.poppins(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
                ],
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'Une demande de débit de ${(amount * 655.957).toStringAsFixed(0)} XOF (~ $amount €) a été envoyée au numéro $phone.',
                    style: const TextStyle(color: BankingTheme.textSecondary, fontSize: 13),
                  ),
                  const SizedBox(height: 16),
                  if (approvalInFlight) ...[
                    const Center(child: CircularProgressIndicator(color: BankingTheme.primary)),
                    const SizedBox(height: 10),
                    const Text('Attente de confirmation opérateur...', textAlign: TextAlign.center, style: TextStyle(color: BankingTheme.primary, fontSize: 12, fontWeight: FontWeight.bold)),
                  ] else ...[
                    const Text('Saisissez votre code secret sur votre téléphone pour approuver le débit, puis simulez la confirmation :', style: TextStyle(color: Colors.white70, fontSize: 12)),
                  ],
                ],
              ),
              actions: [
                if (!approvalInFlight) ...[
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('ANNULER', style: TextStyle(color: Colors.redAccent)),
                  ),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: BankingTheme.primary,
                      foregroundColor: BankingTheme.background,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    onPressed: () async {
                      setDialogState(() {
                        approvalInFlight = true;
                      });
                      
                      // 1. Initialiser le paiement
                      final paymentDetails = await dash.initializeMobileMoneyPayment(amount, provider, phone);
                      if (paymentDetails != null) {
                        // 2. Simuler le callback webhook réussi après 1.5s
                        await Future.delayed(const Duration(milliseconds: 1500));
                        await dash.simulateWebhookCallback(paymentDetails['paymentId'], 'SUCCESS');
                        
                        if (mounted) {
                          Navigator.pop(context); // Close dialog
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('Paiement réussi ! Votre solde a été rechargé de $amount €.', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                              backgroundColor: BankingTheme.primary,
                              behavior: SnackBarBehavior.floating,
                            ),
                          );
                        }
                      } else {
                        if (mounted) Navigator.pop(context);
                      }
                    },
                    child: const Text('SIMULER LE CODE SECRET (OK)'),
                  ),
                ],
              ],
            );
          }
        );
      }
    );
  }

  void _saveAutoRechargeSettings() async {
    final dash = Provider.of<DashboardController>(context, listen: false);
    final success = await dash.updateAutoRechargeSetting({
      'enabled': _autoRechargeEnabled,
      'threshold': _autoRechargeThreshold,
      'rechargeAmount': _autoRechargeAmount,
      'provider': _autoRechargeProvider,
      'phoneNumber': _autoRechargePhoneController.text
    });

    if (success && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Paramètres de rechargement automatique enregistrés avec succès !', style: TextStyle(color: Color(0xFF0A0F1D), fontWeight: FontWeight.bold)),
          backgroundColor: BankingTheme.primary,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  void _showInvoiceDetails(dynamic invoice) {
    showDialog(
      context: context,
      builder: (context) {
        final totalXOF = double.tryParse(invoice['total']?.toString() ?? '0') ?? 0.0;
        final subtotalXOF = totalXOF * 0.82;
        final taxXOF = totalXOF * 0.18;
        final provider = invoice['provider']?.toString() ?? 'WAVE';
        final invoiceNum = invoice['invoiceNumber']?.toString() ?? '';
        final date = invoice['createdAt']?.toString() ?? '';
        final dateStr = date.length >= 10 ? date.substring(0, 10) : date;

        return AlertDialog(
          backgroundColor: BankingTheme.cardBg,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: const BorderSide(color: BankingTheme.borderLight),
          ),
          title: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Facture SendReach', style: GoogleFonts.poppins(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: BankingTheme.primary.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: BankingTheme.primary),
                ),
                child: const Text('PAYÉE', style: TextStyle(color: BankingTheme.primary, fontSize: 10, fontWeight: FontWeight.bold)),
              ),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Divider(color: BankingTheme.borderLight),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('N° Facture :', style: TextStyle(color: BankingTheme.textSecondary, fontSize: 12)),
                    Text(invoiceNum, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12)),
                  ],
                ),
                const SizedBox(height: 6),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Date émission :', style: TextStyle(color: BankingTheme.textSecondary, fontSize: 12)),
                    Text(dateStr, style: const TextStyle(color: Colors.white, fontSize: 12)),
                  ],
                ),
                const SizedBox(height: 6),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Moyen Paiement :', style: TextStyle(color: BankingTheme.textSecondary, fontSize: 12)),
                    Text('Mobile Money ($provider)', style: const TextStyle(color: BankingTheme.accentCyan, fontSize: 12, fontWeight: FontWeight.bold)),
                  ],
                ),
                const SizedBox(height: 16),
                const Text('Détails financiers :', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: BankingTheme.background.withOpacity(0.5),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('Sous-total HT :', style: TextStyle(color: Colors.grey, fontSize: 11)),
                          Text('${subtotalXOF.toStringAsFixed(0)} XOF', style: const TextStyle(color: Colors.white70, fontSize: 11)),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('TVA (18%) :', style: TextStyle(color: Colors.grey, fontSize: 11)),
                          Text('${taxXOF.toStringAsFixed(0)} XOF', style: const TextStyle(color: Colors.white70, fontSize: 11)),
                        ],
                      ),
                      const SizedBox(height: 8),
                      const Divider(color: Colors.white10),
                      const SizedBox(height: 4),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('Total TTC :', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
                          Text('${totalXOF.toStringAsFixed(0)} XOF', style: const TextStyle(color: BankingTheme.primary, fontWeight: FontWeight.bold, fontSize: 13)),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                const Text(
                  'Merci pour votre confiance en SendReach SAS pour vos campagnes SMS !',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.grey, fontSize: 10, fontStyle: FontStyle.italic),
                ),
              ],
            ),
          ),
          actions: [
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: BankingTheme.accentCyan,
                foregroundColor: BankingTheme.background,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              onPressed: () => Navigator.pop(context),
              icon: const Icon(Icons.check, size: 16),
              label: const Text('FERMER'),
            ),
          ],
        );
      },
    );
  }

  Widget _buildOperatorBadge(String name, Color color, IconData icon, bool isSelected, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected ? color.withOpacity(0.15) : BankingTheme.cardBg,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? color : Colors.white.withOpacity(0.06),
            width: 1.5,
          ),
          boxShadow: isSelected
              ? [BoxShadow(color: color.withOpacity(0.2), blurRadius: 8, spreadRadius: 1)]
              : null,
        ),
        child: Row(
          children: [
            Icon(icon, color: isSelected ? color : Colors.white60, size: 16),
            const SizedBox(width: 8),
            Text(
              name,
              style: GoogleFonts.poppins(
                color: isSelected ? color : Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final dash = Provider.of<DashboardController>(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Portefeuille & Facturation',
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
              // 1. BANK CARD DISPLAY
              GlassCard(
                glowColor: BankingTheme.accentCyan,
                padding: EdgeInsets.zero,
                child: Container(
                  padding: const EdgeInsets.all(24),
                  decoration: const BoxDecoration(
                    gradient: BankingTheme.sendReachGradient,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'SENDREACH ENTERPRISE WALLET',
                            style: GoogleFonts.poppins(
                              color: const Color(0xFF0A0F1D).withOpacity(0.6),
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 1.5,
                            ),
                          ),
                          const Icon(Icons.account_balance_wallet_rounded, color: Color(0xFF0A0F1D), size: 24),
                        ],
                      ),
                      const SizedBox(height: 36),
                      Text(
                        '${dash.balance.toStringAsFixed(2)} €',
                        style: GoogleFonts.poppins(
                          color: const Color(0xFF0A0F1D),
                          fontSize: 38,
                          fontWeight: FontWeight.w900,
                          letterSpacing: -1.0,
                        ),
                      ),
                      const SizedBox(height: 32),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'COMPTE ACTIF',
                            style: GoogleFonts.poppins(
                              color: const Color(0xFF0A0F1D).withOpacity(0.6),
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 1.0,
                            ),
                          ),
                          Text(
                            'SUPPORT: MOBILE MONEY (XOF)',
                            style: GoogleFonts.poppins(
                              color: const Color(0xFF0A0F1D).withOpacity(0.8),
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 1.0,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),

              // TAB METHOD SELECTOR
              Row(
                children: [
                  Expanded(
                    child: GestureDetector(
                      onTap: () => setState(() => _paymentMethod = 'MOBILE_MONEY'),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        decoration: BoxDecoration(
                          border: Border(
                            bottom: BorderSide(
                              color: _paymentMethod == 'MOBILE_MONEY' ? BankingTheme.accentCyan : Colors.transparent,
                              width: 2,
                            ),
                          ),
                        ),
                        child: Text(
                          'Mobile Money (CFA)',
                          textAlign: TextAlign.center,
                          style: GoogleFonts.poppins(
                            color: _paymentMethod == 'MOBILE_MONEY' ? Colors.white : BankingTheme.textSecondary,
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                          ),
                        ),
                      ),
                    ),
                  ),
                  Expanded(
                    child: GestureDetector(
                      onTap: () => setState(() => _paymentMethod = 'CARD'),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        decoration: BoxDecoration(
                          border: Border(
                            bottom: BorderSide(
                              color: _paymentMethod == 'CARD' ? BankingTheme.primary : Colors.transparent,
                              width: 2,
                            ),
                          ),
                        ),
                        child: Text(
                          'Carte Bancaire (€)',
                          textAlign: TextAlign.center,
                          style: GoogleFonts.poppins(
                            color: _paymentMethod == 'CARD' ? Colors.white : BankingTheme.textSecondary,
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // 2. PAYMENT METHOD CONDITIONAL RENDERING
              if (_paymentMethod == 'CARD') ...[
                // ORIGINAL CREDIT CARD LAYOUT
                Text(
                  'ALIMENTATION RAPIDE DU COMPTE',
                  style: GoogleFonts.poppins(
                    color: BankingTheme.textSecondary,
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.5,
                  ),
                ),
                const SizedBox(height: 12),
                GridView.count(
                  crossAxisCount: 4,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  crossAxisSpacing: 10,
                  mainAxisSpacing: 10,
                  childAspectRatio: 1.3,
                  children: [10.0, 20.0, 50.0, 100.0].map((amt) {
                    final isSelected = _selectedAmount == amt;
                    return GlassCard(
                      padding: EdgeInsets.zero,
                      glowColor: isSelected ? BankingTheme.primary : null,
                      border: Border.all(
                        color: isSelected ? BankingTheme.primary : Colors.white.withOpacity(0.06),
                        width: 1.0,
                      ),
                      onTap: () {
                        setState(() {
                          _selectedAmount = amt;
                          _amountController.text = amt.toString();
                        });
                      },
                      child: Center(
                        child: Text(
                          '+$amt €',
                          style: GoogleFonts.poppins(
                            color: isSelected ? BankingTheme.primary : Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 16),
                GlassCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      TextFormField(
                        controller: _amountController,
                        style: const TextStyle(color: Colors.white, fontSize: 16),
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        decoration: InputDecoration(
                          labelText: 'Saisir un montant spécifique (€)',
                          labelStyle: const TextStyle(color: BankingTheme.textSecondary, fontSize: 13),
                          prefixIcon: const Icon(Icons.euro_rounded, color: BankingTheme.primary, size: 20),
                          filled: true,
                          fillColor: BankingTheme.background.withOpacity(0.5),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(color: Colors.white.withOpacity(0.05)),
                          ),
                        ),
                        onChanged: (val) {
                          setState(() {
                            _selectedAmount = double.tryParse(val);
                          });
                        },
                      ),
                      const SizedBox(height: 16),
                      ElevatedButton.icon(
                        onPressed: () {
                          final val = double.tryParse(_amountController.text);
                          if (val != null && val > 0) {
                            _triggerDeposit(val);
                          }
                        },
                        icon: const Icon(Icons.credit_card_rounded, size: 18),
                        label: const Text('DÉPOSER DES CRÉDITS'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: BankingTheme.primary,
                          foregroundColor: BankingTheme.background,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                      ),
                    ],
                  ),
                ),
              ] else ...[
                // MOBILE MONEY LAYOUT (WAVE / ORANGE / MTN)
                Text(
                  'SÉLECTIONNEZ VOTRE OPÉRATEUR MOBILE MONEY',
                  style: GoogleFonts.poppins(
                    color: BankingTheme.textSecondary,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.5,
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    _buildOperatorBadge('Wave', const Color(0xFF38BDF8), Icons.waves_rounded, _mmProvider == 'WAVE', () => setState(() => _mmProvider = 'WAVE')),
                    _buildOperatorBadge('Orange', const Color(0xFFFF6B00), Icons.phone_android_rounded, _mmProvider == 'ORANGE', () => setState(() => _mmProvider = 'ORANGE')),
                    _buildOperatorBadge('MTN', const Color(0xFFFFCC00), Icons.flash_on_rounded, _mmProvider == 'MTN', () => setState(() => _mmProvider = 'MTN')),
                  ],
                ),
                const SizedBox(height: 16),
                GlassCard(
                  glowColor: BankingTheme.accentCyan,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Preset selections with XOF display
                      GridView.count(
                        crossAxisCount: 2,
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        crossAxisSpacing: 10,
                        mainAxisSpacing: 10,
                        childAspectRatio: 2.2,
                        children: [10.0, 20.0, 50.0, 100.0].map((amt) {
                          final isSelected = _selectedAmount == amt;
                          return GestureDetector(
                            onTap: () {
                              setState(() {
                                _selectedAmount = amt;
                                _amountController.text = amt.toString();
                              });
                            },
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 200),
                              decoration: BoxDecoration(
                                color: isSelected ? BankingTheme.accentCyan.withOpacity(0.1) : BankingTheme.background.withOpacity(0.5),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: isSelected ? BankingTheme.accentCyan : Colors.white.withOpacity(0.05),
                                  width: 1.5,
                                ),
                              ),
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Text(
                                    '+$amt €',
                                    style: GoogleFonts.poppins(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
                                  ),
                                  Text(
                                    '~ ${(amt * 655.957).toStringAsFixed(0)} XOF',
                                    style: const TextStyle(color: BankingTheme.textSecondary, fontSize: 10),
                                  ),
                                ],
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                      const SizedBox(height: 16),
                      
                      TextFormField(
                        controller: _amountController,
                        style: const TextStyle(color: Colors.white, fontSize: 16),
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        decoration: InputDecoration(
                          labelText: 'Crédits SMS à acheter (€)',
                          labelStyle: const TextStyle(color: BankingTheme.textSecondary, fontSize: 13),
                          prefixIcon: const Icon(Icons.euro_rounded, color: BankingTheme.accentCyan, size: 20),
                          filled: true,
                          fillColor: BankingTheme.background.withOpacity(0.5),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(color: Colors.white.withOpacity(0.05)),
                          ),
                        ),
                        onChanged: (val) {
                          setState(() {
                            _selectedAmount = double.tryParse(val);
                          });
                        },
                      ),
                      const SizedBox(height: 12),
                      
                      TextFormField(
                        controller: _mmPhoneController,
                        style: const TextStyle(color: Colors.white, fontSize: 16),
                        keyboardType: TextInputType.phone,
                        decoration: InputDecoration(
                          labelText: 'Numéro de Téléphone Mobile Money',
                          labelStyle: const TextStyle(color: BankingTheme.textSecondary, fontSize: 13),
                          prefixIcon: const Icon(Icons.phone_iphone_rounded, color: BankingTheme.accentCyan, size: 20),
                          filled: true,
                          fillColor: BankingTheme.background.withOpacity(0.5),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(color: Colors.white.withOpacity(0.05)),
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      
                      ElevatedButton.icon(
                        onPressed: () {
                          final val = double.tryParse(_amountController.text);
                          if (val != null && val > 0) {
                            _triggerMobileMoneyPayment(val, _mmProvider, _mmPhoneController.text);
                          }
                        },
                        icon: const Icon(Icons.payment_rounded, size: 18),
                        label: Text('PAYER ${( (_selectedAmount ?? 0) * 655.957 ).toStringAsFixed(0)} XOF'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: BankingTheme.accentCyan,
                          foregroundColor: BankingTheme.background,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 24),

              // 3. AUTO-RECHARGE RULES PANEL
              Text(
                'SECOUR DES CRÉDITS (RECHARGEMENT AUTOMATIQUE)',
                style: GoogleFonts.poppins(
                  color: BankingTheme.textSecondary,
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.5,
                ),
              ),
              const SizedBox(height: 12),
              GlassCard(
                glowColor: _autoRechargeEnabled ? BankingTheme.primary : null,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Activer la recharge automatique',
                              style: GoogleFonts.poppins(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
                            ),
                            const Text(
                              'Évite la rupture d\'envois en production.',
                              style: TextStyle(color: BankingTheme.textSecondary, fontSize: 10),
                            ),
                          ],
                        ),
                        Switch(
                          value: _autoRechargeEnabled,
                          activeColor: BankingTheme.primary,
                          onChanged: (val) {
                            setState(() {
                              _autoRechargeEnabled = val;
                            });
                          },
                        ),
                      ],
                    ),
                    if (_autoRechargeEnabled) ...[
                      const SizedBox(height: 16),
                      const Divider(color: Colors.white10),
                      const SizedBox(height: 8),
                      
                      // Auto-Recharge Operator Choice
                      Text(
                        'OPÉRATEUR POUR LA RECHARGE AUTOMATIQUE',
                        style: GoogleFonts.poppins(color: BankingTheme.textSecondary, fontSize: 9, fontWeight: FontWeight.bold, letterSpacing: 1.0),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          _buildOperatorBadge('Wave', const Color(0xFF38BDF8), Icons.waves_rounded, _autoRechargeProvider == 'WAVE', () => setState(() => _autoRechargeProvider = 'WAVE')),
                          _buildOperatorBadge('Orange', const Color(0xFFFF6B00), Icons.phone_android_rounded, _autoRechargeProvider == 'ORANGE', () => setState(() => _autoRechargeProvider = 'ORANGE')),
                          _buildOperatorBadge('MTN', const Color(0xFFFFCC00), Icons.flash_on_rounded, _autoRechargeProvider == 'MTN', () => setState(() => _autoRechargeProvider = 'MTN')),
                        ],
                      ),
                      const SizedBox(height: 12),
                      
                      TextFormField(
                        controller: _autoRechargePhoneController,
                        style: const TextStyle(color: Colors.white, fontSize: 15),
                        decoration: InputDecoration(
                          labelText: 'Numéro de prélèvement automatique',
                          labelStyle: const TextStyle(color: BankingTheme.textSecondary, fontSize: 12),
                          filled: true,
                          fillColor: BankingTheme.background.withOpacity(0.5),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                      ),
                      const SizedBox(height: 16),
                      
                      // Threshold Selector
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('Déclencher si solde <', style: GoogleFonts.poppins(color: Colors.white, fontSize: 12)),
                          Text('${_autoRechargeThreshold.toStringAsFixed(0)} €', style: GoogleFonts.poppins(color: BankingTheme.primary, fontWeight: FontWeight.bold, fontSize: 14)),
                        ],
                      ),
                      Slider(
                        value: _autoRechargeThreshold,
                        min: 5.0,
                        max: 50.0,
                        divisions: 9,
                        activeColor: BankingTheme.primary,
                        inactiveColor: Colors.white10,
                        onChanged: (val) {
                          setState(() {
                            _autoRechargeThreshold = val;
                          });
                        },
                      ),
                      
                      // Recharge Amount Selector
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('Montant de recharge auto', style: GoogleFonts.poppins(color: Colors.white, fontSize: 12)),
                          Text('${_autoRechargeAmount.toStringAsFixed(0)} €', style: GoogleFonts.poppins(color: BankingTheme.accentCyan, fontWeight: FontWeight.bold, fontSize: 14)),
                        ],
                      ),
                      Slider(
                        value: _autoRechargeAmount,
                        min: 10.0,
                        max: 200.0,
                        divisions: 19,
                        activeColor: BankingTheme.accentCyan,
                        inactiveColor: Colors.white10,
                        onChanged: (val) {
                          setState(() {
                            _autoRechargeAmount = val;
                          });
                        },
                      ),
                    ],
                    const SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: _saveAutoRechargeSettings,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: BankingTheme.primary,
                        foregroundColor: BankingTheme.background,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      child: const Text('ENREGISTRER LES PARAMÈTRES', style: TextStyle(fontWeight: FontWeight.bold)),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // 4. FACTURES LEGALES LIST
              Text(
                'HISTORIQUE DE FACTURATION LÉGALE',
                style: GoogleFonts.poppins(
                  color: BankingTheme.textSecondary,
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.5,
                ),
              ),
              const SizedBox(height: 12),
              
              if (dash.invoices.isEmpty) ...[
                const GlassCard(
                  child: Padding(
                    padding: EdgeInsets.symmetric(vertical: 24),
                    child: Center(
                      child: Text('Aucune facture générée.', style: TextStyle(color: BankingTheme.textSecondary, fontSize: 12)),
                    ),
                  ),
                ),
              ] else ...[
                ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: dash.invoices.length,
                  separatorBuilder: (context, index) => const SizedBox(height: 10),
                  itemBuilder: (context, index) {
                    final invoice = dash.invoices[index];
                    final date = invoice['createdAt']?.toString() ?? '';
                    final dateStr = date.length >= 10 ? date.substring(0, 10) : date;
                    final totalVal = double.tryParse(invoice['total']?.toString() ?? '0.0') ?? 0.0;
                    final prov = invoice['provider']?.toString() ?? 'WAVE';

                    return GlassCard(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: BankingTheme.accentCyan.withOpacity(0.1),
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(
                                  Icons.receipt_long_rounded,
                                  color: BankingTheme.accentCyan,
                                  size: 16,
                                ),
                              ),
                              const SizedBox(width: 14),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    invoice['invoiceNumber']?.toString() ?? '',
                                    style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white, fontSize: 12),
                                  ),
                                  const SizedBox(height: 3),
                                  Text(
                                    '$dateStr — MM ($prov)',
                                    style: const TextStyle(color: BankingTheme.textSecondary, fontSize: 9),
                                  ),
                                ],
                              ),
                            ],
                          ),
                          Row(
                            children: [
                              Text(
                                '${totalVal.toStringAsFixed(0)} XOF',
                                style: GoogleFonts.poppins(
                                  color: BankingTheme.primary,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12,
                                ),
                              ),
                              const SizedBox(width: 8),
                              GestureDetector(
                                onTap: () => _showInvoiceDetails(invoice),
                                child: Container(
                                  padding: const EdgeInsets.all(6),
                                  decoration: BoxDecoration(
                                    color: Colors.white.withOpacity(0.05),
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(Icons.remove_red_eye_rounded, color: Colors.white70, size: 14),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ],
              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }
}
