import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/api_client.dart';
import '../../core/app_state.dart';
import '../../core/config.dart';
import '../../core/format.dart';
import '../../core/theme.dart';
import '../../models/product.dart';
import '../../widgets/common.dart';
import 'gallery_manager_screen.dart';

class PartnerMenuScreen extends StatefulWidget {
  const PartnerMenuScreen({super.key});

  @override
  State<PartnerMenuScreen> createState() => _PartnerMenuScreenState();
}

class _PartnerMenuScreenState extends State<PartnerMenuScreen> {
  Future<List<Product>>? _future;
  int? _busyProduct;

  @override
  void initState() {
    super.initState();
    _load();
  }

  void _load() {
    setState(() {
      _future = context.read<AppState>().api.partnerProducts();
    });
  }

  Future<void> _openEditor(Product? product) async {
    final result = await showModalBottomSheet<Map<String, dynamic>>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => _ProductEditor(existing: product),
    );
    if (result == null || !mounted) return;

    try {
      final api = context.read<AppState>().api;
      if (product == null) {
        await api.createProduct(result);
      } else {
        await api.updateProduct(product.id, result);
      }
      if (!mounted) return;
      showAppSnack(
        context,
        product == null ? 'Plat ajouté au menu.' : 'Plat mis à jour.',
      );
      _load();
    } on ApiException catch (error) {
      if (mounted) showAppSnack(context, error.message, error: true);
    }
  }

  Future<void> _toggle(Product product, bool value) async {
    setState(() => _busyProduct = product.id);
    try {
      await context.read<AppState>().api.updateProduct(product.id, {
        'is_available': value,
      });
      if (!mounted) return;
      showAppSnack(
        context,
        value
            ? '${product.name} est disponible.'
            : '${product.name} est masqué.',
      );
      _load();
    } on ApiException catch (error) {
      if (mounted) showAppSnack(context, error.message, error: true);
    } finally {
      if (mounted) setState(() => _busyProduct = null);
    }
  }

  Future<void> _delete(Product product) async {
    final confirmed = await showConfirmDialog(
      context,
      title: 'Supprimer ce plat ?',
      message: '« ${product.name} » sera définitivement retiré de votre menu.',
      confirmLabel: 'Supprimer',
      danger: true,
    );
    if (!confirmed || !mounted) return;

    setState(() => _busyProduct = product.id);
    try {
      await context.read<AppState>().api.deleteProduct(product.id);
      if (!mounted) return;
      showAppSnack(context, 'Plat supprimé.');
      _load();
    } on ApiException catch (error) {
      if (mounted) showAppSnack(context, error.message, error: true);
    } finally {
      if (mounted) setState(() => _busyProduct = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      bottom: false,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 12, 14, 0),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Mon menu',
                        style: Theme.of(context).textTheme.headlineSmall,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Ajoutez, modifiez et gérez vos plats.',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
                FilledButton.icon(
                  onPressed: () => _openEditor(null),
                  style: FilledButton.styleFrom(
                    minimumSize: const Size(0, 42),
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  icon: const Icon(Icons.add_rounded, size: 18),
                  label: const Text('Ajouter'),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          Expanded(
            child: FutureBuilder<List<Product>>(
              future: _future,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const LoadingView(label: 'Chargement du menu...');
                }
                if (snapshot.hasError) {
                  final error = snapshot.error;
                  return ErrorState(
                    message: error is ApiException
                        ? error.message
                        : 'Impossible de charger le menu.',
                    onRetry: _load,
                  );
                }

                final products = snapshot.data ?? [];
                if (products.isEmpty) {
                  return EmptyState(
                    icon: Icons.restaurant_menu_rounded,
                    title: 'Votre menu est vide',
                    message:
                        'Ajoutez votre premier plat pour commencer à recevoir des commandes.',
                    action: FilledButton.icon(
                      onPressed: () => _openEditor(null),
                      icon: const Icon(Icons.add_rounded, size: 18),
                      label: const Text('Créer un plat'),
                    ),
                  );
                }

                final available = products
                    .where((product) => product.isAvailable)
                    .length;

                return RefreshIndicator(
                  color: AppColors.purple,
                  onRefresh: () async {
                    _load();
                    await _future;
                  },
                  child: ListView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.fromLTRB(18, 6, 18, 24),
                    children: [
                      Row(
                        children: [
                          Text(
                            '${products.length} plat(s)',
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                          const Spacer(),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 9,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: AppColors.softGreen,
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(
                              '$available en ligne',
                              style: const TextStyle(
                                color: AppColors.success,
                                fontSize: 10.5,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      ...products.map(
                        (product) => Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: _MenuProductCard(
                            product: product,
                            busy: _busyProduct == product.id,
                            onEdit: () => _openEditor(product),
                            onToggle: (value) => _toggle(product, value),
                            onDelete: () => _delete(product),
                            onGallery: () {
                              Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (_) => GalleryManager(
                                    title: 'Galerie • ${product.name}',
                                    isAdmin: false,
                                    productId: product.id,
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _MenuProductCard extends StatelessWidget {
  const _MenuProductCard({
    required this.product,
    required this.busy,
    required this.onEdit,
    required this.onToggle,
    required this.onDelete,
    required this.onGallery,
  });

  final Product product;
  final bool busy;
  final VoidCallback onEdit;
  final ValueChanged<bool> onToggle;
  final VoidCallback onDelete;
  final VoidCallback onGallery;

  String? _absoluteUrl(String? path) {
    if (path == null || path.isEmpty) return null;
    if (path.startsWith('http')) return path;
    return '${AppConfig.apiBaseUrl.replaceFirst(RegExp(r'/api/v\d+$'), '')}$path';
  }

  @override
  Widget build(BuildContext context) {
    final imageUrl = _absoluteUrl(product.imageUrl);

    return SoftCard(
      padding: const EdgeInsets.all(13),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Opacity(
            opacity: product.isAvailable ? 1 : 0.55,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(14),
              child: SizedBox(
                width: 56,
                height: 56,
                child: imageUrl != null
                    ? Image.network(
                        imageUrl,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) =>
                            AppImageBox(color: AppColors.purple, size: 56),
                      )
                    : AppImageBox(color: AppColors.purple, size: 56),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        product.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 14.5,
                          fontWeight: FontWeight.w700,
                          color: product.isAvailable
                              ? AppColors.ink
                              : AppColors.muted,
                        ),
                      ),
                    ),
                    PopupMenuButton<String>(
                      padding: EdgeInsets.zero,
                      iconSize: 19,
                      icon: const Icon(
                        Icons.more_horiz_rounded,
                        color: AppColors.muted,
                      ),
                      onSelected: (value) {
                        if (value == 'edit') onEdit();
                        if (value == 'gallery') onGallery();
                        if (value == 'delete') onDelete();
                      },
                      itemBuilder: (context) => const [
                        PopupMenuItem(
                          value: 'edit',
                          child: Row(
                            children: [
                              Icon(Icons.edit_outlined, size: 18),
                              SizedBox(width: 10),
                              Text('Modifier'),
                            ],
                          ),
                        ),
                        PopupMenuItem(
                          value: 'gallery',
                          child: Row(
                            children: [
                              Icon(Icons.photo_library_outlined, size: 18),
                              SizedBox(width: 10),
                              Text('Galerie'),
                            ],
                          ),
                        ),
                        PopupMenuItem(
                          value: 'delete',
                          child: Row(
                            children: [
                              Icon(
                                Icons.delete_outline_rounded,
                                size: 18,
                                color: AppColors.danger,
                              ),
                              SizedBox(width: 10),
                              Text(
                                'Supprimer',
                                style: TextStyle(color: AppColors.danger),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                if (product.description.isNotEmpty)
                  Text(
                    product.description,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    Text(
                      money(product.price),
                      style: const TextStyle(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w800,
                        color: AppColors.primaryDark,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 7,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.purple.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        product.category,
                        style: const TextStyle(
                          color: AppColors.purple,
                          fontSize: 9.5,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 4),
          Column(
            children: [
              if (busy)
                const Padding(
                  padding: EdgeInsets.all(8),
                  child: SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                )
              else
                Transform.scale(
                  scale: 0.8,
                  child: Switch(
                    value: product.isAvailable,
                    onChanged: onToggle,
                  ),
                ),
              Text(
                product.isAvailable ? 'En ligne' : 'Masqué',
                style: TextStyle(
                  fontSize: 9,
                  fontWeight: FontWeight.w700,
                  color: product.isAvailable
                      ? AppColors.success
                      : AppColors.muted,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ProductEditor extends StatefulWidget {
  const _ProductEditor({this.existing});

  final Product? existing;

  @override
  State<_ProductEditor> createState() => _ProductEditorState();
}

class _ProductEditorState extends State<_ProductEditor> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _name;
  late final TextEditingController _description;
  late final TextEditingController _price;
  late final TextEditingController _emoji;
  late final TextEditingController _prep;
  late final TextEditingController _imageUrl;

  late String _category;
  late bool _available;

  static const _baseCategories = [
    'Entrées',
    'Plats',
    'Grillades',
    'Accompagnements',
    'Desserts',
    'Boissons',
  ];

  List<String> get _categories {
    final existing = widget.existing?.category;
    return {
      ..._baseCategories,
      if (existing != null && existing.isNotEmpty) existing,
    }.toList();
  }

  @override
  void initState() {
    super.initState();
    final existing = widget.existing;
    _name = TextEditingController(text: existing?.name ?? '');
    _description = TextEditingController(text: existing?.description ?? '');
    _price = TextEditingController(
      text: existing != null ? existing.price.toStringAsFixed(0) : '',
    );
    _emoji = TextEditingController(text: existing?.emoji ?? '🍲');
    _prep = TextEditingController(text: '${existing?.prepTime ?? 15}');
    _imageUrl = TextEditingController(text: existing?.imageUrl ?? '');
    _category = existing?.category ?? 'Plats';
    _available = existing?.isAvailable ?? true;
  }

  @override
  void dispose() {
    _name.dispose();
    _description.dispose();
    _price.dispose();
    _emoji.dispose();
    _prep.dispose();
    _imageUrl.dispose();
    super.dispose();
  }

  void _submit() {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    final price = double.parse(_price.text.replaceAll(',', '.'));
    final prep = int.parse(_prep.text);
    Navigator.of(context).pop({
      'name': _name.text.trim(),
      'description': _description.text.trim(),
      'price': price,
      'category': _category,
      'emoji': _emoji.text.trim(),
      'prep_time': prep,
      'is_available': _available,
      'image_url': _imageUrl.text.trim().isEmpty ? null : _imageUrl.text.trim(),
    });
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.existing != null;
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
                        isEditing ? 'Modifier le plat' : 'Nouveau plat',
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
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(
                      width: 76,
                      child: TextFormField(
                        controller: _emoji,
                        textAlign: TextAlign.center,
                        maxLength: 32,
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
                        textCapitalization: TextCapitalization.sentences,
                        decoration: const InputDecoration(
                          labelText: 'Nom du plat',
                        ),
                        validator: (value) =>
                            value == null || value.trim().length < 2
                            ? 'Entrez un nom'
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
                    hintText: 'Ingrédients, particularités...',
                    alignLabelWithHint: true,
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _price,
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        decoration: const InputDecoration(
                          labelText: 'Prix (FCFA)',
                        ),
                        validator: (value) {
                          final parsed = double.tryParse(
                            (value ?? '').replaceAll(',', '.'),
                          );
                          if (parsed == null || parsed <= 0) {
                            return 'Prix invalide';
                          }
                          return null;
                        },
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: TextFormField(
                        controller: _prep,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          labelText: 'Préparation (min)',
                        ),
                        validator: (value) {
                          final parsed = int.tryParse(value ?? '');
                          if (parsed == null || parsed < 1 || parsed > 180) {
                            return '1 à 180 min';
                          }
                          return null;
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: _category,
                  decoration: const InputDecoration(labelText: 'Catégorie'),
                  items: _categories
                      .map(
                        (category) => DropdownMenuItem(
                          value: category,
                          child: Text(category),
                        ),
                      )
                      .toList(),
                  onChanged: (value) {
                    if (value != null) setState(() => _category = value);
                  },
                ),
                const SizedBox(height: 12),
                // 👇 AJOUT : Image du plat avec upload
                TextFormField(
                  controller: _imageUrl,
                  decoration: InputDecoration(
                    labelText: 'Image du plat (URL)',
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
                          if (!mounted) return;
                          setState(() => _imageUrl.text = url);
                        } catch (e) {
                          if (!mounted) return;
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('Erreur upload : $e')),
                          );
                        }
                      },
                    ),
                  ),
                ),
                if (_imageUrl.text.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Image.network(
                      _imageUrl.text.startsWith('http')
                          ? _imageUrl.text
                          : '${AppConfig.apiBaseUrl.replaceFirst(RegExp(r'/api/v\d+$'), '')}${_imageUrl.text}',
                      height: 120,
                      width: double.infinity,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => const SizedBox.shrink(),
                    ),
                  ),
                ],
                const SizedBox(height: 8),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text(
                    'Disponible à la commande',
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                  ),
                  subtitle: const Text(
                    'Désactivez pour masquer temporairement ce plat.',
                    style: TextStyle(fontSize: 11.5),
                  ),
                  value: _available,
                  onChanged: (value) => setState(() => _available = value),
                ),
                const SizedBox(height: 10),
                SizedBox(
                  height: 54,
                  child: FilledButton(
                    onPressed: _submit,
                    child: Text(isEditing ? 'Enregistrer' : 'Ajouter au menu'),
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
