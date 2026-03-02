import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../utils/constants.dart';

class LicenseService {
  static final LicenseService _instance = LicenseService._internal();
  factory LicenseService() => _instance;
  LicenseService._internal();

  // ─── Validate License ────────────────────────────────────

  Future<LicenseResult> validateLicense(String key) async {
    final prefs = await SharedPreferences.getInstance();

    try {
      final uri = Uri.parse(
        '${AppConstants.licenseScriptUrl}?action=validate&key=${Uri.encodeComponent(key)}',
      );
      final response = await http.get(uri).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);

        if (data['status'] == 'active') {
          // Save license key locally
          await prefs.setString(AppConstants.savedLicenseKey, key);
          await prefs.setBool(AppConstants.licenseValidated, true);
          await prefs.setString(AppConstants.prefStoreKey, key);
          return LicenseResult(success: true, message: data['business'] ?? 'Activated');
        } else if (data['status'] == 'revoked') {
          // Clear saved license
          await prefs.remove(AppConstants.savedLicenseKey);
          await prefs.remove(AppConstants.licenseValidated);
          await prefs.remove(AppConstants.prefStoreKey);
          return LicenseResult(success: false, message: 'License has been revoked. Contact support.');
        } else {
          return LicenseResult(success: false, message: 'Invalid license key. Please check and try again.');
        }
      } else {
        return _failOpen(prefs, key);
      }
    } catch (e) {
      // No internet — fail open to protect paying customers
      return _failOpen(prefs, key);
    }
  }

  // ─── Check on App Open ───────────────────────────────────

  Future<LicenseStatus> checkOnAppOpen() async {
    final prefs = await SharedPreferences.getInstance();
    final savedKey = prefs.getString(AppConstants.savedLicenseKey);

    // No key saved — show activation screen
    if (savedKey == null || savedKey.isEmpty) {
      return LicenseStatus.notActivated;
    }

    try {
      final uri = Uri.parse(
        '${AppConstants.licenseScriptUrl}?action=validate&key=${Uri.encodeComponent(savedKey)}',
      );
      final response = await http.get(uri).timeout(const Duration(seconds: 8));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);

        if (data['status'] == 'active') {
          return LicenseStatus.active;
        } else if (data['status'] == 'revoked') {
          // Clear everything
          await prefs.clear();
          return LicenseStatus.revoked;
        } else {
          return LicenseStatus.invalid;
        }
      } else {
        // Server error — fail open
        return LicenseStatus.active;
      }
    } catch (e) {
      // No internet — fail open
      return LicenseStatus.active;
    }
  }

  // ─── Check for Update ────────────────────────────────────

  Future<UpdateResult?> checkForUpdate(String currentVersion) async {
    try {
      final uri = Uri.parse(
        '${AppConstants.licenseScriptUrl}?action=checkUpdate&version=$currentVersion',
      );
      final response = await http.get(uri).timeout(const Duration(seconds: 8));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['updateAvailable'] == true) {
          return UpdateResult(
            version: data['version'] ?? '',
            apkUrl: data['apkUrl'] ?? '',
            message: data['message'] ?? 'A new update is available.',
          );
        }
      }
      return null;
    } catch (e) {
      return null; // silently fail
    }
  }

  // ─── Helpers ─────────────────────────────────────────────

  Future<LicenseResult> _failOpen(SharedPreferences prefs, String key) async {
    final savedKey = prefs.getString(AppConstants.savedLicenseKey);
    if (savedKey != null && savedKey.isNotEmpty) {
      // Already activated before — let them in
      return LicenseResult(success: true, message: 'Activated (offline mode)');
    }
    return LicenseResult(
      success: false,
      message: 'No internet connection. Please try again.',
    );
  }

  Future<void> clearLicense() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(AppConstants.savedLicenseKey);
    await prefs.remove(AppConstants.licenseValidated);
    await prefs.remove(AppConstants.prefStoreKey);
  }

  Future<String?> getSavedKey() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(AppConstants.savedLicenseKey);
  }
}

// ─── Result Classes ───────────────────────────────────────

class LicenseResult {
  final bool success;
  final String message;
  LicenseResult({required this.success, required this.message});
}

class UpdateResult {
  final String version;
  final String apkUrl;
  final String message;
  UpdateResult({
    required this.version,
    required this.apkUrl,
    required this.message,
  });
}

enum LicenseStatus { active, notActivated, revoked, invalid }