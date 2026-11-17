from django.contrib.auth.models import AbstractBaseUser, BaseUserManager, PermissionsMixin
from django.db import models
import uuid


class Shop(models.Model):
    PLAN_CHOICES = (
        ("free", "Free Trial"),
        ("monthly", "Monthly"),
        ("quarterly", "Quarterly"),
        ("yearly", "Yearly"),
    )
    SUBSCRIPTION_STATUS = (
        ("active", "Active"),
        ("expired", "Expired"),
        ("suspended", "Suspended"),
        ("trial", "Trial"),
    )

    id = models.UUIDField(primary_key=True, default=uuid.uuid4, editable=False)
    name = models.CharField(max_length=200)
    owner_name = models.CharField(max_length=200)
    phone = models.CharField(max_length=15)
    email = models.EmailField(blank=True, null=True)
    address = models.TextField(blank=True, null=True)
    city = models.CharField(max_length=100, blank=True, null=True)
    state = models.CharField(max_length=100, blank=True, null=True)
    pincode = models.CharField(max_length=10, blank=True, null=True)
    logo = models.ImageField(upload_to="shop_logos/", blank=True, null=True)
    is_active = models.BooleanField(default=True)
    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)

    # Subscription fields
    plan = models.CharField(max_length=20, choices=PLAN_CHOICES, default="trial")
    subscription_status = models.CharField(max_length=20, choices=SUBSCRIPTION_STATUS, default="trial")
    subscription_start = models.DateTimeField(blank=True, null=True)
    subscription_end = models.DateTimeField(blank=True, null=True)
    monthly_fee = models.DecimalField(max_digits=10, decimal_places=2, default=0)

    class Meta:
        verbose_name = "Shop"
        verbose_name_plural = "Shops"

    def __str__(self):
        return self.name

    @property
    def is_subscription_active(self):
        from django.utils import timezone
        if self.subscription_status == "active" and self.subscription_end:
            return timezone.now() <= self.subscription_end
        return False


class UserManager(BaseUserManager):
    def create_user(self, email, name, phone, shop, password=None, **extra_fields):
        if not email:
            raise ValueError("Email is required")
        email = self.normalize_email(email)
        user = self.model(email=email, name=name, phone=phone, shop=shop, **extra_fields)
        user.set_password(password)
        user.save(using=self._db)
        return user

    def create_superuser(self, email, name, phone, password=None, **extra_fields):
        extra_fields.setdefault("is_staff", True)
        extra_fields.setdefault("is_superuser", True)
        extra_fields.setdefault("role", "owner")

        shop, _ = Shop.objects.get_or_create(
            name="Admin Shop",
            defaults={"owner_name": name, "phone": phone, "email": email},
        )
        return self.create_user(email, name, phone, shop, password, **extra_fields)


class User(AbstractBaseUser, PermissionsMixin):
    ROLE_CHOICES = (
        ("owner", "Owner"),
        ("manager", "Manager"),
        ("staff", "Staff"),
    )

    id = models.UUIDField(primary_key=True, default=uuid.uuid4, editable=False)
    email = models.EmailField(unique=True)
    name = models.CharField(max_length=200)
    phone = models.CharField(max_length=15)
    role = models.CharField(max_length=20, choices=ROLE_CHOICES, default="staff")
    shop = models.ForeignKey(Shop, on_delete=models.CASCADE, related_name="users")
    is_active = models.BooleanField(default=True)
    is_staff = models.BooleanField(default=False)
    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)

    objects = UserManager()

    USERNAME_FIELD = "email"
    REQUIRED_FIELDS = ["name", "phone"]

    class Meta:
        verbose_name = "User"
        verbose_name_plural = "Users"

    def __str__(self):
        return f"{self.name} ({self.role}) - {self.shop.name}"
