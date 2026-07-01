import 'merchant_normalizer.dart';

enum SmsTransactionType { debit, credit }

class ParsedSmsTransaction {
  final double amount;
  final String currency;
  final SmsTransactionType type;
  final String merchant;
  final String bankName;
  final String sender;
  final String paymentMethod;
  final String accountOrCard;
  final DateTime dateTime;
  final String? referenceNumber;
  final double? balance;
  final String? upiId;
  final String rawSms;
  final String smsHash;

  ParsedSmsTransaction({
    required this.amount,
    required this.currency,
    required this.type,
    required this.merchant,
    required this.bankName,
    required this.sender,
    required this.paymentMethod,
    required this.accountOrCard,
    required this.dateTime,
    this.referenceNumber,
    this.balance,
    this.upiId,
    required this.rawSms,
    required this.smsHash,
  });

  Map<String, dynamic> toJson() {
    return {
      'amount': amount,
      'currency': currency,
      'type': type.name,
      'merchant': merchant,
      'bankName': bankName,
      'sender': sender,
      'paymentMethod': paymentMethod,
      'accountOrCard': accountOrCard,
      'dateTime': dateTime.toIso8601String(),
      'referenceNumber': referenceNumber,
      'balance': balance,
      'upiId': upiId,
      'rawSms': rawSms,
      'smsHash': smsHash,
    };
  }

  factory ParsedSmsTransaction.fromJson(Map<String, dynamic> json) {
    return ParsedSmsTransaction(
      amount: (json['amount'] as num).toDouble(),
      currency: json['currency'] as String,
      type: SmsTransactionType.values.firstWhere((e) => e.name == json['type']),
      merchant: json['merchant'] as String,
      bankName: json['bankName'] as String,
      sender: json['sender'] as String,
      paymentMethod: json['paymentMethod'] as String,
      accountOrCard: json['accountOrCard'] as String,
      dateTime: DateTime.parse(json['dateTime'] as String),
      referenceNumber: json['referenceNumber'] as String?,
      balance: (json['balance'] as num?)?.toDouble(),
      upiId: json['upiId'] as String?,
      rawSms: json['rawSms'] as String,
      smsHash: json['smsHash'] as String,
    );
  }
}

abstract class SmsFormatRule {
  bool matches(String sender, String body);
  ParsedSmsTransaction parse(
      String sender, String body, DateTime date, String hash, String baseCurrency);
}

class HdfcCardRule extends SmsFormatRule {
  @override
  bool matches(String sender, String body) {
    final s = sender.toLowerCase();
    final b = body.toLowerCase();
    return s.contains('hdfc') && b.contains('card') && b.contains('spent');
  }

  @override
  ParsedSmsTransaction parse(
      String sender, String body, DateTime date, String hash, String baseCurrency) {
    final amountMatch = RegExp(r'(?:rs\.?|inr)\s*([0-9,]+(?:\.[0-9]{1,2})?)', caseSensitive: false).firstMatch(body);
    final amount = double.tryParse(amountMatch?.group(1)?.replaceAll(',', '') ?? '0') ?? 0.0;
    
    final merchantMatch = RegExp(r'at\s+([A-Za-z0-9\s#\-]+?)(?:\.|\s+on|\s+dt|\s+date|\s+txn|\s+bal|$)', caseSensitive: false).firstMatch(body);
    final rawMerchant = merchantMatch?.group(1)?.trim() ?? 'Amazon';
    
    final cardMatch = RegExp(r'(hdfc\s+card|card\s+ending\s+in\s+\d+|card\s+xx\d+)', caseSensitive: false).firstMatch(body);
    final card = cardMatch?.group(1)?.trim() ?? 'HDFC Card';

    return ParsedSmsTransaction(
      amount: amount,
      currency: 'INR',
      type: SmsTransactionType.debit,
      merchant: MerchantNormalizer.normalize(rawMerchant),
      bankName: 'HDFC',
      sender: sender,
      paymentMethod: 'Card',
      accountOrCard: card,
      dateTime: date,
      rawSms: body,
      smsHash: hash,
    );
  }
}

