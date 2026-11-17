import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../utils/theme.dart';
import '../../utils/errors.dart';
import '../../services/api_service.dart';
import '../../models/bank_account.dart';
import '../../widgets/bank_account_form.dart';
import '../../widgets/bank_cash_toggle.dart';
import '../../widgets/searchable_dropdown.dart';
import '../../widgets/ui_kit.dart';

class AddCreditEntryScreen extends StatefulWidget {
  final String? customerName;
  final String entryType;

  const AddCreditEntryScreen({super.key, this.customerName, this.entryType = 'given'});

  @override
  State<AddCreditEntryScreen> createState() => _AddCreditEntryScreenState();
}

class _AddCreditEntryScreenState extends State<AddCreditEntryScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _amountController = TextEditingController();
  final _remarksController = TextEditingController();

  late String _entryType;
  DateTime _selectedDate = DateTime.now();
  bool _isSaving = false;
  String _paymentMethod = 'Cash';

  List<Map<String, dynamic>> _pendingCustomers = [];
  String? _selectedCustomerName;
  bool _isLoadingCustomers = false;
  String? _customerError;
  List<BankAccount> _bankAccounts = [];
  BankAccount? _selectedBankAccount;
  bool? _toBankOverride;

  bool get _toBank => _toBankOverride ?? (_paymentMethod != 'Cash');

  static const List<(String, IconData)> _methods = [
    ('Cash', Icons.payments_outlined),
    ('UPI', Icons.qr_code_2_rounded),
    ('Bank', Icons.account_balance_rounded),
    ('Other', Icons.more_horiz_rounded),
  ];

  @override
  void initState() {
    super.initState();
    _entryType = widget.entryType;
    if (widget.customerName != null) {
      _nameController.text = widget.customerName!;
    }
    _loadPendingCustomers();
    _loadBankAccounts();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _amountController.dispose();
    _remarksController.dispose();
    super.dispose();
  }

  Future<void> _loadBankAccounts() async {
    try {
      final accounts = await ApiService.getBankAccounts();
      if (!mounted) return;
      setState(() => _bankAccounts = accounts);
    } catch (e) {
      if (!mounted) return;
      setState(() => _bankAccounts = []);
      showApiError(context, e);
    }
  }

  Future<void> _loadPendingCustomers() async {
    setState(() => _isLoadingCustomers = true);
    try {
      final summary = await ApiService.getCreditSummary();
      final customers = List<Map<String, dynamic>>.from(summary['customers'] ?? []);
      if (!mounted) return;
      setState(() {
        _pendingCustomers = customers.where((c) {
          final pending = (c['pending_amount'] ?? 0).toDouble();
          return pending > 0;
        }).toList();
        _isLoadingCustomers = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoadingCustomers = false);
      showApiError(context, e);
    }
  }

  void _onCustomerSelected(String? name) {
    setState(() {
      _selectedCustomerName = name;
      _nameController.text = name ?? '';
      _customerError = null;
      final customer = _pendingCustomers.firstWhere(
        (c) => c['customer_name'] == name,
        orElse: () => {},
      );
      if (customer.isNotEmpty) {
        _phoneController.text = customer['customer_phone'] ?? '';
      }
    });
  }

  Future<void> _selectDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      useRootNavigator: false,
    );
    if (picked != null) {
      if (!mounted) return;
      setState(() => _selectedDate = picked);
    }
  }

  Future<void> _saveEntry() async {
    if (!_formKey.currentState!.validate()) return;
    if (_entryType == 'returned' &&
        (_selectedCustomerName == null || _selectedCustomerName!.isEmpty)) {
      setState(() => _customerError = 'Please select a customer');
      return;
    }
    if (_entryType == 'returned' &&
        _toBank &&
        _selectedBankAccount == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content:
                Text('Choose a bank account, or switch to Cash in hand'),
            backgroundColor: AppTheme.errorColor),
      );
      return;
    }
    setState(() => _isSaving = true);
    try {
      await ApiService.createCreditEntry({
        'customer_name': _nameController.text.trim(),
        'customer_phone': _phoneController.text.trim(),
        'entry_type': _entryType,
        'amount': double.parse(_amountController.text),
        'bank_account': _selectedBankAccount?.id,
        'to_bank': _entryType == 'returned'
            ? _toBank
            : (_selectedBankAccount != null),
        'remarks': _remarksController.text.trim(),
        'date': _selectedDate.toIso8601String().split('T')[0],
      });
      if (mounted) {
        final label = _entryType == 'given' ? 'Credit given' : 'Return recorded';
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(label), backgroundColor: AppTheme.successColor),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _isSaving = false);
      showApiError(context, e);
    }
  }

  Widget _sectionLabel(String text) {
    return Text(
      text,
      style: const TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.w700,
        color: AppTheme.textPrimary,
      ),
    );
  }

  Widget _buildStatusOption({
    required bool selected,
    required IconData icon,
    required String title,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 13),
        decoration: BoxDecoration(
          color: selected ? AppTheme.tintGreenBg : Colors.white,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: selected ? AppTheme.primaryColor : AppTheme.borderLight,
            width: selected ? 1.4 : 1,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 17,
              color: selected ? AppTheme.iconGreen : AppTheme.textSecondary,
            ),
            const SizedBox(width: 8),
            Flexible(
              child: Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: selected ? FontWeight.w700 : FontWeight.w600,
                  color: selected ? AppTheme.primaryDark : AppTheme.textSecondary,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusOptions(bool isGiven) {
    return Row(
      children: [
        Expanded(
          child: _buildStatusOption(
            selected: isGiven,
            icon: Icons.arrow_upward_rounded,
            title: 'Credit Given',
            onTap: () => setState(() {
              _entryType = 'given';
              _selectedCustomerName = null;
            }),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _buildStatusOption(
            selected: !isGiven,
            icon: Icons.arrow_downward_rounded,
            title: 'Amount Returned',
            onTap: () => setState(() {
              _entryType = 'returned';
              _selectedCustomerName = null;
              _nameController.clear();
              _phoneController.clear();
            }),
          ),
        ),
      ],
    );
  }

  Widget _buildMethodTiles() {
    return Row(
      children: [
        for (var i = 0; i < _methods.length; i++) ...[
          if (i > 0) const SizedBox(width: 8),
          Expanded(child: _buildMethodTile(_methods[i].$1, _methods[i].$2)),
        ],
      ],
    );
  }

  Widget _buildMethodTile(String label, IconData icon) {
    final selected = _paymentMethod == label;
    return GestureDetector(
      onTap: () => setState(() {
        _paymentMethod = label;
        _toBankOverride = null;
      }),
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: selected ? AppTheme.primaryColor : Colors.white,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: selected ? AppTheme.primaryColor : AppTheme.borderLight,
          ),
        ),
        child: Column(
          children: [
            Icon(
              icon,
              size: 18,
              color: selected ? Colors.white : AppTheme.textSecondary,
            ),
            const SizedBox(height: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                fontWeight: selected ? FontWeight.w700 : FontWeight.w600,
                color: selected ? Colors.white : AppTheme.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBankAccountField() {
    return SearchableDropdown<BankAccount>(
      items: _bankAccounts
          .map((acc) => SearchableDropdownItem<BankAccount>(
                value: acc,
                label: acc.listLabel,
                leading: const Icon(Icons.account_balance_outlined,
                    size: 18, color: AppTheme.primaryColor),
              ))
          .toList(),
      value: _selectedBankAccount,
      hint: 'Select bank account',
      searchHint: 'Search bank accounts…',
      allLabel: 'Not linked',
      allowOther: true,
      otherLabel: 'Add bank account…',
      fillColor: Colors.white,
      onOtherSubmitted: (name) async {
        final created = await showBankAccountForm(context, initialName: name);
        if (created != null && mounted) {
          setState(() {
            _bankAccounts.insert(0, created);
            _selectedBankAccount = created;
          });
        }
      },
      onChanged: (value) => setState(() {
        _selectedBankAccount = value;
        if (value != null) _toBankOverride = true;
      }),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isGiven = _entryType == 'given';
    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ScreenHeader(
            showBack: true,
            title: isGiven ? 'Add Credit Entry' : 'Add Repayment',
          ),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _sectionLabel('Payment Status'),
                    const SizedBox(height: 8),
                    _buildStatusOptions(isGiven),
                    const SizedBox(height: 18),

                    if (!isGiven) ...[
                      if (_isLoadingCustomers)
                        const SizedBox(
                          height: 56,
                          child: Center(
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(strokeWidth: 2)),
                                SizedBox(width: 12),
                                Text('Loading pending customers...',
                                    style:
                                        TextStyle(fontSize: 13, color: AppTheme.textSecondary)),
                              ],
                            ),
                          ),
                        )
                      else ...[
                        _sectionLabel('Select Pending Customer'),
                        const SizedBox(height: 8),
                        SearchableDropdown<String>(
                          items: _pendingCustomers.map((c) {
                            final name = (c['customer_name'] ?? '').toString();
                            final pending =
                                (c['pending_amount'] ?? 0).toDouble();
                            return SearchableDropdownItem<String>(
                              value: name,
                              label:
                                  '$name  ·  ₹${pending.toStringAsFixed(0)} pending',
                            );
                          }).toList(),
                          value: _selectedCustomerName,
                          hint: 'Choose customer who owes you',
                          searchHint: 'Search customers…',
                          prefix: const Icon(Icons.person_search, size: 18),
                          onChanged: _onCustomerSelected,
                          errorText: () => _customerError,
                        ),
                      ],
                    ] else ...[
                      _sectionLabel('Customer Name'),
                      const SizedBox(height: 8),
                      TextFormField(
                        controller: _nameController,
                        decoration: const InputDecoration(
                          hintText: 'Enter customer name',
                          prefixIcon: Icon(Icons.person_outline, size: 20),
                        ),
                        validator: (v) => v?.isEmpty ?? true ? 'Required' : null,
                      ),
                    ],
                    const SizedBox(height: 16),

                    _sectionLabel('Phone (optional)'),
                    const SizedBox(height: 8),
                    TextFormField(
                      controller: _phoneController,
                      keyboardType: TextInputType.phone,
                      decoration: const InputDecoration(
                        hintText: 'Phone number',
                        prefixIcon: Icon(Icons.phone_outlined, size: 20),
                      ),
                    ),
                    const SizedBox(height: 16),

                    _sectionLabel('Amount'),
                    const SizedBox(height: 8),
                    TextFormField(
                      controller: _amountController,
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(
                        prefixText: '₹ ',
                        prefixStyle: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: AppTheme.textPrimary,
                        ),
                        hintText: isGiven
                            ? 'How much credit you gave?'
                            : 'How much did they return?',
                      ),
                      validator: (v) {
                        if (v == null || v.trim().isEmpty) return 'Required';
                        final amount = double.tryParse(v.trim());
                        if (amount == null) return 'Enter a valid amount';
                        if (amount <= 0) return 'Amount must be greater than 0';
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),

                    _sectionLabel('Date'),
                    const SizedBox(height: 8),
                    InkWell(
                      onTap: _selectDate,
                      borderRadius: BorderRadius.circular(10),
                      child: InputDecorator(
                        decoration: const InputDecoration(
                          hintText: 'Select date',
                          prefixIcon: Icon(Icons.calendar_today_outlined, size: 18),
                          suffixIcon: Icon(
                            Icons.keyboard_arrow_down_rounded,
                            size: 20,
                          ),
                        ),
                        child: Text(
                          DateFormat('MMMM d, yyyy').format(_selectedDate),
                          style: const TextStyle(
                            fontSize: 14,
                            color: AppTheme.textPrimary,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),

                    _sectionLabel('Payment Method'),
                    const SizedBox(height: 8),
                    _buildMethodTiles(),
                    const SizedBox(height: 16),

                    _sectionLabel(isGiven
                        ? 'Bank Account (optional)'
                        : 'Bank or Cash'),
                    const SizedBox(height: 8),
                    if (!isGiven) ...[
                      BankCashToggle(
                        toBank: _toBank,
                        onChanged: (v) =>
                            setState(() => _toBankOverride = v),
                        bankHint:
                            'Repayment amount is added to the selected bank account',
                      ),
                      const SizedBox(height: 12),
                    ],
                    if (!isGiven && !_toBank)
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: AppTheme.tintAmberBg,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Row(
                          children: [
                            Icon(Icons.payments_outlined,
                                size: 16, color: AppTheme.iconAmber),
                            SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'Received as cash — bank balance will not change',
                                style: TextStyle(
                                    fontSize: 12,
                                    color: AppTheme.textSecondary),
                              ),
                            ),
                          ],
                        ),
                      )
                    else
                      _buildBankAccountField(),
                    const SizedBox(height: 16),

                    _sectionLabel('Remarks (optional)'),
                    const SizedBox(height: 8),
                    TextFormField(
                      controller: _remarksController,
                      maxLines: 2,
                      decoration: const InputDecoration(
                        hintText: 'e.g., For bus ticket purchase',
                        prefixIcon: Icon(Icons.notes_outlined, size: 20),
                      ),
                    ),
                    const SizedBox(height: 28),

                    PrimaryButton(
                      label: isGiven ? 'Save Credit Entry' : 'Save Repayment',
                      loading: _isSaving,
                      onPressed: _saveEntry,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
