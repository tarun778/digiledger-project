from rest_framework import generics, permissions, status
from rest_framework.response import Response
from rest_framework.views import APIView
from django.db.models import Sum, Count, Q
from django.db.models.functions import TruncDate, TruncMonth
from django.utils import timezone
from datetime import timedelta
from .models import BankAccount, Category, Transaction, CCBillPayment, CreditEntry, DescriptionSuggestion, account_balances
from .serializers import (
    BankAccountSerializer, CategorySerializer, TransactionSerializer, TransactionListSerializer,
    CCBillPaymentSerializer, CCBillPaymentListSerializer,
    CreditEntrySerializer, CreditEntryListSerializer,
    DescriptionSuggestionSerializer,
)


# Bank Account Views
class BankAccountListView(generics.ListCreateAPIView):
    serializer_class = BankAccountSerializer

    def get_queryset(self):
        qs = BankAccount.objects.filter(shop=self.request.user.shop)
        if self.request.query_params.get("include_inactive") != "1":
            qs = qs.filter(is_active=True)
        return qs

    def get_serializer_context(self):
        ctx = super().get_serializer_context()
        accounts = list(self.get_queryset())
        ctx["balances"] = account_balances(self.request.user.shop, accounts)
        return ctx

    def perform_create(self, serializer):
        serializer.save(shop=self.request.user.shop)


class BankAccountDetailView(generics.RetrieveUpdateDestroyAPIView):
    serializer_class = BankAccountSerializer
    queryset = BankAccount.objects.all()

    def get_queryset(self):
        return BankAccount.objects.filter(shop=self.request.user.shop)

    def put(self, request, *args, **kwargs):
        kwargs["partial"] = True
        return self.update(request, *args, **kwargs)

    def perform_destroy(self, instance):
        # Keep history intact: hide the account instead of hard deleting it.
        instance.is_active = False
        instance.save(update_fields=["is_active"])


class BankAccountMovementsView(APIView):
    """Money in/out for one account: transactions, CC bill payments, credit entries."""

    def get(self, request, pk):
        try:
            account = BankAccount.objects.get(pk=pk, shop=request.user.shop)
        except BankAccount.DoesNotExist:
            return Response({"detail": "Not found"}, status=404)

        movements = []

        for t in Transaction.objects.filter(bank_account=account).select_related("category"):
            if t.transaction_type == "income":
                if not t.to_bank:
                    continue
                direction = "in"
                amount = float(t.debit_amount) + float(t.profit)
            else:
                direction = "out"
                amount = float(t.debit_amount)
            movements.append({
                "id": str(t.id),
                "source": "transaction",
                "date": str(t.date),
                "direction": direction,
                "title": t.description,
                "subtitle": t.category.name if t.category else "",
                "amount": amount,
                "payment_method": t.payment_method,
                "reference": t.transaction_ref,
                "_created_at": t.created_at.isoformat(),
            })

        for c in CCBillPayment.objects.filter(bank_account=account):
            if not c.to_bank:
                continue
            card = c.card_last_4 or ""
            movements.append({
                "id": str(c.id),
                "source": "cc_bill",
                "date": str(c.date),
                "direction": "in",
                "title": "CC bill payment" + (f" • {c.customer_name}" if c.customer_name else ""),
                "subtitle": (f"Card •••• {card}" if card else "").strip(),
                "amount": float(c.amount_paid) + float(c.profit),
                "payment_method": c.payment_method,
                "reference": c.transaction_ref,
                "_created_at": c.created_at.isoformat(),
            })

        for e in CreditEntry.objects.filter(bank_account=account):
            given = e.entry_type == "given"
            if not given and not e.to_bank:
                continue
            movements.append({
                "id": str(e.id),
                "source": "credit",
                "date": str(e.date),
                "direction": "out" if given else "in",
                "title": ("Credit given" if given else "Credit returned")
                         + (f" • {e.customer_name}" if e.customer_name else ""),
                "subtitle": e.remarks or "",
                "amount": float(e.amount),
                "payment_method": "",
                "reference": "",
                "_created_at": e.created_at.isoformat(),
            })

        movements.sort(key=lambda m: (m["date"], m["_created_at"]), reverse=True)
        for m in movements:
            m.pop("_created_at", None)

        balance = float(account.balance)
        running = balance
        for m in movements:
            m["balance_after"] = running
            running += -m["amount"] if m["direction"] == "in" else m["amount"]

        return Response({
            "account": BankAccountSerializer(account, context={"request": request}).data,
            "opening_balance": float(account.opening_balance),
            "money_in": sum(m["amount"] for m in movements if m["direction"] == "in"),
            "money_out": sum(m["amount"] for m in movements if m["direction"] == "out"),
            "balance": balance,
            "movement_count": len(movements),
            "movements": movements,
        })


