import 'package:flutter/material.dart';
import '../../utils/errors.dart';
import '../../utils/theme.dart';
import '../../services/api_service.dart';
import '../../models/bank_account.dart';
import '../../widgets/bank_account_form.dart';
import '../../widgets/ui_kit.dart';
import 'bank_account_movements_screen.dart';

class BankAccountsScreen extends StatefulWidget {
  const BankAccountsScreen({super.key});

  @override
  State<BankAccountsScreen> createState() => _BankAccountsScreenState();
}

class _BankAccountsScreenState extends State<BankAccountsScreen> {
  List<BankAccount> _accounts = [];
  bool _loading = true;
  String _search = '';

  double get _totalBalance =>
      _filtered.fold(0.0, (sum, a) => sum + a.balance);

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final accounts = await ApiService.getBankAccounts();
      if (!mounted) return;
      setState(() {
        _accounts = accounts;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
      showApiError(context, e);
    }
  }

  List<BankAccount> get _filtered {
    final q = _search.trim().toLowerCase();
    if (q.isEmpty) return _accounts;
    return _accounts
        .where((a) =>
            a.displayName.toLowerCase().contains(q) ||
            a.accountName.toLowerCase().contains(q) ||
            a.bankName.toLowerCase().contains(q) ||
            a.maskedNumber.toLowerCase().contains(q))
        .toList();
  }

  String _money(double value) => '₹${value.toStringAsFixed(2)}';

  (Color, Color) _typeStyle(String type) {
    switch (type) {
      case 'current':
        return (AppTheme.iconAmber, AppTheme.tintAmberBg);
      case 'other':
        return (AppTheme.iconPurple, AppTheme.tintPurpleBg);
      default:
        return (AppTheme.iconGreen, AppTheme.tintGreenBg);
    }
  }

  Future<void> _add() async {
    final saved = await showBankAccountForm(context);
    if (!mounted || saved == null) return;
    setState(() => _accounts = [..._accounts, saved]);
  }

  Future<void> _edit(BankAccount acc) async {
    final saved = await showBankAccountForm(context, account: acc);
    if (!mounted || saved == null) return;
    setState(() {
      final index = _accounts.indexWhere((a) => a.id == saved.id);
      if (index != -1) _accounts[index] = saved;
    });
  }

  Future<void> _delete(BankAccount acc) async {
    try {
      await ApiService.deleteBankAccount(acc.id);
      if (!mounted) return;
      setState(
          () => _accounts = _accounts.where((a) => a.id != acc.id).toList());
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Account deleted'),
          backgroundColor: AppTheme.successColor,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      showApiError(context, e);
    }
  }

  void _confirmDelete(BankAccount acc) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        title: const Text('Delete account?'),
        content: Text(
          '"${acc.displayName}" will be hidden from your account list. '
          'Past transactions keep their history.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              _delete(acc);
            },
            style:
                TextButton.styleFrom(foregroundColor: AppTheme.errorColor),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  Widget _buildSummary() {
    return StatGrid(
      columns: 2,
      cards: [
        MiniStatCard(
          label: 'Total Balance',
          value: _money(_totalBalance),
          icon: Icons.account_balance_wallet_outlined,
          color: AppTheme.iconGreen,
          background: AppTheme.tintGreenBg,
        ),
        MiniStatCard(
          label: 'Accounts',
          value: _filtered.length.toString(),
          icon: Icons.account_balance_outlined,
          color: AppTheme.iconBlue,
          background: AppTheme.tintBlueBg,
        ),
      ],
    );
  }

