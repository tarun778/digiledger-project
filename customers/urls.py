from django.urls import path
from . import views

urlpatterns = [
    path("", views.CustomerListView.as_view(), name="customer-list"),
    path("create/", views.CustomerCreateView.as_view(), name="customer-create"),
    path("by-phone/", views.CustomerByPhoneView.as_view(), name="customer-by-phone"),
    path("<uuid:pk>/", views.CustomerDetailView.as_view(), name="customer-detail"),
]
