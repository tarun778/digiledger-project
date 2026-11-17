from django.db import models
from django.conf import settings
import uuid


class Category(models.Model):
    TYPE_CHOICES = (
        ("service", "Service"),
        ("cc_bill", "Credit Card Bill"),
    )

    id = models.UUIDField(primary_key=True, default=uuid.uuid4, editable=False)
    shop = models.ForeignKey("accounts.Shop", on_delete=models.CASCADE, related_name="categories")
    name = models.CharField(max_length=200)
    icon = models.CharField(max_length=50, blank=True, default="📦")
    category_type = models.CharField(max_length=20, choices=TYPE_CHOICES, default="service")
    is_custom = models.BooleanField(default=False)
    is_active = models.BooleanField(default=True)
    created_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        verbose_name_plural = "Categories"
        ordering = ["name"]

    def __str__(self):
        return f"{self.name} ({self.shop.name})"


class BankAccount(models.Model):
    ACCOUNT_TYPES = (
        ("savings", "Savings"),
        ("current", "Current"),
        ("other", "Other"),
    )

    id = models.UUIDField(primary_key=True, default=uuid.uuid4, editable=False)
    shop = models.ForeignKey("accounts.Shop", on_delete=models.CASCADE, related_name="bank_accounts")
    account_name = models.CharField(max_length=120, help_text="e.g. HDFC Savings, Shop Current A/c")
    bank_name = models.CharField(max_length=120, blank=True, default="")
    account_number = models.CharField(max_length=30, blank=True, default="")
    account_type = models.CharField(max_length=20, choices=ACCOUNT_TYPES, default="savings")
    account_type_other = models.CharField(max_length=50, blank=True, default="", help_text="Free-text type when account_type = other")
    opening_balance = models.DecimalField(
        max_digits=12, decimal_places=2, default=0,
        help_text="Balance entered manually when the account was added",
    )
    is_active = models.BooleanField(default=True)
    created_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        verbose_name_plural = "Bank Accounts"
        ordering = ["account_name"]

    def __str__(self):
        return f"{self.account_name} ({self.shop.name})"

    @property
    def type_label(self):
        if self.account_type == "other":
            return self.account_type_other or "Other"
        return dict(self.ACCOUNT_TYPES).get(self.account_type, self.account_type)

    @property
    def masked_number(self):
        number = (self.account_number or "").strip()
        if not number:
            return ""
        if len(number) <= 4:
            return number
        return "•••• " + number[-4:]

    @property
    def balance(self):
        """Current balance = manual entry + money in - money out across the app."""
        return account_balance(self)

    def balance_map(self):
        return {self.id: account_balance(self)}


def account_balance(account):
    from django.db.models import Sum, F

    if account is None:
        return 0
    txn = Transaction.objects.filter(bank_account=account)
    inflow = (
        txn.filter(transaction_type="income", to_bank=True)
        .aggregate(v=Sum(F("debit_amount") + F("profit")))["v"] or 0
    )
    outflow = txn.filter(transaction_type="expense").aggregate(v=Sum("debit_amount"))["v"] or 0
    cc_in = (
        CCBillPayment.objects.filter(bank_account=account, to_bank=True)
        .aggregate(v=Sum(F("amount_paid") + F("profit")))["v"] or 0
    )
    credit_given = CreditEntry.objects.filter(bank_account=account, entry_type="given").aggregate(v=Sum("amount"))["v"] or 0
    credit_returned = (
        CreditEntry.objects.filter(bank_account=account, entry_type="returned", to_bank=True)
        .aggregate(v=Sum("amount"))["v"] or 0
    )
    return account.opening_balance + inflow - outflow + cc_in - credit_given + credit_returned


def account_balances(shop, accounts):
    """Balances for many accounts with a fixed number of queries (used by the list view)."""
    from django.db.models import Sum, F

    ids = [a.id for a in accounts]
    if not ids:
        return {}

    txns = Transaction.objects.filter(shop=shop, bank_account_id__in=ids)
    inflow = dict(
        txns.filter(transaction_type="income", to_bank=True)
        .values_list("bank_account_id")
        .annotate(v=Sum(F("debit_amount") + F("profit")))
        .values_list("bank_account_id", "v")
    )
    outflow = dict(
        txns.filter(transaction_type="expense")
        .values_list("bank_account_id")
        .annotate(v=Sum("debit_amount"))
        .values_list("bank_account_id", "v")
    )
    cc_in = dict(
        CCBillPayment.objects.filter(shop=shop, bank_account_id__in=ids, to_bank=True)
        .values_list("bank_account_id")
        .annotate(v=Sum(F("amount_paid") + F("profit")))
        .values_list("bank_account_id", "v")
    )
    credits = CreditEntry.objects.filter(shop=shop, bank_account_id__in=ids)
    given = dict(
        credits.filter(entry_type="given")
        .values_list("bank_account_id")
        .annotate(v=Sum("amount"))
        .values_list("bank_account_id", "v")
    )
    returned = dict(
        credits.filter(entry_type="returned", to_bank=True)
        .values_list("bank_account_id")
        .annotate(v=Sum("amount"))
        .values_list("bank_account_id", "v")
    )

    return {
        a.id: (
            a.opening_balance
            + (inflow.get(a.id) or 0)
            - (outflow.get(a.id) or 0)
            + (cc_in.get(a.id) or 0)
            - (given.get(a.id) or 0)
            + (returned.get(a.id) or 0)
        )
        for a in accounts
    }


