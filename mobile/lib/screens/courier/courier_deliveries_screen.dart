import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/api_client.dart';
import '../../core/app_state.dart';
import '../../core/format.dart';
import '../../core/theme.dart';
import '../../models/order.dart';
import '../../widgets/common.dart';
import 'courier_tracking_screen.dart';

class CourierDeliveriesScreen extends StatefulWidget {
  const CourierDeliveriesScreen({super.key});

  @override
  State<CourierDeliveriesScreen> createState() =>
      _CourierDeliveriesScreenState();
}

class _CourierDeliveriesScreenState extends State<CourierDeliveriesScreen> {
  Future<List<FoodOrder>>? _future;
  String _filter = 'active';
  int? _busyOrder;

  @override
  void initState() {
    super.initState();
    _load();
  }

  void _load() {
    setState(() {
      _future = context.read<AppState>().api.courierOrders();
    });
  }

  void _openTracking(FoodOrder order) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => CourierTrackingScreen(orderId: order.id),
      ),
    );
  }

  Future<void> _deliver(FoodOrder order) async {
    final confirmed = await showConfirmDialog(
      context,
      title: 'Course terminée ?',
      message:
          'Confirmez la livraison de la commande #${order.id} à ${order.client.fullName}.',
      confirmLabel: 'Marquer livrée',
    );
    if (!confirmed || !mounted) return;

    setState(() => _busyOrder = order.id);
    try {
      await context.read<AppState>().api.deliverOrder(order.id);
      if (!mounted) return;
      showAppSnack(
        context,
        'Course livrée. Gain : ${money(order.deliveryFee)}.',
      );
      _load();
    } on ApiException catch (error) {
      if (mounted) showAppSnack(context, error.message, error: true);
    } finally {
      if (mounted) setState(() => _busyOrder = null);
    }
  }

  List<FoodOrder> _applyFilter(List<FoodOrder> orders) {
    return switch (_filter) {
      'done' => orders.where((order) => order.status == 'delivered').toList(),
      'active' => orders.where((order) => order.status == 'shipping').toList(),
      _ => orders,
    };
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
                        'Mes livraisons',
                        style: Theme.of(context).textTheme.headlineSmall,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Vos courses en cours et terminées.',
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
            child: Row(
              children: [
                _DeliveryFilter(
                  label: 'En cours',
                  selected: _filter == 'active',
                  onTap: () => setState(() => _filter = 'active'),
                ),
                const SizedBox(width: 8),
                _DeliveryFilter(
                  label: 'Livrées',
                  selected: _filter == 'done',
                  onTap: () => setState(() => _filter = 'done'),
                ),
                const SizedBox(width: 8),
                _DeliveryFilter(
                  label: 'Toutes',
                  selected: _filter == 'all',
                  onTap: () => setState(() => _filter = 'all'),
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
                    label: 'Chargement des livraisons...',
                  );
                }
                if (snapshot.hasError) {
                  final error = snapshot.error;
                  return ErrorState(
                    message: error is ApiException
                        ? error.message
                        : 'Impossible de charger vos livraisons.',
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
                          icon: Icons.delivery_dining_outlined,
                          title: 'Aucune livraison',
                          message: _filter == 'active'
                              ? 'Acceptez une course depuis l’onglet Courses.'
                              : 'Vos livraisons terminées apparaîtront ici.',
                          action: _filter == 'active'
                              ? TextButton(
                                  onPressed: _load,
                                  child: const Text('Actualiser'),
                                )
                              : null,
                        ),
                      ),
                    ],
                  );
                }

                return RefreshIndicator(
                  color: AppColors.blue,
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
                          actions: order.status == 'shipping'
                              ? [
                                  SmallActionButton(
                                    label: 'Suivi',
                                    icon: Icons.share_location_rounded,
                                    primary: false,
                                    onPressed: () => _openTracking(order),
                                  ),
                                  SmallActionButton(
                                    label: _busyOrder == order.id
                                        ? 'Un instant...'
                                        : 'Livrer',
                                    icon: Icons.done_all_rounded,
                                    onPressed: _busyOrder == order.id
                                        ? null
                                        : () => _deliver(order),
                                  ),
                                ]
                              : const [],
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

class _DeliveryFilter extends StatelessWidget {
  const _DeliveryFilter({
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
              ? AppColors.blue.withValues(alpha: 0.1)
              : Colors.white,
          borderRadius: BorderRadius.circular(30),
          border: Border.all(color: selected ? AppColors.blue : AppColors.line),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: selected ? AppColors.blue : AppColors.muted,
          ),
        ),
      ),
    );
  }
}
