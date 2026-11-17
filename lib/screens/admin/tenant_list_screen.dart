import 'package:flutter/material.dart';
import '../../services/api_service.dart';
import '../../utils/errors.dart';
import '../../utils/theme.dart';
import '../../utils/form_dialog.dart';
import 'create_tenant_screen.dart';
import 'tenant_detail_screen.dart';

class TenantListScreen extends StatefulWidget {
  const TenantListScreen({super.key});

  @override
  State<TenantListScreen> createState() => _TenantListScreenState();
}

class _TenantListScreenState extends State<TenantListScreen> {
  List<Map<String, dynamic>> _tenants = [];
  bool _isLoading = true;
  String _search = '';

  @override
  void initState() {
    super.initState();
    _loadTenants();
  }

  Future<void> _loadTenants() async {
    setState(() => _isLoading = true);
    try {
      final data = await ApiService.getAdminTenants(search: _search);
      if (!mounted) return;
      setState(() { _tenants = data; _isLoading = false; });
    } catch (e) {
      setState(() => _isLoading = false);
      if (!mounted) return;
      showApiError(context, e);
    }
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'active': return AppTheme.successColor;
      case 'trial': return AppTheme.warningColor;
      case 'expired': return AppTheme.errorColor;
      case 'suspended': return Colors.orange;
      default: return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Tenants'),
        backgroundColor: AppTheme.primaryColor,
        foregroundColor: Colors.white,
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: _loadTenants),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          await showFormDialog(context, const CreateTenantScreen());
          if (!mounted) return;
          _loadTenants();
        },
        icon: const Icon(Icons.add),
        label: const Text('New Tenant'),
        backgroundColor: AppTheme.primaryColor,
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: TextField(
              decoration: InputDecoration(
                hintText: 'Search tenants...',
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                filled: true,
                fillColor: Colors.white,
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              ),
              onChanged: (v) { _search = v; _loadTenants(); },
            ),
          ),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _tenants.isEmpty
                    ? const Center(child: Text('No tenants found'))
                    : RefreshIndicator(
                        onRefresh: _loadTenants,
                        child: ListView.builder(
                          padding: const EdgeInsets.only(bottom: 80),
                          itemCount: _tenants.length,
                          itemBuilder: (context, i) => _tenantCard(_tenants[i]),
                        ),
                      ),
          ),
        ],
      ),
    );
  }

  Widget _tenantCard(Map<String, dynamic> tenant) {
    final status = tenant['subscription_status'] ?? 'trial';
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ListTile(
        contentPadding: const EdgeInsets.all(16),
        leading: CircleAvatar(
          backgroundColor: _statusColor(status).withValues(alpha: 0.1),
          child: Icon(Icons.store, color: _statusColor(status)),
        ),
        title: Text(tenant['name'] ?? '', style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            Text('Owner: ${tenant['owner_name'] ?? ''}'),
            Text('Phone: ${tenant['phone'] ?? ''}'),
            const SizedBox(height: 4),
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: _statusColor(status).withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(status.toUpperCase(), style: TextStyle(fontSize: 11, color: _statusColor(status), fontWeight: FontWeight.bold)),
                ),
                const SizedBox(width: 8),
                Text('${tenant['plan'] ?? 'free'} plan', style: TextStyle(fontSize: 12, color: Colors.grey[600])),
              ],
            ),
          ],
        ),
        trailing: const Icon(Icons.chevron_right),
        onTap: () async {
          await Navigator.push(context, MaterialPageRoute(builder: (_) => TenantDetailScreen(tenantId: tenant['id'])));
          if (!mounted) return;
          _loadTenants();
        },
      ),
    );
  }
}
