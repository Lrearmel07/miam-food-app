import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';

import '../../core/api_client.dart';
import '../../core/app_state.dart';
import '../../core/format.dart';
import '../../core/theme.dart';
import '../../models/order_tracking.dart';
import '../../widgets/common.dart';
import '../../widgets/tracking_map.dart';

class CourierTrackingScreen extends StatefulWidget {
  const CourierTrackingScreen({super.key, required this.orderId});

  final int orderId;

  @override
  State<CourierTrackingScreen> createState() => _CourierTrackingScreenState();
}

class _CourierTrackingScreenState extends State<CourierTrackingScreen> {
  OrderTracking? _tracking;
  String? _error;
  bool _loading = true;
  bool _requestInFlight = false;
  bool _sharingGps = false;
  bool _simulating = false;
  bool _sending = false;
  Timer? _pollTimer;
  Timer? _gpsTimer;
  Timer? _simulationTimer;
  double _simulationProgress = 0;

  @override
  void initState() {
    super.initState();
    _load();
    _pollTimer = Timer.periodic(const Duration(seconds: 5), (_) {
      _load(silent: true);
    });
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    _gpsTimer?.cancel();
    _simulationTimer?.cancel();
    super.dispose();
  }

  Future<void> _load({bool silent = false}) async {
    if (_requestInFlight) return;
    _requestInFlight = true;
    if (!silent && mounted) {
      setState(() {
        _loading = _tracking == null;
        _error = null;
      });
    }

    try {
      final tracking = await context.read<AppState>().api.orderTracking(
        widget.orderId,
      );
      if (!mounted) return;
      setState(() {
        _tracking = tracking;
        _error = null;
        _loading = false;
      });
    } on ApiException catch (error) {
      if (!mounted) return;
      setState(() {
        _error = error.message;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _error = 'Impossible de charger la position de la course.';
        _loading = false;
      });
    } finally {
      _requestInFlight = false;
    }
  }

  Future<bool> _pushPosition(double latitude, double longitude) async {
    if (_sending) return false;
    _sending = true;
    try {
      final tracking = await context.read<AppState>().api.updateCourierLocation(
        widget.orderId,
        latitude: latitude,
        longitude: longitude,
      );
      if (!mounted) return true;
      setState(() {
        _tracking = tracking;
        _error = null;
      });
      return true;
    } on ApiException catch (error) {
      if (mounted) {
        showAppSnack(context, error.message, error: true);
        _stopSharing(showMessage: false);
      }
      return false;
    } finally {
      _sending = false;
    }
  }

