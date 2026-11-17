import 'package:flutter/material.dart';
import '../../utils/theme.dart';
import '../../widgets/ui_kit.dart';

class HelpSupportScreen extends StatelessWidget {
  const HelpSupportScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      body: Column(
        children: [
          const ScreenHeader(showBack: true, title: 'Help & Support'),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 28),
              children: [
                _buildSection(
                  title: 'Getting Started',
                  icon: Icons.rocket_launch_outlined,
                  items: [
                    _buildItem(
                      Icons.login_rounded,
                      'Login',
                      'Use your email and password to login. Contact your shop owner if you don\'t have an account.',
                      AppTheme.iconGreen,
                      AppTheme.tintGreenBg,
                    ),
                    _buildItem(
                      Icons.dashboard_outlined,
                      'Dashboard',
                      'View today\'s summary, monthly stats, and recent transactions at a glance.',
                      AppTheme.iconGreen,
                      AppTheme.tintGreenBg,
                    ),
                    _buildItem(
                      Icons.receipt_long_outlined,
                      'Transactions',
                      'Record all service transactions with category, amount, payment method, and customer details.',
                      AppTheme.iconGreen,
                      AppTheme.tintGreenBg,
                    ),
                    _buildItem(
                      Icons.credit_card_rounded,
                      'CC Bill Payments',
                      'Track credit card bill payments with bank name, card details, and due dates.',
                      AppTheme.iconGreen,
                      AppTheme.tintGreenBg,
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                _buildSection(
                  title: 'Roles & Permissions',
                  icon: Icons.admin_panel_settings_outlined,
                  items: [
                    _buildItem(
                      Icons.admin_panel_settings_outlined,
                      'Owner',
                      'Full access to all features including user management, reports, and settings.',
                      AppTheme.iconBlue,
                      AppTheme.tintBlueBg,
                    ),
                    _buildItem(
                      Icons.manage_accounts_outlined,
                      'Manager',
                      'Can view reports, manage transactions, and CC bills. Cannot manage users.',
                      AppTheme.iconBlue,
                      AppTheme.tintBlueBg,
                    ),
                    _buildItem(
                      Icons.person_outline_rounded,
                      'Staff',
                      'Can only add and view transactions. No access to dashboard, reports, or settings.',
                      AppTheme.iconBlue,
                      AppTheme.tintBlueBg,
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                _buildSection(
                  title: 'Features',
                  icon: Icons.tips_and_updates_outlined,
                  items: [
                    _buildItem(
                      Icons.file_download_outlined,
                      'Export Data',
                      'Download transactions, CC bills, and reports as Excel files from their respective pages.',
                      AppTheme.iconAmber,
                      AppTheme.tintAmberBg,
                    ),
                    _buildItem(
                      Icons.table_chart_outlined,
                      'Table View',
                      'Switch between card view and table view on the transactions page.',
                      AppTheme.iconAmber,
                      AppTheme.tintAmberBg,
                    ),
                    _buildItem(
                      Icons.edit_outlined,
                      'Edit Transactions',
                      'Tap any transaction to view details. Owners and managers can edit or delete.',
                      AppTheme.iconAmber,
                      AppTheme.tintAmberBg,
                    ),
                    _buildItem(
                      Icons.people_outline_rounded,
                      'User Management',
                      'Add staff members, change their roles, or reset passwords from the Users page.',
                      AppTheme.iconAmber,
                      AppTheme.tintAmberBg,
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                SectionCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const CardHeader(
                        title: 'Contact Support',
                        icon: Icons.support_agent_rounded,
                      ),
                      const SizedBox(height: 12),
                      _buildContactRow(
                        Icons.mail_outline_rounded,
                        'Email',
                        'support@digiledger.com',
                        AppTheme.iconGreen,
                        AppTheme.tintGreenBg,
                      ),
                      _buildContactRow(
                        Icons.phone_outlined,
                        'Phone',
                        '+91 98765 43210',
                        AppTheme.iconBlue,
                        AppTheme.tintBlueBg,
                      ),
                      _buildContactRow(
                        Icons.language_rounded,
                        'Website',
                        'www.digiledger.com',
                        AppTheme.iconPurple,
                        AppTheme.tintPurpleBg,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSection({
    required String title,
    required IconData icon,
    required List<Widget> items,
  }) {
    return SectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CardHeader(title: title, icon: icon),
          const SizedBox(height: 6),
          ...items,
        ],
      ),
    );
  }

  Widget _buildItem(
    IconData icon,
    String title,
    String desc,
    Color color,
    Color background,
  ) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          IconTile(icon: icon, color: color, background: background, size: 34),
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
                const SizedBox(height: 2),
                Text(
                  desc,
                  style: const TextStyle(
                    color: AppTheme.textSecondary,
                    fontSize: 11.5,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildContactRow(
    IconData icon,
    String label,
    String value,
    Color color,
    Color background,
  ) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          IconTile(icon: icon, color: color, background: background, size: 34),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    color: AppTheme.textSecondary,
                    fontSize: 11,
                  ),
                ),
                const SizedBox(height: 1),
                Text(
                  value,
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                    color: AppTheme.textPrimary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
