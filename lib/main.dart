import 'package:flutter/material.dart';
import 'package:sqflite/sqflite.dart' as sqflite;
import 'package:path/path.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:flutter_sms_inbox/flutter_sms_inbox.dart';
import 'services/sms_service.dart';
import 'package:google_fonts/google_fonts.dart';
import 'widgets/transaction_card.dart';
import 'widgets/transaction_details_sheet.dart';
import 'models/transaction.dart';

const int pageSize = 30;

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  ThemeMode _themeMode = ThemeMode.system;

  void _toggleTheme() {
    setState(() {
      if (_themeMode == ThemeMode.light) {
        _themeMode = ThemeMode.dark;
      } else {
        _themeMode = ThemeMode.light;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'CBE Transaction History',
      theme: ThemeData(
        colorScheme: ColorScheme(
          brightness: Brightness.light,
          primary: const Color(0xFF3650af),
          onPrimary: Colors.white,
          secondary: const Color(0xFF4fb542),
          onSecondary: Colors.white,
          error: const Color(0xFFd75252),
          onError: Colors.white,
          background: const Color(0xFFF6F7FB),
          onBackground: const Color(0xFF1a1a1a),
          surface: Colors.white,
          onSurface: const Color(0xFF1a1a1a),
        ),
        scaffoldBackgroundColor: const Color(0xFFF6F7FB),
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFFF6F7FB),
          foregroundColor: Color(0xFF1a1a1a),
          elevation: 0,
        ),
        cardColor: Colors.white,
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: Colors.white,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(24),
            borderSide: BorderSide.none,
          ),
        ),
        textTheme: GoogleFonts.sofiaSansTextTheme(),
        useMaterial3: true,
      ),
      darkTheme: ThemeData(
        colorScheme: ColorScheme(
          brightness: Brightness.dark,
          primary: const Color(0xFF3650af),
          onPrimary: Colors.white,
          secondary: const Color(0xFF4fb542),
          onSecondary: Colors.white,
          error: const Color(0xFFd75252),
          onError: Colors.white,
          background: const Color(0xFF23263a),
          onBackground: Colors.white,
          surface: const Color(0xFF292c3c),
          onSurface: Colors.white,
        ),
        scaffoldBackgroundColor: const Color(0xFF23263a),
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFF23263a),
          foregroundColor: Colors.white,
          elevation: 0,
        ),
        cardColor: const Color(0xFF292c3c),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: const Color(0xFF292c3c),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(24),
            borderSide: BorderSide.none,
          ),
        ),
        textTheme: GoogleFonts.sofiaSansTextTheme(),
        useMaterial3: true,
      ),
      themeMode: _themeMode,
      home: TransactionHistoryPage(onToggleTheme: _toggleTheme, themeMode: _themeMode),
    );
  }
}

class TransactionHistoryPage extends StatefulWidget {
  final VoidCallback onToggleTheme;
  final ThemeMode themeMode;
  const TransactionHistoryPage({super.key, required this.onToggleTheme, required this.themeMode});

  @override
  State<TransactionHistoryPage> createState() => _TransactionHistoryPageState();
}

class _TransactionHistoryPageState extends State<TransactionHistoryPage> {
  List<Transaction> transactions = [];
  late sqflite.Database database;
  final SmsService _smsService = SmsService();
  bool _isLoading = true;
  bool _isLoadingMore = false;
  bool _hasMore = true;
  int _currentPage = 0;
  final _scaffoldKey = GlobalKey<ScaffoldMessengerState>();
  String _searchQuery = '';
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    print('Initializing app...');
    _initializeApp();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _smsService.dispose();
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

  Future<bool> _transactionExists(Map<String, dynamic> data) async {
    // Use amount, date, and balance as a unique key (customize as needed)
    final result = await database.query(
      'transactions',
      where: 'amount = ? AND date = ? AND balance = ?',
      whereArgs: [data['amount'], data['date'], data['balance']],
    );
    return result.isNotEmpty;
  }

  Future<void> _initializeApp() async {
    try {
      print('Initializing database...');
      await _initializeDatabase();
      print('Requesting permissions...');
      await _requestPermissions();
      print('Starting SMS listener...');
      await _startSmsListener();
      print('App initialization complete');
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
      await _loadInitialTransactions();
    } catch (e) {
      print('Error during initialization: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
        _scaffoldKey.currentState?.showSnackBar(
          SnackBar(
            content: Text('Error initializing app: $e'),
            duration: const Duration(seconds: 5),
          ),
        );
      }
    }
  }

  Future<void> _requestPermissions() async {
    final hasPermission = await _smsService.requestPermissions();
    if (!hasPermission && mounted) {
      _scaffoldKey.currentState?.showSnackBar(
        const SnackBar(
          content: Text('SMS permission is required for this app to work'),
          duration: Duration(seconds: 5),
        ),
      );
    }
  }

