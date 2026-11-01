import 'package:flutter/material.dart';

import '../../core/theme.dart';
import 'partner_dashboard_screen.dart';
import 'partner_menu_screen.dart';
import 'partner_orders_screen.dart';
import 'partner_profile_screen.dart';

class PartnerShell extends StatefulWidget {
  const PartnerShell({super.key});

  @override
  State<PartnerShell> createState() => _PartnerShellState();
}

class _PartnerShellState extends State<PartnerShell> {
  int _index = 0;

  @override
  Widget build(BuildContext context) {
    final page = switch (_index) {
      1 => const PartnerOrdersScreen(),
      2 => const PartnerMenuScreen(),
      3 => const PartnerProfileScreen(),
      _ => PartnerDashboardScreen(
        onOpenOrders: () => setState(() => _index = 1),
      ),
    };

    return Scaffold(
      body: AnimatedSwitcher(
        duration: const Duration(milliseconds: 240),
        child: KeyedSubtree(key: ValueKey(_index), child: page),
      ),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          border: const Border(top: BorderSide(color: AppColors.line)),
        ),
        child: SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
            child: Row(
              children: [
                _PartnerNavItem(
                  icon: Icons.dashboard_rounded,
                  label: 'Tableau',
                  selected: _index == 0,
                  onTap: () => setState(() => _index = 0),
                ),
                _PartnerNavItem(
                  icon: Icons.receipt_long_rounded,
                  label: 'Commandes',
                  selected: _index == 1,
                  onTap: () => setState(() => _index = 1),
                ),
                _PartnerNavItem(
                  icon: Icons.restaurant_menu_rounded,
                  label: 'Menu',
                  selected: _index == 2,
                  onTap: () => setState(() => _index = 2),
                ),
                _PartnerNavItem(
                  icon: Icons.storefront_rounded,
                  label: 'Profil',
                  selected: _index == 3,
                  onTap: () => setState(() => _index = 3),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _PartnerNavItem extends StatelessWidget {
  const _PartnerNavItem({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: selected
                ? AppColors.purple.withValues(alpha: 0.1)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(18),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                size: 23,
                color: selected ? AppColors.purple : AppColors.muted,
              ),
              const SizedBox(height: 3),
              Text(
                label,
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
                  color: selected ? AppColors.purple : AppColors.muted,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
