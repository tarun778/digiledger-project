from rest_framework.views import APIView
from rest_framework.response import Response
from django.db.models import Sum, Count, F
from django.utils import timezone
from datetime import timedelta, date as date_type
import calendar
from collections import defaultdict

from transactions.models import Transaction, CCBillPayment, CreditEntry
from .serializers import (
    DailyReportSerializer, MonthlyReportSerializer,
    QuarterlyReportSerializer, YearlyReportSerializer,
    CategoryReportSerializer, PaymentMethodReportSerializer,
    ProfitSummarySerializer,
)


def _safe_float(val):
    try:
        return float(val) if val else 0.0
    except (TypeError, ValueError):
        return 0.0


def _to_date(d):
    if hasattr(d, 'date'):
        return d.date()
    return d


class DailyReportView(APIView):
    def get(self, request):
        shop = request.user.shop
        date_from = request.query_params.get("date_from")
        date_to = request.query_params.get("date_to")

        if not date_from:
            date_from = timezone.now().date() - timedelta(days=30)
        if not date_to:
            date_to = timezone.now().date()

        if isinstance(date_from, str):
            date_from = date_type.fromisoformat(date_from)
        if isinstance(date_to, str):
            date_to = date_type.fromisoformat(date_to)

        txn_qs = Transaction.objects.filter(shop=shop, date__gte=date_from, date__lte=date_to)
        cc_qs = CCBillPayment.objects.filter(shop=shop, date__gte=date_from, date__lte=date_to)

        txn_by_day = defaultdict(lambda: {"transactions": 0, "revenue": 0.0, "profit": 0.0})
        for txn in txn_qs:
            day = _to_date(txn.date)
            txn_by_day[day]["transactions"] += 1
            txn_by_day[day]["revenue"] += _safe_float(txn.debit_amount)
            txn_by_day[day]["profit"] += _safe_float(txn.profit)

        cc_by_day = defaultdict(lambda: {"cc_bill_payments": 0, "cc_bill_revenue": 0.0, "cc_bill_profit": 0.0})
        for cc in cc_qs:
            day = _to_date(cc.date)
            cc_by_day[day]["cc_bill_payments"] += 1
            cc_by_day[day]["cc_bill_revenue"] += _safe_float(cc.amount_paid)
            cc_by_day[day]["cc_bill_profit"] += _safe_float(cc.profit)

        all_days = sorted(set(list(txn_by_day.keys()) + list(cc_by_day.keys())))

        result = []
        for day in all_days:
            txn = txn_by_day.get(day, {})
            cc = cc_by_day.get(day, {})
            result.append({
                "date": str(day),
                "transactions": txn.get("transactions", 0),
                "revenue": txn.get("revenue", 0),
                "profit": txn.get("profit", 0),
                "cc_bill_payments": cc.get("cc_bill_payments", 0),
                "cc_bill_revenue": cc.get("cc_bill_revenue", 0),
                "cc_bill_profit": cc.get("cc_bill_profit", 0),
            })

        return Response(result)


class MonthlyReportView(APIView):
    def get(self, request):
        shop = request.user.shop
        year = request.query_params.get("year", timezone.now().year)

        txn_data = (
            Transaction.objects.filter(shop=shop, date__year=year)
            .values("date__month")
            .annotate(
                transactions=Count("id"),
                revenue=Sum("debit_amount"),
                profit=Sum("profit"),
            )
            .order_by("date__month")
        )

        cc_data = (
            CCBillPayment.objects.filter(shop=shop, date__year=year)
            .values("date__month")
            .annotate(
                cc_bill_payments=Count("id"),
                cc_bill_revenue=Sum("amount_paid"),
                cc_bill_profit=Sum("profit"),
            )
            .order_by("date__month")
        )

        cc_map = {item["date__month"]: item for item in cc_data}

        result = []
        for item in txn_data:
            month = item["date__month"]
            cc = cc_map.get(month, {})
            result.append({
                "year": year,
                "month": month,
                "month_name": calendar.month_name[month],
                "transactions": item["transactions"],
                "revenue": item["revenue"] or 0,
                "profit": item["profit"] or 0,
                "cc_bill_payments": cc.get("cc_bill_payments", 0),
                "cc_bill_revenue": cc.get("cc_bill_revenue", 0) or 0,
                "cc_bill_profit": cc.get("cc_bill_profit", 0) or 0,
            })

        return Response(result)