# Category Views
class CategoryListView(generics.ListAPIView):
    serializer_class = CategorySerializer

    def get_queryset(self):
        category_type = self.request.query_params.get("type", None)
        qs = Category.objects.filter(shop=self.request.user.shop, is_active=True)
        if category_type:
            qs = qs.filter(category_type=category_type)
        return qs


class CategoryCreateView(generics.CreateAPIView):
    serializer_class = CategorySerializer

    def perform_create(self, serializer):
        serializer.save(shop=self.request.user.shop, is_custom=True)


class CategoryDetailView(generics.RetrieveUpdateDestroyAPIView):
    serializer_class = CategorySerializer

    def get_queryset(self):
        return Category.objects.filter(shop=self.request.user.shop)


# Transaction Views
class TransactionListView(generics.ListAPIView):
    serializer_class = TransactionListSerializer

    def get_queryset(self):
        qs = Transaction.objects.filter(shop=self.request.user.shop)

        # Filters
        category = self.request.query_params.get("category")
        payment_method = self.request.query_params.get("payment_method")
        date_from = self.request.query_params.get("date_from")
        date_to = self.request.query_params.get("date_to")
        search = self.request.query_params.get("search")

        if category:
            qs = qs.filter(category_id=category)
        if payment_method:
            qs = qs.filter(payment_method=payment_method)
        if date_from:
            qs = qs.filter(date__gte=date_from)
        if date_to:
            qs = qs.filter(date__lte=date_to)
        if search:
            qs = qs.filter(
                Q(description__icontains=search) |
                Q(transaction_ref__icontains=search) |
                Q(customer_name__icontains=search) |
                Q(customer_phone__icontains=search)
            )
        return qs


class TransactionCreateView(generics.CreateAPIView):
    serializer_class = TransactionSerializer


class TransactionDetailView(generics.RetrieveUpdateDestroyAPIView):
    serializer_class = TransactionSerializer

    def get_queryset(self):
        return Transaction.objects.filter(shop=self.request.user.shop)


# CC Bill Payment Views
class CCBillPaymentListView(generics.ListAPIView):
    serializer_class = CCBillPaymentListSerializer

    def get_queryset(self):
        qs = CCBillPayment.objects.filter(shop=self.request.user.shop)

        bank_name = self.request.query_params.get("bank_name")
        payment_method = self.request.query_params.get("payment_method")
        date_from = self.request.query_params.get("date_from")
        date_to = self.request.query_params.get("date_to")
        search = self.request.query_params.get("search")
        due_soon = self.request.query_params.get("due_soon")

        if bank_name:
            qs = qs.filter(bank_name=bank_name)
        if payment_method:
            qs = qs.filter(payment_method=payment_method)
        if date_from:
            qs = qs.filter(date__gte=date_from)
        if date_to:
            qs = qs.filter(date__lte=date_to)
        if search:
            qs = qs.filter(
                Q(customer_name__icontains=search) |
                Q(customer_phone__icontains=search) |
                Q(transaction_ref__icontains=search)
            )
        if due_soon:
            today = timezone.now().date()
            qs = qs.filter(due_date__lte=today + timedelta(days=3), due_date__gte=today)
        return qs


class CCBillPaymentCreateView(generics.CreateAPIView):
    serializer_class = CCBillPaymentSerializer


class CCBillPaymentDetailView(generics.RetrieveUpdateDestroyAPIView):
    serializer_class = CCBillPaymentSerializer

    def get_queryset(self):
        return CCBillPayment.objects.filter(shop=self.request.user.shop)


