import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import '../../utils/errors.dart';
import '../../utils/theme.dart';
import '../../utils/download_helper.dart';
import '../../services/api_service.dart';
import '../../widgets/date_range_dropdown.dart';
import '../../widgets/ui_kit.dart';

class ReportsScreen extends StatefulWidget {
  const ReportsScreen({super.key});

  @override
  State<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends State<ReportsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  bool _isLoading = true;
  DateTimeRange _dateRange = DateTimeRange(
    start: DateTime.now().subtract(const Duration(days: 30)),
    end: DateTime.now(),
  );

  Map<String, dynamic>? _overviewData;
  List<Map<String, dynamic>> _dailyData = [];
  List<Map<String, dynamic>> _ccBillData = [];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 5, vsync: this);
    _loadAllData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }


  String get _dateFrom => DateFormat('yyyy-MM-dd').format(_dateRange.start);
  String get _dateTo => DateFormat('yyyy-MM-dd').format(_dateRange.end);

  Future<bool> _loadAllData() async {
    var ok = true;
    setState(() => _isLoading = true);
    try {
      final overview =
          await ApiService.getReportsOverview(dateFrom: _dateFrom, dateTo: _dateTo);
      if (mounted) setState(() => _overviewData = overview);
    } catch (e) {
      ok = false;
      if (mounted) {
        showApiError(context, e);
      }
    }
    try {
      final daily =
          await ApiService.getDailyReport(dateFrom: _dateFrom, dateTo: _dateTo);
      if (mounted) setState(() => _dailyData = daily);
    } catch (e) {
      ok = false;
      if (mounted) {
        showApiError(context, e);
      }
    }
    try {
      final cc = await ApiService.getCCBillPayments();
      if (mounted) {
        setState(() => _ccBillData = cc.map((e) => {
          'bank_name': e.bankName,
          'amount_paid': e.amountPaid,
          'bill_amount': e.billAmount,
          'service_charges': e.serviceCharges,
          'profit': e.profit,
          'payment_method': e.paymentMethod,
          'date': e.date.toString(),
          'customer_name': e.customerName,
          'remarks': e.remarks,
        }).toList());
      }
    } catch (e) {
      ok = false;
      if (mounted) {
        showApiError(context, e);
      }
    }
    if (mounted) setState(() => _isLoading = false);
    return ok;
  }

  Future<void> _generateReport() async {
    final ok = await _loadAllData();
    if (!ok) return;
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Report generated successfully'),
        backgroundColor: AppTheme.successColor,
      ),
    );
  }

  Future<void> _exportReport(String format) async {
    try {
      final types = ['daily', 'monthly', 'quarterly', 'yearly'];
      final type = types[_tabController.index.clamp(0, 3)];
      final response = await ApiService.exportReport(
        type: type,
        dateFrom: _dateFrom,
        dateTo: _dateTo,
        format: format,
      );
      if (response.statusCode == 200) {
        final bytes = response.bodyBytes;
        final disposition = response.headers['content-disposition'] ?? '';
        final filename =
            disposition.replaceAll('attachment; filename=', '').replaceAll('"', '');
        final ok = DownloadHelper.downloadBytes(bytes, filename);
        if (!mounted) return;
        if (ok) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Downloaded: $filename'),
              backgroundColor: AppTheme.successColor,
            ),
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: AppTheme.primaryColor))
          : RefreshIndicator(
              onRefresh: _loadAllData,
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final isWide = constraints.maxWidth > 900;
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      ScreenHeader(
                        title: 'Reports',
                        subtitle: 'Analyze your business performance',
                        actions: [
                          PopupMenuButton<String>(
                            tooltip: 'Export',
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12)),
                            onSelected: (format) => _exportReport(format),
                            itemBuilder: (context) => const [
                              PopupMenuItem(
                                value: 'pdf',
                                child: Row(
                                  children: [
                                    Icon(Icons.picture_as_pdf_outlined,
                                        size: 18, color: AppTheme.iconRed),
                                    SizedBox(width: 10),
                                    Text('Export PDF'),
                                  ],
                                ),
                              ),
                              PopupMenuItem(
                                value: 'excel',
                                child: Row(
                                  children: [
                                    Icon(Icons.table_chart_outlined,
                                        size: 18, color: AppTheme.iconGreen),
                                    SizedBox(width: 10),
                                    Text('Export Excel'),
                                  ],
                                ),
                              ),
                              PopupMenuItem(
                                value: 'csv',
                                child: Row(
                                  children: [
                                    Icon(Icons.description_outlined,
                                        size: 18, color: AppTheme.iconBlue),
                                    SizedBox(width: 10),
                                    Text('Export CSV'),
                                  ],
                                ),
                              ),
                            ],
                            child: const HeaderIconButton(
                                icon: Icons.ios_share_rounded),
                          ),
                          const SizedBox(width: 6),
                          HeaderIconButton(
                            icon: Icons.tune_rounded,
                            onTap: _generateReport,
                          ),
                        ],
                      ),
                      _buildFilterBar(),
                      _buildTabBar(),
                      const SizedBox(height: 8),
                      Expanded(
                        child: TabBarView(
                          controller: _tabController,
                          children: [
                            _buildOverviewTab(isWide),
                            _buildSalesCollectionTab(isWide),
                            _buildCustomerStatementTab(isWide),
                            _buildPendingReportTab(isWide),
                            _buildCCBillsReportTab(isWide),
                          ],
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
    );
  }

  Widget _buildFilterBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      child: Row(
        children: [
          Expanded(
            child: DateRangeDropdown(
              compact: true,
              selectedRange: _dateRange,
              onRangeChanged: (range) {
                if (range != null) {
                  setState(() {
                    _dateRange = range;
                  });
                  _loadAllData();
                }
              },
            ),
          ),
          const SizedBox(width: 8),
          HeaderIconButton(
            icon: Icons.tune_rounded,
            onTap: _generateReport,
          ),
        ],
      ),
    );
  }

  Widget _buildTabBar() {
    final tabs = [
      ('Overview', Icons.bar_chart_rounded),
      ('Sales & Collection', Icons.receipt_long_rounded),
      ('Customer Statement', Icons.person_outline_rounded),
      ('Pending Report', Icons.pending_actions_rounded),
      ('CC Bills Report', Icons.credit_card_rounded),
    ];

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: List.generate(tabs.length, (i) {
            final (label, icon) = tabs[i];
            final isSelected = _tabController.index == i;
            return Padding(
              padding: const EdgeInsets.only(right: 8),
              child: PillChip(
                label: label,
                icon: icon,
                selected: isSelected,
                onTap: () {
                  setState(() => _tabController.index = i);
                },
              ),
            );
          }),
        ),
      ),
    );
  }

  // ─── OVERVIEW TAB ───

  Widget _buildOverviewTab(bool isWide) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildStatCards(),
          const SizedBox(height: 14),
          if (isWide)
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(flex: 3, child: _buildRevenueVsProfitChart()),
                const SizedBox(width: 14),
                Expanded(flex: 2, child: _buildPaymentStatusChart()),
                const SizedBox(width: 14),
                Expanded(flex: 2, child: _buildTopCustomersList()),
              ],
            )
          else ...[
            _buildRevenueVsProfitChart(),
            const SizedBox(height: 14),
            _buildCategoryPerformanceCard(),
            const SizedBox(height: 14),
            _buildPaymentStatusChart(),
            const SizedBox(height: 14),
            _buildTopCustomersList(),
          ],
          const SizedBox(height: 14),
          if (isWide)
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(flex: 3, child: _buildRecentTransactionsTable()),
                const SizedBox(width: 14),
                Expanded(flex: 2, child: _buildCategoryPerformanceCard()),
              ],
            )
          else
            _buildRecentTransactionsTable(),
          const SizedBox(height: 14),
        ],
      ),
    );
  }

  Widget _buildStatCards() {
    final totalSales = (_overviewData?['total_sales'] as num?)?.toDouble() ?? 0;
    final salesChange = (_overviewData?['sales_change'] as num?)?.toDouble();

    double totalProfit = 0;
    int totalEntries = 0;
    for (final day in _dailyData) {
      totalProfit += (day['profit'] as num?)?.toDouble() ?? 0;
      totalProfit += (day['cc_bill_profit'] as num?)?.toDouble() ?? 0;
      totalEntries += (day['transactions'] as num?)?.toInt() ?? 0;
    }

    double totalCharges = 0;
    for (final cc in _ccBillData) {
      totalCharges += (cc['service_charges'] as num?)?.toDouble() ?? 0;
    }

    return StatGrid(
      cards: [
        _ReportStatTile(
          label: 'Revenue',
          value: '₹${_formatNumber(totalSales)}',
          icon: Icons.account_balance_wallet_outlined,
          color: AppTheme.iconGreen,
          background: AppTheme.tintGreenBg,
          change: salesChange,
        ),
        _ReportStatTile(
          label: 'Profit',
          value: '₹${_formatNumber(totalProfit)}',
          icon: Icons.trending_up_rounded,
          color: AppTheme.iconBlue,
          background: AppTheme.tintBlueBg,
        ),
        _ReportStatTile(
          label: 'Charges',
          value: '₹${_formatNumber(totalCharges)}',
          icon: Icons.percent_rounded,
          color: AppTheme.iconRed,
          background: AppTheme.tintRedBg,
        ),
        _ReportStatTile(
          label: 'Total Entries',
          value: '$totalEntries',
          icon: Icons.receipt_long_outlined,
          color: AppTheme.iconAmber,
          background: AppTheme.tintAmberBg,
        ),
      ],
    );
  }

  Widget _buildRevenueVsProfitChart() {
    final chartLabels = <String>[];
    final chartRevenue = <double>[];
    final chartProfit = <double>[];
    for (final day in _dailyData) {
      chartLabels.add(_formatShortDate('${day['date'] ?? ''}'));
      chartRevenue.add((day['revenue'] as num?)?.toDouble() ?? 0);
      chartProfit.add(((day['profit'] as num?)?.toDouble() ?? 0) +
          ((day['cc_bill_profit'] as num?)?.toDouble() ?? 0));
    }

    final maxVal = [...chartRevenue, ...chartProfit].fold<double>(0, (a, b) {
      return b > a ? b : a;
    });
    final maxY = maxVal > 0 ? maxVal * 1.3 : 100.0;

    return SectionCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const CardHeader(title: 'Revenue vs Profit'),
          const SizedBox(height: 10),
          Row(
            children: [
              _buildLegendDot(AppTheme.primaryColor, 'Revenue'),
              const SizedBox(width: 16),
              _buildLegendDot(AppTheme.accentColor, 'Profit'),
            ],
          ),
          const SizedBox(height: 14),
          SizedBox(
            height: 200,
            child: chartLabels.isEmpty
                ? _buildChartEmptyState()
                : BarChart(
                    BarChartData(
                      alignment: BarChartAlignment.spaceAround,
                      maxY: maxY,
                      barTouchData: BarTouchData(
                        enabled: true,
                        touchTooltipData: BarTouchTooltipData(
                          getTooltipItem: (group, groupIndex, rod, rodIndex) {
                            return BarTooltipItem(
                              '₹${rod.toY.toInt()}',
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
                              if (idx >= 0 && idx < chartLabels.length) {
                                final showLabel = chartLabels.length <= 10 ||
                                    idx %
                                        ((chartLabels.length / 8)
                                            .ceil()
                                            .clamp(1, chartLabels.length)) ==
                                        0;
                                return showLabel
                                    ? Padding(
                                        padding: const EdgeInsets.only(top: 8),
                                        child: Text(chartLabels[idx].toString(),
                                            style: const TextStyle(
                                                fontSize: 9,
                                                color: AppTheme.textMuted)),
                                      )
                                    : const SizedBox.shrink();
                              }
                              return const SizedBox.shrink();
                            },
                          ),
                        ),
                        leftTitles: AxisTitles(
                          sideTitles: SideTitles(
                            showTitles: true,
                            reservedSize: 40,
                            getTitlesWidget: (value, _) {
                              if (value >= 1000) {
                                return Text(
                                    '₹${(value / 1000).toStringAsFixed(0)}K',
                                    style: const TextStyle(
                                        fontSize: 9,
                                        color: AppTheme.textMuted));
                              }
                              return Text('₹${value.toInt()}',
                                  style: const TextStyle(
                                      fontSize: 9,
                                      color: AppTheme.textMuted));
                            },
                          ),
                        ),
                        topTitles: const AxisTitles(
                            sideTitles: SideTitles(showTitles: false)),
                        rightTitles: const AxisTitles(
                            sideTitles: SideTitles(showTitles: false)),
                      ),
                      borderData: FlBorderData(show: false),
                      gridData: FlGridData(
                        show: true,
                        drawVerticalLine: false,
                        horizontalInterval: maxY > 0 ? maxY / 4 : 25,
                        getDrawingHorizontalLine: (value) => const FlLine(
                          color: AppTheme.borderLight,
                          strokeWidth: 1,
                        ),
                      ),
                      barGroups: List.generate(chartRevenue.length, (i) {
                        return BarChartGroupData(
                          x: i,
                          barRods: [
                            BarChartRodData(
                              toY: i < chartRevenue.length
                                  ? chartRevenue[i]
                                  : 0,
                              color: AppTheme.primaryColor,
                              width: chartLabels.length <= 7 ? 12 : 5,
                              borderRadius: BorderRadius.circular(3),
                            ),
                            BarChartRodData(
                              toY: i < chartProfit.length
                                  ? chartProfit[i]
                                  : 0,
                              color: AppTheme.accentColor,
                              width: chartLabels.length <= 7 ? 12 : 5,
                              borderRadius: BorderRadius.circular(3),
                            ),
                          ],
                        );
                      }),
                    ),
                  ),
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
              size: 48,
              color: AppTheme.textSecondary.withValues(alpha: 0.3)),
          const SizedBox(height: 8),
          const Text('No chart data available',
              style: TextStyle(color: AppTheme.textSecondary, fontSize: 13)),
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
                color: color, borderRadius: BorderRadius.circular(3))),
        const SizedBox(width: 6),
        Text(label,
            style: const TextStyle(fontSize: 11, color: AppTheme.textSecondary)),
      ],
    );
  }

  Widget _buildPaymentStatusChart() {
    final paymentStatus = _overviewData?['payment_status'] ?? {};
    final total = paymentStatus['total'] ?? 0;
    final settled = paymentStatus['settled'] ?? 0;
    final partial = paymentStatus['partial'] ?? 0;
    final pending = paymentStatus['pending'] ?? 0;

    final sections = <PieChartSectionData>[];
    if (settled > 0) {
      sections.add(PieChartSectionData(
        value: settled.toDouble(),
        color: AppTheme.primaryColor,
        radius: 50,
        title: '',
        titleStyle: const TextStyle(fontSize: 0),
      ));
    }
    if (partial > 0) {
      sections.add(PieChartSectionData(
        value: partial.toDouble(),
        color: AppTheme.warningColor,
        radius: 50,
        title: '',
        titleStyle: const TextStyle(fontSize: 0),
      ));
    }
    if (pending > 0) {
      sections.add(PieChartSectionData(
        value: pending.toDouble(),
        color: AppTheme.errorColor,
        radius: 50,
        title: '',
        titleStyle: const TextStyle(fontSize: 0),
      ));
    }

    return SectionCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const CardHeader(
            title: 'Payment Status',
            subtitle: 'Overall credit settlement status',
          ),
          const SizedBox(height: 14),
          SizedBox(
            height: 160,
            child: sections.isEmpty
                ? const Center(
                    child: Text('No credit data',
                        style: TextStyle(
                            color: AppTheme.textSecondary, fontSize: 12)))
                : Row(
                    children: [
                      Expanded(
                        child: PieChart(
                          PieChartData(
                            sections: sections,
                            sectionsSpace: 2,
                            centerSpaceRadius: 36,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (settled > 0)
                            _buildPaymentLegend(
                                AppTheme.primaryColor,
                                'Settled',
                                '$settled',
                                total > 0
                                    ? '${(settled / total * 100).toInt()}%'
                                    : '0%'),
                          if (partial > 0) ...[
                            const SizedBox(height: 8),
                            _buildPaymentLegend(
                                AppTheme.warningColor,
                                'Partial',
                                '$partial',
                                total > 0
                                    ? '${(partial / total * 100).toInt()}%'
                                    : '0%'),
                          ],
                          if (pending > 0) ...[
                            const SizedBox(height: 8),
                            _buildPaymentLegend(
                                AppTheme.errorColor,
                                'Pending',
                                '$pending',
                                total > 0
                                    ? '${(pending / total * 100).toInt()}%'
                                    : '0%'),
                          ],
                        ],
                      ),
                    ],
                  ),
          ),
          const SizedBox(height: 8),
          Center(
            child: Text(
              '$total Customers',
              style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.textPrimary),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPaymentLegend(
      Color color, String label, String count, String pct) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
            width: 10,
            height: 10,
            decoration: BoxDecoration(
                color: color, borderRadius: BorderRadius.circular(3))),
        const SizedBox(width: 6),
        Text(label,
            style: const TextStyle(fontSize: 11, color: AppTheme.textSecondary)),
        const SizedBox(width: 4),
        Text('$count ($pct)',
            style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: AppTheme.textPrimary)),
      ],
    );
  }

  Widget _buildTopCustomersList() {
    final topCustomers =
        (_overviewData?['top_customers'] as List?) ?? [];

    return SectionCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const CardHeader(
            title: 'Top Customers by Purchase',
            subtitle: 'Based on total credit given',
          ),
          const SizedBox(height: 14),
          if (topCustomers.isEmpty)
            const EmptyState(
              icon: Icons.people_outline_rounded,
              title: 'No customer data',
            )
          else
            ...List.generate(topCustomers.length, (i) {
              final c = topCustomers[i];
              final name = c['customer_name'] ?? '';
              final credit =
                  (c['total_credit'] ?? c['total_given'] ?? 0).toDouble();
              final initials = _getInitials(name);
              final colors = [
                AppTheme.iconGreen,
                AppTheme.iconBlue,
                AppTheme.iconPurple,
                AppTheme.iconAmber,
                AppTheme.iconTeal,
              ];
              return Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Row(
                  children: [
                    Text('${i + 1}',
                        style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: AppTheme.textSecondary)),
                    const SizedBox(width: 10),
                    CircleAvatar(
                      radius: 16,
                      backgroundColor: colors[i % colors.length],
                      child: Text(initials,
                          style: const TextStyle(
                              color: Colors.white,
                              fontSize: 11,
                              fontWeight: FontWeight.w600)),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(name,
                          style: const TextStyle(
                              fontSize: 13, fontWeight: FontWeight.w500),
                          overflow: TextOverflow.ellipsis),
                    ),
                    Text('₹${_formatNumber(credit)}',
                        style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: AppTheme.textPrimary)),
                  ],
                ),
              );
            }),
        ],
      ),
    );
  }

  Widget _buildRecentTransactionsTable() {
    final recentTxns =
        (_overviewData?['recent_transactions'] as List?) ?? [];
    final recentCredits =
        (_overviewData?['recent_credit_activities'] as List?) ?? [];

    final allItems = <Map<String, dynamic>>[];
    for (var t in recentTxns) {
      allItems.add({
        'date': t['date'] ?? '',
        'customer_name': t['customer_name'] ?? '-',
        'type': 'Sale',
        'amount': t['amount'] ?? 0,
        'payment_method': t['payment_method'] ?? '',
        'status': '',
      });
    }
    for (var c in recentCredits) {
      final isReturned = c['entry_type'] == 'returned';
      allItems.add({
        'date': c['date'] ?? '',
        'customer_name': c['customer_name'] ?? '-',
        'type': isReturned ? 'Payment' : 'Sale (Credit)',
        'amount': c['amount'] ?? 0,
        'payment_method': '',
        'status': '',
      });
    }
    allItems.sort((a, b) =>
        (b['date'] ?? '').toString().compareTo((a['date'] ?? '').toString()));
    final items = allItems.take(10).toList();

    return SectionCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const CardHeader(
            title: 'Recent Transactions',
            subtitle: 'Latest sales, payments and credit activities',
          ),
          const SizedBox(height: 14),
          if (items.isEmpty)
            const EmptyState(
              icon: Icons.receipt_long_rounded,
              title: 'No transactions yet',
            )
          else
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: ConstrainedBox(
                constraints: BoxConstraints(
                    minWidth: MediaQuery.of(context).size.width - 100),
                child: DataTable(
                  headingRowColor:
                      WidgetStateProperty.all(AppTheme.surfaceLight),
                  dataRowMinHeight: 48,
                dataRowMaxHeight: 48,
                  headingRowHeight: 40,
                  columnSpacing: 16,
                  columns: const [
                    DataColumn(label: Text('#',
                        style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600))),
                    DataColumn(label: Text('Date',
                        style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600))),
                    DataColumn(label: Text('Customer',
                        style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600))),
                    DataColumn(label: Text('Type',
                        style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600))),
                    DataColumn(label: Text('Amount (\u20B9)',
                        style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                        numeric: true),
                    DataColumn(label: Text('Payment Mode',
                        style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600))),
                    DataColumn(label: Text('Status',
                        style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600))),
                  ],
                  rows: List.generate(items.length, (i) {
                    final item = items[i];
                    final isSale =
                        item['type'] == 'Sale' || item['type'] == 'Sale (Credit)';
                    final typeColor =
                        isSale ? AppTheme.iconGreen : AppTheme.iconBlue;
                    String status = '';
                    Color statusColor = AppTheme.textMuted;
                    if (isSale) {
                      status = 'Pending';
                      statusColor = AppTheme.iconAmber;
                    } else {
                      status = 'Settled';
                      statusColor = AppTheme.iconGreen;
                    }
                    final amount = (item['amount'] ?? 0).toDouble();
                    String paymentMode = '';
                    final pm = item['payment_method'] ?? '';
                    if (pm == 'cash') {
                      paymentMode = 'Cash';
                    } else if (pm.startsWith('upi')) {
                      paymentMode = 'UPI';
                    } else if (pm == 'card') {
                      paymentMode = 'Card';
                    } else if (pm == 'net_banking') {
                      paymentMode = 'Net Banking';
                    } else {
                      paymentMode = pm;
                    }

                    return DataRow(cells: [
                      DataCell(Text('${i + 1}',
                          style: const TextStyle(fontSize: 12))),
                      DataCell(Text(
                          _formatDisplayDate(item['date'] ?? ''),
                          style: const TextStyle(fontSize: 12))),
                      DataCell(Text(item['customer_name'] ?? '-',
                          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
                          overflow: TextOverflow.ellipsis)),
                      DataCell(
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: isSale
                                ? AppTheme.tintGreenBg
                                : AppTheme.tintBlueBg,
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: Text(item['type'] ?? '',
                              style: TextStyle(
                                  fontSize: 11,
                                  color: typeColor,
                                  fontWeight: FontWeight.w600)),
                        ),
                      ),
                      DataCell(Text('₹${_formatNumber(amount)}',
                          style: const TextStyle(
                              fontSize: 12, fontWeight: FontWeight.w600))),
                      DataCell(Text(paymentMode,
                          style: const TextStyle(fontSize: 12))),
                      DataCell(
                        StatusPill(
                          label: status,
                          color: statusColor,
                          background: isSale
                              ? AppTheme.tintAmberBg
                              : AppTheme.tintGreenBg,
                        ),
                      ),
                    ]);
                  }),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildCategoryPerformanceCard() {
    final salesByCategory =
        (_overviewData?['sales_by_category'] as List?) ?? [];

    const tints = [
      (AppTheme.iconGreen, AppTheme.tintGreenBg),
      (AppTheme.iconBlue, AppTheme.tintBlueBg),
      (AppTheme.iconAmber, AppTheme.tintAmberBg),
      (AppTheme.iconPurple, AppTheme.tintPurpleBg),
      (AppTheme.iconRed, AppTheme.tintRedBg),
    ];

    return SectionCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const CardHeader(
            title: 'Category Performance',
            subtitle: 'Distribution of sales across categories',
          ),
          const SizedBox(height: 14),
          if (salesByCategory.isEmpty)
            const EmptyState(
              icon: Icons.category_outlined,
              title: 'No category data',
              message: 'No sales recorded in the selected period.',
            )
          else
            ...List.generate(salesByCategory.length, (i) {
              final cat = salesByCategory[i];
              final name = '${cat['category_name'] ?? ''}';
              final revenue = (cat['revenue'] as num?)?.toDouble() ?? 0;
              final pct = (cat['percentage'] as num?)?.toDouble() ?? 0;
              final tint = tints[i % tints.length];
              return Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Row(
                  children: [
                    IconTile(
                      icon: Icons.sell_rounded,
                      color: tint.$1,
                      background: tint.$2,
                      size: 34,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Flexible(
                                child: Text(
                                  name,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                    color: AppTheme.textPrimary,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 6),
                              Text(
                                '${pct.toInt()}%',
                                style: const TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  color: AppTheme.textSecondary,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 7),
                          ProgressBar(
                            value: pct / 100,
                            height: 6,
                            color: tint.$1,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 10),
                    Text(
                      '₹${_formatNumber(revenue)}',
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: AppTheme.textPrimary,
                      ),
                    ),
                  ],
                ),
              );
            }),
        ],
      ),
    );
  }

  // ─── SALES & COLLECTION TAB ───

  Widget _buildSalesCollectionTab(bool isWide) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionHeader('Sales & Collection Report',
              'Detailed view of sales and collection data'),
          const SizedBox(height: 14),
          _buildDailyReportTable(),
        ],
      ),
    );
  }

  Widget _buildDailyReportTable() {
    if (_dailyData.isEmpty) {
      return const EmptyState(
        icon: Icons.table_chart_outlined,
        title: 'No data available for the selected period',
        message: 'Try adjusting the date range above.',
      );
    }

    return SectionCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CardHeader(
            title: 'Daily Sales Breakdown',
            subtitle: '${_dailyData.length} days',
          ),
          const SizedBox(height: 14),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: ConstrainedBox(
              constraints:
                  BoxConstraints(minWidth: MediaQuery.of(context).size.width - 100),
              child: DataTable(
                headingRowColor: WidgetStateProperty.all(AppTheme.surfaceLight),
                columns: const [
                  DataColumn(label: Text('Date',
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600))),
                  DataColumn(label: Text('Transactions',
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                      numeric: true),
                  DataColumn(label: Text('Revenue',
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                      numeric: true),
                  DataColumn(label: Text('Profit',
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                      numeric: true),
                  DataColumn(label: Text('CC Bills',
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                      numeric: true),
                  DataColumn(label: Text('CC Revenue',
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                      numeric: true),
                ],
                rows: _dailyData.reversed.map((item) {
                  final revenue = (item['revenue'] ?? 0).toDouble();
                  final profit = (item['profit'] ?? 0).toDouble();
                  final ccRevenue = (item['cc_bill_revenue'] ?? 0).toDouble();
                  return DataRow(cells: [
                    DataCell(Text(
                        _formatDisplayDate(item['date'] ?? ''),
                        style: const TextStyle(fontSize: 12))),
                    DataCell(Text('${item['transactions'] ?? 0}',
                        style: const TextStyle(fontSize: 12))),
                    DataCell(Text('₹${_formatNumber(revenue)}',
                        style: const TextStyle(
                            fontSize: 12, fontWeight: FontWeight.w600))),
                    DataCell(Text('₹${_formatNumber(profit)}',
                        style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: AppTheme.successColor))),
                    DataCell(Text('${item['cc_bill_payments'] ?? 0}',
                        style: const TextStyle(fontSize: 12))),
                    DataCell(Text('₹${_formatNumber(ccRevenue)}',
                        style: const TextStyle(fontSize: 12))),
                  ]);
                }).toList(),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ─── CUSTOMER STATEMENT TAB ───

  Widget _buildCustomerStatementTab(bool isWide) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionHeader('Customer Statement',
              'View transaction history per customer'),
          const SizedBox(height: 14),
          _buildCustomerStatementList(),
        ],
      ),
    );
  }

  Widget _buildCustomerStatementList() {
    final recentTxns =
        (_overviewData?['recent_transactions'] as List?) ?? [];
    final recentCredits =
        (_overviewData?['recent_credit_activities'] as List?) ?? [];

    final customerMap = <String, Map<String, dynamic>>{};

    for (var t in recentTxns) {
      final name = t['customer_name'] ?? '';
      if (name.isEmpty || name == '-') continue;
      customerMap.putIfAbsent(name, () => {
        'name': name,
        'total_spent': 0.0,
        'total_paid': 0.0,
        'transactions': 0,
      });
      customerMap[name]!['total_spent'] += (t['amount'] ?? 0).toDouble();
      customerMap[name]!['transactions'] += 1;
    }

    for (var c in recentCredits) {
      final name = c['customer_name'] ?? '';
      if (name.isEmpty) continue;
      customerMap.putIfAbsent(name, () => {
        'name': name,
        'total_spent': 0.0,
        'total_paid': 0.0,
        'transactions': 0,
      });
      if (c['entry_type'] == 'returned') {
        customerMap[name]!['total_paid'] += (c['amount'] ?? 0).toDouble();
      } else {
        customerMap[name]!['total_spent'] += (c['amount'] ?? 0).toDouble();
      }
    }

    final customers = customerMap.values.toList();
    customers.sort((a, b) =>
        (b['total_spent'] as double).compareTo(a['total_spent'] as double));

    return SectionCard(
      padding: const EdgeInsets.all(16),
      child: customers.isEmpty
          ? const EmptyState(
              icon: Icons.people_outline_rounded,
              title: 'No customer data available',
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                CardHeader(
                  title: 'Customer Statements',
                  subtitle: '${customers.length} customers',
                ),
                const SizedBox(height: 14),
                ...customers.map((c) {
                  final name = c['name'] as String;
                  final spent = c['total_spent'] as double;
                  final paid = c['total_paid'] as double;
                  final pending = spent - paid;
                  final isPending = pending > 0;
                  final initials = _getInitials(name);
                  return Container(
                    margin: const EdgeInsets.only(bottom: 10),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppTheme.surfaceLight,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: [
                        CircleAvatar(
                          radius: 18,
                          backgroundColor: AppTheme.primaryColor,
                          child: Text(initials,
                              style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600)),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(name,
                                  style: const TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w600)),
                              const SizedBox(height: 2),
                              KeyValueRow(
                                label: 'Spent',
                                value: '₹${_formatNumber(spent)}',
                              ),
                              KeyValueRow(
                                label: 'Paid',
                                value: '₹${_formatNumber(paid)}',
                                valueColor: AppTheme.successColor,
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(
                              '₹${_formatNumber(isPending ? pending : 0)}',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                                color: isPending
                                    ? AppTheme.errorColor
                                    : AppTheme.successColor,
                              ),
                            ),
                            const SizedBox(height: 4),
                            StatusPill(
                              label: isPending ? 'Pending' : 'Settled',
                              color: isPending
                                  ? AppTheme.iconRed
                                  : AppTheme.iconGreen,
                              background: isPending
                                  ? AppTheme.tintRedBg
                                  : AppTheme.tintGreenBg,
                            ),
                          ],
                        ),
                      ],
                    ),
                  );
                }),
              ],
            ),
    );
  }

  // ─── PENDING REPORT TAB ───

  Widget _buildPendingReportTab(bool isWide) {
    final recentCredits =
        (_overviewData?['recent_credit_activities'] as List?) ?? [];
    final paymentStatus = _overviewData?['payment_status'] ?? {};

    final pending = <Map<String, dynamic>>[];
    final settled = <Map<String, dynamic>>[];

    for (var c in recentCredits) {
      if (c['entry_type'] == 'given') {
        pending.add(c);
      } else {
        settled.add(c);
      }
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionHeader('Pending Report',
              'Overview of pending payments and credit status'),
          const SizedBox(height: 14),
          _buildPendingStatsCards(paymentStatus),
          const SizedBox(height: 14),
          _buildPendingActivitiesList(recentCredits),
        ],
      ),
    );
  }

  Widget _buildPendingStatsCards(Map<String, dynamic> paymentStatus) {
    final total = paymentStatus['total'] ?? 0;
    final settled = paymentStatus['settled'] ?? 0;
    final partial = paymentStatus['partial'] ?? 0;
    final pending = paymentStatus['pending'] ?? 0;

    final items = [
      ('Total Credit Customers', '$total', Icons.people_outline_rounded,
          AppTheme.iconBlue, AppTheme.tintBlueBg),
      ('Settled', '$settled', Icons.check_circle_outline_rounded,
          AppTheme.iconGreen, AppTheme.tintGreenBg),
      ('Partial', '$partial', Icons.schedule_rounded, AppTheme.iconAmber,
          AppTheme.tintAmberBg),
      ('Pending', '$pending', Icons.pending_actions_rounded, AppTheme.iconRed,
          AppTheme.tintRedBg),
    ];

    return StatGrid(
      cards: items
          .map((item) => StatCard(
                label: item.$1,
                value: item.$2,
                icon: item.$3,
                color: item.$4,
                background: item.$5,
              ))
          .toList(),
    );
  }

  Widget _buildPendingActivitiesList(List activities) {
    return SectionCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const CardHeader(
            title: 'Recent Credit Activities',
            subtitle: 'Credit given and payments received',
          ),
          const SizedBox(height: 14),
          if (activities.isEmpty)
            const EmptyState(
              icon: Icons.history_rounded,
              title: 'No credit activities yet',
            )
          else
            ...activities.map((c) {
              final isReturned = c['entry_type'] == 'returned';
              final color =
                  isReturned ? AppTheme.iconGreen : AppTheme.iconRed;
              final background =
                  isReturned ? AppTheme.tintGreenBg : AppTheme.tintRedBg;
              final amount = (c['amount'] ?? 0).toDouble();
              return Container(
                margin: const EdgeInsets.only(bottom: 10),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppTheme.surfaceLight,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    IconTile(
                      icon: isReturned
                          ? Icons.arrow_downward_rounded
                          : Icons.arrow_upward_rounded,
                      color: color,
                      background: background,
                      size: 34,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(c['customer_name'] ?? '',
                              style: const TextStyle(
                                  fontSize: 14, fontWeight: FontWeight.w600)),
                          const SizedBox(height: 2),
                          Text(
                              '${isReturned ? 'Payment Received' : 'Credit Given'} \u2022 ${_formatDisplayDate(c['date'] ?? '')}',
                              style: const TextStyle(
                                  fontSize: 11,
                                  color: AppTheme.textSecondary)),
                        ],
                      ),
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          '${isReturned ? '+' : '-'}₹${_formatNumber(amount)}',
                          style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: color),
                        ),
                        const SizedBox(height: 4),
                        StatusPill(
                          label: isReturned ? 'Returned' : 'Given',
                          color: color,
                          background: background,
                        ),
                      ],
                    ),
                  ],
                ),
              );
            }),
        ],
      ),
    );
  }

  // ─── CC BILLS REPORT TAB ───

  Widget _buildCCBillsReportTab(bool isWide) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionHeader(
              'CC Bills Report', 'Credit card bill payment history'),
          const SizedBox(height: 14),
          _buildCCBillsSummary(),
          const SizedBox(height: 14),
          _buildCCBillsTable(),
        ],
      ),
    );
  }

  Widget _buildCCBillsSummary() {
    double totalPaid = 0;
    double totalBill = 0;
    double totalCharges = 0;
    double totalProfit = 0;
    for (var cc in _ccBillData) {
      totalPaid += (cc['amount_paid'] ?? 0).toDouble();
      totalBill += (cc['bill_amount'] ?? 0).toDouble();
      totalCharges += (cc['service_charges'] ?? 0).toDouble();
      totalProfit += (cc['profit'] ?? 0).toDouble();
    }

    final items = [
      ('Total Bill Amount', '₹${_formatNumber(totalBill)}',
          Icons.receipt_long_outlined, AppTheme.iconBlue, AppTheme.tintBlueBg),
      ('Total Paid', '₹${_formatNumber(totalPaid)}',
          Icons.check_circle_outline_rounded, AppTheme.iconGreen,
          AppTheme.tintGreenBg),
      ('Service Charges', '₹${_formatNumber(totalCharges)}',
          Icons.percent_rounded, AppTheme.iconAmber, AppTheme.tintAmberBg),
      ('Profit', '₹${_formatNumber(totalProfit)}',
          Icons.trending_up_rounded, AppTheme.iconPurple, AppTheme.tintPurpleBg),
    ];

    return StatGrid(
      cards: items
          .map((item) => StatCard(
                label: item.$1,
                value: item.$2,
                icon: item.$3,
                color: item.$4,
                background: item.$5,
              ))
          .toList(),
    );
  }

  Widget _buildCCBillsTable() {
    if (_ccBillData.isEmpty) {
      return const EmptyState(
        icon: Icons.credit_card_rounded,
        title: 'No CC bill data available',
        message: 'Credit card payments will appear here.',
      );
    }

    return SectionCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CardHeader(
            title: 'CC Bill Payments',
            subtitle: '${_ccBillData.length} records',
          ),
          const SizedBox(height: 14),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: ConstrainedBox(
              constraints:
                  BoxConstraints(minWidth: MediaQuery.of(context).size.width - 100),
              child: DataTable(
                headingRowColor: WidgetStateProperty.all(AppTheme.surfaceLight),
                columns: const [
                  DataColumn(label: Text('Date',
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600))),
                  DataColumn(label: Text('Bank',
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600))),
                  DataColumn(label: Text('Bill Amount',
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                      numeric: true),
                  DataColumn(label: Text('Amount Paid',
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                      numeric: true),
                  DataColumn(label: Text('Charges',
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                      numeric: true),
                  DataColumn(label: Text('Profit',
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                      numeric: true),
                  DataColumn(label: Text('Method',
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600))),
                ],
                rows: _ccBillData.reversed.map((cc) {
                  final billAmount = (cc['bill_amount'] ?? 0).toDouble();
                  final amountPaid = (cc['amount_paid'] ?? 0).toDouble();
                  final charges = (cc['service_charges'] ?? 0).toDouble();
                  final profit = (cc['profit'] ?? 0).toDouble();
                  return DataRow(cells: [
                    DataCell(Text(
                        _formatDisplayDate(cc['date'] ?? ''),
                        style: const TextStyle(fontSize: 12))),
                    DataCell(Text(cc['bank_name'] ?? '',
                        style: const TextStyle(fontSize: 12))),
                    DataCell(Text('₹${_formatNumber(billAmount)}',
                        style: const TextStyle(fontSize: 12))),
                    DataCell(Text('₹${_formatNumber(amountPaid)}',
                        style: const TextStyle(
                            fontSize: 12, fontWeight: FontWeight.w600))),
                    DataCell(Text('₹${_formatNumber(charges)}',
                        style: const TextStyle(fontSize: 12))),
                    DataCell(Text('₹${_formatNumber(profit)}',
                        style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: AppTheme.successColor))),
                    DataCell(Text(cc['payment_method'] ?? '',
                        style: const TextStyle(fontSize: 12))),
                  ]);
                }).toList(),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ─── SHARED HELPERS ───

  Widget _buildSectionHeader(String title, String subtitle) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title,
            style: const TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w800,
                color: AppTheme.textPrimary)),
        const SizedBox(height: 4),
        Text(subtitle,
            style: const TextStyle(
                fontSize: 12, color: AppTheme.textSecondary)),
      ],
    );
  }

  String _getInitials(String name) {
    final words =
        name.split(' ').where((w) => w.trim().isNotEmpty).toList();
    if (words.isEmpty) return '?';
    return words.take(2).map((w) => w[0]).join().toUpperCase();
  }

  String _formatNumber(double value) {
    if (value == value.roundToDouble() && value < 100000) {
      final formatter = NumberFormat('#,##,###', 'en_IN');
      return formatter.format(value.toInt());
    }
    final formatter = NumberFormat('#,##,##0.00', 'en_IN');
    return formatter.format(value);
  }

  String _formatDisplayDate(String dateStr) {
    if (dateStr.isEmpty) return '-';
    try {
      final date = DateTime.parse(dateStr);
      return DateFormat('dd MMM yyyy').format(date);
    } catch (_) {
      return dateStr;
    }
  }

  String _formatShortDate(String dateStr) {
    if (dateStr.isEmpty) return '';
    try {
      final date = DateTime.parse(dateStr);
      return DateFormat('dd MMM').format(date);
    } catch (_) {
      return dateStr;
    }
  }
}

/// Mini stat tile matching [MiniStatCard] with an optional trend delta
/// (e.g. "▲ 18%") rendered under the label.
class _ReportStatTile extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;
  final Color background;
  final double? change;

  const _ReportStatTile({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
    required this.background,
    this.change,
  });

  @override
  Widget build(BuildContext context) {
    final showTrend = change != null && change != 0;
    final positive = (change ?? 0) >= 0;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: AppTheme.cardDecoration,
      child: Row(
        children: [
          Container(
            width: 34,
            height: 34,
            decoration:
                BoxDecoration(color: background, shape: BoxShape.circle),
            child: Icon(icon, size: 17, color: color),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    color: AppTheme.textPrimary,
                  ),
                ),
                Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 11,
                    color: AppTheme.textSecondary,
                  ),
                ),
                if (showTrend) ...[
                  const SizedBox(height: 3),
                  Text(
                    '${positive ? '▲' : '▼'} ${change!.abs().toStringAsFixed(0)}%',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      color: positive
                          ? AppTheme.successColor
                          : AppTheme.errorColor,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
