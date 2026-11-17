import 'package:flutter_dotenv/flutter_dotenv.dart';

class ApiConfig {
  static String get baseUrl => dotenv.env['API_BASE_URL'] ?? 'http://localhost:8000/api';
  static String get appName => dotenv.env['APP_NAME'] ?? 'DigiLedger';
  static String get environment => dotenv.env['ENVIRONMENT'] ?? 'development';
  
  static String get loginUrl => "$baseUrl/auth/login/";
  static String get registerUrl => "$baseUrl/auth/register/";
  static String get profileUrl => "$baseUrl/auth/profile/";
  static String get shopUrl => "$baseUrl/auth/shop/";
  static String get staffUrl => "$baseUrl/auth/staff/";
  static String get changePasswordUrl => "$baseUrl/auth/change-password/";
  
  static String get categoriesUrl => "$baseUrl/transactions/categories/";
  static String get bankAccountsUrl => "$baseUrl/transactions/bank-accounts/";
  static String get transactionsUrl => "$baseUrl/transactions/";
  static String get ccBillsUrl => "$baseUrl/transactions/cc-bills/";
  static String get dashboardUrl => "$baseUrl/transactions/dashboard/";
  static String get chartDataUrl => "$baseUrl/transactions/chart-data/";
  static String get descriptionsUrl => "$baseUrl/transactions/descriptions/";
  
  static String get customersUrl => "$baseUrl/customers/";
  
  static String get dailyReportUrl => "$baseUrl/reports/daily/";
  static String get monthlyReportUrl => "$baseUrl/reports/monthly/";
  static String get quarterlyReportUrl => "$baseUrl/reports/quarterly/";
  static String get yearlyReportUrl => "$baseUrl/reports/yearly/";
  static String get categoryReportUrl => "$baseUrl/reports/category/";
  static String get paymentMethodReportUrl => "$baseUrl/reports/payment-method/";
  static String get profitSummaryUrl => "$baseUrl/reports/profit-summary/";
  static String get reportsOverviewUrl => "$baseUrl/reports/overview/";
  static String get exportTransactionsUrl => "$baseUrl/reports/export/transactions/";
  static String get exportCCBillsUrl => "$baseUrl/reports/export/cc-bills/";
  static String get exportReportUrl => "$baseUrl/reports/export/report/";
  static String get exportDashboardUrl => "$baseUrl/reports/export/dashboard/";

  // Admin API
  static String get adminDashboardUrl => "$baseUrl/admin/dashboard/";
  static String get adminTenantsUrl => "$baseUrl/admin/tenants/";
  static String get adminInvoicesUrl => "$baseUrl/admin/invoices/";
  static String adminTenantDetailUrl(String id) => "$baseUrl/admin/tenants/$id/";
  static String adminTenantRenewUrl(String id) => "$baseUrl/admin/tenants/$id/renew/";
  static String adminTenantSuspendUrl(String id) => "$baseUrl/admin/tenants/$id/suspend/";
  static String adminTenantActivateUrl(String id) => "$baseUrl/admin/tenants/$id/activate/";
  static String adminTenantResetPasswordUrl(String id) => "$baseUrl/admin/tenants/$id/reset-password/";
  static String adminTenantUsersUrl(String id) => "$baseUrl/admin/tenants/$id/users/";
  static String adminInvoiceDetailUrl(String id) => "$baseUrl/admin/invoices/$id/";
  static String adminInvoicePdfUrl(String id) => "$baseUrl/admin/invoices/$id/pdf/";
}
