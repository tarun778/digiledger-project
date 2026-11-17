import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../utils/theme.dart';
import '../../utils/errors.dart';
import '../../utils/download_helper.dart';
import '../../utils/form_dialog.dart';
import '../../services/api_service.dart';
import '../../providers/auth_provider.dart';
import '../../widgets/date_range_dropdown.dart';
import '../../widgets/ui_kit.dart';
import '../transactions/add_transaction_screen.dart';
import '../cc_bills/add_cc_bill_screen.dart';
import '../credits/add_credit_entry_screen.dart';

class DashboardScreen extends StatefulWidget {
  final VoidCallback? onMenuTap;
  final void Function(String tabLabel)? onNavigateTab;
  const DashboardScreen({super.key, this.onMenuTap, this.onNavigateTab});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  Map<String, dynamic>? _dashboardData;
  Map<String, dynamic>? _chartData;
  bool _isLoading = true;
  String _chartPeriod = 'weekly';
  bool _isChartLoading = false;
  DateTimeRange _chartDateRange = DateTimeRange(
    start: DateTime.now().subtract(const Duration(days: 7)),
    end: DateTime.now(),
  );

  @override
  void initState() {
    super.initState();
    _loadDashboard();
  }

  Future<void> _loadDashboard() async {
    setState(() => _isLoading = true);
    try {
      final data = await ApiService.getDashboard();
      if (mounted) setState(() => _dashboardData = data);
    } catch (e) {
      if (mounted) {
        showApiError(context, e);
      }
    }
    try {
      final chart = await ApiService.getChartData(_chartPeriod);
      if (mounted) setState(() => _chartData = chart);
    } catch (e) {
      if (mounted) {
        showApiError(context, e);
      }
    }
    if (mounted) setState(() => _isLoading = false);
  }