  Future<void> _startGps() async {
    if (_sharingGps || _sending) return;
    setState(() => _sending = true);
    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        if (mounted) {
          await _offerSimulation('Le service de localisation est désactivé.');
        }
        return;
      }

      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        if (mounted) {
          await _offerSimulation(
            'L’accès à votre position est refusé. Autorisez-le dans les réglages ou utilisez la simulation.',
          );
        }
        return;
      }

      _stopSimulation();
      if (!mounted) return;
      setState(() => _sharingGps = true);
      await _sendGpsPosition();
      if (!mounted || !_sharingGps) return;
      showAppSnack(
        context,
        'Position partagée. Le client et le restaurant vous suivent en direct.',
      );
      _gpsTimer?.cancel();
      _gpsTimer = Timer.periodic(
        const Duration(seconds: 10),
        (_) => _sendGpsPosition(),
      );
    } catch (_) {
      if (mounted) {
        await _offerSimulation(
          'La position GPS n’est pas disponible sur cet appareil.',
        );
      }
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  Future<void> _sendGpsPosition() async {
    if (!_sharingGps || _sending) return;
    try {
      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 12),
        ),
      );
      await _pushPosition(position.latitude, position.longitude);
    } catch (_) {
      if (!mounted) return;
      _stopSharing(showMessage: false);
      await _offerSimulation(
        'Impossible de récupérer votre position GPS pour le moment.',
      );
    }
  }

  void _startSimulation() {
    final tracking = _tracking;
    if (tracking == null) return;
    _stopGps();
    final start = LatLng(
      tracking.restaurant.latitude,
      tracking.restaurant.longitude,
    );
    final end = LatLng(tracking.delivery.latitude, tracking.delivery.longitude);
    final total = const Distance().as(LengthUnit.Kilometer, start, end);
    final courier = tracking.courier;
    final current = courier != null && courier.hasLocation
        ? LatLng(courier.latitude!, courier.longitude!)
        : start;
    final remaining = const Distance().as(LengthUnit.Kilometer, current, end);
    _simulationProgress = total <= 0
        ? 0
        : (1 - remaining / total).clamp(0.0, 0.95).toDouble();

    setState(() => _simulating = true);
    showAppSnack(
      context,
      'Simulation démarrée : la position avance vers le client.',
    );
    _simulationTimer?.cancel();
    _simulationTimer = Timer.periodic(const Duration(seconds: 3), (_) {
      _advanceSimulation();
    });
  }

  Future<void> _advanceSimulation() async {
    final tracking = _tracking;
    if (!_simulating || tracking == null || _sending) return;
    _simulationProgress = math.min(1.0, _simulationProgress + 0.04);
    final start = LatLng(
      tracking.restaurant.latitude,
      tracking.restaurant.longitude,
    );
    final end = LatLng(tracking.delivery.latitude, tracking.delivery.longitude);
    final position = LatLng(
      start.latitude + (end.latitude - start.latitude) * _simulationProgress,
      start.longitude + (end.longitude - start.longitude) * _simulationProgress,
    );
    await _pushPosition(position.latitude, position.longitude);
    if (_simulationProgress >= 1 && mounted) {
      _stopSimulation(showMessage: false);
      showAppSnack(
        context,
        'Position simulée arrivée à l’adresse de livraison.',
      );
    }
  }

  Future<void> _offerSimulation(String reason) async {
    if (!mounted) return;
    final simulate = await showConfirmDialog(
      context,
      title: 'Position indisponible',
      message:
          '$reason\n\nVous pouvez simuler le trajet pour la démonstration. La position du livreur avancera automatiquement sur la carte.',
      confirmLabel: 'Simuler le trajet',
    );
    if (simulate && mounted) _startSimulation();
  }

  void _stopGps() {
    _gpsTimer?.cancel();
    _gpsTimer = null;
    if (mounted && _sharingGps) setState(() => _sharingGps = false);
  }

  void _stopSimulation({bool showMessage = true}) {
    _simulationTimer?.cancel();
    _simulationTimer = null;
    final wasRunning = _simulating;
    if (mounted && _simulating) setState(() => _simulating = false);
    if (wasRunning && showMessage && mounted) {
      showAppSnack(context, 'Simulation arrêtée.');
    }
  }

  void _stopSharing({bool showMessage = true}) {
    _stopGps();
    _stopSimulation(showMessage: false);
    if (showMessage && mounted) {
      showAppSnack(context, 'Partage de position arrêté.');
    }
  }

  @override
  Widget build(BuildContext context) {
    final tracking = _tracking;
    final canTrack = tracking?.isShipping ?? false;

    return Scaffold(
      appBar: AppBar(
        title: Text('Position · course #${widget.orderId}'),
        actions: [
          IconButton(
            tooltip: 'Actualiser',
            onPressed: () => _load(),
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      body: tracking == null
          ? _loading
                ? const LoadingView(label: 'Chargement de la position...')
                : ErrorState(
                    message:
                        _error ??
                        'Impossible de charger la position de la course.',
                    onRetry: _load,
                  )
          : ListView(
              padding: const EdgeInsets.fromLTRB(18, 6, 18, 30),
              children: [
                if (_error != null) ...[
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.warning.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Text(
                      _error!,
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                ],
                TrackingMap(tracking: tracking, followCourier: true),
                const SizedBox(height: 16),
                SoftCard(
                  padding: const EdgeInsets.all(17),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            width: 44,
                            height: 44,
                            decoration: BoxDecoration(
                              color: canTrack
                                  ? AppColors.blue.withValues(alpha: 0.12)
                                  : AppColors.line,
                              borderRadius: BorderRadius.circular(14),
                            ),
                            child: Icon(
                              canTrack
                                  ? Icons.share_location_rounded
                                  : Icons.lock_outline_rounded,
                              color: canTrack
                                  ? AppColors.blue
                                  : AppColors.muted,
                              size: 23,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  canTrack
                                      ? 'Partage de position'
                                      : 'Suivi indisponible',
                                  style: Theme.of(
                                    context,
                                  ).textTheme.titleMedium,
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  canTrack
                                      ? 'Le client et le restaurant voient votre position en direct.'
                                      : 'Le partage sera disponible dès que la course sera en livraison.',
                                  style: Theme.of(context).textTheme.bodySmall,
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      if (canTrack) ...[
                        const SizedBox(height: 16),
                        Row(
                          children: [
                            Expanded(
                              child: _LiveBadge(
                                active: _sharingGps,
                                icon: Icons.gps_fixed_rounded,
                                label: _sharingGps
                                    ? 'GPS actif'
                                    : 'GPS désactivé',
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: _LiveBadge(
                                active: _simulating,
                                icon: Icons.smart_display_rounded,
                                label: _simulating
                                    ? 'Simulation active'
                                    : 'Simulation arrêtée',
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 14),
                        if (_sharingGps || _simulating) ...[
                          SizedBox(
                            width: double.infinity,
                            child: OutlinedButton.icon(
                              onPressed: _stopSharing,
                              icon: const Icon(Icons.stop_circle_outlined),
                              label: const Text('Arrêter le partage'),
                            ),
                          ),
                        ] else ...[
                          SizedBox(
                            width: double.infinity,
                            child: FilledButton.icon(
                              onPressed: _sending ? null : _startGps,
                              icon: const Icon(Icons.gps_fixed_rounded),
                              label: const Text('Partager ma position GPS'),
                            ),
                          ),
                          const SizedBox(height: 8),
                          SizedBox(
                            width: double.infinity,
                            child: OutlinedButton.icon(
                              onPressed: _startSimulation,
                              icon: const Icon(
                                Icons.play_circle_outline_rounded,
                              ),
                              label: const Text('Simuler le trajet (démo)'),
                            ),
                          ),
                        ],
                        const SizedBox(height: 12),
                        Text(
                          'Position mise à jour ${timeAgo(tracking.courier?.updatedAt ?? tracking.updatedAt)} · '
                          '${tracking.distanceRemainingKm.toStringAsFixed(1)} km restants',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ],
                    ],
                  ),
                ),
                if (canTrack) ...[
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(13),
                    decoration: BoxDecoration(
                      color: AppColors.cream,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: AppColors.line),
                    ),
                    child: const Row(
                      children: [
                        Icon(
                          Icons.info_outline_rounded,
                          size: 18,
                          color: AppColors.muted,
                        ),
                        SizedBox(width: 9),
                        Expanded(
                          child: Text(
                            'Sur simulateur, utilisez « Simuler le trajet » pour faire avancer la position.',
                            style: TextStyle(
                              fontSize: 12,
                              color: AppColors.muted,
                              height: 1.35,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
    );
  }
}

class _LiveBadge extends StatelessWidget {
  const _LiveBadge({
    required this.active,
    required this.icon,
    required this.label,
  });

  final bool active;
  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    final color = active ? AppColors.success : AppColors.muted;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.09),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: color,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
