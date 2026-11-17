from django.contrib import admin
from .models import BankAccount, Category, Transaction, CCBillPayment


@admin.register(BankAccount)
class BankAccountAdmin(admin.ModelAdmin):
    list_display = ("account_name", "shop", "bank_name", "account_type", "opening_balance", "balance", "is_active")
    list_filter = ("account_type", "is_active", "shop")
    search_fields = ("account_name", "bank_name", "account_number")
    readonly_fields = ("created_at",)


@admin.register(Category)
class CategoryAdmin(admin.ModelAdmin):
    list_display = ("name", "shop", "category_type", "is_custom", "is_active")
    list_filter = ("category_type", "is_custom", "is_active", "shop")
    search_fields = ("name",)


@admin.register(Transaction)
class TransactionAdmin(admin.ModelAdmin):
    list_display = ("description", "shop", "category", "payment_method", "debit_amount", "charges", "profit", "date")
    list_filter = ("payment_method", "category", "date", "shop")
    search_fields = ("description", "transaction_ref", "customer_name", "customer_phone")
    date_hierarchy = "date"
    readonly_fields = ("profit",)


@admin.register(CCBillPayment)
class CCBillPaymentAdmin(admin.ModelAdmin):
    list_display = ("customer_name", "shop", "bank_name", "bill_amount", "amount_paid", "service_charges", "profit", "date")
    list_filter = ("bank_name", "payment_method", "date", "shop")
    search_fields = ("customer_name", "customer_phone", "transaction_ref", "card_last_4")
    date_hierarchy = "date"
    readonly_fields = ("profit",)
