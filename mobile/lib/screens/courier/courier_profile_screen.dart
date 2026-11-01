import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/app_state.dart';
import '../../core/config.dart';
import '../../core/format.dart';
import '../../core/theme.dart';
import '../../widgets/common.dart';

class CourierProfileScreen extends StatefulWidget {
  const CourierProfileScreen({super.key});

  @override
  State<CourierProfileScreen> createState() => _CourierProfileScreenState();
}

class _CourierProfileScreenState extends State<CourierProfileScreen> {
  Map<String, dynamic>? _stats;

  @override
  void initState() {
    super.initState();
    _loadStats();
  }

  Future<void> _loadStats() async {
    try {
      final stats = await context.read<AppState>().api.courierStats();
      if (mounted) setState(() => _stats = stats);
    } catch (_) {
      // Les statistiques restent optionnelles sur cet écran.
    }
  }

  Future<void> _logout() async {
    final confirmed = await showConfirmDialog(
      context,
      title: 'Se déconnecter ?',
      message: 'Vous pourrez vous reconnecter avec un autre compte démo.',
      confirmLabel: 'Se déconnecter',
      danger: true,
    );
    if (confirmed && mounted) {
      await context.read<AppState>().logout();
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final user = state.user;
    final earnings = money((_stats?['earnings'] as num?)?.toDouble() ?? 0);

    return SafeArea(
      bottom: false,
      child: RefreshIndicator(
        color: AppColors.blue,
        onRefresh: _loadStats,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(18, 12, 18, 28),
          children: [
            Text(
              'Mon profil',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 12),
            if (user != null)
              Container(
                padding: const EdgeInsets.all(18),
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: [AppColors.primary, AppColors.primaryDark],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.vertical(
                    bottom: Radius.circular(32),
                  ),
                ),
                child: SafeArea(
                  bottom: false,
                  child: Column(
                    children: [
                      Row(
                        children: [
                          AppAvatar(user: user, size: 58),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  user.fullName,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 18,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                const Text(
                                  'Livreur Miam',
                                  style: TextStyle(color: Colors.white70),
                                ),
                              ],
                            ),
                          ),
                          RoleBadge(role: user.role, onDark: true),
                        ],
                      ),
                      const SizedBox(height: 14),
                      Row(
                        children: [
                          Expanded(
                            child: Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.16),
                                borderRadius: BorderRadius.circular(16),
                              ),
                              child: const Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    '--',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.w800,
                                      fontSize: 18,
                                    ),
                                  ),
                                  Text(
                                    'Livraisons',
                                    style: TextStyle(
                                      color: Colors.white70,
                                      fontSize: 12,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.16),
                                borderRadius: BorderRadius.circular(16),
                              ),
                              child: const Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    '4.9',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.w800,
                                      fontSize: 18,
                                    ),
                                  ),
                                  Text(
                                    'Note',
                                    style: TextStyle(
                                      color: Colors.white70,
                                      fontSize: 12,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            const SizedBox(height: 14),
            SectionHeader(title: 'Mes informations'),
            const SizedBox(height: 8),
            SoftCard(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
              child: Column(
                children: [
                  ListTile(
                    leading: const Icon(Icons.mail_outline_rounded),
                    title: const Text('Email'),
                    trailing: Text(user?.email ?? ''),
                  ),
                  const Divider(),
                  ListTile(
                    leading: const Icon(Icons.phone_outlined),
                    title: const Text('Téléphone'),
                    trailing: Text(
                      'Non renseigné',
                    ),
                  ),
                  const Divider(),
                  ListTile(
                    leading: const Icon(Icons.badge_outlined),
                    title: const Text('ID Livreur'),
                    trailing: Text(
                      '#COU-${user?.id.toString().padLeft(4, '0')}',
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            SectionHeader(title: 'Rémunération'),
            const SizedBox(height: 8),
            SoftCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 42,
                        height: 42,
                        decoration: BoxDecoration(
                          color: AppColors.softGreen,
                          borderRadius: BorderRadius.circular(13),
                        ),
                        child: const Icon(
                          Icons.account_balance_wallet_rounded,
                          color: AppColors.success,
                          size: 21,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Solde disponible',
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                            Text(
                              earnings,
                              style: const TextStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.w800,
                                letterSpacing: -0.4,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 9,
                          vertical: 5,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.softGreen,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: const Text(
                          'DÉMO',
                          style: TextStyle(
                            color: AppColors.success,
                            fontSize: 9,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.6,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Les gains correspondent aux frais de livraison des courses terminées. Aucun versement réel n’est effectué.',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            SoftCard(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
              child: Column(
                children: [
                  SettingsTile(
                    icon: Icons.support_agent_rounded,
                    title: 'Aide livreur',
                    subtitle: 'support@miam.app',
                    color: AppColors.blue,
                    onTap: () => showDialog<void>(
                      context: context,
                      builder: (dialogContext) => AlertDialog(
                        title: const Text('Aide livreur'),
                        content: const Text(
                          'Pour cette démo, contactez support@miam.app. En production, un support dédié et une assurance livraison seraient ajoutés.',
                        ),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(dialogContext),
                            child: const Text('Compris'),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const Divider(),
                  SettingsTile(
                    icon: Icons.info_outline_rounded,
                    title: 'À propos de Miam',
                    subtitle: 'Version ${AppConfig.version}',
                    color: AppColors.purple,
                    onTap: () => showAboutDialog(
                      context: context,
                      applicationName: AppConfig.appName,
                      applicationVersion: AppConfig.version,
                      applicationLegalese: 'Application de démonstration.',
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 22),
            OutlinedButton.icon(
              onPressed: _logout,
              icon: const Icon(
                Icons.logout_rounded,
                size: 18,
                color: AppColors.danger,
              ),
              label: const Text(
                'Se déconnecter',
                style: TextStyle(color: AppColors.danger),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
