# Miam

Plateforme Flutter de démonstration pour la livraison de repas. Tous les montants
sont exprimés en FCFA.

- **Application mobile** : espaces client et livreur.
- **Portail Partenaire** : tableau de bord, commandes, menu et profil du restaurant.
- **Portail Admin** : pilotage, commandes, utilisateurs, restaurants et profil.

## API

L'API FastAPI se trouve dans le dossier `../backend`.

```bash
cd ../backend
./venv/bin/uvicorn app.main:app --reload --host 127.0.0.1 --port 8000
```

L'API est disponible sur `http://127.0.0.1:8000` et sa documentation sur
`http://127.0.0.1:8000/docs`.

Par défaut, l'application mobile utilise `http://localhost:8000/api/v1` sur iOS
et `http://10.0.2.2:8000/api/v1` sur l'émulateur Android :

```bash
flutter run --dart-define=API_URL=http://192.168.1.20:8000/api/v1
```

## Application mobile

```bash
flutter pub get
flutter run
```

La page de connexion propose un accès rapide aux comptes **Client** et
**Livreur**. Un compte partenaire ou admin connecté sur mobile est redirigé vers
un écran invitant à utiliser le portail web correspondant.

L'accueil client propose un bouton **Aide** avec **MiamBot** pour poser des questions sur les restaurants, le menu, la commande ou le suivi de livraison.

L'accueil client contient un carrousel de publicités qui défile automatiquement
et reste navigable par glissement ou via ses indicateurs.

## Restaurants et proximité

L'accueil client affiche les restaurants d'Abidjan avec leur cuisine, leur
note, leur délai et leur distance. Les menus de démonstration mettent en avant
les plats ivoiriens et ouest-africains : attiéké, poisson braisé, alloco,
thiéboudienne, mafé, yassa, dégué et jus locaux. Le bouton **Me localiser**
demande l'autorisation de localisation puis trie automatiquement la liste du
restaurant le plus proche au plus éloigné. La distance apparaît aussi sur la
fiche du restaurant.

Si la position est refusée ou indisponible, la liste reste consultable et est
triée par note. Le bouton **Actualiser** relance la position une fois
l'autorisation accordée.

Côté API, les coordonnées GPS des restaurants sont stockées en base. Elles sont
préremplies pour les restaurants de démonstration et peuvent être modifiées
depuis l'éditeur Admin ; si elles sont laissées vides, elles sont estimées à
partir de l'adresse. L'API accepte aussi une position client :

```bash
curl 'http://127.0.0.1:8000/api/v1/restaurants?latitude=5.3200&longitude=-4.0200'
```

Chaque restaurant renvoie alors `latitude`, `longitude`, `distance_km`, et la
liste est triée par distance.

Pour tester sur simulateur iOS, placez la position sur le Plateau à Abidjan :

```bash
xcrun simctl location <device-id> set 5.3200,-4.0200
```

## Suivi de livraison en temps réel

Le suivi cartographique est disponible avec **OpenStreetMap** via `flutter_map`
(aucune clé API nécessaire, une connexion Internet est requise pour les tuiles).

- **Client** : depuis « Mes commandes », bouton **Suivre** ou **Suivre la
  livraison** dans le détail.
- **Partenaire** : dans le portail, filtre **En route**, puis bouton **Suivre**.
- **Livreur** : « Livraisons » → **Suivi** sur une course active, puis
  **Partager ma position GPS** ou **Simuler le trajet (démo)**.

L'écran affiche le restaurant, l'adresse de livraison, la position du livreur, la
distance restante et l'ETA. Il se rafraîchit automatiquement toutes les 5
secondes. La commande de démonstration d'Amina (`client@miam.app`) chez Chez Mama,
livrée à Riviera Palmeraie, est déjà en cours pour tester immédiatement le suivi
côté client et partenaire.

Sur simulateur iOS, si la position GPS n'est pas configurée, utilisez la
simulation depuis l'écran livreur : la position avance automatiquement sur la
carte. Sur un appareil réel, le GPS demande l'autorisation de localisation.

## Portails web

Depuis la racine du projet :

```bash
./scripts/run_web_portals.sh
```

Le script construit puis lance les deux portails :

- Partenaire : `http://127.0.0.1:8081`
- Admin : `http://127.0.0.1:8082`

Pour reconstruire sans relancer les serveurs :

```bash
./scripts/build_web_portals.sh
```

Pour seulement relancer les serveurs :

```bash
./scripts/serve_web_portals.sh
```

En développement, chaque portail peut aussi être lancé directement :

```bash
flutter run -d chrome -t lib/main_partner.dart --web-port 8081
flutter run -d chrome -t lib/main_admin.dart --web-port 8082
```

## Comptes de démonstration

Mot de passe commun : `demo1234`.

| Espace | Rôle | Email |
| --- | --- | --- |
| Mobile | Client | `client@miam.app` |
| Mobile | Client | `client2@miam.app` |
| Mobile | Livreur | `courier@miam.app` |
| Mobile | Livreur | `courier2@miam.app` |
| Portail Partenaire | Partenaire | `partner@miam.app` |
| Portail Partenaire | Partenaire | `partner2@miam.app` |
| Portail Partenaire | Partenaire | `partner3@miam.app` |
| Portail Admin | Administrateur | `admin@miam.app` |

## Vérifications

```bash
dart format lib test integration_test
flutter analyze
flutter test
flutter test integration_test/app_smoke_test.dart -d <device-id> \
  --dart-define=MIAM_DISABLE_MAP_TILES=true
```

Le drapeau `MIAM_DISABLE_MAP_TILES` évite les requêtes de tuiles OpenStreetMap
pendant les tests d'intégration ; la carte, les marqueurs et l'itinéraire restent
affichés.

Le test d'intégration mobile nécessite que l'API soit lancée. Il vérifie la
connexion, la navigation des espaces client et livreur, le suivi cartographique
et le tri des restaurants autour de la position simulée. Les tests de widgets
vérifient les écrans de connexion des deux portails web, le modèle de suivi
cartographique et le calcul des distances.
