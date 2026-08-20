import 'dart:convert';
import 'package:http/http.dart' as http;

// Chrome/desktop demo default. On an Android emulator use 10.0.2.2 instead
// of 127.0.0.1; on a physical device use your machine's LAN IP.
const String kApiBaseUrl = 'http://127.0.0.1:5000';

class QuestionSchema {
  final String key;
  final String label;
  final List<String> options;

  QuestionSchema({required this.key, required this.label, required this.options});

  factory QuestionSchema.fromJson(Map<String, dynamic> json) {
    return QuestionSchema(
      key: json['key'],
      label: json['label'],
      options: List<String>.from(json['options']),
    );
  }
}

class AppSchema {
  final QuestionSchema age;
  final List<QuestionSchema> symptoms;
  final String disclaimer;

  AppSchema({required this.age, required this.symptoms, required this.disclaimer});

  factory AppSchema.fromJson(Map<String, dynamic> json) {
    return AppSchema(
      age: QuestionSchema(
        key: 'Age',
        label: json['age']['label'],
        options: List<String>.from(json['age']['options']),
      ),
      symptoms: (json['symptoms'] as List)
          .map((s) => QuestionSchema.fromJson(s))
          .toList(),
      disclaimer: json['disclaimer'],
    );
  }
}

class RiskFactor {
  final String factor;
  final String direction;
  final double magnitude;

  RiskFactor({required this.factor, required this.direction, required this.magnitude});

  factory RiskFactor.fromJson(Map<String, dynamic> json) {
    return RiskFactor(
      factor: json['factor'],
      direction: json['direction'],
      magnitude: (json['magnitude'] as num).toDouble(),
    );
  }
}

class RiskResult {
  final double riskProbability;
  final String riskBand;
  final List<RiskFactor> topFactors;
  final String disclaimer;

  RiskResult({
    required this.riskProbability,
    required this.riskBand,
    required this.topFactors,
    required this.disclaimer,
  });

  factory RiskResult.fromJson(Map<String, dynamic> json) {
    return RiskResult(
      riskProbability: (json['risk_probability'] as num).toDouble(),
      riskBand: json['risk_band'],
      topFactors: (json['top_factors'] as List)
          .map((f) => RiskFactor.fromJson(f))
          .toList(),
      disclaimer: json['disclaimer'],
    );
  }
}

class AuthResult {
  final String token;
  final String name;
  final String email;
  AuthResult({required this.token, required this.name, required this.email});

  factory AuthResult.fromJson(Map<String, dynamic> json) =>
      AuthResult(token: json['token'], name: json['name'], email: json['email']);
}

class ServerAssessment {
  final String id;
  final DateTime timestamp;
  final double riskProbability;
  final String riskBand;
  final List<RiskFactor> topFactors;
  final String note;

  ServerAssessment({
    required this.id,
    required this.timestamp,
    required this.riskProbability,
    required this.riskBand,
    required this.topFactors,
    required this.note,
  });

  factory ServerAssessment.fromJson(Map<String, dynamic> json) => ServerAssessment(
        id: json['id'],
        timestamp: DateTime.parse(json['timestamp']),
        riskProbability: (json['risk_probability'] as num).toDouble(),
        riskBand: json['risk_band'],
        topFactors: (json['top_factors'] as List).map((f) => RiskFactor.fromJson(f)).toList(),
        note: json['note'] ?? '',
      );
}

class CommunityFactor {
  final String factor;
  final String direction;
  final int count;
  CommunityFactor({required this.factor, required this.direction, required this.count});

  factory CommunityFactor.fromJson(Map<String, dynamic> json) => CommunityFactor(
        factor: json['factor'],
        direction: json['direction'],
        count: json['count'],
      );
}

class CommunityInsights {
  final int totalCheckins;
  final Map<String, double> bandDistribution;
  final List<CommunityFactor> topFactors;

  CommunityInsights({
    required this.totalCheckins,
    required this.bandDistribution,
    required this.topFactors,
  });

  factory CommunityInsights.fromJson(Map<String, dynamic> json) => CommunityInsights(
        totalCheckins: json['total_checkins'],
        bandDistribution: (json['band_distribution'] as Map<String, dynamic>)
            .map((k, v) => MapEntry(k, (v as num).toDouble())),
        topFactors: (json['top_factors'] as List)
            .map((f) => CommunityFactor.fromJson(f))
            .toList(),
      );
}

