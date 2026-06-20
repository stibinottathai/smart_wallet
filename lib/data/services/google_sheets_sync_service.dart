import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../../domain/models/models.dart' as domain;

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

  /// Backs up the entire database to the configured Google Sheet Web App URL
  Future<GoogleSheetsSyncResult> syncDatabase({
    required List<domain.Expense> expenses,
    required List<domain.Income> incomes,
    required List<domain.Category> categories,
    required String webAppUrl,
  }) async {
    if (webAppUrl.trim().isEmpty) {
      return GoogleSheetsSyncResult(
        success: false,
        errorMessage: 'Google Sheets Web App URL is not configured.',
      );
    }

    final categoryMap = {for (var c in categories) c.id: c.name};

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

    try {
      final response = await _postWithRedirects(
        webAppUrl,
        headers: {
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'incomes': incomesPayload,
          'expenses': expensesPayload,
        }),
      );

      if (response.statusCode != 200) {
        return GoogleSheetsSyncResult(
          success: false,
          errorMessage: 'Server responded with code ${response.statusCode}.',
        );
      }

      final contentType = response.headers['content-type'] ?? '';
      if (contentType.contains('text/html') || response.body.trim().startsWith('<')) {
        return GoogleSheetsSyncResult(
          success: false,
          errorMessage: 'Received HTML instead of JSON. This usually means your Web App deployment settings are restricting access. Please ensure that in Google Apps Script under "Deploy > Manage Deployments", "Who has access" is set to "Anyone" and you have deployed a new version of the Web App.',
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
          errorMessage: body['error'] ?? 'Unknown error occurred on Apps Script server.',
        );
      }
    } catch (e) {
      return GoogleSheetsSyncResult(
        success: false,
        errorMessage: 'Connection failed: ${e.toString()}',
      );
    }
  }

  /// Performs a POST request and manually follows redirects (such as Google Apps Script 302 Found)
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
