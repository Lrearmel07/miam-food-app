import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/app_state.dart';
import '../../core/geo.dart';
import '../../core/theme.dart';
import '../../models/restaurant.dart';
import '../../widgets/common.dart';
import 'chatbot_screen.dart';
import 'restaurant_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _search = TextEditingController();
  String? _cuisine;
  String _query = '';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final state = context.read<AppState>();
      state.loadCatalog();
      state.autoLocate();
    });
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  String get _greeting {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Bonjour';
    if (hour < 18) return 'Bon après-midi';
    return 'Bonsoir';
  }

  List<Restaurant> _filtered(List<Restaurant> restaurants, AppState state) {
    final query = _query.trim().toLowerCase();
    final filtered = restaurants.where((restaurant) {
      final matchesQuery =
          query.isEmpty ||
          restaurant.name.toLowerCase().contains(query) ||
          restaurant.cuisine.toLowerCase().contains(query) ||
          restaurant.description.toLowerCase().contains(query);
      final matchesCuisine = _cuisine == null || restaurant.cuisine == _cuisine;
      return matchesQuery && matchesCuisine;
    }).toList();
    return state.sortByDistance(filtered);
  }

  void _resetFilters() {
    _search.clear();
    setState(() {
      _query = '';
      _cuisine = null;
    });
  }

  void _handlePromo(_PromoAction action) {
    final state = context.read<AppState>();
    switch (action) {
      case _PromoAction.explore:
        _resetFilters();
        break;
      case _PromoAction.sweets:
        Restaurant? discovery;
        for (final restaurant in state.restaurants) {
          if (restaurant.cuisine == 'Desserts') {
            discovery = restaurant;
            break;
          }
        }
        if (discovery != null) {
          _openRestaurant(discovery);
        } else {
          _resetFilters();
          if (state.cuisines.contains('Desserts')) {
            setState(() => _cuisine = 'Desserts');
          }
        }
        break;
      case _PromoAction.orders:
        state.setClientTab(1);
        break;
    }
  }

  Future<void> _locate() async {
    final state = context.read<AppState>();
    final located = await state.activateLocation();
    if (!mounted) return;
    if (located) {
      showAppSnack(
        context,
        'Position activée : restaurants triés par distance.',
      );
    } else if (state.locationError != null) {
      showAppSnack(context, state.locationError!, error: true);
    }
  }

  String _subtitle(AppState state, List<Restaurant> restaurants) {
    final base = '${restaurants.length} restaurant(s) disponible(s)';
    if (!state.hasClientLocation || restaurants.isEmpty) return base;
    double? nearest;
    for (final restaurant in restaurants) {
      final distance = state.distanceTo(restaurant);
      if (distance != null && (nearest == null || distance < nearest)) {
        nearest = distance;
      }
    }
    if (nearest == null) return base;
    return '$base • Le plus proche à ${formatDistance(nearest)}';
  }

  void _openRestaurant(Restaurant restaurant) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => RestaurantScreen(restaurant: restaurant),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final restaurants = _filtered(state.restaurants, state);

    return SafeArea(
      bottom: false,
      child: Stack(
        children: [
          RefreshIndicator(
            color: AppColors.primary,
            onRefresh: () => state.loadCatalog(force: true),
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(18, 12, 18, 96),
              children: [
                _buildHeader(state),
                const SizedBox(height: 20),
                TextField(
                  controller: _search,
                  onChanged: (value) => setState(() => _query = value),
                  decoration: InputDecoration(
                    hintText: 'Un plat, un restaurant...',
                    prefixIcon: const Icon(Icons.search_rounded),
                    suffixIcon: _query.isEmpty
                        ? null
                        : IconButton(
                            onPressed: () {
                              _search.clear();
                              setState(() => _query = '');
                            },
                            icon: const Icon(Icons.close_rounded),
                          ),
                  ),
                ),
                const SizedBox(height: 18),

                _PromoCarousel(onAction: _handlePromo),
                const SizedBox(height: 22),
                if (state.cuisines.isNotEmpty)
                  SizedBox(
                    height: 38,
                    child: ListView(
                      scrollDirection: Axis.horizontal,
                      children: [
                        _CuisineChip(
                          label: 'Tout',
                          selected: _cuisine == null,
                          onTap: () => setState(() => _cuisine = null),
                        ),
                        ...state.cuisines.map(
                          (cuisine) => Padding(
                            padding: const EdgeInsets.only(left: 8),
                            child: _CuisineChip(
                              label: cuisine,
                              selected: _cuisine == cuisine,
                              onTap: () => setState(() => _cuisine = cuisine),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                const SizedBox(height: 18),
                _LocationBanner(
                  hasLocation: state.hasClientLocation,
                  locating: state.locating,
                  error: state.locationError,
                  onTap: _locate,
                ),
                const SizedBox(height: 20),
                SectionHeader(
                  title:
                      _cuisine ??
                      (state.hasClientLocation
                          ? 'Les plus proches'
                          : 'Nos restaurants'),
                  subtitle: _subtitle(state, restaurants),
                ),
                const SizedBox(height: 12),
                if (state.catalogLoading && state.restaurants.isEmpty)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 50),
                    child: LoadingView(label: 'On prépare le menu...'),
                  )
                else if (state.catalogError != null &&
                    state.restaurants.isEmpty)
                  SizedBox(
                    height: 320,
                    child: ErrorState(
                      message: state.catalogError!,
                      onRetry: () => state.loadCatalog(force: true),
                    ),
                  )
                else if (restaurants.isEmpty)
                  EmptyState(
                    icon: Icons.search_off_rounded,
                    title: 'Aucun restaurant trouvé',
                    message:
                        'Essayez un autre plat ou retirez le filtre de cuisine.',
                    action: TextButton(
                      onPressed: () {
                        _search.clear();
                        setState(() {
                          _query = '';
                          _cuisine = null;
                        });
                      },
                      child: const Text('Tout afficher'),
                    ),
                  )
                else
                  ...restaurants.map(
                    (restaurant) => Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: RestaurantTile(
                        restaurant: restaurant,
                        distanceKm: state.distanceTo(restaurant),
                        onTap: () => _openRestaurant(restaurant),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          Positioned(
            right: 18,
            bottom: 18,
            child: _ChatbotFab(
              onTap: () {
                Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const ChatbotScreen()),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(AppState state) {
    final user = state.user;
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '$_greeting,',
                style: Theme.of(
                  context,
                ).textTheme.bodyMedium?.copyWith(color: AppColors.muted),
              ),
              const SizedBox(height: 2),
              Text(
                '${user?.firstName ?? 'Gourmand'} 👋',
                style: Theme.of(context).textTheme.headlineMedium,
              ),
            ],
          ),
        ),
        SoftCard(
          padding: const EdgeInsets.all(9),
          margin: EdgeInsets.zero,
          onTap: () => state.setClientTab(3),
          child: const Icon(
            Icons.notifications_none_rounded,
            color: AppColors.ink,
            size: 23,
          ),
        ),
        const SizedBox(width: 10),
        AppAvatar(user: user, size: 48, onTap: () => state.setClientTab(3)),
      ],
    );
  }
}

enum _PromoAction { explore, sweets, orders }

class _Promo {
  const _Promo({
    required this.action,
    required this.badge,
    required this.title,
    required this.subtitle,
    required this.cta,
    required this.emoji,
    required this.colors,
  });

  final _PromoAction action;
  final String badge;
  final String title;
  final String subtitle;
  final String cta;
  final String emoji;
  final List<Color> colors;
}

const _promos = [
  _Promo(
    action: _PromoAction.explore,
    badge: 'LIVRAISON RAPIDE',
    title: 'Envie de bon ?',
    subtitle: 'Vos restos préférés livrés en 20 à 35 min.',
    cta: 'Explorer',
    emoji: '🛵',
    colors: [Color(0xFFFF8A3D), AppColors.primaryDark],
  ),
  _Promo(
    action: _PromoAction.sweets,
    badge: 'FRAÎCHEUR LOCALE',
    title: 'Bissap & douceurs',
    subtitle: 'Jus frais, desserts et gourmandises d’Abidjan.',
    cta: 'Voir les douceurs',
    emoji: '🧃',
    colors: [Color(0xFF21A97A), Color(0xFF0B6B50)],
  ),
  _Promo(
    action: _PromoAction.orders,
    badge: 'SUIVI EN DIRECT',
    title: 'Votre repas arrive',
    subtitle: 'Suivez votre livreur jusqu’à votre porte.',
    cta: 'Mes commandes',
    emoji: '📍',
    colors: [Color(0xFF9A6BFF), Color(0xFF5B2BB5)],
  ),
];

class _PromoCarousel extends StatefulWidget {
  const _PromoCarousel({required this.onAction});

  final ValueChanged<_PromoAction> onAction;

  @override
  State<_PromoCarousel> createState() => _PromoCarouselState();
}

class _PromoCarouselState extends State<_PromoCarousel> {
  final _controller = PageController();
  Timer? _timer;
  int _index = 0;

  @override
  void initState() {
    super.initState();
    _startAutoPlay();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  void _startAutoPlay() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 5), (_) {
      if (!mounted || !_controller.hasClients) return;
      final next = (_index + 1) % _promos.length;
      _controller.animateToPage(
        next,
        duration: const Duration(milliseconds: 420),
        curve: Curves.easeOutCubic,
      );
    });
  }

  void _goTo(int index) {
    _controller.animateToPage(
      index,
      duration: const Duration(milliseconds: 380),
      curve: Curves.easeOutCubic,
    );
  }

  @override
  Widget build(BuildContext context) {
    final activeColor = _promos[_index].colors.first;
    return Column(
      children: [
        SizedBox(
          height: 188,
          child: PageView.builder(
            controller: _controller,
            itemCount: _promos.length,
            onPageChanged: (index) {
              setState(() => _index = index);
              _startAutoPlay();
            },
            itemBuilder: (context, index) {
              final promo = _promos[index];
              return _PromoSlide(
                promo: promo,
                onTap: () => widget.onAction(promo.action),
              );
            },
          ),
        ),
        const SizedBox(height: 10),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(_promos.length, (index) {
            final selected = index == _index;
            return GestureDetector(
              onTap: () => _goTo(index),
              behavior: HitTestBehavior.opaque,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 220),
                  width: selected ? 22 : 7,
                  height: 7,
                  decoration: BoxDecoration(
                    color: selected ? activeColor : AppColors.line,
                    borderRadius: BorderRadius.circular(20),
                  ),
                ),
              ),
            );
          }),
        ),
      ],
    );
  }
}

