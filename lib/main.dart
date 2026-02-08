import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

// 1. Model Class: แบบแปลนสำหรับข้อมูล Pokemon
class Pokemon {
  final String name;
  final String url;
  final int id;

  Pokemon({required this.name, required this.url, required this.id});

  factory Pokemon.fromJson(Map<String, dynamic> json, int index) {
    // ดึง ID จาก index+1 เพราะ API ไม่ส่ง ID มาให้ใน list นี้
    return Pokemon(
      name: json['name'],
      url: json['url'],
      id: index + 1,
    );
  }
}

void main() {
  runApp(const PokedexApp());
}

class PokedexApp extends StatelessWidget {
  const PokedexApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Pokedex Demo',
      theme: ThemeData(
        primarySwatch: Colors.red,
        useMaterial3: true,
      ),
      home: const PokemonListScreen(),
    );
  }
}

class PokemonListScreen extends StatefulWidget {
  const PokemonListScreen({super.key});

  @override
  State<PokemonListScreen> createState() => _PokemonListScreenState();
}

class _PokemonListScreenState extends State<PokemonListScreen> {
  // 2. Future Variable: ตัวแปรเก็บสถานะการดึงข้อมูล
  late Future<List<Pokemon>> futurePokemon;

  @override
  void initState() {
    super.initState();
    futurePokemon = fetchPokemon();
  }

  // 3. API Function: ฟังก์ชันดึงข้อมูลจาก Server
  Future<List<Pokemon>> fetchPokemon() async {
    final response = await http.get(Uri.parse('https://pokeapi.co/api/v2/pokemon?limit=100'));

    if (response.statusCode == 200) {
      final Map<String, dynamic> data = json.decode(response.body);
      final List<dynamic> results = data['results'];

      return results.asMap().entries.map((entry) {
        return Pokemon.fromJson(entry.value, entry.key);
      }).toList();
    } else {
      throw Exception('Failed to load pokemon');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Pokedex Lite'),
        backgroundColor: Colors.redAccent,
        foregroundColor: Colors.white,
      ),
      // 4. FutureBuilder: พระเอกของเรา จัดการสถานะ Loading/Error/Data ให้เอง
      body: FutureBuilder<List<Pokemon>>(
        future: futurePokemon,
        builder: (context, snapshot) {
          if (snapshot.hasData) {
            // กรณีมีข้อมูล: แสดงรายการ
            return ListView.builder(
              itemCount: snapshot.data!.length,
              itemBuilder: (context, index) {
                final pokemon = snapshot.data![index];
                // รูปภาพจาก URL ภายนอก
                final imageUrl = 'https://raw.githubusercontent.com/PokeAPI/sprites/master/sprites/pokemon/${pokemon.id}.png';

                return Card(
                  margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  child: ListTile(
                    leading: Image.network(imageUrl, width: 50, height: 50),
                    title: Text(
                      pokemon.name.toUpperCase(),
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    subtitle: Text('#${pokemon.id.toString().padLeft(3, '0')}'),
                    trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                  ),
                );
              },
            );
          } else if (snapshot.hasError) {
            // กรณีเกิด Error
            return Center(child: Text('${snapshot.error}'));
          }
          // กรณีรอดำเนินการ (Loading)
          return const Center(child: CircularProgressIndicator());
        },
      ),
    );
  }
}