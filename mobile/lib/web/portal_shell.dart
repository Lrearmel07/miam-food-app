import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/app_state.dart';
import '../core/theme.dart';
import '../models/user.dart';
import '../screens/admin/admin_dashboard_screen.dart';
import '../screens/admin/admin_orders_screen.dart';
import '../screens/admin/admin_profile_screen.dart';
import '../screens/admin/admin_restaurants_screen.dart';
import '../screens/admin/admin_users_screen.dart';
import '../screens/partner/partner_dashboard_screen.dart';
import '../screens/partner/partner_menu_screen.dart';
import '../screens/partner/partner_orders_screen.dart';
import '../screens/partner/partner_profile_screen.dart';
import '../widgets/common.dart';
import 'portal_kind.dart';

class PortalNavItem {
  const PortalNavItem({
    required this.icon,
    required this.label,
    required this.keyValue,
  });

  final IconData icon;
  final String label;
  final String keyValue;
}

const partnerNavItems = [
  PortalNavItem(
    icon: Icons.dashboard_rounded,
    label: 'Tableau de bord',
    keyValue: 'partner-nav-dashboard',
  ),
  PortalNavItem(
    icon: Icons.receipt_long_rounded,
    label: 'Commandes',
    keyValue: 'partner-nav-orders',
  ),
  PortalNavItem(
    icon: Icons.restaurant_menu_rounded,
    label: 'Menu',
    keyValue: 'partner-nav-menu',
  ),
  PortalNavItem(
    icon: Icons.storefront_rounded,
    label: 'Profil',
    keyValue: 'partner-nav-profile',
  ),
];

const adminNavItems = [
  PortalNavItem(
    icon: Icons.space_dashboard_rounded,
    label: 'Pilotage',
    keyValue: 'admin-nav-dashboard',
  ),
  PortalNavItem(
    icon: Icons.receipt_long_rounded,
    label: 'Commandes',
    keyValue: 'admin-nav-orders',
  ),
  PortalNavItem(
    icon: Icons.people_alt_rounded,
    label: 'Utilisateurs',
    keyValue: 'admin-nav-users',
  ),
  PortalNavItem(
    icon: Icons.storefront_rounded,
    label: 'Restaurants',
    keyValue: 'admin-nav-restaurants',
  ),
  PortalNavItem(
    icon: Icons.person_rounded,
    label: 'Profil',
    keyValue: 'admin-nav-profile',
  ),
];

class PartnerPortalShell extends StatefulWidget {
  const PartnerPortalShell({super.key});

  @override
  State<PartnerPortalShell> createState() => _PartnerPortalShellState();
}

class _PartnerPortalShellState extends State<PartnerPortalShell> {
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

    return PortalShell(
      kind: PortalKind.partner,
      items: partnerNavItems,
      selectedIndex: _index,
      onSelected: (index) => setState(() => _index = index),
      pageKey: 'partner-$_index',
      page: page,
    );
  }
}

class AdminPortalShell extends StatefulWidget {
  const AdminPortalShell({super.key});

  @override
  State<AdminPortalShell> createState() => _AdminPortalShellState();
}

class _AdminPortalShellState extends State<AdminPortalShell> {
  int _index = 0;

  void _go(int index) => setState(() => _index = index);

  @override
  Widget build(BuildContext context) {
    final page = switch (_index) {
      1 => const AdminOrdersScreen(),
      2 => const AdminUsersScreen(),
      3 => const AdminRestaurantsScreen(),
      4 => const AdminProfileScreen(),
      _ => AdminDashboardScreen(
        onOpenOrders: () => _go(1),
        onOpenUsers: () => _go(2),
      ),
    };

    return PortalShell(
      kind: PortalKind.admin,
      items: adminNavItems,
      selectedIndex: _index,
      onSelected: _go,
      pageKey: 'admin-$_index',
      page: page,
    );
  }
}

class PortalShell extends StatelessWidget {
  const PortalShell({
    super.key,
    required this.kind,
    required this.items,
    required this.selectedIndex,
    required this.onSelected,
    required this.pageKey,
    required this.page,
  });