class _PromoSlide extends StatelessWidget {
  const _PromoSlide({required this.promo, required this.onTap});

  final _Promo promo;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = promo.colors.first;
    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(26),
        gradient: LinearGradient(
          colors: promo.colors,
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.27),
            blurRadius: 22,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          child: Stack(
            children: [
              Positioned(
                right: -26,
                top: -36,
                child: Container(
                  width: 150,
                  height: 150,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white.withValues(alpha: 0.12),
                  ),
                ),
              ),
              Positioned(
                right: 12,
                bottom: -12,
                child: Text(
                  promo.emoji,
                  style: TextStyle(
                    fontSize: 82,
                    shadows: [
                      Shadow(
                        color: Colors.black.withValues(alpha: 0.12),
                        blurRadius: 12,
                        offset: const Offset(0, 6),
                      ),
                    ],
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 18, 118, 18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 9,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        promo.badge,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 9,
                          letterSpacing: 0.7,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    const SizedBox(height: 9),
                    Text(
                      promo.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 24,
                        height: 1.08,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.7,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      promo.subtitle,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.86),
                        fontSize: 12.5,
                        height: 1.35,
                      ),
                    ),
                    const Spacer(),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          promo.cta,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 12.5,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(width: 4),
                        Icon(
                          Icons.arrow_forward_rounded,
                          size: 15,
                          color: Colors.white.withValues(alpha: 0.9),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CuisineChip extends StatelessWidget {
  const _CuisineChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(30),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 16),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: selected ? AppColors.ink : Colors.white,
          borderRadius: BorderRadius.circular(30),
          border: Border.all(color: selected ? AppColors.ink : AppColors.line),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12.5,
            fontWeight: FontWeight.w700,
            color: selected ? Colors.white : AppColors.muted,
          ),
        ),
      ),
    );
  }
}

