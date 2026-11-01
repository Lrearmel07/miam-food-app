import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/api_client.dart';
import '../../core/app_state.dart';
import '../../core/format.dart';
import '../../core/theme.dart';
import '../../models/user.dart';
import '../../widgets/common.dart';

const List<String> _roles = ['all', 'client', 'courier', 'partner', 'admin'];

class AdminUsersScreen extends StatefulWidget {
  const AdminUsersScreen({super.key});

  @override
  State<AdminUsersScreen> createState() => _AdminUsersScreenState();
}

class _AdminUsersScreenState extends State<AdminUsersScreen> {
  Future<List<User>>? _future;
  final _search = TextEditingController();
  final Set<int> _busy = {};
  String _role = 'all';

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
      _future = context.read<AppState>().api.adminUsers();
    });
  }

  Future<void> _toggle(User user, bool active) async {
    final current = context.read<AppState>().user;
    if (user.id == current?.id && !active) {
      showAppSnack(
        context,
        'Vous ne pouvez pas désactiver votre propre compte.',
        error: true,
      );
      return;
    }

    setState(() => _busy.add(user.id));
    try {
      await context.read<AppState>().api.setUserActive(user.id, active);
      if (!mounted) return;
      showAppSnack(
        context,
        active
            ? '${user.fullName} peut à nouveau se connecter.'
            : '${user.fullName} a été désactivé.',
      );
      _load();
    } on ApiException catch (error) {
      if (mounted) showAppSnack(context, error.message, error: true);
    } finally {
      if (mounted) setState(() => _busy.remove(user.id));
    }
  }

  List<User> _filtered(List<User> users) {
    final query = _search.text.trim().toLowerCase();
    return users.where((user) {
      if (_role != 'all' && user.role != _role) return false;
      if (query.isEmpty) return true;
      return user.fullName.toLowerCase().contains(query) ||
          user.email.toLowerCase().contains(query);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      bottom: false,
      child: FutureBuilder<List<User>>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const LoadingView(label: 'Chargement des utilisateurs...');
          }
          if (snapshot.hasError) {
            final error = snapshot.error;
            return ErrorState(
              message: error is ApiException
                  ? error.message
                  : 'Impossible de charger les utilisateurs.',
              onRetry: _load,
            );
          }

          final all = snapshot.data ?? [];
          final users = _filtered(all);
          final active = all.where((user) => user.isActive).length;

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
                                'Utilisateurs',
                                style: Theme.of(
                                  context,
                                ).textTheme.headlineSmall,
                              ),
                              const SizedBox(height: 2),
                              Text(
                                '$active comptes actifs sur ${all.length}',
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
                        hintText: 'Nom ou email...',
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
                        children: _roles
                            .map(
                              (role) => Padding(
                                padding: const EdgeInsets.only(right: 8),
                                child: ChoiceChip(
                                  label: Text(
                                    role == 'all' ? 'Tous' : roleLabel(role),
                                  ),
                                  selected: _role == role,
                                  onSelected: (_) =>
                                      setState(() => _role = role),
                                  showCheckmark: false,
                                  labelStyle: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700,
                                    color: _role == role
                                        ? Colors.white
                                        : AppColors.muted,
                                  ),
                                  selectedColor: AppColors.ink,
                                  backgroundColor: Colors.white,
                                  side: BorderSide(
                                    color: _role == role
                                        ? AppColors.ink
                                        : AppColors.line,
                                  ),
                                ),
                              ),
                            )
                            .toList(),
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: users.isEmpty
                    ? const EmptyState(
                        icon: Icons.people_outline_rounded,
                        title: 'Aucun utilisateur',
                        message:
                            'Aucun compte ne correspond à cette recherche.',
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
                          itemCount: users.length,
                          separatorBuilder: (_, _) => const SizedBox(height: 8),
                          itemBuilder: (context, index) {
                            final user = users[index];
                            return _UserCard(
                              user: user,
                              busy: _busy.contains(user.id),
                              onChanged: (value) => _toggle(user, value),
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

class _UserCard extends StatelessWidget {
  const _UserCard({
    required this.user,
    required this.busy,
    required this.onChanged,
  });

  final User user;
  final bool busy;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return SoftCard(
      padding: const EdgeInsets.fromLTRB(14, 12, 8, 12),
      child: Row(
        children: [
          AppAvatar(user: user, size: 44),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  user.fullName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 14.5,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 1),
                Text(
                  user.email,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    RoleBadge(role: user.role),
                    if (!user.isActive) ...[
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 7,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.danger.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: const Text(
                          'Désactivé',
                          style: TextStyle(
                            color: AppColors.danger,
                            fontSize: 9.5,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 4),
          if (busy)
            const Padding(
              padding: EdgeInsets.all(14),
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2.2),
              ),
            )
          else
            Column(
              children: [
                Switch.adaptive(
                  value: user.isActive,
                  activeTrackColor: AppColors.primary,
                  onChanged: onChanged,
                ),
                Text(
                  user.isActive ? 'Actif' : 'Inactif',
                  style: TextStyle(
                    fontSize: 9,
                    fontWeight: FontWeight.w700,
                    color: user.isActive ? AppColors.success : AppColors.danger,
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }
}