# Dashboard View
class DashboardView(APIView):
    def get(self, request):
        shop = request.user.shop
        today = timezone.now().date()
        month_start = today.replace(day=1)

        today_txn = Transaction.objects.filter(shop=shop, date=today)
        month_txn = Transaction.objects.filter(shop=shop, date__gte=month_start, date__lte=today)

        # Pending credit amounts
        credit_entries = CreditEntry.objects.filter(shop=shop)
        total_pending = 0
        for cust in credit_entries.values("customer_name").distinct().order_by():
            name = cust["customer_name"]
            given = credit_entries.filter(customer_name=name, entry_type="given").aggregate(total=Sum("amount"))["total"] or 0
            returned = credit_entries.filter(customer_name=name, entry_type="returned").aggregate(total=Sum("amount"))["total"] or 0
            total_pending += given - returned

        # CC Bills count
        cc_bills_count = CCBillPayment.objects.filter(shop=shop).count()

        data = {
            "today_transactions": today_txn.count(),
            "today_revenue": today_txn.aggregate(total=Sum("debit_amount"))["total"] or 0,
            "today_profit": today_txn.aggregate(total=Sum("profit"))["total"] or 0,
            "month_transactions": month_txn.count(),
            "month_revenue": month_txn.aggregate(total=Sum("debit_amount"))["total"] or 0,
            "month_profit": month_txn.aggregate(total=Sum("profit"))["total"] or 0,
            "pending_amount": total_pending,
            "cc_bills": cc_bills_count,
            "today_cc_bills": CCBillPayment.objects.filter(shop=shop, date=today).aggregate(
                total=Sum("amount_paid"), profit=Sum("profit")
            ),
            "recent_transactions": TransactionListSerializer(
                Transaction.objects.filter(shop=shop)[:10],
                many=True,
            ).data,
        }
        return Response(data)


class ChartDataView(APIView):
    def get(self, request):
        shop = request.user.shop
        period = request.query_params.get("period", "weekly")
        today = timezone.now().date()

        date_from = request.query_params.get("date_from")
        date_to = request.query_params.get("date_to")

        if date_from and date_to:
            from datetime import datetime as dt
            start = dt.strptime(date_from, "%Y-%m-%d").date()
            today = dt.strptime(date_to, "%Y-%m-%d").date()
        elif period == "weekly":
            start = today - timedelta(days=6)
        elif period == "monthly":
            start = today - timedelta(days=29)
        elif period == "quarterly":
            start = today - timedelta(days=89)
        elif period == "half_yearly":
            start = today - timedelta(days=179)
        elif period == "yearly":
            start = today.replace(year=today.year - 1)
        else:
            start = today - timedelta(days=6)

        txns = Transaction.objects.filter(shop=shop, date__gte=start, date__lte=today)

        use_monthly = period in ("quarterly", "half_yearly", "yearly")

        revenue_by_key = {}
        profit_by_key = {}
        for txn in txns:
            if use_monthly:
                key = txn.date.replace(day=1)
            else:
                key = txn.date
            revenue_by_key[key] = revenue_by_key.get(key, 0) + float(txn.debit_amount or 0)
            profit_by_key[key] = profit_by_key.get(key, 0) + float(txn.profit or 0)

        revenue_data = []
        profit_data = []
        label_list = []

        if use_monthly:
            d = start.replace(day=1)
            while d <= today:
                revenue_data.append(revenue_by_key.get(d, 0))
                profit_data.append(profit_by_key.get(d, 0))
                label_list.append(d.strftime("%b"))
                d = (d.replace(day=28) + timedelta(days=4)).replace(day=1)
        else:
            d = start
            while d <= today:
                revenue_data.append(revenue_by_key.get(d, 0))
                profit_data.append(profit_by_key.get(d, 0))
                if period == "weekly":
                    label_list.append(d.strftime("%a"))
                else:
                    label_list.append(d.strftime("%d"))
                d += timedelta(days=1)

        return Response({
            "period": period,
            "labels": label_list,
            "revenue": revenue_data,
            "profit": profit_data,
        })


# Category seed view
class SeedCategoriesView(APIView):
    def post(self, request):
        shop = request.user.shop
        default_categories = [
            {"name": "Bus Ticket", "icon": "🚌", "category_type": "service"},
            {"name": "Train Ticket", "icon": "🚂", "category_type": "service"},
            {"name": "Flight Ticket", "icon": "✈️", "category_type": "service"},
            {"name": "Electricity Bill", "icon": "💡", "category_type": "service"},
            {"name": "Water Bill", "icon": "💧", "category_type": "service"},
            {"name": "Gas Bill", "icon": "🔥", "category_type": "service"},
            {"name": "Mobile Recharge", "icon": "📱", "category_type": "service"},
            {"name": "DTH Recharge", "icon": "📺", "category_type": "service"},
            {"name": "Aadhar Card", "icon": "🆔", "category_type": "service"},
            {"name": "PAN Card", "icon": "💳", "category_type": "service"},
            {"name": "Passport", "icon": "📘", "category_type": "service"},
            {"name": "Money Transfer", "icon": "💸", "category_type": "service"},
            {"name": "Photocopy/Printing", "icon": "🖨️", "category_type": "service"},
            {"name": "Courier", "icon": "📦", "category_type": "service"},
            {"name": "Insurance", "icon": "🛡️", "category_type": "service"},
            {"name": "Credit Card Bill Payment", "icon": "💳", "category_type": "cc_bill"},
        ]

        created = 0
        for cat in default_categories:
            _, is_new = Category.objects.get_or_create(
                shop=shop,
                name=cat["name"],
                defaults={"icon": cat["icon"], "category_type": cat["category_type"]},
            )
            if is_new:
                created += 1

        return Response({"message": f"{created} categories created", "total": len(default_categories)})


