import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import '../../domain/models/models.dart' as domain;

class ReceiptItem {
  final String name;
  final double price;
  
  ReceiptItem({required this.name, required this.price});
  
  factory ReceiptItem.fromJson(Map<String, dynamic> json) {
    double parseDouble(dynamic val) {
      if (val is num) return val.toDouble();
      if (val is String) return double.tryParse(val) ?? 0.0;
      return 0.0;
    }
    return ReceiptItem(
      name: json['name'] ?? '',
      price: parseDouble(json['price']),
    );
  }
}

class ReceiptScanResult {
  final String merchantName;
  final DateTime date;
  final String? time;
  final double totalAmount;
  final String currency;
  final String category;
  final List<ReceiptItem> items;

  ReceiptScanResult({
    required this.merchantName,
    required this.date,
    this.time,
    required this.totalAmount,
    required this.currency,
    required this.category,
    required this.items,
  });

  factory ReceiptScanResult.fromJson(Map<String, dynamic> json) {
    if ((json.containsKey('valid_receipt') && json['valid_receipt'] == false) ||
        (json.containsKey('error') && json['error'] == 'not_a_receipt')) {
      return ReceiptScanResult(
        merchantName: 'ERROR_NOT_A_RECEIPT',
        date: DateTime.now(),
        totalAmount: 0.0,
        currency: '',
        category: 'not_a_receipt',
        items: [],
      );
    }

    double parseTotal(dynamic val) {
      if (val is num) return val.toDouble();
      if (val is String) return double.tryParse(val) ?? 0.0;
      return 0.0;
    }

    DateTime parseDate(String? dVal, String? tVal) {
      if (dVal == null || dVal.isEmpty) return DateTime.now();
      
      try {
        // AI should now strictly return YYYY-MM-DD
        String normalizedDate = dVal.trim();
        
        // Validate that it roughly matches YYYY-MM-DD before passing to tryParse 
        // to prevent internal FormatExceptions triggering the debugger
        final dateRegex = RegExp(r'^\d{4}-\d{1,2}-\d{1,2}');
        if (!dateRegex.hasMatch(normalizedDate)) {
          return DateTime.now();
        }

        if (tVal != null && tVal.trim().isNotEmpty) {
          // Just a basic check that time starts with digits
          if (RegExp(r'^\d').hasMatch(tVal.trim())) {
             return DateTime.tryParse('$normalizedDate ${tVal.trim()}') ?? DateTime.tryParse(normalizedDate) ?? DateTime.now();
          }
        }
        return DateTime.tryParse(normalizedDate) ?? DateTime.now();
      } catch (_) {
        return DateTime.now();
      }
    }

    final itemsJson = json['items'] as List<dynamic>? ?? [];

    return ReceiptScanResult(
      merchantName: json['merchant_name'] ?? '',
      date: parseDate(json['date'], json['time']),
      time: json['time'],
      totalAmount: parseTotal(json['total_amount']),
      currency: json['currency'] ?? 'USD',
      category: json['category'] ?? '',
      items: itemsJson.map((i) => ReceiptItem.fromJson(i as Map<String, dynamic>)).toList(),
    );
  }
}

