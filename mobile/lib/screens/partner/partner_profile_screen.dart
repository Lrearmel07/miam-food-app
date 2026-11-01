import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/api_client.dart';
import '../../core/app_state.dart';
import '../../core/config.dart';
import '../../core/format.dart';
import '../../core/theme.dart';
import '../../models/restaurant.dart';
import '../../widgets/common.dart';
import 'gallery_manager_screen.dart';

class PartnerProfileScreen extends StatefulWidget {
  const PartnerProfileScreen({super.key});

  @override
  State<PartnerProfileScreen> createState() => _PartnerProfileScreenState();
}

class _PartnerProfileScreenState extends State<PartnerProfileScreen> {
  Future<Restaurant>? _future;

  @override
  void initState() {
    super.initState();
    _load();
  }

  void _load() {
    setState(() {
      _future = context.read<AppState>().api.partnerRestaurant();
    });
  }

  Future<void> _editRestaurant(Restaurant restaurant) async {
    final result = await showModalBottomSheet<Map<String, dynamic>>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => _RestaurantEditor(restaurant: restaurant),
    );
    if (result == null || !mounted) return;

    try {
      await context.read<AppState>().api.updatePartnerRestaurant(result);
      if (!mounted) return;
      showAppSnack(context, 'Informations du restaurant mises à jour.');
      _load();
    } on ApiException catch (error) {
      if (mounted) showAppSnack(context, error.message, error: true);
    }
  }

  Future<void> _openGallery(Restaurant restaurant) async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => GalleryManager(
          title: 'Galerie • ${restaurant.name}',
          isAdmin: false,
          restaurantId: restaurant.id,
        ),
      ),
    );
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
          const SectionHeader(title: 'Mon restaurant'),
          const SizedBox(height: 8),
          FutureBuilder<Restaurant>(
            future: _future,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const SoftCard(
                  child: Padding(
                    padding: EdgeInsets.symmetric(vertical: 18),
                    child: LoadingView(),
                  ),
                );
              }
              if (snapshot.hasError) {
                final error = snapshot.error;
                return SoftCard(
                  child: ErrorState(
                    message: error is ApiException
                        ? error.message
                        : 'Restaurant introuvable.',
                    onRetry: _load,
                  ),
                );
              }

              final restaurant = snapshot.data!;
              return SoftCard(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    Row(
                      children: [
                        AppIconBox(
                          emoji: restaurant.emoji,
                          color: restaurant.tint,
                          size: 58,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                restaurant.name,
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                '${restaurant.cuisine} • ${restaurant.address}',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: Theme.of(context).textTheme.bodySmall,
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
                            color: restaurant.isOpen
                                ? AppColors.softGreen
                                : AppColors.danger.withValues(alpha: 0.08),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            restaurant.isOpen ? 'Ouvert' : 'Fermé',
                            style: TextStyle(
                              color: restaurant.isOpen
                                  ? AppColors.success
                                  : AppColors.danger,
                              fontSize: 10.5,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const Divider(height: 24),
                    Row(
                      children: [
                        Expanded(
                          child: _StatColumn(
                            value: restaurant.rating.toStringAsFixed(1),
                            label: 'Note',
                          ),
                        ),
                        Expanded(
                          child: _StatColumn(
                            value: money(restaurant.deliveryFee),
                            label: 'Livraison',
                          ),
                        ),
                        Expanded(
                          child: _StatColumn(
                            value: money(restaurant.minOrder),
                            label: 'Minimum',
                          ),
                        ),
                        Expanded(
                          child: _StatColumn(
                            value: '${restaurant.etaMin} min',
                            label: 'Préparation',
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    SizedBox(
                      height: 54,
                      width: double.infinity,
                      child: FilledButton.icon(
                        onPressed: () => _editRestaurant(restaurant),
                        icon: const Icon(Icons.edit_outlined, size: 18),
                        label: const Text('Modifier les informations'),
                      ),
                    ),
                    const SizedBox(height: 10),
                    SizedBox(
                      height: 54,
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: () => _openGallery(restaurant),
                        icon: const Icon(
                          Icons.photo_library_outlined,
                          size: 18,
                        ),
                        label: const Text('Gérer la galerie du restaurant'),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
          const SizedBox(height: 20),
          const SectionHeader(title: 'Mon compte'),
          const SizedBox(height: 8),
          if (user != null)
            SoftCard(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
              child: Column(
                children: [
                  ListTile(
                    leading: const Icon(Icons.mail_outline_rounded),
                    title: const Text('Email'),
                    trailing: Text(user.email),
                  ),
                  const Divider(),
                  ListTile(
                    leading: const Icon(Icons.phone_outlined),
                    title: const Text('Téléphone'),
                    trailing: Text(
                      user.phone?.isNotEmpty == true
                          ? user.phone!
                          : 'Non renseigné',
                    ),
                  ),
                  const Divider(),
                  ListTile(
                    leading: const Icon(Icons.store_outlined),
                    title: const Text('Identifiant partenaire'),
                    trailing: Text(
                      '#PAT-${user.id.toString().padLeft(4, '0')}',
                    ),
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
                  title: 'Support partenaire',
                  subtitle: 'support@miam.app',
                  color: AppColors.purple,
                  onTap: () => showDialog<void>(
                    context: context,
                    builder: (dialogContext) => AlertDialog(
                      title: const Text('Support partenaire'),
                      content: const Text(
                        'Cette démo ne contacte pas de support réel. En production, vous auriez un espace dédié pour la facturation, les litiges et la visibilité.',
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
                  color: AppColors.blue,
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
    );
  }
}

class _StatColumn extends StatelessWidget {
  const _StatColumn({required this.value, required this.label});

  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(value, style: const TextStyle(fontWeight: FontWeight.w800)),
        Text(label, style: Theme.of(context).textTheme.bodySmall),
      ],
    );
  }
}

class _RestaurantEditor extends StatefulWidget {
  const _RestaurantEditor({required this.restaurant});

  final Restaurant restaurant;

  @override
  State<_RestaurantEditor> createState() => _RestaurantEditorState();
}

class _RestaurantEditorState extends State<_RestaurantEditor> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _name;
  late final TextEditingController _description;
  late final TextEditingController _address;
  late final TextEditingController _cuisine;
  late final TextEditingController _emoji;
  late final TextEditingController _eta;
  late final TextEditingController _fee;
  late final TextEditingController _minimum;

  @override
  void initState() {
    super.initState();
    final restaurant = widget.restaurant;
    _name = TextEditingController(text: restaurant.name);
    _description = TextEditingController(text: restaurant.description);
    _address = TextEditingController(text: restaurant.address);
    _cuisine = TextEditingController(text: restaurant.cuisine);
    _emoji = TextEditingController(text: restaurant.emoji);
    _eta = TextEditingController(text: '${restaurant.etaMin}');
    _fee = TextEditingController(
      text: restaurant.deliveryFee.toStringAsFixed(0),
    );
    _minimum = TextEditingController(
      text: restaurant.minOrder.toStringAsFixed(0),
    );
  }

  @override
  void dispose() {
    _name.dispose();
    _description.dispose();
    _address.dispose();
    _cuisine.dispose();
    _emoji.dispose();
    _eta.dispose();
    _fee.dispose();
    _minimum.dispose();
    super.dispose();
  }

  double? _number(String raw) =>
      double.tryParse(raw.trim().replaceAll(',', '.'));

  void _submit() {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    Navigator.of(context).pop({
      'name': _name.text.trim(),
      'description': _description.text.trim(),
      'address': _address.text.trim(),
      'cuisine': _cuisine.text.trim(),
      'emoji': _emoji.text.trim(),
      'eta_min': int.parse(_eta.text),
      'delivery_fee': _number(_fee.text),
      'min_order': _number(_minimum.text),
    });
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SafeArea(
        top: false,
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Mon restaurant',
                        style: Theme.of(context).textTheme.headlineSmall,
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.close_rounded),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    SizedBox(
                      width: 76,
                      child: TextFormField(
                        controller: _emoji,
                        textAlign: TextAlign.center,
                        maxLength: 4,
                        style: const TextStyle(fontSize: 24),
                        decoration: const InputDecoration(
                          counterText: '',
                          labelText: 'Emoji',
                        ),
                        validator: (value) =>
                            value == null || value.isEmpty ? '—' : null,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: TextFormField(
                        controller: _name,
                        decoration: const InputDecoration(
                          labelText: 'Nom du restaurant',
                        ),
                        validator: (value) =>
                            value == null || value.trim().length < 2
                            ? 'Nom trop court'
                            : null,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _description,
                  minLines: 2,
                  maxLines: 3,
                  decoration: const InputDecoration(
                    labelText: 'Description',
                    alignLabelWithHint: true,
                  ),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _address,
                  decoration: const InputDecoration(
                    labelText: 'Adresse',
                    prefixIcon: Icon(Icons.location_on_outlined),
                  ),
                  validator: (value) => value == null || value.trim().length < 5
                      ? 'Adresse trop courte'
                      : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _cuisine,
                  decoration: const InputDecoration(
                    labelText: 'Type de cuisine',
                    prefixIcon: Icon(Icons.restaurant_rounded),
                  ),
                  validator: (value) => value == null || value.trim().isEmpty
                      ? 'Indiquez la cuisine'
                      : null,
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _eta,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          labelText: 'Délai (min)',
                        ),
                        validator: (value) {
                          final parsed = int.tryParse(value ?? '');
                          if (parsed == null || parsed < 5 || parsed > 120) {
                            return '5 à 120';
                          }
                          return null;
                        },
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: TextFormField(
                        controller: _fee,
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        decoration: const InputDecoration(
                          labelText: 'Livraison (FCFA)',
                        ),
                        validator: (value) {
                          final parsed = _number(value ?? '');
                          if (parsed == null || parsed < 0) {
                            return 'Invalide';
                          }
                          return null;
                        },
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: TextFormField(
                        controller: _minimum,
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        decoration: const InputDecoration(
                          labelText: 'Minimum (FCFA)',
                        ),
                        validator: (value) {
                          final parsed = _number(value ?? '');
                          if (parsed == null || parsed < 0) {
                            return 'Invalide';
                          }
                          return null;
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                SizedBox(
                  height: 54,
                  child: FilledButton(
                    onPressed: _submit,
                    child: const Text('Enregistrer'),
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
