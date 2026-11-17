import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../config/api_config.dart';
import '../../services/api_service.dart';
import '../../utils/errors.dart';
import '../../utils/theme.dart';

class InvoiceListScreen extends StatefulWidget {
  const InvoiceListScreen({super.key});

  @override
  State<InvoiceListScreen> createState() => _InvoiceListScreenState();
}

class _InvoiceListScreenState extends State<InvoiceListScreen> {
  List<Map<String, dynamic>> _invoices = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadInvoices();
  }

  Future<void> _loadInvoices() async {
    setState(() => _isLoading = true);
    try {
      final data = await ApiService.getAdminInvoices();
      if (!mounted) return;
      setState(() { _invoices = data; _isLoading = false; });
    } catch (e) {
      setState(() => _isLoading = false);
      if (!mounted) return;
      showApiError(context, e);
    }
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'paid': return AppTheme.successColor;
      case 'pending': return AppTheme.warningColor;
      case 'cancelled': return AppTheme.errorColor;
      default: return Colors.grey;
    }
  }

  void _downloadPdf(String invoiceId) async {
    final url = Uri.parse(ApiConfig.adminInvoicePdfUrl(invoiceId));
    if (await canLaunchUrl(url)) {
      await launchUrl(url, mode: LaunchMode.externalApplication);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Invoices'),
        backgroundColor: AppTheme.secondaryColor,
        foregroundColor: Colors.white,
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: _loadInvoices),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _invoices.isEmpty
              ? const Center(child: Text('No invoices found'))
              : RefreshIndicator(
                  onRefresh: _loadInvoices,
                  child: ListView.builder(
                    padding: const EdgeInsets.all(12),
                    itemCount: _invoices.length,
                    itemBuilder: (context, i) => _invoiceCard(_invoices[i]),
                  ),
                ),
    );
  }

  Widget _invoiceCard(Map<String, dynamic> invoice) {
    final status = invoice['status'] ?? 'pending';
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(invoice['invoice_number'] ?? '', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(color: _statusColor(status), borderRadius: BorderRadius.circular(12)),
                  child: Text(status.toUpperCase(), style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold)),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text('Shop: ${invoice['shop_name'] ?? ''}', style: TextStyle(color: Colors.grey[600])),
            Text('Plan: ${invoice['plan'] ?? ''}', style: TextStyle(color: Colors.grey[600])),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Amount: Rs. ${invoice['amount']}', style: const TextStyle(fontWeight: FontWeight.w500)),
                    Text('Tax: Rs. ${invoice['tax']}', style: TextStyle(color: Colors.grey[600], fontSize: 13)),
                    Text('Total: Rs. ${invoice['total_amount']}', style: const TextStyle(fontWeight: FontWeight.bold, color: AppTheme.primaryColor)),
                  ],
                ),
                IconButton(
                  icon: const Icon(Icons.download, color: AppTheme.secondaryColor),
                  onPressed: () => _downloadPdf(invoice['id']),
                  tooltip: 'Download PDF',
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
