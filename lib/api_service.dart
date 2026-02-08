import 'dart:convert';
import 'package:http/http.dart' as http;

class Pokemon {
  final String name;
  final String imageUrl;

  Pokemon({required this.name, required this.imageUrl});

  // Factory Constructor สำหรับแปลง JSON เป็น Object
  factory Pokemon.fromJson(Map<String, dynamic> json, int index) {
    // ทริค: ใช้ index + 1 เพื่อหาเลข ID ของโปเกมอนสำหรับดึงรูป
    final id = index + 1; 
    return Pokemon(
      name: json['name'],
      imageUrl: 'https://raw.githubusercontent.com/PokeAPI/sprites/master/sprites/pokemon/$id.png',
    );
  }
}

Future<List<Pokemon>> fetchPokemon() async {
  final response = await http.get(Uri.parse('https://pokeapi.co/api/v2/pokemon?limit=20'));

  if (response.statusCode == 200) {
    final Map<String, dynamic> data = json.decode(response.body);
    final List<dynamic> results = data['results'];

    // แปลง List ของ JSON ให้เป็น List ของ Pokemon Object
    return results.asMap().entries.map((entry) {
      int index = entry.key;
      Map<String, dynamic> val = entry.value;
      return Pokemon.fromJson(val, index);
    }).toList();
  } else {
    throw Exception('Failed to load pokemon');
  }
}