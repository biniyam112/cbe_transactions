import 'package:flutter/material.dart';
import 'package:sqflite/sqflite.dart' as sqflite;
import '../models/transaction.dart';
import '../widgets/transaction_card.dart';
import '../widgets/transaction_details_sheet.dart';
import '../services/sms_service.dart';

const int pageSize = 30;

class TransactionListView extends StatefulWidget {
  final sqflite.Database database;
  final SmsService smsService;
  const TransactionListView({super.key, required this.database, required this.smsService});

  @override
  State<TransactionListView> createState() => _TransactionListViewState();
}

class _TransactionListViewState extends State<TransactionListView> {
  List<Transaction> transactions = [];
  bool _isLoading = true;
  bool _isLoadingMore = false;
  bool _hasMore = true;
  String _searchQuery = '';
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    _loadInitialTransactions();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >= _scrollController.position.maxScrollExtent - 200 &&
        !_isLoadingMore &&
        _hasMore &&
        !_isLoading) {
      _loadMoreTransactions();
    }
  }

  Future<void> _loadInitialTransactions() async {
    setState(() {
      transactions = [];
      _hasMore = true;
      _isLoading = true;
    });
    await _loadMoreTransactions(reset: true);
    setState(() {
      _isLoading = false;
    });
  }

  Future<void> _loadMoreTransactions({bool reset = false}) async {
    if (_isLoadingMore) return;
    setState(() {
      _isLoadingMore = true;
    });
    final offset = reset ? 0 : transactions.length;
    final List<Map<String, dynamic>> maps = await widget.database.query(
      'transactions',
      orderBy: 'date DESC',
      limit: pageSize,
      offset: offset,
    );
    final newTransactions = List.generate(maps.length, (i) => Transaction.fromMap(maps[i]));
    setState(() {
      if (reset) {
        transactions = newTransactions;
      } else {
        transactions.addAll(newTransactions);
      }
      _hasMore = newTransactions.length == pageSize;
      _isLoadingMore = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final searchBarFill = isDark ? theme.cardColor : Colors.white;
    final searchTextColor = isDark ? Colors.white : const Color(0xFF1a1a1a);
    final searchHintColor = isDark ? Colors.white54 : Colors.black45;
    final searchCursorColor = isDark ? Colors.white : const Color(0xFF1a1a1a);
    final filteredTransactions = _searchQuery.isEmpty
        ? transactions
        : transactions.where((t) {
            final q = _searchQuery.toLowerCase();
            return t.amount.toString().contains(q) ||
                t.balance.toString().contains(q) ||
                t.date.toString().toLowerCase().contains(q) ||
                (t.payer?.toLowerCase().contains(q) ?? false) ||
                (t.receiver?.toLowerCase().contains(q) ?? false);
          }).toList();
    return Column(
      children: [
        Container(
          color: Colors.transparent,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: TextField(
            style: TextStyle(color: searchTextColor),
            cursorColor: searchCursorColor,
            decoration: InputDecoration(
              hintText: 'Search by amount, balance, date, payer, or receiver',
              hintStyle: TextStyle(color: searchHintColor),
              prefixIcon: Icon(Icons.search, color: searchHintColor),
              filled: true,
              fillColor: searchBarFill,
              contentPadding: const EdgeInsets.symmetric(vertical: 0, horizontal: 16),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(24),
                borderSide: BorderSide.none,
              ),
            ),
            onChanged: (value) {
              setState(() {
                _searchQuery = value;
              });
            },
          ),
        ),
        Expanded(
          child: _isLoading
              ? const Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      CircularProgressIndicator(),
                      SizedBox(height: 16),
                      Text('Loading transactions...'),
                    ],
                  ),
                )
              : filteredTransactions.isEmpty
                  ? const Center(
                      child: Text(
                        'No transactions yet. Waiting for SMS...',
                        style: TextStyle(fontSize: 16),
                      ),
                    )
                  : ListView.builder(
                      controller: _scrollController,
                      itemCount: filteredTransactions.length + (_hasMore ? 1 : 0),
                      itemBuilder: (context, index) {
                        if (index == filteredTransactions.length && _hasMore) {
                          return const Padding(
                            padding: EdgeInsets.symmetric(vertical: 16),
                            child: Center(child: CircularProgressIndicator()),
                          );
                        }
                        final transaction = filteredTransactions[index];
                        final isDeposit = transaction.amount > 0;
                        return TransactionCard(
                          transaction: transaction,
                          isDeposit: isDeposit,
                          onTap: () => _showTransactionDetails(context, transaction),
                        );
                      },
                    ),
        ),
      ],
    );
  }

  void _showTransactionDetails(BuildContext context, Transaction transaction) {
    showModalBottomSheet(
      context: context,
      shape: RoundedRectangleBorder(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        side: BorderSide(color: Theme.of(context).colorScheme.onSurface),
      ),
      builder: (context) {
        return TransactionDetailsSheet(transaction: transaction);
      },
    );
  }
}
