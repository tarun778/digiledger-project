from rest_framework import serializers


class DailyReportSerializer(serializers.Serializer):
    date = serializers.DateField()
    transactions = serializers.IntegerField()
    revenue = serializers.DecimalField(max_digits=12, decimal_places=2)
    profit = serializers.DecimalField(max_digits=12, decimal_places=2)
    cc_bill_payments = serializers.IntegerField()
    cc_bill_revenue = serializers.DecimalField(max_digits=12, decimal_places=2)
    cc_bill_profit = serializers.DecimalField(max_digits=12, decimal_places=2)


class MonthlyReportSerializer(serializers.Serializer):
    year = serializers.IntegerField()
    month = serializers.IntegerField()
    month_name = serializers.CharField()
    transactions = serializers.IntegerField()
    revenue = serializers.DecimalField(max_digits=12, decimal_places=2)
    profit = serializers.DecimalField(max_digits=12, decimal_places=2)
    cc_bill_payments = serializers.IntegerField()
    cc_bill_revenue = serializers.DecimalField(max_digits=12, decimal_places=2)
    cc_bill_profit = serializers.DecimalField(max_digits=12, decimal_places=2)


class QuarterlyReportSerializer(serializers.Serializer):
    year = serializers.IntegerField()
    quarter = serializers.IntegerField()
    quarter_name = serializers.CharField()
    transactions = serializers.IntegerField()
    revenue = serializers.DecimalField(max_digits=12, decimal_places=2)
    profit = serializers.DecimalField(max_digits=12, decimal_places=2)


class YearlyReportSerializer(serializers.Serializer):
    year = serializers.IntegerField()
    transactions = serializers.IntegerField()
    revenue = serializers.DecimalField(max_digits=12, decimal_places=2)
    profit = serializers.DecimalField(max_digits=12, decimal_places=2)


class CategoryReportSerializer(serializers.Serializer):
    category_name = serializers.CharField()
    category_icon = serializers.CharField()
    transactions = serializers.IntegerField()
    revenue = serializers.DecimalField(max_digits=12, decimal_places=2)
    profit = serializers.DecimalField(max_digits=12, decimal_places=2)


class PaymentMethodReportSerializer(serializers.Serializer):
    payment_method = serializers.CharField()
    payment_label = serializers.CharField()
    transactions = serializers.IntegerField()
    revenue = serializers.DecimalField(max_digits=12, decimal_places=2)
    profit = serializers.DecimalField(max_digits=12, decimal_places=2)


class ProfitSummarySerializer(serializers.Serializer):
    total_revenue = serializers.DecimalField(max_digits=12, decimal_places=2)
    total_profit = serializers.DecimalField(max_digits=12, decimal_places=2)
    total_transactions = serializers.IntegerField()
    total_cc_payments = serializers.IntegerField()
    avg_profit_per_day = serializers.DecimalField(max_digits=12, decimal_places=2)
    best_day_profit = serializers.DecimalField(max_digits=12, decimal_places=2)
    best_day_date = serializers.DateField()
