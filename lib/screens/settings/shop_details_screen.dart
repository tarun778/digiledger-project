import 'package:flutter/material.dart';
import '../../utils/errors.dart';
import '../../utils/theme.dart';
import '../../services/api_service.dart';
import '../../providers/auth_provider.dart';
import '../../widgets/ui_kit.dart';
import 'package:provider/provider.dart';

class ShopDetailsScreen extends StatefulWidget {
  const ShopDetailsScreen({super.key});

  @override
  State<ShopDetailsScreen> createState() => _ShopDetailsScreenState();
}

class _ShopDetailsScreenState extends State<ShopDetailsScreen> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nameController;
  late TextEditingController _phoneController;
  late TextEditingController _addressController;
  late TextEditingController _cityController;
  late TextEditingController _stateController;
  late TextEditingController _pincodeController;
  bool _isLoading = true;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController();
    _phoneController = TextEditingController();
    _addressController = TextEditingController();
    _cityController = TextEditingController();
    _stateController = TextEditingController();
    _pincodeController = TextEditingController();
    _loadShop();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _addressController.dispose();
    _cityController.dispose();
    _stateController.dispose();
    _pincodeController.dispose();
    super.dispose();
  }

  Future<void> _loadShop() async {
    try {
      final shop = await ApiService.getShop();
      if (!mounted) return;
      setState(() {
        _nameController.text = shop['name'] ?? '';
        _phoneController.text = shop['phone'] ?? '';
        _addressController.text = shop['address'] ?? '';
        _cityController.text = shop['city'] ?? '';
        _stateController.text = shop['state'] ?? '';
        _pincodeController.text = shop['pincode'] ?? '';
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      if (!mounted) return;
      showApiError(context, e);
    }
  }

  bool get _canEdit => context.read<AuthProvider>().user?.isOwner == true;

  Future<void> _saveShop() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isSaving = true);
    try {
      await ApiService.updateShop({
        'name': _nameController.text.trim(),
        'phone': _phoneController.text.trim(),
        'address': _addressController.text.trim(),
        'city': _cityController.text.trim(),
        'state': _stateController.text.trim(),
        'pincode': _pincodeController.text.trim(),
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Shop details updated'), backgroundColor: AppTheme.successColor),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      setState(() => _isSaving = false);
      if (!mounted) return;
      showApiError(context, e);
    }
  }

  Widget _label(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Text(
        text,
        style: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w700,
          color: AppTheme.textPrimary,
        ),
      ),
    );
  }

  Widget _buildHeroCard() {
    final name = _nameController.text.trim();
    final initial = name.isEmpty ? 'S' : name[0].toUpperCase();

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
      decoration: AppTheme.cardDecoration,
      child: Column(
        children: [
          Container(
            width: 72,
            height: 72,
            decoration: const BoxDecoration(
              color: AppTheme.tintGreenBg,
              shape: BoxShape.circle,
            ),
            child: Center(
              child: name.isEmpty
                  ? const Icon(Icons.store_rounded, size: 32, color: AppTheme.iconGreen)
                  : Text(
                      initial,
                      style: const TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.w800,
                        color: AppTheme.iconGreen,
                      ),
                    ),
            ),
          ),
          if (name.isNotEmpty) ...[
            const SizedBox(height: 12),
            Text(
              name,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: AppTheme.textPrimary,
              ),
            ),
          ],
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      body: Column(
        children: [
          ScreenHeader(
            showBack: true,
            title: 'Shop Details',
            actions: [
              if (_canEdit)
                HeaderIconButton(
                  icon: Icons.save_rounded,
                  color: AppTheme.iconGreen,
                  onTap: _isSaving ? null : _saveShop,
                ),
            ],
          ),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
                    child: Form(
                      key: _formKey,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          _buildHeroCard(),
                          const SizedBox(height: 16),
                          SectionCard(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                _label('Shop Name'),
                                TextFormField(
                                  controller: _nameController,
                                  enabled: _canEdit,
                                  decoration: const InputDecoration(hintText: 'Shop name'),
                                  validator: (v) => v?.isEmpty ?? true ? 'Required' : null,
                                ),
                                const SizedBox(height: 14),
                                _label('Phone Number'),
                                TextFormField(
                                  controller: _phoneController,
                                  enabled: _canEdit,
                                  keyboardType: TextInputType.phone,
                                  decoration: InputDecoration(
                                    hintText: 'Phone number',
                                    prefix: Container(
                                      padding: const EdgeInsets.only(right: 10),
                                      margin: const EdgeInsets.only(right: 10),
                                      decoration: const BoxDecoration(
                                        border: Border(
                                          right: BorderSide(color: AppTheme.borderLight),
                                        ),
                                      ),
                                      child: const Text(
                                        '+91',
                                        style: TextStyle(
                                          fontSize: 14,
                                          fontWeight: FontWeight.w700,
                                          color: AppTheme.textSecondary,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 14),
                                _label('Address'),
                                TextFormField(
                                  controller: _addressController,
                                  enabled: _canEdit,
                                  maxLines: 2,
                                  decoration: const InputDecoration(hintText: 'Shop address'),
                                ),
                                const SizedBox(height: 14),
                                Row(
                                  children: [
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          _label('City'),
                                          TextFormField(
                                            controller: _cityController,
                                            enabled: _canEdit,
                                            decoration: const InputDecoration(hintText: 'City'),
                                          ),
                                        ],
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          _label('State'),
                                          TextFormField(
                                            controller: _stateController,
                                            enabled: _canEdit,
                                            decoration: const InputDecoration(hintText: 'State'),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 14),
                                _label('Pincode'),
                                TextFormField(
                                  controller: _pincodeController,
                                  enabled: _canEdit,
                                  decoration: const InputDecoration(hintText: 'Pincode'),
                                ),
                              ],
                            ),
                          ),
                          if (!_canEdit) ...[
                            const SizedBox(height: 16),
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: AppTheme.tintAmberBg,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: AppTheme.iconAmber.withValues(alpha: 0.35),
                                  width: 0.6,
                                ),
                              ),
                              child: const Row(
                                children: [
                                  Icon(Icons.lock_rounded, color: AppTheme.iconAmber, size: 18),
                                  SizedBox(width: 10),
                                  Expanded(
                                    child: Text(
                                      'Only the shop owner can edit shop details',
                                      style: TextStyle(
                                        color: AppTheme.iconAmber,
                                        fontSize: 12.5,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                          if (_canEdit) ...[
                            const SizedBox(height: 16),
                            PrimaryButton(
                              label: 'Save Changes',
                              loading: _isSaving,
                              onPressed: _saveShop,
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}
