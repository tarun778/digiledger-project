import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../utils/theme.dart';
import '../../utils/download_helper.dart';
import '../../utils/errors.dart';
import '../../utils/form_dialog.dart';
import '../../services/api_service.dart';
import '../../widgets/date_range_dropdown.dart';
import '../../widgets/searchable_dropdown.dart';
import '../../widgets/ui_kit.dart';
import 'credit_detail_screen.dart';
import 'add_credit_entry_screen.dart';

class PendingPaymentsScreen extends StatefulWidget {
  const PendingPaymentsScreen({super.key});

  @override
  State<PendingPaymentsScreen> createState() => _PendingPaymentsScreenState();
}

class _PendingPaymentsScreenState extends State<PendingPaymentsScreen> {
  List<Map<String, dynamic>> _customers = [];
  List<Map<String, dynamic>> _filteredCustomers = [];
  bool _isLoading = true;

  String _selectedCustomerFilter = 'All Customers';
  String _selectedStatusFilter = 'All';
  DateTimeRange? _selectedDateRange;
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();

  int _currentPage = 0;
  final int _rowsPerPage = 10;

  @override
  void initState() {
    super.initState();
    _loadSummary();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  String _getStatus(Map<String, dynamic> cust) {
    final pending = (cust['pending_amount'] ?? 0).toDouble();
    final totalReturned = (cust['total_returned'] ?? 0).toDouble();
    if (pending <= 0) return 'Settled';
    if (totalReturned > 0) return 'Partial';
    return 'Pending';
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'Settled':
        return AppTheme.iconGreen;
      case 'Partial':
        return AppTheme.iconAmber;
      case 'Pending':
        return AppTheme.iconRed;
      default:
        return AppTheme.textSecondary;
    }
  }

  Color _getStatusBgColor(String status) {
    switch (status) {
      case 'Settled':
        return AppTheme.tintGreenBg;
      case 'Partial':
        return AppTheme.tintAmberBg;
      case 'Pending':
        return AppTheme.tintRedBg;
      default:
        return AppTheme.tintGreyBg;
    }
  }

  Future<void> _loadSummary() async {
    setState(() => _isLoading = true);
    try {
      final summary = await ApiService.getCreditSummary();
      final customers = List<Map<String, dynamic>>.from(summary['customers'] ?? []);

      final Map<String, Map<String, dynamic>> merged = {};
      for (final c in customers) {
        final name = (c['customer_name'] ?? '').toString().trim().toLowerCase();
        if (!merged.containsKey(name)) {
          merged[name] = Map<String, dynamic>.from(c);
        } else {
          final existing = merged[name]!;
          final cDate = (c['last_date'] ?? '').toString();
          final eDate = (existing['last_date'] ?? '').toString();
          if (cDate.compareTo(eDate) > 0) {
            merged[name] = Map<String, dynamic>.from(c);
          }
        }
      }

      final deduped = merged.values.toList();
      deduped.sort((a, b) {
        final aDate = (a['last_date'] ?? '').toString();
        final bDate = (b['last_date'] ?? '').toString();
        return bDate.compareTo(aDate);
      });

      if (!mounted) return;
      setState(() {
        _customers = deduped;
        _isLoading = false;
      });
      _applyFilters();
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      showApiError(context, e);
    }
  }

  String _csvField(String value) {
    if (value.contains(',') || value.contains('"') || value.contains('\n') || value.contains('\r')) {
      return '"${value.replaceAll('"', '""')}"';
    }
    return value;
  }

