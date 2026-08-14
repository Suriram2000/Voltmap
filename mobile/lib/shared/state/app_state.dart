import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/charging_receipt.dart';
import '../models/charger_submission.dart';
import '../models/saved_trip.dart';

final appStateProvider = ChangeNotifierProvider<AppState>((ref) {
  final state = AppState();
  state.load();
  return state;
});

class AppState extends ChangeNotifier {
  static const adminIdentifier = 'skotla100@gmail.com';
  static const contactEmail = 'skotla100@gmail.com';
  static const contactPhone = '+919392788714';

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
  static const _accountCreatedAtKey = 'voltmap_account_created_at';
  static const _accountLastSignInKey = 'voltmap_account_last_sign_in';
  static const _phoneVerifiedKey = 'voltmap_phone_verified';
  static const _chargerSubmissionsKey = 'voltmap_charger_submissions';

  SharedPreferences? _preferences;

  bool isReady = false;
  bool isSignedIn = false;
  bool hasLocalAccount = false;
  bool darkMode = false;
  bool notificationsEnabled = true;
  String userName = 'VoltMapEV Driver';
  String userIdentifier = 'driver@example.com';
  String vehicleName = 'Tata Nexon EV';
  double vehicleRangeKm = 325;
  final Set<String> favoriteStationIds = {};
  int _favoritesRevision = 0;
  final List<SavedTrip> savedTrips = [];
  final List<ChargingReceipt> chargingReceipts = [];
  final List<ChargerSubmission> chargerSubmissions = [];

  bool get isDemoAccount =>
      isSignedIn &&
      !hasLocalAccount &&
      const {'demo@voltmap.in', 'demo@voltmapev.com'}
          .contains(userIdentifier.toLowerCase());

  bool get isRegisteredAccount =>
      isSignedIn && hasLocalAccount && !isDemoAccount;

  bool get isAdminAccount =>
      isRegisteredAccount && userIdentifier.toLowerCase() == adminIdentifier;

  int get favoritesRevision => _favoritesRevision;

  List<LocalAccountSummary> get localAccountSummaries => hasLocalAccount
      ? [
          LocalAccountSummary(
            name: userName,
            identifier: userIdentifier,
            createdAt: _dateFromPreference(_accountCreatedAtKey),
            lastSignInAt: _dateFromPreference(_accountLastSignInKey),
          ),
        ]
      : const [];

