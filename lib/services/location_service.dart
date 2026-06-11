// services/location_service.dart
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import 'firestore_service.dart';

/// Types of location errors for showing appropriate UI dialogs.
enum LocationErrorType { none, serviceDisabled, permissionDenied, permissionDeniedForever, fetchFailed }

/// Result of a location update attempt with detailed status.
class LocationResult {
  final bool success;
  final String message;
  final String? label;
  final LocationErrorType errorType;

  const LocationResult({
    required this.success,
    required this.message,
    this.label,
    this.errorType = LocationErrorType.none,
  });
}

class LocationService {
  final FirestoreService _db;

  LocationService(this._db);

  /// Check and request location permissions with detailed status reporting.
  Future<LocationResult> _checkPermissions() async {
    bool serviceEnabled;
    try {
      serviceEnabled = await Geolocator.isLocationServiceEnabled();
    } catch (e) {
      debugPrint('[LocationService] Error checking location service: $e');
      return const LocationResult(
        success: false,
        message: 'Could not check location services.',
        errorType: LocationErrorType.serviceDisabled,
      );
    }

    if (!serviceEnabled) {
      return const LocationResult(
        success: false,
        message: 'Location services are turned off.\nPlease enable GPS to share your location.',
        errorType: LocationErrorType.serviceDisabled,
      );
    }

    LocationPermission permission;
    try {
      permission = await Geolocator.checkPermission();
    } catch (e) {
      debugPrint('[LocationService] Error checking permission: $e');
      return const LocationResult(
        success: false,
        message: 'Could not check location permission.',
        errorType: LocationErrorType.permissionDenied,
      );
    }

    if (permission == LocationPermission.denied) {
      try {
        permission = await Geolocator.requestPermission();
      } catch (e) {
        debugPrint('[LocationService] Error requesting permission: $e');
        return const LocationResult(
          success: false,
          message: 'Could not request location permission.',
          errorType: LocationErrorType.permissionDenied,
        );
      }
      if (permission == LocationPermission.denied) {
        return const LocationResult(
          success: false,
          message: 'Location permission was denied.\nPlease allow location access to share with your family.',
          errorType: LocationErrorType.permissionDenied,
        );
      }
    }

    if (permission == LocationPermission.deniedForever) {
      return const LocationResult(
        success: false,
        message: 'Location permission is permanently denied.\nPlease enable it in your device Settings.',
        errorType: LocationErrorType.permissionDeniedForever,
      );
    }

    return const LocationResult(success: true, message: 'OK');
  }

  /// Get a human-readable address from coordinates via reverse geocoding.
  Future<String> _reverseGeocode(double lat, double lng) async {
    try {
      final placemarks = await placemarkFromCoordinates(lat, lng);
      if (placemarks.isNotEmpty) {
        final p = placemarks.first;
        final parts = <String>[];
        if (p.street != null && p.street!.isNotEmpty) parts.add(p.street!);
        if (p.locality != null && p.locality!.isNotEmpty) parts.add(p.locality!);
        if (p.administrativeArea != null && p.administrativeArea!.isNotEmpty && parts.length < 2) {
          parts.add(p.administrativeArea!);
        }
        if (parts.isNotEmpty) return parts.join(', ');
      }
    } catch (e) {
      debugPrint('[LocationService] Geocoding failed: $e');
    }
    return 'Lat: ${lat.toStringAsFixed(4)}, Lng: ${lng.toStringAsFixed(4)}';
  }

  /// Convert longitude to OSM tile X coordinate.
  static int lngToTileX(double lng, int zoom) =>
      ((lng + 180) / 360 * pow(2, zoom)).floor();

  /// Convert latitude to OSM tile Y coordinate.
  static int latToTileY(double lat, int zoom) {
    final latRad = lat * pi / 180;
    return ((1 - log(tan(latRad) + 1 / cos(latRad)) / pi) / 2 * pow(2, zoom)).floor();
  }

  /// Get the OpenStreetMap tile URL for given coordinates.
  static String getMapTileUrl(double lat, double lng, {int zoom = 15, int dx = 0, int dy = 0}) {
    final x = lngToTileX(lng, zoom) + dx;
    final y = latToTileY(lat, zoom) + dy;
    return 'https://tile.openstreetmap.org/$zoom/$x/$y.png';
  }

  /// Open device location settings (GPS toggle).
  static Future<void> openLocationSettings() async {
    await Geolocator.openLocationSettings();
  }

  /// Open app-level permission settings.
  static Future<void> openAppSettings() async {
    await Geolocator.openAppSettings();
  }

  /// Fetch current device position, reverse-geocode it, and push to Firestore.
  Future<LocationResult> updateCurrentLocation(String uid, {bool sharing = true}) async {
    final permResult = await _checkPermissions();
    if (!permResult.success) return permResult;

    Position position;
    try {
      debugPrint('[LocationService] Fetching GPS position...');
      position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 15),
        ),
      );
      debugPrint('[LocationService] Got position: ${position.latitude}, ${position.longitude}');
    } catch (e) {
      debugPrint('[LocationService] getCurrentPosition error: $e');
      try {
        debugPrint('[LocationService] Retrying with low accuracy...');
        position = await Geolocator.getCurrentPosition(
          locationSettings: const LocationSettings(
            accuracy: LocationAccuracy.low,
            timeLimit: Duration(seconds: 10),
          ),
        );
      } catch (e2) {
        debugPrint('[LocationService] Fallback also failed: $e2');
        return const LocationResult(
          success: false,
          message: 'Could not get GPS position.\nMake sure GPS is enabled and try again.',
          errorType: LocationErrorType.fetchFailed,
        );
      }
    }

    final label = await _reverseGeocode(position.latitude, position.longitude);
    debugPrint('[LocationService] Geocoded label: $label');

    try {
      await _db.updateLocation(
        uid: uid,
        lat: position.latitude,
        lng: position.longitude,
        label: label,
        sharing: sharing,
      );
    } catch (e) {
      debugPrint('[LocationService] Firestore update error: $e');
      return LocationResult(
        success: false,
        message: 'Got location but failed to save. Please try again.',
        label: label,
        errorType: LocationErrorType.fetchFailed,
      );
    }

    return LocationResult(success: true, message: 'Location updated.', label: label);
  }
}
