import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

// ==========================================
// 1. MODELS (โครงสร้างข้อมูล)
// ==========================================

// Model สำหรับ List (ข้อมูลเบื้องต้นแสดงหน้ารวม)
class PokemonListEntry {
  final String name;
  final String url;
  final int id;

  PokemonListEntry({required this.name, required this.url, required this.id});

  factory PokemonListEntry.fromJson(Map<String, dynamic> json, int index) {
    // ดึง ID จาก URL เพื่อความแม่นยำ
    final urlParts = json['url'].toString().split('/');
    final id = int.parse(urlParts[urlParts.length - 2]);
    return PokemonListEntry(name: json['name'], url: json['url'], id: id);
  }
}

// Model สำหรับ Detail (ข้อมูลเจาะลึก)
class PokemonDetail {
  final int id;
  final String name;
  final int height;
  final int weight;
  final List<String> types;
  final Map<String, int> stats; // hp, attack, defense, etc.

  PokemonDetail({
    required this.id,
    required this.name,
    required this.height,
    required this.weight,
    required this.types,
    required this.stats,
  });

  factory PokemonDetail.fromJson(Map<String, dynamic> json) {
    return PokemonDetail(
      id: json['id'],
      name: json['name'],
      height: json['height'],
      weight: json['weight'],
      types: (json['types'] as List)
          .map((t) => t['type']['name'].toString())
          .toList(),
      stats: Map.fromEntries((json['stats'] as List).map((s) => MapEntry(
            s['stat']['name'].toString(),
            s['base_stat'] as int,
          ))),
    );
  }
}

// ==========================================
// 2. CONSTANTS & HELPERS (ค่าคงที่และฟังก์ชันช่วย)
// ==========================================

// ช่วง ID ของแต่ละ Gen
const Map<String, List<int>> generationRanges = {
  'Gen 1': [1, 151],
  'Gen 2': [152, 251],
  'Gen 3': [252, 386],
  'Gen 4': [387, 493],
  'Gen 5': [494, 649],
};

// เลือกสีตามธาตุ
Color getTypeColor(String type) {
  switch (type) {
    case 'fire': return const Color(0xFFFA6C6C);
    case 'water': return const Color(0xFF6890F0);
    case 'grass': return const Color(0xFF48CFB2);
    case 'electric': return const Color(0xFFFFCE4B);
    case 'psychic': return const Color(0xFFF85888);
    case 'poison': return const Color(0xFFA040A0);
    case 'bug': return const Color(0xFFA8B820);
    case 'ground': return const Color(0xFFE0C068);
    case 'rock': return const Color(0xFFB8A038);
    case 'fairy': return const Color(0xFFEE99AC);
    case 'dragon': return const Color(0xFF7038F8);
    case 'ice': return const Color(0xFF98D8D8);
    case 'fighting': return const Color(0xFFC03028);
    case 'ghost': return const Color(0xFF705898);
    case 'steel': return const Color(0xFFB8B8D0);
    case 'flying': return const Color(0xFFA98FF3);
    case 'dark': return const Color(0xFF705746);
    default: return const Color(0xFFA8A878); // Normal
  }
}

// ==========================================
// 3. MAIN APP (จุดเริ่มต้นแอป)
// ==========================================

void main() {
  runApp(const PokedexApp());
}

class PokedexApp extends StatelessWidget {
  const PokedexApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Pro Pokedex',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.redAccent),
        scaffoldBackgroundColor: const Color(0xFFF5F5F5),
        fontFamily: 'Roboto', // ใช้ฟอนต์มาตรฐานให้อ่านง่าย
      ),
      home: const PokemonListScreen(),
    );
  }
}

// ==========================================
// 4. SCREEN 1: LIST SCREEN (หน้ารวม)
// ==========================================

class PokemonListScreen extends StatefulWidget {
  const PokemonListScreen({super.key});

  @override
  State<PokemonListScreen> createState() => _PokemonListScreenState();
}

