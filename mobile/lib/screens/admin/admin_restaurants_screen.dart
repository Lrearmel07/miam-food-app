import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/api_client.dart';
import '../../core/app_state.dart';
import '../../core/config.dart';
import '../../core/theme.dart';
import '../../models/restaurant.dart';
import '../../widgets/common.dart';

class AdminRestaurantsScreen extends StatefulWidget {
  const AdminRestaurantsScreen({super.key});

  @override
  State<AdminRestaurantsScreen> createState() => _AdminRestaurantsScreenState();
}

class _AdminRestaurantsScreenState extends State<AdminRestaurantsScreen> {
  Future<List<Restaurant>>? _future;
  final Set<int> _busy = {};

  @override
  void initState() {
    super.initState();
    _load();
  }

  void _load() {
    setState(() {
      _future = context.read<AppState>().api.adminRestaurants();
    });
  }

  Future<void> _toggleOpen(Restaurant restaurant, bool isOpen) async {
    setState(() => _busy.add(restaurant.id));
    try {
      await context.read<AppState>().api.updateRestaurant(restaurant.id, {
        'is_open': isOpen,
      });
      if (!mounted) return;
      showAppSnack(
        context,
        '${restaurant.name} est maintenant ${isOpen ? 'ouvert' : 'fermé'}.',
      );
      _load();
    } on ApiException catch (error) {
      if (mounted) showAppSnack(context, error.message, error: true);
    } finally {
      if (mounted) setState(() => _busy.remove(restaurant.id));
    }
  }

  Future<void> _openEditor([Restaurant? restaurant]) async {
    final result = await showModalBottomSheet<Map<String, dynamic>>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => _RestaurantAdminEditor(restaurant: restaurant),
    );
    if (result == null || !mounted) return;