# Credit Entry Views
class CreditEntryListView(generics.ListAPIView):
    serializer_class = CreditEntryListSerializer

    def get_queryset(self):
        qs = CreditEntry.objects.filter(shop=self.request.user.shop)
        customer = self.request.query_params.get("customer")
        if customer:
            qs = qs.filter(customer_name=customer)
        return qs


class CreditEntryCreateView(generics.CreateAPIView):
    serializer_class = CreditEntrySerializer


class CreditEntryDetailView(generics.RetrieveUpdateDestroyAPIView):
    serializer_class = CreditEntrySerializer

    def get_queryset(self):
        return CreditEntry.objects.filter(shop=self.request.user.shop)


class CreditSummaryView(APIView):
    def get(self, request):
        shop = request.user.shop
        entries = CreditEntry.objects.filter(shop=shop)

        # Group by customer_name only (not phone, to avoid duplicates)
        customer_names = entries.values_list("customer_name", flat=True).distinct().order_by()
        summary = []
        for name in customer_names:
            if not name:
                continue
            customer_entries = entries.filter(customer_name=name)
            latest = customer_entries.order_by("-created_at").first()
            phone = latest.customer_phone if latest else ""
            given = customer_entries.filter(entry_type="given").aggregate(total=Sum("amount"))["total"] or 0
            returned = customer_entries.filter(entry_type="returned").aggregate(total=Sum("amount"))["total"] or 0
            pending = given - returned
            last_entry = customer_entries.order_by("-date", "-created_at").first()
            summary.append({
                "customer_name": name,
                "customer_phone": phone or "",
                "total_given": float(given),
                "total_returned": float(returned),
                "pending_amount": float(pending),
                "last_date": str(last_entry.date) if last_entry else None,
                "entry_count": customer_entries.count(),
                "last_account": last_entry.bank_account.account_name if last_entry and last_entry.bank_account else "",
                "last_account_number": last_entry.bank_account.masked_number if last_entry and last_entry.bank_account else "",
                "last_account_id": str(last_entry.bank_account_id) if last_entry and last_entry.bank_account else None,
            })

        # Sort by latest entry date descending (most recent on top)
        summary.sort(key=lambda x: x["last_date"] or "", reverse=True)
        total_pending = sum(s["pending_amount"] for s in summary)

        return Response({
            "customers": summary,
            "total_pending": total_pending,
            "total_customers": len(summary),
        })


# Description Suggestion Views
class DescriptionSuggestionListView(generics.ListAPIView):
    serializer_class = DescriptionSuggestionSerializer

    def get_queryset(self):
        return DescriptionSuggestion.objects.filter(shop=self.request.user.shop)


class DescriptionSuggestionCreateView(generics.CreateAPIView):
    serializer_class = DescriptionSuggestionSerializer


class DescriptionSuggestionDetailView(generics.RetrieveUpdateDestroyAPIView):
    serializer_class = DescriptionSuggestionSerializer

    def get_queryset(self):
        return DescriptionSuggestion.objects.filter(shop=self.request.user.shop, is_default=False)


class SeedDescriptionSuggestionsView(APIView):
    def post(self, request):
        shop = request.user.shop
        defaults = [
            "Cash Paid",
            "Cash Collected",
            "Cash Withdrawal",
            "Bus Ticket",
            "Flight Ticket",
            "Train Ticket",
            "PAN Card Creation",
            "PAN Card Update",
            "Aadhar Correction",
            "Aadhar Update",
            "Mobile Recharge",
            "Electricity Bill Payment",
            "Water Bill Payment",
            "Gas Bill Payment",
            "Courier Service",
            "Money Transfer",
            "Passport Application",
            "Insurance Payment",
            "Photocopy/Printing",
            "DTH Recharge",
        ]

        created = 0
        for idx, text in enumerate(defaults):
            _, is_new = DescriptionSuggestion.objects.get_or_create(
                shop=shop,
                text=text,
                defaults={"is_default": True, "sort_order": idx},
            )
            if is_new:
                created += 1

        return Response({"message": f"{created} description suggestions created", "total": len(defaults)})
