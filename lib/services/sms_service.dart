import 'package:flutter_sms_inbox/flutter_sms_inbox.dart';
import 'package:permission_handler/permission_handler.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'dart:async';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart';
import 'package:http/io_client.dart';
import '../models/transaction.dart';

class SmsService {
  static const String cbeSender = "CBE";
  Function(SmsMessage)? onNewTransaction;
  final SmsQuery _query = SmsQuery();
  bool _isListening = false;
  Timer? _checkTimer;
  DateTime _lastCheck = DateTime.now();

  Future<bool> requestPermissions() async {
    try {
      print('Requesting SMS permission...');
      var status = await Permission.sms.request();
      print('SMS permission status: $status');
      return status.isGranted;
    } catch (e) {
      print('Error requesting SMS permission: $e');
      return false;
    }
  }

  Future<void> startListening(Function(SmsMessage) onSmsReceived) async {
    if (_isListening) {
      print('SMS listener already running');
      return;
    }
    _isListening = true;

    try {
      print('Starting SMS checker...');
      final messages = await _query.querySms(
        kinds: [SmsQueryKind.inbox],
        count: 100,
      );
      print('Found ${messages.length} recent messages');
      for (var message in messages) {
        print('Checking message from: ${message.sender}');
        if (message.sender?.contains(cbeSender) ?? false) {
          print('Found CBE message: ${message.body}');
          onSmsReceived(message);
        }
      }
      print('Setting up periodic SMS checker...');
      _checkTimer = Timer.periodic(const Duration(seconds: 30), (timer) async {
        try {
          final messages = await _query.querySms(
            kinds: [SmsQueryKind.inbox],
            count: 100,
          );
          for (var message in messages) {
            if (message.date?.isAfter(_lastCheck) ?? false) {
              print('Found new message from: ${message.sender}');
              if (message.sender?.contains(cbeSender) ?? false) {
                print('Found new CBE message: ${message.body}');
                onSmsReceived(message);
              }
            }
          }
          _lastCheck = DateTime.now();
        } catch (e) {
          print('Error checking for new messages: $e');
        }
      });
      print('SMS checker setup complete');
    } catch (e) {
      print('Error in SMS checker: $e');
      _isListening = false;
      rethrow;
    }
  }

  void dispose() {
    _checkTimer?.cancel();
    _isListening = false;
  }

