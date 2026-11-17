from rest_framework import serializers
from .models import (
    BankAccount, Category, Transaction, CCBillPayment, CreditEntry,
    DescriptionSuggestion, account_balance, account_balances,
)


class BankAccountSerializer(serializers.ModelSerializer):
    balance = serializers.SerializerMethodField()
    type_label = serializers.CharField(read_only=True)
    masked_number = serializers.CharField(read_only=True)

    class Meta:
        model = BankAccount
        fields = (
            "id", "account_name", "bank_name", "account_number", "account_type",
            "account_type_other", "opening_balance", "is_active", "type_label",
            "masked_number", "balance", "created_at",
        )
        read_only_fields = ("id", "created_at")

    def get_balance(self, obj):
        balances = self.context.get("balances")
        if balances is not None and obj.id in balances:
            return balances[obj.id]
        return obj.balance

    def validate(self, attrs):
        if attrs.get("account_type") == "other" and not (attrs.get("account_type_other") or "").strip():
            raise serializers.ValidationError({"account_type_other": "Enter the account type."})
        return attrs


class CategorySerializer(serializers.ModelSerializer):
    class Meta:
        model = Category
        fields = "__all__"
        read_only_fields = ("id", "shop", "created_at")


class TransactionSerializer(serializers.ModelSerializer):
    category_name = serializers.CharField(source="category.name", read_only=True)
    user_name = serializers.CharField(source="user.name", read_only=True)
    bank_account_name = serializers.CharField(source="bank_account.account_name", read_only=True)

    class Meta:
        model = Transaction
        fields = "__all__"
        read_only_fields = ("id", "shop", "user", "profit", "created_at", "updated_at")

    def validate_bank_account(self, value):
        if value is None:
            return value
        request = self.context.get("request")
        if request is not None and value.shop_id != request.user.shop_id:
            raise serializers.ValidationError("Invalid bank account.")
        return value

    def create(self, validated_data):
        validated_data["shop"] = self.context["request"].user.shop
        validated_data["user"] = self.context["request"].user
        return super().create(validated_data)


class TransactionListSerializer(serializers.ModelSerializer):
    category_name = serializers.CharField(source="category.name", read_only=True)
    user_name = serializers.CharField(source="user.name", read_only=True)
    bank_account_name = serializers.CharField(source="bank_account.account_name", read_only=True)
    bank_account_number = serializers.CharField(source="bank_account.masked_number", read_only=True)

    class Meta:
        model = Transaction
        fields = (
            "id", "description", "category", "category_name", "payment_method",
            "transaction_type", "bank_account", "bank_account_name",
            "bank_account_number", "to_bank", "transaction_ref", "debit_amount", "charges", "profit",
            "customer_name", "customer_phone", "remarks", "date", "created_at", "user_name",
        )


class CCBillPaymentSerializer(serializers.ModelSerializer):
    bank_account_name = serializers.CharField(source="bank_account.account_name", read_only=True)

    class Meta:
        model = CCBillPayment
        fields = "__all__"
        read_only_fields = ("id", "shop", "user", "profit", "created_at", "updated_at")

    def validate_bank_account(self, value):
        if value is None:
            return value
        request = self.context.get("request")
        if request is not None and value.shop_id != request.user.shop_id:
            raise serializers.ValidationError("Invalid bank account.")
        return value

    def create(self, validated_data):
        validated_data["shop"] = self.context["request"].user.shop
        validated_data["user"] = self.context["request"].user
        return super().create(validated_data)


class CCBillPaymentListSerializer(serializers.ModelSerializer):
    bank_account_name = serializers.CharField(source="bank_account.account_name", read_only=True)
    bank_account_number = serializers.CharField(source="bank_account.masked_number", read_only=True)

    class Meta:
        model = CCBillPayment
        fields = (
            "id", "customer_name", "customer_phone", "bank_name", "card_last_4",
            "bill_amount", "amount_paid", "payment_method", "bank_account",
            "bank_account_name", "bank_account_number", "to_bank", "transaction_ref",
            "service_charges", "profit", "due_date", "remarks", "date", "created_at",
        )


class CreditEntrySerializer(serializers.ModelSerializer):
    user_name = serializers.CharField(source="user.name", read_only=True)
    bank_account_name = serializers.CharField(source="bank_account.account_name", read_only=True)

    class Meta:
        model = CreditEntry
        fields = "__all__"
        read_only_fields = ("id", "shop", "user", "created_at")

    def validate_bank_account(self, value):
        if value is None:
            return value
        request = self.context.get("request")
        if request is not None and value.shop_id != request.user.shop_id:
            raise serializers.ValidationError("Invalid bank account.")
        return value

    def create(self, validated_data):
        validated_data["shop"] = self.context["request"].user.shop
        validated_data["user"] = self.context["request"].user
        return super().create(validated_data)


class CreditEntryListSerializer(serializers.ModelSerializer):
    user_name = serializers.CharField(source="user.name", read_only=True)
    bank_account_name = serializers.CharField(source="bank_account.account_name", read_only=True)
    bank_account_number = serializers.CharField(source="bank_account.masked_number", read_only=True)

    class Meta:
        model = CreditEntry
        fields = (
            "id", "customer_name", "customer_phone", "entry_type",
            "amount", "remarks", "date", "user_name", "created_at",
            "bank_account", "bank_account_name", "bank_account_number", "to_bank",
        )


class DashboardSerializer(serializers.Serializer):
    today_transactions = serializers.IntegerField()
    today_revenue = serializers.DecimalField(max_digits=12, decimal_places=2)
    today_profit = serializers.DecimalField(max_digits=12, decimal_places=2)
    month_transactions = serializers.IntegerField()
    month_revenue = serializers.DecimalField(max_digits=12, decimal_places=2)
    month_profit = serializers.DecimalField(max_digits=12, decimal_places=2)
    total_customers = serializers.IntegerField()
    recent_transactions = TransactionListSerializer(many=True)


class DescriptionSuggestionSerializer(serializers.ModelSerializer):
    class Meta:
        model = DescriptionSuggestion
        fields = ("id", "text", "is_default", "sort_order", "created_at")
        read_only_fields = ("id", "is_default", "created_at")

    def create(self, validated_data):
        validated_data["shop"] = self.context["request"].user.shop
        return super().create(validated_data)
