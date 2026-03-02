import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:uuid/uuid.dart';
import '../services/firebase_service.dart';
import '../models/customer.dart';
import '../utils/app_colors.dart';
import '../utils/constants.dart';
import 'customer_detail_screen.dart';

class DuesScreen extends StatefulWidget {
  const DuesScreen({super.key});

  @override
  State<DuesScreen> createState() => _DuesScreenState();
}

class _DuesScreenState extends State<DuesScreen> {
  final FirebaseService _firebase = FirebaseService();
  String _searchQuery = '';
  Map<String, bool> _whatsappSent = {};

  @override
  void initState() {
    super.initState();
    _loadSentState();
  }

  Future<void> _loadSentState() async {
    final prefs = await SharedPreferences.getInstance();
    final keys = prefs.getKeys().where(
        (k) => k.startsWith(AppConstants.prefWhatsappSent));
    setState(() {
      for (final k in keys) {
        _whatsappSent[k] = prefs.getBool(k) ?? false;
      }
    });
  }

  Future<void> _markSent(String customerId) async {
    final key = '${AppConstants.prefWhatsappSent}$customerId';
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(key, true);
    setState(() => _whatsappSent[key] = true);
  }

  Future<void> _sendWhatsApp(Customer customer) async {
    final message =
        'नमस्ते ${customer.name} जी, आपके मेडिकल स्टोर का बकाया ₹${customer.totalDue.toStringAsFixed(0)} है। कृपया जल्द भुगतान करें। धन्यवाद।';
    final phone = '91${customer.phone.replaceAll(RegExp(r'[^0-9]'), '')}';
    final uri = Uri.parse(
        'whatsapp://send?phone=$phone&text=${Uri.encodeComponent(message)}');
    final fallback = Uri.parse(
        'https://wa.me/$phone?text=${Uri.encodeComponent(message)}');

    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    } else {
      await launchUrl(fallback, mode: LaunchMode.externalApplication);
    }
    await _markSent(customer.id);
  }

  List<Customer> _filtered(List<Customer> customers) {
    if (_searchQuery.isEmpty) return customers;
    final q = _searchQuery.toLowerCase();
    return customers.where((c) =>
        c.name.toLowerCase().contains(q) ||
        c.phone.contains(q)).toList();
  }

  void _showAddCustomerDialog() {
    final nameCtrl = TextEditingController();
    final phoneCtrl = TextEditingController();
    final addressCtrl = TextEditingController();
    final dueCtrl = TextEditingController();
    String? error;
    bool attempted = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => StatefulBuilder(
        builder: (ctx, setS) => Container(
          decoration: const BoxDecoration(
            color: AppColors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          padding: EdgeInsets.only(
            left: 20,
            right: 20,
            top: 20,
            bottom: MediaQuery.of(ctx).viewInsets.bottom + 20,
          ),
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: AppColors.grey.withOpacity(0.4),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                const Text(
                  'Add Customer',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textDark,
                  ),
                ),
                const SizedBox(height: 20),
                _inputField(nameCtrl, 'Customer Name', Icons.person_rounded),
                const SizedBox(height: 12),
                _inputField(phoneCtrl, 'Phone Number', Icons.phone_rounded,
                    keyboardType: TextInputType.phone),
                const SizedBox(height: 12),
                _inputField(
                    addressCtrl, 'Address', Icons.location_on_rounded),
                const SizedBox(height: 12),
                _inputField(
                    dueCtrl, 'Balance Due (₹)', Icons.currency_rupee_rounded,
                    keyboardType: TextInputType.number),
                if (error != null) ...[
                  const SizedBox(height: 8),
                  Text(error!,
                      style: const TextStyle(
                          color: AppColors.danger, fontSize: 13)),
                ],
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () async {
                      setS(() => attempted = true);
                      if (nameCtrl.text.trim().isEmpty ||
                          phoneCtrl.text.trim().isEmpty) {
                        setS(() => error = 'Name and phone are required.');
                        return;
                      }
                      final customer = Customer(
                        id: const Uuid().v4(),
                        name: nameCtrl.text.trim(),
                        phone: phoneCtrl.text.trim(),
                        address: addressCtrl.text.trim(),
                        totalDue:
                            double.tryParse(dueCtrl.text.trim()) ?? 0,
                        createdAt: DateTime.now(),
                      );
                      await _firebase.addCustomer(customer);
                      if (ctx.mounted) Navigator.pop(ctx);
                    },
                    child: const Text('Add Customer',
                        style: TextStyle(
                            fontSize: 16, fontWeight: FontWeight.bold)),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showRecordPayment(Customer customer) {
    final amountCtrl = TextEditingController();
    final noteCtrl = TextEditingController();
    String? error;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => StatefulBuilder(
        builder: (ctx, setS) => Container(
          decoration: const BoxDecoration(
            color: AppColors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          padding: EdgeInsets.only(
            left: 20,
            right: 20,
            top: 20,
            bottom: MediaQuery.of(ctx).viewInsets.bottom + 20,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppColors.grey.withOpacity(0.4),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Record Payment — ${customer.name}',
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textDark,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'Current due: ₹${customer.totalDue.toStringAsFixed(2)}',
                style: const TextStyle(
                    color: AppColors.danger, fontWeight: FontWeight.w500),
              ),
              const SizedBox(height: 20),
              _inputField(amountCtrl, 'Amount Paid (₹)',
                  Icons.currency_rupee_rounded,
                  keyboardType: TextInputType.number),
              const SizedBox(height: 12),
              _inputField(noteCtrl, 'Note (optional)', Icons.note_rounded),
              if (error != null) ...[
                const SizedBox(height: 8),
                Text(error!,
                    style: const TextStyle(
                        color: AppColors.danger, fontSize: 13)),
              ],
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () async {
                    final amount =
                        double.tryParse(amountCtrl.text.trim()) ?? 0;
                    if (amount <= 0) {
                      setS(() => error = 'Enter a valid amount.');
                      return;
                    }
                    if (amount > customer.totalDue) {
                      setS(() =>
                          error = 'Amount exceeds current due balance.');
                      return;
                    }
                    final payment = Payment(
                      id: const Uuid().v4(),
                      customerId: customer.id,
                      amount: amount,
                      date: DateTime.now(),
                      note: noteCtrl.text.trim(),
                    );
                    await _firebase.addPayment(payment, customer);
                    if (ctx.mounted) {
                      Navigator.pop(ctx);
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                              '✅ ₹${amount.toStringAsFixed(0)} recorded for ${customer.name}'),
                          backgroundColor: AppColors.safe,
                        ),
                      );
                    }
                  },
                  child: const Text('Record Payment',
                      style: TextStyle(
                          fontSize: 16, fontWeight: FontWeight.bold)),
                ),
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }

  void _confirmDelete(Customer c) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Delete Customer'),
        content: Text('Delete "${c.name}"? This cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style:
                ElevatedButton.styleFrom(backgroundColor: AppColors.danger),
            onPressed: () async {
              Navigator.pop(context);
              await _firebase.deleteCustomer(c.id);
            },
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Credit & Dues',
            style: TextStyle(fontWeight: FontWeight.bold)),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _showAddCustomerDialog,
        backgroundColor: AppColors.primary,
        child: const Icon(Icons.person_add_rounded, color: AppColors.white),
      ),
      body: Column(
        children: [
          // Search
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: TextField(
              onChanged: (v) => setState(() => _searchQuery = v),
              style: const TextStyle(color: AppColors.textDark),
              decoration: InputDecoration(
                hintText: 'Search by name or phone...',
                prefixIcon: const Icon(Icons.search_rounded,
                    color: AppColors.navy),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear_rounded),
                        onPressed: () =>
                            setState(() => _searchQuery = ''),
                      )
                    : null,
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide:
                      BorderSide(color: AppColors.navy.withOpacity(0.4)),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide:
                      const BorderSide(color: AppColors.navy, width: 2),
                ),
                contentPadding: const EdgeInsets.symmetric(vertical: 0),
              ),
            ),
          ),

          // List
          Expanded(
            child: StreamBuilder<List<Customer>>(
              stream: _firebase.getCustomers(),
              builder: (context, snap) {
                if (snap.connectionState == ConnectionState.waiting) {
                  return const Center(
                      child: CircularProgressIndicator(
                          color: AppColors.primary));
                }

                final all = snap.data ?? [];
                final filtered = _filtered(all);
                final totalDue =
                    filtered.fold(0.0, (s, c) => s + c.totalDue);

                return Column(
                  children: [
                    // Total due banner
                    if (filtered.isNotEmpty)
                      Container(
                        margin:
                            const EdgeInsets.fromLTRB(16, 0, 16, 8),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 12),
                        decoration: BoxDecoration(
                          color: AppColors.navy,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          mainAxisAlignment:
                              MainAxisAlignment.spaceBetween,
                          children: [
                            const Text(
                              'Total Outstanding',
                              style: TextStyle(
                                color: AppColors.white,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            Text(
                              '₹${totalDue.toStringAsFixed(2)}',
                              style: const TextStyle(
                                color: AppColors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 18,
                              ),
                            ),
                          ],
                        ),
                      ),

                    // Customer list
                    Expanded(
                      child: filtered.isEmpty
                          ? Center(
                              child: Column(
                                mainAxisAlignment:
                                    MainAxisAlignment.center,
                                children: [
                                  Icon(
                                      Icons
                                          .account_balance_wallet_rounded,
                                      size: 64,
                                      color: AppColors.grey
                                          .withOpacity(0.5)),
                                  const SizedBox(height: 16),
                                  Text(
                                    _searchQuery.isNotEmpty
                                        ? 'No customers found'
                                        : 'No customers added yet',
                                    style: const TextStyle(
                                        color: AppColors.grey,
                                        fontSize: 16),
                                  ),
                                ],
                              ),
                            )
                          : ListView.builder(
                              padding: const EdgeInsets.fromLTRB(
                                  16, 0, 16, 100),
                              itemCount: filtered.length,
                              itemBuilder: (_, i) =>
                                  _customerCard(filtered[i]),
                            ),
                    ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _customerCard(Customer c) {
    final sentKey = '${AppConstants.prefWhatsappSent}${c.id}';
    final sent = _whatsappSent[sentKey] ?? false;

    return GestureDetector(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(
            builder: (_) => CustomerDetailScreen(customer: c)),
      ),
      child: Card(
        margin: const EdgeInsets.only(bottom: 10),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppColors.navy.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.person_rounded,
                        color: AppColors.navy, size: 22),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          c.name,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 15,
                            color: AppColors.textDark,
                          ),
                        ),
                        Text(
                          c.phone,
                          style: const TextStyle(
                              fontSize: 12,
                              color: AppColors.textMedium),
                        ),
                      ],
                    ),
                  ),
                  Text(
                    '₹${c.totalDue.toStringAsFixed(0)}',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 18,
                      color: AppColors.navy,
                    ),
                  ),
                ],
              ),
              if (c.address.isNotEmpty) ...[
                const SizedBox(height: 6),
                Text(
                  c.address,
                  style: const TextStyle(
                      fontSize: 12, color: AppColors.textMedium),
                ),
              ],
              const SizedBox(height: 10),
              Row(
                children: [
                  // WhatsApp button
                  Expanded(
                    child: GestureDetector(
                      onTap: () => _sendWhatsApp(c),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            vertical: 8),
                        decoration: BoxDecoration(
                          color: sent
                              ? AppColors.whatsappSent
                              : AppColors.whatsapp,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          mainAxisAlignment:
                              MainAxisAlignment.center,
                          children: [
                            Icon(
                              sent
                                  ? Icons.check_rounded
                                  : Icons.message_rounded,
                              color: AppColors.white,
                              size: 16,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              sent ? 'Sent' : 'WhatsApp Reminder',
                              style: const TextStyle(
                                color: AppColors.white,
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  // Record Payment
                  Expanded(
                    child: GestureDetector(
                      onTap: () => _showRecordPayment(c),
                      child: Container(
                        padding:
                            const EdgeInsets.symmetric(vertical: 8),
                        decoration: BoxDecoration(
                          color: AppColors.primary,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Row(
                          mainAxisAlignment:
                              MainAxisAlignment.center,
                          children: [
                            Icon(Icons.payments_rounded,
                                color: AppColors.white, size: 16),
                            SizedBox(width: 6),
                            Text(
                              'Record Payment',
                              style: TextStyle(
                                color: AppColors.white,
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  // Delete
                  GestureDetector(
                    onTap: () => _confirmDelete(c),
                    child: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: AppColors.danger.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                            color:
                                AppColors.danger.withOpacity(0.3)),
                      ),
                      child: const Icon(Icons.delete_rounded,
                          color: AppColors.danger, size: 18),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _inputField(
    TextEditingController ctrl,
    String label,
    IconData icon, {
    TextInputType keyboardType = TextInputType.text,
  }) {
    return TextField(
      controller: ctrl,
      keyboardType: keyboardType,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, color: AppColors.primary),
      ),
    );
  }
}