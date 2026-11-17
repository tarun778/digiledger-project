from rest_framework import generics
from django.db.models import Q
from .models import Customer
from .serializers import CustomerSerializer, CustomerListSerializer, CustomerDetailSerializer


class CustomerListView(generics.ListAPIView):
    serializer_class = CustomerListSerializer

    def get_queryset(self):
        qs = Customer.objects.filter(shop=self.request.user.shop, is_active=True)
        search = self.request.query_params.get("search")
        if search:
            qs = qs.filter(
                Q(name__icontains=search) |
                Q(phone__icontains=search) |
                Q(email__icontains=search)
            )
        return qs


class CustomerCreateView(generics.CreateAPIView):
    serializer_class = CustomerSerializer


class CustomerDetailView(generics.RetrieveUpdateDestroyAPIView):
    serializer_class = CustomerDetailSerializer

    def get_queryset(self):
        return Customer.objects.filter(shop=self.request.user.shop)


class CustomerByPhoneView(generics.GenericAPIView):
    serializer_class = CustomerDetailSerializer

    def get(self, request):
        phone = request.query_params.get("phone")
        if not phone:
            return {"error": "Phone number required"}

        customer = Customer.objects.filter(
            shop=request.user.shop, phone=phone
        ).first()

        if customer:
            serializer = self.get_serializer(customer)
            return Response(serializer.data)

        return Response({"phone": phone, "exists": False})