class GenericSmsParser {
  static String calculateHash(String input) {
    var hash = 0xcbf29ce484222325;
    for (var i = 0; i < input.length; i++) {
      hash = hash ^ input.codeUnitAt(i);
      hash = hash * 0x100000001b3;
    }
    return hash.toUnsigned(64).toRadixString(16);
  }

  static bool isTransactionSms(String sender, String body) {
    final cleaned = body.toLowerCase();
    
    // Ignore spam, otp, marketing
    final ignoreKeywords = [
      'otp', 'verification code', 'verification pin', 'one-time password', 'one time password',
      'promo', 'discount', 'cashback up to', 'win ', 'congratulations',
      'delivered', 'delivery', 'shipped', 'order placed', 'parcel', 'tracking',
      'subscribe', 'subscription renew', 'recharge successful', 'bill generated',
      'prepaid plan', 'marketing', 'ad:', 'apply now', 'get free', 'invest now', 'offered'
    ];
    for (final keyword in ignoreKeywords) {
      if (cleaned.contains(keyword)) {
        return false;
      }
    }

    final hasAmount = RegExp(r'(?:rs\.?|inr|usd|\$)\s*[0-9,]+(?:\.[0-9]+)?', caseSensitive: false).hasMatch(cleaned);
    if (!hasAmount) return false;

    final transactionKeywords = [
      'spent', 'spent on', 'debited', 'paid to', 'paid for', 'payment of', 'withdrawn', 'withdrawal',
      'credited', 'received', 'refunded', 'salary', 'deposit', 'deposited', 'added', 'transferred',
      'txn', 'transaction', 'transfer to', 'refund'
    ];
    
    for (final keyword in transactionKeywords) {
      if (cleaned.contains(keyword)) {
        return true;
      }
    }
    
    return false;
  }

