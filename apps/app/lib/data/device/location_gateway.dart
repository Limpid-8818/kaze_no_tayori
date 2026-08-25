/// 定位插件的窄接口，避免 feature 与 geolocator 类型耦合。
library;

import 'package:geolocator/geolocator.dart';

class GeoCoordinate {
  const GeoCoordinate({
    required this.latitude,
    required this.longitude,
    required this.accuracyM,
    required this.measuredAt,
  });

  final double latitude;
  final double longitude;
  final double accuracyM;
  final DateTime measuredAt;
}

abstract interface class LocationGateway {
  Future<bool> isServiceEnabled();

  Future<GeoCoordinate> current();
}

class GeolocatorLocationGateway implements LocationGateway {
  const GeolocatorLocationGateway();

  @override
  Future<bool> isServiceEnabled() => Geolocator.isLocationServiceEnabled();

  @override
  Future<GeoCoordinate> current() async {
    final position = await Geolocator.getCurrentPosition(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.medium,
        timeLimit: Duration(seconds: 10),
      ),
    );
    return GeoCoordinate(
      latitude: position.latitude,
      longitude: position.longitude,
      accuracyM: position.accuracy,
      measuredAt: position.timestamp,
    );
  }
}
