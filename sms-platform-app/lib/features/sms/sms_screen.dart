import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/theme/banking_theme.dart';
import '../../core/widgets/glass_card.dart';
import '../dashboard/dashboard_controller.dart';

class SmsScreen extends StatefulWidget {
  const SmsScreen({Key? key}) : super(key: key);

  @override
  State<SmsScreen> createState() => _SmsScreenState();
}

class _SmsScreenState extends State<SmsScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  
  // Single SMS state
  final _toController = TextEditingController();
  final _msgController = TextEditingController();
  String? _selectedSenderId;
  
  // Campaign state
  final _recipientsController = TextEditingController(); // Comma-separated list for simplicity
  String? _selectedCampaignId;

  // Live GSM 7-bit segment calculator state
  int _charCount = 0;
  int _segments = 1;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _msgController.addListener(_updateCharCount);

    final dash = Provider.of<DashboardController>(context, listen: false);
    if (dash.senderIds.isNotEmpty) {
      _selectedSenderId = dash.senderIds[0]['name'];
    }
    if (dash.campaigns.isNotEmpty) {
      _selectedCampaignId = dash.campaigns[0]['id'];
    }
  }

  void _updateCharCount() {
    final text = _msgController.text;
    setState(() {
      _charCount = text.length;
      if (_charCount <= 160) {
        _segments = 1;
      } else {
        _segments = (_charCount / 153).ceil();
      }
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    _toController.dispose();
    _msgController.dispose();
    _recipientsController.dispose();
    super.dispose();
  }

  void _sendSingle() async {
    final to = _toController.text.trim();
    final msg = _msgController.text;
    final sender = _selectedSenderId;

    if (to.isEmpty || msg.isEmpty || sender == null) {
      _showSnackBar('Veuillez remplir tous les champs', Colors.orange);
      return;
    }

    final dash = Provider.of<DashboardController>(context, listen: false);
    final success = await dash.sendSingleSms(to, msg, sender);

    if (success) {
      _showSnackBar('SMS ajouté à la file d\'attente !', BankingTheme.primary);
      _toController.clear();
      _msgController.clear();
    } else {
      _showSnackBar('Erreur d\'envoi (Solde insuffisant ou numéro invalide)', Colors.redAccent);
    }
  }

  void _sendCampaign() async {
    final recipientsText = _recipientsController.text.trim();
    final campaignId = _selectedCampaignId;

    if (recipientsText.isEmpty || campaignId == null) {
      _showSnackBar('Veuillez spécifier les destinataires et la campagne', Colors.orange);
      return;
    }

    // Split by commas
    final recipients = recipientsText
        .split(',')
        .map((r) => r.trim())
        .where((r) => r.isNotEmpty)
        .toList();

    if (recipients.isEmpty) {
      _showSnackBar('Aucun numéro valide détecté', Colors.orange);
      return;
    }

    final dash = Provider.of<DashboardController>(context, listen: false);
    final success = await dash.triggerCampaign(campaignId, recipients);

    if (success) {
      _showSnackBar('Campagne en cours d\'envoi !', BankingTheme.primary);
      _recipientsController.clear();
    } else {
      _showSnackBar('Échec du déclenchement de la campagne', Colors.redAccent);
    }
  }

  void _showSnackBar(String text, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(text, style: const TextStyle(color: Color(0xFF0A0F1D), fontWeight: FontWeight.bold)),
        backgroundColor: color,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final dash = Provider.of<DashboardController>(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Services d\'Envoi',
          style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 20),
        ),
        backgroundColor: BankingTheme.background,
        elevation: 0,
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: BankingTheme.primary,
          labelColor: BankingTheme.primary,
          unselectedLabelColor: BankingTheme.textSecondary,
          tabs: const [
            Tab(icon: Icon(Icons.sms_outlined), text: 'Envoi Direct'),
            Tab(icon: Icon(Icons.campaign_outlined), text: 'Campagnes'),
          ],
        ),
      ),
      body: Container(
        decoration: const BoxDecoration(color: BankingTheme.background),
        child: TabBarView(
          controller: _tabController,
          children: [
            // Tab 1: Single SMS
            _buildSingleSmsTab(dash),
            // Tab 2: Campaigns
            _buildCampaignsTab(dash),
          ],
        ),
      ),
    );
  }

  Widget _buildSingleSmsTab(DashboardController dash) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Sending Form Card
          GlassCard(
            glowColor: BankingTheme.primary,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'ENVOYER UN SMS TRANSACTIONNEL',
                  style: GoogleFonts.poppins(
                    color: BankingTheme.textSecondary,
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.5,
                  ),
                ),
                const SizedBox(height: 20),

                // Sender ID Approved Dropdown
                _buildDropdownField(
                  label: 'Identifiant de l\'expéditeur (Sender ID)',
                  value: _selectedSenderId,
                  items: dash.senderIds.map<DropdownMenuItem<String>>((id) {
                    return DropdownMenuItem<String>(
                      value: id['name'],
                      child: Text(id['name']?.toString() ?? ''),
                    );
                  }).toList(),
                  onChanged: (val) => setState(() => _selectedSenderId = val),
                ),
                const SizedBox(height: 16),

                // Recipient
                _buildInputField(
                  controller: _toController,
                  label: 'Destinataire (Format E.164)',
                  hint: '+33612345678',
                  icon: Icons.phone_android_rounded,
                  keyboardType: TextInputType.phone,
                ),
                const SizedBox(height: 16),

                // Message body
                _buildInputField(
                  controller: _msgController,
                  label: 'Message',
                  hint: 'Saisissez votre message ici...',
                  icon: Icons.message_outlined,
                  maxLines: 4,
                ),
                const SizedBox(height: 8),

                // Live counter segments display
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Caractères : $_charCount',
                      style: const TextStyle(color: BankingTheme.textSecondary, fontSize: 12),
                    ),
                    Text(
                      'Segments SMS : $_segments (Max 1600)',
                      style: TextStyle(
                        color: _segments > 1 ? Colors.amber : BankingTheme.primary,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),

                // Action button
                ElevatedButton.icon(
                  onPressed: _sendSingle,
                  icon: const Icon(Icons.send_rounded, size: 18),
                  label: const Text('PROPAGER LE SMS'),
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
          const SizedBox(height: 24),

          // Transaction History list
          Text(
            'HISTORIQUE DE LIVRAISON',
            style: GoogleFonts.poppins(
              color: BankingTheme.textSecondary,
              fontSize: 11,
              fontWeight: FontWeight.bold,
              letterSpacing: 1.5,
            ),
          ),
          const SizedBox(height: 12),

          dash.recentLogs.isEmpty
              ? GlassCard(
                  child: const Center(child: Padding(padding: EdgeInsets.all(20), child: Text('Aucun log.'))),
                )
              : ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: dash.recentLogs.length,
                  separatorBuilder: (context, index) => const SizedBox(height: 10),
                  itemBuilder: (context, index) {
                    final log = dash.recentLogs[index];
                    return _buildLogCard(log);
                  },
                ),
        ],
      ),
    );
  }

  Widget _buildCampaignsTab(DashboardController dash) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Form Card
          GlassCard(
            glowColor: Colors.blueAccent,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'DÉCLENCHER UNE CAMPAGNE DE MASSE',
                  style: GoogleFonts.poppins(
                    color: BankingTheme.textSecondary,
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.5,
                  ),
                ),
                const SizedBox(height: 20),

                // Select Campaign Draft Dropdown
                _buildDropdownField(
                  label: 'Sélectionner la Campagne',
                  value: _selectedCampaignId,
                  items: dash.campaigns.map<DropdownMenuItem<String>>((camp) {
                    return DropdownMenuItem<String>(
                      value: camp['id'],
                      child: Text(camp['name']?.toString() ?? ''),
                    );
                  }).toList(),
                  onChanged: (val) => setState(() => _selectedCampaignId = val),
                ),
                const SizedBox(height: 16),

                // Recipients Text Area
                _buildInputField(
                  controller: _recipientsController,
                  label: 'Destinataires (Séparés par des virgules)',
                  hint: '+33612345678, +22507080910...',
                  icon: Icons.people_outline_rounded,
                  maxLines: 5,
                ),
                const SizedBox(height: 24),

                // Action button
                ElevatedButton.icon(
                  onPressed: _sendCampaign,
                  icon: const Icon(Icons.rocket_launch_rounded, size: 18),
                  label: const Text('LANCER LA CAMPAGNE'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blueAccent,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // Campaigns lists
          Text(
            'CAMPAGNES PLANIFIÉES ET EN COURS',
            style: GoogleFonts.poppins(
              color: BankingTheme.textSecondary,
              fontSize: 11,
              fontWeight: FontWeight.bold,
              letterSpacing: 1.5,
            ),
          ),
          const SizedBox(height: 12),

          dash.campaigns.isEmpty
              ? GlassCard(
                  child: const Center(child: Padding(padding: EdgeInsets.all(20), child: Text('Aucune campagne.'))),
                )
              : ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: dash.campaigns.length,
                  separatorBuilder: (context, index) => const SizedBox(height: 10),
                  itemBuilder: (context, index) {
                    final camp = dash.campaigns[index];
                    final status = camp['status']?.toString().toUpperCase() ?? 'DRAFT';
                    Color col = BankingTheme.textSecondary;
                    if (status == 'COMPLETED') col = BankingTheme.primary;
                    if (status == 'SENDING') col = Colors.blueAccent;

                    return GlassCard(
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(camp['name']?.toString() ?? '', style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
                              const SizedBox(height: 4),
                              Text(camp['messageBody']?.toString() ?? '', style: const TextStyle(color: BankingTheme.textSecondary, fontSize: 12)),
                            ],
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(color: col.withOpacity(0.1), borderRadius: BorderRadius.circular(6)),
                            child: Text(status, style: TextStyle(color: col, fontSize: 10, fontWeight: FontWeight.bold)),
                          ),
                        ],
                      ),
                    );
                  },
                ),
        ],
      ),
    );
  }

  Widget _buildDropdownField({
    required String label,
    required String? value,
    required List<DropdownMenuItem<String>> items,
    required void Function(String?) onChanged,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(color: BankingTheme.textSecondary, fontSize: 12)),
        const SizedBox(height: 6),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            color: BankingTheme.background.withOpacity(0.5),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.white.withOpacity(0.05)),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: value,
              items: items,
              onChanged: onChanged,
              dropdownColor: BankingTheme.cardBg,
              isExpanded: true,
              style: const TextStyle(color: Colors.white, fontSize: 15),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildInputField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
    int maxLines = 1,
    TextInputType? keyboardType,
  }) {
    return TextFormField(
      controller: controller,
      maxLines: maxLines,
      keyboardType: keyboardType,
      style: const TextStyle(color: Colors.white, fontSize: 15),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(color: BankingTheme.textSecondary, fontSize: 13),
        hintText: hint,
        hintStyle: const TextStyle(color: Colors.white24, fontSize: 14),
        prefixIcon: Icon(icon, color: BankingTheme.primary, size: 20),
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
      ),
    );
  }

  Widget _buildLogCard(Map<String, dynamic> log) {
    final status = log['status']?.toString().toUpperCase() ?? 'PENDING';
    final recipient = log['recipient']?.toString() ?? '+33';
    final senderId = log['senderIdName']?.toString() ?? 'INFO';
    final cost = double.tryParse(log['cost']?.toString() ?? '0') ?? 0.00;

    Color statusColor = Colors.amber;
    if (status == 'DELIVERED') statusColor = BankingTheme.primary;
    if (status == 'FAILED') statusColor = Colors.redAccent;

    return GlassCard(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(shape: BoxShape.circle, color: statusColor),
              ),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(recipient, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
                  const SizedBox(height: 2),
                  Text('Sender: $senderId | Status: $status', style: const TextStyle(color: BankingTheme.textSecondary, fontSize: 11)),
                ],
              ),
            ],
          ),
          Text('-${cost.toStringAsFixed(4)} €', style: const TextStyle(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }
}