  Future<void> _exportDashboard() async {
    String format = 'pdf';
    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: const Text('Export Dashboard'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('Choose export format:', style: TextStyle(fontSize: 14)),
              const SizedBox(height: 16),
              ListTile(
                leading: Container(
                  width: 20, height: 20,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: format == 'pdf' ? AppTheme.primaryColor : Colors.grey, width: 2),
                  ),
                  child: format == 'pdf' ? Center(child: Container(width: 10, height: 10, decoration: const BoxDecoration(shape: BoxShape.circle, color: AppTheme.primaryColor))) : null,
                ),
                title: const Text('PDF'),
                onTap: () => setDialogState(() => format = 'pdf'),
              ),
              ListTile(
                leading: Container(
                  width: 20, height: 20,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: format == 'excel' ? AppTheme.primaryColor : Colors.grey, width: 2),
                  ),
                  child: format == 'excel' ? Center(child: Container(width: 10, height: 10, decoration: const BoxDecoration(shape: BoxShape.circle, color: AppTheme.primaryColor))) : null,
                ),
                title: const Text('Excel (XLSX)'),
                onTap: () => setDialogState(() => format = 'excel'),
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(ctx);
                _doExportDashboard(format);
              },
              style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primaryColor, foregroundColor: Colors.white),
              child: const Text('Export'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _doExportDashboard(String format) async {
    try {
      final response = await ApiService.exportDashboard(format: format);
      if (response.statusCode == 200) {
        final bytes = response.bodyBytes;
        final disposition = response.headers['content-disposition'] ?? '';
        final filename = disposition.replaceAll('attachment; filename=', '').replaceAll('"', '');
        final mimeType = format == 'pdf' ? 'application/pdf' : 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet';
        final ok = DownloadHelper.downloadBytes(bytes, filename, mimeType: mimeType);
        if (!mounted) return;
        if (ok) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Downloaded: $filename'), backgroundColor: AppTheme.successColor),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Export is available on the web version of DigiLedger'),
              backgroundColor: AppTheme.errorColor,
            ),
          );
        }
      }
    } catch (e) {
      if (!mounted) return;
      showApiError(context, e);
    }
  }

  Future<void> _loadChart(String period) async {
    setState(() {
      _chartPeriod = period;
      _isChartLoading = true;
    });
    try {
      final dateFrom = '${_chartDateRange.start.year}-${_chartDateRange.start.month.toString().padLeft(2, '0')}-${_chartDateRange.start.day.toString().padLeft(2, '0')}';
      final dateTo = '${_chartDateRange.end.year}-${_chartDateRange.end.month.toString().padLeft(2, '0')}-${_chartDateRange.end.day.toString().padLeft(2, '0')}';
      final chart = await ApiService.getChartData(period, dateFrom: dateFrom, dateTo: dateTo);
      if (mounted) {
        setState(() {
          _chartData = chart;
          _isChartLoading = false;
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _isChartLoading = false);
      showApiError(context, e);
    }
  }

  String _getGreeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Good Morning';
    if (hour < 17) return 'Good Afternoon';
    return 'Good Evening';
  }

  String _getGreetingEmoji() {
    final hour = DateTime.now().hour;
    if (hour < 12) return '🌅';
    if (hour < 17) return '☀️';
    return '🌙';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: AppTheme.primaryColor))
          : RefreshIndicator(
              onRefresh: _loadDashboard,
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final isWide = constraints.maxWidth > 900;
                  if (isWide) {
                    return _buildWideLayout();
                  }
                  return _buildMobileLayout();
                },
              ),
            ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showNewEntrySheet,
        backgroundColor: AppTheme.primaryDark,
        elevation: 4,
        icon: const Icon(Icons.add_rounded, color: Colors.white, size: 24),
        label: const Text('New Entry',
            style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w700,
                fontSize: 14)),
      ),
    );
  }

  /// "Add New Entry" chooser — mirrors the mockup's options sheet.
  void _showNewEntrySheet() {
    final options = [
      (
        'Add Transaction',
        'Add money in or out from your business',
        Icons.swap_horiz_rounded,
        AppTheme.iconGreen,
        AppTheme.tintGreenBg,
        () async {
          await showFormDialog(context, const AddTransactionScreen());
          if (!mounted) return;
          _loadDashboard();
        },
      ),
      (
        'Add CC Bill Payment',
        'Record credit card bill payments',
        Icons.credit_card_rounded,
        AppTheme.iconPurple,
        AppTheme.tintPurpleBg,
        () async {
          await showFormDialog(context, const AddCCBillScreen());
          if (!mounted) return;
          _loadDashboard();
        },
      ),
      (
        'Add Credit Entry',
        'Give credit to a customer',
        Icons.person_add_alt_1_rounded,
        AppTheme.iconAmber,
        AppTheme.tintAmberBg,
        () async {
          await showFormDialog(context, const AddCreditEntryScreen());
          if (!mounted) return;
          _loadDashboard();
        },
      ),
      (
        'Add Repayment',
        'Record customer repayment',
        Icons.savings_outlined,
        AppTheme.iconBlue,
        AppTheme.tintBlueBg,
        () async {
          await showFormDialog(
              context, const AddCreditEntryScreen(entryType: 'returned'));
          if (!mounted) return;
          _loadDashboard();
        },
      ),
    ];

    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
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
              const Text(
                'Add New Entry',
                style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                    color: AppTheme.textPrimary),
              ),
              const SizedBox(height: 2),
              const Text(
                'Choose what you want to add',
                style:
                    TextStyle(fontSize: 12, color: AppTheme.textSecondary),
              ),
              const SizedBox(height: 12),
              ...options.map(
                (o) => ListTile(
                  contentPadding: const EdgeInsets.symmetric(
                      horizontal: 4, vertical: 2),
                  leading: IconTile(
                      icon: o.$3, color: o.$4, background: o.$5),
                  title: Text(
                    o.$1,
                    style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: AppTheme.textPrimary),
                  ),
                  subtitle: Text(
                    o.$2,
                    style: const TextStyle(
                        fontSize: 11.5, color: AppTheme.textSecondary),
                  ),
                  trailing: const Icon(Icons.chevron_right_rounded,
                      size: 20, color: AppTheme.textMuted),
                  onTap: () {
                    Navigator.of(ctx).pop();
                    o.$6();
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ─── Wide layout (>900px): left column + right sidebar ───

  Widget _buildWideLayout() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (widget.onMenuTap != null)
          Padding(
            padding: const EdgeInsets.only(left: 8, top: 12),
            child: IconButton(
              onPressed: widget.onMenuTap,
              icon: const Icon(Icons.menu_rounded,
                  color: AppTheme.textPrimary, size: 24),
            ),
          ),
        Expanded(
          flex: 3,
          child: SingleChildScrollView(
            padding:
                const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildHeader(),
                const SizedBox(height: 16),
                _buildTodayCollection(),
                const SizedBox(height: 16),
                _buildStatsRow(isWide: true),
                const SizedBox(height: 16),
                _buildRevenueOverview(),
                const SizedBox(height: 16),
                _buildPromoCard(),
              ],
            ),
          ),
        ),
        SizedBox(
          width: 300,
          child: SingleChildScrollView(
            padding: const EdgeInsets.only(right: 16, top: 16, left: 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildQuickActionsSection(isWide: true),
                const SizedBox(height: 16),
                _buildRecentTransactionsSidebar(),
              ],
            ),
          ),
        ),
      ],
    );
  }

  // ─── Mobile layout: single column ───

  Widget _buildMobileLayout() {
    return SafeArea(
      bottom: false,
      child: ListView(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
      children: [
        _buildMobileHeader(),
        const SizedBox(height: 14),
        _buildDateRangeBar(),
        const SizedBox(height: 14),
        _buildTodayCollection(),
        const SizedBox(height: 14),
        _buildStatsRow(isWide: false),
        const SizedBox(height: 14),
        _buildRevenueOverview(),
        const SizedBox(height: 14),
        _buildQuickActionsSection(isWide: false),
        const SizedBox(height: 14),
        _buildRecentTransactionsMobile(),
        const SizedBox(height: 14),
        _buildPromoCard(),
      ],
      ),
    );
  }

  // ─── Mobile header: greeting + shop name ───

  Widget _buildMobileHeader() {
    return Padding(
      padding: const EdgeInsets.only(top: 8, bottom: 2),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(9),
            decoration: BoxDecoration(
              color: AppTheme.tintGreenBg,
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.storefront_rounded,
                size: 20, color: AppTheme.primaryColor),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      '${_getGreeting()} ',
                      style: const TextStyle(
                          fontSize: 12, color: AppTheme.textSecondary),
                    ),
                    Text(_getGreetingEmoji(),
                        style: const TextStyle(fontSize: 13)),
                  ],
                ),
                const SizedBox(height: 1),
                Consumer<AuthProvider>(
                  builder: (_, auth, __) => Row(
                    children: [
                      Flexible(
                        child: Text(
                          auth.user?.shopName ?? 'My Shop',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w800,
                            color: AppTheme.textPrimary,
                          ),
                        ),
                      ),
                      const Icon(Icons.keyboard_arrow_down_rounded,
                          size: 18, color: AppTheme.textSecondary),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDateRangeBar() {
    return Row(
      children: [
        Expanded(
          child: SizedBox(
            width: double.infinity,
            child: DateRangeDropdown(
              selectedRange: _chartDateRange,
              compact: true,
              onRangeChanged: (range) {
                if (range != null) {
                  setState(() => _chartDateRange = range);
                  _loadChart(_chartPeriod);
                }
              },
            ),
          ),
        ),
        const SizedBox(width: 8),
        HeaderIconButton(
          icon: Icons.file_download_outlined,
          onTap: _exportDashboard,
        ),
      ],
    );
  }

  // ─── 1. Header ───

  Widget _buildHeader() {
    final tagline = Text(
      'Smarter Books\nBrighter Business',
      textAlign: TextAlign.end,
      style: TextStyle(
        fontSize: 11,
        fontWeight: FontWeight.w600,
        color: const Color(0xFF1B5E20).withValues(alpha: 0.6),
        height: 1.3,
      ),
    );
    final controls = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        DateRangeDropdown(
          selectedRange: _chartDateRange,
          compact: true,
          onRangeChanged: (range) {
            if (range != null) {
              setState(() => _chartDateRange = range);
              _loadChart(_chartPeriod);
            }
          },
        ),
        const SizedBox(width: 8),
        IconButton(
          onPressed: _exportDashboard,
          icon: const Icon(Icons.file_download_outlined,
              color: AppTheme.textSecondary, size: 22),
          tooltip: 'Export',
        ),
      ],
    );
    final titleColumn = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              '${_getGreeting()} ',
              style: const TextStyle(
                fontSize: 14,
                color: AppTheme.textSecondary,
              ),
            ),
            Text(
              _getGreetingEmoji(),
              style: const TextStyle(fontSize: 16),
            ),
          ],
        ),
        const SizedBox(height: 2),
        Consumer<AuthProvider>(
          builder: (_, auth, __) => Text(
            auth.user?.shopName ?? 'My Shop',
            style: const TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: AppTheme.textPrimary,
            ),
          ),
        ),
        const SizedBox(height: 2),
        Text(
          "Here's your business overview for today.",
          style: TextStyle(
            fontSize: 13,
            color: AppTheme.textSecondary.withValues(alpha: 0.7),
          ),
        ),
      ],
    );

    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < 640) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(child: titleColumn),
                  const SizedBox(width: 8),
                  tagline,
                ],
              ),
              const SizedBox(height: 10),
              controls,
            ],
          );
        }
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: titleColumn),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [tagline, const SizedBox(height: 6), controls],
            ),
          ],
        );
      },
    );
  }

  // ─── 2. Today's Collection ───

  Widget _buildTodayCollection() {
    final todayRevenue = _dashboardData?['today_revenue'] ?? 0;
    final todayProfit = _dashboardData?['today_profit'] ?? 0;
    final todayTxns = _dashboardData?['today_transactions'] ?? 0;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [
            Color(0xFF16A34A),
            Color(0xFF15803D),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF15803D).withValues(alpha: 0.32),
            blurRadius: 16,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  "Today's Collection",
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 8),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(
                    '₹$todayRevenue',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 32,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.8,
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Icon(Icons.trending_up_rounded,
                        color: Colors.white.withValues(alpha: 0.9),
                        size: 15),
                    const SizedBox(width: 5),
                    Text(
                      '₹$todayProfit profit · $todayTxns entries today',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.85),
                        fontSize: 11.5,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Container(
            width: 74,
            height: 74,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(18),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    _buildMiniBar(7, 16),
                    const SizedBox(width: 4),
                    _buildMiniBar(7, 26),
                    const SizedBox(width: 4),
                    _buildMiniBar(7, 20),
                    const SizedBox(width: 4),
                    _buildMiniBar(7, 34),
                  ],
                ),
                const SizedBox(height: 6),
                const Icon(Icons.savings_rounded,
                    color: Colors.white, size: 16),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMiniBar(double width, double height) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.75),
        borderRadius: BorderRadius.circular(3),
      ),
    );
  }

  // ─── 3. Stats grid (Revenue / Profit / Entries / Pending) ───

  Widget _buildStatsRow({required bool isWide}) {
    final monthRevenue = _dashboardData?['month_revenue'] ?? 0;
    final monthProfit = _dashboardData?['month_profit'] ?? 0;
    final monthTxns = _dashboardData?['month_transactions'] ?? 0;
    final pendingAmount = _dashboardData?['pending_amount'] ?? 0;

    final stats = [
      const (
        'Revenue',
        Icons.account_balance_wallet_outlined,
        AppTheme.iconGreen,
        AppTheme.tintGreenBg,
      ),
      const (
        'Profit',
        Icons.trending_up_rounded,
        AppTheme.iconBlue,
        AppTheme.tintBlueBg,
      ),
      const (
        'Total Entries',
        Icons.receipt_long_outlined,
        AppTheme.iconAmber,
        AppTheme.tintAmberBg,
      ),
      const (
        'Pending Amount',
        Icons.pending_actions_outlined,
        AppTheme.iconRed,
        AppTheme.tintRedBg,
      ),
    ];
    final values = ['₹$monthRevenue', '₹$monthProfit', '$monthTxns', '₹$pendingAmount'];

    if (isWide) {
      return Row(
        children: List.generate(stats.length, (i) {
          final s = stats[i];
          return Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: StatCard(
                label: s.$1,
                value: values[i],
                icon: s.$2,
                color: s.$3,
                background: s.$4,
              ),
            ),
          );
        }),
      );
    }

    return StatGrid(
      cards: List.generate(stats.length, (i) {
        final s = stats[i];
        return StatCard(
          label: s.$1,
          value: values[i],
          icon: s.$2,
          color: s.$3,
          background: s.$4,
        );
      }),
    );
  }

  // ─── 4. Revenue Overview ───

  Widget _buildRevenueOverview() {
    final labels = (_chartData?['labels'] as List?) ?? [];
    final revenue = (_chartData?['revenue'] as List?) ?? [];
    final profit = (_chartData?['profit'] as List?) ?? [];

    final maxVal = [...revenue, ...profit].fold<double>(0, (a, b) {
      final v = double.tryParse(b.toString()) ?? 0;
      return v > a ? v : a;
    });
    final maxY = maxVal > 0 ? maxVal * 1.3 : 100.0;
    final axisInterval = _chartInterval(maxY);
    final totalRevenue = revenue.fold<double>(0, (sum, raw) {
      return sum + (double.tryParse(raw.toString()) ?? 0);
    });

    final periods = [
      ('weekly', 'Weekly'),
      ('monthly', 'Monthly'),
      ('quarterly', 'Quarterly'),
      ('half_yearly', 'Half-Year'),
      ('yearly', 'Yearly'),
    ];

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppTheme.tintGreenBg,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.bar_chart_rounded,
                    color: AppTheme.primaryColor, size: 20),
              ),
              const SizedBox(width: 10),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Revenue Overview',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: AppTheme.textPrimary),
                    ),
                    SizedBox(height: 2),
                    Text(
                      'Track your revenue growth over time',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                          fontSize: 11, color: AppTheme.textSecondary),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    '₹${NumberFormat.decimalPattern('en_IN').format(totalRevenue)}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                        color: AppTheme.textPrimary),
                  ),
                  const SizedBox(height: 1),
                  const Text(
                    'Revenue',
                    style: TextStyle(
                        fontSize: 10, color: AppTheme.textMuted),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 16),
          // Period tabs
          Container(
            height: 36,
            decoration: BoxDecoration(
              color: const Color(0xFFF0F0F5),
              borderRadius: BorderRadius.circular(10),
            ),
            padding: const EdgeInsets.all(3),
            child: Row(
              children: periods.map((p) {
                final (value, label) = p;
                final isSelected = _chartPeriod == value;
                return Expanded(
                  child: GestureDetector(
                    onTap: () => _loadChart(value),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? const Color(0xFF1B5E20)
                            : Colors.transparent,
                        borderRadius: BorderRadius.circular(8),
                        boxShadow: isSelected
                            ? [
                                BoxShadow(
                                  color: const Color(0xFF1B5E20)
                                      .withValues(alpha: 0.3),
                                  blurRadius: 4,
                                  offset: const Offset(0, 1),
                                ),
                              ]
                            : null,
                      ),
                      child: Center(
                        child: Text(
                          label,
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: isSelected
                                ? FontWeight.w600
                                : FontWeight.w400,
                            color: isSelected
                                ? Colors.white
                                : AppTheme.textSecondary,
                          ),
                        ),
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
          const SizedBox(height: 20),
          // Chart
          SizedBox(
            height: 180,
            child: _isChartLoading
                ? const Center(
                    child:
                        CircularProgressIndicator(strokeWidth: 2))
                : labels.isEmpty
                    ? _buildChartEmptyState()
                    : BarChart(
                        BarChartData(
                          alignment: BarChartAlignment.spaceAround,
                          maxY: maxY,
                          barTouchData: BarTouchData(
                            enabled: true,
                            touchTooltipData: BarTouchTooltipData(
                              getTooltipItem: (group, groupIndex, rod,
                                  rodIndex) {
                                final label =
                                    groupIndex < labels.length
                                        ? labels[groupIndex]
                                        : '';
                                return BarTooltipItem(
                                  '$label\n₹${rod.toY.toInt()}',
                                  const TextStyle(
                                      color: Colors.white,
                                      fontSize: 11,
                                      fontWeight: FontWeight.w500),
                                );
                              },
                            ),
                          ),
                          titlesData: FlTitlesData(
                            show: true,
                            bottomTitles: AxisTitles(
                              sideTitles: SideTitles(
                                showTitles: true,
                                reservedSize: 24,
                                getTitlesWidget: (value, _) {
                                  final idx = value.toInt();
                                  if (idx >= 0 &&
                                      idx < labels.length) {
                                    final showLabel =
                                        labels.length <= 10 ||
                                            idx %
                                                    ((labels.length /
                                                            8)
                                                        .ceil()
                                                        .clamp(
                                                            1,
                                                            labels
                                                                .length)) ==
                                                0;
                                    return showLabel
                                        ? Padding(
                                            padding:
                                                const EdgeInsets.only(
                                                    top: 8),
                                            child: Text(
                                                labels[idx]
                                                    .toString(),
                                                style: const TextStyle(
                                                    fontSize: 9,
                                                    color: Colors
                                                        .grey)),
                                          )
                                        : const SizedBox
                                            .shrink();
                                  }
                                  return const SizedBox.shrink();
                                },
                              ),
                            ),
                            leftTitles: AxisTitles(
                              sideTitles: SideTitles(
                                showTitles: true,
                                reservedSize: 36,
                                interval: axisInterval,
                                getTitlesWidget: (value, meta) {
                                  if (value < 0 || value > maxY) {
                                    return const SizedBox.shrink();
                                  }
                                  final label = value >= 1000
                                      ? '${(value ~/ 1000).toString().padLeft(2, '0')}k'
                                      : value.toInt().toString();
                                  return Padding(
                                    padding: const EdgeInsets.only(right: 8),
                                    child: Text(
                                      label,
                                      textAlign: TextAlign.right,
                                      style: const TextStyle(
                                          fontSize: 9,
                                          color: AppTheme.textMuted),
                                    ),
                                  );
                                },
                              ),
                            ),
                            topTitles: const AxisTitles(
                                sideTitles: SideTitles(
                                    showTitles: false)),
                            rightTitles: const AxisTitles(
                                sideTitles: SideTitles(
                                    showTitles: false)),
                          ),
                          borderData: FlBorderData(show: false),
                          gridData: FlGridData(
                            show: true,
                            drawVerticalLine: false,
                            horizontalInterval: axisInterval,
                            getDrawingHorizontalLine: (value) => const FlLine(
                              color: AppTheme.borderLight,
                              strokeWidth: 0.6,
                            ),
                          ),
                          barGroups: List.generate(
                              revenue.length, (i) {
                            return BarChartGroupData(
                              x: i,
                              barRods: [
                                BarChartRodData(
                                  toY: (i < revenue.length
                                      ? double.tryParse(
                                              revenue[i]
                                                  .toString()) ??
                                          0
                                      : 0),
                                  color: AppTheme.primaryColor,
                                  width: labels.length <= 7
                                      ? 14
                                      : 6,
                                  borderRadius:
                                      const BorderRadius.vertical(
                                          top: Radius.circular(4)),
                                ),
                                BarChartRodData(
                                  toY: (i < profit.length
                                      ? double.tryParse(
                                              profit[i]
                                                  .toString()) ??
                                          0
                                      : 0),
                                  color: const Color(0xFF86EFAC),
                                  width: labels.length <= 7
                                      ? 14
                                      : 6,
                                  borderRadius:
                                      const BorderRadius.vertical(
                                          top: Radius.circular(4)),
                                ),
                              ],
                            );
                          }),
                        ),
                      ),
          ),
          const SizedBox(height: 12),
          // Legend
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _buildLegendDot(AppTheme.primaryColor, 'Revenue'),
              const SizedBox(width: 16),
              _buildLegendDot(
                  const Color(0xFF86EFAC), 'Profit'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildChartEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.bar_chart_rounded,
              size: 64,
              color: AppTheme.textSecondary.withValues(alpha: 0.3)),
          const SizedBox(height: 12),
          const Text(
            'No data yet',
            style: TextStyle(
              color: AppTheme.textPrimary,
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Start adding transactions to see your revenue\noverview here: weekly, monthly or yearly.',
            style: TextStyle(
              color:
                  AppTheme.textSecondary.withValues(alpha: 0.6),
              fontSize: 12,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildLegendDot(Color color, String label) {
    return Row(
      children: [
        Container(
            width: 10,
            height: 10,
            decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(3))),
        const SizedBox(width: 6),
        Text(label,
            style: const TextStyle(
                fontSize: 11, color: AppTheme.textSecondary)),
      ],
    );
  }

  double _chartInterval(double maxY) {
    if (maxY <= 0) return 1;
    final raw = maxY / 3;
    final magnitude =
        math.pow(10, (math.log(raw) / math.ln10).floor()).toDouble();
    final normalised = raw / magnitude;
    final step = normalised <= 1
        ? 1.0
        : normalised <= 2
            ? 2.0
            : normalised <= 5
                ? 5.0
                : 10.0;
    return step * magnitude;
  }

  // ─── 5. Quick Actions ───

  List<(String, IconData, Color, Color, VoidCallback)> _quickActions() {
    return [
      (
        'Add\nTransaction',
        Icons.swap_horiz_rounded,
        AppTheme.iconGreen,
        AppTheme.tintGreenBg,
        () async {
          await showFormDialog(context, const AddTransactionScreen());
          if (!mounted) return;
          _loadDashboard();
        },
      ),
      (
        'CC\nBill',
        Icons.credit_card_rounded,
        AppTheme.iconPurple,
        AppTheme.tintPurpleBg,
        () async {
          await showFormDialog(context, const AddCCBillScreen());
          if (!mounted) return;
          _loadDashboard();
        },
      ),
      (
        'Add\nCredit',
        Icons.person_add_alt_1_rounded,
        AppTheme.iconAmber,
        AppTheme.tintAmberBg,
        () async {
          await showFormDialog(context, const AddCreditEntryScreen());
          if (!mounted) return;
          _loadDashboard();
        },
      ),
      (
        'View\nReports',
        Icons.bar_chart_rounded,
        AppTheme.iconBlue,
        AppTheme.tintBlueBg,
        () => widget.onNavigateTab?.call('Reports'),
      ),
    ];
  }

  Widget _buildQuickActionsSection({required bool isWide}) {
    final actions = _quickActions();

    final content = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Quick Actions',
          style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: AppTheme.textPrimary),
        ),
        const SizedBox(height: 12),
        Row(
          children: actions
              .map((a) => Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      child: _buildQuickActionCard(
                          a.$1, a.$2, a.$3, a.$4, a.$5),
                    ),
                  ))
              .toList(),
        ),
      ],
    );

    if (isWide) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: AppTheme.cardDecoration,
        child: content,
      );
    }
    return content;
  }

  Widget _buildQuickActionCard(String title, IconData icon, Color color,
      Color bg, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(11),
            decoration: BoxDecoration(
              color: bg,
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: color, size: 21),
          ),
          const SizedBox(height: 8),
          Text(
            title,
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: AppTheme.textPrimary,
              height: 1.25,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  // ─── 6. Recent Transactions ───

  Widget _buildRecentTransactionsSidebar() {
    final transactions =
        _dashboardData?['recent_transactions'] as List? ?? [];

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.receipt_long_outlined,
                  color: Color(0xFF1B5E20), size: 20),
              SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment:
                      CrossAxisAlignment.start,
                  children: [
                    Text('Recent Transactions',
                        style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w600)),
                    Text(
                        'Your latest transactions will appear here',
                        style: TextStyle(
                            fontSize: 11,
                            color:
                                AppTheme.textSecondary)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (transactions.isEmpty)
            const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Column(
                  children: [
                    Icon(Icons.receipt_long_rounded,
                        size: 40,
                        color: AppTheme.textSecondary),
                    SizedBox(height: 8),
                    Text('No transactions yet',
                        style: TextStyle(
                            color: AppTheme.textSecondary,
                            fontSize: 13)),
                    Text('Tap + to add your first',
                        style: TextStyle(
                            color: AppTheme.textSecondary,
                            fontSize: 12)),
                  ],
                ),
              ),
            )
          else
            ...transactions.take(5).map(
                (txn) => _buildTransactionTile(txn)),
        ],
      ),
    );
  }

  Widget _buildRecentTransactionsMobile() {
    final transactions =
        _dashboardData?['recent_transactions'] as List? ?? [];

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: AppTheme.cardDecoration,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(
                child: Text('Recent Transactions',
                    style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: AppTheme.textPrimary)),
              ),
              GestureDetector(
                onTap: () => widget.onNavigateTab?.call('Transactions'),
                child: const Text('View All',
                    style: TextStyle(
                        fontSize: 12.5,
                        color: AppTheme.primaryColor,
                        fontWeight: FontWeight.w700)),
              ),
            ],
          ),
          const SizedBox(height: 6),
          if (transactions.isEmpty)
            const EmptyState(
              icon: Icons.receipt_long_rounded,
              title: 'No transactions yet',
              message: 'Tap + New Entry to add your first transaction.',
            )
          else
            ...transactions.take(5).map(
                (txn) => _buildTransactionTile(txn)),
        ],
      ),
    );
  }

  Widget _buildTransactionTile(Map<String, dynamic> txn) {
    final amount =
        double.tryParse(txn['debit_amount'].toString()) ?? 0;
    final profit =
        double.tryParse(txn['profit'].toString()) ?? 0;
    final method = (txn['payment_method'] ?? 'cash').toString();
    final date = (txn['date'] ?? '').toString();
    final style = _methodStyle(method);
    final description = (txn['description'] ?? '').toString();

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: style.$2,
              shape: BoxShape.circle,
            ),
            child: Icon(style.$1, size: 17, color: style.$3),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  description.isNotEmpty
                      ? description
                      : (txn['category_name']?.toString() ?? 'Transaction'),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.textPrimary),
                ),
                const SizedBox(height: 3),
                Text(
                  [
                    if (txn['category_name'] != null &&
                        txn['category_name'].toString().isNotEmpty)
                      txn['category_name'].toString(),
                    _methodLabel(method),
                    if (date.isNotEmpty) date,
                  ].join(' · '),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                      fontSize: 11,
                      color: AppTheme.textSecondary),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '₹${amount.toInt()}',
                style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    color: AppTheme.textPrimary),
              ),
              const SizedBox(height: 2),
              DeltaText('+₹${profit.toInt()}', positive: profit >= 0),
            ],
          ),
        ],
      ),
    );
  }

  (IconData, Color, Color) _methodStyle(String method) {
    switch (method.toLowerCase()) {
      case 'upi':
        return (Icons.qr_code_2_rounded, AppTheme.tintPurpleBg,
            AppTheme.iconPurple);
      case 'bank':
      case 'bank_transfer':
        return (Icons.account_balance_rounded, AppTheme.tintBlueBg,
            AppTheme.iconBlue);
      case 'card':
      case 'credit_card':
        return (Icons.credit_card_rounded, AppTheme.tintAmberBg,
            AppTheme.iconAmber);
      default:
        return (Icons.payments_rounded, AppTheme.tintGreenBg,
            AppTheme.iconGreen);
    }
  }

  String _methodLabel(String method) {
    switch (method.toLowerCase()) {
      case 'upi':
        return 'UPI';
      case 'bank':
      case 'bank_transfer':
        return 'Bank';
      case 'card':
      case 'credit_card':
        return 'Card';
      default:
        return 'Cash';
    }
  }

  // ─── 7. Promo card ───

  Widget _buildPromoCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            const Color(0xFF1B5E20).withValues(alpha: 0.06),
            const Color(0xFF2E7D32).withValues(alpha: 0.04),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: const Color(0xFF1B5E20).withValues(alpha: 0.1),
          width: 1,
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: const Color(0xFFE8F5E9),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.shield_outlined,
                color: Color(0xFF1B5E20), size: 24),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Keep your business finances organized',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.textPrimary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Simple. Secure. Smart.',
                  style: TextStyle(
                    fontSize: 12,
                    color: AppTheme.textSecondary
                        .withValues(alpha: 0.7),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
