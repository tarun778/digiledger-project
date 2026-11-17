from django.contrib import admin
from django.contrib.auth.admin import UserAdmin as BaseUserAdmin
from .models import User, Shop


@admin.register(Shop)
class ShopAdmin(admin.ModelAdmin):
    list_display = ("name", "owner_name", "phone", "email", "city", "plan", "subscription_status", "subscription_end", "is_active", "created_at")
    list_filter = ("is_active", "subscription_status", "plan", "city", "state")
    search_fields = ("name", "owner_name", "phone", "email")
    readonly_fields = ("created_at", "updated_at")
    list_editable = ("subscription_status", "is_active")


@admin.register(User)
class UserAdmin(BaseUserAdmin):
    list_display = ("email", "name", "phone", "role", "shop", "is_active")
    list_filter = ("role", "is_active", "shop")
    search_fields = ("email", "name", "phone")
    ordering = ("-created_at",)

    fieldsets = (
        (None, {"fields": ("email", "password")}),
        ("Personal Info", {"fields": ("name", "phone", "role", "shop")}),
        ("Permissions", {"fields": ("is_active", "is_staff", "is_superuser", "groups", "user_permissions")}),
    )

    add_fieldsets = (
        (
            None,
            {
                "classes": ("wide",),
                "fields": ("email", "name", "phone", "role", "shop", "password1", "password2"),
            },
        ),
    )
