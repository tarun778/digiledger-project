from django.contrib import admin
from .models import Invoice


@admin.register(Invoice)
class InvoiceAdmin(admin.ModelAdmin):
    list_display = ("invoice_number", "shop", "plan", "total_amount", "status", "created_at")
    list_filter = ("status", "plan")
    search_fields = ("invoice_number", "shop__name")
    readonly_fields = ("id", "invoice_number", "created_at")
