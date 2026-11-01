import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../core/api_client.dart';
import '../../core/app_state.dart';
import '../../core/config.dart';
import '../../core/format.dart';
import '../../core/geo.dart';
import '../../core/theme.dart';
import '../../models/product.dart';
import '../../models/restaurant.dart';
import '../../widgets/common.dart';
import 'cart_screen.dart';

class RestaurantScreen extends StatefulWidget {
  const RestaurantScreen({super.key, required this.restaurant});

  final Restaurant restaurant;

  @override
  State<RestaurantScreen> createState() => _RestaurantScreenState();
}

class _RestaurantScreenState extends State<RestaurantScreen> {
  List<Product> _menu = [];
  List<Map<String, dynamic>> _gallery = [];
  bool _loading = true;
  String? _error;
  String _category = 'Tout';

  Restaurant get restaurant => widget.restaurant;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final api = context.read<AppState>().api;
      final results = await Future.wait([
        api.menu(restaurant.id),
        api.publicRestaurantGallery(restaurant.id),
      ]);

      if (!mounted) return;
      setState(() {
        _menu = results[0] as List<Product>;
        _gallery = results[1] as List<Map<String, dynamic>>;
      });
    } on ApiException catch (error) {
      if (!mounted) return;
      setState(() => _error = error.message);
    } catch (_) {
      if (!mounted) return;
      setState(() => _error = 'Impossible de charger le menu.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  String _absoluteImageUrl(String path) {
    if (path.startsWith('http://') || path.startsWith('https://')) {
      return path;
    }
    final origin = AppConfig.apiBaseUrl.replaceFirst(RegExp(r'/api/v\d+$'), '');
    return path.startsWith('/') ? '$origin$path' : '$origin/$path';
  }

  // Visionneuse avec slide et zoom
  void _showFullScreenImage(int initialIndex) {
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.black,
        insetPadding: EdgeInsets.zero,
        child: Stack(
          children: [
            PageView.builder(
              controller: PageController(initialPage: initialIndex),
              itemCount: _gallery.length,
              itemBuilder: (context, index) {
                final imageUrl = _gallery[index]['image_url'] as String? ?? '';
                return InteractiveViewer(
                  panEnabled: true,
                  minScale: 0.5,
                  maxScale: 4.0,
                  child: Image.network(
                    _absoluteImageUrl(imageUrl),
                    fit: BoxFit.contain,
                    errorBuilder: (_, _, _) => const Icon(
                      Icons.broken_image,
                      color: Colors.white,
                      size: 50,
                    ),
                  ),
                );
              },
            ),
            Positioned(
              top: 40,
              right: 20,
              child: IconButton(
                icon: const Icon(Icons.close, color: Colors.white, size: 30),
                onPressed: () => Navigator.pop(ctx),
              ),
            ),
          ],
        ),
      ),
    );
  }

  List<String> get _categories {
    final values = <String>{'Tout'};
    for (final product in _menu) {
      values.add(product.category);
    }
    return values.toList();
  }

  List<Product> get _visibleProducts {
    if (_category == 'Tout') return _menu;
    return _menu.where((product) => product.category == _category).toList();
  }

  Future<void> _addProduct(Product product) async {
    if (!restaurant.isOpen) {
      showAppSnack(
        context,
        'Ce restaurant est fermé pour le moment.',
        error: true,
      );
      return;
    }

    final state = context.read<AppState>();
    final added = state.addToCart(product, restaurant);
    if (added) return;

    final replace = await showConfirmDialog(
      context,
      title: 'Remplacer le panier ?',
      message:
          'Votre panier contient déjà des plats de ${state.cartRestaurant?.name ?? 'un autre restaurant'}. Voulez-vous le remplacer ?',
      confirmLabel: 'Remplacer',
    );
    if (replace && mounted) {
      state.replaceCartWith(product, restaurant);
    }
  }

  void _openCart() {
    Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => const CartScreen()));
  }

  void _openProduct(Product product) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => _ProductDetailSheet(
        product: product,
        restaurant: restaurant,
        onAdd: () => _addProduct(product),
        onRemove: () => context.read<AppState>().decrement(product),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final categories = _categories;
    final distance = state.distanceTo(restaurant);

    return Scaffold(
      body: RefreshIndicator(
        color: AppColors.primary,
        onRefresh: _load,
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            SliverAppBar(
              pinned: true,
              stretch: true,
              expandedHeight: 280,
              backgroundColor: restaurant.tint,
              foregroundColor: Colors.white,
              systemOverlayStyle: SystemUiOverlayStyle.light,
              leadingWidth: 64,
              leading: Padding(
                padding: const EdgeInsets.only(left: 12),
                child: Center(
                  child: Material(
                    color: Colors.black.withValues(alpha: 0.18),
                    shape: const CircleBorder(),
                    child: IconButton(
                      onPressed: () => Navigator.of(context).pop(),
                      icon: const Icon(
                        Icons.arrow_back_rounded,
                        color: Colors.white,
                        size: 21,
                      ),
                    ),
                  ),
                ),
              ),
              flexibleSpace: FlexibleSpaceBar(
                background: _Header(
                  restaurant: restaurant,
                  absoluteImageUrl: _absoluteImageUrl,
                ),
              ),
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(18, 18, 18, 26),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (!restaurant.isOpen) ...[
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(13),
                        decoration: BoxDecoration(
                          color: AppColors.danger.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: AppColors.danger.withValues(alpha: 0.18),
                          ),
                        ),
                        child: const Row(
                          children: [
                            Icon(
                              Icons.lock_clock_rounded,
                              size: 19,
                              color: AppColors.danger,
                            ),
                            SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                'Ce restaurant est fermé. Revenez un peu plus tard !',
                                style: TextStyle(
                                  color: AppColors.danger,
                                  fontSize: 12.5,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 14),
                    ],
                    Text(
                      restaurant.description,
                      style: Theme.of(
                        context,
                      ).textTheme.bodyMedium?.copyWith(color: AppColors.muted),
                    ),
                    const SizedBox(height: 16),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        _InfoChip(
                          icon: Icons.star_rounded,
                          label: restaurant.rating.toStringAsFixed(1),
                          color: AppColors.warning,
                        ),
                        _InfoChip(
                          icon: Icons.schedule_rounded,
                          label: '${restaurant.etaMin} min',
                          color: AppColors.blue,
                        ),
                        _InfoChip(
                          icon: Icons.delivery_dining_rounded,
                          label: money(restaurant.deliveryFee),
                          color: AppColors.primary,
                        ),
                        if (distance != null)
                          _InfoChip(
                            icon: Icons.near_me_rounded,
                            label: formatDistance(distance),
                            color: AppColors.blue,
                          ),
                      ],
                    ),
                    const SizedBox(height: 24),
                    if (_gallery.isNotEmpty) ...[
                      const Text(
                        'Galerie',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 10),
                      SizedBox(
                        height: 130,
                        child: ListView.separated(
                          scrollDirection: Axis.horizontal,
                          itemCount: _gallery.length,
                          separatorBuilder: (_, __) =>
                              const SizedBox(width: 10),
                          itemBuilder: (context, index) {
                            final imageUrl =
                                _gallery[index]['image_url'] as String? ?? '';
                            return GestureDetector(
                              onTap: () =>
                                  _showFullScreenImage(index), // 👈 index
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(16),
                                child: Image.network(
                                  _absoluteImageUrl(imageUrl),
                                  width: 180,
                                  height: 130,
                                  fit: BoxFit.cover,
                                  loadingBuilder: (context, child, progress) {
                                    if (progress == null) return child;
                                    return Container(
                                      width: 180,
                                      height: 130,
                                      color: AppColors.peach,
                                      child: const Center(
                                        child: SizedBox(
                                          width: 22,
                                          height: 22,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                          ),
                                        ),
                                      ),
                                    );
                                  },
                                  errorBuilder: (_, __, ___) => Container(
                                    width: 180,
                                    height: 130,
                                    color: AppColors.line,
                                    child: const Icon(
                                      Icons.broken_image_outlined,
                                      color: AppColors.muted,
                                    ),
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                      const SizedBox(height: 24),
                    ],
                    SectionHeader(
                      title: 'Le menu',
                      subtitle: '${_menu.length} plats disponibles',
                    ),
                    const SizedBox(height: 12),
                    if (!_loading && _error == null && _menu.isNotEmpty)
                      SizedBox(
                        height: 36,
                        child: ListView.separated(
                          scrollDirection: Axis.horizontal,
                          itemCount: categories.length,
                          separatorBuilder: (_, __) => const SizedBox(width: 8),
                          itemBuilder: (context, index) {
                            final category = categories[index];
                            final selected = _category == category;
                            return InkWell(
                              onTap: () => setState(() => _category = category),
                              borderRadius: BorderRadius.circular(30),
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 180),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 15,
                                ),
                                alignment: Alignment.center,
                                decoration: BoxDecoration(
                                  color: selected
                                      ? AppColors.ink
                                      : Colors.white,
                                  borderRadius: BorderRadius.circular(30),
                                  border: Border.all(
                                    color: selected
                                        ? AppColors.ink
                                        : AppColors.line,
                                  ),
                                ),
                                child: Text(
                                  category,
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700,
                                    color: selected
                                        ? Colors.white
                                        : AppColors.muted,
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                    const SizedBox(height: 12),
                    if (_loading)
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 50),
                        child: LoadingView(label: 'Chargement du menu...'),
                      )
                    else if (_error != null)
                      SizedBox(
                        height: 280,
                        child: ErrorState(message: _error!, onRetry: _load),
                      )
                    else if (_visibleProducts.isEmpty)
                      const EmptyState(
                        icon: Icons.restaurant_menu_rounded,
                        title: 'Menu vide',
                        message:
                            'Aucun plat dans cette catégorie pour le moment.',
                      )
                    else
                      ..._visibleProducts.map(
                        (product) => Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: _ProductCard(
                            product: product,
                            tint: restaurant.tint,
                            quantity: state.quantityOf(product.id),
                            onTap: () => _openProduct(product),
                            onAdd: () => _addProduct(product),
                            onRemove: () => state.decrement(product),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: state.cart.isEmpty
          ? null
          : SafeArea(
              top: false,
              child: Container(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  border: const Border(top: BorderSide(color: AppColors.line)),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.ink.withValues(alpha: 0.06),
                      blurRadius: 20,
                      offset: const Offset(0, -8),
                    ),
                  ],
                ),
                child: FilledButton(
                  onPressed: _openCart,
                  child: Row(
                    children: [
                      Container(
                        width: 26,
                        height: 26,
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.22),
                          borderRadius: BorderRadius.circular(9),
                        ),
                        child: Center(
                          child: Text(
                            '${state.cartCount}',
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      const Expanded(child: Text('Voir le panier')),
                      Text(money(state.cartTotal)),
                    ],
                  ),
                ),
              ),
            ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.restaurant, required this.absoluteImageUrl});

  final Restaurant restaurant;
  final String Function(String) absoluteImageUrl;

  @override
  Widget build(BuildContext context) {
    final tint = restaurant.tint;
    final coverUrl = restaurant.coverImageUrl ?? restaurant.imageUrl;
    final hasCover = coverUrl != null && coverUrl.isNotEmpty;

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [tint, Color.lerp(tint, Colors.black, 0.32)!],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Stack(
        fit: StackFit.expand,
        children: [
          if (hasCover)
            Positioned.fill(
              child: Image.network(
                absoluteImageUrl(coverUrl),
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => const SizedBox.shrink(),
              ),
            ),
          Positioned.fill(
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.black.withValues(alpha: 0.15),
                    Colors.black.withValues(alpha: 0.55),
                  ],
                ),
              ),
            ),
          ),
          if (!hasCover) // 👈 On cache l'emoji si l'image est là
            Positioned(
              right: 18,
              top: 64,
              child: Hero(
                tag: 'restaurant-${restaurant.id}',
                child: Text(
                  restaurant.emoji,
                  style: const TextStyle(fontSize: 104),
                ),
              ),
            ),
          Positioned(
            left: 20,
            right: 130,
            bottom: 22,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 5,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    restaurant.cuisine.toUpperCase(),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 9.5,
                      letterSpacing: 1,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                const SizedBox(height: 9),
                Text(
                  restaurant.name,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 30,
                    height: 1.05,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.9,
                  ),
                ),
                const SizedBox(height: 7),
                Row(
                  children: [
                    const Icon(
                      Icons.location_on_rounded,
                      size: 14,
                      color: Colors.white70,
                    ),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        restaurant.address,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 11.5,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _InfoChip extends StatelessWidget {
  const _InfoChip({
    required this.icon,
    required this.label,
    required this.color,
  });
  final IconData icon;
  final String label;
  final Color color;
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.09),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 5),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: 11.5,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

class _ProductCard extends StatelessWidget {
  const _ProductCard({
    required this.product,
    required this.tint,
    required this.quantity,
    required this.onTap,
    required this.onAdd,
    required this.onRemove,
  });
  final Product product;
  final Color tint;
  final int quantity;
  final VoidCallback onTap;
  final VoidCallback onAdd;
  final VoidCallback onRemove;
  @override
  Widget build(BuildContext context) {
    return SoftCard(
      onTap: onTap,
      padding: const EdgeInsets.all(12),
      child: Row(
        children: [
          AppImageBox(
            imageUrl: product.imageUrl,
            emoji: product.emoji,
            color: tint,
            size: 62,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  product.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                if (product.description.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    product.description,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
                const SizedBox(height: 7),
                Row(
                  children: [
                    Text(
                      money(product.price),
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                        color: AppColors.primaryDark,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Icon(
                      Icons.schedule_rounded,
                      size: 12,
                      color: AppColors.muted.withValues(alpha: 0.8),
                    ),
                    const SizedBox(width: 3),
                    Text(
                      '${product.prepTime} min',
                      style: const TextStyle(
                        fontSize: 10.5,
                        color: AppColors.muted,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          if (quantity == 0)
            Material(
              color: AppColors.primary,
              shape: const CircleBorder(),
              child: InkWell(
                onTap: onAdd,
                customBorder: const CircleBorder(),
                child: const SizedBox(
                  width: 38,
                  height: 38,
                  child: Icon(Icons.add_rounded, color: Colors.white, size: 21),
                ),
              ),
            )
          else
            QuantityStepper(
              quantity: quantity,
              onAdd: onAdd,
              onRemove: onRemove,
            ),
        ],
      ),
    );
  }
}

class _ProductDetailSheet extends StatelessWidget {
  const _ProductDetailSheet({
    required this.product,
    required this.restaurant,
    required this.onAdd,
    required this.onRemove,
  });
  final Product product;
  final Restaurant restaurant;
  final VoidCallback onAdd;
  final VoidCallback onRemove;
  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final quantity = state.quantityOf(product.id);
    final canOrder = restaurant.isOpen && product.isAvailable;
    final tint = restaurant.tint;
    final displayPrice = quantity == 0
        ? product.price
        : product.price * quantity;

    return ConstrainedBox(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.sizeOf(context).height * 0.9,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Flexible(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(24, 2, 24, 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      AppImageBox(
                        imageUrl: product.imageUrl,
                        emoji: product.emoji,
                        color: tint,
                        size: 92,
                      ),
                      const Spacer(),
                      IconButton(
                        onPressed: () => Navigator.of(context).pop(),
                        style: IconButton.styleFrom(
                          backgroundColor: AppColors.cream,
                          foregroundColor: AppColors.ink,
                        ),
                        icon: const Icon(Icons.close_rounded),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      _DetailTag(
                        icon: Icons.restaurant_menu_rounded,
                        label: product.category,
                        color: tint,
                      ),
                      _DetailTag(
                        icon: Icons.schedule_rounded,
                        label: '${product.prepTime} min',
                        color: AppColors.primaryDark,
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  Text(
                    product.name,
                    style: Theme.of(
                      context,
                    ).textTheme.headlineMedium?.copyWith(fontSize: 27),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      const Icon(
                        Icons.storefront_rounded,
                        size: 16,
                        color: AppColors.muted,
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          '${restaurant.name} · ${restaurant.address}',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 22),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: AppColors.line),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(
                              Icons.info_outline_rounded,
                              size: 18,
                              color: tint,
                            ),
                            const SizedBox(width: 7),
                            Text(
                              'À propos',
                              style: Theme.of(context).textTheme.titleMedium,
                            ),
                          ],
                        ),
                        const SizedBox(height: 9),
                        Text(
                          product.description.isEmpty
                              ? 'Aucune description disponible pour ce plat.'
                              : product.description,
                          style: Theme.of(
                            context,
                          ).textTheme.bodyLarge?.copyWith(color: AppColors.ink),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          Container(
            decoration: const BoxDecoration(
              color: Colors.white,
              border: Border(top: BorderSide(color: AppColors.line)),
            ),
            child: SafeArea(
              top: false,
              minimum: const EdgeInsets.fromLTRB(24, 14, 24, 16),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          quantity == 0 ? 'Prix' : 'Total · $quantity',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          money(displayPrice),
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w800,
                            color: AppColors.primaryDark,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  if (!canOrder)
                    FilledButton(
                      onPressed: null,
                      child: Text(
                        product.isAvailable
                            ? 'Restaurant fermé'
                            : 'Indisponible',
                      ),
                    )
                  else if (quantity == 0)
                    FilledButton.icon(
                      onPressed: onAdd,
                      style: FilledButton.styleFrom(
                        minimumSize: const Size(132, 52),
                      ),
                      icon: const Icon(Icons.add_rounded, size: 20),
                      label: const Text('Ajouter'),
                    )
                  else
                    QuantityStepper(
                      quantity: quantity,
                      onAdd: onAdd,
                      onRemove: onRemove,
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _DetailTag extends StatelessWidget {
  const _DetailTag({
    required this.icon,
    required this.label,
    required this.color,
  });
  final IconData icon;
  final String label;
  final Color color;
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 7),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(30),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 5),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: 12,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}
