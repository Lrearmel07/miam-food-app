import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/api_client.dart';
import '../../core/app_state.dart';
import '../../core/format.dart';
import '../../core/theme.dart';
import '../../models/order.dart';
import '../../widgets/common.dart';

class AdminDashboardScreen extends StatefulWidget {
  const AdminDashboardScreen({
    super.key,
    required this.onOpenOrders,
    required this.onOpenUsers,
  });

  final VoidCallback onOpenOrders;
  final VoidCallback onOpenUsers;

  @override
  State<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

class _AdminDashboardData {
  const _AdminDashboardData({required this.stats, required this.orders});

  final Map<String, dynamic> stats;
  final List<FoodOrder> orders;
}

class _AdminDashboardScreenState extends State<AdminDashboardScreen> {
  Future<_AdminDashboardData>? _future;

  @override
  void initState() {
    super.initState();
    _load();
  }

  void _load() {
    final api = context.read<AppState>().api;
    setState(() {
      _future = () async {
        final stats = await api.adminStats();
        final orders = await api.adminOrders();
        return _AdminDashboardData(stats: stats, orders: orders);
      }();
    });
  }

  Future<void> _createPartner() async {
    final result = await showModalBottomSheet<Map<String, dynamic>>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => const _PartnerEditor(),
    );
    if (result == null || !mounted) return;

