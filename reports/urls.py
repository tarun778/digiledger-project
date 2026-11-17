from django.urls import path
from . import views
from . import export_views

urlpatterns = [
    path("daily/", views.DailyReportView.as_view(), name="daily-report"),
    path("monthly/", views.MonthlyReportView.as_view(), name="monthly-report"),
    path("quarterly/", views.QuarterlyReportView.as_view(), name="quarterly-report"),
    path("yearly/", views.YearlyReportView.as_view(), name="yearly-report"),
    path("category/", views.CategoryReportView.as_view(), name="category-report"),
    path("payment-method/", views.PaymentMethodReportView.as_view(), name="payment-method-report"),
    path("profit-summary/", views.ProfitSummaryView.as_view(), name="profit-summary"),
    path("overview/", views.ReportsOverviewView.as_view(), name="reports-overview"),
    # Export
    path("export/transactions/", export_views.ExportTransactionsExcelView.as_view(), name="export-transactions"),
    path("export/cc-bills/", export_views.ExportCCBillsExcelView.as_view(), name="export-cc-bills"),
    path("export/report/", export_views.ExportReportExcelView.as_view(), name="export-report"),
    path("export/dashboard/", export_views.ExportDashboardPDFView.as_view(), name="export-dashboard"),
]
