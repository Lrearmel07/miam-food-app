import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/api_client.dart';
import '../../core/app_state.dart';
import '../../core/format.dart';
import '../../core/theme.dart';
import '../../models/order.dart';
import '../../widgets/common.dart';

class CourierHomeScreen extends StatefulWidget {
  const CourierHomeScreen({super.key, required this.onAccepted});

  final VoidCallback onAccepted;

  @override
  State<CourierHomeScreen> createState() => _CourierHomeScreenState();
}

class _CourierHomeData {
  const _CourierHomeData({required this.stats, required this.orders});

  final Map<String, dynamic> stats;
  final List<FoodOrder> orders;
}

class _CourierHomeScreenState extends State<CourierHomeScreen> {
  Future<_CourierHomeData>? _future;
  int? _busyOrder;

  @override
  void initState() {
    super.initState();
    _load();
  }

  void _load() {
    final api = context.read<AppState>().api;
    setState(() {
      _future = () async {
        final stats = await api.courierStats();
        final orders = await api.courierAvailable();
        return _CourierHomeData(stats: stats, orders: orders);
      }();
    });
  }

  Future<void> _accept(FoodOrder order) async {
    setState(() => _busyOrder = order.id);
    try {
      await context.read<AppState>().api.acceptOrder(order.id);
      if (!mounted) return;
      showAppSnack(
        context,
        'Course acceptée ! Rendez-vous chez ${order.restaurant.name}.',
      );
      widget.onAccepted();
    } on ApiException catch (error) {
      if (mounted) showAppSnack(context, error.message, error: true);
      if (mounted) _load();
    } finally {
      if (mounted) setState(() => _busyOrder = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      bottom: false,
      child: FutureBuilder<_CourierHomeData>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const LoadingView(label: 'Recherche des courses...');
          }
          if (snapshot.hasError) {
            final error = snapshot.error;
            return ErrorState(
              message: error is ApiException
                  ? error.message
                  : 'Impossible de charger les courses.',
              onRetry: _load,
            );
          }

          final data = snapshot.data!;
          final stats = data.stats;
          final orders = data.orders;

          return RefreshIndicator(
            color: AppColors.blue,
            onRefresh: () async {
              _load();
              await _future;
            },
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(18, 12, 18, 28),
              children: [
                _Header(
                  name: context.watch<AppState>().user?.firstName ?? 'Livreur',
                  onRefresh: _load,
                ),
                const SizedBox(height: 18),
                _StatsGrid(stats: stats),
                const SizedBox(height: 24),
                SectionHeader(
                  title: 'Courses disponibles',
                  subtitle: orders.isEmpty
                      ? 'Restez connecté, ça arrive !'
                      : '${orders.length} course(s) prête(s) à récupérer',
                ),
                const SizedBox(height: 12),
                if (orders.isEmpty)
                  SizedBox(
                    height: 300,
                    child: EmptyState(
                      icon: Icons.delivery_dining_outlined,
                      title: 'Aucune course pour le moment',
                      message:
                          'Les commandes prêtes à être livrées apparaîtront ici en temps réel.',
                      action: TextButton.icon(
                        onPressed: _load,
                        icon: const Icon(Icons.refresh_rounded, size: 18),
                        label: const Text('Actualiser'),
                      ),
                    ),
                  )
                else
                  ...orders.map(
                    (order) => Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: _CourseCard(
                        order: order,
                        busy: _busyOrder == order.id,
                        onAccept: () => _accept(order),
                      ),
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

class _Header extends StatelessWidget {
  const _Header({required this.name, required this.onRefresh});

  final String name;
  final VoidCallback onRefresh;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(26),
        gradient: const LinearGradient(
          colors: [Color(0xFF2F80ED), Color(0xFF1C5FC4)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: [
          BoxShadow(
            color: AppColors.blue.withValues(alpha: 0.28),
            blurRadius: 22,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 9,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.18),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Text(
                    'ESPACE LIVREUR',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 9,
                      letterSpacing: 0.9,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  'Prêt à rouler, $name ?',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 23,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.6,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Acceptez une course et suivez vos gains.',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.8),
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Container(
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.16),
              borderRadius: BorderRadius.circular(16),
            ),
            child: IconButton(
              onPressed: onRefresh,
              icon: const Icon(
                Icons.refresh_rounded,
                color: Colors.white,
                size: 21,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _StatsGrid extends StatelessWidget {
  const _StatsGrid({required this.stats});

  final Map<String, dynamic> stats;

  @override
  Widget build(BuildContext context) {
    final items = [
      (
        label: 'Disponibles',
        value: '${stats['available'] ?? 0}',
        icon: Icons.explore_outlined,
        color: AppColors.blue,
      ),
      (
        label: 'En cours',
        value: '${stats['active'] ?? 0}',
        icon: Icons.delivery_dining_rounded,
        color: AppColors.primary,
      ),
      (
        label: 'Livrées',
        value: '${stats['delivered'] ?? 0}',
        icon: Icons.done_all_rounded,
        color: AppColors.success,
      ),
      (
        label: 'Gains',
        value: money((stats['earnings'] as num?)?.toDouble() ?? 0),
        icon: Icons.account_balance_wallet_outlined,
        color: AppColors.purple,
      ),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        final width = (constraints.maxWidth - 10) / 2;
        return Wrap(
          spacing: 10,
          runSpacing: 10,
          children: items
              .map(
                (item) => SizedBox(
                  width: width,
                  child: StatCard(
                    label: item.label,
                    value: item.value,
                    icon: item.icon,
                    color: item.color,
                  ),
                ),
              )
              .toList(),
        );
      },
    );
  }
}

class _CourseCard extends StatelessWidget {
  const _CourseCard({
    required this.order,
    required this.busy,
    required this.onAccept,
  });

  final FoodOrder order;
  final bool busy;
  final VoidCallback onAccept;

  @override
  Widget build(BuildContext context) {
    return SoftCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              AppIconBox(
                emoji: order.restaurant.emoji,
                color: order.restaurant.tint,
                size: 46,
              ),
              const SizedBox(width: 11),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      order.restaurant.name,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    Text(
                      'Course #${order.id} • ${timeAgo(order.createdAt)}',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: AppColors.softGreen,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  money(order.deliveryFee),
                  style: const TextStyle(
                    color: AppColors.success,
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          _RouteLine(
            icon: Icons.storefront_rounded,
            color: order.restaurant.tint,
            label: 'Récupération',
            value: order.restaurant.address,
          ),
          Padding(
            padding: const EdgeInsets.only(left: 12),
            child: Container(width: 2, height: 16, color: AppColors.line),
          ),
          _RouteLine(
            icon: Icons.location_on_rounded,
            color: AppColors.primary,
            label: 'Livraison • ${order.client.fullName}',
            value: order.address,
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${order.itemCount} article(s)',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                    Text(
                      money(order.total),
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(
                height: 42,
                child: FilledButton(
                  onPressed: busy ? null : onAccept,
                  style: FilledButton.styleFrom(
                    minimumSize: const Size(0, 42),
                    padding: const EdgeInsets.symmetric(horizontal: 18),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  child: busy
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Text('Accepter'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _RouteLine extends StatelessWidget {
  const _RouteLine({
    required this.icon,
    required this.color,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final Color color;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 26,
          height: 26,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.12),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, size: 14, color: color),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: AppColors.muted,
                ),
              ),
              const SizedBox(height: 1),
              Text(
                value,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