  static ParsedSmsTransaction parse(
      String sender, String body, DateTime date, String baseCurrency) {
    final hash = calculateHash('$sender|$body|${date.millisecondsSinceEpoch}');
    
    // Extensible format rules
    final rules = <SmsFormatRule>[
      HdfcCardRule(),
    ];

    for (final rule in rules) {
      if (rule.matches(sender, body)) {
        return rule.parse(sender, body, date, hash, baseCurrency);
      }
    }

    // Fallback Generic Parsing
    final amountMatch = RegExp(r'(?:rs\.?|inr|usd|\$)\s*([0-9,]+(?:\.[0-9]{1,2})?)', caseSensitive: false).firstMatch(body);
    final amount = double.tryParse(amountMatch?.group(1)?.replaceAll(',', '') ?? '0') ?? 0.0;

    final currency = body.toLowerCase().contains('usd') || body.contains('\$') ? 'USD' : 'INR';

    // Type detection
    SmsTransactionType type = SmsTransactionType.debit;
    final creditKeywords = ['credited', 'received', 'refunded', 'refund', 'salary', 'deposit', 'deposited', 'added', 'interest'];
    for (final keyword in creditKeywords) {
      if (body.toLowerCase().contains(keyword)) {
        type = SmsTransactionType.credit;
        break;
      }
    }

    // Extract Merchant
    String rawMerchant = 'Unknown';
    if (type == SmsTransactionType.debit) {
      final merchantMatch = RegExp(r'(?:at|paid to|transfer to|sent to|spent on)\s+([A-Za-z0-9\s#\-]+?)(?:\.|\s+on|\s+dt|\s+date|\s+txn|\s+bal|\s+avail|\s+ending|$)', caseSensitive: false).firstMatch(body);
      if (merchantMatch != null) {
        rawMerchant = merchantMatch.group(1)!.trim();
      }
    } else {
      if (body.toLowerCase().contains('salary')) {
        rawMerchant = 'Salary';
      } else if (body.toLowerCase().contains('refund')) {
        rawMerchant = 'Refund';
      } else if (body.toLowerCase().contains('interest')) {
        rawMerchant = 'Interest';
      } else {
        final fromMatch = RegExp(r'(?:from|by)\s+([A-Za-z0-9\s#\-]+?)(?:\.|\s+on|\s+dt|\s+date|\s+txn|\s+bal|$)', caseSensitive: false).firstMatch(body);
        if (fromMatch != null) {
          rawMerchant = fromMatch.group(1)!.trim();
        }
      }
    }

    // Clean up merchant if it captured too much trailing text
    if (rawMerchant.contains('txn') || rawMerchant.contains('transaction') || rawMerchant.contains('avail') || rawMerchant.contains('bal')) {
      rawMerchant = rawMerchant.split(RegExp(r'\s+(?:txn|transaction|bal|avail)\b'))[0].trim();
    }

    // Extract Bank Name from sender address
    String bankName = 'Unknown Bank';
    final senderUpper = sender.toUpperCase();
    if (senderUpper.contains('HDFC')) {
      bankName = 'HDFC';
    } else if (senderUpper.contains('ICICI')) {
      bankName = 'ICICI';
    } else if (senderUpper.contains('SBI')) {
      bankName = 'SBI';
    } else if (senderUpper.contains('AXIS')) {
      bankName = 'Axis';
    } else if (senderUpper.contains('KOTAK')) {
      bankName = 'Kotak';
    } else if (senderUpper.contains('PNB')) {
      bankName = 'PNB';
    } else if (senderUpper.contains('BOB')) {
      bankName = 'BOB';
    }

    // Extract Payment Method
    String paymentMethod = 'Bank Account';
    if (body.toLowerCase().contains('upi')) {
      paymentMethod = 'UPI';
    } else if (body.toLowerCase().contains('card') || body.toLowerCase().contains('visa') || body.toLowerCase().contains('mastercard') || body.toLowerCase().contains('rupay')) {
      paymentMethod = 'Card';
    } else if (body.toLowerCase().contains('atm') || body.toLowerCase().contains('cash withdrawal')) {
      paymentMethod = 'ATM';
    } else if (body.toLowerCase().contains('neft')) {
      paymentMethod = 'NEFT';
    } else if (body.toLowerCase().contains('imps')) {
      paymentMethod = 'IMPS';
    } else if (body.toLowerCase().contains('rtgs')) {
      paymentMethod = 'RTGS';
    } else if (body.toLowerCase().contains('wallet') || body.toLowerCase().contains('paytm') || body.toLowerCase().contains('phonepe') || body.toLowerCase().contains('gpay')) {
      paymentMethod = 'Wallet';
    }

    // Extract Account/Card suffix
    String accountOrCard = 'Account';
    final cardMatch = RegExp(r'(?:card|ending in|xx|a/c|acct|account)\s*([0-9Xx]{2,6})', caseSensitive: false).firstMatch(body);
    if (cardMatch != null) {
      accountOrCard = 'Account ending in ${cardMatch.group(1)}';
    }

    // Extract Reference Number
    String? referenceNumber;
    final refMatch = RegExp(r'(?:ref|txn|utr|id)\.?\s*(?:no|num)?\.?\s*[:\-]?\s*([0-9a-zA-Z]+)', caseSensitive: false).firstMatch(body);
    if (refMatch != null) {
      referenceNumber = refMatch.group(1);
    }

    // Extract Balance
    double? balance;
    final balMatch = RegExp(r'(?:bal|balance|avail|available)\s*(?:is)?\s*(?:rs\.?|inr)?\s*([0-9,]+(?:\.[0-9]{1,2})?)', caseSensitive: false).firstMatch(body);
    if (balMatch != null) {
      balance = double.tryParse(balMatch.group(1)!.replaceAll(',', ''));
    }

    // Extract UPI ID
    String? upiId;
    final upiMatch = RegExp(r'([a-zA-Z0-9.\-_]+@[a-zA-Z0-9]+)').firstMatch(body);
    if (upiMatch != null) {
      upiId = upiMatch.group(1);
    }

    return ParsedSmsTransaction(
      amount: amount,
      currency: currency,
      type: type,
      merchant: MerchantNormalizer.normalize(rawMerchant),
      bankName: bankName,
      sender: sender,
      paymentMethod: paymentMethod,
      accountOrCard: accountOrCard,
      dateTime: date,
      referenceNumber: referenceNumber,
      balance: balance,
      upiId: upiId,
      rawSms: body,
      smsHash: hash,
    );
  }
}
