from django.urls import path
from . import views

urlpatterns = [
    # Bank Accounts
    path("bank-accounts/", views.BankAccountListView.as_view(), name="bank-account-list"),
    path("bank-accounts/<uuid:pk>/movements/", views.BankAccountMovementsView.as_view(), name="bank-account-movements"),
    path("bank-accounts/<uuid:pk>/", views.BankAccountDetailView.as_view(), name="bank-account-detail"),

    # Categories
    path("categories/", views.CategoryListView.as_view(), name="category-list"),
    path("categories/create/", views.CategoryCreateView.as_view(), name="category-create"),
    path("categories/<uuid:pk>/", views.CategoryDetailView.as_view(), name="category-detail"),
    path("categories/seed/", views.SeedCategoriesView.as_view(), name="category-seed"),

    # Transactions
    path("", views.TransactionListView.as_view(), name="transaction-list"),
    path("create/", views.TransactionCreateView.as_view(), name="transaction-create"),
    path("<uuid:pk>/", views.TransactionDetailView.as_view(), name="transaction-detail"),

    # CC Bill Payments
    path("cc-bills/", views.CCBillPaymentListView.as_view(), name="ccbill-list"),
    path("cc-bills/create/", views.CCBillPaymentCreateView.as_view(), name="ccbill-create"),
    path("cc-bills/<uuid:pk>/", views.CCBillPaymentDetailView.as_view(), name="ccbill-detail"),

    # Dashboard
    path("dashboard/", views.DashboardView.as_view(), name="dashboard"),
    path("chart-data/", views.ChartDataView.as_view(), name="chart-data"),

    # Credit Entries (Pending Payments)
    path("credits/", views.CreditEntryListView.as_view(), name="credit-list"),
    path("credits/create/", views.CreditEntryCreateView.as_view(), name="credit-create"),
    path("credits/<uuid:pk>/", views.CreditEntryDetailView.as_view(), name="credit-detail"),
    path("credits/summary/", views.CreditSummaryView.as_view(), name="credit-summary"),

    # Description Suggestions
    path("descriptions/", views.DescriptionSuggestionListView.as_view(), name="description-list"),
    path("descriptions/create/", views.DescriptionSuggestionCreateView.as_view(), name="description-create"),
    path("descriptions/<uuid:pk>/", views.DescriptionSuggestionDetailView.as_view(), name="description-detail"),
    path("descriptions/seed/", views.SeedDescriptionSuggestionsView.as_view(), name="description-seed"),
]
