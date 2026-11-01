import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/api_client.dart';
import '../../core/app_state.dart';
import '../../core/format.dart';
import '../../core/theme.dart';
import '../../models/order.dart';
import '../../widgets/common.dart';

const List<String> _allStatuses = [
  'pending',
  'accepted',
  'preparing',
  'ready',
  'shipping',
  'delivered',
  'cancelled',
];

class AdminOrdersScreen extends StatefulWidget {
  const AdminOrdersScreen({super.key});

  @override
  State<AdminOrdersScreen> createState() => _AdminOrdersScreenState();
}

class _AdminOrdersScreenState extends State<AdminOrdersScreen> {
  Future<List<FoodOrder>>? _future;
  final _search = TextEditingController();
  String _filter = 'all';

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  void _load() {
    setState(() {
      _future = context.read<AppState>().api.adminOrders();
    });
  }

  Future<void> _changeStatus(FoodOrder order) async {
    final status = await showModalBottomSheet<String>(
      context: context,
      useSafeArea: true,
      builder: (sheetContext) => _StatusSheet(order: order),
    );
    if (status == null || status == order.status || !mounted) return;

    try {
      await context.read<AppState>().api.adminUpdateOrderStatus(
        order.id,
        status,
      );
      if (!mounted) return;
      showAppSnack(context, 'Commande #${order.id} → ${statusLabel(status)}.');
      _load();
    } on ApiException catch (error) {
      if (mounted) showAppSnack(context, error.message, error: true);
    }
  }

  List<FoodOrder> _filtered(List<FoodOrder> orders) {
    final query = _search.text.trim().toLowerCase();
    return orders.where((order) {
      final matchesFilter = switch (_filter) {
        'active' => order.isActive,
        'delivered' => order.status == 'delivered',
        'cancelled' => order.status == 'cancelled',
        _ => true,
      };
      if (!matchesFilter) return false;
      if (query.isEmpty) return true;
      return order.id.toString().contains(query) ||
          order.restaurant.name.toLowerCase().contains(query) ||
          order.client.fullName.toLowerCase().contains(query) ||
          (order.courier?.fullName.toLowerCase().contains(query) ?? false);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      bottom: false,
      child: FutureBuilder<List<FoodOrder>>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const LoadingView(label: 'Chargement des commandes...');
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

          final all = snapshot.data ?? [];
          final orders = _filtered(all);
          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(18, 12, 18, 0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Commandes',
                                style: Theme.of(
                                  context,
                                ).textTheme.headlineSmall,
                              ),
                              const SizedBox(height: 2),
                              Text(
                                '${all.length} commandes sur la plateforme',
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
                    TextField(
                      controller: _search,
                      onChanged: (_) => setState(() {}),
                      decoration: InputDecoration(
                        hintText: 'N° de commande, client, restaurant...',
                        prefixIcon: const Icon(Icons.search_rounded),
                        suffixIcon: _search.text.isEmpty
                            ? null
                            : IconButton(
                                onPressed: () {
                                  _search.clear();
                                  setState(() {});
                                },
                                icon: const Icon(Icons.close_rounded),
                              ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
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
                            selected: _filter == 'delivered',
                            onTap: () => setState(() => _filter = 'delivered'),
                          ),
                          _FilterChip(
                            label: 'Annulées',
                            selected: _filter == 'cancelled',
                            onTap: () => setState(() => _filter = 'cancelled'),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: orders.isEmpty
                    ? const EmptyState(
                        icon: Icons.receipt_long_outlined,
                        title: 'Aucune commande',
                        message:
                            'Aucune commande ne correspond à ce filtre pour le moment.',
                      )
                    : RefreshIndicator(
                        color: AppColors.ink,
                        onRefresh: () async {
                          _load();
                          await _future;
                        },
                        child: ListView.separated(
                          physics: const AlwaysScrollableScrollPhysics(),
                          padding: const EdgeInsets.fromLTRB(18, 14, 18, 28),
                          itemCount: orders.length,
                          separatorBuilder: (_, _) =>
                              const SizedBox(height: 10),
                          itemBuilder: (context, index) {
                            final order = orders[index];
                            return OrderCard(
                              order: order,
                              showClient: true,
                              showCourier: true,
                              actions: [
                                SmallActionButton(
                                  label: 'Statut',
                                  icon: Icons.tune_rounded,
                                  primary: false,
                                  onPressed: () => _changeStatus(order),
                                ),
                              ],
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

class _StatusSheet extends StatelessWidget {
  const _StatusSheet({required this.order});

  final FoodOrder order;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 2, 8, 6),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Statut de la commande',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '#${order.id} • ${order.restaurant.name}',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close_rounded),
                ),
              ],
            ),
          ),
          Flexible(
            child: ListView(
              shrinkWrap: true,
              padding: const EdgeInsets.fromLTRB(12, 4, 12, 18),
              children: _allStatuses.map((status) {
                final selected = status == order.status;
                final color = statusColor(status);
                return ListTile(
                  onTap: () => Navigator.pop(context, status),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                  leading: Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(11),
                    ),
                    child: Icon(statusIcon(status), size: 18, color: color),
                  ),
                  title: Text(
                    statusLabel(status),
                    style: TextStyle(
                      fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
                    ),
                  ),
                  subtitle: Text(
                    statusHint(status),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  trailing: selected
                      ? Icon(Icons.check_circle_rounded, color: color)
                      : null,
                );
              }).toList(),
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
      child: ChoiceChip(
        label: Text(label),
        selected: selected,
        onSelected: (_) => onTap(),
        showCheckmark: false,
        labelStyle: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w700,
          color: selected ? Colors.white : AppColors.muted,
        ),
        selectedColor: AppColors.ink,
        backgroundColor: Colors.white,
        side: BorderSide(color: selected ? AppColors.ink : AppColors.line),
      ),
    );
  }
}
