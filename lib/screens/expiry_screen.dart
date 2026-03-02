import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../services/firebase_service.dart';
import '../models/medicine.dart';
import '../utils/app_colors.dart';

class ExpiryScreen extends StatefulWidget {
  final int initialTab;
  const ExpiryScreen({super.key, this.initialTab = 0});

  @override
  State<ExpiryScreen> createState() => _ExpiryScreenState();
}

class _ExpiryScreenState extends State<ExpiryScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final FirebaseService _firebase = FirebaseService();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(
      length: 3,
      vsync: this,
      initialIndex: widget.initialTab,
    );
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Expiry Tracker',
            style: TextStyle(fontWeight: FontWeight.bold)),
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: AppColors.white,
          labelColor: AppColors.white,
          unselectedLabelColor: AppColors.white.withOpacity(0.6),
          tabs: const [
            Tab(
              icon: Icon(Icons.dangerous_rounded, size: 18),
              text: 'Expired',
            ),
            Tab(
              icon: Icon(Icons.warning_rounded, size: 18),
              text: '7 Days',
            ),
            Tab(
              icon: Icon(Icons.schedule_rounded, size: 18),
              text: '30 Days',
            ),
          ],
        ),
      ),
      body: StreamBuilder<List<Medicine>>(
        stream: _firebase.getMedicines(),
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(
                child: CircularProgressIndicator(color: AppColors.primary));
          }

          final all = snap.data ?? [];
          final expired =
              all.where((m) => m.isExpired).toList()
                ..sort((a, b) => a.expiryDate.compareTo(b.expiryDate));
          final critical =
              all.where((m) => m.isCritical).toList()
                ..sort((a, b) => a.expiryDate.compareTo(b.expiryDate));
          final warning =
              all.where((m) => m.isWarning).toList()
                ..sort((a, b) => a.expiryDate.compareTo(b.expiryDate));

          return TabBarView(
            controller: _tabController,
            children: [
              _ExpiryList(
                medicines: expired,
                emptyMessage: '✅ No expired medicines!',
                emptySubMessage: 'All medicines are within their expiry date.',
                statusColor: AppColors.danger,
                statusLabel: (m) => 'Expired ${m.daysUntilExpiry.abs()}d ago',
              ),
              _ExpiryList(
                medicines: critical,
                emptyMessage: '✅ Nothing expiring in 7 days!',
                emptySubMessage: 'Your stock looks good for the next week.',
                statusColor: AppColors.warning,
                statusLabel: (m) => '${m.daysUntilExpiry}d left',
              ),
              _ExpiryList(
                medicines: warning,
                emptyMessage: '✅ Nothing expiring in 30 days!',
                emptySubMessage: 'Your stock looks good for the next month.',
                statusColor: Colors.orange,
                statusLabel: (m) => '${m.daysUntilExpiry}d left',
              ),
            ],
          );
        },
      ),
    );
  }
}

class _ExpiryList extends StatelessWidget {
  final List<Medicine> medicines;
  final String emptyMessage;
  final String emptySubMessage;
  final Color statusColor;
  final String Function(Medicine) statusLabel;

  const _ExpiryList({
    required this.medicines,
    required this.emptyMessage,
    required this.emptySubMessage,
    required this.statusColor,
    required this.statusLabel,
  });

  @override
  Widget build(BuildContext context) {
    if (medicines.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.check_circle_rounded,
                size: 72, color: AppColors.safe.withOpacity(0.6)),
            const SizedBox(height: 16),
            Text(
              emptyMessage,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: AppColors.safe,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              emptySubMessage,
              style: const TextStyle(
                  fontSize: 13, color: AppColors.textMedium),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }

    return Column(
      children: [
        // Summary banner
        Container(
          width: double.infinity,
          margin: const EdgeInsets.all(16),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: statusColor.withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: statusColor.withOpacity(0.3)),
          ),
          child: Row(
            children: [
              Icon(Icons.info_rounded, color: statusColor, size: 20),
              const SizedBox(width: 10),
              Text(
                '${medicines.length} medicine${medicines.length > 1 ? 's' : ''} need attention',
                style: TextStyle(
                  color: statusColor,
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
            ],
          ),
        ),

        // List
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
            itemCount: medicines.length,
            itemBuilder: (_, i) =>
                _expiryCard(medicines[i], statusColor, statusLabel),
          ),
        ),
      ],
    );
  }

  Widget _expiryCard(
      Medicine m, Color color, String Function(Medicine) labelFn) {
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            // Status indicator
            Container(
              width: 4,
              height: 70,
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    m.name,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                      color: AppColors.textDark,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    '${m.company} · ${m.category}',
                    style: const TextStyle(
                        fontSize: 12, color: AppColors.textMedium),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    'Batch: ${m.batchNumber} · Qty: ${m.quantity} · Rack: ${m.rack}',
                    style: const TextStyle(
                        fontSize: 12, color: AppColors.textMedium),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    'Expiry: ${DateFormat('dd MMM yyyy').format(m.expiryDate)}',
                    style: TextStyle(
                      fontSize: 12,
                      color: color,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),

            // Days badge
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: color.withOpacity(0.4)),
              ),
              child: Text(
                labelFn(m),
                style: TextStyle(
                  color: color,
                  fontWeight: FontWeight.bold,
                  fontSize: 11,
                ),
                textAlign: TextAlign.center,
              ),
            ),
          ],
        ),
      ),
    );
  }
}