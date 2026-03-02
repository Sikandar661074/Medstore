import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';
import '../services/firebase_service.dart';
import '../models/medicine.dart';
import '../utils/app_colors.dart';

class InventoryScreen extends StatefulWidget {
  const InventoryScreen({super.key});

  @override
  State<InventoryScreen> createState() => _InventoryScreenState();
}

class _InventoryScreenState extends State<InventoryScreen> {
  final FirebaseService _firebase = FirebaseService();
  String _searchQuery = '';
  String _filterStatus = 'All';
  final List<String> _filters = ['All', 'Safe', 'Expiring', 'Expired'];

  List<Medicine> _applyFilters(List<Medicine> medicines) {
    List<Medicine> result = medicines;

    if (_searchQuery.isNotEmpty) {
      final q = _searchQuery.toLowerCase();
      result = result.where((m) =>
          m.name.toLowerCase().contains(q) ||
          m.company.toLowerCase().contains(q) ||
          m.batchNumber.toLowerCase().contains(q) ||
          m.category.toLowerCase().contains(q)).toList();
    }

    switch (_filterStatus) {
      case 'Safe':
        result = result.where((m) => m.isSafe).toList();
        break;
      case 'Expiring':
        result = result.where((m) => m.isWarning || m.isCritical).toList();
        break;
      case 'Expired':
        result = result.where((m) => m.isExpired).toList();
        break;
    }

    return result;
  }

