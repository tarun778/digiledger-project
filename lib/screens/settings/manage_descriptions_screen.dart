import 'package:flutter/material.dart';
import '../../utils/errors.dart';
import '../../utils/theme.dart';
import '../../services/api_service.dart';
import '../../widgets/ui_kit.dart';

class ManageDescriptionsScreen extends StatefulWidget {
  const ManageDescriptionsScreen({super.key});

  @override
  State<ManageDescriptionsScreen> createState() => _ManageDescriptionsScreenState();
}

class _ManageDescriptionsScreenState extends State<ManageDescriptionsScreen> {
  List<Map<String, dynamic>> _suggestions = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadSuggestions();
  }

  Future<void> _loadSuggestions() async {
    setState(() => _isLoading = true);
    try {
      final suggestions = await ApiService.getDescriptionSuggestions();
      if (!mounted) return;
      setState(() {
        _suggestions = suggestions;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      if (!mounted) return;
      showApiError(context, e);
    }
  }

  void _showAddDialog() {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Add Description'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(
            hintText: 'e.g., Bus Ticket',
            labelText: 'Description Text',
          ),
          autofocus: true,
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          TextButton(
            onPressed: () async {
              if (controller.text.trim().isEmpty) {
                ScaffoldMessenger.maybeOf(ctx)?.showSnackBar(
                  const SnackBar(content: Text('Enter a description')),
                );
                return;
              }
              try {
                await ApiService.createDescriptionSuggestion({
                  'text': controller.text.trim(),
                });
                if (!ctx.mounted) return;
                Navigator.pop(ctx);
                if (!mounted) return;
                _loadSuggestions();
              } catch (e) {
                if (!mounted) return;
                showApiError(context, e);
              }
            },
            child: const Text('Add'),
          ),
        ],
      ),
    );
  }

  void _confirmDelete(Map<String, dynamic> suggestion) {
    if (suggestion['is_default'] == true) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Default suggestions cannot be deleted'),
          backgroundColor: AppTheme.errorColor,
        ),
      );
      return;
    }
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Description'),
        content: Text('Delete "${suggestion['text']}"?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          TextButton(
            onPressed: () async {
              try {
                await ApiService.deleteDescriptionSuggestion(suggestion['id']);
                if (!ctx.mounted) return;
                Navigator.pop(ctx);
                if (!mounted) return;
                _loadSuggestions();
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

  Future<void> _seedDefaults() async {
    try {
      await ApiService.seedDescriptionSuggestions();
      if (!mounted) return;
      _loadSuggestions();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Default descriptions added!'), backgroundColor: AppTheme.successColor),
      );
    } catch (e) {
      if (!mounted) return;
      showApiError(context, e);
    }
  }

  Widget _buildSuggestionRow(Map<String, dynamic> suggestion) {
    final isDefault = suggestion['is_default'] == true;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: AppTheme.cardDecoration,
      child: Row(
        children: [
          IconTile(
            icon: isDefault ? Icons.lock_outline_rounded : Icons.description_outlined,
            color: isDefault ? AppTheme.iconAmber : AppTheme.iconGreen,
            background: isDefault ? AppTheme.tintAmberBg : AppTheme.tintGreenBg,
            size: 36,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  suggestion['text'] ?? '',
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
                  isDefault ? 'Default' : 'Custom',
                  style: TextStyle(
                    fontSize: 11,
                    color: isDefault ? AppTheme.iconAmber : AppTheme.iconGreen,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          if (!isDefault)
            IconButton(
              tooltip: 'Delete',
              visualDensity: VisualDensity.compact,
              onPressed: () => _confirmDelete(suggestion),
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
            icon: Icons.description_rounded,
            title: 'No descriptions yet',
          ),
          const SizedBox(height: 8),
          PrimaryButton(
            label: 'Load Default Descriptions',
            icon: Icons.download_rounded,
            expanded: false,
            onPressed: _seedDefaults,
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
        label: 'Add Description',
        icon: Icons.add_rounded,
        onPressed: _showAddDialog,
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
            title: 'Manage Descriptions',
            actions: [
              HeaderIconButton(
                icon: Icons.add_rounded,
                color: AppTheme.iconGreen,
                onTap: _showAddDialog,
              ),
            ],
          ),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _suggestions.isEmpty
                    ? _buildEmptyState()
                    : RefreshIndicator(
                        onRefresh: _loadSuggestions,
                        child: ListView.builder(
                          physics: const AlwaysScrollableScrollPhysics(),
                          padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
                          itemCount: _suggestions.length,
                          itemBuilder: (context, index) =>
                              _buildSuggestionRow(_suggestions[index]),
                        ),
                      ),
          ),
          if (!_isLoading) _buildBottomBar(),
        ],
      ),
    );
  }
}
