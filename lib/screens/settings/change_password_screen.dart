import 'package:flutter/material.dart';
import '../../utils/errors.dart';
import '../../utils/theme.dart';
import '../../services/api_service.dart';
import '../../widgets/ui_kit.dart';

class ChangePasswordScreen extends StatefulWidget {
  const ChangePasswordScreen({super.key});

  @override
  State<ChangePasswordScreen> createState() => _ChangePasswordScreenState();
}

class _ChangePasswordScreenState extends State<ChangePasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  final _oldPasswordController = TextEditingController();
  final _newPasswordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  bool _isSaving = false;
  bool _showOld = false;
  bool _showNew = false;

  @override
  void dispose() {
    _oldPasswordController.dispose();
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _changePassword() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isSaving = true);
    try {
      await ApiService.changePassword(
        _oldPasswordController.text,
        _newPasswordController.text,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Password changed successfully'), backgroundColor: AppTheme.successColor),
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      body: Column(
        children: [
          const ScreenHeader(showBack: true, title: 'Change Password'),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(vertical: 22),
                      decoration: AppTheme.cardDecoration,
                      child: Column(
                        children: [
                          Container(
                            width: 72,
                            height: 72,
                            decoration: const BoxDecoration(
                              color: AppTheme.tintBlueBg,
                              shape: BoxShape.circle,
                            ),
                            child: const Center(
                              child: Icon(
                                Icons.lock_outline_rounded,
                                size: 34,
                                color: AppTheme.iconBlue,
                              ),
                            ),
                          ),
                          const SizedBox(height: 12),
                          const Text(
                            'Keep your account secure',
                            style: TextStyle(
                              fontSize: 13,
                              color: AppTheme.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    SectionCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          _label('Current Password'),
                          TextFormField(
                            controller: _oldPasswordController,
                            obscureText: !_showOld,
                            decoration: InputDecoration(
                              hintText: 'Enter current password',
                              prefixIcon: const Icon(Icons.lock_rounded, size: 20),
                              suffixIcon: IconButton(
                                icon: Icon(
                                  _showOld ? Icons.visibility_rounded : Icons.visibility_off_rounded,
                                  size: 20,
                                ),
                                onPressed: () => setState(() => _showOld = !_showOld),
                              ),
                            ),
                            validator: (v) => v?.isEmpty ?? true ? 'Required' : null,
                          ),
                          const SizedBox(height: 14),
                          _label('New Password'),
                          TextFormField(
                            controller: _newPasswordController,
                            obscureText: !_showNew,
                            decoration: InputDecoration(
                              hintText: 'Enter new password',
                              prefixIcon: const Icon(Icons.lock_reset_rounded, size: 20),
                              suffixIcon: IconButton(
                                icon: Icon(
                                  _showNew ? Icons.visibility_rounded : Icons.visibility_off_rounded,
                                  size: 20,
                                ),
                                onPressed: () => setState(() => _showNew = !_showNew),
                              ),
                            ),
                            validator: (v) {
                              if (v?.isEmpty ?? true) return 'Required';
                              if (v!.length < 8) return 'Must be at least 8 characters';
                              return null;
                            },
                          ),
                          const SizedBox(height: 14),
                          _label('Confirm New Password'),
                          TextFormField(
                            controller: _confirmPasswordController,
                            obscureText: true,
                            decoration: const InputDecoration(
                              hintText: 'Re-enter new password',
                              prefixIcon: Icon(Icons.lock_reset_rounded, size: 20),
                            ),
                            validator: (v) {
                              if (v != _newPasswordController.text) return 'Passwords do not match';
                              return null;
                            },
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    PrimaryButton(
                      label: 'Update Password',
                      loading: _isSaving,
                      onPressed: _changePassword,
                    ),
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