  Future<void> load() async {
    try {
      _preferences = await SharedPreferences.getInstance();
      final preferences = _preferences!;
      favoriteStationIds
        ..clear()
        ..addAll(preferences.getStringList(_favoritesKey) ?? const []);
      _favoritesRevision++;
      darkMode = preferences.getBool(_darkModeKey) ?? false;
      notificationsEnabled = preferences.getBool(_notificationsKey) ?? true;
      userName = preferences.getString(_nameKey) ?? userName;
      userIdentifier = preferences.getString(_emailKey) ?? userIdentifier;
      vehicleName = preferences.getString(_vehicleKey) ?? vehicleName;
      vehicleRangeKm = preferences.getDouble(_rangeKey) ?? vehicleRangeKm;
      isSignedIn = preferences.getBool(_signedInKey) ?? false;
      hasLocalAccount = preferences.containsKey(_accountPasswordHashKey) ||
          (preferences.getBool(_phoneVerifiedKey) ?? false);

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

      final submissionJson = preferences.getString(_chargerSubmissionsKey);
      if (submissionJson != null) {
        final decoded = jsonDecode(submissionJson) as List<dynamic>;
        chargerSubmissions
          ..clear()
          ..addAll(
            decoded.map(
              (item) => ChargerSubmission.fromJson(
                item as Map<String, dynamic>,
              ),
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
    required String identifier,
    required String password,
  }) async {
    final normalizedIdentifier = normalizeAccountIdentifier(identifier);
    if (_preferences == null) {
      return 'Browser storage is unavailable. Please enable it and try again.';
    }
    if (normalizedIdentifier == null) {
      return 'Enter a valid email address or phone number.';
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
    final now = DateTime.now().toIso8601String();

    userName = name.trim();
    userIdentifier = normalizedIdentifier;
    hasLocalAccount = true;
    isSignedIn = true;
    await Future.wait([
      _preferences!.setString(_nameKey, userName),
      _preferences!.setString(_emailKey, userIdentifier),
      _preferences!.setString(_accountSaltKey, salt),
      _preferences!.setString(_accountPasswordHashKey, digest),
      _preferences!.setString(_accountCreatedAtKey, now),
      _preferences!.setString(_accountLastSignInKey, now),
      _preferences!.setBool(_signedInKey, true),
    ]);
    notifyListeners();
    return null;
  }

  Future<String?> signIn({
    required String identifier,
    required String password,
  }) async {
    final normalizedIdentifier = normalizeAccountIdentifier(identifier);
    if (_preferences == null) {
      return 'Browser storage is unavailable. Please enable it and try again.';
    }

    final salt = _preferences!.getString(_accountSaltKey);
    final savedDigest = _preferences!.getString(_accountPasswordHashKey);
    final isValid = hasLocalAccount &&
        normalizedIdentifier != null &&
        normalizedIdentifier == userIdentifier.toLowerCase() &&
        salt != null &&
        savedDigest != null &&
        _passwordDigest(password, salt) == savedDigest;
    if (!isValid) return 'Email/phone or password is incorrect.';

    isSignedIn = true;
    await Future.wait([
      _preferences!.setBool(_signedInKey, true),
      _preferences!.setString(
        _accountLastSignInKey,
        DateTime.now().toIso8601String(),
      ),
    ]);
    notifyListeners();
    return null;
  }

  Future<void> enterDemoAccount() async {
    userName = 'VoltMapEV Demo Driver';
    userIdentifier = 'demo@voltmapev.com';
    isSignedIn = true;
    final preferences = _preferences;
    if (preferences != null) {
      await Future.wait([
        preferences.setString(_nameKey, userName),
        preferences.setString(_emailKey, userIdentifier),
        preferences.setBool(_signedInKey, true),
      ]);
    }
    notifyListeners();
  }

  Future<String?> completePhoneVerification(String phoneNumber) async {
    final normalizedPhone = normalizeIndianMobile(phoneNumber);
    if (_preferences == null) {
      return 'Browser storage is unavailable. Please enable it and try again.';
    }
    if (normalizedPhone == null) {
      return 'Enter a valid India mobile number.';
    }

    final now = DateTime.now().toIso8601String();
    userName = 'VoltMapEV Driver';
    userIdentifier = normalizedPhone;
    hasLocalAccount = true;
    isSignedIn = true;
    await Future.wait([
      _preferences!.setString(_nameKey, userName),
      _preferences!.setString(_emailKey, userIdentifier),
      _preferences!.setBool(_phoneVerifiedKey, true),
      _preferences!.setBool(_signedInKey, true),
      if (!_preferences!.containsKey(_accountCreatedAtKey))
        _preferences!.setString(_accountCreatedAtKey, now),
      _preferences!.setString(_accountLastSignInKey, now),
    ]);
    notifyListeners();
    return null;
  }

  Future<void> signOut() async {
    isSignedIn = false;
    await _preferences?.setBool(_signedInKey, false);
    notifyListeners();
  }

  Future<void> deleteLocalAccountAndData() async {
    const personalDataKeys = [
      _favoritesKey,
      _tripsKey,
      _receiptsKey,
      _darkModeKey,
      _notificationsKey,
      _nameKey,
      _emailKey,
      _vehicleKey,
      _rangeKey,
      _signedInKey,
      _accountSaltKey,
      _accountPasswordHashKey,
      _accountCreatedAtKey,
      _accountLastSignInKey,
      _phoneVerifiedKey,
      _chargerSubmissionsKey,
    ];
    final preferences = _preferences;
    if (preferences != null) {
      await Future.wait(personalDataKeys.map(preferences.remove));
    }

    isSignedIn = false;
    hasLocalAccount = false;
    darkMode = false;
    notificationsEnabled = true;
    userName = 'VoltMapEV Driver';
    userIdentifier = 'driver@example.com';
    vehicleName = 'Tata Nexon EV';
    vehicleRangeKm = 325;
    favoriteStationIds.clear();
    _favoritesRevision++;
    savedTrips.clear();
    chargingReceipts.clear();
    chargerSubmissions.clear();
    notifyListeners();
  }

  Future<void> toggleFavorite(String stationId) async {
    if (!favoriteStationIds.add(stationId)) {
      favoriteStationIds.remove(stationId);
    }
    _favoritesRevision++;
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

  Future<void> saveChargerSubmission(ChargerSubmission submission) async {
    chargerSubmissions.removeWhere((saved) => saved.id == submission.id);
    chargerSubmissions.insert(0, submission);
    if (chargerSubmissions.length > 20) {
      chargerSubmissions.removeRange(20, chargerSubmissions.length);
    }
    notifyListeners();
    final encoded = jsonEncode(
      chargerSubmissions.map((item) => item.toJson()).toList(growable: false),
    );
    await _preferences?.setString(_chargerSubmissionsKey, encoded);
  }

  Future<void> updateProfile({
    required String name,
    required String identifier,
  }) async {
    final normalizedIdentifier = normalizeAccountIdentifier(identifier);
    if (normalizedIdentifier == null) return;
    userName = name.trim();
    userIdentifier = normalizedIdentifier;
    notifyListeners();
    await _preferences?.setString(_nameKey, userName);
    await _preferences?.setString(_emailKey, userIdentifier);
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

  DateTime? _dateFromPreference(String key) {
    final value = _preferences?.getString(key);
    return value == null ? null : DateTime.tryParse(value);
  }

  static String? normalizeAccountIdentifier(String input) {
    final value = input.trim();
    if (RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(value)) {
      return value.toLowerCase();
    }

    var digits = value.replaceAll(RegExp(r'[^0-9]'), '');
    if (digits.length == 11 && digits.startsWith('0')) {
      digits = digits.substring(1);
    }
    if (digits.length == 10 && RegExp(r'^[6-9]').hasMatch(digits)) {
      return '+91$digits';
    }
    if (digits.length == 12 && digits.startsWith('91')) {
      return '+$digits';
    }
    if (value.startsWith('+') && digits.length >= 10 && digits.length <= 15) {
      return '+$digits';
    }
    return null;
  }

  static String? normalizeIndianMobile(String input) {
    var digits = input.replaceAll(RegExp(r'[^0-9]'), '');
    if (digits.length == 12 && digits.startsWith('91')) {
      digits = digits.substring(2);
    }
    if (digits.length == 11 && digits.startsWith('0')) {
      digits = digits.substring(1);
    }
    return digits.length == 10 && RegExp(r'^[6-9]').hasMatch(digits)
        ? '+91$digits'
        : null;
  }
}

class LocalAccountSummary {
  const LocalAccountSummary({
    required this.name,
    required this.identifier,
    required this.createdAt,
    required this.lastSignInAt,
  });

  final String name;
  final String identifier;
  final DateTime? createdAt;
  final DateTime? lastSignInAt;
}
