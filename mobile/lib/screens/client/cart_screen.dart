import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/app_state.dart';
import '../../core/format.dart';
import '../../core/theme.dart';
import '../../models/cart_line.dart';
import '../../widgets/common.dart';
import 'checkout_screen.dart';

class CartScreen extends StatelessWidget {
  const CartScreen({super.key, this.embedded = false});

  final bool embedded;

  void _goHome(BuildContext context) {
    if (embedded) {
      context.read<AppState>().setClientTab(0);
    } else {
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final restaurant = state.cartRestaurant;

    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: !embedded,
        title: const Text('Mon panier'),
        actions: [
          if (state.cart.isNotEmpty)
            TextButton(
              onPressed: () async {
                final confirmed = await showConfirmDialog(
                  context,
                  title: 'Vider le panier ?',
                  message:
                      'Tous les plats ajoutés seront retirés de votre panier.',
                  confirmLabel: 'Vider',
                  danger: true,
                );
                if (confirmed && context.mounted) {
                  state.clearCart();
                }
              },
              child: const Text('Vider'),
            ),
        ],
      ),
      body: state.cart.isEmpty
          ? EmptyState(
              icon: Icons.shopping_bag_outlined,
              title: 'Votre panier est vide',
              message:
                  'Parcourez les restaurants et ajoutez vos plats préférés.',
              action: FilledButton(
                onPressed: () => _goHome(context),
                child: const Text('Découvrir les restaurants'),
              ),
            )
          : ListView(
              padding: const EdgeInsets.fromLTRB(18, 8, 18, 24),
              children: [
                if (restaurant != null)
                  SoftCard(
                    padding: const EdgeInsets.all(13),
                    child: Row(
                      children: [
                        AppIconBox(
                          emoji: restaurant.emoji,
                          color: restaurant.tint,
                          size: 50,
                        ),
                        const SizedBox(width: 11),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                restaurant.name,
                                style: const TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                '${restaurant.etaMin} min • ${money(restaurant.deliveryFee)} de livraison',
                                style: Theme.of(context).textTheme.bodySmall,
                              ),
                            ],
                          ),
                        ),
                        TextButton(
                          onPressed: () => _goHome(context),
                          child: const Text('Ajouter'),
                        ),
                      ],
                    ),
                  ),
                const SizedBox(height: 18),
                SectionHeader(
                  title: 'Vos plats',
                  subtitle: '${state.cartCount} article(s)',
                ),
                const SizedBox(height: 10),
                ...state.cart.map(
                  (line) => Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: _CartLineCard(
                      line: line,
                      tint: restaurant?.tint ?? AppColors.primary,
                      onAdd: () => state.increment(line.product),
                      onRemove: () => state.decrement(line.product),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                SoftCard(
                  child: Column(
                    children: [
                      _BillRow(
                        label: 'Sous-total',
                        value: money(state.cartSubtotal),
                      ),
                      const SizedBox(height: 10),
                      _BillRow(
                        label: 'Frais de livraison',
                        value: money(state.cartDeliveryFee),
                      ),
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 13),
                        child: Divider(),
                      ),
                      _BillRow(
                        label: 'Total',
                        value: money(state.cartTotal),
                        strong: true,
                      ),
                      if (restaurant != null &&
                          state.cartSubtotal < restaurant.minOrder) ...[
                        const SizedBox(height: 12),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(11),
                          decoration: BoxDecoration(
                            color: AppColors.warning.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            'Minimum de commande : ${money(restaurant.minOrder)}. Ajoutez encore ${money(restaurant.minOrder - state.cartSubtotal)}.',
                            style: const TextStyle(
                              fontSize: 11.5,
                              color: Color(0xFF9A6500),
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  height: 56,
                  child: FilledButton(
                    onPressed:
                        restaurant != null &&
                            state.cartSubtotal >= restaurant.minOrder
                        ? () {
                            Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) => const CheckoutScreen(),
                              ),
                            );
                          }
                        : null,
                    child: const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text('Passer au paiement'),
                        SizedBox(width: 8),
                        Icon(Icons.arrow_forward_rounded, size: 18),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                Center(
                  child: Text(
                    'Paiement sécurisé • Livraison suivie',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ),
              ],
            ),
    );
  }
}

class _CartLineCard extends StatelessWidget {
  const _CartLineCard({
    required this.line,
    required this.tint,
    required this.onAdd,
    required this.onRemove,
  });

  final CartLine line;
  final Color tint;
  final VoidCallback onAdd;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    return SoftCard(
      padding: const EdgeInsets.all(12),
      child: Row(
        children: [
          AppImageBox(
            imageUrl: line.product.imageUrl,
            emoji: line.product.emoji,
            color: tint,
            size: 56,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  line.product.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 14.5,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  money(line.product.price),
                  style: const TextStyle(
                    fontSize: 12.5,
                    color: AppColors.muted,
                  ),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                money(line.total),
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 6),
              QuantityStepper(
                quantity: line.quantity,
                onAdd: onAdd,
                onRemove: onRemove,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _BillRow extends StatelessWidget {
  const _BillRow({
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
              fontSize: strong ? 16 : 13.5,
              fontWeight: strong ? FontWeight.w800 : FontWeight.w500,
              color: strong ? AppColors.ink : AppColors.muted,
            ),
          ),
        ),
        Text(
          value,
          style: TextStyle(
            fontSize: strong ? 20 : 13.5,
            fontWeight: strong ? FontWeight.w800 : FontWeight.w600,
            color: AppColors.ink,
          ),
        ),
      ],
    );
  }
}
