from rest_framework import generics, permissions, status
from rest_framework.response import Response
from rest_framework.views import APIView
from django.contrib.auth import get_user_model
from django.db import models
from django.utils import timezone
from datetime import timedelta
from decimal import Decimal

from accounts.models import Shop
from .models import Invoice
from .serializers import (
    AdminShopSerializer, CreateTenantSerializer,
    SubscriptionUpdateSerializer, InvoiceSerializer,
    TenantPasswordResetSerializer,
)

User = get_user_model()


class IsSuperuser(permissions.BasePermission):
    def has_permission(self, request, view):
        return request.user and request.user.is_superuser


class AdminDashboardView(APIView):
    permission_classes = [IsSuperuser]

    def get(self, request):
        total_shops = Shop.objects.count()
        active_shops = Shop.objects.filter(subscription_status="active").count()
        trial_shops = Shop.objects.filter(subscription_status="trial").count()
        expired_shops = Shop.objects.filter(subscription_status="expired").count()
        total_users = User.objects.count()
        total_revenue = Invoice.objects.filter(status="paid").aggregate(
            total=models.Sum("total_amount")
        )["total"] or 0

        return Response({
            "total_shops": total_shops,
            "active_shops": active_shops,
            "trial_shops": trial_shops,
            "expired_shops": expired_shops,
            "total_users": total_users,
            "total_revenue": float(total_revenue),
        })


class TenantListView(generics.ListAPIView):
    serializer_class = AdminShopSerializer
    permission_classes = [IsSuperuser]

    def get_queryset(self):
        queryset = Shop.objects.all().order_by("-created_at")
        search = self.request.query_params.get("search")
        if search:
            queryset = queryset.filter(
                models.Q(name__icontains=search) |
                models.Q(owner_name__icontains=search) |
                models.Q(email__icontains=search) |
                models.Q(phone__icontains=search)
            )
        return queryset


class TenantDetailView(generics.RetrieveAPIView):
    serializer_class = AdminShopSerializer
    permission_classes = [IsSuperuser]
    queryset = Shop.objects.all()


class CreateTenantView(APIView):
    permission_classes = [IsSuperuser]

    def post(self, request):
        serializer = CreateTenantSerializer(data=request.data)
        serializer.is_valid(raise_exception=True)
        data = serializer.validated_data

        shop = Shop.objects.create(
            name=data["shop_name"],
            owner_name=data["owner_name"],
            phone=data["owner_phone"],
            email=data["owner_email"],
            plan=data["plan"],
            subscription_status="trial" if data["plan"] == "free" else "active",
            subscription_start=timezone.now(),
            subscription_end=timezone.now() + timedelta(days=30),
        )

        user = User.objects.create_user(
            email=data["owner_email"],
            name=data["owner_name"],
            phone=data["owner_phone"],
            shop=shop,
            password=data["password"],
            role="owner",
        )

        if data["plan"] != "free":
            months = data["subscription_months"]
            tax_rate = Decimal("0.18")
            base_fee = shop.monthly_fee * months
            tax = base_fee * tax_rate
            total = base_fee + tax

            shop.subscription_start = timezone.now()
            shop.subscription_end = timezone.now() + timedelta(days=months * 30)
            shop.monthly_fee = base_fee / months if months else 0
            shop.save()

            invoice = Invoice.objects.create(
                shop=shop,
                plan=data["plan"],
                amount=base_fee,
                tax=tax,
                total_amount=total,
                status="paid",
                billing_period_start=shop.subscription_start,
                billing_period_end=shop.subscription_end,
                notes=f"Auto-generated for {data['plan']} plan ({months} months)",
            )
            invoice.paid_at = timezone.now()
            invoice.save()

        return Response({
            "shop": AdminShopSerializer(shop).data,
            "credentials": {
                "email": data["owner_email"],
                "password": data["password"],
            },
            "message": f"Tenant '{shop.name}' created successfully",
        }, status=status.HTTP_201_CREATED)