  Future<void> _exportCsv() async {
    try {
      final entries = await ApiService.getCreditEntries();
      if (!mounted) return;
      final buffer = StringBuffer();
      buffer.writeln('Date,Customer,Phone,Entry Type,Amount,Payment Method,Remarks');
      for (final entry in entries) {
        final paymentMethod = entry.bankAccountName.isNotEmpty
            ? entry.bankAccountName
            : (entry.toBank ? 'Bank' : 'Cash');
        final row = [
          DateFormat('yyyy-MM-dd').format(entry.date),
          entry.customerName,
          entry.customerPhone,
          entry.entryType == 'given' ? 'Given' : 'Returned',
          entry.amount.toStringAsFixed(2),
          paymentMethod,
          entry.remarks,
        ];
        buffer.writeln(row.map(_csvField).join(','));
      }
      final bytes = Uint8List.fromList(utf8.encode(buffer.toString()));
      final now = DateTime.now();
      final stamp = '${now.year.toString().padLeft(4, '0')}'
          '${now.month.toString().padLeft(2, '0')}'
          '${now.day.toString().padLeft(2, '0')}_'
          '${now.hour.toString().padLeft(2, '0')}'
          '${now.minute.toString().padLeft(2, '0')}'
          '${now.second.toString().padLeft(2, '0')}';
      final filename = 'credit_entries_$stamp.csv';
      final ok = DownloadHelper.downloadBytes(bytes, filename, mimeType: 'text/csv');
      if (!mounted) return;
      if (ok) {
        showApiSuccess(context, 'Downloaded: $filename');
      } else {
        showApiError(context, 'Export is available on the web version of DigiLedger');
      }
    } catch (e) {
      if (!mounted) return;
      showApiError(context, e);
    }
  }

  void _applyFilters() {
    List<Map<String, dynamic>> result = List.from(_customers);

    if (_selectedCustomerFilter != 'All Customers') {
      result = result.where((c) => c['customer_name'] == _selectedCustomerFilter).toList();
    }

    if (_selectedStatusFilter != 'All') {
      result = result.where((c) => _getStatus(c) == _selectedStatusFilter).toList();
    }

    if (_searchQuery.isNotEmpty) {
      final query = _searchQuery.toLowerCase();
      result = result.where((c) {
        final name = (c['customer_name'] ?? '').toString().toLowerCase();
        final phone = (c['customer_phone'] ?? '').toString().toLowerCase();
        return name.contains(query) || phone.contains(query);
      }).toList();
    }

    if (_selectedDateRange != null) {
      result = result.where((c) {
        final lastDateStr = c['last_date'] ?? '';
        if (lastDateStr.isEmpty) return false;
        try {
          final date = DateTime.parse(lastDateStr);
          return date.isAfter(_selectedDateRange!.start.subtract(const Duration(days: 1))) &&
              date.isBefore(_selectedDateRange!.end.add(const Duration(days: 1)));
        } catch (_) {
          return false;
        }
      }).toList();
    }

    setState(() {
      _filteredCustomers = result;
      _currentPage = 0;
    });
  }

  void _resetFilters() {
    setState(() {
      _selectedCustomerFilter = 'All Customers';
      _selectedStatusFilter = 'All';
      _selectedDateRange = null;
      _searchQuery = '';
      _searchController.clear();
    });
    _applyFilters();
  }

  int get _totalPages => (_filteredCustomers.length / _rowsPerPage).ceil().clamp(1, 999);

  List<Map<String, dynamic>> get _paginatedCustomers {
    final start = _currentPage * _rowsPerPage;
    final end = (start + _rowsPerPage).clamp(0, _filteredCustomers.length);
    return _filteredCustomers.sublist(start, end);
  }

  List<String> get _uniqueCustomerNames {
    final names = _customers.map((c) => (c['customer_name'] ?? '').toString()).where((n) => n.isNotEmpty).toSet().toList();
    names.sort();
    return names;
  }

