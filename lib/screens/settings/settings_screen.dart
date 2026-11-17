import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../utils/theme.dart';
import '../../utils/download_helper.dart';
import '../../utils/errors.dart';
import '../../providers/auth_provider.dart';
import '../../services/api_service.dart';
import '../../widgets/ui_kit.dart';
import '../staff/staff_screen.dart';
import '../banking/bank_accounts_screen.dart';
import 'edit_profile_screen.dart';
import 'shop_details_screen.dart';
import 'manage_categories_screen.dart';
import 'manage_descriptions_screen.dart';
import 'change_password_screen.dart';
import 'help_support_screen.dart';
import 'about_screen.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      body: Consumer<AuthProvider>(
        builder: (context, auth, _) {
          return Column(
            children: [
              const ScreenHeader(title: 'Settings'),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(16, 6, 16, 28),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildProfileCard(auth),
                      const SizedBox(height: 18),
                      _buildSection('Account', [
                        _buildMenuItem(
                          icon: Icons.person_outline_rounded,
                          title: 'Edit Profile',
                          subtitle: 'Update your name, email, phone',
                          color: AppTheme.iconGreen,
                          background: AppTheme.tintGreenBg,
                          onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const EditProfileScreen())),
                        ),
                        _buildMenuItem(
                          icon: Icons.lock_outline_rounded,
                          title: 'Change Password',
                          subtitle: 'Update your account password',
                          color: AppTheme.iconBlue,
                          background: AppTheme.tintBlueBg,
                          onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ChangePasswordScreen())),
                        ),
                      ]),
                      const SizedBox(height: 16),
                      _buildSection('Shop', [
                        _buildMenuItem(
                          icon: Icons.store_outlined,
                          title: 'Shop Details',
                          subtitle: 'Update shop name, address, phone',
                          color: AppTheme.iconAmber,
                          background: AppTheme.tintAmberBg,
                          onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ShopDetailsScreen())),
                        ),
                        _buildMenuItem(
                          icon: Icons.category_outlined,
                          title: 'Manage Categories',
                          subtitle: 'Add or remove service categories',
                          color: AppTheme.iconPurple,
                          background: AppTheme.tintPurpleBg,
                          onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ManageCategoriesScreen())),
                        ),
                        _buildMenuItem(
                          icon: Icons.account_balance_outlined,
                          title: 'Bank Accounts',
                          subtitle: 'Add or manage your bank accounts',
                          color: AppTheme.iconBlue,
                          background: AppTheme.tintBlueBg,
                          onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const BankAccountsScreen())),
                        ),
                        _buildMenuItem(
                          icon: Icons.description_outlined,
                          title: 'Manage Descriptions',
                          subtitle: 'Add or remove description suggestions',
                          color: AppTheme.iconGreen,
                          background: AppTheme.tintGreenBg,
                          onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ManageDescriptionsScreen())),
                        ),
                        if (auth.user?.isOwner == true)
                          _buildMenuItem(
                            icon: Icons.people_outline_rounded,
                            title: 'User Management',
                            subtitle: 'Add or remove staff members',
                            color: AppTheme.iconBlue,
                            background: AppTheme.tintBlueBg,
                            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const StaffScreen())),
                          ),
                      ]),
                      const SizedBox(height: 16),
                      _buildSection('Data & Support', [
                        _buildMenuItem(
                          icon: Icons.backup_outlined,
                          title: 'Backup Data',
                          subtitle: 'Export all your data',
                          color: AppTheme.iconAmber,
                          background: AppTheme.tintAmberBg,
                          onTap: () => _showBackupDialog(context),
                        ),
                        _buildMenuItem(
                          icon: Icons.help_outline_rounded,
                          title: 'Help & Support',
                          subtitle: 'Get help with using the app',
                          color: AppTheme.iconPurple,
                          background: AppTheme.tintPurpleBg,
                          onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const HelpSupportScreen())),
                        ),
                        _buildMenuItem(
                          icon: Icons.info_outline_rounded,
                          title: 'About',
                          subtitle: 'Version 1.0.0',
                          color: AppTheme.iconGreen,
                          background: AppTheme.tintGreenBg,
                          onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AboutScreen())),
                        ),
                      ]),
                      const SizedBox(height: 18),
                      _buildLogoutTile(context, auth),
                    ],
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildProfileCard(AuthProvider auth) {
    final name = auth.user?.name ?? '';
    final initial = name.isEmpty ? 'U' : name[0].toUpperCase();
    final role = (auth.user?.role ?? '').toUpperCase();

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: AppTheme.cardDecoration,
      child: Row(
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: const BoxDecoration(
              color: AppTheme.tintGreenBg,
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(
                initial,
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.iconGreen,
                ),
              ),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.textPrimary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  auth.user?.email ?? '',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppTheme.textSecondary,
                  ),
                ),
                if (role.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
                    decoration: BoxDecoration(
                      color: AppTheme.tintGreenBg,
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      role,
                      style: const TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.6,
                        color: AppTheme.iconGreen,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSection(String title, List<Widget> children) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 8),
          child: Text(
            title.toUpperCase(),
            style: const TextStyle(
              fontWeight: FontWeight.w700,
              color: AppTheme.textSecondary,
              fontSize: 12,
              letterSpacing: 0.6,
            ),
          ),
        ),
        Container(
          decoration: AppTheme.cardDecoration,
          child: Column(children: children),
        ),
      ],
    );
  }

  Widget _buildMenuItem({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
    Color color = AppTheme.iconGreen,
    Color background = AppTheme.tintGreenBg,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
          child: Row(
            children: [
              IconTile(icon: icon, color: color, background: background, size: 36),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 13.5,
                        color: AppTheme.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 1),
                    Text(
                      subtitle,
                      style: const TextStyle(
                        fontSize: 11,
                        color: AppTheme.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              const Icon(
                Icons.chevron_right_rounded,
                color: AppTheme.textMuted,
                size: 20,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLogoutTile(BuildContext context, AuthProvider auth) {
    return Container(
      decoration: AppTheme.cardDecoration,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: () => _confirmLogout(context, auth),
          child: const Padding(
            padding: EdgeInsets.symmetric(horizontal: 14, vertical: 13),
            child: Row(
              children: [
                IconTile(
                  icon: Icons.logout_rounded,
                  color: AppTheme.iconRed,
                  background: AppTheme.tintRedBg,
                  size: 36,
                ),
                SizedBox(width: 12),
                Text(
                  'Logout',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 13.5,
                    color: AppTheme.errorColor,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _confirmLogout(BuildContext context, AuthProvider auth) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Logout'),
        content: const Text('Are you sure you want to logout?'),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              auth.logout();
            },
            style: TextButton.styleFrom(foregroundColor: AppTheme.errorColor),
            child: const Text('Logout'),
          ),
        ],
      ),
    );
  }

  void _showBackupDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Backup Data'),
        content: const Text('Export all your transactions and CC bill payments as Excel files.'),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              _exportBackup(context, 'transactions');
            },
            child: const Text('Transactions'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              _exportBackup(context, 'cc_bills');
            },
            child: const Text('CC Bills'),
          ),
        ],
      ),
    );
  }

  Future<void> _exportBackup(BuildContext context, String kind) async {
    final messenger = ScaffoldMessenger.maybeOf(context);
    try {
      final response = kind == 'transactions'
          ? await ApiService.exportTransactions()
          : await ApiService.exportCCBills();
      final disposition = response.headers['content-disposition'] ?? '';
      var filename = disposition
          .replaceAll('attachment; filename=', '')
          .replaceAll('"', '')
          .trim();
      if (filename.isEmpty) filename = 'backup_$kind.xlsx';
      final ok = DownloadHelper.downloadBytes(
        response.bodyBytes,
        filename,
        mimeType: 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
      );
      messenger
        ?..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: Text(ok ? 'Downloaded: $filename' : 'Export is available on the web version of DigiLedger'),
            backgroundColor: ok ? AppTheme.successColor : AppTheme.errorColor,
          ),
        );
    } catch (e) {
      messenger
        ?..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(content: Text(apiErrorText(e)), backgroundColor: AppTheme.errorColor),
        );
    }
  }
}
