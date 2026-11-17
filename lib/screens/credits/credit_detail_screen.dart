import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../utils/theme.dart';
import '../../utils/errors.dart';
import '../../utils/form_dialog.dart';
import '../../services/api_service.dart';
import '../../models/credit_entry.dart';
import '../../widgets/ui_kit.dart';
import 'add_credit_entry_screen.dart';

class CreditDetailScreen extends StatefulWidget {
  final String customerName;

  const CreditDetailScreen({super.key, required this.customerName});

  @override
  State<CreditDetailScreen> createState() => _CreditDetailScreenState();
}

class _CreditDetailScreenState extends State<CreditDetailScreen> {
  static const List<String> _tabLabels = ['Overview', 'Payments', 'Notes'];

  List<CreditEntry> _entries = [];
  bool _isLoading = true;
  double _totalGiven = 0;
  double _totalReturned = 0;
  double _pendingAmount = 0;
  int _selectedTab = 0;

  @override
  void initState() {
    super.initState();
    _loadEntries();
  }

  Future<void> _loadEntries() async {
    setState(() => _isLoading = true);
    try {
      final entries = await ApiService.getCreditEntries(customer: widget.customerName);
      double given = 0;
      double returned = 0;
      for (final e in entries) {
        if (e.entryType == 'given') {
          given += e.amount;
        } else {
          returned += e.amount;
        }
      }
      if (!mounted) return;
      setState(() {
        _entries = entries;
        _totalGiven = given;
        _totalReturned = returned;
        _pendingAmount = given - returned;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      showApiError(context, e);
    }
  }

  Future<void> _deleteEntry(CreditEntry entry) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Entry'),
        content: const Text('Are you sure you want to delete this entry?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete', style: TextStyle(color: AppTheme.errorColor)),
          ),
        ],
      ),
    );
    if (!mounted) return;
    if (confirm == true) {
      try {
        await ApiService.deleteCreditEntry(entry.id);
        if (!mounted) return;
        _loadEntries();
      } catch (e) {
        if (!mounted) return;
        showApiError(context, e);
      }
    }
  }

  double get _settlementRate => _totalGiven > 0 ? _totalReturned / _totalGiven : 0.0;

  String _initials() {
    final name = widget.customerName.trim();
    return name.isNotEmpty ? name[0].toUpperCase() : '?';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ScreenHeader(
            showBack: true,
            title: 'Customer Details',
            actions: [
              HeaderIconButton(
                icon: Icons.person_add_alt_1_rounded,
                color: AppTheme.primaryColor,
                onTap: () => _addEntry('given'),
              ),
              const SizedBox(width: 8),
              HeaderIconButton(
                icon: Icons.savings_outlined,
                color: AppTheme.primaryColor,
                onTap: () => _addEntry('returned'),
              ),
            ],
          ),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator(color: AppTheme.primaryColor))
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
                        child: _buildCustomerCard(),
                      ),
                      const SizedBox(height: 14),
                      _buildTabBar(),
                      const SizedBox(height: 12),
                      Expanded(child: _buildTabContent()),
                    ],
                  ),
          ),
        ],
      ),
      bottomNavigationBar: Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          border: Border(top: BorderSide(color: AppTheme.borderLight, width: 0.6)),
        ),
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
        child: SafeArea(
          top: false,
          child: PrimaryButton(
            label: 'Add Repayment',
            icon: Icons.savings_outlined,
            onPressed: () => _addEntry('returned'),
          ),
        ),
      ),
    );
  }

  // ─── Customer summary card ───

  Widget _buildCustomerCard() {
    final phone = _entries.isNotEmpty ? _entries.first.customerPhone : '';

    return SectionCard(
      child: Column(
        children: [
          Row(
            children: [
              Container(
                width: 56,
                height: 56,
                alignment: Alignment.center,
                decoration: const BoxDecoration(
                  color: AppTheme.tintGreenBg,
                  shape: BoxShape.circle,
                ),
                child: Text(
                  _initials(),
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    color: AppTheme.primaryColor,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.customerName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: AppTheme.textPrimary,
                      ),
                    ),
                    if (phone.isNotEmpty) ...[
                      const SizedBox(height: 3),
                      Text(
                        phone,
                        style: const TextStyle(
                          fontSize: 12.5,
                          color: AppTheme.textSecondary,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          KeyValueRow(
            label: 'Total Credit',
            value: '₹${_totalGiven.toStringAsFixed(0)}',
            valueColor: AppTheme.errorColor,
            bold: true,
          ),
          KeyValueRow(
            label: 'Total Repaid',
            value: '₹${_totalReturned.toStringAsFixed(0)}',
            valueColor: AppTheme.successColor,
            bold: true,
          ),
          KeyValueRow(
            label: 'Outstanding',
            value: '₹${_pendingAmount.toStringAsFixed(0)}',
            valueColor: AppTheme.errorColor,
            bold: true,
          ),
          const SizedBox(height: 6),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Settlement Rate',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.textSecondary,
                ),
              ),
              Text(
                '${(_settlementRate * 100).toStringAsFixed(1)}%',
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                  color: AppTheme.successColor,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ProgressBar(value: _settlementRate),
        ],
      ),
    );
  }

  // ─── Segmented tabs ───

  Widget _buildTabBar() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: List.generate(_tabLabels.length, (i) {
          final selected = _selectedTab == i;
          return Padding(
            padding: EdgeInsets.only(right: i == _tabLabels.length - 1 ? 0 : 6),
            child: GestureDetector(
              onTap: () => setState(() => _selectedTab = i),
              behavior: HitTestBehavior.opaque,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 8),
                decoration: BoxDecoration(
                  color: selected ? AppTheme.primaryColor : Colors.transparent,
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  _tabLabels[i],
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                    color: selected ? Colors.white : AppTheme.textSecondary,
                  ),
                ),
              ),
            ),
          );
        }),
      ),
    );
  }

  Widget _buildTabContent() {
    switch (_selectedTab) {
      case 1:
        return _buildPaymentsTab();
      case 2:
        return _buildNotesTab();
      default:
        return _buildOverviewTab();
    }
  }

  // ─── Overview tab ───

  Widget _buildOverviewTab() {
    final givenEntries = _entries.where((e) => e.entryType == 'given').toList();
    DateTime? creditDate;
    for (final e in givenEntries) {
      if (creditDate == null || e.date.isAfter(creditDate)) creditDate = e.date;
    }
    DateTime? firstDate;
    for (final e in _entries) {
      if (firstDate == null || e.date.isBefore(firstDate)) firstDate = e.date;
    }
    final dueDate = creditDate?.add(const Duration(days: 30));
    final dateFormat = DateFormat('dd MMM yyyy');

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(
                  child: _buildInfoTile(
                    label: 'Credit Date',
                    icon: Icons.calendar_today_outlined,
                    color: AppTheme.iconBlue,
                    background: AppTheme.tintBlueBg,
                    value: Text(
                      creditDate != null ? dateFormat.format(creditDate) : '—',
                      style: const TextStyle(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.textPrimary,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _buildInfoTile(
                    label: 'Due Date',
                    icon: Icons.event_rounded,
                    color: AppTheme.iconAmber,
                    background: AppTheme.tintAmberBg,
                    value: Text(
                      dueDate != null ? dateFormat.format(dueDate) : '—',
                      style: const TextStyle(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.textPrimary,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(
                  child: _buildInfoTile(
                    label: 'Status',
                    icon: Icons.hourglass_bottom_rounded,
                    color: AppTheme.iconAmber,
                    background: AppTheme.tintAmberBg,
                    value: _pendingAmount > 0 ? StatusPill.pending() : StatusPill.paid(),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _buildInfoTile(
                    label: 'Customer Since',
                    icon: Icons.person_outline,
                    color: AppTheme.iconPurple,
                    background: AppTheme.tintPurpleBg,
                    value: Text(
                      firstDate != null ? dateFormat.format(firstDate) : '—',
                      style: const TextStyle(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.textPrimary,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          SectionCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const CardHeader(title: 'Payment History', icon: Icons.history),
                const SizedBox(height: 12),
                _buildTimelineList(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoTile({
    required String label,
    required IconData icon,
    required Color color,
    required Color background,
    required Widget value,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: AppTheme.cardDecoration,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          IconTile(icon: icon, color: color, background: background, size: 34),
          const SizedBox(height: 10),
          Text(
            label,
            style: const TextStyle(fontSize: 11, color: AppTheme.textSecondary),
          ),
          const SizedBox(height: 4),
          value,
        ],
      ),
    );
  }

  // ─── Payments tab (timeline) ───

  Widget _buildPaymentsTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      child: SectionCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const CardHeader(title: 'Payment History', icon: Icons.history),
            const SizedBox(height: 12),
            _buildTimelineList(),
          ],
        ),
      ),
    );
  }

  Widget _buildTimelineList() {
    if (_entries.isEmpty) {
      return const Center(
        child: EmptyState(
          icon: Icons.receipt_long_rounded,
          title: 'No entries found',
        ),
      );
    }
    return Column(
      children: [
        for (var i = 0; i < _entries.length; i++)
          _buildTimelineItem(_entries[i], isLast: i == _entries.length - 1),
      ],
    );
  }

  Widget _buildTimelineItem(CreditEntry entry, {required bool isLast}) {
    final isGiven = entry.entryType == 'given';
    final amountColor = isGiven ? AppTheme.errorColor : AppTheme.successColor;
    final typeLabel = isGiven ? 'Credit Given' : 'Repayment';
    final dateLabel = DateFormat('dd MMM yyyy').format(entry.date);

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Column(
            children: [
              Container(
                width: 12,
                height: 12,
                decoration: BoxDecoration(
                  color: AppTheme.primaryColor,
                  shape: BoxShape.circle,
                  border: Border.all(color: AppTheme.tintGreenBg, width: 3),
                ),
              ),
              if (!isLast)
                Expanded(
                  child: Container(
                    width: 2,
                    margin: const EdgeInsets.only(top: 4),
                    color: AppTheme.borderLight,
                  ),
                ),
            ],
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Container(
              margin: EdgeInsets.only(bottom: isLast ? 0 : 12),
              padding: const EdgeInsets.all(12),
              decoration: AppTheme.cardDecoration,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          '₹${entry.amount.toStringAsFixed(0)}',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w800,
                            color: amountColor,
                          ),
                        ),
                      ),
                      if (isGiven)
                        const StatusPill(
                          label: 'Pending',
                          color: AppTheme.iconRed,
                          background: AppTheme.tintRedBg,
                        )
                      else
                        StatusPill.paid(),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '$typeLabel · $dateLabel',
                    style: const TextStyle(
                      fontSize: 11.5,
                      color: AppTheme.textSecondary,
                    ),
                  ),
                  if (entry.remarks.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      entry.remarks,
                      style: const TextStyle(
                        fontSize: 11,
                        color: AppTheme.textMuted,
                      ),
                    ),
                  ],
                  if (entry.bankAccountName.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        const Icon(Icons.account_balance_outlined,
                            size: 13, color: AppTheme.textSecondary),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            entry.bankAccountNumber.isNotEmpty
                                ? '${entry.bankAccountName} • ${entry.bankAccountNumber}'
                                : entry.bankAccountName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 10.5,
                              color: AppTheme.textSecondary,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                  if (entry.entryType == 'returned' && !entry.toBank) ...[
                    const SizedBox(height: 4),
                    const Row(
                      children: [
                        Icon(Icons.payments_outlined,
                            size: 13, color: AppTheme.iconAmber),
                        SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            'Cash in hand — bank balance unchanged',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 10.5,
                              color: AppTheme.textSecondary,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      PopupMenuButton<String>(
                        padding: EdgeInsets.zero,
                        icon: const Icon(
                          Icons.more_vert_rounded,
                          size: 16,
                          color: AppTheme.textMuted,
                        ),
                        onSelected: (v) {
                          if (v == 'delete') _deleteEntry(entry);
                        },
                        itemBuilder: (ctx) => const [
                          PopupMenuItem(
                            value: 'delete',
                            child: Text(
                              'Delete',
                              style: TextStyle(color: AppTheme.errorColor),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ─── Notes tab ───

  Widget _buildNotesTab() {
    final notes = _entries.where((e) => e.remarks.trim().isNotEmpty).toList();
    if (notes.isEmpty) {
      return const Center(
        child: EmptyState(
          icon: Icons.notes_outlined,
          title: 'No notes yet',
          message: 'Remarks you add to an entry will show up here.',
        ),
      );
    }
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      children: notes.map(_buildNoteCard).toList(),
    );
  }

  Widget _buildNoteCard(CreditEntry entry) {
    final isGiven = entry.entryType == 'given';

    return SectionCard(
      margin: const EdgeInsets.only(bottom: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  '₹${entry.amount.toStringAsFixed(0)}',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    color: isGiven ? AppTheme.errorColor : AppTheme.successColor,
                  ),
                ),
              ),
              Text(
                DateFormat('dd MMM yyyy').format(entry.date),
                style: const TextStyle(
                  fontSize: 11.5,
                  color: AppTheme.textSecondary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            entry.remarks,
            style: const TextStyle(
              fontSize: 12.5,
              color: AppTheme.textPrimary,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }

  void _addEntry(String type) async {
    await showFormDialog(
      context,
      AddCreditEntryScreen(
        customerName: widget.customerName,
        entryType: type,
      ),
    );
    if (!mounted) return;
    _loadEntries();
  }
}
