import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/app_state.dart';
import '../../core/config.dart';
import '../../core/theme.dart';
import '../../widgets/common.dart';

class AdminProfileScreen extends StatelessWidget {
  const AdminProfileScreen({super.key});

  Future<void> _logout(BuildContext context) async {
    final confirmed = await showConfirmDialog(
      context,
      title: 'Se déconnecter ?',
      message: 'Vous pourrez vous reconnecter avec un autre compte démo.',
      confirmLabel: 'Se déconnecter',
      danger: true,
    );
    if (confirmed && context.mounted) {
      await context.read<AppState>().logout();
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AppState>().user;

    return SafeArea(
      bottom: false,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(18, 12, 18, 28),
        children: [
          Text('Mon profil', style: Theme.of(context).textTheme.headlineSmall),
          const SizedBox(height: 12),
          if (user != null) ...[
            SoftCard(
              padding: const EdgeInsets.all(18),
              child: Row(
                children: [
                  AppAvatar(user: user, size: 54),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          user.fullName,
                          style: const TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        Text(
                          user.email,
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ],
                    ),
                  ),
                  RoleBadge(role: user.role),
                ],
              ),
            ),
            const SizedBox(height: 16),
          ],
          const SizedBox(height: 20),
          SectionHeader(title: 'Informations du compte'),
          const SizedBox(height: 8),
          if (user != null)
            SoftCard(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
              child: Column(
                children: [
                  InfoRow(
                    icon: Icons.mail_outline_rounded,
                    label: 'Email',
                    value: user.email,
                  ),
                  const Divider(),
                  InfoRow(
                    icon: Icons.phone_outlined,
                    label: 'Téléphone',
                    value: user.phone?.isNotEmpty == true
                        ? user.phone!
                        : 'Non renseigné',
                  ),
                  const Divider(),
                  InfoRow(
                    icon: Icons.badge_outlined,
                    label: 'Identifiant administrateur',
                    value: '#ADM-${user.id.toString().padLeft(4, '0')}',
                  ),
                ],
              ),
            ),
          const SizedBox(height: 20),
          SectionHeader(title: 'Privilèges'),
          const SizedBox(height: 8),
          SoftCard(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            child: Column(
              children: const [
                _PrivilegeRow(
                  icon: Icons.people_alt_rounded,
                  label: 'Gestion des utilisateurs',
                ),
                _PrivilegeRow(
                  icon: Icons.storefront_rounded,
                  label: 'Gestion des restaurants',
                ),
                _PrivilegeRow(
                  icon: Icons.receipt_long_rounded,
                  label: 'Supervision des commandes',
                ),
                _PrivilegeRow(
                  icon: Icons.person_add_alt_1_rounded,
                  label: 'Création de comptes partenaires',
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          SectionHeader(title: 'Préférences'),
          const SizedBox(height: 8),
          SoftCard(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
            child: Column(
              children: [
                SettingsTile(
                  icon: Icons.support_agent_rounded,
                  title: 'Support technique',
                  subtitle: 'admin@miam.app',
                  color: AppColors.blue,
                  onTap: () => showDialog<void>(
                    context: context,
                    builder: (dialogContext) => AlertDialog(
                      title: const Text('Support technique'),
                      content: const Text(
                        'Cette démo ne contacte pas de support réel. En production, cette entrée ouvrirait le canal de support interne.',
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
            onPressed: () => _logout(context),
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
    );
  }
}

class _PrivilegeRow extends StatelessWidget {
  const _PrivilegeRow({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: AppColors.success.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              Icons.check_rounded,
              size: 17,
              color: AppColors.success,
            ),
          ),
          const SizedBox(width: 11),
          Icon(icon, size: 17, color: AppColors.muted),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              label,
              style: const TextStyle(
                fontSize: 13.5,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
