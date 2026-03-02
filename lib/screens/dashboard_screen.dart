import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../services/firebase_service.dart';
import '../services/license_service.dart';
import '../services/notification_service.dart';
import '../models/medicine.dart';
import '../models/customer.dart';
import '../utils/app_colors.dart';
import '../utils/constants.dart';
import 'activation_screen.dart';
import 'login_screen.dart';
import 'inventory_screen.dart';
import 'expiry_screen.dart';
import 'dues_screen.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  final FirebaseService _firebase = FirebaseService();
  final LicenseService _license = LicenseService();
  String _userRole = AppConstants.roleStaff;
  String _searchQuery = '';
  List<Medicine> _medicines = [];
  List<Customer> _customers = [];
  bool _loadingRole = true;

  @override
  void initState() {
    super.initState();
    _loadRole();
    _checkForUpdate();
  }

  Future<void> _loadRole() async {
    final role = await _firebase.getUserRole();
    setState(() {
      _userRole = role;
      _loadingRole = false;
    });
  }

  Future<void> _checkForUpdate() async {
    final update = await _license.checkForUpdate(AppConstants.appVersion);
    if (update != null && mounted) {
      _showUpdateDialog(update);
    }
  }

  void _showUpdateDialog(UpdateResult update) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.system_update_rounded, color: AppColors.primary),
            SizedBox(width: 8),
            Text('Update Available'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Version ${update.version} is available.'),
            const SizedBox(height: 8),
            Text(update.message,
                style: const TextStyle(color: AppColors.textMedium)),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Later'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              final uri = Uri.parse(update.apkUrl);
              if (await canLaunchUrl(uri)) await launchUrl(uri);
            },
            child: const Text('Download Now'),
          ),
        ],
      ),
    );
  }

  Future<void> _logout() async {
    await _firebase.logout();
    if (!mounted) return;
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => const LoginScreen()),
    );
  }

  List<Medicine> get _filteredMedicines {
    if (_searchQuery.isEmpty) return _medicines;
    final q = _searchQuery.toLowerCase();
    return _medicines.where((m) =>
        m.name.toLowerCase().contains(q) ||
        m.company.toLowerCase().contains(q) ||
        m.batchNumber.toLowerCase().contains(q) ||
        m.category.toLowerCase().contains(q)).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text(
          'MedStore Manager',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.notifications_rounded),
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => const ExpiryScreen(),
              ),
            ),
          ),
        ],
      ),
      drawer: _buildDrawer(),
      body: StreamBuilder<List<Medicine>>(
        stream: _firebase.getMedicines(),
        builder: (context, medSnap) {
          if (medSnap.hasData && medSnap.data != null) {
            _medicines = medSnap.data!;
            // Check and notify on data load smoothly after frame
            WidgetsBinding.instance.addPostFrameCallback((_) {
              NotificationService().checkAndNotify(_medicines);
            });
          }
          return StreamBuilder<List<Customer>>(
            stream: _firebase.getCustomers(),
            builder: (context, custSnap) {
              if (custSnap.hasData) _customers = custSnap.data!;
              return _buildBody();
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const InventoryScreen()),
        ),
        backgroundColor: AppColors.primary,
        icon: const Icon(Icons.add_rounded, color: AppColors.white),
        label: const Text(
          'Add Medicine',
          style: TextStyle(color: AppColors.white, fontWeight: FontWeight.bold),
        ),
      ),
    );
  }

  Widget _buildBody() {
    final expired = _medicines.where((m) => m.isExpired).length;
    final critical = _medicines.where((m) => m.isCritical).length;
    final warning = _medicines.where((m) => m.isWarning).length;
    final totalDue = _customers.fold(0.0, (sum, c) => sum + c.totalDue);
    final filtered = _filteredMedicines;

    return RefreshIndicator(
      onRefresh: () async => setState(() {}),
      color: AppColors.primary,
      child: CustomScrollView(
        physics: const ClampingScrollPhysics(),
        slivers: [
          // Search Bar
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: TextField(
                onChanged: (v) => setState(() => _searchQuery = v),
                decoration: InputDecoration(
                  hintText: 'Search medicines, batch, company...',
                  prefixIcon:
                      const Icon(Icons.search_rounded, color: AppColors.primary),
                  suffixIcon: _searchQuery.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear_rounded),
                          onPressed: () => setState(() => _searchQuery = ''),
                        )
                      : null,
                  contentPadding: const EdgeInsets.symmetric(vertical: 0),
                ),
              ),
            ),
          ),

          // Stat Cards
          if (_searchQuery.isEmpty)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                child: Column(
                  children: [
                    // Row 1
                    Row(
                      children: [
                        Expanded(
                          child: _statCard(
                            label: 'Total Medicines',
                            value: '${_medicines.length}',
                            icon: Icons.medication_rounded,
                            color: AppColors.primary,
                            onTap: () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                  builder: (_) => const InventoryScreen()),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _statCard(
                            label: 'Expired',
                            value: '$expired',
                            icon: Icons.dangerous_rounded,
                            color: AppColors.danger,
                            onTap: () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) =>
                                    const ExpiryScreen(initialTab: 0),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    // Row 2
                    Row(
                      children: [
                        Expanded(
                          child: _statCard(
                            label: 'Expiring in 7d',
                            value: '$critical',
                            icon: Icons.warning_rounded,
                            color: AppColors.warning,
                            onTap: () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) =>
                                    const ExpiryScreen(initialTab: 1),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _statCard(
                            label: 'Expiring in 30d',
                            value: '$warning',
                            icon: Icons.schedule_rounded,
                            color: Colors.orange,
                            onTap: () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) =>
                                    const ExpiryScreen(initialTab: 2),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    // Dues Card — premium gradient navy
                    GestureDetector(
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const DuesScreen()),
                      ),
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(24),
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [AppColors.navy, AppColors.navyLight],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.circular(20),
                          boxShadow: [
                            BoxShadow(
                              color: AppColors.navy.withValues(alpha: 0.25),
                              blurRadius: 15,
                              offset: const Offset(0, 8),
                            ),
                          ],
                        ),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: AppColors.white.withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(14),
                              ),
                              child: const Icon(
                                Icons.account_balance_wallet_rounded,
                                color: AppColors.white,
                                size: 32,
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'Total Balance Due',
                                    style: TextStyle(
                                      color: AppColors.white,
                                      fontSize: 13,
                                      fontWeight: FontWeight.w400,
                                      letterSpacing: 0.3,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    '₹${totalDue.toStringAsFixed(2)}',
                                    style: const TextStyle(
                                      color: AppColors.white,
                                      fontSize: 28,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Icon(
                              Icons.arrow_forward_ios_rounded,
                              color: AppColors.white.withValues(alpha: 0.7),
                              size: 16,
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    const Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        'All Medicines',
                        style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.bold,
                          color: AppColors.textDark,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

          // Medicine List
          filtered.isEmpty
              ? SliverFillRemaining(
                  child: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.medication_rounded,
                            size: 64,
                            color: AppColors.grey.withOpacity(0.5)),
                        const SizedBox(height: 16),
                        Text(
                          _searchQuery.isNotEmpty
                              ? 'No medicines found'
                              : 'No medicines added yet',
                          style: const TextStyle(
                              color: AppColors.grey, fontSize: 16),
                        ),
                      ],
                    ),
                  ),
                )
              : SliverPadding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
                  sliver: SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (context, index) => _medicineCard(filtered[index]),
                      childCount: filtered.length,
                    ),
                  ),
                ),
        ],
      ),
    );
  }

  Widget _statCard({
    required String label,
    required String value,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    // The inner container needs the specific background based on the required color
    Color bgColor;
    if (color == AppColors.primary) bgColor = AppColors.safeBg;
    else if (color == AppColors.danger) bgColor = AppColors.dangerBg;
    else if (color == AppColors.warning) bgColor = AppColors.warningBg;
    else bgColor = color.withValues(alpha: 0.1);

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
        decoration: BoxDecoration(
          color: AppColors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 15,
              offset: const Offset(0, 8),
            ),
          ],
          border: Border.all(color: AppColors.border, width: 0.5),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: bgColor,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: color, size: 24),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    value,
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: color,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    label,
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: AppColors.textMedium,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _medicineCard(Medicine m) {
    Color statusColor;
    String statusLabel;
    IconData statusIcon;
    Color statusBgColor;

    if (m.isExpired) {
      statusColor = AppColors.danger;
      statusBgColor = AppColors.dangerBg;
      statusLabel = 'Expired';
      statusIcon = Icons.dangerous_rounded;
    } else if (m.isCritical) {
      statusColor = AppColors.warning;
      statusBgColor = AppColors.warningBg;
      statusLabel = '${m.daysUntilExpiry}d left';
      statusIcon = Icons.warning_rounded;
    } else if (m.isWarning) {
      statusColor = AppColors.warning;
      statusBgColor = AppColors.warningBg;
      statusLabel = '${m.daysUntilExpiry}d left';
      statusIcon = Icons.schedule_rounded;
    } else {
      statusColor = AppColors.safe;
      statusBgColor = AppColors.safeBg;
      statusLabel = 'Safe';
      statusIcon = Icons.check_circle_rounded;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.border, width: 0.5),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: statusBgColor,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(Icons.medication_rounded,
                  color: statusColor, size: 28),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    m.name,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                      color: AppColors.textDark,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${m.company} · ${m.category}',
                    style: const TextStyle(
                        fontSize: 13, color: AppColors.textMedium),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Batch: ${m.batchNumber} · Qty: ${m.quantity}',
                    style: const TextStyle(
                        fontSize: 12, color: AppColors.textMedium),
                  ),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: statusBgColor,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: statusColor.withValues(alpha: 0.2)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(statusIcon, size: 14, color: statusColor),
                      const SizedBox(width: 4),
                      Text(
                        statusLabel,
                        style: TextStyle(
                          fontSize: 12,
                          color: statusColor,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  '₹${m.sellingPrice.toStringAsFixed(0)}',
                  style: const TextStyle(
                    fontWeight: FontWeight.w900,
                    color: AppColors.primary,
                    fontSize: 16,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDrawer() {
    return Drawer(
      child: Column(
        children: [
          DrawerHeader(
            decoration: const BoxDecoration(color: AppColors.primary),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                const Icon(Icons.local_pharmacy_rounded,
                    color: AppColors.white, size: 48),
                const SizedBox(height: 8),
                const Text(
                  'MedStore Manager',
                  style: TextStyle(
                    color: AppColors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  _userRole == AppConstants.roleOwner ? 'Owner' : 'Staff',
                  style: TextStyle(
                    color: AppColors.white.withOpacity(0.8),
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
          _drawerItem(Icons.home_rounded, 'Home', () => Navigator.pop(context)),
          _drawerItem(Icons.medication_rounded, 'Inventory', () {
            Navigator.pop(context);
            Navigator.push(context,
                MaterialPageRoute(builder: (_) => const InventoryScreen()));
          }),
          _drawerItem(Icons.warning_rounded, 'Expiry Tracker', () {
            Navigator.pop(context);
            Navigator.push(context,
                MaterialPageRoute(builder: (_) => const ExpiryScreen()));
          }),
          _drawerItem(Icons.account_balance_wallet_rounded, 'Dues', () {
            Navigator.pop(context);
            Navigator.push(context,
                MaterialPageRoute(builder: (_) => const DuesScreen()));
          }),
          if (_userRole == AppConstants.roleOwner)
            _drawerItem(Icons.people_rounded, 'Manage Staff', () {
              Navigator.pop(context);
              _showManageStaff();
            }),
          _drawerItem(Icons.phone_rounded, 'Contact Us', () {
            Navigator.pop(context);
            _showContactUs();
          }),
          const Spacer(),
          _drawerItem(Icons.logout_rounded, 'Logout', _logout,
              color: AppColors.danger),
          const SizedBox(height: 8),
          Text(
            'Developed by ${AppConstants.developerName}',
            style: const TextStyle(fontSize: 11, color: AppColors.grey),
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  Widget _drawerItem(IconData icon, String label, VoidCallback onTap,
      {Color color = AppColors.primary}) {
    return ListTile(
      leading: Icon(icon, color: color),
      title: Text(label,
          style: TextStyle(color: color, fontWeight: FontWeight.w500)),
      onTap: onTap,
    );
  }

  void _showContactUs() {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Contact Us'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading:
                  const Icon(Icons.phone_rounded, color: AppColors.whatsapp),
              title: const Text('WhatsApp'),
              subtitle: Text(AppConstants.contactWhatsApp),
              onTap: () async {
                final uri = Uri.parse(
                    'https://wa.me/${AppConstants.contactWhatsApp.replaceAll('+', '')}');
                if (await canLaunchUrl(uri)) await launchUrl(uri);
              },
            ),
            ListTile(
              leading:
                  const Icon(Icons.email_rounded, color: AppColors.primary),
              title: const Text('Email'),
              subtitle: Text(AppConstants.contactEmail),
              onTap: () async {
                final uri =
                    Uri.parse('mailto:${AppConstants.contactEmail}');
                if (await canLaunchUrl(uri)) await launchUrl(uri);
              },
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  void _showManageStaff() {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Manage Staff'),
        content: SizedBox(
          width: double.maxFinite,
          child: StreamBuilder<List<Map<String, dynamic>>>(
            stream: _firebase.getStaffUsers(),
            builder: (context, snap) {
              if (!snap.hasData) {
                return const Center(child: CircularProgressIndicator());
              }
              final users = snap.data!;
              if (users.isEmpty) {
                return const Text('No staff accounts yet.');
              }
              return ListView.builder(
                shrinkWrap: true,
                itemCount: users.length,
                itemBuilder: (_, i) {
                  final u = users[i];
                  return ListTile(
                    leading: const Icon(Icons.person_rounded,
                        color: AppColors.primary),
                    title: Text(u['email'] ?? ''),
                    subtitle: Text(u['role'] ?? ''),
                    trailing: u['role'] != AppConstants.roleOwner
                        ? IconButton(
                            icon: const Icon(Icons.delete_rounded,
                                color: AppColors.danger),
                            onPressed: () =>
                                _firebase.deleteStaffUser(u['id']),
                          )
                        : null,
                  );
                },
              );
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
          ElevatedButton.icon(
            onPressed: () {
              Navigator.pop(context);
              _showAddStaff();
            },
            icon: const Icon(Icons.add_rounded),
            label: const Text('Add Staff'),
          ),
        ],
      ),
    );
  }

  void _showAddStaff() {
    final emailCtrl = TextEditingController();
    final passCtrl = TextEditingController();
    String? error;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setS) => AlertDialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Text('Add Staff Account'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: emailCtrl,
                keyboardType: TextInputType.emailAddress,
                decoration: const InputDecoration(labelText: 'Staff Email'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: passCtrl,
                obscureText: true,
                decoration: const InputDecoration(labelText: 'Password'),
              ),
              if (error != null) ...[
                const SizedBox(height: 8),
                Text(error!, style: const TextStyle(color: AppColors.danger)),
              ],
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                final err = await _firebase.createStaffAccount(
                  emailCtrl.text.trim(),
                  passCtrl.text.trim(),
                );
                if (err == null) {
                  Navigator.pop(ctx);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('✅ Staff account created!'),
                      backgroundColor: AppColors.safe,
                    ),
                  );
                } else {
                  setS(() => error = err);
                }
              },
              child: const Text('Create'),
            ),
          ],
        ),
      ),
    );
  }
}