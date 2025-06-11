import 'package:flutter/material.dart';
import '../models/transaction.dart';

class TransactionCard extends StatelessWidget {
  final Transaction transaction;
  final bool isDeposit;
  final VoidCallback onTap;

  const TransactionCard({
    super.key,
    required this.transaction,
    required this.isDeposit,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final isIncoming = transaction.amount > 0;
    final isOutgoing = transaction.amount < 0;
    debugPrint(
        'Transaction amount: ${transaction.amount}, isIncoming: $isIncoming, isOutgoing: $isOutgoing');
    final cardColor = theme.cardColor;
    final primaryText = isDark ? Colors.white : const Color(0xFF1a1a1a);
    final secondaryText = isDark ? Colors.white70 : Colors.black54;
    final accentBlue = isDark ? const Color(0xFF4f6bed) : Colors.blue;
    final payerColor = isIncoming ? Colors.green : Colors.red;
    final receiverColor = isIncoming ? Colors.green : Colors.red;
    final amountColor = isIncoming ? Colors.green : Colors.red;
    final iconColor = isIncoming ? Colors.green : Colors.red;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      child: GestureDetector(
        onTap: onTap,
        child: Card(
          color: cardColor,
          elevation: 2,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
          child: Row(
            children: [
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(18.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Amount: ETB \\${transaction.amount.toStringAsFixed(2)}',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 18,
                              color: amountColor,
                            ),
                          ),
                          Icon(
                            isDeposit ? Icons.arrow_downward : Icons.arrow_upward,
                            color: iconColor,
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Date: \\${transaction.date.toString().split('.')[0]}',
                        style: TextStyle(fontSize: 15, color: primaryText),
                      ),
                      const SizedBox(height: 4),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (transaction.payer != null && transaction.payer!.isNotEmpty)
                            Text(
                              'Payer: \\${transaction.payer}',
                              style: TextStyle(
                                fontSize: 14,
                                color: isDark ? Colors.white70 : Colors.black87,
                              ),
                            ),
                          if (transaction.receiver != null && transaction.receiver!.isNotEmpty)
                            Text(
                              'Receiver: \\${transaction.receiver}',
                              style: TextStyle(
                                fontSize: 14,
                                color: isDark ? Colors.white70 : Colors.black87,
                              ),
                            ),
                          if (transaction.reason != null && transaction.reason!.isNotEmpty)
                            Text(
                              'Reason: \\${transaction.reason}',
                              style: TextStyle(
                                fontSize: 12,
                                color: isDark ? Colors.white70 : Colors.black87,
                              ),
                            ),
                          const SizedBox(height: 4),
                          Text(
                            'Balance: ETB ${transaction.balance.toStringAsFixed(2)}',
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                              color: isDark ? Colors.white : const Color(0xFF4f6bed),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