  Future<Map<String, dynamic>> parseTransactionSms(SmsMessage smsMsg) async {
    try {
      final sms = smsMsg.body ?? '';
      print('Parsing SMS: $sms');
      // Try to extract a shorturl.at or direct CBE link
      final urlRegex =
          RegExp(r'(https://shorturl\.at/\w+|https://apps\.cbe\.com\.et:100/\?id=[^\s]+)');
      final match = urlRegex.firstMatch(sms);
      String? foundUrl;
      if (match != null) {
        foundUrl = match.group(0);
        print('Found URL: $foundUrl');
      } else {
        print('No URL found in SMS');
      }
      String? actualUrl = foundUrl;
      String? payer;
      String? receiver;
      if (foundUrl != null && foundUrl.contains('shorturl.at')) {
        print('Following short URL...');
        final response = await http.get(Uri.parse(foundUrl));
        actualUrl = response.headers['location'] ?? foundUrl;
        print('Resolved short URL to: $actualUrl');
      }
      // If we have a direct CBE PDF link, try to parse payer/receiver from the PDF
      if (actualUrl != null && actualUrl.contains('apps.cbe.com.et')) {
        try {
          final pdfData = await _parseCbePdf(actualUrl);
          payer = pdfData['payer'];
          receiver = pdfData['receiver'];
        } catch (e) {
          print('Error parsing PDF for payer/receiver: $e');
        }
      }
      // Fallback: Try to extract payer/receiver from SMS text (if possible)
      final payerRegex = RegExp(r'Payer:?\s*([A-Z\s]+)');
      final receiverRegex = RegExp(r'Receiver:?\s*([A-Z\s]+)');
      final payerMatch = payerRegex.firstMatch(sms);
      final receiverMatch = receiverRegex.firstMatch(sms);
      payer ??= payerMatch?.group(1)?.trim();
      receiver ??= receiverMatch?.group(1)?.trim();
      // Parse the transaction details from the SMS
      final amountRegex = RegExp(r'ETB\s*([\d,]+\.\d{2})');
      final serviceChargeRegex = RegExp(
          r'Service charge(?: and VAT\(15%\))? with a total of ETB ([\d,]+\.\d{2})|Service charge ETB([\d,]+\.\d{2})');
      final vatRegex = RegExp(r'VAT\(15%\)[^\d]*(\d+\.\d{2})');
      final balanceRegex = RegExp(r'Balance is ETB\s*([\d,]+\.\d{2})');
      final dateRegex = RegExp(r'(\d{1,2}/\d{1,2}/\d{4},?\s*\d{1,2}:\d{2}:\d{2}\s*[APMapm]{2})');
      final amountMatch = amountRegex.firstMatch(sms);
      final serviceChargeMatch = serviceChargeRegex.firstMatch(sms);
      final vatMatch = vatRegex.firstMatch(sms);
      final balanceMatch = balanceRegex.firstMatch(sms);
      final dateMatch = dateRegex.firstMatch(sms);
      String? parsedDate;
      if (dateMatch != null) {
        // Example: 6/9/2025, 7:53:00 PM
        try {
          parsedDate = _parseCbeDate(dateMatch.group(1)!);
        } catch (e) {
          print('Error parsing date from SMS: $e');
        }
      }
      // Fallback to SMS message date
      parsedDate ??= smsMsg.date?.toIso8601String();
      print('Parsed values:');
      print('Amount: ${amountMatch?.group(1)}');
      print('Service Charge: ${serviceChargeMatch?.group(1) ?? serviceChargeMatch?.group(2)}');
      print('VAT: ${vatMatch?.group(1)}');
      print('Balance: ${balanceMatch?.group(1)}');
      print('Date: $parsedDate');
      print('Payer: $payer');
      print('Receiver: $receiver');
      final transactionData = {
        'amount': double.tryParse((amountMatch?.group(1) ?? '0').replaceAll(',', '')),
        'serviceCharge': double.tryParse(
            (serviceChargeMatch?.group(1) ?? serviceChargeMatch?.group(2) ?? '0')
                .replaceAll(',', '')),
        'vat': double.tryParse((vatMatch?.group(1) ?? '0').replaceAll(',', '')),
        'balance': double.tryParse((balanceMatch?.group(1) ?? '0').replaceAll(',', '')),
        'date': parsedDate ?? DateTime.now().toIso8601String(),
        'url': actualUrl,
        'payer': payer,
        'receiver': receiver,
      };
      print('Created transaction data: $transactionData');
      return transactionData;
    } catch (e) {
      print('Error parsing SMS: $e');
      return {};
    }
  }

  Future<http.Response> getInsecure(String url) async {
    final ioc = HttpClient()
      ..badCertificateCallback = (X509Certificate cert, String host, int port) => true;
    final client = IOClient(ioc);
    return await client.get(Uri.parse(url));
  }

  Future<Map<String, String>> _parseCbePdf(String url) async {
    try {
      // Download the PDF to a temp file (insecure, dev only)
      final response = await getInsecure(url);
      if (response.statusCode != 200) return {'payer': '', 'receiver': '', 'reason': ''};
      final tempDir = await getTemporaryDirectory();
      final tempFile = File('${tempDir.path}/cbe_temp.pdf');
      await tempFile.writeAsBytes(response.bodyBytes);
      // Extract text from the PDF using Syncfusion
      final bytes = await tempFile.readAsBytes();
      final document = PdfDocument(inputBytes: bytes);
      final text = PdfTextExtractor(document).extractText();
      document.dispose();
      // Use regex to extract payer, receiver, and reason
      final payerRegex = RegExp(r'Payer\s*([A-Z\s\.]+)', caseSensitive: false);
      final receiverRegex = RegExp(r'Receiver\s*([A-Z\s\.]+)', caseSensitive: false);
      final reasonRegex = RegExp(r'Reason / Type of service\s*([^\n]+)', caseSensitive: false);
      String payer = '';
      String receiver = '';
      String reason = '';
      final payerMatch = payerRegex.firstMatch(text);
      if (payerMatch != null) {
        payer = payerMatch.group(1)?.trim() ?? '';
      }
      final receiverMatch = receiverRegex.firstMatch(text);
      if (receiverMatch != null) {
        receiver = receiverMatch.group(1)?.trim() ?? '';
      }
      final reasonMatch = reasonRegex.firstMatch(text);
      if (reasonMatch != null) {
        reason = reasonMatch.group(1)?.trim() ?? '';
      }
      print('Extracted from PDF: Payer: $payer, Receiver: $receiver, Reason: $reason');
      return {'payer': payer, 'receiver': receiver, 'reason': reason};
    } catch (e) {
      print('Error parsing PDF: $e');
      return {'payer': '', 'receiver': '', 'reason': ''};
    }
  }

