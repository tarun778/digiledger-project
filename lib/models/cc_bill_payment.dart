class CCBillPayment {
  final String id;
  final String customerName;
  final String customerPhone;
  final String bankName;
  final String cardLast4;
  final double billAmount;
  final double amountPaid;
  final String paymentMethod;
  final String bankAccount;
  final String bankAccountName;
  final String bankAccountNumber;
  final bool toBank;
  final String transactionRef;
  final double serviceCharges;
  final double profit;
  final DateTime? dueDate;
  final String remarks;
  final DateTime date;

  CCBillPayment({
    required this.id,
    required this.customerName,
    required this.customerPhone,
    required this.bankName,
    required this.cardLast4,
    required this.billAmount,
    required this.amountPaid,
    required this.paymentMethod,
    this.bankAccount = '',
    this.bankAccountName = '',
    this.bankAccountNumber = '',
    this.toBank = false,
    required this.transactionRef,
    required this.serviceCharges,
    required this.profit,
    this.dueDate,
    required this.remarks,
    required this.date,
  });

  factory CCBillPayment.fromJson(Map<String, dynamic> json) {
    return CCBillPayment(
      id: json['id'],
      customerName: json['customer_name'],
      customerPhone: json['customer_phone'],
      bankName: json['bank_name'],
      cardLast4: json['card_last_4'] ?? '',
      billAmount: double.parse(json['bill_amount'].toString()),
      amountPaid: double.parse(json['amount_paid'].toString()),
      paymentMethod: json['payment_method'],
      bankAccount: json['bank_account']?.toString() ?? '',
      bankAccountName: json['bank_account_name'] ?? '',
      bankAccountNumber: json['bank_account_number'] ?? '',
      toBank: json['to_bank'] ?? false,
      transactionRef: json['transaction_ref'] ?? '',
      serviceCharges: double.parse(json['service_charges'].toString()),
      profit: double.parse(json['profit'].toString()),
      dueDate: json['due_date'] != null ? DateTime.parse(json['due_date']) : null,
      remarks: json['remarks'] ?? '',
      date: DateTime.parse(json['date']),
    );
  }

  String get bankLabel {
    switch (bankName) {
      case 'sbi': return 'SBI';
      case 'hdfc': return 'HDFC';
      case 'icici': return 'ICICI';
      case 'axis': return 'Axis';
      case 'kotak': return 'Kotak';
      case 'yes_bank': return 'Yes Bank';
      case 'rbl': return 'RBL';
      case 'au_bank': return 'AU Bank';
      case 'indusind': return 'IndusInd';
      case 'bob': return 'Bank of Baroda';
      case 'pnb': return 'PNB';
      default: return 'Other';
    }
  }
}