class _PokemonListScreenState extends State<PokemonListScreen> {
  List<PokemonListEntry> _allPokemon = [];
  List<PokemonListEntry> _filteredPokemon = [];
  bool _isLoading = true;
  String _selectedGen = 'Gen 1';
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _fetchInitialData();
  }

  // ดึงข้อมูลครั้งเดียว เก็บลง _allPokemon
  Future<void> _fetchInitialData() async {
    try {
      // ดึงถึง Gen 5 (649 ตัว)
      final response = await http.get(
          Uri.parse('https://pokeapi.co/api/v2/pokemon?limit=649'));
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final results = data['results'] as List;
        
        setState(() {
          _allPokemon = results.asMap().entries.map((e) {
            return PokemonListEntry.fromJson(e.value, e.key);
          }).toList();
          _filterData(); // กรองข้อมูลครั้งแรก
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint("Error: $e");
    }
  }

  // ฟังก์ชันกรองข้อมูล (Search + Gen Filter)
  void _filterData() {
    final range = generationRanges[_selectedGen]!;
    final query = _searchController.text.toLowerCase();

    setState(() {
      _filteredPokemon = _allPokemon.where((pokemon) {
        final bool inGen = pokemon.id >= range[0] && pokemon.id <= range[1];
        final bool matchesSearch = pokemon.name.toLowerCase().contains(query);
        return inGen && matchesSearch;
      }).toList();
    });
  }

  @override
  Widget build(BuildContext context) {
    // Responsive Logic: เช็คความกว้างหน้าจอ
    double screenWidth = MediaQuery.of(context).size.width;
    // PC (>600px) โชว์ 6 คอลัมน์, มือถือ โชว์ 3 คอลัมน์
    int crossAxisCount = screenWidth > 600 ? 6 : 3;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Pokedex', style: TextStyle(fontWeight: FontWeight.w900, letterSpacing: 1.5)),
        centerTitle: true,
        backgroundColor: Colors.redAccent,
        foregroundColor: Colors.white,
        elevation: 0,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(bottom: Radius.circular(20)),
        ),
      ),
      body: Column(
        children: [
          // 1. Search Bar
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 20, 16, 10),
            child: TextField(
              controller: _searchController,
              onChanged: (value) => _filterData(),
              decoration: InputDecoration(
                hintText: 'Search for a Pokémon by name...',
                prefixIcon: const Icon(Icons.search, color: Colors.redAccent),
                filled: true,
                fillColor: Colors.white,
                contentPadding: const EdgeInsets.symmetric(vertical: 0),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(30),
                  borderSide: BorderSide.none,
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(30),
                  borderSide: BorderSide(color: Colors.grey.shade300),
                ),
              ),
            ),
          ),

          // 2. Gen Filter Chips
          SizedBox(
            height: 50,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              children: generationRanges.keys.map((gen) {
                final isSelected = _selectedGen == gen;
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: ChoiceChip(
                    label: Text(gen),
                    selected: isSelected,
                    onSelected: (bool selected) {
                      if (selected) {
                        setState(() {
                          _selectedGen = gen;
                          _searchController.clear();
                          _filterData();
                        });
                      }
                    },
                    selectedColor: Colors.redAccent,
                    labelStyle: TextStyle(
                      color: isSelected ? Colors.white : Colors.black87,
                      fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                    ),
                    backgroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                  ),
                );
              }).toList(),
            ),
          ),

          const SizedBox(height: 10),

          // 3. Grid View
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _filteredPokemon.isEmpty 
                  ? const Center(child: Text("ไม่พบ Pokemon ที่ค้นหา"))
                  : GridView.builder(
                    padding: const EdgeInsets.all(12),
                    gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: crossAxisCount,
                      childAspectRatio: 0.75, // สัดส่วนสูงกว่ากว้าง (แนวตั้ง)
                      crossAxisSpacing: 10,
                      mainAxisSpacing: 10,
                    ),
                    itemCount: _filteredPokemon.length,
                    itemBuilder: (context, index) {
                      final pokemon = _filteredPokemon[index];
                      // ใช้รูป Official Artwork
                      final imageUrl = 'https://raw.githubusercontent.com/PokeAPI/sprites/master/sprites/pokemon/other/official-artwork/${pokemon.id}.png';

                      return GestureDetector(
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => PokemonDetailScreen(pokemonEntry: pokemon),
                            ),
                          );
                        },
                        child: Card(
                          elevation: 2,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                          color: Colors.white,
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              // Hero Animation: เชื่อมรูปภาพไปหน้าถัดไป
                              Expanded(
                                flex: 3,
                                child: Hero(
                                  tag: 'pokemon-img-${pokemon.id}',
                                  child: Image.network(
                                    imageUrl, 
                                    fit: BoxFit.contain,
                                    errorBuilder: (c,e,s) => const Icon(Icons.broken_image, color: Colors.grey),
                                  ),
                                ),
                              ),
                              Expanded(
                                flex: 1,
                                child: Column(
                                  children: [
                                    Text(
                                      pokemon.name.toUpperCase(),
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: screenWidth > 600 ? 14 : 11, // ปรับขนาดฟอนต์
                                      ),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    Text(
                                      '#${pokemon.id.toString().padLeft(3, '0')}',
                                      style: TextStyle(
                                        color: Colors.grey,
                                        fontSize: screenWidth > 600 ? 12 : 10,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

// ==========================================
// 5. SCREEN 2: DETAIL SCREEN (หน้าแสดงรายละเอียด)
// ==========================================

class PokemonDetailScreen extends StatefulWidget {
  final PokemonListEntry pokemonEntry;

  const PokemonDetailScreen({super.key, required this.pokemonEntry});

  @override
  State<PokemonDetailScreen> createState() => _PokemonDetailScreenState();
}

class _PokemonDetailScreenState extends State<PokemonDetailScreen> {
  late Future<PokemonDetail> _detailFuture;

  @override
  void initState() {
    super.initState();
    _detailFuture = _fetchPokemonDetail();
  }

  Future<PokemonDetail> _fetchPokemonDetail() async {
    final response = await http.get(Uri.parse(widget.pokemonEntry.url));
    if (response.statusCode == 200) {
      return PokemonDetail.fromJson(json.decode(response.body));
    } else {
      throw Exception('Failed to load detail');
    }
  }

  @override
  Widget build(BuildContext context) {
    final imageUrl = 'https://raw.githubusercontent.com/PokeAPI/sprites/master/sprites/pokemon/other/official-artwork/${widget.pokemonEntry.id}.png';

    return Scaffold(
      backgroundColor: Colors.white,
      body: FutureBuilder<PokemonDetail>(
        future: _detailFuture,
        builder: (context, snapshot) {
          // กรณีโหลดอยู่: แสดง Loading แต่ยังโชว์สีพื้นหลังและรูป Hero ได้ (ถ้าออกแบบเพิ่ม)
          // แต่เพื่อความง่าย เราใช้ CircularProgressIndicator ก่อน
          if (snapshot.connectionState == ConnectionState.waiting) {
             return const Center(child: CircularProgressIndicator());
          } 
          
          if (snapshot.hasError) {
             return Center(child: Text("Error: ${snapshot.error}"));
          }

          if (snapshot.hasData) {
            final detail = snapshot.data!;
            Color primaryColor = getTypeColor(detail.types.first);

            return CustomScrollView(
              slivers: [
                // ส่วนหัว AppBar + รูปภาพ (SliverAppBar)
                SliverAppBar(
                  expandedHeight: 300,
                  backgroundColor: primaryColor,
                  pinned: true,
                  flexibleSpace: FlexibleSpaceBar(
                    background: Container(
                      color: primaryColor,
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          // วงกลมตกแต่งด้านหลัง
                          Positioned(
                            top: -50,
                            right: -50,
                            child: CircleAvatar(
                              radius: 130,
                              backgroundColor: Colors.white.withOpacity(0.2),
                            ),
                          ),
                          Positioned(
                            bottom: 20,
                            child: Hero(
                              tag: 'pokemon-img-${widget.pokemonEntry.id}',
                              child: Image.network(imageUrl, height: 200),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                
                // ส่วนเนื้อหาด้านล่าง
                SliverToBoxAdapter(
                  child: Container(
                    decoration: const BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
                    ),
                    transform: Matrix4.translationValues(0.0, -20.0, 0.0), // ดันขึ้นไปทับ AppBar นิดหน่อย
                    child: Padding(
                      padding: const EdgeInsets.all(24.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // ชื่อและประเภท
                          Center(
                            child: Column(
                              children: [
                                Text(
                                  detail.name.toUpperCase(),
                                  style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w900),
                                ),
                                const SizedBox(height: 10),
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: detail.types.map((type) => Container(
                                    margin: const EdgeInsets.symmetric(horizontal: 5),
                                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                                    decoration: BoxDecoration(
                                      color: getTypeColor(type),
                                      borderRadius: BorderRadius.circular(20),
                                    ),
                                    child: Text(
                                      type.toUpperCase(),
                                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                                    ),
                                  )).toList(),
                                ),
                              ],
                            ),
                          ),
                          
                          const SizedBox(height: 30),
                          
                          // ขนาดตัว (Height / Weight)
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                            children: [
                              _buildAttributeColumn('Weight', '${detail.weight / 10} kg', Icons.fitness_center),
                              _buildAttributeColumn('Height', '${detail.height / 10} m', Icons.height),
                            ],
                          ),

                          const SizedBox(height: 30),
                          const Text("Base Stats", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                          const SizedBox(height: 15),
                          
                          // กราฟพลัง
                          ...detail.stats.entries.map((entry) {
                            return _buildStatRow(entry.key, entry.value, primaryColor);
                          }),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            );
          }
          return const SizedBox();
        },
      ),
    );
  }

  Widget _buildAttributeColumn(String label, String value, IconData icon) {
    return Column(
      children: [
        Icon(icon, color: Colors.grey[400]),
        const SizedBox(height: 5),
        Text(value, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        Text(label, style: const TextStyle(color: Colors.grey)),
      ],
    );
  }

  Widget _buildStatRow(String label, int value, Color color) {
    // แปลงชื่อ Stat ย่อๆ
    String shortLabel = label;
    if (label == 'special-attack') shortLabel = 'Sp. Atk';
    if (label == 'special-defense') shortLabel = 'Sp. Def';

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          SizedBox(
            width: 70,
            child: Text(
              shortLabel.toUpperCase(),
              style: TextStyle(color: Colors.grey[600], fontWeight: FontWeight.bold, fontSize: 12),
            ),
          ),
          SizedBox(
            width: 30,
            child: Text('$value', style: const TextStyle(fontWeight: FontWeight.bold)),
          ),
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: LinearProgressIndicator(
                value: value / 150, // เทียบกับค่า Max ประมาณ 150
                backgroundColor: Colors.grey[200],
                color: color,
                minHeight: 10,
              ),
            ),
          ),
        ],
      ),
    );
  }
}