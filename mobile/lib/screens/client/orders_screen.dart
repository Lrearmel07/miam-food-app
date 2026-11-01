import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/api_client.dart';
import '../../core/app_state.dart';
import '../../core/format.dart';
import '../../core/theme.dart';
import '../../models/order.dart';
import '../../widgets/common.dart';
import '../tracking/order_tracking_screen.dart';

class OrdersScreen extends StatefulWidget {
  const OrdersScreen({super.key});

  @override
  State<OrdersScreen> createState() => _OrdersScreenState();
}

class _OrdersScreenState extends State<OrdersScreen> {
  Future<List<FoodOrder>>? _future;
  String _filter = 'all';

  @override
  void initState() {
    super.initState();
    _load();
  }

  void _load() {
    setState(() {
      _future = context.read<AppState>().api.orders();
    });
  }

  List<FoodOrder> _applyFilter(List<FoodOrder> orders) {
    return switch (_filter) {
      'active' => orders.where((order) => order.isActive).toList(),
      'done' => orders.where((order) => order.status == 'delivered').toList(),
      'cancelled' =>
        orders.where((order) => order.status == 'cancelled').toList(),
      _ => orders,
    };
  }

  Future<void> _cancel(FoodOrder order) async {
    final confirmed = await showConfirmDialog(
      context,
      title: 'Annuler la commande ?',
      message:
          'La commande #${order.id} chez ${order.restaurant.name} sera annulée.',
      confirmLabel: 'Annuler la commande',
      danger: true,
    );
    if (!confirmed || !mounted) return;

    try {
      await context.read<AppState>().cancelOrder(order.id);
      if (!mounted) return;
      showAppSnack(context, 'Commande annulée.');
      _load();
    } on ApiException catch (error) {
      if (mounted) showAppSnack(context, error.message, error: true);
    }
  }

  void _openTracking(FoodOrder order) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => OrderTrackingScreen(orderId: order.id),
      ),
    );
  }

  bool _canTrack(FoodOrder order) {
    return [
      'accepted',
      'preparing',
      'ready',
      'shipping',
      'delivered',
    ].contains(order.status);
  }

  void _showDetails(FoodOrder order) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (sheetContext) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 22),
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    AppIconBox(
                      emoji: order.restaurant.emoji,
                      color: order.restaurant.tint,
                      size: 52,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Commande #${order.id}',
                            style: Theme.of(context).textTheme.titleLarge,
                          ),
                          Text(
                            '${order.restaurant.name} • ${formatDateTime(order.createdAt)}',
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ],
                      ),
                    ),
                    StatusBadge(status: order.status),
                  ],
                ),
                const SizedBox(height: 20),
                if (order.status == 'cancelled')
                  _CancelledBanner()
                else
                  _StatusTimeline(status: order.status),
                const SizedBox(height: 20),
                Text(
                  'Articles',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 8),
                ...order.items.map(
                  (line) => Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: Row(
                      children: [
                        Text(
                          '${line.quantity}×',
                          style: const TextStyle(
                            fontWeight: FontWeight.w800,
                            fontSize: 13,
                            color: AppColors.primary,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            line.name,
                            style: const TextStyle(fontSize: 13.5),
                          ),
                        ),
                        Text(
                          money(line.total),
                          style: const TextStyle(
                            fontSize: 13,
                            color: AppColors.muted,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const Divider(height: 22),
                _DetailRow(label: 'Sous-total', value: money(order.subtotal)),
                const SizedBox(height: 5),
                _DetailRow(label: 'Livraison', value: money(order.deliveryFee)),
                const SizedBox(height: 8),
                _DetailRow(
                  label: 'Total',
                  value: money(order.total),
                  strong: true,
                ),
                const SizedBox(height: 18),
                InfoRow(
                  icon: Icons.location_on_outlined,
                  label: 'Adresse de livraison',
                  value: order.address,
                ),
                if (order.courier != null)
                  InfoRow(
                    icon: Icons.delivery_dining_rounded,
                    label: 'Livreur',
                    value: order.courier!.fullName,
                  ),
                if (order.notes.trim().isNotEmpty)
                  InfoRow(
                    icon: Icons.notes_rounded,
                    label: 'Instructions',
                    value: order.notes,
                  ),
                const SizedBox(height: 12),
                if (order.status != 'cancelled') ...[
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed: () {
                        Navigator.pop(sheetContext);
                        _openTracking(order);
                      },
                      icon: const Icon(Icons.map_rounded, size: 19),
                      label: Text(
                        order.status == 'delivered'
                            ? 'Voir le trajet'
                            : 'Suivre la livraison',
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                ],
                if (order.canCancel)
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: () {
                        Navigator.pop(sheetContext);
                        _cancel(order);
                      },
                      icon: const Icon(
                        Icons.close_rounded,
                        size: 18,
                        color: AppColors.danger,
                      ),
                      label: const Text(
                        'Annuler la commande',
                        style: TextStyle(color: AppColors.danger),
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

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      bottom: false,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 12, 12, 0),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Mes commandes',
                        style: Theme.of(context).textTheme.headlineSmall,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Suivez vos repas en temps réel.',
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
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 38,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 18),
              children: [
                _FilterChip(
                  label: 'Toutes',
                  selected: _filter == 'all',
                  onTap: () => setState(() => _filter = 'all'),
                ),
                _FilterChip(
                  label: 'En cours',
                  selected: _filter == 'active',
                  onTap: () => setState(() => _filter = 'active'),
                ),
                _FilterChip(
                  label: 'Livrées',
                  selected: _filter == 'done',
                  onTap: () => setState(() => _filter = 'done'),
                ),
                _FilterChip(
                  label: 'Annulées',
                  selected: _filter == 'cancelled',
                  onTap: () => setState(() => _filter = 'cancelled'),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: FutureBuilder<List<FoodOrder>>(
              future: _future,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const LoadingView(
                    label: 'Chargement des commandes...',
                  );
                }
                if (snapshot.hasError) {
                  final error = snapshot.error;
                  return ErrorState(
                    message: error is ApiException
                        ? error.message
                        : 'Impossible de charger les commandes.',
                    onRetry: _load,
                  );
                }

                final orders = _applyFilter(snapshot.data ?? []);
                if (orders.isEmpty) {
                  return ListView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    children: [
                      SizedBox(
                        height: 420,
                        child: EmptyState(
                          icon: Icons.receipt_long_outlined,
                          title: _filter == 'all'
                              ? 'Aucune commande'
                              : 'Rien par ici',
                          message: _filter == 'all'
                              ? 'Vos prochaines commandes apparaîtront ici.'
                              : 'Aucune commande ne correspond à ce filtre.',
                          action: _filter == 'all'
                              ? FilledButton(
                                  onPressed: () =>
                                      context.read<AppState>().setClientTab(0),
                                  child: const Text('Commander'),
                                )
                              : TextButton(
                                  onPressed: () =>
                                      setState(() => _filter = 'all'),
                                  child: const Text('Voir toutes'),
                                ),
                        ),
                      ),
                    ],
                  );
                }

                return RefreshIndicator(
                  color: AppColors.primary,
                  onRefresh: () async {
                    _load();
                    await _future;
                  },
                  child: ListView.builder(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.fromLTRB(18, 6, 18, 24),
                    itemCount: orders.length,
                    itemBuilder: (context, index) {
                      final order = orders[index];
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: OrderCard(
                          order: order,
                          onTap: () => _showDetails(order),
                          showCourier: true,
                          actions: [
                            if (_canTrack(order))
                              SmallActionButton(
                                label: order.status == 'delivered'
                                    ? 'Trajet'
                                    : 'Suivre',
                                icon: Icons.map_rounded,
                                primary: false,
                                onPressed: () {
                                  _openTracking(order);
                                },
                              ),
                            if (order.canCancel)
                              SmallActionButton(
                                label: 'Annuler',
                                icon: Icons.close_rounded,
                                primary: false,
                                danger: true,
                                onPressed: () {
                                  _cancel(order);
                                },
                              ),
                          ],
                        ),
                      );
                    },
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

class _FilterChip extends StatelessWidget {
  const _FilterChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(30),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(horizontal: 15),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: selected ? AppColors.ink : Colors.white,
            borderRadius: BorderRadius.circular(30),
            border: Border.all(
              color: selected ? AppColors.ink : AppColors.line,
            ),
          ),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: selected ? Colors.white : AppColors.muted,
            ),
          ),
        ),
      ),
    );
  }
}

