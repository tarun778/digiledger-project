from django.db import models
import uuid


class Customer(models.Model):
    id = models.UUIDField(primary_key=True, default=uuid.uuid4, editable=False)
    shop = models.ForeignKey("accounts.Shop", on_delete=models.CASCADE, related_name="customers")
    name = models.CharField(max_length=200)
    phone = models.CharField(max_length=15)
    email = models.EmailField(blank=True, default="")
    address = models.TextField(blank=True, default="")
    notes = models.TextField(blank=True, default="")
    total_transactions = models.IntegerField(default=0)
    total_spent = models.DecimalField(max_digits=12, decimal_places=2, default=0)
    total_profit = models.DecimalField(max_digits=12, decimal_places=2, default=0)
    is_active = models.BooleanField(default=True)
    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)

    class Meta:
        ordering = ["-created_at"]
        unique_together = ["shop", "phone"]

    def __str__(self):
        return f"{self.name} ({self.phone}) - {self.shop.name}"

    def update_stats(self):
        from transactions.models import Transaction, CCBillPayment

        txn_stats = Transaction.objects.filter(shop=self.shop, customer=self).aggregate(
            total=Count("id"),
            revenue=Sum("debit_amount"),
            profit=Sum("profit"),
        )
        cc_stats = CCBillPayment.objects.filter(shop=self.shop, customer=self).aggregate(
            total=Count("id"),
            revenue=Sum("amount_paid"),
            profit=Sum("profit"),
        )

        self.total_transactions = (txn_stats["total"] or 0) + (cc_stats["total"] or 0)
        self.total_spent = (txn_stats["revenue"] or 0) + (cc_stats["revenue"] or 0)
        self.total_profit = (txn_stats["profit"] or 0) + (cc_stats["profit"] or 0)
        self.save(update_fields=["total_transactions", "total_spent", "total_profit"])


from django.db.models import Count, Sum
