class BankAccount {
  final String id;
  final String accountName;
  final String bankName;
  final String accountNumber;
  final String accountType;
  final String accountTypeOther;
  final double openingBalance;
  final bool isActive;
  final String typeLabel;
  final String maskedNumber;
  final double balance;
  final String? createdAt;

  BankAccount({
    required this.id,
    required this.accountName,
    required this.bankName,
    required this.accountNumber,
    required this.accountType,
    required this.accountTypeOther,
    required this.openingBalance,
    required this.isActive,
    required this.typeLabel,
    required this.maskedNumber,
    required this.balance,
    this.createdAt,
  });

  factory BankAccount.fromJson(Map<String, dynamic> json) {
    return BankAccount(
      id: json['id'],
      accountName: json['account_name'] ?? '',
      bankName: json['bank_name'] ?? '',
      accountNumber: json['account_number'] ?? '',
      accountType: json['account_type'] ?? 'savings',
      accountTypeOther: json['account_type_other'] ?? '',
      openingBalance: double.tryParse(json['opening_balance'].toString()) ?? 0,
      isActive: json['is_active'] ?? true,
      typeLabel: json['type_label'] ?? '',
      maskedNumber: json['masked_number'] ?? '',
      balance: double.tryParse(json['balance'].toString()) ?? 0,
      createdAt: json['created_at']?.toString(),
    );
  }

  String get displayName {
    if (bankName.isEmpty) return accountName;
    return '$accountName ($bankName)';
  }

  String get listLabel {
    final type = typeLabel.isEmpty ? accountType : typeLabel;
    if (maskedNumber.isEmpty) return '$displayName • $type';
    return '$displayName • $type $maskedNumber';
  }

  bool get isNegative => balance < 0;
}
