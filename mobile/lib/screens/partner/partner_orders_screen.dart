import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/api_client.dart';
import '../../core/app_state.dart';
import '../../core/format.dart';
import '../../core/theme.dart';
import '../../models/order.dart';
import '../../widgets/common.dart';
import '../tracking/order_tracking_screen.dart';

class PartnerOrdersScreen extends StatefulWidget {
  const PartnerOrdersScreen({super.key});

  @override
  State<PartnerOrdersScreen> createState() => _PartnerOrdersScreenState();
}

class _PartnerOrdersScreenState extends State<PartnerOrdersScreen> {
  Future<List<FoodOrder>>? _future;
  String _filter = 'todo';
  int? _busyOrder;

  @override
  void initState() {
    super.initState();
    _load();
  }

  void _load() {
    setState(() {
      _future = context.read<AppState>().api.partnerOrders();
    });
  }

  bool _matches(FoodOrder order) {
    return switch (_filter) {
      'ready' => order.status == 'ready',
      'shipping' => order.status == 'shipping',
      'history' => ['delivered', 'cancelled'].contains(order.status),
      _ => ['pending', 'accepted', 'preparing'].contains(order.status),
    };
  }

  void _openTracking(FoodOrder order) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => OrderTrackingScreen(orderId: order.id),
      ),
    );
  }

  Future<void> _updateStatus(FoodOrder order, String status) async {
    if (status == 'cancelled') {
      final confirmed = await showConfirmDialog(
        context,
        title: 'Refuser la commande ?',
        message:
            'La commande #${order.id} de ${order.client.fullName} sera annulée.',
        confirmLabel: 'Refuser',
        danger: true,
      );
      if (!confirmed || !mounted) return;
    }

    setState(() => _busyOrder = order.id);
    try {
      await context.read<AppState>().api.updatePartnerOrderStatus(
        order.id,
        status,
      );
      if (!mounted) return;
      showAppSnack(
        context,
        'Commande #${order.id} : ${statusLabel(status).toLowerCase()}.',
        icon: statusIcon(status),
      );
      _load();
    } on ApiException catch (error) {
      if (mounted) showAppSnack(context, error.message, error: true);
    } finally {
      if (mounted) setState(() => _busyOrder = null);
    }
  }

  List<Widget> _actions(FoodOrder order) {
    final busy = _busyOrder == order.id;
    switch (order.status) {
      case 'pending':
        return [
          SmallActionButton(
            label: 'Refuser',
            primary: false,
            danger: true,
            icon: Icons.close_rounded,
            onPressed: busy
                ? null
                : () {
                    _updateStatus(order, 'cancelled');
                  },
          ),
          SmallActionButton(
            label: 'Accepter',
            icon: Icons.check_rounded,
            onPressed: busy
                ? null
                : () {
                    _updateStatus(order, 'accepted');
                  },
          ),
        ];
      case 'accepted':
        return [
          SmallActionButton(
            label: 'Commencer',
            icon: Icons.soup_kitchen_rounded,
            onPressed: busy
                ? null
                : () {
                    _updateStatus(order, 'preparing');
                  },
          ),
        ];
      case 'preparing':
        return [
          SmallActionButton(
            label: 'Prête',
            icon: Icons.shopping_bag_rounded,
            onPressed: busy
                ? null
                : () {
                    _updateStatus(order, 'ready');
                  },
          ),
        ];
      case 'ready':
        return [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: AppColors.teal.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.delivery_dining_rounded,
                  size: 16,
                  color: AppColors.teal,
                ),
                SizedBox(width: 6),
                Text(
                  'En attente d’un livreur',
                  style: TextStyle(
                    color: AppColors.teal,
                    fontSize: 11.5,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
          SmallActionButton(
            label: 'Suivre',
            icon: Icons.map_rounded,
            primary: false,
            onPressed: () => _openTracking(order),
          ),
        ];
      case 'shipping':
        return [
          SmallActionButton(
            label: 'Suivre',
            icon: Icons.map_rounded,
            onPressed: () => _openTracking(order),
          ),
        ];
      case 'delivered':
        return [
          SmallActionButton(
            label: 'Trajet',
            icon: Icons.map_rounded,
            primary: false,
            onPressed: () => _openTracking(order),
          ),
        ];
      default:
        return const [];
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
            padding: const EdgeInsets.fromLTRB(18, 12, 12, 0),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Commandes',
                        style: Theme.of(context).textTheme.headlineSmall,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Gérez le flux de votre restaurant.',
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
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 18),
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _PartnerFilter(
                  label: 'À traiter',
                  selected: _filter == 'todo',
                  onTap: () => setState(() => _filter = 'todo'),
                ),
                _PartnerFilter(
                  label: 'Prêtes',
                  selected: _filter == 'ready',
                  onTap: () => setState(() => _filter = 'ready'),
                ),
                _PartnerFilter(
                  label: 'En route',
                  selected: _filter == 'shipping',
                  onTap: () => setState(() => _filter = 'shipping'),
                ),
                _PartnerFilter(
                  label: 'Historique',
                  selected: _filter == 'history',
                  onTap: () => setState(() => _filter = 'history'),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
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

                final orders = (snapshot.data ?? []).where(_matches).toList();

                if (orders.isEmpty) {
                  return ListView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    children: [
                      SizedBox(
                        height: 420,
                        child: EmptyState(
                          icon: Icons.receipt_long_outlined,
                          title: _filter == 'todo'
                              ? 'Tout est à jour !'
                              : 'Aucune commande',
                          message: _filter == 'todo'
                              ? 'Les nouvelles commandes apparaîtront ici.'
                              : 'Aucune commande dans cette section.',
                          action: TextButton.icon(
                            onPressed: _load,
                            icon: const Icon(Icons.refresh_rounded, size: 18),
                            label: const Text('Actualiser'),
                          ),
                        ),
                      ),
                    ],
                  );
                }

                return RefreshIndicator(
                  color: AppColors.purple,
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
                          showClient: true,
                          showCourier: true,
                          actions: _actions(order),
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

class _PartnerFilter extends StatelessWidget {
  const _PartnerFilter({
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
        padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 9),
        decoration: BoxDecoration(
          color: selected
              ? AppColors.purple.withValues(alpha: 0.1)
              : Colors.white,
          borderRadius: BorderRadius.circular(30),
          border: Border.all(
            color: selected ? AppColors.purple : AppColors.line,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: selected ? AppColors.purple : AppColors.muted,
          ),
        ),
      ),
    );
  }
}
