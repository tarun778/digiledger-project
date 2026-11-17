from rest_framework import serializers
from accounts.models import Shop, User
from .models import Invoice


class AdminShopSerializer(serializers.ModelSerializer):
    user_count = serializers.SerializerMethodField()
    is_subscription_active = serializers.ReadOnlyField()

    class Meta:
        model = Shop
        fields = (
            "id", "name", "owner_name", "phone", "email",
            "address", "city", "state", "pincode",
            "is_active", "created_at",
            "plan", "subscription_status", "subscription_start",
            "subscription_end", "monthly_fee",
            "user_count", "is_subscription_active",
        )
        read_only_fields = ("id", "created_at")

    def get_user_count(self, obj):
        return obj.users.count()


class CreateTenantSerializer(serializers.Serializer):
    shop_name = serializers.CharField(max_length=200)
    owner_name = serializers.CharField(max_length=200)
    owner_email = serializers.EmailField()
    owner_phone = serializers.CharField(max_length=15)
    password = serializers.CharField(min_length=8)
    plan = serializers.ChoiceField(choices=Shop.PLAN_CHOICES, default="trial")
    subscription_months = serializers.IntegerField(default=1, min_value=1, max_value=12)

    def validate_owner_email(self, value):
        if User.objects.filter(email=value).exists():
            raise serializers.ValidationError("An account with this email already exists")
        return value


class SubscriptionUpdateSerializer(serializers.Serializer):
    plan = serializers.ChoiceField(choices=Shop.PLAN_CHOICES)
    subscription_months = serializers.IntegerField(min_value=1, max_value=12)
    amount = serializers.DecimalField(max_digits=10, decimal_places=2)
    tax = serializers.DecimalField(max_digits=10, decimal_places=2, default=0)
    notes = serializers.CharField(required=False, default="")


class InvoiceSerializer(serializers.ModelSerializer):
    shop_name = serializers.CharField(source="shop.name", read_only=True)

    class Meta:
        model = Invoice
        fields = "__all__"
        read_only_fields = ("id", "invoice_number", "created_at")


class TenantPasswordResetSerializer(serializers.Serializer):
    new_password = serializers.CharField(min_length=8)
