import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/collar.dart';

class EspCommService {
  // ESP32 SoftAP default gateway IP — change if yours differs
  static const String _baseUrl = 'http://192.168.4.1/data';

  Future<List<Collar>> fetchCollars() async {
    final response = await http
        .get(Uri.parse(_baseUrl))
        .timeout(const Duration(seconds: 5));

    if (response.statusCode != 200) {
      throw Exception('ESP32 returned ${response.statusCode}');
    }

    final List<dynamic> data = jsonDecode(response.body);
    return data.map((j) => Collar.fromJson(j as Map<String, dynamic>)).toList();
  }
}