class QuarterlyReportView(APIView):
    def get(self, request):
        shop = request.user.shop
        year = request.query_params.get("year", timezone.now().year)

        txn_data = (
            Transaction.objects.filter(shop=shop, date__year=year)
            .values("date__month")
            .annotate(
                transactions=Count("id"),
                revenue=Sum("debit_amount"),
                profit=Sum("profit"),
            )
            .order_by("date__month")
        )

        quarters = {
            1: {"transactions": 0, "revenue": 0, "profit": 0},
            2: {"transactions": 0, "revenue": 0, "profit": 0},
            3: {"transactions": 0, "revenue": 0, "profit": 0},
            4: {"transactions": 0, "revenue": 0, "profit": 0},
        }

        for item in txn_data:
            month = item["date__month"]
            q = (month - 1) // 3 + 1
            quarters[q]["transactions"] += item["transactions"]
            quarters[q]["revenue"] += _safe_float(item["revenue"])
            quarters[q]["profit"] += _safe_float(item["profit"])

        result = []
        for q_num, data in quarters.items():
            m1 = calendar.month_name[(q_num - 1) * 3 + 1][:3]
            m2 = calendar.month_name[q_num * 3][:3]
            result.append({
                "year": year,
                "quarter": q_num,
                "quarter_name": f"Q{q_num} ({m1}-{m2})",
                "transactions": data["transactions"],
                "revenue": data["revenue"],
                "profit": data["profit"],
            })

        return Response(result)


class YearlyReportView(APIView):
    def get(self, request):
        shop = request.user.shop

        txn_data = (
            Transaction.objects.filter(shop=shop)
            .annotate(year=F("date__year"))
            .values("year")
            .annotate(
                transactions=Count("id"),
                revenue=Sum("debit_amount"),
                profit=Sum("profit"),
            )
            .order_by("year")
        )

        cc_data = (
            CCBillPayment.objects.filter(shop=shop)
            .annotate(year=F("date__year"))
            .values("year")
            .annotate(
                cc_bill_payments=Count("id"),
                cc_bill_revenue=Sum("amount_paid"),
                cc_bill_profit=Sum("profit"),
            )
            .order_by("year")
        )

        cc_map = {item["year"]: item for item in cc_data}

        result = []
        for item in txn_data:
            year = item["year"]
            cc = cc_map.get(year, {})
            result.append({
                "year": year,
                "transactions": item["transactions"],
                "revenue": item["revenue"] or 0,
                "profit": item["profit"] or 0,
                "cc_bill_payments": cc.get("cc_bill_payments", 0),
                "cc_bill_revenue": cc.get("cc_bill_revenue", 0) or 0,
                "cc_bill_profit": cc.get("cc_bill_profit", 0) or 0,
            })

        return Response(result)


class CategoryReportView(APIView):
    def get(self, request):
        shop = request.user.shop
        date_from = request.query_params.get("date_from")
        date_to = request.query_params.get("date_to")

        qs = Transaction.objects.filter(shop=shop)
        if date_from:
            qs = qs.filter(date__gte=date_from)
        if date_to:
            qs = qs.filter(date__lte=date_to)

        data = (
            qs.values("category__name", "category__icon")
            .annotate(
                transactions=Count("id"),
                revenue=Sum("debit_amount"),
                profit=Sum("profit"),
            )
            .order_by("-revenue")
        )

        result = [
            {
                "category_name": item["category__name"] or "Uncategorized",
                "category_icon": item["category__icon"] or "",
                "transactions": item["transactions"],
                "revenue": item["revenue"] or 0,
                "profit": item["profit"] or 0,
            }
            for item in data
        ]

        return Response(result)


class PaymentMethodReportView(APIView):
    def get(self, request):
        shop = request.user.shop
        date_from = request.query_params.get("date_from")
        date_to = request.query_params.get("date_to")

        PAYMENT_LABELS = dict(Transaction.PAYMENT_METHOD_CHOICES)

        qs = Transaction.objects.filter(shop=shop)
        if date_from:
            qs = qs.filter(date__gte=date_from)
        if date_to:
            qs = qs.filter(date__lte=date_to)

        data = (
            qs.values("payment_method")
            .annotate(
                transactions=Count("id"),
                revenue=Sum("debit_amount"),
                profit=Sum("profit"),
            )
            .order_by("-revenue")
        )

        result = [
            {
                "payment_method": item["payment_method"],
                "payment_label": PAYMENT_LABELS.get(item["payment_method"], item["payment_method"]),
                "transactions": item["transactions"],
                "revenue": item["revenue"] or 0,
                "profit": item["profit"] or 0,
            }
            for item in data
        ]

        return Response(result)


