import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/theme/banking_theme.dart';
import '../../core/widgets/glass_card.dart';
import '../auth/auth_controller.dart';
import 'dashboard_controller.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({Key? key}) : super(key: key);

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Provider.of<DashboardController>(context, listen: false).fetchDashboardData();
    });
  }

  @override
  Widget build(BuildContext context) {
    final auth = Provider.of<AuthController>(context);
    final dash = Provider.of<DashboardController>(context);

    final companyName = auth.currentUser?['companyName'] ?? 'Ma Super Entreprise';
    final stats = dash.statsSummary;

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          color: BankingTheme.background,
        ),
        child: RefreshIndicator(
          onRefresh: () => dash.fetchDashboardData(),
          color: BankingTheme.primary,
          backgroundColor: BankingTheme.cardBg,
          child: SafeArea(
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // 1. HEADER SECTION
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            companyName.toUpperCase(),
                            style: GoogleFonts.poppins(
                              fontSize: 12,
                              color: BankingTheme.primary,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 2.0,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Tableau de Bord',
                            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                                  fontSize: 26,
                                  fontWeight: FontWeight.w800,
                                ),
                          ),
                        ],
                      ),
                      // User icon / logout trigger
                      IconButton(
                        icon: const Icon(Icons.logout_rounded, color: Colors.redAccent),
                        onPressed: () {
                          auth.logout();
                          Navigator.pushReplacementNamed(context, '/login');
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),

                  // 2. VIRTUAL CREDIT CARD (SaaS Wallet Balance)
                  GlassCard(
                    glowColor: BankingTheme.primary,
                    padding: EdgeInsets.zero,
                    child: Container(
                      padding: const EdgeInsets.all(24),
                      decoration: const BoxDecoration(
                        gradient: BankingTheme.bankingCardGradient,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'SMS PLATINUM CREDIT',
                                style: GoogleFonts.poppins(
                                  color: Colors.white70,
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: 1.5,
                                ),
                              ),
                              const Icon(Icons.electric_bolt_rounded, color: BankingTheme.primary, size: 24),
                            ],
                          ),
                          const SizedBox(height: 32),
                          // Currency Balance
                          Text(
                            '${dash.balance.toStringAsFixed(2)} €',
                            style: GoogleFonts.poppins(
                              color: Colors.white,
                              fontSize: 36,
                              fontWeight: FontWeight.w800,
                              letterSpacing: -1.0,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'SOLDE DE COMPTE SaaS',
                            style: GoogleFonts.poppins(
                              color: BankingTheme.primary,
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 2.0,
                            ),
                          ),
                          const SizedBox(height: 24),
                          // Sub-action buttons in Card
                          Row(
                            children: [
                              Expanded(
                                child: ElevatedButton.icon(
                                  onPressed: () => Navigator.pushNamed(context, '/wallet'),
                                  icon: const Icon(Icons.add_rounded, size: 18),
                                  label: const Text('RECHARGER'),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: BankingTheme.primary,
                                    foregroundColor: BankingTheme.background,
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                    padding: const EdgeInsets.symmetric(vertical: 12),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: OutlinedButton.icon(
                                  onPressed: () => Navigator.pushNamed(context, '/sms'),
                                  icon: const Icon(Icons.send_rounded, size: 16),
                                  label: const Text('ENVOI RAPIDE'),
                                  style: OutlinedButton.styleFrom(
                                    foregroundColor: Colors.white,
                                    side: const BorderSide(color: Colors.white24),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                    padding: const EdgeInsets.symmetric(vertical: 12),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),

                  // 3. QUICK ACTIONS GRID
                  Text(
                    'SERVICES DISPONIBLES',
                    style: GoogleFonts.poppins(
                      color: BankingTheme.textSecondary,
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.5,
                    ),
                  ),
                  const SizedBox(height: 12),
                  GridView.count(
                    crossAxisCount: 2,
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    crossAxisSpacing: 12,
                    mainAxisSpacing: 12,
                    childAspectRatio: 1.45,
                    children: [
                      _buildQuickAction(
                        context,
                        title: 'Envoi SMS',
                        desc: 'Unitaire transactionnel',
                        icon: Icons.sms_outlined,
                        color: BankingTheme.primary,
                        route: '/sms',
                      ),
                      _buildQuickAction(
                        context,
                        title: 'Campagnes',
                        desc: 'Envois de masse',
                        icon: Icons.campaign_outlined,
                        color: Colors.blueAccent,
                        route: '/sms', // reuse same or route
                      ),
                      _buildQuickAction(
                        context,
                        title: 'Facturation',
                        desc: 'Wallet & Cartes',
                        icon: Icons.credit_card_rounded,
                        color: Colors.amber,
                        route: '/wallet',
                      ),
                      _buildQuickAction(
                        context,
                        title: 'Paramètres',
                        desc: 'Sender ID & API',
                        icon: Icons.settings_outlined,
                        color: Colors.purpleAccent,
                        route: '/settings',
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),

                  // 4. STATISTICS SUMMARY
                  GlassCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'STATISTIQUES DE LIVRAISON',
                              style: GoogleFonts.poppins(
                                color: BankingTheme.textSecondary,
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 1.5,
                              ),
                            ),
                            const Icon(Icons.analytics_outlined, color: BankingTheme.primary, size: 18),
                          ],
                        ),
                        const SizedBox(height: 16),
                        // Triple Linear Progress Bars
                        _buildStatBar('DISTRIBUÉ (DELIVERED)', stats['DELIVERED'] ?? 70.0, BankingTheme.primary),
                        const SizedBox(height: 12),
                        _buildStatBar('EN COURS (PENDING)', stats['PENDING'] ?? 20.0, Colors.amber),
                        const SizedBox(height: 12),
                        _buildStatBar('ÉCHECS (FAILED)', stats['FAILED'] ?? 10.0, Colors.redAccent),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),

                  // 5. RECENT ACTIVITY LOGS
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'ACTIVITÉ RÉCENTE',
                        style: GoogleFonts.poppins(
                          color: BankingTheme.textSecondary,
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1.5,
                        ),
                      ),
                      TextButton(
                        onPressed: () => Navigator.pushNamed(context, '/sms'),
                        child: const Text('VOIR TOUT', style: TextStyle(color: BankingTheme.primary, fontSize: 12)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),

                  // Fetch list items
                  dash.recentLogs.isEmpty
                      ? GlassCard(
                          child: Center(
                            child: Padding(
                              padding: const EdgeInsets.symmetric(vertical: 20),
                              child: Text('Aucune transaction récente.', style: TextStyle(color: BankingTheme.textSecondary)),
                            ),
                          ),
                        )
                      : ListView.separated(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: dash.recentLogs.length > 3 ? 3 : dash.recentLogs.length,
                          separatorBuilder: (context, index) => const SizedBox(height: 10),
                          itemBuilder: (context, index) {
                            final log = dash.recentLogs[index];
                            return _buildLogCard(log);
                          },
                        ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildQuickAction(
    BuildContext context, {
    required String title,
    required String desc,
    required IconData icon,
    required Color color,
    required String route,
  }) {
    return GlassCard(
      padding: const EdgeInsets.all(16),
      onTap: () => Navigator.pushNamed(context, route),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: GoogleFonts.poppins(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                desc,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.inter(
                  color: BankingTheme.textSecondary,
                  fontSize: 10,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatBar(String label, double value, Color color) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label, style: const TextStyle(color: Colors.white70, fontSize: 11, fontWeight: FontWeight.bold)),
            Text('${value.toStringAsFixed(0)}%', style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.bold)),
          ],
        ),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: value / 100,
            backgroundColor: Colors.white.withOpacity(0.05),
            valueColor: AlwaysStoppedAnimation(color),
            minHeight: 6,
          ),
        ),
      ],
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
              // Icon with status glowing background dot
              Container(
                width: 10,
                height: 10,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: statusColor,
                  boxShadow: [
                    BoxShadow(color: statusColor.withOpacity(0.6), blurRadius: 8, spreadRadius: 1)
                  ],
                ),
              ),
              const SizedBox(width: 16),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    recipient,
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Expéditeur: $senderId | Statut: $status',
                    style: const TextStyle(color: BankingTheme.textSecondary, fontSize: 11),
                  ),
                ],
              ),
            ],
          ),
          Text(
            '-${cost.toStringAsFixed(4)} €',
            style: GoogleFonts.poppins(
              color: Colors.white70,
              fontSize: 13,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}
