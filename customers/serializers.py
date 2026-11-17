from rest_framework import serializers
from .models import Customer


class CustomerSerializer(serializers.ModelSerializer):
    class Meta:
        model = Customer
        fields = "__all__"
        read_only_fields = ("id", "shop", "total_transactions", "total_spent", "total_profit", "created_at", "updated_at")

    def create(self, validated_data):
        validated_data["shop"] = self.context["request"].user.shop
        return super().create(validated_data)


class CustomerListSerializer(serializers.ModelSerializer):
    class Meta:
        model = Customer
        fields = (
            "id", "name", "phone", "email", "total_transactions",
            "total_spent", "total_profit", "created_at",
        )


class CustomerDetailSerializer(serializers.ModelSerializer):
    recent_transactions = serializers.SerializerMethodField()
    recent_cc_bills = serializers.SerializerMethodField()

    class Meta:
        model = Customer
        fields = "__all__"
        read_only_fields = ("id", "shop", "total_transactions", "total_spent", "total_profit", "created_at", "updated_at")

    def get_recent_transactions(self, obj):
        from transactions.serializers import TransactionListSerializer
        return TransactionListSerializer(
            obj.transactions.all()[:10], many=True
        ).data

    def get_recent_cc_bills(self, obj):
        from transactions.serializers import CCBillPaymentListSerializer
        return CCBillPaymentListSerializer(
            obj.cc_bill_payments.all()[:10], many=True
        ).data
