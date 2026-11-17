from rest_framework import serializers
from django.contrib.auth import get_user_model
from .models import Shop

User = get_user_model()


class ShopSerializer(serializers.ModelSerializer):
    is_subscription_active = serializers.ReadOnlyField()

    class Meta:
        model = Shop
        fields = "__all__"
        read_only_fields = ("id", "created_at", "updated_at")


class UserSerializer(serializers.ModelSerializer):
    shop_name = serializers.CharField(source="shop.name", read_only=True)
    subscription_status = serializers.SerializerMethodField()
    subscription_end = serializers.SerializerMethodField()

    class Meta:
        model = User
        fields = ("id", "email", "name", "phone", "role", "shop", "shop_name", "is_active", "is_superuser", "last_login", "created_at", "subscription_status", "subscription_end")
        read_only_fields = ("id", "created_at", "last_login")

    def get_subscription_status(self, obj):
        if obj.shop:
            return obj.shop.subscription_status
        return None

    def get_subscription_end(self, obj):
        if obj.shop and obj.shop.subscription_end:
            return obj.shop.subscription_end
        return None


class RegisterSerializer(serializers.ModelSerializer):
    password = serializers.CharField(write_only=True, min_length=8)
    shop_name = serializers.CharField(write_only=True)
    shop_phone = serializers.CharField(write_only=True)
    shop_address = serializers.CharField(write_only=True, required=False, default="")
    shop_city = serializers.CharField(write_only=True, required=False, default="")
    shop_state = serializers.CharField(write_only=True, required=False, default="")
    shop_pincode = serializers.CharField(write_only=True, required=False, default="")

    class Meta:
        model = User
        fields = (
            "email", "name", "phone", "password",
            "shop_name", "shop_phone", "shop_address",
            "shop_city", "shop_state", "shop_pincode",
        )

    def validate_email(self, value):
        if User.objects.filter(email=value).exists():
            raise serializers.ValidationError("An account with this email already exists")
        return value

    def create(self, validated_data):
        shop_name = validated_data.pop("shop_name")
        shop_phone = validated_data.pop("shop_phone")
        shop_address = validated_data.pop("shop_address", "")
        shop_city = validated_data.pop("shop_city", "")
        shop_state = validated_data.pop("shop_state", "")
        shop_pincode = validated_data.pop("shop_pincode", "")
        password = validated_data.pop("password")

        shop = Shop.objects.create(
            name=shop_name,
            owner_name=validated_data["name"],
            phone=shop_phone,
            address=shop_address,
            city=shop_city,
            state=shop_state,
            pincode=shop_pincode,
        )

        user = User.objects.create_user(
            email=validated_data["email"],
            name=validated_data["name"],
            phone=validated_data["phone"],
            shop=shop,
            password=password,
            role="owner",
        )
        return user


class LoginSerializer(serializers.Serializer):
    email = serializers.EmailField()
    password = serializers.CharField()


class AddStaffSerializer(serializers.ModelSerializer):
    password = serializers.CharField(write_only=True, min_length=8)

    class Meta:
        model = User
        fields = ("email", "name", "phone", "role", "password")

    def validate_role(self, value):
        if value == "owner":
            raise serializers.ValidationError("Cannot create another owner. Each shop has only one owner.")
        if value not in ("staff", "manager"):
            raise serializers.ValidationError("Role must be 'staff' or 'manager'")
        return value

    def validate_email(self, value):
        shop = self.context["request"].user.shop
        if User.objects.filter(email=value, shop=shop).exists():
            raise serializers.ValidationError("A user with this email already exists in your shop")
        return value

    def create(self, validated_data):
        password = validated_data.pop("password")
        shop = self.context["request"].user.shop
        user = User.objects.create_user(
            email=validated_data["email"],
            name=validated_data["name"],
            phone=validated_data["phone"],
            shop=shop,
            password=password,
            role=validated_data.get("role", "staff"),
        )
        return user


class ChangePasswordSerializer(serializers.Serializer):
    old_password = serializers.CharField()
    new_password = serializers.CharField(min_length=8)

    def validate_old_password(self, value):
        user = self.context["request"].user
        if not user.check_password(value):
            raise serializers.ValidationError("Old password is incorrect")
        return value
