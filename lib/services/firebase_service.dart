import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/medicine.dart';
import '../models/customer.dart';
import '../utils/constants.dart';

class FirebaseService {
  static final FirebaseService _instance = FirebaseService._internal();
  factory FirebaseService() => _instance;
  FirebaseService._internal();

  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // ─── Auth ───────────────────────────────────────────────

  User? get currentUser => _auth.currentUser;
  Stream<User?> get authStateChanges => _auth.authStateChanges();

  Future<String?> login(String email, String password) async {
    try {
      await _auth.signInWithEmailAndPassword(email: email, password: password);
      return null; // success
    } on FirebaseAuthException catch (e) {
      switch (e.code) {
        case 'user-not-found':
          return 'No account found with this email.';
        case 'wrong-password':
          return 'Incorrect password.';
        case 'invalid-email':
          return 'Invalid email address.';
        case 'user-disabled':
          return 'This account has been disabled.';
        default:
          return 'Login failed. Please try again.';
      }
    }
  }

  Future<String?> createStaffAccount(String email, String password) async {
    try {
      final credential = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );
      // Save staff role in Firestore
      final storeKey = await _getStoreKey();
      await _db
          .collection('stores')
          .doc(storeKey)
          .collection(AppConstants.colUsers)
          .doc(credential.user!.uid)
          .set({
        'email': email,
        'role': AppConstants.roleStaff,
        'createdAt': DateTime.now().toIso8601String(),
      });
      return null;
    } on FirebaseAuthException catch (e) {
      if (e.code == 'email-already-in-use') {
        return 'This email is already registered.';
      }
      return 'Failed to create account. Please try again.';
    }
  }

  Future<void> logout() async {
    await _auth.signOut();
  }

  Future<String> getUserRole() async {
    try {
      final storeKey = await _getStoreKey();
      final uid = _auth.currentUser?.uid;
      if (uid == null) return AppConstants.roleStaff;
      final doc = await _db
          .collection('stores')
          .doc(storeKey)
          .collection(AppConstants.colUsers)
          .doc(uid)
          .get();
      return doc.data()?['role'] ?? AppConstants.roleStaff;
    } catch (e) {
      return AppConstants.roleStaff;
    }
  }

  // ─── Store Key ──────────────────────────────────────────

  Future<String> _getStoreKey() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(AppConstants.prefStoreKey) ?? 'default';
  }

  // ─── Medicines ──────────────────────────────────────────

  Future<String> _storeBase() async {
    final key = await _getStoreKey();
    return 'stores/$key';
  }

  Stream<List<Medicine>> getMedicines() async* {
    final base = await _storeBase();
    yield* _db
        .collection('$base/${AppConstants.colMedicines}')
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snap) => snap.docs
            .map((doc) => Medicine.fromMap(doc.id, doc.data()))
            .toList());
  }

  Future<void> addMedicine(Medicine medicine) async {
    final base = await _storeBase();
    await _db
        .collection('$base/${AppConstants.colMedicines}')
        .add(medicine.toMap());
  }

  Future<void> updateMedicine(Medicine medicine) async {
    final base = await _storeBase();
    await _db
        .collection('$base/${AppConstants.colMedicines}')
        .doc(medicine.id)
        .update(medicine.toMap());
  }

  Future<void> deleteMedicine(String id) async {
    final base = await _storeBase();
    await _db
        .collection('$base/${AppConstants.colMedicines}')
        .doc(id)
        .delete();
  }

  Future<bool> batchNumberExists(String batchNumber, {String? excludeId}) async {
    final base = await _storeBase();
    final snap = await _db
        .collection('$base/${AppConstants.colMedicines}')
        .where('batchNumber', isEqualTo: batchNumber)
        .get();
    if (excludeId != null) {
      return snap.docs.any((doc) => doc.id != excludeId);
    }
    return snap.docs.isNotEmpty;
  }

  // ─── Customers ──────────────────────────────────────────

  Stream<List<Customer>> getCustomers() async* {
    final base = await _storeBase();
    yield* _db
        .collection('$base/${AppConstants.colCustomers}')
        .orderBy('totalDue', descending: true)
        .snapshots()
        .map((snap) => snap.docs
            .map((doc) => Customer.fromMap(doc.id, doc.data()))
            .toList());
  }

  Future<void> addCustomer(Customer customer) async {
    final base = await _storeBase();
    await _db
        .collection('$base/${AppConstants.colCustomers}')
        .add(customer.toMap());
  }

  Future<void> updateCustomer(Customer customer) async {
    final base = await _storeBase();
    await _db
        .collection('$base/${AppConstants.colCustomers}')
        .doc(customer.id)
        .update(customer.toMap());
  }

  Future<void> deleteCustomer(String id) async {
    final base = await _storeBase();
    await _db
        .collection('$base/${AppConstants.colCustomers}')
        .doc(id)
        .delete();
  }

  // ─── Payments ───────────────────────────────────────────

  Stream<List<Payment>> getPayments(String customerId) async* {
    final base = await _storeBase();
    yield* _db
        .collection('$base/${AppConstants.colPayments}')
        .where('customerId', isEqualTo: customerId)
        .orderBy('date', descending: true)
        .snapshots()
        .map((snap) => snap.docs
            .map((doc) => Payment.fromMap(doc.id, doc.data()))
            .toList());
  }

  Future<void> addPayment(Payment payment, Customer customer) async {
    final base = await _storeBase();
    // Add payment record
    await _db
        .collection('$base/${AppConstants.colPayments}')
        .add(payment.toMap());
    // Update customer balance
    final newDue = (customer.totalDue - payment.amount).clamp(0.0, double.infinity);
    await _db
        .collection('$base/${AppConstants.colCustomers}')
        .doc(customer.id)
        .update({'totalDue': newDue});
  }

  // ─── Staff Users ─────────────────────────────────────────

  Stream<List<Map<String, dynamic>>> getStaffUsers() async* {
    final base = await _storeBase();
    yield* _db
        .collection('$base/${AppConstants.colUsers}')
        .snapshots()
        .map((snap) => snap.docs
            .map((doc) => {'id': doc.id, ...doc.data()})
            .toList());
  }

  Future<void> deleteStaffUser(String uid) async {
    final base = await _storeBase();
    await _db
        .collection('$base/${AppConstants.colUsers}')
        .doc(uid)
        .delete();
  }
}