  Widget _buildAccountCard(BankAccount acc) {
    final style = _typeStyle(acc.accountType);
    final title = acc.displayName.isNotEmpty ? acc.displayName : 'Bank Account';
    final type = acc.typeLabel.isNotEmpty ? acc.typeLabel : acc.accountType;

    return GestureDetector(
      onTap: () => _openMovements(acc),
      child: Container(
        height: 150,
        padding: const EdgeInsets.all(14),
        decoration: AppTheme.cardDecoration,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                IconTile(
                  icon: Icons.account_balance_rounded,
                  color: style.$1,
                  background: style.$2,
                  size: 40,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 14,
                          color: AppTheme.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        acc.bankName.isEmpty ? type : acc.bankName,
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
                _buildMenu(acc),
              ],
            ),
            const Spacer(),
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _money(acc.balance),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                          color: acc.balance >= 0
                              ? AppTheme.successColor
                              : AppTheme.errorColor,
                        ),
                      ),
                      const SizedBox(height: 2),
                      const Text(
                        'Available Balance',
                        style: TextStyle(
                          fontSize: 10.5,
                          color: AppTheme.textMuted,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: style.$2,
                    borderRadius: BorderRadius.circular(100),
                  ),
                  child: Text(
                    type,
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      color: style.$1,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGrid() {
    return LayoutBuilder(
      builder: (context, constraints) {
        const spacing = 12.0;
        final columns = constraints.maxWidth > 1000
            ? 3
            : constraints.maxWidth > 640
                ? 2
                : 1;
        final itemWidth =
            (constraints.maxWidth - spacing * (columns - 1)) / columns;

        return Wrap(
          spacing: spacing,
          runSpacing: spacing,
          children: _filtered
              .map((acc) => SizedBox(width: itemWidth, child: _buildAccountCard(acc)))
              .toList(),
        );
      },
    );
  }

  Future<void> _openMovements(BankAccount acc) async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => BankAccountMovementsScreen(account: acc),
      ),
    );
    if (!mounted) return;
    _load();
  }

  Widget _buildMenu(BankAccount acc) {
    return PopupMenuButton<String>(
      onSelected: (value) {
        if (value == 'edit') {
          _edit(acc);
        } else if (value == 'transactions') {
          _openMovements(acc);
        } else if (value == 'delete') {
          _confirmDelete(acc);
        }
      },
      padding: EdgeInsets.zero,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      itemBuilder: (context) => const [
        PopupMenuItem(
          value: 'edit',
          child: Row(
            children: [
              Icon(Icons.edit_outlined,
                  size: 16, color: AppTheme.iconGreen),
              SizedBox(width: 8),
              Text('Edit'),
            ],
          ),
        ),
        PopupMenuItem(
          value: 'transactions',
          child: Row(
            children: [
              Icon(Icons.receipt_long_outlined,
                  size: 16, color: AppTheme.iconBlue),
              SizedBox(width: 8),
              Text('Transactions'),
            ],
          ),
        ),
        PopupMenuItem(
          value: 'delete',
          child: Row(
            children: [
              Icon(Icons.delete_outline_rounded,
                  size: 16, color: AppTheme.iconRed),
              SizedBox(width: 8),
              Text(
                'Delete',
                style: TextStyle(color: AppTheme.errorColor),
              ),
            ],
          ),
        ),
      ],
      child: const Padding(
        padding: EdgeInsets.all(4),
        child: Icon(
          Icons.more_horiz_rounded,
          size: 20,
          color: AppTheme.textMuted,
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const EmptyState(
            icon: Icons.account_balance_outlined,
            title: 'No bank accounts yet',
            message: 'Add an account to track your bank balances here.',
          ),
          const SizedBox(height: 8),
          PrimaryButton(
            label: 'Add Account',
            icon: Icons.add_rounded,
            expanded: false,
            onPressed: _add,
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final canPop = Navigator.of(context).canPop();
    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      body: Column(
        children: [
          ScreenHeader(
            showBack: canPop,
            title: 'Bank Accounts',
            subtitle: 'Savings, current and other accounts',
            actions: [
              HeaderIconButton(
                icon: Icons.add_rounded,
                color: AppTheme.iconGreen,
                onTap: _add,
              ),
            ],
          ),
          Expanded(
            child: _loading
                ? const Center(
                    child:
                        CircularProgressIndicator(color: AppTheme.primaryColor))
                : _accounts.isEmpty
                    ? _buildEmptyState()
                    : RefreshIndicator(
                        onRefresh: _load,
                        child: ListView(
                          physics: const AlwaysScrollableScrollPhysics(),
                          padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
                          children: [
                            _buildSummary(),
                            const SizedBox(height: 12),
                            SearchField(
                              hint: 'Search by name, bank or number...',
                              onChanged: (v) =>
                                  setState(() => _search = v),
                            ),
                            const SizedBox(height: 12),
                            if (_filtered.isEmpty)
                              const EmptyState(
                                icon: Icons.search_off_rounded,
                                title: 'No accounts found',
                                message:
                                    'Try a different name, bank or number.',
                              )
                            else
                              _buildGrid(),
                          ],
                        ),
                      ),
          ),
        ],
      ),
    );
  }
}