    try {
      await context.read<AppState>().api.adminCreatePartner(
        email: result['email'] as String,
        password: result['password'] as String,
        fullName: result['full_name'] as String,
        restaurantName: result['restaurant_name'] as String,
        cuisine: result['cuisine'] as String,
        phone: result['phone'] as String?,
      );
      if (!mounted) return;
      showAppSnack(context, 'Compte partenaire créé avec succès.');
      _load();
    } on ApiException catch (error) {
      if (mounted) showAppSnack(context, error.message, error: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      bottom: false,
      child: FutureBuilder<_AdminDashboardData>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const LoadingView(label: 'Chargement de la plateforme...');
          }
          if (snapshot.hasError) {
            final error = snapshot.error;
            return ErrorState(
              message: error is ApiException
                  ? error.message
                  : 'Impossible de charger les statistiques.',
              onRetry: _load,
            );
          }

          final stats = snapshot.data!.stats;
          final orders = snapshot.data!.orders;
          final recent = orders.take(3).toList();

          return RefreshIndicator(
            color: AppColors.ink,
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
                            'Pilotage',
                            style: Theme.of(context).textTheme.headlineSmall,
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Vue d’ensemble de Miam.',
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      onPressed: _load,
                      icon: const Icon(Icons.refresh_rounded),
                    ),
                    AppAvatar(user: context.watch<AppState>().user, size: 40),
                  ],
                ),
                const SizedBox(height: 12),
                _RevenueHero(
                  revenue: (stats['revenue'] as num?)?.toDouble() ?? 0,
                  orders: (stats['orders'] as num?)?.toInt() ?? 0,
                  pending: (stats['pending_orders'] as num?)?.toInt() ?? 0,
                  onOpenOrders: widget.onOpenOrders,
                ),
                const SizedBox(height: 18),
                LayoutBuilder(
                  builder: (context, constraints) {
                    final columns = constraints.maxWidth >= 760 ? 4 : 2;
                    final width =
                        (constraints.maxWidth - (columns - 1) * 10) / columns;
                    final cards = [
                      (
                        label: 'Clients',
                        value: '${stats['clients'] ?? 0}',
                        icon: Icons.people_outline_rounded,
                        color: AppColors.primary,
                      ),
                      (
                        label: 'Livreurs',
                        value: '${stats['couriers'] ?? 0}',
                        icon: Icons.delivery_dining_rounded,
                        color: AppColors.blue,
                      ),
                      (
                        label: 'Partenaires',
                        value: '${stats['partners'] ?? 0}',
                        icon: Icons.storefront_rounded,
                        color: AppColors.purple,
                      ),
                      (
                        label: 'Restaurants',
                        value: '${stats['restaurants'] ?? 0}',
                        icon: Icons.restaurant_rounded,
                        color: AppColors.teal,
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
                const SizedBox(height: 18),
                Row(
                  children: [
                    Expanded(
                      child: _QuickAction(
                        icon: Icons.person_add_alt_1_rounded,
                        label: 'Créer un partenaire',
                        color: AppColors.primary,
                        onTap: _createPartner,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _QuickAction(
                        icon: Icons.people_alt_rounded,
                        label: 'Gérer les comptes',
                        color: AppColors.blue,
                        onTap: widget.onOpenUsers,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 22),
                SectionHeader(
                  title: 'Commandes récentes',
                  actionLabel: 'Tout voir',
                  onAction: widget.onOpenOrders,
                ),
                const SizedBox(height: 10),
                if (recent.isEmpty)
                  const EmptyState(
                    icon: Icons.receipt_long_outlined,
                    title: 'Aucune commande',
                    message: 'Les commandes de la plateforme apparaîtront ici.',
                  )
                else
                  ...recent.map(
                    (order) => Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: OrderCard(
                        order: order,
                        showClient: true,
                        showCourier: true,
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

class _RevenueHero extends StatelessWidget {
  const _RevenueHero({
    required this.revenue,
    required this.orders,
    required this.pending,
    required this.onOpenOrders,
  });

  final double revenue;
  final int orders;
  final int pending;
  final VoidCallback onOpenOrders;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(28),
        gradient: const LinearGradient(
          colors: [Color(0xFF24211F), Color(0xFF3D3733)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: [
          BoxShadow(
            color: AppColors.ink.withValues(alpha: 0.24),
            blurRadius: 24,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Text(
                  'CHIFFRE D’AFFAIRES',
                  style: TextStyle(
                    color: AppColors.primary,
                    fontSize: 8.5,
                    letterSpacing: 0.9,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              const Spacer(),
              const Icon(
                Icons.insights_rounded,
                color: AppColors.primary,
                size: 20,
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            money(revenue),
            style: const TextStyle(
              color: Colors.white,
              fontSize: 36,
              fontWeight: FontWeight.w800,
              letterSpacing: -1.3,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            'Commandes livrées sur la plateforme',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.55),
              fontSize: 11,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: MiniStat(
                  label: 'Commandes',
                  value: '$orders',
                  onDark: true,
                ),
              ),
              Container(
                width: 1,
                height: 30,
                color: Colors.white.withValues(alpha: 0.14),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: MiniStat(
                  label: 'En cours',
                  value: '$pending',
                  onDark: true,
                ),
              ),
              TextButton(
                onPressed: onOpenOrders,
                style: TextButton.styleFrom(foregroundColor: AppColors.primary),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text('Voir'),
                    SizedBox(width: 2),
                    Icon(Icons.arrow_forward_rounded, size: 15),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _QuickAction extends StatelessWidget {
  const _QuickAction({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return SoftCard(
      onTap: onTap,
      padding: const EdgeInsets.all(14),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(11),
            ),
            child: Icon(icon, size: 18, color: color),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              label,
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
  }
}

class _PartnerEditor extends StatefulWidget {
  const _PartnerEditor();

  @override
  State<_PartnerEditor> createState() => _PartnerEditorState();
}

class _PartnerEditorState extends State<_PartnerEditor> {
  final _formKey = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _password = TextEditingController(text: 'demo1234');
  final _name = TextEditingController();
  final _phone = TextEditingController();
  final _restaurant = TextEditingController();
  final _cuisine = TextEditingController(text: 'International');
  bool _obscure = true;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    _name.dispose();
    _phone.dispose();
    _restaurant.dispose();
    _cuisine.dispose();
    super.dispose();
  }

  void _submit() {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    Navigator.of(context).pop({
      'email': _email.text.trim(),
      'password': _password.text,
      'full_name': _name.text.trim(),
      'phone': _phone.text.trim().isEmpty ? null : _phone.text.trim(),
      'restaurant_name': _restaurant.text.trim(),
      'cuisine': _cuisine.text.trim(),
    });
  }

  @override
  Widget build(BuildContext context) {
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
                        'Nouveau partenaire',
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
                TextFormField(
                  controller: _name,
                  textCapitalization: TextCapitalization.words,
                  decoration: const InputDecoration(
                    labelText: 'Nom du gérant',
                    prefixIcon: Icon(Icons.person_outline_rounded),
                  ),
                  validator: (value) => value == null || value.trim().length < 2
                      ? 'Nom trop court'
                      : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _email,
                  keyboardType: TextInputType.emailAddress,
                  autocorrect: false,
                  decoration: const InputDecoration(
                    labelText: 'Email de connexion',
                    prefixIcon: Icon(Icons.mail_outline_rounded),
                  ),
                  validator: (value) => value == null || !value.contains('@')
                      ? 'Email invalide'
                      : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _password,
                  obscureText: _obscure,
                  decoration: InputDecoration(
                    labelText: 'Mot de passe',
                    prefixIcon: const Icon(Icons.lock_outline_rounded),
                    suffixIcon: IconButton(
                      onPressed: () => setState(() => _obscure = !_obscure),
                      icon: Icon(
                        _obscure
                            ? Icons.visibility_outlined
                            : Icons.visibility_off_outlined,
                      ),
                    ),
                  ),
                  validator: (value) => value == null || value.length < 6
                      ? 'Au moins 6 caractères'
                      : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _phone,
                  keyboardType: TextInputType.phone,
                  decoration: const InputDecoration(
                    labelText: 'Téléphone (optionnel)',
                    hintText: '+225 07 00 00 00 00',
                    prefixIcon: Icon(Icons.phone_outlined),
                  ),
                ),
                const SizedBox(height: 18),
                const Text(
                  'Restaurant',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _restaurant,
                  textCapitalization: TextCapitalization.words,
                  decoration: const InputDecoration(
                    labelText: 'Nom du restaurant',
                    prefixIcon: Icon(Icons.storefront_outlined),
                  ),
                  validator: (value) => value == null || value.trim().length < 2
                      ? 'Nom trop court'
                      : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _cuisine,
                  decoration: const InputDecoration(
                    labelText: 'Type de cuisine',
                    prefixIcon: Icon(Icons.restaurant_rounded),
                  ),
                  validator: (value) => value == null || value.trim().isEmpty
                      ? 'Cuisine requise'
                      : null,
                ),
                const SizedBox(height: 20),
                SizedBox(
                  height: 54,
                  child: FilledButton(
                    onPressed: _submit,
                    child: const Text('Créer le compte'),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Le restaurant sera créé fermé : le partenaire pourra l’ouvrir depuis son tableau de bord.',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ⬇️ AJOUT : MiniStat était utilisé dans _RevenueHero mais n'était défini nulle part.

class MiniStat extends StatelessWidget {
  const MiniStat({
    super.key,
    required this.label,
    required this.value,
    this.onDark = false,
  });

  final String label;
  final String value;
  final bool onDark;

  @override
  Widget build(BuildContext context) {
    final textColor = onDark ? Colors.white : AppColors.ink;
    final mutedColor = onDark
        ? Colors.white.withValues(alpha: 0.55)
        : AppColors.muted;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          value,
          style: TextStyle(
            color: textColor,
            fontSize: 18,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.4,
          ),
        ),
        const SizedBox(height: 2),
        Text(label, style: TextStyle(color: mutedColor, fontSize: 11)),
      ],
    );
  }
}