  final PortalKind kind;
  final List<PortalNavItem> items;
  final int selectedIndex;
  final ValueChanged<int> onSelected;
  final String pageKey;
  final Widget page;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: LayoutBuilder(
        builder: (context, constraints) {
          final expanded = constraints.maxWidth >= 1080;
          return Row(
            children: [
              _Sidebar(
                kind: kind,
                items: items,
                selectedIndex: selectedIndex,
                onSelected: onSelected,
                expanded: expanded,
              ),
              Expanded(
                child: ColoredBox(
                  color: AppColors.cream,
                  child: LayoutBuilder(
                    builder: (context, content) {
                      final width = content.maxWidth > 1120
                          ? 1120.0
                          : content.maxWidth;
                      return Center(
                        child: SizedBox(
                          width: width,
                          height: content.maxHeight,
                          child: AnimatedSwitcher(
                            duration: const Duration(milliseconds: 220),
                            switchInCurve: Curves.easeOutCubic,
                            switchOutCurve: Curves.easeInCubic,
                            child: KeyedSubtree(
                              key: ValueKey(pageKey),
                              child: page,
                            ),
                          ),
                        ),
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

class _Sidebar extends StatelessWidget {
  const _Sidebar({
    required this.kind,
    required this.items,
    required this.selectedIndex,
    required this.onSelected,
    required this.expanded,
  });

  final PortalKind kind;
  final List<PortalNavItem> items;
  final int selectedIndex;
  final ValueChanged<int> onSelected;
  final bool expanded;

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AppState>().user;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      width: expanded ? 264 : 88,
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(right: BorderSide(color: AppColors.line)),
      ),
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: EdgeInsets.fromLTRB(
                expanded ? 22 : 18,
                24,
                expanded ? 22 : 18,
                22,
              ),
              child: expanded
                  ? Row(
                      children: [
                        _PortalLogo(kind: kind),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Miam',
                                style: TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: -0.5,
                                ),
                              ),
                              Text(
                                kind.shortLabel,
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w700,
                                  color: kind.accent,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    )
                  : Center(child: _PortalLogo(kind: kind)),
            ),
            Padding(
              padding: EdgeInsets.fromLTRB(
                expanded ? 20 : 12,
                0,
                expanded ? 20 : 12,
                10,
              ),
              child: Text(
                expanded ? 'NAVIGATION' : '···',
                textAlign: expanded ? TextAlign.left : TextAlign.center,
                style: const TextStyle(
                  fontSize: 9,
                  letterSpacing: 1.2,
                  fontWeight: FontWeight.w800,
                  color: AppColors.muted,
                ),
              ),
            ),
            for (var i = 0; i < items.length; i++)
              Padding(
                padding: EdgeInsets.fromLTRB(
                  expanded ? 12 : 10,
                  3,
                  expanded ? 12 : 10,
                  3,
                ),
                child: _NavTile(
                  key: ValueKey(items[i].keyValue),
                  item: items[i],
                  kind: kind,
                  selected: selectedIndex == i,
                  expanded: expanded,
                  onTap: () => onSelected(i),
                ),
              ),
            const Spacer(),
            const Divider(),
            Padding(
              padding: EdgeInsets.fromLTRB(
                expanded ? 18 : 12,
                16,
                expanded ? 14 : 12,
                18,
              ),
              child: expanded
                  ? _UserFooter(kind: kind, user: user)
                  : Column(
                      children: [
                        AppAvatar(user: user, size: 38),
                        const SizedBox(height: 10),
                        IconButton(
                          tooltip: 'Se déconnecter',
                          onPressed: () => context.read<AppState>().logout(),
                          icon: const Icon(
                            Icons.logout_rounded,
                            size: 19,
                            color: AppColors.muted,
                          ),
                        ),
                      ],
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PortalLogo extends StatelessWidget {
  const _PortalLogo({required this.kind});

  final PortalKind kind;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 44,
      height: 44,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [kind.accent, kind.accentDark],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: kind.accent.withValues(alpha: 0.28),
            blurRadius: 14,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Icon(kind.icon, color: Colors.white, size: 22),
    );
  }
}

class _NavTile extends StatefulWidget {
  const _NavTile({
    super.key,
    required this.item,
    required this.kind,
    required this.selected,
    required this.expanded,
    required this.onTap,
  });

  final PortalNavItem item;
  final PortalKind kind;
  final bool selected;
  final bool expanded;
  final VoidCallback onTap;

  @override
  State<_NavTile> createState() => _NavTileState();
}

class _NavTileState extends State<_NavTile> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final kind = widget.kind;
    final selected = widget.selected;
    final background = selected
        ? kind.accent.withValues(alpha: 0.1)
        : _hovered
        ? AppColors.cream
        : Colors.transparent;

    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      cursor: SystemMouseCursors.click,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: widget.onTap,
          borderRadius: BorderRadius.circular(14),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 140),
            padding: EdgeInsets.symmetric(
              horizontal: widget.expanded ? 12 : 0,
              vertical: 12,
            ),
            decoration: BoxDecoration(
              color: background,
              borderRadius: BorderRadius.circular(14),
            ),
            child: widget.expanded
                ? Row(
                    children: [
                      Icon(
                        widget.item.icon,
                        size: 20,
                        color: selected ? kind.accent : AppColors.muted,
                      ),
                      const SizedBox(width: 11),
                      Expanded(
                        child: Text(
                          widget.item.label,
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: selected
                                ? FontWeight.w800
                                : FontWeight.w600,
                            color: selected ? kind.accent : AppColors.ink,
                          ),
                        ),
                      ),
                      if (selected)
                        Container(
                          width: 6,
                          height: 6,
                          decoration: BoxDecoration(
                            color: kind.accent,
                            shape: BoxShape.circle,
                          ),
                        ),
                    ],
                  )
                : Tooltip(
                    message: widget.item.label,
                    child: Icon(
                      widget.item.icon,
                      size: 21,
                      color: selected ? kind.accent : AppColors.muted,
                    ),
                  ),
          ),
        ),
      ),
    );
  }
}

class _UserFooter extends StatelessWidget {
  const _UserFooter({required this.kind, required this.user});

  final PortalKind kind;
  final User? user;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Row(
          children: [
            AppAvatar(user: user, size: 38),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    user?.fullName ?? '',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 1),
                  Text(
                    user?.email ?? '',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 10,
                      color: AppColors.muted,
                    ),
                  ),
                ],
              ),
            ),
            IconButton(
              tooltip: 'Se déconnecter',
              onPressed: () => context.read<AppState>().logout(),
              icon: const Icon(
                Icons.logout_rounded,
                size: 18,
                color: AppColors.muted,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
          decoration: BoxDecoration(
            color: kind.accent.withValues(alpha: 0.07),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Text(
            'Connecté · ${kind.shortLabel}',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 9.5,
              fontWeight: FontWeight.w700,
              color: kind.accent,
            ),
          ),
        ),
      ],
    );
  }
}