class ProfitSummaryView(APIView):
    def get(self, request):
        shop = request.user.shop
        date_from = request.query_params.get("date_from")
        date_to = request.query_params.get("date_to")

        if not date_from:
            date_from = timezone.now().date() - timedelta(days=365)
        if not date_to:
            date_to = timezone.now().date()

        if isinstance(date_from, str):
            date_from = date_type.fromisoformat(date_from)
        if isinstance(date_to, str):
            date_to = date_type.fromisoformat(date_to)

        txn_qs = Transaction.objects.filter(shop=shop, date__gte=date_from, date__lte=date_to)
        cc_qs = CCBillPayment.objects.filter(shop=shop, date__gte=date_from, date__lte=date_to)

        total_txn_revenue = txn_qs.aggregate(total=Sum("debit_amount"))["total"] or 0
        total_txn_profit = txn_qs.aggregate(total=Sum("profit"))["total"] or 0
        total_txn_count = txn_qs.count()
        total_cc_count = cc_qs.count()
        total_cc_revenue = cc_qs.aggregate(total=Sum("amount_paid"))["total"] or 0
        total_cc_profit = cc_qs.aggregate(total=Sum("profit"))["total"] or 0

        total_revenue = _safe_float(total_txn_revenue) + _safe_float(total_cc_revenue)
        total_profit = _safe_float(total_txn_profit) + _safe_float(total_cc_profit)

        days = max((date_to - date_from).days, 1)

        best_day = None
        best_profit = 0
        daily_profit_map = defaultdict(float)
        for txn in txn_qs:
            day = _to_date(txn.date)
            daily_profit_map[day] += _safe_float(txn.profit)
        for day, profit in daily_profit_map.items():
            if profit > best_profit:
                best_profit = profit
                best_day = {"day": day, "daily_profit": profit}

        return Response({
            "total_revenue": total_revenue,
            "total_profit": total_profit,
            "total_transactions": total_txn_count,
            "total_cc_payments": total_cc_count,
            "avg_profit_per_day": round(total_profit / days, 2),
            "best_day_profit": best_day["daily_profit"] if best_day else 0,
            "best_day_date": str(best_day["day"]) if best_day else None,
            "date_from": str(date_from),
            "date_to": str(date_to),
        })