  Future<void> _initializeDatabase() async {
    try {
      database = await sqflite.openDatabase(
        join(await sqflite.getDatabasesPath(), 'transactions_database.db'),
        onCreate: (db, version) {
          print('Creating database...');
          return db.execute(
            'CREATE TABLE transactions(id INTEGER PRIMARY KEY AUTOINCREMENT, amount REAL, serviceCharge REAL, vat REAL, balance REAL, date TEXT, url TEXT, payer TEXT, receiver TEXT, reason TEXT)',
          );
        },
        version: 1,
      );
      print('Database initialized successfully');
    } catch (e) {
      print('Error initializing database: $e');
      rethrow;
    }
  }

  Future<void> _loadInitialTransactions() async {
    setState(() {
      transactions = [];
      _currentPage = 0;
      _hasMore = true;
    });
    await _loadMoreTransactions(reset: true);
  }

  Future<void> _loadMoreTransactions({bool reset = false}) async {
    if (_isLoadingMore) return;
    setState(() {
      _isLoadingMore = true;
    });
    final offset = reset ? 0 : transactions.length;
    final List<Map<String, dynamic>> maps = await database.query(
      'transactions',
      orderBy: 'date DESC',
      limit: pageSize,
      offset: offset,
    );
    final newTransactions = List.generate(maps.length, (i) {
      return Transaction(
        id: maps[i]['id'],
        amount: maps[i]['amount'],
        serviceCharge: maps[i]['serviceCharge'],
        vat: maps[i]['vat'],
        balance: maps[i]['balance'],
        date: DateTime.parse(maps[i]['date']),
        payer: maps[i]['payer'],
        receiver: maps[i]['receiver'],
        reason: maps[i]['reason'],
        url: maps[i]['url'],
      );
    });
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

  Future<void> _startSmsListener() async {
    try {
      _smsService.onNewTransaction = (SmsMessage message) async {
        print('New transaction received: ${message.body}');
        final transactionData = await _smsService.parseTransactionSms(message);
        if (transactionData.isNotEmpty) {
          print('Saving transaction: $transactionData');
          final exists = await _transactionExists(transactionData);
          if (!exists) {
            await database.transaction((txn) async {
              await txn.insert('transactions', transactionData);
            });
            await _loadMoreTransactions();
            if (mounted) {
              _scaffoldKey.currentState?.showSnackBar(
                const SnackBar(
                  content: Text('New transaction recorded!'),
                  duration: Duration(seconds: 2),
                ),
              );
            }
          }
        }
      };
      await _smsService.startListening(_smsService.onNewTransaction!);
      print('SMS listener started successfully');
    } catch (e) {
      print('Error starting SMS listener: $e');
      rethrow;
    }
  }

  Future<void> _batchInsertTransactions(List<SmsMessage> messages) async {
    await database.transaction((txn) async {
      for (final message in messages) {
        final data = await _smsService.parseTransactionSms(message);
        final exists = await txn.query(
          'transactions',
          where: 'amount = ? AND date = ? AND balance = ?',
          whereArgs: [data['amount'], data['date'], data['balance']],
        );
        if (exists.isEmpty) {
          await txn.insert('transactions', data);
        }
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final filteredTransactions = _searchQuery.isEmpty
        ? transactions
        : transactions.where((t) {
            final q = _searchQuery.toLowerCase();
            return t.amount.toString().contains(q) ||
                t.balance.toString().contains(q) ||
                t.date.toString().toLowerCase().contains(q);
          }).toList();
    return ScaffoldMessenger(
      key: _scaffoldKey,
      child: Scaffold(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        appBar: AppBar(
          title: const Text('CBE Transaction History'),
          actions: [
            IconButton(
              icon: Icon(widget.themeMode == ThemeMode.dark ? Icons.light_mode : Icons.dark_mode),
              onPressed: widget.onToggleTheme,
              tooltip: 'Toggle Theme',
            ),
            IconButton(
              icon: const Icon(Icons.refresh),
              onPressed: () async {
                setState(() {
                  _isLoading = true;
                });
                List<SmsMessage> newMessages = [];
                await _smsService.startListening((SmsMessage message) async {
                  newMessages.add(message);
                });
                await _batchInsertTransactions(newMessages);
                await _loadInitialTransactions();
                setState(() {
                  _isLoading = false;
                });
              },
              tooltip: 'Refresh',
            ),
          ],
        ),
        body: Column(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              child: TextField(
                decoration: InputDecoration(
                  hintText: 'Search by amount, balance, or date',
                  prefixIcon: const Icon(Icons.search),
                  filled: true,
                  fillColor: Theme.of(context).cardColor,
                  contentPadding: const EdgeInsets.symmetric(vertical: 10, horizontal: 16),
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
                            final isDeposit = transaction.amount > 0; // Simplified logic
                            return Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                              child: TransactionCard(
                                transaction: transaction,
                                isDeposit: isDeposit,
                                onTap: () => _showTransactionDetails(context, transaction),
                              ),
                            );
                          },
                        ),
            ),
          ],
        ),
      ),
    );
  }

  void _showTransactionDetails(BuildContext context, Transaction transaction) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return TransactionDetailsSheet(transaction: transaction);
      },
    );
  }
}
