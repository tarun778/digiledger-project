import 'package:flutter/material.dart';
import '../../utils/errors.dart';
import '../../utils/theme.dart';
import '../../services/api_service.dart';
import '../../models/category.dart';
import '../../widgets/ui_kit.dart';

class ManageCategoriesScreen extends StatefulWidget {
  const ManageCategoriesScreen({super.key});

  @override
  State<ManageCategoriesScreen> createState() => _ManageCategoriesScreenState();
}

class _ManageCategoriesScreenState extends State<ManageCategoriesScreen> {
  List<Category> _categories = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadCategories();
  }

  Future<void> _loadCategories() async {
    setState(() => _isLoading = true);
    try {
      final categories = await ApiService.getCategories();
      if (!mounted) return;
      setState(() {
        _categories = categories;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      if (!mounted) return;
      showApiError(context, e);
    }
  }

  void _showAddEditDialog({Category? category}) {
    final nameController = TextEditingController(text: category?.name ?? '');
    final iconController = TextEditingController(text: category?.icon ?? '📁');
    var type = category?.categoryType ?? 'service';

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: Text(category == null ? 'Add Category' : 'Edit Category'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                decoration: const InputDecoration(labelText: 'Name', hintText: 'e.g., Bus Ticket'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: iconController,
                decoration: const InputDecoration(labelText: 'Icon (emoji)', hintText: 'e.g., 🚌'),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  ChoiceChip(
                    label: const Text('Service'),
                    selected: type == 'service',
                    onSelected: (_) => setDialogState(() => type = 'service'),
                  ),
                  const SizedBox(width: 8),
                  ChoiceChip(
                    label: const Text('Credit Card Bill'),
                    selected: type == 'cc_bill',
                    onSelected: (_) => setDialogState(() => type = 'cc_bill'),
                  ),
                ],
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
            TextButton(
              onPressed: () async {
                if (nameController.text.trim().isEmpty) {
                  ScaffoldMessenger.maybeOf(ctx)?.showSnackBar(
                    const SnackBar(content: Text('Enter a category name')),
                  );
                  return;
                }
                try {
                  if (category == null) {
                    await ApiService.createCategory({
                      'name': nameController.text.trim(),
                      'icon': iconController.text.trim(),
                      'category_type': type,
                    });
                  } else {
                    await ApiService.updateCategory(category.id, {
                      'name': nameController.text.trim(),
                      'icon': iconController.text.trim(),
                      'category_type': type,
                    });
                  }
                  if (!ctx.mounted) return;
                  Navigator.pop(ctx);
                  if (!mounted) return;
                  _loadCategories();
                } catch (e) {
                  if (!mounted) return;
                  showApiError(context, e);
                }
              },
              child: Text(category == null ? 'Add' : 'Save'),
            ),
          ],
        ),
      ),
    );
  }

  void _confirmDelete(Category category) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Category'),
        content: Text('Delete "${category.name}"? Transactions using this category will keep their data.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          TextButton(
            onPressed: () async {
              try {
                await ApiService.deleteCategory(category.id);
                if (!ctx.mounted) return;
                Navigator.pop(ctx);
                if (!mounted) return;
                _loadCategories();
              } catch (e) {
                if (!mounted) return;
                showApiError(context, e);
              }
            },
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  Future<void> _seedCategories() async {
    try {
      await ApiService.seedCategories();
      if (!mounted) return;
      _loadCategories();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Default categories added!'), backgroundColor: AppTheme.successColor),
      );
    } catch (e) {
      if (!mounted) return;
      showApiError(context, e);
    }
  }

  IconData _typeIcon(String type) =>
      type == 'cc_bill' ? Icons.credit_card_rounded : Icons.payments_outlined;

  Color _typeColor(String type) =>
      type == 'cc_bill' ? AppTheme.iconBlue : AppTheme.iconGreen;

  Color _typeBackground(String type) =>
      type == 'cc_bill' ? AppTheme.tintBlueBg : AppTheme.tintGreenBg;

  String _typeLabel(String type) =>
      type == 'cc_bill' ? 'Credit Card Bill' : 'Service';

  Widget _buildCategoryRow(Category cat) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: AppTheme.cardDecoration,
      child: Row(
        children: [
          IconTile(
            icon: _typeIcon(cat.categoryType),
            color: _typeColor(cat.categoryType),
            background: _typeBackground(cat.categoryType),
            size: 36,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  cat.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 13.5,
                    color: AppTheme.textPrimary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  _typeLabel(cat.categoryType),
                  style: const TextStyle(
                    fontSize: 11,
                    color: AppTheme.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            tooltip: 'Edit',
            visualDensity: VisualDensity.compact,
            onPressed: () => _showAddEditDialog(category: cat),
            icon: const Icon(Icons.edit_outlined, size: 18, color: AppTheme.iconGreen),
          ),
          IconButton(
            tooltip: 'Delete',
            visualDensity: VisualDensity.compact,
            onPressed: () => _confirmDelete(cat),
            icon: const Icon(Icons.delete_outline_rounded, size: 18, color: AppTheme.iconRed),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const EmptyState(
            icon: Icons.category_rounded,
            title: 'No categories yet',
          ),
          const SizedBox(height: 8),
          PrimaryButton(
            label: 'Load Default Categories',
            icon: Icons.download_rounded,
            expanded: false,
            onPressed: _seedCategories,
          ),
        ],
      ),
    );
  }

  Widget _buildBottomBar() {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
      decoration: BoxDecoration(
        color: Colors.white,
        border: const Border(top: BorderSide(color: AppTheme.borderLight, width: 0.6)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: PrimaryButton(
        label: 'Add Category',
        icon: Icons.add_rounded,
        onPressed: () => _showAddEditDialog(),
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
            title: 'Manage Categories',
            actions: [
              HeaderIconButton(
                icon: Icons.add_rounded,
                color: AppTheme.iconGreen,
                onTap: () => _showAddEditDialog(),
              ),
            ],
          ),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _categories.isEmpty
                    ? _buildEmptyState()
                    : RefreshIndicator(
                        onRefresh: _loadCategories,
                        child: ListView.builder(
                          physics: const AlwaysScrollableScrollPhysics(),
                          padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
                          itemCount: _categories.length,
                          itemBuilder: (context, index) =>
                              _buildCategoryRow(_categories[index]),
                        ),
                      ),
          ),
          if (!_isLoading) _buildBottomBar(),
        ],
      ),
    );
  }
}
