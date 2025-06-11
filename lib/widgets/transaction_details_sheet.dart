import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/transaction.dart';

class TransactionDetailsSheet extends StatelessWidget {
  final Transaction transaction;
  const TransactionDetailsSheet({super.key, required this.transaction});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final labelColor = isDark ? Colors.white70 : Colors.black87;
    final valueColor = isDark ? Colors.white : Colors.black;
    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            Text(
              'Transaction Details',
              style: TextStyle(
                  fontSize: 20, fontWeight: FontWeight.bold, color: theme.colorScheme.primary),
            ),
            const SizedBox(height: 16),
            _infoRow(
                'Amount', 'ETB ${transaction.amount.toStringAsFixed(2)}', labelColor, valueColor),
            _infoRow('Date', transaction.date.toString().split('.')[0], labelColor, valueColor),
            if (transaction.payer != null)
              _infoRow('Payer', transaction.payer!, labelColor, valueColor),
            if (transaction.receiver != null)
              _infoRow('Receiver', transaction.receiver!, labelColor, valueColor),
            _infoRow('Service Charge', 'ETB ${transaction.serviceCharge.toStringAsFixed(2)}',
                labelColor, valueColor),
            _infoRow('VAT', 'ETB ${transaction.vat.toStringAsFixed(2)}', labelColor, valueColor),
            _infoRow(
                'Balance', 'ETB ${transaction.balance.toStringAsFixed(2)}', labelColor, valueColor),
            if (transaction.reason != null && transaction.reason!.isNotEmpty)
              _infoRow('Reason / Type of service', transaction.reason!, labelColor, valueColor),
            const SizedBox(height: 12),
            if (transaction.url != null && transaction.url!.isNotEmpty)
              TextButton.icon(
                icon: const Icon(Icons.open_in_new),
                label: const Text('Open Transaction PDF'),
                onPressed: () async {
                  final url = Uri.parse(transaction.url!);
                  await launchUrl(url, mode: LaunchMode.externalApplication);
                },
              ),
          ],
        ),
      ),
    );
  }

  Widget _infoRow(String label, String value, Color labelColor, Color valueColor) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('$label: ', style: TextStyle(fontWeight: FontWeight.w600, color: labelColor)),
          Expanded(child: Text(value, style: TextStyle(color: valueColor))),
        ],
      ),
    );
  }
}
