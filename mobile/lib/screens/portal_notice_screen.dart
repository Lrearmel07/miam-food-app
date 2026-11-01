import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/app_state.dart';
import '../core/theme.dart';

class PortalNoticeScreen extends StatelessWidget {
  const PortalNoticeScreen({super.key, required this.role});

  final String role;

  @override
  Widget build(BuildContext context) {
    final isPartner = role == 'partner';
    final title = isPartner ? 'Espace Partenaire' : 'Espace Administrateur';
    final icon = isPartner ? Icons.storefront_rounded : Icons.shield_rounded;
    final accent = isPartner ? AppColors.purple : AppColors.ink;

    return Scaffold(
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Container(
            width: 470,
            padding: const EdgeInsets.all(32),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(30),
              border: Border.all(color: AppColors.line),
              boxShadow: [
                BoxShadow(
                  color: AppColors.ink.withValues(alpha: 0.07),
                  blurRadius: 40,
                  offset: const Offset(0, 18),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 70,
                  height: 70,
                  decoration: BoxDecoration(
                    color: accent.withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(icon, size: 31, color: accent),
                ),
                const SizedBox(height: 20),
                Text(title, style: Theme.of(context).textTheme.headlineSmall),
                const SizedBox(height: 10),
                Text(
                  'Ce compte se connecte désormais uniquement sur le portail web $title.',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 14,
                    height: 1.5,
                    color: AppColors.muted,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  context.watch<AppState>().user?.email ?? '',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 24),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: AppColors.cream,
                    borderRadius: BorderRadius.circular(15),
                  ),
                  child: const Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(
                        Icons.open_in_browser_rounded,
                        size: 18,
                        color: AppColors.muted,
                      ),
                      SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'Ouvrez le portail web correspondant dans votre navigateur pour continuer.',
                          style: TextStyle(
                            fontSize: 12,
                            height: 1.45,
                            color: AppColors.muted,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 22),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: () => context.read<AppState>().logout(),
                    style: FilledButton.styleFrom(backgroundColor: accent),
                    icon: const Icon(Icons.logout_rounded, size: 18),
                    label: const Text('Se déconnecter'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