class Transaction(models.Model):
    DIRECTION_CHOICES = (
        ("income", "Money In"),
        ("expense", "Money Out"),
    )

    PAYMENT_METHOD_CHOICES = (
        ("cash", "Cash"),
        ("upi_gpay", "Google Pay"),
        ("upi_phonepe", "PhonePe"),
        ("upi_paytm", "Paytm"),
        ("upi_other", "Other UPI"),
        ("net_banking", "Net Banking"),
        ("card", "Card"),
        ("other", "Other"),
    )

    id = models.UUIDField(primary_key=True, default=uuid.uuid4, editable=False)
    shop = models.ForeignKey("accounts.Shop", on_delete=models.CASCADE, related_name="transactions")
    user = models.ForeignKey(settings.AUTH_USER_MODEL, on_delete=models.SET_NULL, null=True, related_name="transactions")
    category = models.ForeignKey(Category, on_delete=models.SET_NULL, null=True, related_name="transactions")
    customer = models.ForeignKey("customers.Customer", on_delete=models.SET_NULL, null=True, blank=True, related_name="transactions")
    bank_account = models.ForeignKey(
        BankAccount, on_delete=models.SET_NULL, null=True, blank=True,
        related_name="transactions", help_text="Account money moves in/out of",
    )
    to_bank = models.BooleanField(
        default=False,
        help_text="Money In credited to the bank account (payment + profit). Off = cash in hand, bank untouched",
    )

    # Transaction details
    transaction_type = models.CharField(max_length=20, choices=DIRECTION_CHOICES, default="income")
    description = models.CharField(max_length=500, help_text="e.g., Bus ticket from Chennai to Bangalore")
    transaction_ref = models.CharField(max_length=200, blank=True, default="", help_text="PNR, UPI Ref, Receipt No")
    payment_method = models.CharField(max_length=30, choices=PAYMENT_METHOD_CHOICES, default="cash")
    debit_amount = models.DecimalField(max_digits=12, decimal_places=2, help_text="Amount paid by customer")
    charges = models.DecimalField(max_digits=12, decimal_places=2, default=0, help_text="Service charges collected")
    profit = models.DecimalField(max_digits=12, decimal_places=2, default=0, help_text="Profit = charges")

    # Customer info (if no customer profile linked)
    customer_name = models.CharField(max_length=200, blank=True, default="")
    customer_phone = models.CharField(max_length=15, blank=True, default="")

    # Extra
    remarks = models.TextField(blank=True, default="")
    date = models.DateField()
    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)

    class Meta:
        ordering = ["-date", "-created_at"]

    def __str__(self):
        return f"{self.description} - ₹{self.debit_amount} ({self.shop.name})"

    def save(self, *args, **kwargs):
        self.profit = self.charges
        super().save(*args, **kwargs)


