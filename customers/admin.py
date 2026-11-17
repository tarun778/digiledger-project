from django.contrib import admin
from .models import Customer


@admin.register(Customer)
class CustomerAdmin(admin.ModelAdmin):
    list_display = ("name", "phone", "shop", "total_transactions", "total_spent", "total_profit", "is_active")
    list_filter = ("is_active", "shop")
    search_fields = ("name", "phone", "email")
    readonly_fields = ("total_transactions", "total_spent", "total_profit", "created_at", "updated_at")
