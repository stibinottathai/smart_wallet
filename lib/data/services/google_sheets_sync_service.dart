import 'dart:convert';
import 'dart:math';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/foundation.dart';
import '../../domain/models/models.dart' as domain;

/// Debug flag - set to true to enable verbose logging
const bool _debugSync = true;

void _log(String message) {
  if (_debugSync) {
    debugPrint('[GoogleSheetsSync] $message');
  }
}

class GoogleSheetsSyncResult {
  final bool success;
  final String? errorMessage;
  final String? spreadsheetName;
  final String? spreadsheetUrl;

  GoogleSheetsSyncResult({
    required this.success,
    this.errorMessage,
    this.spreadsheetName,
    this.spreadsheetUrl,
  });
}

class GoogleSheetsSyncService {
  static const _webAppUrlKey = 'google_sheets_webapp_url';

  /// Fetches the configured Web App URL from SharedPreferences
  Future<String> getSavedUrl() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_webAppUrlKey) ?? '';
  }

  /// Saves the Web App URL to SharedPreferences
  Future<void> saveUrl(String url) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_webAppUrlKey, url.trim());
  }

  /// Validates the Web App URL format
  static String? validateWebAppUrl(String url) {
    final trimmed = url.trim();
    if (trimmed.isEmpty) return 'URL cannot be empty';
    if (!trimmed.startsWith('https://script.google.com/macros/s/')) {
      return 'Invalid URL format. Must start with https://script.google.com/macros/s/. Do not copy the redirected URL from your browser.';
    }
    if (!trimmed.contains('/exec')) {
      return 'URL must end with /exec (not /dev). Deploy a new version in Apps Script to get the production URL.';
    }
    return null;
  }

  /// Test connection to the Web App URL without syncing data
  /// Sends a 'test: true' flag so Apps Script can return sheet info without clearing data
  Future<GoogleSheetsSyncResult> testConnection({required String webAppUrl}) async {
    _log('Testing connection to: $webAppUrl');
    
    final validationError = validateWebAppUrl(webAppUrl);
    if (validationError != null) {
      return GoogleSheetsSyncResult(success: false, errorMessage: validationError);
    }

    try {
      final response = await _postWithRedirects(
        webAppUrl,
        headers: {'Content-Type': 'text/plain'},
        body: jsonEncode({'test': true}),
      );

      _log('Test connection response: ${response.statusCode}');
      _log('Response body: ${response.body.substring(0, min(200, response.body.length))}');

      if (response.statusCode != 200) {
        return GoogleSheetsSyncResult(
          success: false,
          errorMessage: 'Server responded with code ${response.statusCode}. Check Web App deployment.',
        );
      }

      final contentType = response.headers['content-type'] ?? '';
      if (contentType.contains('text/html') || response.body.trim().startsWith('<')) {
        return GoogleSheetsSyncResult(
          success: false,
          errorMessage: 'Received HTML instead of JSON. Ensure Web App is deployed with "Anyone" access and you deployed a NEW VERSION.',
        );
      }

      final Map<String, dynamic> body = jsonDecode(response.body);
      if (body['success'] == true) {
        return GoogleSheetsSyncResult(
          success: true,
          spreadsheetName: body['spreadsheetName'] as String?,
          spreadsheetUrl: body['spreadsheetUrl'] as String?,
        );
      } else {
        return GoogleSheetsSyncResult(
          success: false,
          errorMessage: body['error'] ?? 'Apps Script returned error.',
        );
      }
    } catch (e) {
      _log('Test connection failed: $e');
      return GoogleSheetsSyncResult(
        success: false,
        errorMessage: 'Connection failed: ${e.toString()}',
      );
    }
  }

  /// Backs up the entire database to the configured Google Sheet Web App URL
  Future<GoogleSheetsSyncResult> syncDatabase({
    required List<domain.Expense> expenses,
    required List<domain.Income> incomes,
    required List<domain.Category> categories,
    required String webAppUrl,
  }) async {
    _log('Starting syncDatabase');
    _log('Incomes: ${incomes.length}, Expenses: ${expenses.length}, Categories: ${categories.length}');
    
    final validationError = validateWebAppUrl(webAppUrl);
    if (validationError != null) {
      return GoogleSheetsSyncResult(
        success: false,
        errorMessage: validationError,
      );
    }

    final categoryMap = {for (var c in categories) c.id: c.name};
    _log('Category map built: ${categoryMap.length} entries');

    // Format incomes payload
    final incomesPayload = incomes.map((inc) {
      return {
        'id': inc.id,
        'date': inc.date.toIso8601String().substring(0, 10),
        'source': inc.source,
        'amount': inc.amount,
        'isRecurring': inc.isRecurring,
        'frequency': inc.frequency.displayName,
      };
    }).toList();

    // Format expenses payload
    final expensesPayload = expenses.map((exp) {
      return {
        'id': exp.id,
        'date': exp.date.toIso8601String().substring(0, 10),
        'category': categoryMap[exp.categoryId] ?? 'Uncategorized',
        'amount': exp.amount,
        'note': exp.note ?? '',
        'source': exp.source.name,
      };
    }).toList();

    _log('Payload prepared. Sending POST request...');

    try {
      final response = await _postWithRedirects(
        webAppUrl,
        headers: {
          'Content-Type': 'text/plain',
        },
        body: jsonEncode({
          'incomes': incomesPayload,
          'expenses': expensesPayload,
        }),
      );

      _log('Response status: ${response.statusCode}');
      _log('Response headers: ${response.headers}');
      _log('Response body (first 500 chars): ${response.body.substring(0, min(500, response.body.length))}');

      if (response.statusCode != 200) {
        return GoogleSheetsSyncResult(
          success: false,
          errorMessage: 'Server responded with code ${response.statusCode}. Check Web App URL and deployment.',
        );
      }

      final contentType = response.headers['content-type'] ?? '';
      if (contentType.contains('text/html') || response.body.trim().startsWith('<')) {
        return GoogleSheetsSyncResult(
          success: false,
          errorMessage: 'Received HTML instead of JSON.\n\n'
              'FIX: In Google Apps Script:\n'
              '1. Open your sheet → Extensions → Apps Script\n'
              '2. Click Deploy → Manage deployments\n'
              '3. Click the pencil icon → New version → Deploy\n'
              '4. Set "Execute as: Me" and "Who has access: Anyone"\n'
              '5. Copy the NEW Web App URL (ends with /exec)',
        );
      }

      final Map<String, dynamic> body = jsonDecode(response.body);
      _log('Parsed response: $body');
      
      if (body['success'] == true) {
        return GoogleSheetsSyncResult(
          success: true,
          spreadsheetName: body['spreadsheetName'] as String?,
          spreadsheetUrl: body['spreadsheetUrl'] as String?,
        );
      } else {
        return GoogleSheetsSyncResult(
          success: false,
          errorMessage: body['error'] ?? 'Unknown error occurred on Apps Script server.',
        );
      }
    } catch (e) {
      _log('Sync exception: $e');
      return GoogleSheetsSyncResult(
        success: false,
        errorMessage: 'Connection failed: ${e.toString()}. Check internet and URL.',
      );
    }
  }

  Future<http.Response> _postWithRedirects(
    String url, {
    required Map<String, String> headers,
    required String body,
  }) async {
    final client = http.Client();
    try {
      var currentUrl = url;
      var currentMethod = 'POST';
      var currentHeaders = Map<String, String>.from(headers);
      var currentBody = body;

      int redirectCount = 0;
      const maxRedirects = 10;

      while (redirectCount < maxRedirects) {
        final uri = Uri.parse(currentUrl);
        final request = http.Request(currentMethod, uri);

        request.followRedirects = false; // We handle redirects manually
        request.headers.addAll(currentHeaders);
        if (currentMethod == 'POST') {
          request.body = currentBody;
        }

        final streamedResponse = await client.send(request);
        final response = await http.Response.fromStream(streamedResponse);

        if (response.statusCode == 301 ||
            response.statusCode == 302 ||
            response.statusCode == 303 ||
            response.statusCode == 307 ||
            response.statusCode == 308) {
          final location = response.headers['location'];
          if (location == null || location.isEmpty) {
            return response; // No location header, return redirect response as is
          }

          // Resolve relative redirect location against current URL
          final resolvedUri = uri.resolve(location);
          currentUrl = resolvedUri.toString();
          redirectCount++;

          // Determine method and body for next request in redirect chain
          if (response.statusCode == 301 ||
              response.statusCode == 302 ||
              response.statusCode == 303) {
            currentMethod = 'GET';
            currentHeaders.remove('Content-Type'); // content type not needed for GET
            currentBody = '';
          }
        } else {
          return response; // Not a redirect, return response
        }
      }

      throw http.ClientException('Redirect loop detected or exceeded max redirects ($maxRedirects)');
    } finally {
      client.close();
    }
  }
}
