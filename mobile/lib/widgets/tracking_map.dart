import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../core/theme.dart';
import '../models/order_tracking.dart';

const bool _tilesDisabled = bool.fromEnvironment('MIAM_DISABLE_MAP_TILES');

class TrackingMap extends StatelessWidget {
  const TrackingMap({
    super.key,
    required this.tracking,
    this.height = 320,
    this.followCourier = false,
  });

  final OrderTracking tracking;
  final double height;
  final bool followCourier;

  List<LatLng> get _route {
    final points = <LatLng>[
      LatLng(tracking.restaurant.latitude, tracking.restaurant.longitude),
    ];
    final courier = tracking.courier;
    if (courier != null && courier.hasLocation) {
      points.add(LatLng(courier.latitude!, courier.longitude!));
    }
    points.add(LatLng(tracking.delivery.latitude, tracking.delivery.longitude));
    return points;
  }

  @override
  Widget build(BuildContext context) {
    final route = _route;
    final courier = tracking.courier;
    final bounds = LatLngBounds.fromPoints(route);

    return SizedBox(
      height: height,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: Stack(
          children: [
            FlutterMap(
              key: ValueKey(tracking.orderId),
              options: MapOptions(
                initialCameraFit: CameraFit.bounds(
                  bounds: bounds,
                  padding: const EdgeInsets.all(52),
                ),
                minZoom: 3,
                maxZoom: 18,
                backgroundColor: const Color(0xFFE8EEE7),
              ),
              children: [
                if (!_tilesDisabled)
                  TileLayer(
                    urlTemplate:
                        'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                    userAgentPackageName: 'com.miamapp.miam',
                  ),
                PolylineLayer(
                  polylines: [
                    Polyline(
                      points: route,
                      strokeWidth: 8,
                      color: Colors.white,
                      borderStrokeWidth: 0,
                    ),
                    Polyline(
                      points: route,
                      strokeWidth: 4.5,
                      color: AppColors.primary,
                      pattern: StrokePattern.dashed(segments: const [10, 7]),
                    ),
                  ],
                ),
                MarkerLayer(
                  markers: [
                    Marker(
                      point: LatLng(
                        tracking.restaurant.latitude,
                        tracking.restaurant.longitude,
                      ),
                      width: 46,
                      height: 46,
                      alignment: Alignment.center,
                      child: const _MapPin(
                        icon: Icons.restaurant_rounded,
                        color: AppColors.primary,
                        label: 'Restaurant',
                      ),
                    ),
                    Marker(
                      point: LatLng(
                        tracking.delivery.latitude,
                        tracking.delivery.longitude,
                      ),
                      width: 46,
                      height: 46,
                      alignment: Alignment.center,
                      child: const _MapPin(
                        icon: Icons.home_rounded,
                        color: AppColors.blue,
                        label: 'Client',
                      ),
                    ),
                    if (courier != null && courier.hasLocation)
                      Marker(
                        point: LatLng(courier.latitude!, courier.longitude!),
                        width: 52,
                        height: 52,
                        alignment: Alignment.center,
                        child: _MapPin(
                          icon: Icons.delivery_dining_rounded,
                          color: tracking.isDelivered
                              ? AppColors.teal
                              : AppColors.ink,
                          label: courier.fullName,
                          emphasis: true,
                        ),
                      ),
                  ],
                ),
                const _MapAttribution(),
              ],
            ),
            Positioned(
              left: 14,
              bottom: 14,
              child: _MapLegend(
                courierName: courier?.fullName,
                followCourier: followCourier,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MapPin extends StatelessWidget {
  const _MapPin({
    required this.icon,
    required this.color,
    required this.label,
    this.emphasis = false,
  });

  final IconData icon;
  final Color color;
  final String label;
  final bool emphasis;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: label,
      child: Container(
        width: emphasis ? 46 : 40,
        height: emphasis ? 46 : 40,
        decoration: BoxDecoration(
          color: color,
          shape: BoxShape.circle,
          border: Border.all(color: Colors.white, width: 3),
          boxShadow: [
            BoxShadow(
              color: color.withValues(alpha: 0.3),
              blurRadius: 12,
              offset: const Offset(0, 5),
            ),
          ],
        ),
        child: Icon(icon, color: Colors.white, size: emphasis ? 25 : 21),
      ),
    );
  }
}

class _MapLegend extends StatelessWidget {
  const _MapLegend({this.courierName, this.followCourier = false});

  final String? courierName;
  final bool followCourier;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.94),
        borderRadius: BorderRadius.circular(14),
        boxShadow: const [
          BoxShadow(
            color: Color(0x19000000),
            blurRadius: 12,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.delivery_dining_rounded,
            size: 16,
            color: AppColors.ink,
          ),
          const SizedBox(width: 6),
          Text(
            courierName == null
                ? 'Livreur en attente'
                : followCourier
                ? '$courierName • en direct'
                : courierName!,
            style: const TextStyle(
              fontSize: 11.5,
              fontWeight: FontWeight.w700,
              color: AppColors.ink,
            ),
          ),
        ],
      ),
    );
  }
}

class _MapAttribution extends StatelessWidget {
  const _MapAttribution();

  @override
  Widget build(BuildContext context) {
    return const Align(
      alignment: Alignment.bottomRight,
      child: Padding(
        padding: EdgeInsets.all(6),
        child: DecoratedBox(
          decoration: BoxDecoration(color: Color(0xCCFFFFFF)),
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: 5, vertical: 2),
            child: Text(
              '© OpenStreetMap',
              style: TextStyle(fontSize: 8.5, color: AppColors.muted),
            ),
          ),
        ),
      ),
    );
  }
}
