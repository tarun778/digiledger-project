import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../models/bank_account.dart';
import '../../services/api_service.dart';
import '../../utils/theme.dart';
import '../../widgets/ui_kit.dart';

class BankAccountMovementsScreen extends StatefulWidget {
  final BankAccount account;

  const BankAccountMovementsScreen({super.key, required this.account});

  @override
  State<BankAccountMovementsScreen> createState() =>
      _BankAccountMovementsScreenState();
}

class _BankAccountMovementsScreenState
    extends State<BankAccountMovementsScreen> {
  static const List<String> _monthNames = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
  ];

  bool _loading = true;
  double _openingBalance = 0;
  double _moneyIn = 0;
  double _moneyOut = 0;
  double _balance = 0;
  int _count = 0;
  List<Map<String, dynamic>> _movements = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final data = await ApiService.getBankAccountMovements(widget.account.id);
      if (!mounted) return;
      setState(() {
        _openingBalance = _asDouble(data['opening_balance']);
        _moneyIn = _asDouble(data['money_in']);
        _moneyOut = _asDouble(data['money_out']);
        _balance = _asDouble(data['balance']);
        _count = (data['movement_count'] as num?)?.toInt() ?? 0;
        _movements = ((data['movements'] as List?) ?? [])
            .map((row) => Map<String, dynamic>.from(row))
            .toList();
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to load movements: $e'),
          backgroundColor: AppTheme.errorColor,
        ),
      );
    }
  }

  double _asDouble(dynamic value) =>
      double.tryParse(value.toString()) ?? 0;

  String _money(double value) =>
      '₹${NumberFormat.decimalPattern('en_IN').format(value)}';

  String _prettyDate(String iso) {
    final parts = iso.split('-');
    if (parts.length != 3) return iso;
    final monthIndex = (int.tryParse(parts[1]) ?? 1) - 1;
    if (monthIndex < 0 || monthIndex > 11) return iso;
    final day = int.tryParse(parts[2]) ?? 0;
    return '$day ${_monthNames[monthIndex]} ${parts[0]}';
  }

  String _sourceLabel(String source) {
    switch (source) {
      case 'cc_bill':
        return 'CC bill payment';
      case 'credit':
        return 'Credit entry';
      default:
        return 'Transaction';
    }
  }

  IconData _sourceIcon(String source) {
    switch (source) {
      case 'cc_bill':
        return Icons.credit_card_rounded;
      case 'credit':
        return Icons.currency_rupee_rounded;
      default:
        return Icons.receipt_long_rounded;
    }
  }

  Widget _buildSummary() {
    return StatGrid(
      cards: [
        MiniStatCard(
          label: 'Money In',
          value: _money(_moneyIn),
          icon: Icons.south_east_rounded,
          color: AppTheme.iconGreen,
          background: AppTheme.tintGreenBg,
        ),
        MiniStatCard(
          label: 'Money Out',
          value: _money(_moneyOut),
          icon: Icons.north_west_rounded,
          color: AppTheme.iconRed,
          background: AppTheme.tintRedBg,
        ),
        MiniStatCard(
          label: 'Balance',
          value: _money(_balance),
          icon: Icons.account_balance_wallet_outlined,
          color: AppTheme.iconBlue,
          background: AppTheme.tintBlueBg,
        ),
        MiniStatCard(
          label: 'Opening Balance',
          value: _money(_openingBalance),
          icon: Icons.savings_outlined,
          color: AppTheme.iconAmber,
          background: AppTheme.tintAmberBg,
        ),
      ],
    );
  }

  Widget _buildMovement(Map<String, dynamic> m) {
    final isIn = m['direction'] == 'in';
    final amount = _asDouble(m['amount']);
    final color = isIn ? AppTheme.successColor : AppTheme.errorColor;
    final background = isIn ? AppTheme.tintGreenBg : AppTheme.tintRedBg;
    final title = (m['title'] ?? '').toString();
    final subtitle = (m['subtitle'] ?? '').toString();
    final paymentMethod = (m['payment_method'] ?? '').toString();
    final source = (m['source'] ?? '').toString();
    final meta = <String>[
      _sourceLabel(source),
      if (paymentMethod.isNotEmpty) paymentMethod,
      if (subtitle.isNotEmpty) subtitle,
    ].join(' • ');

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 9),
      child: Row(
        children: [
          IconTile(
            icon: _sourceIcon(source),
            color: color,
            background: background,
            size: 36,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title.isEmpty ? _sourceLabel(source) : title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.textPrimary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  meta,
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
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '${isIn ? '+' : '-'}${_money(amount)}',
                style: TextStyle(
                  fontSize: 13.5,
                  fontWeight: FontWeight.w800,
                  color: color,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                'Bal ${_money(_asDouble(m['balance_after']))}',
                style: const TextStyle(
                  fontSize: 10,
                  color: AppTheme.textMuted,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  List<Widget> _buildMovements() {
    final rows = <Widget>[];
    String? lastDate;
    for (var i = 0; i < _movements.length; i++) {
      final movement = _movements[i];
      final date = (movement['date'] ?? '').toString();
      if (date != lastDate) {
        rows.add(Padding(
          padding: EdgeInsets.fromLTRB(0, lastDate == null ? 4 : 16, 0, 6),
          child: Text(
            _prettyDate(date),
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: AppTheme.textMuted,
              letterSpacing: 0.3,
            ),
          ),
        ));
        lastDate = date;
      }
      rows.add(_buildMovement(movement));
      if (i < _movements.length - 1) {
        rows.add(const Divider(height: 1, thickness: 0.6, color: AppTheme.borderLight));
      }
    }
    return rows;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      body: Column(
        children: [
          ScreenHeader(
            showBack: true,
            title: widget.account.displayName.isEmpty
                ? 'Bank Account'
                : widget.account.displayName,
            subtitle: 'Money in and out of this account',
          ),
          Expanded(
            child: _loading
                ? const Center(
                    child:
                        CircularProgressIndicator(color: AppTheme.primaryColor))
                : RefreshIndicator(
                    onRefresh: _load,
                    child: ListView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
                      children: [
                        _buildSummary(),
                        const SizedBox(height: 14),
                        if (_movements.isEmpty)
                          const EmptyState(
                            icon: Icons.swap_vert_rounded,
                            title: 'No movements yet',
                            message:
                                'Money coming in and going out of this account will show up here.',
                          )
                        else
                          SectionCard(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                CardHeader(
                                  icon: Icons.swap_vert_rounded,
                                  title: 'Movements',
                                  subtitle: '$_count '
                                      'entries, latest first',
                                ),
                                const SizedBox(height: 6),
                                const Divider(
                                    height: 1,
                                    thickness: 0.6,
                                    color: AppTheme.borderLight),
                                ..._buildMovements(),
                              ],
                            ),
                          ),
                      ],
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}