class ReceiptScanService {
  Future<ReceiptScanResult?> scanReceipt({
    required String imagePath,
    required String apiKey,
    required String aiModel,
    required domain.AiProvider aiProvider,
    required List<domain.Category> categories,
  }) async {
    try {
      final file = File(imagePath);
      if (!await file.exists()) {
        throw Exception('Image file not found.');
      }

      // 1. Run OCR with Google ML Kit
      final inputImage = InputImage.fromFilePath(imagePath);
      final textRecognizer = TextRecognizer(script: TextRecognitionScript.latin);
      RecognizedText recognizedText;
      try {
        recognizedText = await textRecognizer.processImage(inputImage);
      } finally {
        textRecognizer.close();
      }

      final extractedText = recognizedText.text;
      if (extractedText.trim().isEmpty) {
        throw Exception('No text detected in the image.');
      }

      final categoryListStr = categories.map((c) => '- "${c.id}": ${c.name}').join('\n');

      // 2. Send extracted text to OpenRouter
      final prompt = '''You are a receipt validation and extraction assistant.

Your first task is to determine whether the OCR text belongs to a genuine receipt, invoice, bill, payment slip, fuel receipt, restaurant receipt, grocery receipt, utility bill, or purchase transaction document.

A valid receipt usually contains several of the following:
- Merchant or store name
- Date and/or time
- Total amount
- Currency
- Item names
- Quantity or price information
- Tax, VAT, GST, or service charge
- Invoice/receipt number
- Payment method

If the OCR text does NOT clearly represent a receipt, invoice, or bill, return ONLY:
{
  "valid_receipt": false,
  "confidence": 0,
  "reason": "Brief explanation"
}

Examples of invalid receipts:
- Selfies or photos of people
- Landscape photos
- Screenshots of social media
- Chat messages
- Documents without purchase information
- Random images containing numbers or dates only
- Business cards
- ID cards
- Bank statements
- Medical reports
- Forms

If the OCR text DOES represent a valid receipt or bill, return ONLY:
{
  "valid_receipt": true,
  "confidence": 95,
  "merchant_name": "",
  "date": "",
  "time": "",
  "total_amount": 0,
  "currency": "",
  "category": "",
  "items": [
    {
      "name": "",
      "price": 0
    }
  ]
}

Rules:
- Return valid JSON only.
- No markdown.
- No explanations outside JSON.
- Confidence must be between 0 and 100.
- If information is missing, use null.
- For category, you MUST select the closest exact category ID from this list:
$categoryListStr
- The "date" field MUST be standardized to EXACTLY "YYYY-MM-DD" format. IMPORTANT FOR UAE RECEIPTS: Always consider DD/MM/YY or DD.MM.YY format first. If you see "21.06.26" or "21/06/26", the last number is the year, so it means 21st of June 2026. You must return "2026-06-21".
- Choose the final payable amount as total_amount.
- Do not guess values that are not present.
- Reject documents that only contain dates, numbers, or unrelated text.

OCR TEXT:
$extractedText''';

      final Map<String, String> headers = {
        'Content-Type': 'application/json',
      };
      if (aiProvider == domain.AiProvider.anthropic) {
        headers['x-api-key'] = apiKey;
        headers['anthropic-version'] = '2023-06-01';
      } else {
        headers['Authorization'] = 'Bearer $apiKey';
        headers['HTTP-Referer'] = 'https://github.com/stibinottathai/smart_wallet';
        headers['X-Title'] = 'Smart Wallet';
      }

      final Map<String, dynamic> payload = {
        'model': aiModel,
        'messages': [
          {
            'role': 'user',
            'content': prompt,
          }
        ],
      };
      if (aiProvider == domain.AiProvider.anthropic) {
        payload['max_tokens'] = 1000;
      } else {
        payload['response_format'] = {'type': 'json_object'};
      }

      final response = await http.post(
        Uri.parse(aiProvider.endpoint),
        headers: headers,
        body: jsonEncode(payload),
      );

      if (response.statusCode != 200) {
        final detail = _extractErrorDetail(response.body, response.statusCode);
        throw Exception('API responded with code ${response.statusCode}: $detail');
      }

      final Map<String, dynamic> bodyDecoded = jsonDecode(response.body);
      String? content;
      if (aiProvider == domain.AiProvider.anthropic) {
        final contentList = bodyDecoded['content'] as List<dynamic>?;
        if (contentList != null && contentList.isNotEmpty) {
          content = contentList[0]['text'] as String?;
        }
      } else {
        final choices = bodyDecoded['choices'] as List<dynamic>?;
        if (choices != null && choices.isNotEmpty) {
          content = choices[0]['message']['content'] as String?;
        }
      }

      if (content == null) {
        throw Exception('Null content returned from AI Provider');
      }

      content = content.trim();
      
      // Robust JSON extraction: find the first '{' and the last '}'
      final startIndex = content.indexOf('{');
      final endIndex = content.lastIndexOf('}');
      
      if (startIndex != -1 && endIndex != -1 && endIndex >= startIndex) {
        content = content.substring(startIndex, endIndex + 1);
      }

      final Map<String, dynamic> decoded = jsonDecode(content);
      return ReceiptScanResult.fromJson(decoded);
    } catch (e) {
      throw Exception('Failed to process receipt: $e');
    }
  }

  String matchCategory(String categoryGuess, List<domain.Category> categories) {
    final guess = categoryGuess.trim();
    if (categories.any((c) => c.id == guess)) {
      return guess;
    }
    // Fallback: search for names
    final lowerGuess = guess.toLowerCase();
    try {
      final cat = categories.firstWhere((c) => c.name.toLowerCase() == lowerGuess);
      return cat.id;
    } catch (_) {
      return categories.first.id;
    }
  }

  String _extractErrorDetail(String body, int statusCode) {
    if (statusCode == 400) {
      return 'Bad Request. The selected model might be unavailable or the API key is not properly configured.';
    } else if (statusCode == 401 || statusCode == 403) {
      return 'Authentication failed. Please verify your API key in the AI Configuration settings.';
    } else if (statusCode == 404) {
      return 'Model not found. The configured model might not exist or may not be available.';
    } else if (statusCode == 429) {
      return 'Rate limit exceeded. Please try again later or check your API credits.';
    }

    try {
      final decoded = jsonDecode(body);
      final err = decoded['error'];
      if (err is Map) {
        final message = err['message'] ?? err['code'] ?? body;
        return message.toString();
      }
    } catch (_) {}
    return body.length > 200 ? 'HTTP $statusCode (see logs)' : body;
  }
}