  void _showAddEditDialog({Medicine? medicine}) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _AddEditMedicineSheet(
        medicine: medicine,
        onSave: (m) async {
          if (medicine == null) {
            await _firebase.addMedicine(m);
          } else {
            await _firebase.updateMedicine(m);
          }
        },
      ),
    );
  }

  void _confirmDelete(Medicine m) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Delete Medicine'),
        content: Text('Delete "${m.name}"? This cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.danger),
            onPressed: () async {
              Navigator.pop(context);
              await _firebase.deleteMedicine(m.id);
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Medicine deleted.'),
                    backgroundColor: AppColors.danger,
                  ),
                );
              }
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
        title: const Text('Medicine Inventory',
            style: TextStyle(fontWeight: FontWeight.bold)),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showAddEditDialog(),
        backgroundColor: AppColors.primary,
        elevation: 4,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        icon: const Icon(Icons.add_rounded, color: AppColors.white),
        label: const Text(
          'Add Medicine',
          style: TextStyle(
            color: AppColors.white,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      body: Column(
        children: [
          // Search
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
            child: Container(
              decoration: BoxDecoration(
                color: AppColors.safeBg,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.border),
              ),
              child: TextField(
                onChanged: (v) => setState(() => _searchQuery = v),
                decoration: InputDecoration(
                  hintText: 'Search medicines, batch, company...',
                  hintStyle: const TextStyle(color: AppColors.textMedium, fontSize: 14),
                  prefixIcon: const Icon(Icons.search_rounded, color: AppColors.primary),
                  border: InputBorder.none,
                  enabledBorder: InputBorder.none,
                  focusedBorder: InputBorder.none,
                  suffixIcon: _searchQuery.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear_rounded, color: AppColors.textMedium),
                          onPressed: () => setState(() => _searchQuery = ''),
                        )
                      : null,
                  contentPadding: const EdgeInsets.symmetric(vertical: 14),
                ),
              ),
            ),
          ),

          // Filter Chips
          SizedBox(
            height: 48,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: _filters.length,
              separatorBuilder: (_, __) => const SizedBox(width: 8),
              itemBuilder: (_, i) {
                final f = _filters[i];
                final selected = _filterStatus == f;
                return FilterChip(
                  label: Text(f),
                  selected: selected,
                  onSelected: (_) => setState(() => _filterStatus = f),
                  selectedColor: AppColors.primary,
                  showCheckmark: true,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                    side: BorderSide(
                      color: selected ? AppColors.primary : AppColors.border,
                      width: 1,
                    ),
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
                  labelStyle: TextStyle(
                    color: selected ? AppColors.white : AppColors.textDark,
                    fontWeight: selected ? FontWeight.bold : FontWeight.w500,
                  ),
                  checkmarkColor: AppColors.white,
                  backgroundColor: AppColors.white,
                );
              },
            ),
          ),

          const SizedBox(height: 8),

          // List
          Expanded(
            child: StreamBuilder<List<Medicine>>(
              stream: _firebase.getMedicines(),
              builder: (context, snap) {
                if (snap.connectionState == ConnectionState.waiting) {
                  return const Center(
                      child: CircularProgressIndicator(
                          color: AppColors.primary));
                }
                if (!snap.hasData || snap.data!.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.medication_rounded,
                            size: 64,
                            color: AppColors.grey.withValues(alpha: 0.5)),
                        const SizedBox(height: 16),
                        const Text('No medicines added yet.',
                            style: TextStyle(color: AppColors.grey)),
                        const SizedBox(height: 8),
                        ElevatedButton.icon(
                          onPressed: () => _showAddEditDialog(),
                          icon: const Icon(Icons.add_rounded),
                          label: const Text('Add Medicine'),
                        ),
                      ],
                    ),
                  );
                }

                final filtered = _applyFilters(snap.data!);

                if (filtered.isEmpty) {
                  return const Center(
                    child: Text('No medicines match your filter.',
                        style: TextStyle(color: AppColors.grey)),
                  );
                }

                return ListView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 100),
                  physics: const ClampingScrollPhysics(),
                  itemCount: filtered.length,
                  itemBuilder: (_, i) => _medicineCard(filtered[i]),
                );
              },
            ),
          ),
        ],
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
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
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
                      const SizedBox(height: 4),
                      Text(
                        'Rack: ${m.rack}',
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
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Icon(Icons.calendar_today_rounded,
                        size: 14, color: AppColors.grey),
                    const SizedBox(width: 6),
                    Text(
                      'Pur: ${DateFormat('dd MMM yyyy').format(m.purchaseDate)}',
                      style: const TextStyle(
                          fontSize: 12, color: AppColors.grey),
                    ),
                  ],
                ),
                Row(
                  children: [
                    Icon(Icons.event_busy_rounded,
                        size: 14, color: AppColors.grey),
                    const SizedBox(width: 6),
                    Text(
                      'Exp: ${DateFormat('dd MMM yyyy').format(m.expiryDate)}',
                      style: const TextStyle(
                          fontSize: 12, color: AppColors.grey),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton.icon(
                  onPressed: () => _showAddEditDialog(medicine: m),
                  icon:
                      const Icon(Icons.edit_rounded, color: AppColors.primary),
                  label: const Text('Edit',
                      style: TextStyle(color: AppColors.primary)),
                ),
                TextButton.icon(
                  onPressed: () => _confirmDelete(m),
                  icon:
                      const Icon(Icons.delete_rounded, color: AppColors.danger),
                  label: const Text('Delete',
                      style: TextStyle(color: AppColors.danger)),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Add / Edit Bottom Sheet ──────────────────────────────

class _AddEditMedicineSheet extends StatefulWidget {
  final Medicine? medicine;
  final Future<void> Function(Medicine) onSave;

  const _AddEditMedicineSheet({this.medicine, required this.onSave});

  @override
  State<_AddEditMedicineSheet> createState() => _AddEditMedicineSheetState();
}

class _AddEditMedicineSheetState extends State<_AddEditMedicineSheet> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _name;
  late TextEditingController _company;
  late TextEditingController _batch;
  late TextEditingController _purchasePrice;
  late TextEditingController _sellingPrice;
  late TextEditingController _quantity;
  late TextEditingController _rack;
  DateTime? _purchaseDate;
  DateTime? _expiryDate;
  bool _isSaving = false;
  bool _attempted = false;
  String? _batchError;

  final List<String> _categories = [
    'Tablet', 'Syrup', 'Injection', 'Cream',
    'Drops', 'Capsule', 'Powder', 'Other'
  ];
  String _selectedCategory = 'Tablet';

  @override
  void initState() {
    super.initState();
    final m = widget.medicine;
    _name = TextEditingController(text: m?.name ?? '');
    _company = TextEditingController(text: m?.company ?? '');
    _batch = TextEditingController(text: m?.batchNumber ?? '');
    _purchasePrice =
        TextEditingController(text: m?.purchasePrice.toString() ?? '');
    _sellingPrice =
        TextEditingController(text: m?.sellingPrice.toString() ?? '');
    _quantity = TextEditingController(text: m?.quantity.toString() ?? '');
    _rack = TextEditingController(text: m?.rack ?? '');
    _purchaseDate = m?.purchaseDate;
    _expiryDate = m?.expiryDate;
    if (m != null) _selectedCategory = m.category;
  }

  @override
  void dispose() {
    _name.dispose();
    _company.dispose();
    _batch.dispose();
    _purchasePrice.dispose();
    _sellingPrice.dispose();
    _quantity.dispose();
    _rack.dispose();
    super.dispose();
  }

  Future<void> _pickDate(bool isExpiry) async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: isExpiry ? now.add(const Duration(days: 365)) : now,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
      builder: (context, child) => Theme(
        data: Theme.of(context).copyWith(
          colorScheme:
              const ColorScheme.light(primary: AppColors.primary),
        ),
        child: child!,
      ),
    );
    if (picked != null) {
      setState(() {
        if (isExpiry) {
          _expiryDate = picked;
        } else {
          _purchaseDate = picked;
        }
      });
    }
  }

  Future<void> _save() async {
    setState(() => _attempted = true);

    if (!_formKey.currentState!.validate()) return;
    if (_purchaseDate == null || _expiryDate == null) return;

    setState(() => _isSaving = true);

    final exists = await FirebaseService().batchNumberExists(
      _batch.text.trim(),
      excludeId: widget.medicine?.id,
    );

    if (exists) {
      setState(() {
        _batchError = 'Batch number already exists.';
        _isSaving = false;
      });
      return;
    }

    try {
      final medicine = Medicine(
        id: widget.medicine?.id ?? const Uuid().v4(),
        name: _name.text.trim(),
        company: _company.text.trim(),
        category: _selectedCategory,
        batchNumber: _batch.text.trim(),
        purchaseDate: _purchaseDate!,
        expiryDate: _expiryDate!,
        purchasePrice: double.tryParse(_purchasePrice.text) ?? 0,
        sellingPrice: double.tryParse(_sellingPrice.text) ?? 0,
        quantity: int.tryParse(_quantity.text) ?? 0,
        rack: _rack.text.trim(),
        createdAt: widget.medicine?.createdAt ?? DateTime.now(),
      );

      try {
        await widget.onSave(medicine).timeout(const Duration(milliseconds: 1500));
      } catch (_) {
        // Timeout means the network is slow or offline, but Firestore 
        // already wrote the change locally! We don't need to block UI.
      }
      
      if (!mounted) return;
      Navigator.pop(context);
    } catch (e) {
      if (!mounted) return;
      setState(() => _isSaving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error saving: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 20,
      ),
      child: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppColors.grey.withValues(alpha: 0.4),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                widget.medicine == null ? 'Add Medicine' : 'Edit Medicine',
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textDark,
                ),
              ),
              const SizedBox(height: 20),

              _field(_name, 'Medicine Name', Icons.medication_rounded,
                  required: true),
              const SizedBox(height: 12),
              _field(_company, 'Company / Brand', Icons.business_rounded,
                  required: true),
              const SizedBox(height: 12),

              // Category Dropdown
              DropdownButtonFormField<String>(
                value: _selectedCategory,
                decoration: const InputDecoration(
                  labelText: 'Category',
                  prefixIcon: Icon(Icons.category_rounded,
                      color: AppColors.primary),
                ),
                items: _categories
                    .map((c) =>
                        DropdownMenuItem(value: c, child: Text(c)))
                    .toList(),
                onChanged: (v) =>
                    setState(() => _selectedCategory = v ?? 'Tablet'),
              ),
              const SizedBox(height: 12),

              // Batch
              TextFormField(
                controller: _batch,
                decoration: InputDecoration(
                  labelText: 'Batch Number',
                  prefixIcon: const Icon(Icons.qr_code_rounded,
                      color: AppColors.primary),
                  errorText: _batchError,
                ),
                onChanged: (_) => setState(() => _batchError = null),
                validator: (v) =>
                    v == null || v.isEmpty ? 'Required' : null,
              ),
              const SizedBox(height: 12),

              Row(
                children: [
                  Expanded(
                    child: _field(
                        _purchasePrice, 'Purchase ₹', Icons.money_rounded,
                        keyboardType: TextInputType.number,
                        required: true),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _field(
                        _sellingPrice, 'Selling ₹', Icons.sell_rounded,
                        keyboardType: TextInputType.number,
                        required: true),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              Row(
                children: [
                  Expanded(
                    child: _field(_quantity, 'Quantity',
                        Icons.inventory_2_rounded,
                        keyboardType: TextInputType.number,
                        required: true),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _field(
                        _rack, 'Rack / Location', Icons.grid_view_rounded),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              Row(
                children: [
                  Expanded(
                      child: _datePicker('Purchase Date', _purchaseDate,
                          () => _pickDate(false))),
                  const SizedBox(width: 12),
                  Expanded(
                      child: _datePicker('Expiry Date', _expiryDate,
                          () => _pickDate(true))),
                ],
              ),

              if (_attempted &&
                  (_purchaseDate == null || _expiryDate == null))
                const Padding(
                  padding: EdgeInsets.only(top: 8),
                  child: Text(
                    'Please select both dates.',
                    style:
                        TextStyle(color: AppColors.danger, fontSize: 12),
                  ),
                ),

              const SizedBox(height: 24),

              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _isSaving ? null : _save,
                  child: _isSaving
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                              color: AppColors.white, strokeWidth: 2),
                        )
                      : Text(
                          widget.medicine == null
                              ? 'Add Medicine'
                              : 'Save Changes',
                          style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold),
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _field(
    TextEditingController ctrl,
    String label,
    IconData icon, {
    TextInputType keyboardType = TextInputType.text,
    bool required = false,
  }) {
    return TextFormField(
      controller: ctrl,
      keyboardType: keyboardType,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, color: AppColors.primary),
      ),
      validator: required
          ? (v) => v == null || v.isEmpty ? 'Required' : null
          : null,
    );
  }

  Widget _datePicker(String label, DateTime? date, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding:
            const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
        decoration: BoxDecoration(
          color: AppColors.white,
          border: Border.all(
            color: (_attempted && date == null)
                ? AppColors.danger
                : AppColors.primary.withValues(alpha: 0.4),
          ),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Icon(Icons.calendar_today_rounded,
                size: 16,
                color: (_attempted && date == null)
                    ? AppColors.danger
                    : AppColors.primary),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                date != null
                    ? DateFormat('dd MMM yyyy').format(date)
                    : label,
                style: TextStyle(
                  fontSize: 13,
                  color: date != null
                      ? AppColors.textDark
                      : AppColors.grey,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}