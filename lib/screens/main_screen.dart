import 'package:flutter/material.dart';
import '../../utils/theme.dart';
import '../../providers/auth_provider.dart';
import 'package:provider/provider.dart';
import 'dashboard/dashboard_screen.dart';
import 'transactions/transaction_list_screen.dart';
import 'cc_bills/cc_bill_list_screen.dart';
import 'reports/reports_screen.dart';
import 'settings/settings_screen.dart';
import 'staff/staff_screen.dart';
import 'credits/pending_payments_screen.dart';
import 'admin/admin_dashboard_screen.dart';
import 'banking/bank_accounts_screen.dart';
import 'settings/edit_profile_screen.dart';
import 'settings/help_support_screen.dart';

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _selectedIndex = 0;
  bool _sidebarOpen = true;
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  final GlobalKey<NavigatorState> _contentNavKey = GlobalKey<NavigatorState>();
  final ValueNotifier<int> _tabIndex = ValueNotifier<int>(0);

  List<_NavItem> _navItems = [];
  List<Widget> _screens = [];
  bool _initialized = false;

  @override
  void dispose() {
    _tabIndex.dispose();
    super.dispose();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_initialized) {
      _initialized = true;
      if (MediaQuery.of(context).size.width < 900) {
        _sidebarOpen = false;
      }
      _buildNavigation();
    }
  }

  void _buildNavigation() {
    final auth = context.read<AuthProvider>();
    final isStaff = auth.user?.role == 'staff';
    final isSuperuser = auth.user?.isSuperuser == true;

    if (isStaff) {
      _navItems = [
        const _NavItem(Icons.receipt_long_rounded, 'Transactions'),
        const _NavItem(Icons.credit_card_rounded, 'CC Bills'),
      ];
      _screens = [
        const TransactionListScreen(),
        const CCBillListScreen(),
      ];
    } else if (isSuperuser) {
      _navItems = [
        const _NavItem(Icons.admin_panel_settings, 'Admin'),
        const _NavItem(Icons.dashboard_rounded, 'Dashboard'),
        const _NavItem(Icons.receipt_long_rounded, 'Transactions'),
        const _NavItem(Icons.credit_card_rounded, 'CC Bills'),
        const _NavItem(Icons.pending_actions_rounded, 'Pending'),
        const _NavItem(Icons.account_balance_rounded, 'Bank Accounts'),
        const _NavItem(Icons.analytics_rounded, 'Reports'),
        const _NavItem(Icons.people_rounded, 'Users'),
        const _NavItem(Icons.settings_rounded, 'Settings'),
      ];
      _screens = [
        const AdminDashboardScreen(),
        DashboardScreen(
          onMenuTap: _toggleSidebar,
          onNavigateTab: _navigateToTab,
        ),
        const TransactionListScreen(),
        const CCBillListScreen(),
        const PendingPaymentsScreen(),
        const BankAccountsScreen(),
        const ReportsScreen(),
        const StaffScreen(),
        const SettingsScreen(),
      ];
    } else {
      _navItems = [
        const _NavItem(Icons.dashboard_rounded, 'Dashboard'),
        const _NavItem(Icons.receipt_long_rounded, 'Transactions'),
        const _NavItem(Icons.credit_card_rounded, 'CC Bills'),
        const _NavItem(Icons.pending_actions_rounded, 'Pending'),
        const _NavItem(Icons.account_balance_rounded, 'Bank Accounts'),
        const _NavItem(Icons.analytics_rounded, 'Reports'),
        const _NavItem(Icons.people_rounded, 'Users'),
        const _NavItem(Icons.settings_rounded, 'Settings'),
      ];
      _screens = [
        DashboardScreen(
          onMenuTap: _toggleSidebar,
          onNavigateTab: _navigateToTab,
        ),
        const TransactionListScreen(),
        const CCBillListScreen(),
        const PendingPaymentsScreen(),
        const BankAccountsScreen(),
        const ReportsScreen(),
        const StaffScreen(),
        const SettingsScreen(),
      ];
    }
    if (_selectedIndex >= _screens.length) _selectedIndex = 0;
    _tabIndex.value = _selectedIndex;
  }

  void _navigateToTab(String label) {
    final index = _navItems.indexWhere((item) => item.label == label);
    if (index >= 0) _onNavTap(index);
  }

  void _toggleSidebar() {
    if (MediaQuery.of(context).size.width < 900) {
      _scaffoldKey.currentState?.openDrawer();
    } else {
      setState(() => _sidebarOpen = !_sidebarOpen);
    }
  }

  void _closeDrawer() {
    if (_scaffoldKey.currentState?.isDrawerOpen ?? false) {
      Navigator.of(context).maybePop();
    }
  }

  void _openContentScreen(Widget screen) {
    _closeDrawer();
    _contentNavKey.currentState?.push(
      MaterialPageRoute(builder: (_) => screen),
    );
  }

  void _onNavTap(int index) {
    if (index == _selectedIndex) {
      // Re-tapping current tab: pop any pushed screen (New…) back to root
      _contentNavKey.currentState?.popUntil((route) => route.isFirst);
      return;
    }
    setState(() => _selectedIndex = index);
    _tabIndex.value = index;
    // Reveal the (already rebuilt) root screen for the new tab
    _contentNavKey.currentState?.popUntil((route) => route.isFirst);
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isMobile = screenWidth < 900;

    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: AppTheme.backgroundColor,
      drawer: isMobile ? _buildDrawer() : null,
      body: Column(
        children: [
          if (isMobile) _buildTopBar(),
          Expanded(
            child: Row(
              children: [
                if (!isMobile) _buildDesktopSidebar(),
                Expanded(
                  // Nested navigator: pushed routes (New Transaction, New CC
                  // Bill, details, settings sub-pages, etc.) open inside the
                  // content area so the sidebar stays visible. Keyed by index
                  // so switching tabs resets to that tab's root screen.
                  child: Navigator(
                    key: _contentNavKey,
                    onGenerateRoute: (settings) {
                      return MaterialPageRoute(
                        settings: settings,
                        builder: (_) => ValueListenableBuilder<int>(
                          valueListenable: _tabIndex,
                          builder: (_, index, __) => _screens[index],
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      bottomNavigationBar: isMobile ? _buildBottomNav() : null,
    );
  }

  String get _initials {
    final name = (context.read<AuthProvider>().user?.name ?? '').trim();
    if (name.isEmpty) return 'U';
    return name[0].toUpperCase();
  }

  Widget _buildTopBar() {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(color: Colors.black12, blurRadius: 8, offset: Offset(0, 2)),
        ],
      ),
      child: SafeArea(
        bottom: false,
        child: SizedBox(
          height: 54,
          child: Row(
            children: [
              IconButton(
                onPressed: () => _scaffoldKey.currentState?.openDrawer(),
                icon: const Icon(Icons.menu_rounded,
                    size: 24, color: AppTheme.textPrimary),
              ),
              Expanded(
                child: Center(
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(9),
                          border: Border.all(color: AppTheme.borderLight),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.06),
                              blurRadius: 4,
                              offset: const Offset(0, 1),
                            ),
                          ],
                        ),
                        child: Image.asset(
                          'assets/images/logo_icon.png',
                          width: 24,
                          height: 24,
                          fit: BoxFit.contain,
                          errorBuilder: (_, __, ___) => const Icon(
                            Icons.account_balance_wallet_rounded,
                            size: 22,
                            color: AppTheme.primaryColor,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      const Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'DigiLedger',
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w800,
                              color: AppTheme.textPrimary,
                              letterSpacing: -0.2,
                            ),
                          ),
                          Text(
                            'Smart Finance Management',
                            style: TextStyle(
                              fontSize: 9,
                              color: AppTheme.textMuted,
                              letterSpacing: 0.2,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.only(right: 8),
                child: PopupMenuButton<String>(
                  tooltip: 'Account menu',
                  onSelected: (value) {
                    if (value == 'profile') {
                      _openContentScreen(const EditProfileScreen());
                    } else if (value == 'settings') {
                      final i = _navItems
                          .indexWhere((n) => n.label == 'Settings');
                      if (i >= 0) _onNavTap(i);
                    } else if (value == 'logout') {
                      context.read<AuthProvider>().logout();
                    }
                  },
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                  color: Colors.white,
                  elevation: 10,
                  padding: const EdgeInsets.symmetric(horizontal: 6),
                  itemBuilder: (_) => [
                    const PopupMenuItem(
                      value: 'profile',
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.person_outline_rounded,
                              size: 18, color: AppTheme.textSecondary),
                          SizedBox(width: 10),
                          Text('Profile',
                              style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w500,
                                  color: AppTheme.textPrimary)),
                        ],
                      ),
                    ),
                    const PopupMenuItem(
                      value: 'settings',
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.settings_outlined,
                              size: 18, color: AppTheme.textSecondary),
                          SizedBox(width: 10),
                          Text('Settings',
                              style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w500,
                                  color: AppTheme.textPrimary)),
                        ],
                      ),
                    ),
                    const PopupMenuDivider(height: 1),
                    const PopupMenuItem(
                      value: 'logout',
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.logout_rounded,
                              size: 18, color: AppTheme.errorColor),
                          SizedBox(width: 10),
                          Text('Logout',
                              style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  color: AppTheme.errorColor)),
                        ],
                      ),
                    ),
                  ],
                  child: CircleAvatar(
                    radius: 15,
                    backgroundColor:
                        AppTheme.primaryColor.withValues(alpha: 0.12),
                    child: Text(
                      _initials,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: AppTheme.primaryColor,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDesktopSidebar() {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      width: _sidebarOpen ? 220 : 76,
      decoration: const BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(color: Colors.black12, blurRadius: 6, offset: Offset(2, 0)),
        ],
      ),
      child: Column(
        children: [
          // Logo
          SizedBox(
            height: 60,
            child: Stack(
              children: [
                Positioned.fill(
                  child: Padding(
                    padding: EdgeInsets.only(left: 14, right: _sidebarOpen ? 36 : 8),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(5),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(9),
                            border: Border.all(color: AppTheme.borderLight),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.06),
                                blurRadius: 4,
                                offset: const Offset(0, 1),
                              ),
                            ],
                          ),
                          child: Image.asset(
                            'assets/images/logo_icon.png',
                            width: 22,
                            height: 22,
                            fit: BoxFit.contain,
                            errorBuilder: (_, __, ___) => const Icon(
                              Icons.account_balance_wallet_rounded,
                              size: 20,
                              color: AppTheme.primaryColor,
                            ),
                          ),
                        ),
                        if (_sidebarOpen) ...[
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'DigiLedger',
                                  style: TextStyle(
                                    color: AppTheme.primaryColor,
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                                Text(
                                  'Smart Finance Management',
                                  style: TextStyle(
                                    color: AppTheme.textSecondary.withValues(alpha: 0.6),
                                    fontSize: 9,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
                Positioned(
                  right: 4,
                  top: 0,
                  bottom: 0,
                  child: Center(
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: _toggleSidebar,
                      child: Padding(
                        padding: const EdgeInsets.all(6),
                        child: Icon(
                          _sidebarOpen ? Icons.chevron_left_rounded : Icons.chevron_right_rounded,
                          color: AppTheme.textSecondary,
                          size: 18,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const Divider(color: AppTheme.borderLight, height: 1),

          // User info
          if (_sidebarOpen)
            Container(
              margin: const EdgeInsets.fromLTRB(10, 10, 10, 4),
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppTheme.primaryColor.withValues(alpha: 0.04),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 16,
                    backgroundColor: AppTheme.primaryColor.withValues(alpha: 0.12),
                    child: const Icon(Icons.person, color: AppTheme.primaryColor, size: 18),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Consumer<AuthProvider>(
                          builder: (_, auth, __) => Text(
                            auth.user?.name ?? 'User',
                            style: const TextStyle(
                              color: AppTheme.textPrimary,
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        Consumer<AuthProvider>(
                          builder: (_, auth, __) => Text(
                            (auth.user?.role ?? 'staff').toUpperCase(),
                            style: const TextStyle(
                              color: AppTheme.textSecondary,
                              fontSize: 10,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

          const SizedBox(height: 6),

          // Nav items
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              itemCount: _navItems.length,
              itemBuilder: (context, index) {
                final item = _navItems[index];
                final isSelected = _selectedIndex == index;
                return Padding(
                  padding: const EdgeInsets.only(bottom: 2),
                  child: Material(
                    color: Colors.transparent,
                    borderRadius: BorderRadius.circular(8),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(8),
                      onTap: () => _onNavTap(index),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 150),
                        padding: EdgeInsets.symmetric(
                          horizontal: _sidebarOpen ? 12 : 0,
                          vertical: 10,
                        ),
                        decoration: BoxDecoration(
                          color: isSelected
                              ? AppTheme.primaryColor.withValues(alpha: 0.08)
                              : Colors.transparent,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          mainAxisAlignment: _sidebarOpen ? MainAxisAlignment.start : MainAxisAlignment.center,
                          children: [
                            Icon(
                              item.icon,
                              size: 19,
                              color: isSelected ? AppTheme.primaryColor : AppTheme.textSecondary,
                            ),
                            if (_sidebarOpen) ...[
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  item.label,
                                  style: TextStyle(
                                    color: isSelected ? AppTheme.primaryColor : AppTheme.textSecondary,
                                    fontSize: 13,
                                    fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),

          if (_sidebarOpen)
            Padding(
              padding: const EdgeInsets.fromLTRB(10, 0, 10, 8),
              child: Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: const Color(0xFFE8F5E9),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: const Color(0xFF2E7D32).withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(Icons.bar_chart_rounded, size: 20, color: Color(0xFF2E7D32)),
                    ),
                    const SizedBox(height: 10),
                    const Text(
                      'Keep your business finances organized',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF1B5E20),
                        height: 1.3,
                      ),
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'Simple. Secure. Smart.',
                      style: TextStyle(
                        fontSize: 11,
                        color: Color(0xFF66BB6A),
                      ),
                    ),
                  ],
                ),
              ),
            ),

          // Logout
          Padding(
            padding: const EdgeInsets.all(10),
            child: Material(
              color: Colors.transparent,
              borderRadius: BorderRadius.circular(8),
              child: InkWell(
                borderRadius: BorderRadius.circular(8),
                onTap: () => context.read<AuthProvider>().logout(),
                child: Container(
                  padding: EdgeInsets.symmetric(
                    horizontal: _sidebarOpen ? 12 : 0,
                    vertical: 10,
                  ),
                  child: Row(
                    mainAxisAlignment: _sidebarOpen ? MainAxisAlignment.start : MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.logout_rounded, size: 19, color: AppTheme.errorColor),
                      if (_sidebarOpen) ...[
                        const SizedBox(width: 10),
                        const Text(
                          'Logout',
                          style: TextStyle(color: AppTheme.errorColor, fontSize: 13),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  List<int> _bottomIndices() {
    const preferred = ['Dashboard', 'Transactions', 'CC Bills', 'Settings'];
    final out = <int>[];
    for (final label in preferred) {
      final i = _navItems.indexWhere((n) => n.label == label);
      if (i >= 0) out.add(i);
    }
    if (out.isEmpty) {
      for (var i = 0; i < _navItems.length && out.length < 4; i++) {
        out.add(i);
      }
    }
    return out;
  }

  Widget _buildBottomNav() {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(color: Colors.black12, blurRadius: 10, offset: Offset(0, -2)),
        ],
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: 62,
          child: Row(
            children: [
              for (final i in _bottomIndices())
                Expanded(
                  child: _buildTabButton(
                    icon: _navItems[i].icon,
                    label: _navItems[i].label,
                    isSelected: _selectedIndex == i,
                    onTap: () => _onNavTap(i),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTabButton({
    required IconData icon,
    required String label,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 5),
            decoration: BoxDecoration(
              color: isSelected
                  ? AppTheme.primaryColor.withValues(alpha: 0.12)
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(999),
            ),
            child: Icon(
              icon,
              size: 20,
              color: isSelected ? AppTheme.primaryColor : AppTheme.textSecondary,
            ),
          ),
          const SizedBox(height: 4),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              label,
              style: TextStyle(
                fontSize: 11,
                color: isSelected ? AppTheme.primaryColor : AppTheme.textSecondary,
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDrawer() {
    final user = context.read<AuthProvider>().user;
    final name = (user?.name ?? 'User').trim();
    final email = user?.email ?? '';
    final initials = name.isEmpty ? 'U' : name[0].toUpperCase();

    return Drawer(
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.horizontal(right: Radius.circular(22)),
      ),
      child: SafeArea(
        child: Column(
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(16, 20, 16, 18),
              decoration: const BoxDecoration(
                color: AppTheme.primaryColor,
                borderRadius: BorderRadius.vertical(bottom: Radius.circular(24)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(2),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white54, width: 2),
                        ),
                        child: CircleAvatar(
                          radius: 24,
                          backgroundColor: Colors.white.withValues(alpha: 0.18),
                          child: Text(
                            initials,
                            style: const TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.w700,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
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
                                color: Colors.white,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              email,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.white.withValues(alpha: 0.8),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  Material(
                    color: Colors.white.withValues(alpha: 0.18),
                    borderRadius: BorderRadius.circular(999),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(999),
                      onTap: () => _openContentScreen(const EditProfileScreen()),
                      child: const Padding(
                        padding:
                            EdgeInsets.symmetric(horizontal: 16, vertical: 9),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.person_outline_rounded,
                                size: 16, color: Colors.white),
                            SizedBox(width: 8),
                            Text(
                              'View Profile',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: Colors.white,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(vertical: 8),
                children: [
                  for (var i = 0; i < _navItems.length; i++)
                    _buildDrawerRow(i),
                  const Divider(
                    color: AppTheme.borderLight,
                    height: 1,
                    indent: 16,
                    endIndent: 16,
                  ),
                  _buildDrawerAction(
                    icon: Icons.person_outline_rounded,
                    label: 'Edit Profile',
                    onTap: () => _openContentScreen(const EditProfileScreen()),
                  ),
                  _buildDrawerAction(
                    icon: Icons.help_outline_rounded,
                    label: 'Help & Support',
                    onTap: () => _openContentScreen(const HelpSupportScreen()),
                  ),
                  const Divider(
                    color: AppTheme.borderLight,
                    height: 1,
                    indent: 16,
                    endIndent: 16,
                  ),
                  _buildDrawerAction(
                    icon: Icons.logout_rounded,
                    label: 'Logout',
                    color: AppTheme.errorColor,
                    onTap: () {
                      _closeDrawer();
                      context.read<AuthProvider>().logout();
                    },
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDrawerRow(int index) {
    final item = _navItems[index];
    final isSelected = _selectedIndex == index;
    return ListTile(
      dense: true,
      selected: isSelected,
      selectedTileColor: AppTheme.primaryColor.withValues(alpha: 0.07),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16),
      leading: Icon(
        item.icon,
        size: 20,
        color: isSelected ? AppTheme.primaryColor : AppTheme.textSecondary,
      ),
      title: Text(
        item.label,
        style: TextStyle(
          fontSize: 14,
          fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
          color: isSelected ? AppTheme.primaryColor : AppTheme.textPrimary,
        ),
      ),
      trailing: isSelected
          ? const Icon(Icons.check_circle_rounded,
              size: 16, color: AppTheme.primaryColor)
          : null,
      onTap: () {
        _closeDrawer();
        _onNavTap(index);
      },
    );
  }

  Widget _buildDrawerAction({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    Color? color,
  }) {
    return ListTile(
      dense: true,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16),
      leading: Icon(icon, size: 20, color: color ?? AppTheme.textSecondary),
      title: Text(
        label,
        style: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w500,
          color: color ?? AppTheme.textPrimary,
        ),
      ),
      onTap: onTap,
    );
  }
}

class _NavItem {
  final IconData icon;
  final String label;
  const _NavItem(this.icon, this.label);
}
