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

class AddCCBillScreen extends StatefulWidget {
  const AddCCBillScreen({super.key});

  @override
  State<AddCCBillScreen> createState() => _AddCCBillScreenState();
}

class _AddCCBillScreenState extends State<AddCCBillScreen> {
  final _formKey = GlobalKey<FormState>();
  final _customerNameController = TextEditingController();
  final _customerPhoneController = TextEditingController();
  final _cardLast4Controller = TextEditingController();
  final _billAmountController = TextEditingController();
  final _amountPaidController = TextEditingController();
  final _chargesController = TextEditingController();
  final _refController = TextEditingController();
  final _remarksController = TextEditingController();

  String _bankName = 'sbi';
  String _paymentMethod = 'cash';
  DateTime _selectedDate = DateTime.now();
  DateTime? _dueDate;
  bool _isSaving = false;
  List<BankAccount> _bankAccounts = [];
  BankAccount? _selectedBankAccount;
  bool? _toBankOverride;

  bool get _toBank => _toBankOverride ?? (_paymentMethod != 'cash');

  void _setPaymentMethod(String value) {
    setState(() {
      _paymentMethod = value;
      _toBankOverride = null;
    });
  }

  @override
  void initState() {
    super.initState();
    _loadBankAccounts();
  }

  @override
  void dispose() {
    _customerNameController.dispose();
    _customerPhoneController.dispose();
    _cardLast4Controller.dispose();
    _billAmountController.dispose();
    _amountPaidController.dispose();
    _chargesController.dispose();
    _refController.dispose();
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

  /// Which of the four mockup tiles (Cash / UPI / Bank / Other) is active.
  String get _methodGroup {
    switch (_paymentMethod) {
      case 'cash':
        return 'cash';
      case 'upi_gpay':
      case 'upi_phonepe':
      case 'upi_paytm':
      case 'upi_other':
        return 'upi';
      case 'net_banking':
        return 'bank';
      default:
        return 'other';
    }
  }

  static const TextStyle _labelStyle = TextStyle(
    fontSize: 12,
    fontWeight: FontWeight.w700,
    color: AppTheme.textPrimary,
  );

  Widget _label(String text) => Text(text, style: _labelStyle);

  Widget _labeled(String text, Widget child) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(text, style: _labelStyle),
          const SizedBox(height: 6),
          child,
        ],
      );

  static const TextStyle _rupeeStyle = TextStyle(
    fontSize: 15,
    fontWeight: FontWeight.w700,
    color: AppTheme.textPrimary,
  );

  InputDecoration _amountDecoration(String hint) => InputDecoration(
        hintText: hint,
        prefixText: '₹ ',
        prefixStyle: _rupeeStyle,
      );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      body: Column(
        children: [
          const ScreenHeader(showBack: true, title: 'Add CC Bill'),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _label('Customer Details'),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                          child: _labeled(
                            'Customer Name',
                            TextFormField(
                              controller: _customerNameController,
                              decoration: const InputDecoration(
                                hintText: 'Enter customer name',
                                prefixIcon: Icon(Icons.person_rounded),
                              ),
                              validator: (value) =>
                                  value?.isEmpty ?? true ? 'Required' : null,
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _labeled(
                            'Phone Number',
                            TextFormField(
                              controller: _customerPhoneController,
                              keyboardType: TextInputType.phone,
                              decoration: const InputDecoration(
                                hintText: 'Enter phone number',
                                prefixIcon: Icon(Icons.phone_rounded),
                              ),
                              validator: (value) =>
                                  value?.isEmpty ?? true ? 'Required' : null,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 18),

                    _label('Card Details'),
                    const SizedBox(height: 10),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: _labeled(
                            'Bank',
                            SearchableDropdown<String>(
                              items: const [
                                SearchableDropdownItem(value: 'sbi', label: 'SBI'),
                                SearchableDropdownItem(value: 'hdfc', label: 'HDFC'),
                                SearchableDropdownItem(value: 'icici', label: 'ICICI'),
                                SearchableDropdownItem(value: 'axis', label: 'Axis'),
                                SearchableDropdownItem(value: 'kotak', label: 'Kotak'),
                                SearchableDropdownItem(value: 'yes_bank', label: 'Yes Bank'),
                                SearchableDropdownItem(value: 'rbl', label: 'RBL'),
                                SearchableDropdownItem(value: 'au_bank', label: 'AU Bank'),
                                SearchableDropdownItem(value: 'indusind', label: 'IndusInd'),
                                SearchableDropdownItem(value: 'bob', label: 'Bank of Baroda'),
                                SearchableDropdownItem(value: 'pnb', label: 'PNB'),
                                SearchableDropdownItem(value: 'other', label: 'Other'),
                              ],
                              value: _bankName,
                              hint: 'Select bank',
                              searchHint: 'Search banks…',
                              prefix: const Icon(Icons.account_balance_rounded,
                                  size: 18),
                              onChanged: (value) =>
                                  setState(() => _bankName = value ?? 'sbi'),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _labeled(
                            'Card Last 4 Digits',
                            TextFormField(
                              controller: _cardLast4Controller,
                              keyboardType: TextInputType.number,
                              maxLength: 4,
                              decoration: const InputDecoration(
                                hintText: '0000',
                                prefixIcon: Icon(Icons.credit_card_rounded),
                                counterText: '',
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 18),

                    _label('Payment Details'),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                          child: _labeled(
                            'Bill Amount',
                            TextFormField(
                              controller: _billAmountController,
                              keyboardType: TextInputType.number,
                              decoration: _amountDecoration('Bill Amount'),
                              validator: (value) {
                                if (value == null || value.trim().isEmpty) {
                                  return 'Required';
                                }
                                final amount = double.tryParse(value.trim());
                                if (amount == null) {
                                  return 'Enter a valid number';
                                }
                                if (amount <= 0) {
                                  return 'Amount must be greater than 0';
                                }
                                return null;
                              },
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _labeled(
                            'Amount Paid',
                            TextFormField(
                              controller: _amountPaidController,
                              keyboardType: TextInputType.number,
                              decoration: _amountDecoration('Amount Paid'),
                              validator: (value) {
                                if (value == null || value.trim().isEmpty) {
                                  return 'Required';
                                }
                                final paid = double.tryParse(value.trim());
                                if (paid == null) {
                                  return 'Enter a valid number';
                                }
                                if (paid < 0) return 'Cannot be negative';
                                return null;
                              },
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: _labeled(
                            'Service Charges',
                            TextFormField(
                              controller: _chargesController,
                              keyboardType: TextInputType.number,
                              decoration: _amountDecoration('Service Charges'),
                              validator: (value) {
                                if (value == null || value.trim().isEmpty) {
                                  return null;
                                }
                                if (double.tryParse(value.trim()) == null) {
                                  return 'Enter a valid number';
                                }
                                return null;
                              },
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _labeled(
                            'Transaction Reference',
                            TextFormField(
                              controller: _refController,
                              decoration: const InputDecoration(
                                hintText: 'UPI Ref, Receipt No',
                                prefixIcon: Icon(Icons.tag_rounded),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // Dates (existing date-picker behaviour preserved)
                    Row(
                      children: [
                        Expanded(
                          child: _labeled(
                            'Payment Date',
                            InkWell(
                              onTap: () async {
                                final date = await showDatePicker(
                                  context: context,
                                  initialDate: _selectedDate,
                                  firstDate: DateTime(2020),
                                  lastDate:
                                      DateTime.now().add(const Duration(days: 1)),
                                  useRootNavigator: false,
                                );
                                if (date != null) {
                                  if (!mounted) return;
                                  setState(() => _selectedDate = date);
                                }
                              },
                              borderRadius: BorderRadius.circular(10),
                              child: InputDecorator(
                                decoration: const InputDecoration(
                                  prefixIcon: Icon(
                                    Icons.calendar_today_rounded,
                                    size: 18,
                                    color: AppTheme.textSecondary,
                                  ),
                                ),
                                child: Text(
                                  DateFormat('MMMM d, yyyy').format(_selectedDate),
                                  style: const TextStyle(fontSize: 14),
                                ),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _labeled(
                            'Due Date',
                            InkWell(
                              onTap: () async {
                                final date = await showDatePicker(
                                  context: context,
                                  initialDate: _dueDate ??
                                      DateTime.now().add(const Duration(days: 7)),
                                  firstDate: DateTime.now(),
                                  lastDate: DateTime.now()
                                      .add(const Duration(days: 365)),
                                  useRootNavigator: false,
                                );
                                if (date != null) {
                                  if (!mounted) return;
                                  setState(() => _dueDate = date);
                                }
                              },
                              borderRadius: BorderRadius.circular(10),
                              child: InputDecorator(
                                decoration: const InputDecoration(
                                  prefixIcon: Icon(
                                    Icons.event_rounded,
                                    size: 18,
                                    color: AppTheme.textSecondary,
                                  ),
                                ),
                                child: Text(
                                  _dueDate != null
                                      ? DateFormat('MMMM d, yyyy').format(_dueDate!)
                                      : 'Select date',
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: _dueDate != null
                                        ? AppTheme.textPrimary
                                        : AppTheme.textMuted,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    _labeled('Payment Method', _buildPaymentMethodTiles()),
                    if (_methodGroup == 'upi') ...[
                      const SizedBox(height: 10),
                      _labeled(
                        'UPI App',
                        SearchableDropdown<String>(
                          items: const [
                            SearchableDropdownItem(value: 'upi_gpay', label: 'Google Pay'),
                            SearchableDropdownItem(value: 'upi_phonepe', label: 'PhonePe'),
                            SearchableDropdownItem(value: 'upi_paytm', label: 'Paytm'),
                            SearchableDropdownItem(value: 'upi_other', label: 'Other UPI'),
                          ],
                          value: _paymentMethod,
                          hint: 'Select UPI app',
                          searchHint: 'Search UPI apps…',
                              onChanged: (value) =>
                                  _setPaymentMethod(value ?? 'upi_gpay'),

                        ),
                      ),
                    ],
                    const SizedBox(height: 16),
                    _labeled(
                      'Bank or Cash',
                      BankCashToggle(
                        toBank: _toBank,
                        onChanged: (v) => setState(() => _toBankOverride = v),
                        bankHint:
                            'Amount paid + service charges is added to the selected bank account',
                      ),
                    ),
                    const SizedBox(height: 12),
                    if (_toBank)
                      _labeled(
                          'Bank Account (optional)', _buildBankAccountField())
                    else
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
                                'Paid in cash — bank balance will not change',
                                style: TextStyle(
                                    fontSize: 12,
                                    color: AppTheme.textSecondary),
                              ),
                            ),
                          ],
                        ),
                      ),
                    const SizedBox(height: 16),

                    _labeled(
                      'Remarks',
                      TextFormField(
                        controller: _remarksController,
                        maxLines: 3,
                        decoration: const InputDecoration(
                          hintText: 'Any additional notes...',
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),

                    PrimaryButton(
                      label: 'Save Bill',
                      loading: _isSaving,
                      onPressed: _isSaving ? null : _saveCCBillPayment,
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

  /// Cash / UPI / Bank / Other — 4 equal tiles, icon above label.
  Widget _buildPaymentMethodTiles() {
    return Row(
      children: [
        _methodTile(
          label: 'Cash',
          icon: Icons.payments_outlined,
          selected: _methodGroup == 'cash',
          onTap: () => _setPaymentMethod('cash'),
        ),
        const SizedBox(width: 8),
        _methodTile(
          label: 'UPI',
          icon: Icons.qr_code_2_rounded,
          selected: _methodGroup == 'upi',
          onTap: () => _setPaymentMethod('upi_gpay'),
        ),
        const SizedBox(width: 8),
        _methodTile(
          label: 'Bank',
          icon: Icons.account_balance_outlined,
          selected: _methodGroup == 'bank',
          onTap: () => _setPaymentMethod('net_banking'),
        ),
        const SizedBox(width: 8),
        _methodTile(
          label: 'Other',
          icon: Icons.more_horiz_rounded,
          selected: _methodGroup == 'other',
          onTap: () => _setPaymentMethod('other'),
        ),
      ],
    );
  }

  Widget _methodTile({
    required String label,
    required IconData icon,
    required bool selected,
    required VoidCallback onTap,
  }) {
    return Expanded(
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(10),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            height: 74,
            decoration: BoxDecoration(
              color: selected ? AppTheme.primaryColor : Colors.white,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: selected ? AppTheme.primaryColor : AppTheme.borderLight,
              ),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  icon,
                  size: 20,
                  color: selected ? Colors.white : AppTheme.textSecondary,
                ),
                const SizedBox(height: 6),
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight:
                        selected ? FontWeight.w700 : FontWeight.w500,
                    color: selected ? Colors.white : AppTheme.textPrimary,
                  ),
                ),
              ],
            ),
          ),
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

  Future<void> _saveCCBillPayment() async {
    if (!_formKey.currentState!.validate()) return;
    if (_toBank && _selectedBankAccount == null) {
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
      await ApiService.createCCBillPayment({
        'customer_name': _customerNameController.text.trim(),
        'customer_phone': _customerPhoneController.text.trim(),
        'bank_name': _bankName,
        'card_last_4': _cardLast4Controller.text.trim(),
        'bill_amount': double.tryParse(_billAmountController.text) ?? 0,
        'amount_paid': double.tryParse(_amountPaidController.text) ?? 0,
        'payment_method': _paymentMethod,
        'bank_account': _selectedBankAccount?.id,
        'to_bank': _toBank,
        'transaction_ref': _refController.text.trim(),
        'service_charges': double.tryParse(_chargesController.text) ?? 0,
        'due_date': _dueDate?.toIso8601String().split('T')[0],
        'remarks': _remarksController.text.trim(),
        'date': _selectedDate.toIso8601String().split('T')[0],
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Payment saved!'), backgroundColor: AppTheme.successColor),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (!mounted) return;
      showApiError(context, e);
    }
    if (mounted) setState(() => _isSaving = false);
  }
}
