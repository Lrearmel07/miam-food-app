import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/app_state.dart';
import '../../core/config.dart';
import '../../core/theme.dart';
import '../../widgets/common.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  bool _uploading = false;

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

  void _showDemoAccounts() {
    showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Comptes de démonstration'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ...AppState.demoEmails.entries.map(
              (entry) => Padding(
                padding: const EdgeInsets.only(bottom: 9),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        '${entry.key} :',
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                    ),
                    Text(
                      entry.value,
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.muted,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Mot de passe : ${AppState.demoPassword}',
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Fermer'),
          ),
        ],
      ),
    );
  }

  Future<void> _pickAvatar() async {
    final result = await FilePicker.pickFiles(type: FileType.image);
    if (result.isEmpty) return;
    final file = result.first;
    final bytes = await file.readAsBytes();
    if (bytes.isEmpty) return;

    setState(() => _uploading = true);
    try {
      final url = await context.read<AppState>().api.uploadImageBytes(
        bytes: bytes,
        fileName: file.name,
      );
      if (!mounted) return; // ✅ Guard après le premier await

      await context.read<AppState>().updateAvatar(url);
      if (mounted) {
        showAppSnack(context, 'Photo de profil mise à jour !');
      }
    } catch (e) {
      if (mounted) {
        showAppSnack(context, 'Erreur upload : $e', error: true);
      }
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AppState>().user;

    String? avatarUrl;
    if (user?.avatarUrl != null && user!.avatarUrl!.isNotEmpty) {
      avatarUrl = user.avatarUrl!.startsWith('http')
          ? user.avatarUrl!
          : '${AppConfig.apiBaseUrl.replaceFirst(RegExp(r'/api/v\d+$'), '')}${user.avatarUrl!}';
    }

    return SafeArea(
      bottom: false,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(18, 12, 18, 28),
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Mon profil',
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
              ),
              IconButton(
                onPressed: _showDemoAccounts,
                icon: const Icon(Icons.help_outline_rounded),
              ),
            ],
          ),
          const SizedBox(height: 10),
          if (user != null) ...[
            SoftCard(
              padding: const EdgeInsets.all(18),
              child: Row(
                children: [
                  GestureDetector(
                    onTap: _uploading ? null : _pickAvatar,
                    child: Stack(
                      children: [
                        CircleAvatar(
                          radius: 27,
                          backgroundColor: AppColors.primary,
                          backgroundImage: avatarUrl != null
                              ? NetworkImage(avatarUrl)
                              : null,
                          child: avatarUrl == null
                              ? Text(
                                  user.fullName.isNotEmpty
                                      ? user.fullName
                                            .substring(0, 2)
                                            .toUpperCase()
                                      : 'U',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                  ),
                                )
                              : null,
                        ),
                        Positioned(
                          bottom: 0,
                          right: 0,
                          child: Container(
                            padding: const EdgeInsets.all(2),
                            decoration: const BoxDecoration(
                              color: Colors.white,
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              _uploading
                                  ? Icons.hourglass_top
                                  : Icons.camera_alt,
                              size: 14,
                              color: AppColors.primary,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
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
                        const SizedBox(height: 3),
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
          SectionHeader(title: 'Informations'),
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
                    icon: Icons.verified_user_outlined,
                    label: 'Type de compte',
                    value: user.roleLabelText,
                  ),
                ],
              ),
            ),
          const SizedBox(height: 20),
          SectionHeader(title: 'Application'),
          const SizedBox(height: 8),
          SoftCard(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
            child: Column(
              children: [
                SettingsTile(
                  icon: Icons.switch_account_outlined,
                  title: 'Comptes de démonstration',
                  subtitle: 'Tester les quatre rôles',
                  onTap: _showDemoAccounts,
                ),
                const Divider(),
                SettingsTile(
                  icon: Icons.info_outline_rounded,
                  title: 'À propos de Miam',
                  subtitle: 'Version ${AppConfig.version}',
                  onTap: () => showAboutDialog(
                    context: context,
                    applicationName: AppConfig.appName,
                    applicationVersion: AppConfig.version,
                    applicationLegalese:
                        'Application de démonstration — API FastAPI + Flutter.',
                    children: const [
                      SizedBox(height: 12),
                      Text(
                        'Miam met en relation clients, restaurants et livreurs. Les données et paiements sont simulés.',
                      ),
                    ],
                  ),
                ),
                const Divider(),
                SettingsTile(
                  icon: Icons.support_agent_rounded,
                  title: 'Aide & contact',
                  subtitle: 'support@miam.app',
                  color: AppColors.blue,
                  onTap: () => showDialog<void>(
                    context: context,
                    builder: (dialogContext) => AlertDialog(
                      title: const Text('Besoin d’aide ?'),
                      content: const Text(
                        'Cette application est une démonstration. Pour toute question sur un projet réel, contactez support@miam.app.',
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
          const SizedBox(height: 14),
          Text(
            'Miam ${AppConfig.version} • Fait avec soin',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ),
    );
  }
}
