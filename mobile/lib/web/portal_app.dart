import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/app_state.dart';
import '../core/theme.dart';
import 'portal_kind.dart';
import 'portal_login_screen.dart';
import 'portal_shell.dart';

class PartnerWebApp extends StatelessWidget {
  const PartnerWebApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const PortalApp(kind: PortalKind.partner);
  }
}

class AdminWebApp extends StatelessWidget {
  const AdminWebApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const PortalApp(kind: PortalKind.admin);
  }
}

class PortalApp extends StatelessWidget {
  const PortalApp({super.key, required this.kind});

  final PortalKind kind;

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => AppState(tokenKey: 'miam_${kind.role}_token')..restore(),
      child: MaterialApp(
        title: 'Miam · ${kind.title}',
        debugShowCheckedModeBanner: false,
        theme: buildMiamTheme(),
        home: PortalGate(kind: kind),
      ),
    );
  }
}

class PortalGate extends StatelessWidget {
  const PortalGate({super.key, required this.kind});

  final PortalKind kind;

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();

    final Widget page;
    String pageKey;
    if (state.booting) {
      page = _PortalSplash(kind: kind);
      pageKey = 'splash';
    } else if (state.user == null) {
      page = PortalLoginScreen(kind: kind);
      pageKey = 'login';
    } else if (state.user!.role != kind.role) {
      page = _WrongPortalScreen(kind: kind);
      pageKey = 'wrong-portal';
    } else {
      page = kind == PortalKind.partner
          ? const PartnerPortalShell()
          : const AdminPortalShell();
      pageKey = 'portal';
    }

    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 280),
      switchInCurve: Curves.easeOutCubic,
      switchOutCurve: Curves.easeInCubic,
      child: KeyedSubtree(key: ValueKey(pageKey), child: page),
    );
  }
}

class _PortalSplash extends StatelessWidget {
  const _PortalSplash({required this.kind});

  final PortalKind kind;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [kind.accentDark, kind.accent],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(24),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(20),
                  child: Image.asset('assets/icon.png', width: 78, height: 78),
                ),
              ),
              const SizedBox(height: 18),
              const Text(
                'Miam',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 30,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.8,
                ),
              ),
              const SizedBox(height: 5),
              Text(
                kind.title,
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.72),
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 24),
              const SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(
                  strokeWidth: 2.5,
                  color: Colors.white,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _WrongPortalScreen extends StatelessWidget {
  const _WrongPortalScreen({required this.kind});

  final PortalKind kind;

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final role = switch (state.user?.role) {
      'partner' => 'partenaire',
      'admin' => 'administrateur',
      'courier' => 'livreur',
      'client' => 'client',
      _ => 'inconnu',
    };

    return Scaffold(
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Container(
            width: 470,
            padding: const EdgeInsets.all(34),
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
                  width: 68,
                  height: 68,
                  decoration: BoxDecoration(
                    color: kind.accent.withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.lock_outline_rounded,
                    size: 30,
                    color: kind.accent,
                  ),
                ),
                const SizedBox(height: 20),
                Text(
                  'Mauvais portail',
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                const SizedBox(height: 9),
                Text(
                  'Ce compte est un compte $role. ${kind.title} est réservé aux comptes ${kind.shortLabel.toLowerCase()}s.',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 14,
                    height: 1.5,
                    color: AppColors.muted,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  state.user?.email ?? '',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: AppColors.ink,
                  ),
                ),
                const SizedBox(height: 26),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: () => state.logout(),
                    style: FilledButton.styleFrom(backgroundColor: kind.accent),
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
