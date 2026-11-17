from rest_framework import generics, permissions, status
from rest_framework.response import Response
from rest_framework.views import APIView
from rest_framework_simplejwt.tokens import RefreshToken
from django.contrib.auth import authenticate, get_user_model
from .serializers import (
    RegisterSerializer, LoginSerializer, UserSerializer,
    ShopSerializer, AddStaffSerializer, ChangePasswordSerializer,
)
from .models import Shop

User = get_user_model()


class RegisterView(generics.CreateAPIView):
    serializer_class = RegisterSerializer
    permission_classes = [permissions.AllowAny]

    def create(self, request, *args, **kwargs):
        serializer = self.get_serializer(data=request.data)
        serializer.is_valid(raise_exception=True)
        user = serializer.save()
        refresh = RefreshToken.for_user(user)
        return Response({
            "user": UserSerializer(user).data,
            "tokens": {
                "access": str(refresh.access_token),
                "refresh": str(refresh),
            },
        }, status=status.HTTP_201_CREATED)


class LoginView(APIView):
    permission_classes = [permissions.AllowAny]

    def post(self, request):
        serializer = LoginSerializer(data=request.data)
        serializer.is_valid(raise_exception=True)

        email = serializer.validated_data["email"]
        password = serializer.validated_data["password"]

        from django.contrib.auth import get_user_model
        User = get_user_model()

        try:
            user_obj = User.objects.get(email=email)
        except User.DoesNotExist:
            return Response(
                {"error": "No account found with this email"},
                status=status.HTTP_404_NOT_FOUND,
            )

        user = authenticate(email=email, password=password)
        if user is None:
            return Response(
                {"error": "Incorrect password. Please try again."},
                status=status.HTTP_401_UNAUTHORIZED,
            )

        # Check subscription status (skip for superusers)
        if not user.is_superuser and user.shop:
            from django.utils import timezone
            shop = user.shop
            if shop.subscription_status == "suspended":
                return Response(
                    {"error": "Your account has been suspended. Please contact support."},
                    status=status.HTTP_403_FORBIDDEN,
                )
            if shop.subscription_status == "expired":
                return Response(
                    {"error": "Your subscription has expired. Please contact support to renew."},
                    status=status.HTTP_403_FORBIDDEN,
                )
            if shop.subscription_end and shop.subscription_end < timezone.now():
                shop.subscription_status = "expired"
                shop.save()
                return Response(
                    {"error": "Your subscription has expired. Please contact support to renew."},
                    status=status.HTTP_403_FORBIDDEN,
                )

        from django.utils import timezone as _tz
        user.last_login = _tz.now()
        user.save(update_fields=["last_login"])

        refresh = RefreshToken.for_user(user)
        return Response({
            "user": UserSerializer(user).data,
            "tokens": {
                "access": str(refresh.access_token),
                "refresh": str(refresh),
            },
        })


class ProfileView(generics.RetrieveUpdateAPIView):
    serializer_class = UserSerializer

    def get_object(self):
        return self.request.user


class ShopView(generics.RetrieveUpdateAPIView):
    serializer_class = ShopSerializer

    def get_object(self):
        return self.request.user.shop


class StaffListView(generics.ListAPIView):
    serializer_class = UserSerializer

    def get_queryset(self):
        return User.objects.filter(shop=self.request.user.shop).exclude(role="owner")


class AddStaffView(generics.CreateAPIView):
    serializer_class = AddStaffSerializer

    def perform_create(self, serializer):
        if self.request.user.role != "owner":
            from rest_framework.exceptions import PermissionDenied
            raise PermissionDenied("Only shop owner can add staff")
        serializer.save()


class StaffDetailView(generics.RetrieveUpdateDestroyAPIView):
    serializer_class = UserSerializer

    def get_queryset(self):
        return User.objects.filter(shop=self.request.user.shop)

    def perform_update(self, serializer):
        if self.request.user.role != "owner":
            from rest_framework.exceptions import PermissionDenied
            raise PermissionDenied("Only shop owner can update staff")
        new_role = serializer.validated_data.get("role")
        if new_role == "owner":
            from rest_framework.exceptions import ValidationError
            raise ValidationError("Cannot assign owner role. Each shop has only one owner.")
        serializer.save()

    def perform_destroy(self, instance):
        if instance.role == "owner":
            from rest_framework.exceptions import PermissionDenied
            raise PermissionDenied("Cannot remove the shop owner")
        if instance.id == self.request.user.id:
            from rest_framework.exceptions import PermissionDenied
            raise PermissionDenied("Cannot remove yourself")
        instance.delete()


class StaffPasswordResetView(APIView):
    def post(self, request, pk):
        if request.user.role != "owner":
            from rest_framework.exceptions import PermissionDenied
            raise PermissionDenied("Only shop owner can reset passwords")

        staff = User.objects.get(pk=pk, shop=request.user.shop)
        new_password = request.data.get("password")
        if not new_password or len(new_password) < 8:
            return Response({"error": "Password must be at least 8 characters"}, status=400)

        staff.set_password(new_password)
        staff.save()
        return Response({"message": "Password reset successfully"})


class ChangePasswordView(APIView):
    def post(self, request):
        serializer = ChangePasswordSerializer(data=request.data, context={"request": request})
        serializer.is_valid(raise_exception=True)
        request.user.set_password(serializer.validated_data["new_password"])
        request.user.save()
        return Response({"message": "Password changed successfully"})