  String _parseCbeDate(String dateStr) {
    // Example: 6/9/2025, 7:53:00 PM
    final dateTime = DateTime.parse(_convertToIso(dateStr));
    return dateTime.toIso8601String();
  }

  String _convertToIso(String dateStr) {
    // Convert CBE date string to ISO format
    // Example: 6/9/2025, 7:53:00 PM -> 2025-06-09T19:53:00
    final regex =
        RegExp(r'(\d{1,2})/(\d{1,2})/(\d{4}),?\s*(\d{1,2}):(\d{2}):(\d{2})\s*([APMapm]{2})');
    final match = regex.firstMatch(dateStr);
    if (match == null) throw Exception('Invalid date format');
    int month = int.parse(match.group(1)!);
    int day = int.parse(match.group(2)!);
    int year = int.parse(match.group(3)!);
    int hour = int.parse(match.group(4)!);
    int minute = int.parse(match.group(5)!);
    int second = int.parse(match.group(6)!);
    String ampm = match.group(7)!.toUpperCase();
    if (ampm == 'PM' && hour != 12) hour += 12;
    if (ampm == 'AM' && hour == 12) hour = 0;
    return '$year-${month.toString().padLeft(2, '0')}-${day.toString().padLeft(2, '0')}T${hour.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')}:${second.toString().padLeft(2, '0')}';
  }

  Transaction? _parseCbeSms(SmsMessage message) {
    final body = message.body?.toLowerCase() ?? '';
    if (!body.contains('cbe')) return null;

    final amountRegex = RegExp(r'ETB\s*([\d,]+\.?\d*)');
    final serviceChargeRegex = RegExp(r'Service charge\s*ETB\s*([\d,]+\.?\d*)');
    final vatRegex = RegExp(r'VAT\(15%\)\s*ETB\s*([\d,]+\.?\d*)');
    final balanceRegex = RegExp(r'Current Balance\s*is\s*ETB\s*([\d,]+\.?\d*)');
    final urlRegex = RegExp(r'(https?://[^\s]+)');

    final amountMatch = amountRegex.firstMatch(body);
    final serviceChargeMatch = serviceChargeRegex.firstMatch(body);
    final vatMatch = vatRegex.firstMatch(body);
    final balanceMatch = balanceRegex.firstMatch(body);
    final urlMatch = urlRegex.firstMatch(body);

    if (amountMatch == null || balanceMatch == null) return null;

    final amount = double.parse(amountMatch.group(1)!.replaceAll(',', ''));
    final serviceCharge = serviceChargeMatch != null
        ? double.parse(serviceChargeMatch.group(1)!.replaceAll(',', ''))
        : 0.0;
    final vat = vatMatch != null ? double.parse(vatMatch.group(1)!.replaceAll(',', '')) : 0.0;
    final balance = double.parse(balanceMatch.group(1)!.replaceAll(',', ''));
    final url = urlMatch?.group(1);

    // Determine if the transaction is a credit or debit
    final isCredit = body.contains('credited');
    final transactionAmount = isCredit ? amount : -amount;

    return Transaction(
      amount: transactionAmount,
      serviceCharge: serviceCharge,
      vat: vat,
      balance: balance,
      date: message.date ?? DateTime.now(),
      url: url,
    );
  }
}
