class CreditEntry {
  final String id;
  final String customerName;
  final String customerPhone;
  final String entryType;
  final double amount;
  final String remarks;
  final DateTime date;
  final String userName;
  final String bankAccount;
  final String bankAccountName;
  final String bankAccountNumber;
  final bool toBank;

  CreditEntry({
    required this.id,
    required this.customerName,
    required this.customerPhone,
    required this.entryType,
    required this.amount,
    required this.remarks,
    required this.date,
    required this.userName,
    this.bankAccount = '',
    this.bankAccountName = '',
    this.bankAccountNumber = '',
    this.toBank = false,
  });

  factory CreditEntry.fromJson(Map<String, dynamic> json) {
    return CreditEntry(
      id: json['id'],
      customerName: json['customer_name'],
      customerPhone: json['customer_phone'] ?? '',
      entryType: json['entry_type'],
      amount: double.parse(json['amount'].toString()),
      remarks: json['remarks'] ?? '',
      date: DateTime.parse(json['date']),
      userName: json['user_name'] ?? '',
      bankAccount: json['bank_account']?.toString() ?? '',
      bankAccountName: json['bank_account_name'] ?? '',
      bankAccountNumber: json['bank_account_number'] ?? '',
      toBank: json['to_bank'] ?? false,
    );
  }

  String get entryTypeLabel => entryType == 'given' ? 'Credit Given' : 'Amount Returned';
}
