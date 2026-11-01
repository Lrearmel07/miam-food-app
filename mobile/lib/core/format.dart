import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

const List<String> _months = [
  'janv.',
  'févr.',
  'mars',
  'avr.',
  'mai',
  'juin',
  'juil.',
  'août',
  'sept.',
  'oct.',
  'nov.',
  'déc.',
];

final NumberFormat _fcfaFormat = NumberFormat.decimalPattern('fr_FR');

String money(num value) => '${_fcfaFormat.format(value.round())} FCFA';

DateTime? parseApiDate(Object? value) {
  if (value is! String) return null;
  final raw = value.trim();
  if (raw.isEmpty) return null;
  final parsed = DateTime.tryParse(raw);
  if (parsed == null) return null;
  if (parsed.isUtc) return parsed;
  return DateTime.utc(
    parsed.year,
    parsed.month,
    parsed.day,
    parsed.hour,
    parsed.minute,
    parsed.second,
    parsed.millisecond,
    parsed.microsecond,
  );
}

String _two(int value) => value.toString().padLeft(2, '0');

String formatDateTime(DateTime date) {
  final local = date.toLocal();
  return '${local.day} ${_months[local.month - 1]} • ${_two(local.hour)}:${_two(local.minute)}';
}

String timeAgo(DateTime date) {
  final diff = DateTime.now().difference(date.toLocal());
  if (diff.inMinutes < 1) return "à l'instant";
  if (diff.inMinutes < 60) return 'il y a ${diff.inMinutes} min';
  if (diff.inHours < 24) return 'il y a ${diff.inHours} h';
  if (diff.inDays == 1) return 'hier';
  return 'il y a ${diff.inDays} j';
}

String statusLabel(String status) => switch (status) {
  'pending' => 'En attente',
  'accepted' => 'Acceptée',
  'preparing' => 'En préparation',
  'ready' => 'Prête',
  'shipping' => 'En livraison',
  'delivered' => 'Livrée',
  'cancelled' => 'Annulée',
  _ => status,
};

String statusHint(String status) => switch (status) {
  'pending' => "Le restaurant n'a pas encore répondu.",
  'accepted' => 'Le restaurant a accepté votre commande.',
  'preparing' => 'Votre repas est en cours de préparation.',
  'ready' => 'La commande attend un livreur.',
  'shipping' => 'Votre livreur est en route.',
  'delivered' => 'Bon appétit !',
  'cancelled' => 'Cette commande a été annulée.',
  _ => '',
};

IconData statusIcon(String status) => switch (status) {
  'pending' => Icons.schedule_rounded,
  'accepted' => Icons.check_circle_outline_rounded,
  'preparing' => Icons.soup_kitchen_rounded,
  'ready' => Icons.shopping_bag_rounded,
  'shipping' => Icons.delivery_dining_rounded,
  'delivered' => Icons.done_all_rounded,
  'cancelled' => Icons.cancel_outlined,
  _ => Icons.info_outline_rounded,
};

Color statusColor(String status) => switch (status) {
  'pending' => const Color(0xFFF59E0B),
  'accepted' => const Color(0xFF3B82F6),
  'preparing' => const Color(0xFF8B5CF6),
  'ready' => const Color(0xFF14B8A6),
  'shipping' => const Color(0xFFF97316),
  'delivered' => const Color(0xFF22C55E),
  'cancelled' => const Color(0xFFEF4444),
  _ => const Color(0xFF6B7280),
};

bool isActiveOrder(String status) =>
    !['delivered', 'cancelled'].contains(status);

bool canCancelOrder(String status) =>
    ['pending', 'accepted', 'preparing'].contains(status);

String roleLabel(String role) => switch (role) {
  'client' => 'Client',
  'courier' => 'Livreur',
  'partner' => 'Partenaire',
  'admin' => 'Administrateur',
  _ => role,
};

IconData roleIcon(String role) => switch (role) {
  'client' => Icons.person_rounded,
  'courier' => Icons.delivery_dining_rounded,
  'partner' => Icons.storefront_rounded,
  'admin' => Icons.shield_rounded,
  _ => Icons.person_rounded,
};

Color colorFromHex(String? hex, {Color fallback = const Color(0xFFFF6B35)}) {
  if (hex == null || hex.isEmpty) return fallback;
  final cleaned = hex.replaceAll('#', '').trim();
  if (cleaned.length != 6) return fallback;
  final value = int.tryParse(cleaned, radix: 16);
  if (value == null) return fallback;
  return Color(0xFF000000 | value);
}

String initialsOf(String name) {
  final parts = name.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty);
  if (parts.isEmpty) return '?';
  if (parts.length == 1) return parts.first.substring(0, 1).toUpperCase();
  return '${parts.first[0]}${parts.last[0]}'.toUpperCase();
}
