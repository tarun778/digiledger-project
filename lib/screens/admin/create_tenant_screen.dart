import 'package:flutter/material.dart';
import '../../services/api_service.dart';
import '../../utils/errors.dart';
import '../../utils/theme.dart';
import '../../widgets/searchable_dropdown.dart';

class CreateTenantScreen extends StatefulWidget {
  const CreateTenantScreen({super.key});

  @override
  State<CreateTenantScreen> createState() => _CreateTenantScreenState();
}

class _CreateTenantScreenState extends State<CreateTenantScreen> {
  final _formKey = GlobalKey<FormState>();
  final _shopNameController = TextEditingController();
  final _ownerNameController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _passwordController = TextEditingController();
  String _selectedPlan = 'monthly';
  int _subscriptionMonths = 1;
  bool _isLoading = false;
  bool _obscurePassword = true;

  @override
  void dispose() {
    _shopNameController.dispose();
    _ownerNameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _createTenant() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);
    try {
      final result = await ApiService.createTenant({
        'shop_name': _shopNameController.text.trim(),
        'owner_name': _ownerNameController.text.trim(),
        'owner_email': _emailController.text.trim(),
        'owner_phone': _phoneController.text.trim(),
        'password': _passwordController.text,
        'plan': _selectedPlan,
        'subscription_months': _subscriptionMonths,
      });

      if (mounted) {
        showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('Tenant Created'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Shop: ${result['shop']['name']}'),
                const SizedBox(height: 8),
                Text('Email: ${result['credentials']['email']}'),
                Text('Password: ${result['credentials']['password']}'),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(color: Colors.orange[50], borderRadius: BorderRadius.circular(8)),
                  child: const Text('Save these credentials! They won\'t be shown again.', style: TextStyle(fontSize: 12)),
                ),
              ],
            ),
            actions: [
              TextButton(onPressed: () { Navigator.of(ctx).pop(); Navigator.of(context).pop(); }, child: const Text('OK')),
            ],
          ),
        );
      }
    } catch (e) {
      if (mounted) showApiError(context, e);
    }
    if (!mounted) return;
    setState(() => _isLoading = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Create Tenant'),
        backgroundColor: AppTheme.primaryColor,
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _sectionHeader('Shop Details'),
              _buildField(_shopNameController, 'Shop Name', Icons.store, required: true),
              _buildField(_ownerNameController, 'Owner Name', Icons.person, required: true),
              _buildField(_emailController, 'Email', Icons.email, keyboardType: TextInputType.emailAddress, required: true),
              _buildField(_phoneController, 'Phone', Icons.phone, keyboardType: TextInputType.phone, required: true),
              _buildPasswordField(),
              const SizedBox(height: 20),
              _sectionHeader('Subscription'),
              const SizedBox(height: 8),
              SearchableDropdown<String>(
                items: const [
                  SearchableDropdownItem(value: 'free', label: 'Free Trial'),
                  SearchableDropdownItem(value: 'monthly', label: 'Monthly'),
                  SearchableDropdownItem(value: 'quarterly', label: 'Quarterly'),
                  SearchableDropdownItem(value: 'yearly', label: 'Yearly'),
                ],
                value: _selectedPlan,
                hint: 'Select plan',
                searchHint: 'Search plans…',
                labelText: 'Plan',
                onChanged: (v) => setState(() => _selectedPlan = v ?? 'monthly'),
              ),
              if (_selectedPlan != 'free') ...[
                const SizedBox(height: 12),
                SearchableDropdown<int>(
                  items: List.generate(
                    12,
                    (i) => SearchableDropdownItem(
                      value: i + 1,
                      label: '${i + 1} month${i > 0 ? 's' : ''}',
                    ),
                  ),
                  value: _subscriptionMonths,
                  hint: 'Duration',
                  searchHint: 'Search duration…',
                  labelText: 'Duration (months)',
                  onChanged: (v) =>
                      setState(() => _subscriptionMonths = v ?? 1),
                ),
              ],
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _createTenant,
                  style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primaryColor, foregroundColor: Colors.white),
                  child: _isLoading
                      ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                      : const Text('Create Tenant', style: TextStyle(fontSize: 16)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _sectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppTheme.primaryColor)),
    );
  }

  Widget _buildField(TextEditingController controller, String label, IconData icon,
      {TextInputType? keyboardType, bool required = false}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextFormField(
        controller: controller,
        keyboardType: keyboardType,
        decoration: InputDecoration(
          labelText: label,
          prefixIcon: Icon(icon),
          border: const OutlineInputBorder(),
        ),
        validator: required ? (v) => v == null || v.trim().isEmpty ? '$label is required' : null : null,
      ),
    );
  }

  Widget _buildPasswordField() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextFormField(
        controller: _passwordController,
        obscureText: _obscurePassword,
        decoration: InputDecoration(
          labelText: 'Password',
          prefixIcon: const Icon(Icons.lock),
          border: const OutlineInputBorder(),
          suffixIcon: IconButton(
            icon: Icon(_obscurePassword ? Icons.visibility : Icons.visibility_off),
            onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
          ),
        ),
        validator: (v) => v == null || v.length < 8 ? 'Password must be at least 8 characters' : null,
      ),
    );
  }
}
