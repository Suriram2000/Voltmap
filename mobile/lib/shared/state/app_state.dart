import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/charging_receipt.dart';
import '../models/saved_trip.dart';

final appStateProvider = ChangeNotifierProvider<AppState>((ref) {
  final state = AppState();
  state.load();
  return state;
});

class AppState extends ChangeNotifier {
  static const _favoritesKey = 'voltmap_favorites';
  static const _tripsKey = 'voltmap_saved_trips';
  static const _receiptsKey = 'voltmap_charging_receipts';
  static const _darkModeKey = 'voltmap_dark_mode';
  static const _notificationsKey = 'voltmap_notifications';
  static const _nameKey = 'voltmap_profile_name';
  static const _emailKey = 'voltmap_profile_email';
  static const _vehicleKey = 'voltmap_vehicle';
  static const _rangeKey = 'voltmap_vehicle_range';
  static const _signedInKey = 'voltmap_signed_in';
  static const _accountSaltKey = 'voltmap_account_salt';
  static const _accountPasswordHashKey = 'voltmap_account_password_hash';

  SharedPreferences? _preferences;

  bool isReady = false;
  bool isSignedIn = false;
  bool hasLocalAccount = false;
  bool darkMode = false;
  bool notificationsEnabled = true;
  String userName = 'VoltMap Driver';
  String userEmail = 'driver@example.com';
  String vehicleName = 'Tata Nexon EV';
  double vehicleRangeKm = 325;
  final Set<String> favoriteStationIds = {};
  final List<SavedTrip> savedTrips = [];
  final List<ChargingReceipt> chargingReceipts = [];

  Future<void> load() async {
    try {
      _preferences = await SharedPreferences.getInstance();
      final preferences = _preferences!;
      favoriteStationIds
        ..clear()
        ..addAll(preferences.getStringList(_favoritesKey) ?? const []);
      darkMode = preferences.getBool(_darkModeKey) ?? false;
      notificationsEnabled = preferences.getBool(_notificationsKey) ?? true;
      userName = preferences.getString(_nameKey) ?? userName;
      userEmail = preferences.getString(_emailKey) ?? userEmail;
      vehicleName = preferences.getString(_vehicleKey) ?? vehicleName;
      vehicleRangeKm = preferences.getDouble(_rangeKey) ?? vehicleRangeKm;
      isSignedIn = preferences.getBool(_signedInKey) ?? false;
      hasLocalAccount = preferences.containsKey(_accountPasswordHashKey);

      final savedTripJson = preferences.getString(_tripsKey);
      if (savedTripJson != null) {
        final decoded = jsonDecode(savedTripJson) as List<dynamic>;
        savedTrips
          ..clear()
          ..addAll(
            decoded.map(
              (item) => SavedTrip.fromJson(item as Map<String, dynamic>),
            ),
          );
      }

      final receiptJson = preferences.getString(_receiptsKey);
      if (receiptJson != null) {
        final decoded = jsonDecode(receiptJson) as List<dynamic>;
        chargingReceipts
          ..clear()
          ..addAll(
            decoded.map(
              (item) => ChargingReceipt.fromJson(item as Map<String, dynamic>),
            ),
          );
      }
    } catch (_) {
      // The app stays usable with in-memory state if browser storage is blocked.
    } finally {
      isReady = true;
      notifyListeners();
    }
  }

  bool isFavorite(String stationId) => favoriteStationIds.contains(stationId);

  Future<String?> signUp({
    required String name,
    required String email,
    required String password,
  }) async {
    final normalizedEmail = email.trim().toLowerCase();
    if (_preferences == null) {
      return 'Browser storage is unavailable. Please enable it and try again.';
    }
    if (hasLocalAccount) {
      return 'A local account already exists. Sign in or reset this browser data.';
    }

    final saltBytes = List<int>.generate(
      24,
      (_) => Random.secure().nextInt(256),
    );
    final salt = base64UrlEncode(saltBytes);
    final digest = _passwordDigest(password, salt);

    userName = name.trim();
    userEmail = normalizedEmail;
    hasLocalAccount = true;
    isSignedIn = true;
    await Future.wait([
      _preferences!.setString(_nameKey, userName),
      _preferences!.setString(_emailKey, userEmail),
      _preferences!.setString(_accountSaltKey, salt),
      _preferences!.setString(_accountPasswordHashKey, digest),
      _preferences!.setBool(_signedInKey, true),
    ]);
    notifyListeners();
    return null;
  }