  void _openDetail(Map<String, dynamic> cust) async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => CreditDetailScreen(customerName: cust['customer_name'])),
    );
    if (!mounted) return;
    _loadSummary();
  }

  void _navigateToAdd() async {
    await showFormDialog(context, const AddCreditEntryScreen());
    if (!mounted) return;
    _loadSummary();
  }

  void _showPendingCustomersDialog() {
    double outstandingTotal = 0;
    for (final c in _filteredCustomers) {
      final p = (c['pending_amount'] ?? 0);
      outstandingTotal += (p is num) ? p.toDouble() : 0;
    }
    final pendingCustomers = _filteredCustomers.where((c) {
      final pending = (c['pending_amount'] ?? 0).toDouble();
      return pending > 0;
    }).toList()..sort((a, b) {
      final aPending = (a['pending_amount'] ?? 0).toDouble();
      final bPending = (b['pending_amount'] ?? 0).toDouble();
      return bPending.compareTo(aPending);
    });

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.7,
        minChildSize: 0.4,
        maxChildSize: 0.9,
        expand: false,
        builder: (ctx, scrollController) => Column(
          children: [
            Container(
              margin: const EdgeInsets.only(top: 8),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: AppTheme.borderLight,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppTheme.tintAmberBg,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.pending_outlined, color: AppTheme.iconAmber, size: 20),
                  ),
                  const SizedBox(width: 10),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Pending Customers', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: AppTheme.textPrimary)),
                        Text('Customers who still need to pay', style: TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
                      ],
                    ),
                  ),
                  Text(
                    '${pendingCustomers.length} customers',
                    style: const TextStyle(fontSize: 12, color: AppTheme.iconAmber, fontWeight: FontWeight.w700),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: pendingCustomers.isEmpty
                  ? const Center(child: Text('All customers are settled!', style: TextStyle(color: AppTheme.textSecondary)))
                  : ListView.separated(
                      controller: scrollController,
                      itemCount: pendingCustomers.length,
                      separatorBuilder: (_, __) => const Divider(height: 1, indent: 70),
                      itemBuilder: (context, index) {
                        final cust = pendingCustomers[index];
                        final name = cust['customer_name'] ?? '';
                        final phone = cust['customer_phone'] ?? '';
                        final pending = (cust['pending_amount'] ?? 0).toDouble();
                        final totalCredit = (cust['total_given'] ?? 0).toDouble();
                        final repaid = (cust['total_returned'] ?? 0).toDouble();
                        final initials = name.isNotEmpty ? name[0].toUpperCase() : '?';
                        final status = _getStatus(cust);

                        return ListTile(
                          onTap: () {
                            Navigator.pop(ctx);
                            _openDetail(cust);
                          },
                          leading: CircleAvatar(
                            backgroundColor: _getStatusBgColor(status),
                            child: Text(initials, style: TextStyle(color: _getStatusColor(status), fontWeight: FontWeight.w700, fontSize: 16)),
                          ),
                          title: Text(name, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14, color: AppTheme.textPrimary)),
                          subtitle: Text(
                            phone.isNotEmpty ? phone : '$totalCredit credit | $repaid repaid',
                            style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary),
                          ),
                          trailing: Text(
                            '₹${pending.toStringAsFixed(0)}',
                            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: AppTheme.errorColor),
                          ),
                        );
                      },
                    ),
            ),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: const BoxDecoration(
                color: AppTheme.surfaceLight,
                border: Border(top: BorderSide(color: AppTheme.borderLight)),
              ),
              child: Row(
                children: [
                  const Text('Total Outstanding', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppTheme.textPrimary)),
                  const Spacer(),
                  Text(
                    '₹${outstandingTotal.toStringAsFixed(0)}',
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: AppTheme.errorColor),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _navigateToAdd,
        backgroundColor: AppTheme.primaryDark,
        icon: const Icon(Icons.add, color: Colors.white),
        label: const Text('Add Credit',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 14)),
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const ScreenHeader(
            title: 'Pending Credits',
            subtitle: 'Track and manage all customer credit payments',
            leadingIcon: Icons.storefront_rounded,
          ),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator(color: AppTheme.primaryColor))
                : _customers.isEmpty
                    ? const Center(
                        child: EmptyState(
                          icon: Icons.receipt_long_rounded,
                          title: 'No pending payments',
                          message: 'Tap "Add Credit" to record credit given to a customer',
                        ),
                      )
                    : RefreshIndicator(
                        onRefresh: _loadSummary,
                        color: AppTheme.primaryColor,
                        child: LayoutBuilder(
                          builder: (context, constraints) {
                            final isWide = constraints.maxWidth > 900;
                            return SingleChildScrollView(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  _buildSummaryCards(isWide),
                                  _buildFilterBar(),
                                  if (isWide)
                                    _buildWideLayout()
                                  else
                                    _buildMobileLayout(),
                                  SizedBox(height: isWide ? 72 : 100),
                                ],
                              ),
                            );
                          },
                        ),
                      ),
          ),
        ],
      ),
    );
  }

  // ─── Stats ───

  Widget _buildSummaryCards(bool isWide) {
    double totalCredit = 0;
    double totalRepaid = 0;
    double outstanding = 0;
    for (final c in _filteredCustomers) {
      totalCredit += (c['total_given'] is num) ? (c['total_given'] as num).toDouble() : 0;
      totalRepaid += (c['total_returned'] is num) ? (c['total_returned'] as num).toDouble() : 0;
      outstanding += (c['pending_amount'] is num) ? (c['pending_amount'] as num).toDouble() : 0;
    }
    final cards = [
      MiniStatCard(
        label: 'Total Customers',
        value: '${_filteredCustomers.length}',
        icon: Icons.people_alt_outlined,
        color: AppTheme.iconBlue,
        background: AppTheme.tintBlueBg,
      ),
      MiniStatCard(
        label: 'Total Credit',
        value: '₹${totalCredit.toStringAsFixed(0)}',
        icon: Icons.account_balance_wallet_outlined,
        color: AppTheme.iconRed,
        background: AppTheme.tintRedBg,
      ),
      MiniStatCard(
        label: 'Total Repaid',
        value: '₹${totalRepaid.toStringAsFixed(0)}',
        icon: Icons.check_circle_outline,
        color: AppTheme.iconGreen,
        background: AppTheme.tintGreenBg,
      ),
      MiniStatCard(
        label: 'Outstanding',
        value: '₹${outstanding.toStringAsFixed(0)}',
        icon: Icons.hourglass_bottom_rounded,
        color: AppTheme.iconAmber,
        background: AppTheme.tintAmberBg,
        onTap: _showPendingCustomersDialog,
      ),
    ];

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      child: StatGrid(cards: cards, columns: isWide ? 4 : 2),
    );
  }

  // ─── Filters ───

  Widget _buildFilterBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      child: SectionCard(
        padding: const EdgeInsets.all(12),
        child: LayoutBuilder(
          builder: (context, constraints) {
            if (constraints.maxWidth > 1080) {
              return Row(
                children: [
                  Expanded(flex: 3, child: _buildCustomerDropdown()),
                  const SizedBox(width: 10),
                  Expanded(flex: 2, child: _buildStatusDropdown()),
                  const SizedBox(width: 10),
                  Expanded(flex: 3, child: _buildDateRangeButton()),
                  const SizedBox(width: 10),
                  Expanded(flex: 4, child: _buildSearchField()),
                  const SizedBox(width: 10),
                  _buildSearchButton(),
                  const SizedBox(width: 8),
                  _buildResetButton(),
                  const SizedBox(width: 8),
                  _buildExportButton(),
                ],
              );
            }
            if (constraints.maxWidth > 700) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      Expanded(flex: 2, child: _buildCustomerDropdown()),
                      const SizedBox(width: 10),
                      Expanded(flex: 2, child: _buildStatusDropdown()),
                      const SizedBox(width: 10),
                      Expanded(flex: 3, child: _buildDateRangeButton()),
                      const SizedBox(width: 10),
                      Expanded(flex: 3, child: _buildSearchField()),
                    ],
                  ),
                  const SizedBox(height: 10),
                  _buildButtonRow(),
                ],
              );
            }
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Expanded(child: _buildCustomerDropdown()),
                    const SizedBox(width: 8),
                    Expanded(child: _buildStatusDropdown()),
                  ],
                ),
                const SizedBox(height: 8),
                _buildDateRangeButton(),
                const SizedBox(height: 8),
                _buildSearchField(),
                const SizedBox(height: 10),
                _buildButtonRow(),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildSearchButton() {
    return PrimaryButton(
      label: 'Search',
      icon: Icons.search_rounded,
      expanded: false,
      height: 44,
      onPressed: _applyFilters,
    );
  }

  Widget _buildResetButton() {
    return DarkButton(
      label: 'Reset',
      icon: Icons.refresh_rounded,
      onPressed: _resetFilters,
    );
  }

  Widget _buildExportButton() {
    return PrimaryButton(
      label: 'Export',
      icon: Icons.ios_share_rounded,
      expanded: false,
      height: 44,
      onPressed: _exportCsv,
    );
  }

  Widget _buildButtonRow() {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        _buildSearchButton(),
        _buildResetButton(),
        _buildExportButton(),
      ],
    );
  }

  Widget _buildCustomerDropdown() {
    final allSelected = _selectedCustomerFilter == 'All Customers';
    return SearchableDropdown<String>(
      items: _uniqueCustomerNames
          .map((name) => SearchableDropdownItem(value: name, label: name))
          .toList(),
      value: allSelected ? null : _selectedCustomerFilter,
      hint: 'All Customers',
      searchHint: 'Search customers…',
      allLabel: 'All Customers',
      allowOther: true,
      otherLabel: 'Other…',
      dense: true,
      fontSize: 13,
      fillColor: Colors.white,
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      onChanged: (val) {
        setState(() => _selectedCustomerFilter =
            (val == null || val.isEmpty) ? 'All Customers' : val);
      },
    );
  }

  Widget _buildStatusDropdown() {
    const labels = {
      'All': 'All Status',
      'Pending': 'Pending',
      'Partial': 'Partial',
      'Settled': 'Settled',
    };
    return SearchableDropdown<String>(
      items: labels.entries
          .map((e) => SearchableDropdownItem(value: e.key, label: e.value))
          .toList(),
      value: _selectedStatusFilter,
      hint: 'All Status',
      searchHint: 'Search status…',
      allLabel: 'All Status',
      allowOther: true,
      otherLabel: 'Other…',
      dense: true,
      fontSize: 13,
      fillColor: Colors.white,
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      onChanged: (val) {
        setState(() =>
            _selectedStatusFilter = (val == null || val.isEmpty) ? 'All' : val);
      },
    );
  }

  Widget _buildDateRangeButton() {
    return SizedBox(
      width: double.infinity,
      child: DateRangeDropdown(
        selectedRange: _selectedDateRange,
        compact: true,
        accentColor: AppTheme.primaryColor,
        onRangeChanged: (range) {
          setState(() => _selectedDateRange = range);
        },
      ),
    );
  }

  Widget _buildSearchField() {
    return SearchField(
      controller: _searchController,
      hint: 'Search by name or phone...',
      onChanged: (val) => setState(() => _searchQuery = val),
    );
  }

  // ─── Records ───

  Widget _buildRecordsHeader() {
    return Row(
      children: [
        const Icon(Icons.receipt_long_rounded, size: 18, color: AppTheme.primaryColor),
        const SizedBox(width: 8),
        Text(
          'Credit Records (${_filteredCustomers.length})',
          style: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w700,
            color: AppTheme.textPrimary,
          ),
        ),
      ],
    );
  }

  Widget _buildWideLayout() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: 3,
            child: Column(
              children: [
                _buildDataTable(),
                _buildPagination(horizontalPadding: 0),
              ],
            ),
          ),
          const SizedBox(width: 16),
          SizedBox(
            width: 320,
            child: Column(
              children: [
                _buildCollectionSummary(),
                const SizedBox(height: 12),
                _buildRecentCreditActivities(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMobileLayout() {
    return Column(
      children: [
        _buildRecordCards(),
        _buildPagination(),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
          child: _buildCollectionSummary(),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
          child: _buildRecentCreditActivities(),
        ),
      ],
    );
  }

  Widget _buildRecordCards() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildRecordsHeader(),
          const SizedBox(height: 10),
          if (_filteredCustomers.isEmpty)
            const SectionCard(
              padding: EdgeInsets.all(40),
              child: Center(
                child: Text(
                  'No matching records found',
                  style: TextStyle(color: AppTheme.textSecondary, fontSize: 14),
                ),
              ),
            )
          else
            ..._paginatedCustomers.map(_buildRecordCard),
        ],
      ),
    );
  }

  String _lastAccountLine(Map<String, dynamic> cust) {
    final name = (cust['last_account'] ?? '').toString().trim();
    if (name.isEmpty) return '';
    final number = (cust['last_account_number'] ?? '').toString().trim();
    final masked = number.length > 4
        ? '•••• ${number.substring(number.length - 4)}'
        : number;
    if (masked.isEmpty) return 'Last entry via $name';
    return 'Last entry via $name $masked';
  }

  Widget _buildRecordCard(Map<String, dynamic> cust) {
    final name = (cust['customer_name'] ?? '').toString();
    final creditDate = (cust['last_date'] ?? '-').toString();
    final totalCredit = (cust['total_given'] ?? 0).toDouble();
    final repaid = (cust['total_returned'] ?? 0).toDouble();
    final pending = (cust['pending_amount'] ?? 0).toDouble();
    final status = _getStatus(cust);
    final statusColor = _getStatusColor(status);
    final statusBg = _getStatusBgColor(status);
    final initials = name.isNotEmpty ? name[0].toUpperCase() : '?';
    final lastAccountLine = _lastAccountLine(cust);

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: AppTheme.cardDecoration,
      child: Material(
        type: MaterialType.transparency,
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: () => _openDetail(cust),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(color: statusBg, shape: BoxShape.circle),
                  child: Text(
                    initials,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: statusColor,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        name,
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
                        creditDate,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 11,
                          color: AppTheme.textSecondary,
                        ),
                      ),
                      if (lastAccountLine.isNotEmpty) ...[
                        const SizedBox(height: 3),
                        Row(
                          children: [
                            const Icon(Icons.account_balance_outlined,
                                size: 14, color: AppTheme.textSecondary),
                            const SizedBox(width: 4),
                            Expanded(
                              child: Text(
                                lastAccountLine,
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
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      '₹${totalCredit.toStringAsFixed(0)}',
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        color: AppTheme.errorColor,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '₹${repaid.toStringAsFixed(0)} paid',
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.successColor,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: AppTheme.tintRedBg,
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        '₹${pending.toStringAsFixed(0)} pending',
                        style: const TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          color: AppTheme.errorColor,
                        ),
                      ),
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

  Widget _buildDataTable() {
    if (_filteredCustomers.isEmpty) {
      return const SectionCard(
        padding: EdgeInsets.all(40),
        child: Center(
          child: Text(
            'No matching records found',
            style: TextStyle(color: AppTheme.textSecondary, fontSize: 14),
          ),
        ),
      );
    }

    return SectionCard(
      padding: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
            child: _buildRecordsHeader(),
          ),
          const Divider(height: 1),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: ConstrainedBox(
              constraints: BoxConstraints(minWidth: MediaQuery.of(context).size.width > 900 ? 920 : 920),
              child: DataTable(
                headingRowColor: WidgetStateProperty.all(AppTheme.surfaceLight),
                headingTextStyle: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.textSecondary,
                  letterSpacing: 0.5,
                ),
                dataTextStyle: const TextStyle(fontSize: 12, color: AppTheme.textPrimary),
                columnSpacing: 20,
                horizontalMargin: 16,
                columns: const [
                  DataColumn(label: Text('#')),
                  DataColumn(label: Text('Customer')),
                  DataColumn(label: Text('Phone')),
                  DataColumn(label: Text('Credit Date')),
                  DataColumn(label: Text('Credit Amount')),
                  DataColumn(label: Text('Repaid')),
                  DataColumn(label: Text('Pending')),
                  DataColumn(label: Text('Status')),
                  DataColumn(label: Text('Actions')),
                ],
                rows: List.generate(_paginatedCustomers.length, (index) {
                  final cust = _paginatedCustomers[index];
                  final globalIndex = _currentPage * _rowsPerPage + index + 1;
                  return _buildDataRow(cust, globalIndex);
                }),
              ),
            ),
          ),
        ],
      ),
    );
  }

  DataRow _buildDataRow(Map<String, dynamic> cust, int index) {
    final name = cust['customer_name'] ?? '';
    final phone = cust['customer_phone'] ?? '-';
    final creditDate = cust['last_date'] ?? '-';
    final totalCredit = (cust['total_given'] ?? 0).toDouble();
    final pending = (cust['pending_amount'] ?? 0).toDouble();
    final repaid = (cust['total_returned'] ?? 0).toDouble();
    final status = _getStatus(cust);
    final statusColor = _getStatusColor(status);
    final statusBg = _getStatusBgColor(status);
    final initials = name.isNotEmpty ? name[0].toUpperCase() : '?';

    return DataRow(
      cells: [
        DataCell(Text('$index', style: const TextStyle(fontSize: 11, color: AppTheme.textSecondary))),
        DataCell(
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircleAvatar(
                radius: 14,
                backgroundColor: statusBg,
                child: Text(
                  initials,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: statusColor,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                name,
                style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12),
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
        DataCell(Text(phone, style: const TextStyle(fontSize: 12))),
        DataCell(Text(creditDate, style: const TextStyle(fontSize: 11, color: AppTheme.textSecondary))),
        DataCell(Text(
          '₹${totalCredit.toStringAsFixed(0)}',
          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12),
        )),
        DataCell(Text(
          '₹${repaid.toStringAsFixed(0)}',
          style: TextStyle(
              fontWeight: FontWeight.w600,
              fontSize: 12,
              color: repaid > 0 ? AppTheme.successColor : AppTheme.textSecondary),
        )),
        DataCell(Text(
          '₹${pending.toStringAsFixed(0)}',
          style: TextStyle(
            fontWeight: FontWeight.w700,
            fontSize: 12,
            color: pending > 0 ? AppTheme.errorColor : AppTheme.successColor,
          ),
        )),
        DataCell(
          StatusPill(
            label: status,
            color: statusColor,
            background: statusBg,
          ),
        ),
        DataCell(
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildActionIcon(
                icon: Icons.visibility_outlined,
                color: AppTheme.iconBlue,
                background: AppTheme.tintBlueBg,
                onTap: () => _openDetail(cust),
              ),
              const SizedBox(width: 4),
              _buildActionIcon(
                icon: Icons.edit_outlined,
                color: AppTheme.iconAmber,
                background: AppTheme.tintAmberBg,
                onTap: () => _openDetail(cust),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildActionIcon({
    required IconData icon,
    required Color color,
    required Color background,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(6),
      child: Container(
        padding: const EdgeInsets.all(5),
        decoration: BoxDecoration(
          color: background,
          borderRadius: BorderRadius.circular(6),
        ),
        child: Icon(icon, size: 16, color: color),
      ),
    );
  }

  // ─── Pagination ───

  Widget _buildPagination({double horizontalPadding = 16}) {
    if (_filteredCustomers.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: EdgeInsets.fromLTRB(horizontalPadding, 12, horizontalPadding, 0),
      child: SectionCard(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Showing ${_currentPage * _rowsPerPage + 1}-${((_currentPage + 1) * _rowsPerPage).clamp(0, _filteredCustomers.length)} of ${_filteredCustomers.length}',
              style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary),
            ),
            Row(
              children: [
                _buildPageButton(
                  icon: Icons.chevron_left,
                  enabled: _currentPage > 0,
                  onTap: () => setState(() => _currentPage--),
                ),
                const SizedBox(width: 4),
                ...List.generate(_totalPages, (i) {
                  if (_totalPages > 7) {
                    if (i == 0 || i == _totalPages - 1 || (i >= _currentPage - 1 && i <= _currentPage + 1)) {
                      return _buildPageNumber(i);
                    }
                    if (i == _currentPage - 2 || i == _currentPage + 2) {
                      return const Padding(
                        padding: EdgeInsets.symmetric(horizontal: 4),
                        child: Text('...', style: TextStyle(color: AppTheme.textSecondary)),
                      );
                    }
                    return const SizedBox.shrink();
                  }
                  return _buildPageNumber(i);
                }),
                const SizedBox(width: 4),
                _buildPageButton(
                  icon: Icons.chevron_right,
                  enabled: _currentPage < _totalPages - 1,
                  onTap: () => setState(() => _currentPage++),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPageButton({required IconData icon, required bool enabled, required VoidCallback onTap}) {
    return InkWell(
      onTap: enabled ? onTap : null,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.all(6),
        decoration: BoxDecoration(
          color: enabled ? AppTheme.primaryColor.withValues(alpha: 0.08) : AppTheme.tintGreyBg,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(
          icon,
          size: 18,
          color: enabled ? AppTheme.primaryColor : AppTheme.textMuted,
        ),
      ),
    );
  }

  Widget _buildPageNumber(int page) {
    final isActive = page == _currentPage;
    return InkWell(
      onTap: () => setState(() => _currentPage = page),
      borderRadius: BorderRadius.circular(8),
      child: Container(
        width: 32,
        height: 32,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: isActive ? AppTheme.primaryColor : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(
          '${page + 1}',
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: isActive ? Colors.white : AppTheme.textPrimary,
          ),
        ),
      ),
    );
  }

  // ─── Collection summary ───

  Widget _buildCollectionSummary() {
    double totalCredit = 0;
    double totalRepaid = 0;
    double outstanding = 0;
    for (final c in _filteredCustomers) {
      totalCredit += (c['total_given'] is num) ? (c['total_given'] as num).toDouble() : 0;
      totalRepaid += (c['total_returned'] is num) ? (c['total_returned'] as num).toDouble() : 0;
      outstanding += (c['pending_amount'] is num) ? (c['pending_amount'] as num).toDouble() : 0;
    }
    final rate = totalCredit > 0 ? totalRepaid / totalCredit : 0.0;

    return SectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const CardHeader(title: 'Collection Summary', icon: Icons.pie_chart_outline),
          const SizedBox(height: 8),
          KeyValueRow(
            label: 'Total Credit',
            value: '₹${totalCredit.toStringAsFixed(0)}',
            valueColor: AppTheme.errorColor,
            bold: true,
          ),
          KeyValueRow(
            label: 'Total Repaid',
            value: '₹${totalRepaid.toStringAsFixed(0)}',
            valueColor: AppTheme.successColor,
            bold: true,
          ),
          KeyValueRow(
            label: 'Outstanding',
            value: '₹${outstanding.toStringAsFixed(0)}',
            valueColor: AppTheme.warningColor,
            bold: true,
          ),
          const SizedBox(height: 6),
          const Divider(),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Settlement Rate',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppTheme.textSecondary),
              ),
              Text(
                '${(rate * 100).toStringAsFixed(1)}%',
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                  color: AppTheme.successColor,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ProgressBar(value: rate),
        ],
      ),
    );
  }

  // ─── Recent activities ───

  Widget _buildRecentCreditActivities() {
    final recentCustomers = List<Map<String, dynamic>>.from(_customers)
      ..sort((a, b) {
        final aDate = a['last_date'] ?? '';
        final bDate = b['last_date'] ?? '';
        return bDate.compareTo(aDate);
      });
    final displayList = recentCustomers.take(8).toList();

    return SectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const CardHeader(title: 'Recent Credit Activities', icon: Icons.history),
          const SizedBox(height: 8),
          if (displayList.isEmpty)
            const Center(
              child: Padding(
                padding: EdgeInsets.all(20),
                child: Text(
                  'No recent activities',
                  style: TextStyle(color: AppTheme.textSecondary, fontSize: 13),
                ),
              ),
            )
          else
            ...displayList.map(_buildActivityItem),
        ],
      ),
    );
  }

  Widget _buildActivityItem(Map<String, dynamic> cust) {
    final name = (cust['customer_name'] ?? '').toString();
    final totalCredit = (cust['total_given'] ?? 0).toDouble();
    final date = cust['last_date'] ?? '-';
    final initials = name.isNotEmpty ? name[0].toUpperCase() : '?';
    final status = _getStatus(cust);
    final statusColor = _getStatusColor(status);
    final statusBg = _getStatusBgColor(status);

    return InkWell(
      onTap: () => _openDetail(cust),
      borderRadius: BorderRadius.circular(10),
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: AppTheme.surfaceLight,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: AppTheme.borderLight, width: 0.6),
        ),
        child: Row(
          children: [
            Container(
              width: 34,
              height: 34,
              alignment: Alignment.center,
              decoration: BoxDecoration(color: statusBg, shape: BoxShape.circle),
              child: Text(
                initials,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: statusColor,
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 12.5,
                      color: AppTheme.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    date,
                    style: const TextStyle(color: AppTheme.textSecondary, fontSize: 10.5),
                  ),
                  if (_lastAccountLine(cust).isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        const Icon(Icons.account_balance_outlined,
                            size: 13, color: AppTheme.textSecondary),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            _lastAccountLine(cust),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                                color: AppTheme.textSecondary, fontSize: 10),
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 8),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  '₹${totalCredit.toStringAsFixed(0)}',
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 13,
                    color: AppTheme.textPrimary,
                  ),
                ),
                const SizedBox(height: 4),
                StatusPill(label: status, color: statusColor, background: statusBg),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
