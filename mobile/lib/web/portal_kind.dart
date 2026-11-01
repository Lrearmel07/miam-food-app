import 'package:flutter/material.dart';

import '../core/theme.dart';

enum PortalKind {
  partner(
    role: 'partner',
    shortLabel: 'Partenaire',
    title: 'Espace Partenaire',
    eyebrow: 'PORTAIL RESTAURANT',
    headline: 'Pilotez votre restaurant, sans friction.',
    description:
        'Vos commandes, votre carte et vos performances réunies dans un espace pensé pour le service.',
    demoEmail: 'partner@miam.app',
    icon: Icons.storefront_rounded,
    accent: AppColors.purple,
    accentDark: Color(0xFF6D28D9),
    highlights: [
      'Suivez les commandes et leurs statuts',
      'Gérez votre menu et vos produits',
      'Analysez votre chiffre d’affaires',
    ],
  ),
  admin(
    role: 'admin',
    shortLabel: 'Admin',
    title: 'Espace Administrateur',
    eyebrow: 'BACK-OFFICE MIAM',
    headline: 'La plateforme sous contrôle.',
    description:
        'Supervisez les comptes, les restaurants et les commandes depuis un back-office centralisé.',
    demoEmail: 'admin@miam.app',
    icon: Icons.shield_rounded,
    accent: AppColors.ink,
    accentDark: Color(0xFF0F0D0C),
    highlights: [
      'Pilotez l’activité de la plateforme',
      'Gérez les utilisateurs et les restaurants',
      'Suivez toutes les commandes en cours',
    ],
  );

  const PortalKind({
    required this.role,
    required this.shortLabel,
    required this.title,
    required this.eyebrow,
    required this.headline,
    required this.description,
    required this.demoEmail,
    required this.icon,
    required this.accent,
    required this.accentDark,
    required this.highlights,
  });

  final String role;
  final String shortLabel;
  final String title;
  final String eyebrow;
  final String headline;
  final String description;
  final String demoEmail;
  final IconData icon;
  final Color accent;
  final Color accentDark;
  final List<String> highlights;

  String get demoPassword => 'demo1234';
}