  Future<String?> signIn({
    required String email,
    required String password,
  }) async {
    final normalizedEmail = email.trim().toLowerCase();
    if (_preferences == null) {
      return 'Browser storage is unavailable. Please enable it and try again.';
    }

    final salt = _preferences!.getString(_accountSaltKey);
    final savedDigest = _preferences!.getString(_accountPasswordHashKey);
    final isValid = hasLocalAccount &&
        normalizedEmail == userEmail.toLowerCase() &&
        salt != null &&
        savedDigest != null &&
        _passwordDigest(password, salt) == savedDigest;
    if (!isValid) return 'Email or password is incorrect.';

    isSignedIn = true;
    await _preferences!.setBool(_signedInKey, true);
    notifyListeners();
    return null;
  }

  Future<void> enterDemoAccount() async {
    userName = 'VoltMap Demo Driver';
    userEmail = 'demo@voltmap.in';
    isSignedIn = true;
    final preferences = _preferences;
    if (preferences != null) {
      await Future.wait([
        preferences.setString(_nameKey, userName),
        preferences.setString(_emailKey, userEmail),
        preferences.setBool(_signedInKey, true),
      ]);
    }
    notifyListeners();
  }

  Future<void> signOut() async {
    isSignedIn = false;
    await _preferences?.setBool(_signedInKey, false);
    notifyListeners();
  }

  Future<void> toggleFavorite(String stationId) async {
    if (!favoriteStationIds.add(stationId)) {
      favoriteStationIds.remove(stationId);
    }
    notifyListeners();
    await _preferences?.setStringList(
      _favoritesKey,
      favoriteStationIds.toList(growable: false),
    );
  }

  Future<void> saveTrip(SavedTrip trip) async {
    savedTrips.removeWhere((saved) => saved.id == trip.id);
    savedTrips.insert(0, trip);
    notifyListeners();
    await _persistTrips();
  }

  Future<void> removeTrip(String tripId) async {
    savedTrips.removeWhere((trip) => trip.id == tripId);
    notifyListeners();
    await _persistTrips();
  }

  Future<void> saveChargingReceipt(ChargingReceipt receipt) async {
    chargingReceipts.removeWhere((saved) => saved.id == receipt.id);
    chargingReceipts.insert(0, receipt);
    if (chargingReceipts.length > 25) {
      chargingReceipts.removeRange(25, chargingReceipts.length);
    }
    notifyListeners();
    await _persistReceipts();
  }

  Future<void> updateProfile({
    required String name,
    required String email,
  }) async {
    userName = name.trim();
    userEmail = email.trim();
    notifyListeners();
    await _preferences?.setString(_nameKey, userName);
    await _preferences?.setString(_emailKey, userEmail);
  }

  Future<void> updateVehicle({
    required String name,
    required double rangeKm,
  }) async {
    vehicleName = name.trim();
    vehicleRangeKm = rangeKm;
    notifyListeners();
    await _preferences?.setString(_vehicleKey, vehicleName);
    await _preferences?.setDouble(_rangeKey, vehicleRangeKm);
  }

  Future<void> setDarkMode(bool value) async {
    darkMode = value;
    notifyListeners();
    await _preferences?.setBool(_darkModeKey, value);
  }

  Future<void> setNotificationsEnabled(bool value) async {
    notificationsEnabled = value;
    notifyListeners();
    await _preferences?.setBool(_notificationsKey, value);
  }

  Future<void> _persistTrips() async {
    final encoded = jsonEncode(
      savedTrips.map((trip) => trip.toJson()).toList(growable: false),
    );
    await _preferences?.setString(_tripsKey, encoded);
  }

  Future<void> _persistReceipts() async {
    final encoded = jsonEncode(
      chargingReceipts
          .map((receipt) => receipt.toJson())
          .toList(growable: false),
    );
    try {
      await _preferences?.setString(_receiptsKey, encoded);
    } catch (_) {
      // Keep the in-memory receipt if browser storage is unavailable.
    }
  }

  String _passwordDigest(String password, String salt) {
    return sha256.convert(utf8.encode('$salt:$password')).toString();
  }
}
