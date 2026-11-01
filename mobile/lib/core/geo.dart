import 'dart:math' as math;

double distanceKmBetween(
  double startLatitude,
  double startLongitude,
  double endLatitude,
  double endLongitude,
) {
  const radius = 6371.0;
  final lat1 = startLatitude * math.pi / 180;
  final lat2 = endLatitude * math.pi / 180;
  final deltaLat = (endLatitude - startLatitude) * math.pi / 180;
  final deltaLng = (endLongitude - startLongitude) * math.pi / 180;
  final value =
      math.sin(deltaLat / 2) * math.sin(deltaLat / 2) +
      math.cos(lat1) *
          math.cos(lat2) *
          math.sin(deltaLng / 2) *
          math.sin(deltaLng / 2);
  return radius * 2 * math.asin(math.sqrt(value));
}

String formatDistance(double kilometers) {
  if (kilometers < 1) {
    return '${(kilometers * 1000).round()} m';
  }
  return '${kilometers.toStringAsFixed(1).replaceAll('.', ',')} km';
}
