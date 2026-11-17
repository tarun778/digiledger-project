import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../utils/theme.dart';
import '../../utils/download_helper.dart';
import '../../utils/errors.dart';
import '../../utils/form_dialog.dart';
import '../../services/api_service.dart';
import '../../models/cc_bill_payment.dart';
import '../../widgets/date_range_dropdown.dart';
import '../../widgets/searchable_dropdown.dart';
import '../../widgets/ui_kit.dart';
import 'add_cc_bill_screen.dart';

class CCBillListScreen extends StatefulWidget {
  const CCBillListScreen({super.key});

  @override
  State<CCBillListScreen> createState() => _CCBillListScreenState();
}

class _CCBillListScreenState extends State<CCBillListScreen> {
  List<CCBillPayment> _ccBillPayments = [];
  bool _isLoading = true;
  String? _selectedBank;
  DateTime? _dateFrom;
  DateTime? _dateTo;
  String _statusFilter = 'All Bills';
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadCCBillPayments();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadCCBillPayments() async {
    setState(() => _isLoading = true);
    try {
      final payments = await ApiService.getCCBillPayments(
        bankName: _selectedBank,
        dateFrom: _dateFrom?.toIso8601String().split('T')[0],
        dateTo: _dateTo?.toIso8601String().split('T')[0],
      );
      if (!mounted) return;
      setState(() {
        _ccBillPayments = payments;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      showApiError(context, e);
    }
  }

  // ── Status helpers ──

  bool _isPaid(CCBillPayment bill) =>
      bill.amountPaid > 0 && bill.amountPaid >= bill.billAmount;

  bool _isOverdue(CCBillPayment bill) {
    if (_isPaid(bill) || bill.dueDate == null) return false;
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final due = bill.dueDate!;
    return DateTime(due.year, due.month, due.day).isBefore(today);
  }

  bool _isDueThisWeek(CCBillPayment bill) {
    if (_isPaid(bill) || bill.dueDate == null) return false;
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final due = DateTime(
        bill.dueDate!.year, bill.dueDate!.month, bill.dueDate!.day);
    return !due.isBefore(today) &&
        due.isBefore(today.add(const Duration(days: 7)));
  }

  String _money(num value) => '₹${value.toStringAsFixed(2)}';

  // ── Derived data ──

  List<CCBillPayment> get _visibleBills {
    var list = List<CCBillPayment>.from(_ccBillPayments);

    final query = _searchQuery.trim().toLowerCase();
    if (query.isNotEmpty) {
      list = list
          .where((b) =>
              b.bankLabel.toLowerCase().contains(query) ||
              b.customerName.toLowerCase().contains(query) ||
              b.customerPhone.contains(query) ||
              b.cardLast4.contains(query))
          .toList();
    }

    switch (_statusFilter) {
      case 'Paid':
        list = list.where(_isPaid).toList();
        break;
      case 'Pending':
        list = list.where((b) => !_isPaid(b) && !_isOverdue(b)).toList();
        break;
      case 'Overdue':
        list = list.where(_isOverdue).toList();
        break;
    }

    return list;
  }

  double get _totalAmount =>
      _visibleBills.fold(0.0, (sum, b) => sum + b.billAmount);

  double get _paidAmount =>
      _visibleBills.fold(0.0, (sum, b) => sum + b.amountPaid);

  double get _pendingAmount {
    final pending = _totalAmount - _paidAmount;
    return pending < 0 ? 0 : pending;
  }

  int get _overdueCount => _visibleBills.where(_isOverdue).length;

  int get _dueThisWeekCount =>
      _visibleBills.where(_isDueThisWeek).length;

  // ── UI ──

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: AppTheme.primaryColor))
          : RefreshIndicator(
              onRefresh: _loadCCBillPayments,
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: EdgeInsets.zero,
                children: [
                  ScreenHeader(
                    title: 'CC Bills',
                    subtitle: 'Manage your credit card bills',
                    leadingIcon: Icons.credit_card_rounded,
                    actions: [
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          HeaderIconButton(
                            icon: Icons.file_download_rounded,
                            onTap: _exportCCBills,
                          ),
                          const SizedBox(width: 6),
                          HeaderIconButton(
                            icon: Icons.filter_list_rounded,
                            onTap: _showFilterSheet,
                          ),
                          const SizedBox(width: 6),
                          HeaderIconButton(
                            icon: Icons.refresh_rounded,
                            onTap: _loadCCBillPayments,
                          ),
                        ],
                      ),
                    ],
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        SearchField(
                          controller: _searchController,
                          hint: 'Search by bank or card...',
                          onChanged: (value) =>
                              setState(() => _searchQuery = value),
                        ),
                        const SizedBox(height: 12),
                        _buildStatTiles(),
                        const SizedBox(height: 14),
                        ChipSelector(
                          options: const [
                            'All Bills',
                            'Paid',
                            'Pending',
                            'Overdue'
                          ],
                          selected: _statusFilter,
                          onChanged: (value) =>
                              setState(() => _statusFilter = value),
                        ),
                        const SizedBox(height: 12),
                      ],
                    ),
                  ),
                  _buildBillList(),
                ],
              ),
            ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: AppTheme.primaryDark,
        onPressed: () async {
          await showFormDialog(context, const AddCCBillScreen());
          if (!mounted) return;
          _loadCCBillPayments();
        },
        icon: const Icon(Icons.add, color: Colors.white, size: 24),
        label: const Text(
          'Add Bill',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w700,
            fontSize: 14,
          ),
        ),
      ),
    );
  }

  Widget _buildStatTiles() {
    final tiles = <Widget>[
      MiniStatCard(
        label: 'Total Bills',
        value: '${_visibleBills.length}',
        icon: Icons.receipt_long_outlined,
        color: AppTheme.iconAmber,
        background: AppTheme.tintAmberBg,
      ),
      MiniStatCard(
        label: 'Total Amount',
        value: _money(_totalAmount),
        icon: Icons.account_balance_wallet_outlined,
        color: AppTheme.iconGreen,
        background: AppTheme.tintGreenBg,
      ),
      MiniStatCard(
        label: 'Paid Amount',
        value: _money(_paidAmount),
        icon: Icons.check_circle_outline,
        color: AppTheme.iconGreen,
        background: AppTheme.tintGreenBg,
      ),
      MiniStatCard(
        label: 'Pending',
        value: _money(_pendingAmount),
        icon: Icons.pending_actions_outlined,
        color: AppTheme.iconRed,
        background: AppTheme.tintRedBg,
      ),
    ];

    if (_overdueCount > 0 || _dueThisWeekCount > 0) {
      tiles.add(
        MiniStatCard(
          label: 'Overdue',
          value: '$_overdueCount',
          icon: Icons.warning_amber_outlined,
          color: AppTheme.iconRed,
          background: AppTheme.tintRedBg,
        ),
      );
      tiles.add(
        MiniStatCard(
          label: 'Due This Week',
          value: '$_dueThisWeekCount',
          icon: Icons.event_available_outlined,
          color: AppTheme.iconBlue,
          background: AppTheme.tintBlueBg,
        ),
      );
    }

    return StatGrid(cards: tiles);
  }

  Widget _buildBillList() {
    final bills = _visibleBills;

    if (bills.isEmpty) {
      final filtered = _searchQuery.trim().isNotEmpty ||
          _statusFilter != 'All Bills';
      return EmptyState(
        icon: Icons.credit_card_rounded,
        title: filtered ? 'No bills match your filters' : 'No CC bill payments yet',
        message: filtered
            ? 'Try a different search or filter'
            : 'Tap Add Bill to record your first payment',
      );
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 92),
      child: Column(
        children: bills.map(_buildCCBillCard).toList(),
      ),
    );
  }

  Widget _buildCCBillCard(CCBillPayment bill) {
    final StatusPill status = _isPaid(bill)
        ? StatusPill.paid()
        : (_isOverdue(bill) ? StatusPill.overdue() : StatusPill.pending());
    final title = bill.cardLast4.isNotEmpty
        ? '${bill.bankLabel} •••• ${bill.cardLast4}'
        : bill.bankLabel;
    final dueText = bill.dueDate != null
        ? 'Due: ${DateFormat('d MMM yyyy').format(bill.dueDate!)}'
        : 'No due date';
    final meta = StringBuffer(bill.customerName);
    meta.write(' • ${DateFormat('MMM d, yyyy').format(bill.date)}');
    if (bill.transactionRef.isNotEmpty) meta.write(' • ${bill.transactionRef}');

    return SectionCard(
      margin: const EdgeInsets.only(bottom: 10),
      padding: EdgeInsets.zero,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: () => _showBillDetails(bill),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const IconTile(
                      icon: Icons.credit_card_rounded,
                      color: AppTheme.iconBlue,
                      background: AppTheme.tintBlueBg,
                      size: 42,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              color: AppTheme.textPrimary,
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            dueText,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 11,
                              color: AppTheme.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 10),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          _money(bill.billAmount),
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w800,
                            color: AppTheme.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 5),
                        status,
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        meta.toString(),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 11,
                          color: AppTheme.textMuted,
                        ),
                      ),
                    ),
                    PopupMenuButton<String>(
                      padding: EdgeInsets.zero,
                      splashRadius: 18,
                      icon: const Icon(Icons.more_vert_rounded,
                          size: 18, color: AppTheme.textSecondary),
                      itemBuilder: (context) => [
                        const PopupMenuItem(
                          value: 'delete',
                          child: Row(
                            children: [
                              Icon(Icons.delete_rounded,
                                  color: AppTheme.errorColor, size: 20),
                              SizedBox(width: 8),
                              Text('Delete'),
                            ],
                          ),
                        ),
                      ],
                      onSelected: (value) {
                        if (value == 'delete') {
                          _deleteCCBillPayment(bill.id);
                        }
                      },
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showBillDetails(CCBillPayment bill) {
    final status = _isPaid(bill)
        ? StatusPill.paid()
        : (_isOverdue(bill) ? StatusPill.overdue() : StatusPill.pending());

    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 38,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppTheme.borderLight,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  const IconTile(
                    icon: Icons.credit_card_rounded,
                    color: AppTheme.iconBlue,
                    background: AppTheme.tintBlueBg,
                    size: 38,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          bill.bankLabel,
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w800,
                            color: AppTheme.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          bill.customerName,
                          style: const TextStyle(
                            fontSize: 12,
                            color: AppTheme.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  status,
                ],
              ),
              const SizedBox(height: 12),
              KeyValueRow(label: 'Bill Amount', value: _money(bill.billAmount), bold: true),
              KeyValueRow(
                label: 'Amount Paid',
                value: _money(bill.amountPaid),
                valueColor: AppTheme.successColor,
                bold: true,
              ),
              KeyValueRow(label: 'Service Charges', value: _money(bill.serviceCharges)),
              KeyValueRow(
                label: 'Profit',
                value: _money(bill.profit),
                valueColor: AppTheme.successColor,
              ),
              KeyValueRow(
                label: 'Credited to',
                value: bill.toBank ? 'Bank account' : 'Cash in hand',
                valueColor:
                    bill.toBank ? AppTheme.successColor : AppTheme.iconAmber,
              ),
              KeyValueRow(label: 'Phone', value: bill.customerPhone),
              KeyValueRow(
                label: 'Card',
                value: bill.cardLast4.isNotEmpty ? '**** ${bill.cardLast4}' : '—',
              ),
              KeyValueRow(
                label: 'Due Date',
                value: bill.dueDate != null
                    ? DateFormat('d MMM yyyy').format(bill.dueDate!)
                    : '—',
              ),
              KeyValueRow(
                label: 'Payment Date',
                value: DateFormat('d MMM yyyy').format(bill.date),
              ),
              KeyValueRow(
                label: 'Payment Method',
                value: bill.paymentMethod.replaceAll('_', ' '),
              ),
              if (bill.transactionRef.isNotEmpty)
                KeyValueRow(label: 'Reference', value: bill.transactionRef),
              if (bill.remarks.isNotEmpty)
                KeyValueRow(label: 'Remarks', value: bill.remarks),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _deleteCCBillPayment(String id) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Payment'),
        content: const Text('Are you sure you want to delete this payment?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: AppTheme.errorColor),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (!mounted) return;
    if (confirmed == true) {
      try {
        await ApiService.deleteCCBillPayment(id);
        if (!mounted) return;
        _loadCCBillPayments();
        showApiSuccess(context, 'Payment deleted');
      } catch (e) {
        if (!mounted) return;
        showApiError(context, e);
      }
    }
  }

  Future<void> _exportCCBills() async {
    try {
      final response = await ApiService.exportCCBills();
      if (response.statusCode == 200) {
        final bytes = response.bodyBytes;
        final disposition = response.headers['content-disposition'] ?? '';
        final filename = disposition.replaceAll('attachment; filename=', '').replaceAll('"', '');
        final ok = DownloadHelper.downloadBytes(
          bytes,
          filename,
          mimeType:
              'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
        );
        if (!mounted) return;
        if (ok) {
          showApiSuccess(context, 'Downloaded: $filename');
        } else {
          showApiError(
              context, 'Export is available on the web version of DigiLedger');
        }
      }
    } catch (e) {
      if (!mounted) return;
      showApiError(context, e);
    }
  }

  void _showFilterSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Filter CC Bill Payments',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 20),
              DateRangeDropdown(
                selectedRange: _dateFrom != null && _dateTo != null
                    ? DateTimeRange(start: _dateFrom!, end: _dateTo!)
                    : null,
                onRangeChanged: (range) {
                  if (range != null) {
                    setState(() {
                      _dateFrom = range.start;
                      _dateTo = range.end;
                    });
                  } else {
                    setState(() {
                      _dateFrom = null;
                      _dateTo = null;
                    });
                  }
                },
              ),
              const SizedBox(height: 16),
              SearchableDropdown<String>(
                items: const [
                  SearchableDropdownItem(value: 'sbi', label: 'SBI'),
                  SearchableDropdownItem(value: 'hdfc', label: 'HDFC'),
                  SearchableDropdownItem(value: 'icici', label: 'ICICI'),
                  SearchableDropdownItem(value: 'axis', label: 'Axis'),
                  SearchableDropdownItem(value: 'kotak', label: 'Kotak'),
                  SearchableDropdownItem(value: 'yes_bank', label: 'Yes Bank'),
                  SearchableDropdownItem(value: 'other', label: 'Other'),
                ],
                value: _selectedBank,
                hint: 'All Banks',
                searchHint: 'Search banks…',
                allLabel: 'All Banks',
                allowOther: true,
                otherLabel: 'Other…',
                labelText: 'Bank',
                onChanged: (value) {
                  setState(() => _selectedBank = value);
                },
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () {
                        setState(() {
                          _dateFrom = null;
                          _dateTo = null;
                          _selectedBank = null;
                        });
                        Navigator.pop(context);
                        _loadCCBillPayments();
                      },
                      child: const Text('Clear'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () {
                        Navigator.pop(context);
                        _loadCCBillPayments();
                      },
                      child: const Text('Apply'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}
