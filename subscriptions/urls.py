from django.urls import path
from . import views
from .invoice_pdf import generate_invoice_pdf
from django.http import HttpResponse

def invoice_pdf_view(request, pk):
    response = generate_invoice_pdf(pk)
    if response is None:
        return HttpResponse("Invoice not found", status=404)
    return response

urlpatterns = [
    path("dashboard/", views.AdminDashboardView.as_view(), name="admin-dashboard"),
    path("tenants/", views.TenantListView.as_view(), name="tenant-list"),
    path("tenants/create/", views.CreateTenantView.as_view(), name="tenant-create"),
    path("tenants/<uuid:pk>/", views.TenantDetailView.as_view(), name="tenant-detail"),
    path("tenants/<uuid:pk>/users/", views.TenantUserListView.as_view(), name="tenant-users"),
    path("tenants/<uuid:pk>/renew/", views.RenewSubscriptionView.as_view(), name="tenant-renew"),
    path("tenants/<uuid:pk>/suspend/", views.SuspendTenantView.as_view(), name="tenant-suspend"),
    path("tenants/<uuid:pk>/activate/", views.ActivateTenantView.as_view(), name="tenant-activate"),
    path("tenants/<uuid:pk>/reset-password/", views.TenantPasswordResetView.as_view(), name="tenant-reset-password"),
    path("invoices/", views.InvoiceListView.as_view(), name="invoice-list"),
    path("invoices/<uuid:pk>/", views.InvoiceDetailView.as_view(), name="invoice-detail"),
    path("invoices/generate/", views.GenerateInvoiceView.as_view(), name="invoice-generate"),
    path("invoices/<uuid:pk>/pdf/", invoice_pdf_view, name="invoice-pdf"),
]