class ApiException implements Exception {
  final String message;
  ApiException(this.message);
  @override
  String toString() => message;
}

class ApiService {
  static Map<String, String> _authHeaders(String token) => {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      };

  static String _extractError(http.Response res) {
    try {
      final body = jsonDecode(res.body);
      return body['error'] ?? 'Request failed (${res.statusCode})';
    } catch (_) {
      return 'Request failed (${res.statusCode})';
    }
  }

  static Future<AppSchema> fetchSchema() async {
    final res = await http.get(Uri.parse('$kApiBaseUrl/schema'));
    if (res.statusCode != 200) {
      throw Exception('Failed to load schema (${res.statusCode})');
    }
    return AppSchema.fromJson(jsonDecode(res.body));
  }

  static Future<RiskResult> predict(Map<String, String> answers) async {
    final res = await http.post(
      Uri.parse('$kApiBaseUrl/predict'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(answers),
    );
    if (res.statusCode != 200) {
      throw Exception('Prediction failed (${res.statusCode}): ${res.body}');
    }
    return RiskResult.fromJson(jsonDecode(res.body));
  }

  static Future<AuthResult> register(String name, String email, String password) async {
    final res = await http.post(
      Uri.parse('$kApiBaseUrl/auth/register'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'name': name, 'email': email, 'password': password}),
    );
    if (res.statusCode != 200) throw ApiException(_extractError(res));
    return AuthResult.fromJson(jsonDecode(res.body));
  }

  static Future<AuthResult> login(String email, String password) async {
    final res = await http.post(
      Uri.parse('$kApiBaseUrl/auth/login'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'email': email, 'password': password}),
    );
    if (res.statusCode != 200) throw ApiException(_extractError(res));
    return AuthResult.fromJson(jsonDecode(res.body));
  }

  static Future<void> logout(String token) async {
    await http.post(Uri.parse('$kApiBaseUrl/auth/logout'), headers: _authHeaders(token));
  }

  static Future<void> updateName(String token, String name) async {
    final res = await http.patch(
      Uri.parse('$kApiBaseUrl/me'),
      headers: _authHeaders(token),
      body: jsonEncode({'name': name}),
    );
    if (res.statusCode != 200) throw ApiException(_extractError(res));
  }

  static Future<ServerAssessment> saveAssessment(
    String token, {
    required double riskProbability,
    required String riskBand,
    required List<RiskFactor> topFactors,
    String note = '',
  }) async {
    final res = await http.post(
      Uri.parse('$kApiBaseUrl/assessments/save'),
      headers: _authHeaders(token),
      body: jsonEncode({
        'risk_probability': riskProbability,
        'risk_band': riskBand,
        'top_factors': topFactors
            .map((f) => {'factor': f.factor, 'direction': f.direction, 'magnitude': f.magnitude})
            .toList(),
        'note': note,
      }),
    );
    if (res.statusCode != 200) throw ApiException(_extractError(res));
    return ServerAssessment.fromJson(jsonDecode(res.body));
  }

  static Future<List<ServerAssessment>> getAssessments(String token) async {
    final res = await http.get(Uri.parse('$kApiBaseUrl/assessments'), headers: _authHeaders(token));
    if (res.statusCode != 200) throw ApiException(_extractError(res));
    return (jsonDecode(res.body) as List).map((e) => ServerAssessment.fromJson(e)).toList();
  }

  static Future<void> updateNote(String token, String assessmentId, String note) async {
    final res = await http.patch(
      Uri.parse('$kApiBaseUrl/assessments/$assessmentId/note'),
      headers: _authHeaders(token),
      body: jsonEncode({'note': note}),
    );
    if (res.statusCode != 200) throw ApiException(_extractError(res));
  }

  static Future<CommunityInsights> getInsights() async {
    final res = await http.get(Uri.parse('$kApiBaseUrl/insights'));
    if (res.statusCode != 200) throw ApiException(_extractError(res));
    return CommunityInsights.fromJson(jsonDecode(res.body));
  }
}