class ReportsOverviewView(APIView):
    def get(self, request):
        shop = request.user.shop
        today = timezone.now().date()
        date_from = request.query_params.get("date_from")
        date_to = request.query_params.get("date_to")

        if not date_from:
            date_from = today - timedelta(days=30)
        if not date_to:
            date_to = today

        if isinstance(date_from, str):
            d_from = date_type.fromisoformat(date_from)
        else:
            d_from = date_from
        if isinstance(date_to, str):
            d_to = date_type.fromisoformat(date_to)
        else:
            d_to = date_to

        period_days = max((d_to - d_from).days, 1)
        prev_from = d_from - timedelta(days=period_days)
        prev_to = d_from - timedelta(days=1)

        # Current period
        txn_qs = Transaction.objects.filter(shop=shop, date__gte=d_from, date__lte=d_to)
        credit_qs = CreditEntry.objects.filter(shop=shop, date__gte=d_from, date__lte=d_to)

        total_sales = _safe_float(txn_qs.aggregate(total=Sum("debit_amount"))["total"])
        total_collections = _safe_float(
            credit_qs.filter(entry_type="returned").aggregate(total=Sum("amount"))["total"]
        )

        total_credit_given = _safe_float(
            credit_qs.filter(entry_type="given").aggregate(total=Sum("amount"))["total"]
        )
        total_credit_returned = _safe_float(
            credit_qs.filter(entry_type="returned").aggregate(total=Sum("amount"))["total"]
        )
        pending_amount = total_credit_given - total_credit_returned

        total_customers = txn_qs.values("customer_name").distinct().order_by().count()
        credit_customers = credit_qs.values("customer_name").distinct().order_by().count()
        total_customers = max(total_customers, credit_customers)

        # Previous period for comparison
        prev_txn = Transaction.objects.filter(shop=shop, date__gte=prev_from, date__lte=prev_to)
        prev_credit = CreditEntry.objects.filter(shop=shop, date__gte=prev_from, date__lte=prev_to)

        prev_sales = _safe_float(prev_txn.aggregate(total=Sum("debit_amount"))["total"])
        prev_collections = _safe_float(
            prev_credit.filter(entry_type="returned").aggregate(total=Sum("amount"))["total"]
        )
        prev_pending_given = _safe_float(
            prev_credit.filter(entry_type="given").aggregate(total=Sum("amount"))["total"]
        )
        prev_pending_returned = _safe_float(
            prev_credit.filter(entry_type="returned").aggregate(total=Sum("amount"))["total"]
        )
        prev_pending = prev_pending_given - prev_pending_returned
        prev_customers = prev_txn.values("customer_name").distinct().order_by().count()

        def pct_change(current, previous):
            if previous and previous > 0:
                change = ((current - previous) / previous) * 100
                return round(change, 0)
            return 0

        # Payment status from all credit entries
        all_credit = CreditEntry.objects.filter(shop=shop)
        customer_names = all_credit.values_list("customer_name", flat=True).distinct().order_by()
        settled_count = 0
        partial_count = 0
        pending_count = 0
        for name in customer_names:
            given = _safe_float(
                all_credit.filter(customer_name=name, entry_type="given").aggregate(total=Sum("amount"))["total"]
            )
            returned = _safe_float(
                all_credit.filter(customer_name=name, entry_type="returned").aggregate(total=Sum("amount"))["total"]
            )
            balance = given - returned
            if balance <= 0:
                settled_count += 1
            elif returned > 0:
                partial_count += 1
            else:
                pending_count += 1

        total_credit_customers = settled_count + partial_count + pending_count

        # Top customers by purchase (credit given)
        top_customers = []
        for name in all_credit.values_list("customer_name", flat=True).distinct().order_by():
            total_given = _safe_float(
                all_credit.filter(customer_name=name, entry_type="given").aggregate(total=Sum("amount"))["total"]
            )
            if total_given > 0:
                top_customers.append({"customer_name": name, "total_credit": total_given})
        top_customers.sort(key=lambda x: x["total_credit"], reverse=True)
        top_customers = top_customers[:5]

        # Sales by category
        category_data = (
            txn_qs.values("category__name")
            .annotate(revenue=Sum("debit_amount"), count=Count("id"))
            .order_by("-revenue")
        )
        sales_by_category = []
        for item in category_data:
            name = item["category__name"] or "Uncategorized"
            revenue = _safe_float(item["revenue"])
            sales_by_category.append({"category_name": name, "revenue": revenue})
        total_category_revenue = sum(c["revenue"] for c in sales_by_category)
        for c in sales_by_category:
            c["percentage"] = round(
                (c["revenue"] / total_category_revenue * 100) if total_category_revenue > 0 else 0, 1
            )

        # Sales vs Collections chart (last 30 days) - Python-side grouping
        start_30 = today - timedelta(days=29)
        txn_30 = Transaction.objects.filter(shop=shop, date__gte=start_30, date__lte=today)
        credit_30 = CreditEntry.objects.filter(
            shop=shop, date__gte=start_30, date__lte=today, entry_type="returned"
        )

        sales_by_day = defaultdict(float)
        for txn in txn_30:
            day = _to_date(txn.date)
            sales_by_day[day] += _safe_float(txn.debit_amount)

        collections_by_day = defaultdict(float)
        for ce in credit_30:
            day = _to_date(ce.date)
            collections_by_day[day] += _safe_float(ce.amount)

        chart_labels = []
        chart_sales = []
        chart_collections = []
        d = start_30
        while d <= today:
            chart_labels.append(d.strftime("%d %b"))
            chart_sales.append(sales_by_day.get(d, 0))
            chart_collections.append(collections_by_day.get(d, 0))
            d += timedelta(days=1)

        # Recent transactions
        recent_txns = Transaction.objects.filter(shop=shop).order_by("-date", "-created_at")[:10]
        recent_list = []
        for txn in recent_txns:
            recent_list.append({
                "date": str(txn.date),
                "customer_name": txn.customer_name or "-",
                "description": txn.description,
                "amount": float(txn.debit_amount),
                "payment_method": txn.payment_method,
                "charges": float(txn.charges),
                "profit": float(txn.profit),
            })

        # Recent credit activities
        recent_credits = CreditEntry.objects.filter(shop=shop).order_by("-date", "-created_at")[:10]
        recent_credit_list = []
        for ce in recent_credits:
            recent_credit_list.append({
                "date": str(ce.date),
                "customer_name": ce.customer_name,
                "entry_type": ce.entry_type,
                "amount": float(ce.amount),
                "remarks": ce.remarks,
            })

        return Response({
            "total_sales": total_sales,
            "sales_change": pct_change(total_sales, prev_sales),
            "total_collections": total_collections,
            "collections_change": pct_change(total_collections, prev_collections),
            "pending_amount": pending_amount,
            "pending_change": pct_change(pending_amount, prev_pending),
            "total_customers": total_customers,
            "customers_change": pct_change(total_customers, prev_customers),
            "payment_status": {
                "total": total_credit_customers,
                "settled": settled_count,
                "partial": partial_count,
                "pending": pending_count,
            },
            "top_customers": top_customers,
            "sales_by_category": sales_by_category,
            "chart": {
                "labels": chart_labels,
                "sales": chart_sales,
                "collections": chart_collections,
            },
            "recent_transactions": recent_list,
            "recent_credit_activities": recent_credit_list,
        })
