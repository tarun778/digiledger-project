from django.urls import path
from rest_framework_simplejwt.views import TokenRefreshView
from . import views

urlpatterns = [
    path("register/", views.RegisterView.as_view(), name="register"),
    path("login/", views.LoginView.as_view(), name="login"),
    path("token/refresh/", TokenRefreshView.as_view(), name="token-refresh"),
    path("profile/", views.ProfileView.as_view(), name="profile"),
    path("shop/", views.ShopView.as_view(), name="shop"),
    path("staff/", views.StaffListView.as_view(), name="staff-list"),
    path("staff/add/", views.AddStaffView.as_view(), name="staff-add"),
    path("staff/<uuid:pk>/", views.StaffDetailView.as_view(), name="staff-detail"),
    path("staff/<uuid:pk>/reset-password/", views.StaffPasswordResetView.as_view(), name="staff-reset-password"),
    path("change-password/", views.ChangePasswordView.as_view(), name="change-password"),
]
