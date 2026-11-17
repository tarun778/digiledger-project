class Transaction {
  final String id;
  final String description;
  final String category;
  final String categoryName;
  final String paymentMethod;
  final String transactionType;
  final String bankAccount;
  final String bankAccountName;
  final String bankAccountNumber;
  final bool toBank;
  final String transactionRef;
  final double debitAmount;
  final double charges;
  final double profit;
  final String customerName;
  final String customerPhone;
  final String remarks;
  final DateTime date;
  final String userName;

  Transaction({
    required this.id,
    required this.description,
    required this.category,
    required this.categoryName,
    required this.paymentMethod,
    this.transactionType = 'income',
    this.bankAccount = '',
    this.bankAccountName = '',
    this.bankAccountNumber = '',
    this.toBank = false,
    required this.transactionRef,
    required this.debitAmount,
    required this.charges,
    required this.profit,
    required this.customerName,
    required this.customerPhone,
    required this.remarks,
    required this.date,
    required this.userName,
  });

  factory Transaction.fromJson(Map<String, dynamic> json) {
    return Transaction(
      id: json['id'],
      description: json['description'],
      category: json['category'] ?? '',
      categoryName: json['category_name'] ?? '',
      paymentMethod: json['payment_method'],
      transactionType: json['transaction_type'] ?? 'income',
      bankAccount: json['bank_account']?.toString() ?? '',
      bankAccountName: json['bank_account_name'] ?? '',
      bankAccountNumber: json['bank_account_number'] ?? '',
      toBank: json['to_bank'] ?? false,
      transactionRef: json['transaction_ref'] ?? '',
      debitAmount: double.parse(json['debit_amount'].toString()),
      charges: double.parse(json['charges'].toString()),
      profit: double.parse(json['profit'].toString()),
      customerName: json['customer_name'] ?? '',
      customerPhone: json['customer_phone'] ?? '',
      remarks: json['remarks'] ?? '',
      date: DateTime.parse(json['date']),
      userName: json['user_name'] ?? '',
    );
  }

  String get paymentMethodLabel {
    switch (paymentMethod) {
      case 'cash': return 'Cash';
      case 'upi_gpay': return 'Google Pay';
      case 'upi_phonepe': return 'PhonePe';
      case 'upi_paytm': return 'Paytm';
      case 'upi_other': return 'Other UPI';
      case 'net_banking': return 'Net Banking';
      case 'card': return 'Card';
      default: return paymentMethod;
    }
  }
}
