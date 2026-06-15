import 'package:geolocator/geolocator.dart' as geo;
import 'package:latlong2/latlong.dart';

enum AppLocationPermission { denied, deniedForever, whileInUse, always }

extension AppLocationPermissionX on AppLocationPermission {
  bool get isGranted =>
      this == AppLocationPermission.whileInUse ||
      this == AppLocationPermission.always;
}

class LocationException implements Exception {
  final String message;

  const LocationException(this.message);

  @override
  String toString() => 'LocationException($message)';
}

class UserLocation {
  final LatLng coordinates;
  final double? accuracyMeters;
  final DateTime? timestamp;

  const UserLocation({
    required this.coordinates,
    this.accuracyMeters,
    this.timestamp,
  });
}

abstract class LocationService {
  Future<bool> isServiceEnabled();

  Future<AppLocationPermission> checkPermission();

  Future<AppLocationPermission> requestPermission();

  Future<UserLocation?> getCurrentLocation();
}

class GeolocatorLocationService implements LocationService {
  const GeolocatorLocationService();

  @override
  Future<bool> isServiceEnabled() => geo.Geolocator.isLocationServiceEnabled();

  @override
  Future<AppLocationPermission> checkPermission() async {
    final permission = await geo.Geolocator.checkPermission();
    return _mapPermission(permission);
  }

  @override
  Future<AppLocationPermission> requestPermission() async {
    final permission = await geo.Geolocator.requestPermission();
    return _mapPermission(permission);
  }

  @override
  Future<UserLocation?> getCurrentLocation() async {
    try {
      final position = await geo.Geolocator.getCurrentPosition(
        locationSettings: const geo.LocationSettings(
          accuracy: geo.LocationAccuracy.medium,
          distanceFilter: 75,
        ),
      );
      return UserLocation(
        coordinates: LatLng(position.latitude, position.longitude),
        accuracyMeters: position.accuracy,
        timestamp: position.timestamp,
      );
    } on geo.LocationServiceDisabledException {
      throw const LocationException(
        'Ative a localização do dispositivo para usar este recurso.',
      );
    } on geo.PermissionDeniedException {
      throw const LocationException(
        'Permita o acesso à localização para centralizar no mapa.',
      );
    } catch (_) {
      throw const LocationException(
        'Não foi possível obter sua localização agora.',
      );
    }
  }

  AppLocationPermission _mapPermission(geo.LocationPermission permission) {
    switch (permission) {
      case geo.LocationPermission.always:
        return AppLocationPermission.always;
      case geo.LocationPermission.whileInUse:
        return AppLocationPermission.whileInUse;
      case geo.LocationPermission.deniedForever:
        return AppLocationPermission.deniedForever;
      case geo.LocationPermission.denied:
      case geo.LocationPermission.unableToDetermine:
        return AppLocationPermission.denied;
    }
  }
}
