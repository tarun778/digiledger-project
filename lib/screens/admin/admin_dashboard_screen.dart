import 'package:flutter/material.dart';
import '../../services/api_service.dart';
import '../../utils/errors.dart';
import '../../utils/theme.dart';
import 'tenant_list_screen.dart';
import 'invoice_list_screen.dart';

class AdminDashboardScreen extends StatefulWidget {
  const AdminDashboardScreen({super.key});

  @override
  State<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends State<AdminDashboardScreen> {
  Map<String, dynamic>? _dashboard;
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadDashboard();
  }

  Future<void> _loadDashboard() async {
    try {
      setState(() { _isLoading = true; _error = null; });
      final data = await ApiService.getAdminDashboard();
      if (!mounted) return;
      setState(() { _dashboard = data; _isLoading = false; });
    } catch (e) {
      setState(() { _error = apiErrorText(e); _isLoading = false; });
      if (!mounted) return;
      showApiError(context, e);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Admin Dashboard'),
        backgroundColor: AppTheme.primaryColor,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadDashboard,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.error_outline, size: 48, color: AppTheme.errorColor),
                    const SizedBox(height: 16),
                    Text(_error!, textAlign: TextAlign.center),
                    const SizedBox(height: 16),
                    ElevatedButton(onPressed: _loadDashboard, child: const Text('Retry')),
                  ],
                ))
              : RefreshIndicator(
                  onRefresh: _loadDashboard,
                  child: SingleChildScrollView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Overview', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 16),
                        _buildStatsGrid(),
                        const SizedBox(height: 24),
                        _buildQuickActions(),
                      ],
                    ),
                  ),
                ),
    );
  }

  Widget _buildStatsGrid() {
    final stats = [
      {'title': 'Total Shops', 'value': '${_dashboard?['total_shops'] ?? 0}', 'icon': Icons.store, 'color': AppTheme.primaryColor},
      {'title': 'Active', 'value': '${_dashboard?['active_shops'] ?? 0}', 'icon': Icons.check_circle, 'color': AppTheme.successColor},
      {'title': 'Trial', 'value': '${_dashboard?['trial_shops'] ?? 0}', 'icon': Icons.timer, 'color': AppTheme.warningColor},
      {'title': 'Expired', 'value': '${_dashboard?['expired_shops'] ?? 0}', 'icon': Icons.cancel, 'color': AppTheme.errorColor},
      {'title': 'Total Users', 'value': '${_dashboard?['total_users'] ?? 0}', 'icon': Icons.people, 'color': AppTheme.secondaryColor},
      {'title': 'Revenue', 'value': 'Rs. ${(_dashboard?['total_revenue'] ?? 0).toStringAsFixed(0)}', 'icon': Icons.currency_rupee, 'color': Colors.green},
    ];

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3, crossAxisSpacing: 12, mainAxisSpacing: 12, childAspectRatio: 1.5,
      ),
      itemCount: stats.length,
      itemBuilder: (context, i) {
        final s = stats[i];
        return Card(
          elevation: 2,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(s['icon'] as IconData, color: s['color'] as Color, size: 28),
                const SizedBox(height: 8),
                Text(s['value'] as String, style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: s['color'] as Color)),
                const SizedBox(height: 4),
                Text(s['title'] as String, style: TextStyle(fontSize: 12, color: Colors.grey[600])),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildQuickActions() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Quick Actions', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(child: _actionCard('Manage Tenants', Icons.business, AppTheme.primaryColor, () {
              Navigator.push(context, MaterialPageRoute(builder: (_) => const TenantListScreen()));
            })),
            const SizedBox(width: 12),
            Expanded(child: _actionCard('Invoices', Icons.receipt_long, AppTheme.secondaryColor, () {
              Navigator.push(context, MaterialPageRoute(builder: (_) => const InvoiceListScreen()));
            })),
          ],
        ),
      ],
    );
  }

  Widget _actionCard(String title, IconData icon, Color color, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Card(
        elevation: 2,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            children: [
              Icon(icon, color: color, size: 36),
              const SizedBox(height: 8),
              Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
            ],
          ),
        ),
      ),
    );
  }
}