    try {
      final api = context.read<AppState>().api;
      if (restaurant == null) {
        await api.createRestaurant(result);
      } else {
        await api.updateRestaurant(restaurant.id, result);
      }
      if (!mounted) return;
      showAppSnack(
        context,
        restaurant == null
            ? 'Restaurant créé avec succès.'
            : 'Restaurant mis à jour.',
      );
      _load();
    } on ApiException catch (error) {
      if (mounted) showAppSnack(context, error.message, error: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      bottom: false,
      child: FutureBuilder<List<Restaurant>>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const LoadingView(label: 'Chargement des restaurants...');
          }
          if (snapshot.hasError) {
            final error = snapshot.error;
            return ErrorState(
              message: error is ApiException
                  ? error.message
                  : 'Impossible de charger les restaurants.',
              onRetry: _load,
            );
          }

          final restaurants = snapshot.data ?? [];
          final open = restaurants.where((r) => r.isOpen).length;

          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(18, 12, 18, 0),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Restaurants',
                            style: Theme.of(context).textTheme.headlineSmall,
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '$open ouverts sur ${restaurants.length}',
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      onPressed: _load,
                      icon: const Icon(Icons.refresh_rounded),
                    ),
                    const SizedBox(width: 2),
                    FilledButton.icon(
                      onPressed: () => _openEditor(),
                      style: FilledButton.styleFrom(
                        backgroundColor: AppColors.ink,
                        minimumSize: const Size(0, 42),
                        padding: const EdgeInsets.symmetric(horizontal: 13),
                      ),
                      icon: const Icon(Icons.add_rounded, size: 18),
                      label: const Text('Ajouter'),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              Expanded(
                child: restaurants.isEmpty
                    ? EmptyState(
                        icon: Icons.storefront_outlined,
                        title: 'Aucun restaurant',
                        message:
                            'Ajoutez le premier restaurant de la plateforme.',
                        action: FilledButton.icon(
                          onPressed: () => _openEditor(),
                          icon: const Icon(Icons.add_rounded),
                          label: const Text('Créer un restaurant'),
                        ),
                      )
                    : RefreshIndicator(
                        color: AppColors.ink,
                        onRefresh: () async {
                          _load();
                          await _future;
                        },
                        child: ListView.separated(
                          physics: const AlwaysScrollableScrollPhysics(),
                          padding: const EdgeInsets.fromLTRB(18, 10, 18, 28),
                          itemCount: restaurants.length,
                          separatorBuilder: (_, _) =>
                              const SizedBox(height: 10),
                          itemBuilder: (context, index) {
                            final restaurant = restaurants[index];
                            return _RestaurantAdminCard(
                              restaurant: restaurant,
                              busy: _busy.contains(restaurant.id),
                              onToggle: (value) =>
                                  _toggleOpen(restaurant, value),
                              onEdit: () => _openEditor(restaurant),
                            );
                          },
                        ),
                      ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _RestaurantAdminCard extends StatelessWidget {
  const _RestaurantAdminCard({
    required this.restaurant,
    required this.busy,
    required this.onToggle,
    required this.onEdit,
  });

  final Restaurant restaurant;
  final bool busy;
  final ValueChanged<bool> onToggle;
  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context) {
    return SoftCard(
      padding: const EdgeInsets.all(14),
      child: Column(
        children: [
          Row(
            children: [
              AppIconBox(
                emoji: restaurant.emoji,
                color: restaurant.tint,
                size: 54,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      restaurant.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 15,
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
              IconButton(
                onPressed: onEdit,
                icon: const Icon(Icons.edit_outlined, size: 19),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              const Icon(
                Icons.star_rounded,
                size: 16,
                color: AppColors.warning,
              ),
              const SizedBox(width: 3),
              Text(
                restaurant.rating.toStringAsFixed(1),
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(width: 12),
              const Icon(
                Icons.restaurant_menu_rounded,
                size: 15,
                color: AppColors.muted,
              ),
              const SizedBox(width: 4),
              Text(
                '${restaurant.productCount} plats',
                style: Theme.of(context).textTheme.bodySmall,
              ),
              const Spacer(),
              if (busy)
                const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2.2),
                )
              else ...[
                Text(
                  restaurant.isOpen ? 'Ouvert' : 'Fermé',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    color: restaurant.isOpen
                        ? AppColors.success
                        : AppColors.danger,
                  ),
                ),
                Transform.scale(
                  scale: 0.8,
                  child: Switch.adaptive(
                    value: restaurant.isOpen,
                    activeTrackColor: AppColors.primary,
                    onChanged: onToggle,
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

class _RestaurantAdminEditor extends StatefulWidget {
  const _RestaurantAdminEditor({this.restaurant});

  final Restaurant? restaurant;

  @override
  State<_RestaurantAdminEditor> createState() => _RestaurantAdminEditorState();
}

class _RestaurantAdminEditorState extends State<_RestaurantAdminEditor> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _name;
  late final TextEditingController _description;
  late final TextEditingController _address;
  late final TextEditingController _latitude;
  late final TextEditingController _longitude;
  late final TextEditingController _cuisine;
  late final TextEditingController _emoji;
  late final TextEditingController _eta;
  late final TextEditingController _fee;
  late final TextEditingController _minimum;
  late final TextEditingController _coverImage; // 👈 AJOUT
  late bool _isOpen;

  @override
  void initState() {
    super.initState();
    final restaurant = widget.restaurant;
    _name = TextEditingController(text: restaurant?.name ?? '');
    _description = TextEditingController(text: restaurant?.description ?? '');
    _address = TextEditingController(text: restaurant?.address ?? '');
    _latitude = TextEditingController(
      text: restaurant?.latitude?.toStringAsFixed(6) ?? '',
    );
    _longitude = TextEditingController(
      text: restaurant?.longitude?.toStringAsFixed(6) ?? '',
    );
    _cuisine = TextEditingController(
      text: restaurant?.cuisine ?? 'International',
    );
    _emoji = TextEditingController(text: restaurant?.emoji ?? '🍽️');
    _eta = TextEditingController(text: '${restaurant?.etaMin ?? 25}');
    _fee = TextEditingController(
      text: (restaurant?.deliveryFee ?? 1500).toStringAsFixed(0),
    );
    _minimum = TextEditingController(
      text: (restaurant?.minOrder ?? 5000).toStringAsFixed(0),
    );
    _coverImage = TextEditingController(
      text: restaurant?.coverImageUrl ?? '',
    ); // 👈 AJOUT
    _isOpen = restaurant?.isOpen ?? true;
  }

  @override
  void dispose() {
    _name.dispose();
    _description.dispose();
    _address.dispose();
    _latitude.dispose();
    _longitude.dispose();
    _cuisine.dispose();
    _emoji.dispose();
    _eta.dispose();
    _fee.dispose();
    _minimum.dispose();
    _coverImage.dispose(); // 👈 AJOUT
    super.dispose();
  }

  double? _number(String raw) =>
      double.tryParse(raw.trim().replaceAll(',', '.'));

  void _submit() {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    final latitude = _number(_latitude.text);
    final longitude = _number(_longitude.text);
    Navigator.of(context).pop({
      'name': _name.text.trim(),
      'description': _description.text.trim(),
      'address': _address.text.trim(),
      'cover_image_url': _coverImage.text.trim().isEmpty
          ? null
          : _coverImage.text.trim(), // 👈 AJOUT
      if (latitude != null && longitude != null) 'latitude': latitude,
      if (latitude != null && longitude != null) 'longitude': longitude,
      'cuisine': _cuisine.text.trim(),
      'emoji': _emoji.text.trim(),
      'eta_min': int.parse(_eta.text),
      'delivery_fee': _number(_fee.text),
      'min_order': _number(_minimum.text),
      'is_open': _isOpen,
      if (widget.restaurant == null) 'color': '#FF7A45',
    });
  }

  @override
  Widget build(BuildContext context) {
    final editing = widget.restaurant != null;
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
                        editing
                            ? 'Modifier le restaurant'
                            : 'Nouveau restaurant',
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
                        maxLength: 34,
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
                        textCapitalization: TextCapitalization.words,
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

                //Image de couverture avec bouton d'upload
                TextFormField(
                  controller: _coverImage,
                  decoration: InputDecoration(
                    labelText: 'Image de couverture (URL)',
                    hintText: '/uploads/xxx.jpg',
                    prefixIcon: const Icon(Icons.image_outlined),
                    suffixIcon: IconButton(
                      icon: const Icon(Icons.upload_file),
                      tooltip: 'Uploader une image',
                      onPressed: () async {
                        final result = await FilePicker.pickFiles(
                          type: FileType.image,
                        );
                        if (result.isEmpty) return;
                        final file = result.first;
                        final bytes = await file.readAsBytes();
                        if (bytes.isEmpty) return;
                        try {
                          final url = await context
                              .read<AppState>()
                              .api
                              .uploadImageBytes(
                                bytes: bytes,
                                fileName: file.name,
                              );
                          if (mounted) {
                            setState(() => _coverImage.text = url);
                          }
                        } catch (e) {
                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text('Erreur upload : $e')),
                            );
                          }
                        }
                      },
                    ),
                  ),
                ),
                if (_coverImage.text.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Image.network(
                      _coverImage.text.startsWith('http')
                          ? _coverImage.text
                          : '${AppConfig.apiBaseUrl.replaceFirst(RegExp(r'/api/v\d+$'), '')}${_coverImage.text}',
                      height: 120,
                      width: double.infinity,
                      fit: BoxFit.cover,
                      errorBuilder: (_, _, _) => const SizedBox.shrink(),
                    ),
                  ),
                ],

                // 👆 FIN AJOUT
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
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _latitude,
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                          signed: true,
                        ),
                        decoration: const InputDecoration(
                          labelText: 'Latitude (optionnel)',
                        ),
                        validator: (value) {
                          final raw = value?.trim() ?? '';
                          if (raw.isEmpty) {
                            return _longitude.text.trim().isEmpty
                                ? null
                                : 'Requis avec la longitude';
                          }
                          final parsed = _number(raw);
                          if (parsed == null || parsed < -90 || parsed > 90) {
                            return 'Entre -90 et 90';
                          }
                          return null;
                        },
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: TextFormField(
                        controller: _longitude,
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                          signed: true,
                        ),
                        decoration: const InputDecoration(
                          labelText: 'Longitude (optionnel)',
                        ),
                        validator: (value) {
                          final raw = value?.trim() ?? '';
                          if (raw.isEmpty) {
                            return _latitude.text.trim().isEmpty
                                ? null
                                : 'Requis avec la latitude';
                          }
                          final parsed = _number(raw);
                          if (parsed == null || parsed < -180 || parsed > 180) {
                            return 'Entre -180 et 180';
                          }
                          return null;
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _cuisine,
                  decoration: const InputDecoration(
                    labelText: 'Type de cuisine',
                    prefixIcon: Icon(Icons.restaurant_rounded),
                  ),
                  validator: (value) => value == null || value.trim().isEmpty
                      ? 'Cuisine requise'
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
                          if (parsed == null || parsed < 0) return 'Invalide';
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
                          if (parsed == null || parsed < 0) return 'Invalide';
                          return null;
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                SwitchListTile.adaptive(
                  value: _isOpen,
                  activeTrackColor: AppColors.primary,
                  contentPadding: EdgeInsets.zero,
                  title: const Text(
                    'Restaurant ouvert',
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
                  ),
                  subtitle: const Text(
                    'Les clients peuvent commander immédiatement.',
                  ),
                  onChanged: (value) => setState(() => _isOpen = value),
                ),
                const SizedBox(height: 14),
                SizedBox(
                  height: 54,
                  child: FilledButton(
                    onPressed: _submit,
                    child: Text(
                      editing ? 'Enregistrer' : 'Créer le restaurant',
                    ),
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
