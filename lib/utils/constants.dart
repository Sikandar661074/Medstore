class AppConstants {
  // App Info
  static const String appName = 'MedStore Manager';
  static const String appVersion = '1.0.0';
  static const String developerName = 'Sikandar Ansari';
  static const String contactWhatsApp = '+917019348778';
  static const String contactEmail = 'supportpanchet@gmail.com';

  // License
  static const String licenseScriptUrl = 'https://script.google.com/macros/s/AKfycbzS5xWUQn794QS4jjfdWUnjQhpaCdqUwYZy0NuXtvRIvKgdfCjL7J6dkfC2_g83iSvYFA/exec';
  static const String savedLicenseKey = 'license_key';
  static const String licenseValidated = 'license_validated';

  // User Roles
  static const String roleOwner = 'owner';
  static const String roleStaff = 'staff';

  // Firestore Collections
  static const String colMedicines = 'medicines';
  static const String colCustomers = 'customers';
  static const String colPayments = 'payments';
  static const String colUsers = 'users';

  // Notification IDs
  static const int notifExpiryId = 1001;
  static const int notifDuesId = 1002;

  // Expiry Thresholds
  static const int expiryWarningDays = 30;
  static const int expiryCriticalDays = 7;

  // SharedPreferences Keys
  static const String prefWhatsappSent = 'whatsapp_sent_';
  static const String prefStoreKey = 'store_license_key';
}