class _StatusTimeline extends StatelessWidget {
  const _StatusTimeline({required this.status});

  final String status;

  static const _steps = [
    'pending',
    'accepted',
    'preparing',
    'ready',
    'shipping',
    'delivered',
  ];

  @override
  Widget build(BuildContext context) {
    final current = _steps.indexOf(status);
    return Column(
      children: List.generate(_steps.length, (index) {
        final step = _steps[index];
        final done = index < current;
        final isCurrent = index == current;
        final color = done || isCurrent ? statusColor(step) : AppColors.line;
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Column(
              children: [
                Container(
                  width: 28,
                  height: 28,
                  decoration: BoxDecoration(
                    color: done || isCurrent
                        ? color.withValues(alpha: 0.12)
                        : AppColors.cream,
                    shape: BoxShape.circle,
                    border: Border.all(color: color, width: 1.4),
                  ),
                  child: Icon(
                    done ? Icons.check_rounded : statusIcon(step),
                    size: 15,
                    color: done || isCurrent ? color : AppColors.muted,
                  ),
                ),
                if (index < _steps.length - 1)
                  Container(
                    width: 2,
                    height: isCurrent ? 34 : 28,
                    color: done ? color.withValues(alpha: 0.5) : AppColors.line,
                  ),
              ],
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Padding(
                padding: EdgeInsets.only(top: 4, bottom: isCurrent ? 10 : 0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      statusLabel(step),
                      style: TextStyle(
                        fontSize: 13.5,
                        fontWeight: isCurrent
                            ? FontWeight.w800
                            : FontWeight.w600,
                        color: done || isCurrent
                            ? AppColors.ink
                            : AppColors.muted,
                      ),
                    ),
                    if (isCurrent) ...[
                      const SizedBox(height: 2),
                      Text(
                        statusHint(step),
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ],
        );
      }),
    );
  }
}

class _CancelledBanner extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.danger.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(16),
      ),
      child: const Row(
        children: [
          Icon(Icons.cancel_outlined, color: AppColors.danger, size: 22),
          SizedBox(width: 10),
          Expanded(
            child: Text(
              'Cette commande a été annulée. Aucun montant ne sera prélevé.',
              style: TextStyle(
                color: AppColors.danger,
                fontSize: 12.5,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({
    required this.label,
    required this.value,
    this.strong = false,
  });

  final String label;
  final String value;
  final bool strong;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(
            label,
            style: TextStyle(
              fontSize: strong ? 15 : 13,
              fontWeight: strong ? FontWeight.w800 : FontWeight.w500,
              color: strong ? AppColors.ink : AppColors.muted,
            ),
          ),
        ),
        Text(
          value,
          style: TextStyle(
            fontSize: strong ? 18 : 13,
            fontWeight: strong ? FontWeight.w800 : FontWeight.w600,
          ),
        ),
      ],
    );
  }
}
