import 'package:flutter/material.dart';
import '../../services/api_service.dart';
import '../../utils/errors.dart';
import '../../utils/theme.dart';
import '../../widgets/searchable_dropdown.dart';

class TenantDetailScreen extends StatefulWidget {
  final String tenantId;
  const TenantDetailScreen({super.key, required this.tenantId});

  @override
  State<TenantDetailScreen> createState() => _TenantDetailScreenState();
}

class _TenantDetailScreenState extends State<TenantDetailScreen> {
  Map<String, dynamic>? _tenant;
  List<dynamic> _users = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      final tenant = await ApiService.getAdminTenantDetail(widget.tenantId);
      final usersResp = await ApiService.getAdminTenantUsers(widget.tenantId);
      if (!mounted) return;
      setState(() { _tenant = tenant; _users = usersResp; _isLoading = false; });
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

  void _showRenewDialog() {
    String plan = _tenant!['plan'] ?? 'monthly';
    int months = 1;
    final amountController = TextEditingController(text: '999');
    final notesController = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: const Text('Renew Subscription'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SearchableDropdown<String>(
                items: const [
                  SearchableDropdownItem(value: 'monthly', label: 'Monthly'),
                  SearchableDropdownItem(value: 'quarterly', label: 'Quarterly'),
                  SearchableDropdownItem(value: 'yearly', label: 'Yearly'),
                ],
                value: plan,
                hint: 'Select plan',
                searchHint: 'Search plans…',
                labelText: 'Plan',
                onChanged: (v) => setDialogState(() => plan = v ?? plan),
              ),
              const SizedBox(height: 12),
              SearchableDropdown<int>(
                items: List.generate(
                  12,
                  (i) => SearchableDropdownItem(
                    value: i + 1,
                    label: '${i + 1} month${i > 0 ? 's' : ''}',
                  ),
                ),
                value: months,
                hint: 'Duration',
                searchHint: 'Search duration…',
                labelText: 'Duration',
                onChanged: (v) => setDialogState(() => months = v ?? months),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: amountController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'Amount (Rs.)', border: OutlineInputBorder()),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: notesController,
                decoration: const InputDecoration(labelText: 'Notes', border: OutlineInputBorder()),
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
            ElevatedButton(
              onPressed: () async {
                Navigator.pop(ctx);
                try {
                  await ApiService.renewTenantSubscription(widget.tenantId, {
                    'plan': plan,
                    'subscription_months': months,
                    'amount': double.tryParse(amountController.text) ?? 0,
                    'tax': 0,
                    'notes': notesController.text,
                  });
                  if (!mounted) return;
                  _loadData();
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Subscription renewed'), backgroundColor: AppTheme.successColor),
                  );
                } catch (e) {
                  if (!mounted) return;
                  showApiError(context, e);
                }
              },
              child: const Text('Renew'),
            ),
          ],
        ),
      ),
    );
  }

  void _showResetPasswordDialog() {
    final passwordController = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Reset Owner Password'),
        content: TextField(
          controller: passwordController,
          obscureText: true,
          decoration: const InputDecoration(labelText: 'New Password', border: OutlineInputBorder()),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () async {
              if (passwordController.text.length < 8) {
                ScaffoldMessenger.maybeOf(ctx)?.showSnackBar(
                  const SnackBar(content: Text('Password must be at least 8 characters')),
                );
                return;
              }
              Navigator.pop(ctx);
              try {
                await ApiService.resetTenantPassword(widget.tenantId, passwordController.text);
                if (!mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Password reset successfully'), backgroundColor: AppTheme.successColor),
                );
              } catch (e) {
                if (!mounted) return;
                showApiError(context, e);
              }
            },
            child: const Text('Reset'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final status = _tenant?['subscription_status'] ?? 'trial';
    return Scaffold(
      appBar: AppBar(
        title: Text(_tenant?['name'] ?? 'Tenant Details'),
        backgroundColor: AppTheme.primaryColor,
        foregroundColor: Colors.white,
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: _loadData),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _tenant == null
              ? const Center(child: Text('Tenant not found'))
              : SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Status Card
                      Card(
                        elevation: 3,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Icon(Icons.store, size: 32, color: _statusColor(status)),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(_tenant!['name'], style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                                        Text(_tenant!['owner_name'], style: TextStyle(color: Colors.grey[600])),
                                      ],
                                    ),
                                  ),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                                    decoration: BoxDecoration(color: _statusColor(status), borderRadius: BorderRadius.circular(20)),
                                    child: Text(status.toUpperCase(), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12)),
                                  ),
                                ],
                              ),
                              const Divider(height: 24),
                              _infoRow('Phone', _tenant!['phone'] ?? ''),
                              _infoRow('Email', _tenant!['email'] ?? ''),
                              _infoRow('City', _tenant!['city'] ?? 'N/A'),
                              _infoRow('Plan', _tenant!['plan'] ?? 'free'),
                              _infoRow('Users', '${_tenant!['user_count'] ?? 0}'),
                              _infoRow('Subscription End', _tenant!['subscription_end']?.toString().substring(0, 10) ?? 'N/A'),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Actions
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          if (status != 'active')
                            ElevatedButton.icon(
                              onPressed: () async {
                                try {
                                  await ApiService.activateTenant(widget.tenantId);
                                  if (!mounted) return;
                                  _loadData();
                                } catch (e) {
                                  if (!context.mounted) return;
                                  showApiError(context, e);
                                }
                              },
                              icon: const Icon(Icons.check_circle),
                              label: const Text('Activate'),
                              style: ElevatedButton.styleFrom(backgroundColor: AppTheme.successColor),
                            ),
                          if (status == 'active')
                            ElevatedButton.icon(
                              onPressed: () async {
                                try {
                                  await ApiService.suspendTenant(widget.tenantId);
                                  if (!mounted) return;
                                  _loadData();
                                } catch (e) {
                                  if (!context.mounted) return;
                                  showApiError(context, e);
                                }
                              },
                              icon: const Icon(Icons.block),
                              label: const Text('Suspend'),
                              style: ElevatedButton.styleFrom(backgroundColor: AppTheme.errorColor),
                            ),
                          ElevatedButton.icon(
                            onPressed: _showRenewDialog,
                            icon: const Icon(Icons.autorenew),
                            label: const Text('Renew'),
                            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.secondaryColor),
                          ),
                          ElevatedButton.icon(
                            onPressed: _showResetPasswordDialog,
                            icon: const Icon(Icons.lock_reset),
                            label: const Text('Reset Password'),
                          ),
                        ],
                      ),
                      const SizedBox(height: 24),

                      // Users
                      const Text('Users', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 8),
                      ..._users.map((u) => Card(
                        child: ListTile(
                          leading: CircleAvatar(
                            child: Text((u['name'] ?? '?')[0].toUpperCase()),
                          ),
                          title: Text(u['name'] ?? ''),
                          subtitle: Text('${u['email']} - ${u['role']}'),
                          trailing: Icon(
                            u['is_active'] == true ? Icons.check_circle : Icons.cancel,
                            color: u['is_active'] == true ? AppTheme.successColor : AppTheme.errorColor,
                          ),
                        ),
                      )),
                    ],
                  ),
                ),
    );
  }

  Widget _infoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          SizedBox(width: 120, child: Text(label, style: TextStyle(color: Colors.grey[600]))),
          Expanded(child: Text(value, style: const TextStyle(fontWeight: FontWeight.w500))),
        ],
      ),
    );
  }
}
