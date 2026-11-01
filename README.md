# Miam - Application de Livraison de Repas

Miam est une plateforme complète de livraison de repas composée de :
- **Une application mobile** (Flutter) pour les clients, livreurs et partenaires.
-  **Un site web Admin** (Flutter Web) pour la supervision globale.
-  **Un site web Partenaire** (Flutter Web) pour gérer les restaurants, menus et galeries.
-  **Une API backend** (FastAPI + SQLite) qui fait le lien entre tous les clients.

## Architecture du projet

```text
miam-food-app/
├── backend/          # API FastAPI (Python)
│   ├── app/          # Code source de l'API
│   ├── food.db       # Base de données SQLite (ignorée par Git)
│   └── requirements.txt
├── mobile/           # Application Flutter (Mobile, Admin Web, Partenaire Web)
│   ├── lib/          # Code source Dart
│   ├── web/          # Configuration Flutter Web
│   └── pubspec.yaml
├── scripts/          # Scripts de lancement (ex: start_web.sh)
└── .gitignore