class _LocationBanner extends StatelessWidget {
  const _LocationBanner({
    required this.hasLocation,
    required this.locating,
    required this.error,
    required this.onTap,
  });

  final bool hasLocation;
  final bool locating;
  final String? error;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = error != null
        ? AppColors.danger
        : hasLocation
        ? AppColors.success
        : AppColors.primary;
    final title = hasLocation ? 'Autour de vous' : 'Restaurants proches';
    final subtitle =
        error ??
        (hasLocation
            ? 'Triés selon votre position actuelle.'
            : 'Activez votre position pour voir les plus proches.');

    return SoftCard(
      padding: const EdgeInsets.fromLTRB(14, 12, 10, 12),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(
              hasLocation
                  ? Icons.my_location_rounded
                  : Icons.location_searching_rounded,
              color: color,
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ),
          const SizedBox(width: 6),
          if (locating)
            const Padding(
              padding: EdgeInsets.all(10),
              child: SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(strokeWidth: 2.2),
              ),
            )
          else
            TextButton(
              onPressed: onTap,
              style: TextButton.styleFrom(
                minimumSize: const Size(0, 38),
                padding: const EdgeInsets.symmetric(horizontal: 10),
              ),
              child: Text(
                hasLocation ? 'Actualiser' : 'Me localiser',
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _ChatbotFab extends StatelessWidget {
  const _ChatbotFab({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(60),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(60),
            gradient: const LinearGradient(
              colors: [AppColors.primary, AppColors.primaryDark],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            boxShadow: [
              BoxShadow(
                color: AppColors.primary.withValues(alpha: 0.32),
                blurRadius: 18,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: const Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.smart_toy_rounded, color: Colors.white),
              SizedBox(width: 8),
              Text(
                'Aide',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
