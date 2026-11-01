import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/api_client.dart';
import '../../core/app_state.dart';
import '../../core/format.dart';
import '../../core/theme.dart';
import '../../models/restaurant.dart';
import '../../widgets/common.dart';

class PartnerDashboardScreen extends StatefulWidget {
  const PartnerDashboardScreen({super.key, required this.onOpenOrders});

  final VoidCallback onOpenOrders;

  @override
  State<PartnerDashboardScreen> createState() => _PartnerDashboardScreenState();
}

class _PartnerDashboardData {
  const _PartnerDashboardData({required this.stats, required this.restaurant});

  final Map<String, dynamic> stats;
  final Restaurant restaurant;
}

class _PartnerDashboardScreenState extends State<PartnerDashboardScreen> {
  Future<_PartnerDashboardData>? _future;
  bool _toggling = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  void _load() {
    final api = context.read<AppState>().api;
    setState(() {
      _future = () async {
        final stats = await api.partnerStats();
        final restaurant = await api.partnerRestaurant();
        return _PartnerDashboardData(stats: stats, restaurant: restaurant);
      }();
    });
  }

  Future<void> _toggleOpen(bool value) async {
    setState(() => _toggling = true);
    try {
      await context.read<AppState>().api.updatePartnerRestaurant({
        'is_open': value,
      });
      if (!mounted) return;
      showAppSnack(
        context,
        value
            ? 'Votre restaurant est maintenant ouvert.'
            : 'Votre restaurant est maintenant fermé.',
      );
      _load();
    } on ApiException catch (error) {
      if (mounted) showAppSnack(context, error.message, error: true);
    } finally {
      if (mounted) setState(() => _toggling = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      bottom: false,
      child: FutureBuilder<_PartnerDashboardData>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const LoadingView(label: 'Chargement du tableau de bord...');
          }
          if (snapshot.hasError) {
            final error = snapshot.error;
            return ErrorState(
              message: error is ApiException
                  ? error.message
                  : 'Impossible de charger le tableau de bord.',
              onRetry: _load,
            );
          }

          final data = snapshot.data!;
          final stats = data.stats;
          final pending = (stats['pending'] as num?)?.toInt() ?? 0;

          return RefreshIndicator(
            color: AppColors.purple,
            onRefresh: () async {
              _load();
              await _future;
            },
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(18, 12, 18, 28),
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Tableau de bord',
                            style: Theme.of(context).textTheme.headlineSmall,
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Bonjour ${context.watch<AppState>().user?.firstName ?? ''} 👋',
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      onPressed: _load,
                      icon: const Icon(Icons.refresh_rounded),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                _RestaurantHero(
                  restaurant: data.restaurant,
                  toggling: _toggling,
                  onOpenChanged: _toggleOpen,
                ),
                const SizedBox(height: 18),
                LayoutBuilder(
                  builder: (context, constraints) {
                    final columns = constraints.maxWidth >= 760 ? 4 : 2;
                    final width =
                        (constraints.maxWidth - (columns - 1) * 10) / columns;
                    final cards = [
                      (
                        label: "Commandes aujourd'hui",
                        value: '${stats['orders_today'] ?? 0}',
                        icon: Icons.receipt_long_rounded,
                        color: AppColors.purple,
                      ),
                      (
                        label: 'À traiter',
                        value: '$pending',
                        icon: Icons.pending_actions_rounded,
                        color: AppColors.warning,
                      ),
                      (
                        label: 'Produits au menu',
                        value: '${stats['products'] ?? 0}',
                        icon: Icons.restaurant_menu_rounded,
                        color: AppColors.blue,
                      ),
                      (
                        label: "Chiffre d'affaires",
                        value: money(
                          (stats['revenue'] as num?)?.toDouble() ?? 0,
                        ),
                        icon: Icons.trending_up_rounded,
                        color: AppColors.success,
                      ),
                    ];
                    return Wrap(
                      spacing: 10,
                      runSpacing: 10,
                      children: cards
                          .map(
                            (card) => SizedBox(
                              width: width,
                              child: StatCard(
                                label: card.label,
                                value: card.value,
                                icon: card.icon,
                                color: card.color,
                              ),
                            ),
                          )
                          .toList(),
                    );
                  },
                ),
                const SizedBox(height: 20),
                if (pending > 0)
                  _PendingBanner(count: pending, onTap: widget.onOpenOrders),
                if (pending > 0) const SizedBox(height: 16),
                SoftCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            width: 38,
                            height: 38,
                            decoration: BoxDecoration(
                              color: AppColors.warning.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Icon(
                              Icons.lightbulb_outline_rounded,
                              size: 20,
                              color: AppColors.warning,
                            ),
                          ),
                          const SizedBox(width: 11),
                          const Expanded(
                            child: Text(
                              'Le conseil du jour',
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Text(
                        data.restaurant.isOpen
                            ? 'Un menu à jour et des temps de préparation réalistes améliorent la satisfaction client.'
                            : 'Votre restaurant est fermé : les clients ne peuvent pas commander. Pensez à rouvrir pendant le service.',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: AppColors.muted,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _RestaurantHero extends StatelessWidget {
  const _RestaurantHero({
    required this.restaurant,
    required this.toggling,
    required this.onOpenChanged,
  });

  final Restaurant restaurant;
  final bool toggling;
  final ValueChanged<bool> onOpenChanged;

  @override
  Widget build(BuildContext context) {
    final tint = restaurant.tint;
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(26),
        gradient: LinearGradient(
          colors: [tint, Color.lerp(tint, Colors.black, 0.32)!],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: [
          BoxShadow(
            color: tint.withValues(alpha: 0.24),
            blurRadius: 24,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.18),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Center(
                  child: Text(
                    restaurant.emoji,
                    style: const TextStyle(fontSize: 34),
                  ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      restaurant.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.5,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        const Icon(
                          Icons.star_rounded,
                          size: 15,
                          color: Color(0xFFFFD166),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          '${restaurant.rating.toStringAsFixed(1)} • ${restaurant.cuisine}',
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.85),
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      restaurant.address,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.7),
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.16),
              borderRadius: BorderRadius.circular(18),
            ),
            child: Row(
              children: [
                Icon(
                  restaurant.isOpen
                      ? Icons.storefront_rounded
                      : Icons.do_not_disturb_on_outlined,
                  size: 19,
                  color: Colors.white,
                ),
                const SizedBox(width: 9),
                Expanded(
                  child: Text(
                    restaurant.isOpen
                        ? 'Ouvert — vous acceptez les commandes'
                        : 'Fermé — aucune commande possible',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                if (toggling)
                  const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                else
                  Switch(
                    value: restaurant.isOpen,
                    onChanged: onOpenChanged,
                    activeTrackColor: AppColors.success,
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _PendingBanner extends StatelessWidget {
  const _PendingBanner({required this.count, required this.onTap});

  final int count;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return SoftCard(
      color: const Color(0xFFFFF6E5),
      borderColor: const Color(0xFFFBE2B1),
      onTap: onTap,
      child: Row(
        children: [
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              color: AppColors.warning.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Icon(
              Icons.pending_actions_rounded,
              color: AppColors.warning,
              size: 23,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '$count commande(s) à traiter',
                  style: const TextStyle(
                    fontSize: 14.5,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 2),
                const Text(
                  'Acceptez ou préparez les commandes en attente.',
                  style: TextStyle(fontSize: 11.5, color: AppColors.muted),
                ),
              ],
            ),
          ),
          const Icon(
            Icons.arrow_forward_rounded,
            size: 20,
            color: AppColors.warning,
          ),
        ],
      ),
    );
  }
}