class CCBillPayment(models.Model):
    BANK_CHOICES = (
        ("sbi", "SBI"),
        ("hdfc", "HDFC"),
        ("icici", "ICICI"),
        ("axis", "Axis"),
        ("kotak", "Kotak"),
        ("yes_bank", "Yes Bank"),
        ("rbl", "RBL"),
        ("au_bank", "AU Bank"),
        ("indusind", "IndusInd"),
        ("bob", "Bank of Baroda"),
        ("pnb", "Punjab National Bank"),
        ("other", "Other"),
    )

    PAYMENT_METHOD_CHOICES = (
        ("cash", "Cash"),
        ("upi_gpay", "Google Pay"),
        ("upi_phonepe", "PhonePe"),
        ("upi_paytm", "Paytm"),
        ("upi_other", "Other UPI"),
        ("net_banking", "Net Banking"),
        ("other", "Other"),
    )

    id = models.UUIDField(primary_key=True, default=uuid.uuid4, editable=False)
    shop = models.ForeignKey("accounts.Shop", on_delete=models.CASCADE, related_name="cc_bill_payments")
    user = models.ForeignKey(settings.AUTH_USER_MODEL, on_delete=models.SET_NULL, null=True, related_name="cc_bill_payments")
    customer = models.ForeignKey("customers.Customer", on_delete=models.SET_NULL, null=True, blank=True, related_name="cc_bill_payments")
    bank_account = models.ForeignKey(
        BankAccount, on_delete=models.SET_NULL, null=True, blank=True,
        related_name="cc_bill_payments", help_text="Account the bill was paid from",
    )
    to_bank = models.BooleanField(
        default=False,
        help_text="Money In credited to the bank account (amount paid + service charges). Off = cash in hand",
    )

    # CC Bill details
    customer_name = models.CharField(max_length=200)
    customer_phone = models.CharField(max_length=15)
    bank_name = models.CharField(max_length=30, choices=BANK_CHOICES, default="other")
    card_last_4 = models.CharField(max_length=4, blank=True, default="", help_text="Last 4 digits of card")
    bill_amount = models.DecimalField(max_digits=12, decimal_places=2, help_text="Actual credit card bill amount")
    amount_paid = models.DecimalField(max_digits=12, decimal_places=2, help_text="Amount customer wants to pay")
    payment_method = models.CharField(max_length=30, choices=PAYMENT_METHOD_CHOICES, default="cash")
    transaction_ref = models.CharField(max_length=200, blank=True, default="")
    service_charges = models.DecimalField(max_digits=12, decimal_places=2, default=0)
    profit = models.DecimalField(max_digits=12, decimal_places=2, default=0)
    due_date = models.DateField(null=True, blank=True)
    remarks = models.TextField(blank=True, default="")
    date = models.DateField()
    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)

    class Meta:
        verbose_name_plural = "CC Bill Payments"
        ordering = ["-date", "-created_at"]

    def __str__(self):
        return f"{self.customer_name} - ₹{self.amount_paid} ({self.bank_name})"

    def save(self, *args, **kwargs):
        self.profit = self.service_charges
        super().save(*args, **kwargs)


class DescriptionSuggestion(models.Model):
    id = models.UUIDField(primary_key=True, default=uuid.uuid4, editable=False)
    shop = models.ForeignKey("accounts.Shop", on_delete=models.CASCADE, related_name="description_suggestions")
    text = models.CharField(max_length=300)
    is_default = models.BooleanField(default=False, help_text="Built-in default suggestion")
    sort_order = models.IntegerField(default=0)
    created_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        ordering = ["sort_order", "text"]
        unique_together = ["shop", "text"]

    def __str__(self):
        return self.text


class CreditEntry(models.Model):
    ENTRY_TYPES = (
        ("given", "Credit Given"),
        ("returned", "Amount Returned"),
    )

    id = models.UUIDField(primary_key=True, default=uuid.uuid4, editable=False)
    shop = models.ForeignKey("accounts.Shop", on_delete=models.CASCADE, related_name="credit_entries")
    user = models.ForeignKey(settings.AUTH_USER_MODEL, on_delete=models.SET_NULL, null=True, related_name="credit_entries")
    bank_account = models.ForeignKey(
        BankAccount, on_delete=models.SET_NULL, null=True, blank=True,
        related_name="credit_entries", help_text="Account the credit was given from / repaid into",
    )
    to_bank = models.BooleanField(
        default=False,
        help_text="Repayment credited to the bank account. Off = cash in hand",
    )
    customer_name = models.CharField(max_length=200)
    customer_phone = models.CharField(max_length=20, blank=True, default="")
    entry_type = models.CharField(max_length=20, choices=ENTRY_TYPES)
    amount = models.DecimalField(max_digits=12, decimal_places=2)
    remarks = models.TextField(blank=True, default="")
    date = models.DateField()
    created_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        verbose_name_plural = "Credit Entries"
        ordering = ["-date", "-created_at"]

    def __str__(self):
        return f"{self.customer_name} - ₹{self.amount} ({self.entry_type})"

    @property
    def pending_balance(self):
        given = CreditEntry.objects.filter(
            shop=self.shop, customer_name=self.customer_name, entry_type="given"
        ).aggregate(total=Sum("amount"))["total"] or 0
        returned = CreditEntry.objects.filter(
            shop=self.shop, customer_name=self.customer_name, entry_type="returned"
        ).aggregate(total=Sum("amount"))["total"] or 0
        return given - returned