class RenewSubscriptionView(APIView):
    permission_classes = [IsSuperuser]

    def post(self, request, pk):
        try:
            shop = Shop.objects.get(pk=pk)
        except Shop.DoesNotExist:
            return Response({"error": "Shop not found"}, status=404)

        serializer = SubscriptionUpdateSerializer(data=request.data)
        serializer.is_valid(raise_exception=True)
        data = serializer.validated_data

        months = data["subscription_months"]
        now = timezone.now()

        if shop.subscription_end and shop.subscription_end > now:
            start = shop.subscription_end
        else:
            start = now

        end = start + timedelta(days=months * 30)

        shop.plan = data["plan"]
        shop.subscription_status = "active"
        shop.subscription_start = start
        shop.subscription_end = end
        shop.monthly_fee = data["amount"] / months
        shop.is_active = True
        shop.save()

        invoice = Invoice.objects.create(
            shop=shop,
            plan=data["plan"],
            amount=data["amount"],
            tax=data["tax"],
            total_amount=data["amount"] + data["tax"],
            status="paid",
            billing_period_start=start,
            billing_period_end=end,
            notes=data.get("notes", f"Renewal - {months} months"),
        )
        invoice.paid_at = now
        invoice.save()

        return Response({
            "shop": AdminShopSerializer(shop).data,
            "invoice": InvoiceSerializer(invoice).data,
            "message": f"Subscription renewed until {end.strftime('%d %b %Y')}",
        })


class SuspendTenantView(APIView):
    permission_classes = [IsSuperuser]

    def post(self, request, pk):
        try:
            shop = Shop.objects.get(pk=pk)
        except Shop.DoesNotExist:
            return Response({"error": "Shop not found"}, status=404)

        shop.subscription_status = "suspended"
        shop.is_active = False
        shop.save()

        return Response({"message": f"Shop '{shop.name}' suspended"})


class ActivateTenantView(APIView):
    permission_classes = [IsSuperuser]

    def post(self, request, pk):
        try:
            shop = Shop.objects.get(pk=pk)
        except Shop.DoesNotExist:
            return Response({"error": "Shop not found"}, status=404)

        shop.is_active = True
        if shop.subscription_end and shop.subscription_end > timezone.now():
            shop.subscription_status = "active"
        shop.save()

        return Response({"message": f"Shop '{shop.name}' activated"})


class InvoiceListView(generics.ListAPIView):
    serializer_class = InvoiceSerializer
    permission_classes = [IsSuperuser]

    def get_queryset(self):
        queryset = Invoice.objects.all()
        shop_id = self.request.query_params.get("shop_id")
        if shop_id:
            queryset = queryset.filter(shop_id=shop_id)
        return queryset


class InvoiceDetailView(generics.RetrieveAPIView):
    serializer_class = InvoiceSerializer
    permission_classes = [IsSuperuser]
    queryset = Invoice.objects.all()


class GenerateInvoiceView(APIView):
    permission_classes = [IsSuperuser]

    def post(self, request):
        shop_id = request.data.get("shop_id")
        try:
            shop = Shop.objects.get(pk=shop_id)
        except Shop.DoesNotExist:
            return Response({"error": "Shop not found"}, status=404)

        amount = Decimal(str(request.data.get("amount", 0)))
        tax_rate = Decimal("0.18")
        tax = amount * tax_rate
        total = amount + tax

        invoice = Invoice.objects.create(
            shop=shop,
            plan=request.data.get("plan", shop.plan),
            amount=amount,
            tax=tax,
            total_amount=total,
            status="pending",
            billing_period_start=shop.subscription_start or timezone.now(),
            billing_period_end=shop.subscription_end or timezone.now(),
            notes=request.data.get("notes", ""),
        )

        return Response(InvoiceSerializer(invoice).data, status=201)


class TenantUserListView(APIView):
    permission_classes = [IsSuperuser]

    def get(self, request, pk):
        try:
            shop = Shop.objects.get(pk=pk)
        except Shop.DoesNotExist:
            return Response({"error": "Shop not found"}, status=404)

        users = User.objects.filter(shop=shop)
        return Response([
            {
                "id": str(u.id),
                "email": u.email,
                "name": u.name,
                "phone": u.phone,
                "role": u.role,
                "is_active": u.is_active,
                "created_at": u.created_at,
            }
            for u in users
        ])


class TenantPasswordResetView(APIView):
    permission_classes = [IsSuperuser]

    def post(self, request, pk):
        try:
            shop = Shop.objects.get(pk=pk)
        except Shop.DoesNotExist:
            return Response({"error": "Shop not found"}, status=404)

        serializer = TenantPasswordResetSerializer(data=request.data)
        serializer.is_valid(raise_exception=True)

        owner = User.objects.filter(shop=shop, role="owner").first()
        if owner:
            owner.set_password(serializer.validated_data["new_password"])
            owner.save()
            return Response({"message": "Owner password reset successfully"})
        return Response({"error": "No owner found"}, status=404)
