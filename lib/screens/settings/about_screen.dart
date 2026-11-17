import 'package:flutter/material.dart';
import '../../utils/theme.dart';
import '../../widgets/ui_kit.dart';

class AboutScreen extends StatelessWidget {
  const AboutScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      body: Column(
        children: [
          const ScreenHeader(showBack: true, title: 'About'),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 28),
              children: [
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
                  decoration: AppTheme.cardDecoration,
                  child: const Column(
                    children: [
                      _AppIcon(),
                      SizedBox(height: 14),
                      Text(
                        'DigiLedger',
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.w800,
                          color: AppTheme.textPrimary,
                          letterSpacing: -0.3,
                        ),
                      ),
                      SizedBox(height: 4),
                      Text(
                        'Digital Ledger for Shops',
                        style: TextStyle(
                          color: AppTheme.textSecondary,
                          fontSize: 13,
                        ),
                      ),
                      SizedBox(height: 12),
                      _VersionPill(),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                const SectionCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      CardHeader(
                        title: 'About DigiLedger',
                        icon: Icons.info_outline_rounded,
                      ),
                      SizedBox(height: 10),
                      Text(
                        'DigiLedger is a modern digital ledger application designed for small businesses and shop owners. '
                        'Replace your traditional paper-based bookkeeping with a powerful, easy-to-use digital solution.',
                        style: TextStyle(
                          color: AppTheme.textSecondary,
                          fontSize: 13,
                          height: 1.5,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                const SectionCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      CardHeader(
                        title: 'Key Features',
                        icon: Icons.star_outline_rounded,
                      ),
                      SizedBox(height: 12),
                      _Feature(text: 'Multi-tenant shop management'),
                      _Feature(text: 'Transaction tracking with categories'),
                      _Feature(text: 'Credit card bill payment tracking'),
                      _Feature(text: 'Role-based access (Owner, Manager, Staff)'),
                      _Feature(text: 'Daily, monthly, quarterly & yearly reports'),
                      _Feature(text: 'Export data to Excel & PDF'),
                      _Feature(text: 'Profit analytics & dashboard'),
                      _Feature(text: 'Customer management'),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                const SectionCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      CardHeader(
                        title: 'Technology',
                        icon: Icons.memory_rounded,
                      ),
                      SizedBox(height: 8),
                      KeyValueRow(label: 'Backend', value: 'Django REST Framework'),
                      KeyValueRow(label: 'Frontend', value: 'Flutter (Web, Android, iOS)'),
                      KeyValueRow(label: 'Database', value: 'PostgreSQL / SQLite'),
                      KeyValueRow(label: 'Auth', value: 'JWT (JSON Web Tokens)'),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                const Center(
                  child: Text(
                    'Made with ❤ for small businesses',
                    style: TextStyle(color: AppTheme.textSecondary, fontSize: 12),
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

class _AppIcon extends StatelessWidget {
  const _AppIcon();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 84,
      height: 84,
      decoration: BoxDecoration(
        color: Colors.white,
        shape: BoxShape.circle,
        border: Border.all(color: AppTheme.borderLight),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ClipOval(
        child: Image.asset(
          'assets/images/logo_icon.png',
          width: 84,
          height: 84,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => const Icon(
            Icons.account_balance_wallet_rounded,
            size: 40,
            color: AppTheme.primaryColor,
          ),
        ),
      ),
    );
  }
}

class _VersionPill extends StatelessWidget {
  const _VersionPill();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
      decoration: BoxDecoration(
        color: AppTheme.tintGreenBg,
        borderRadius: BorderRadius.circular(999),
      ),
      child: const Text(
        'Version 1.0.0',
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: AppTheme.iconGreen,
          letterSpacing: 0.3,
        ),
      ),
    );
  }
}

class _Feature extends StatelessWidget {
  final String text;

  const _Feature({required this.text});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 9),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.check_circle_rounded, size: 16, color: AppTheme.successColor),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(
                fontSize: 13,
                color: AppTheme.textPrimary,
                height: 1.35,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
