import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

// ==========================================
// 1. MODELS
// ==========================================

class PokemonListEntry {
  final String name;
  final String url;
  final int id;

  PokemonListEntry({required this.name, required this.url, required this.id});

  factory PokemonListEntry.fromJson(Map<String, dynamic> json) {
    final urlParts = json['url'].toString().split('/');
    final id = int.parse(urlParts[urlParts.length - 2]);
    return PokemonListEntry(name: json['name'], url: json['url'], id: id);
  }
}

class PokemonDetail {
  final int id;
  final String name;
  final int height;
  final int weight;
  final List<String> types;
  final Map<String, int> stats;
  final String speciesUrl;

  PokemonDetail({
    required this.id,
    required this.name,
    required this.height,
    required this.weight,
    required this.types,
    required this.stats,
    required this.speciesUrl,
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
      speciesUrl: json['species']['url'],
    );
  }
}

class EvolutionNode {
  final String speciesName;
  final int speciesId;
  final List<EvolutionNode> evolvesTo;

  EvolutionNode({required this.speciesName, required this.speciesId, required this.evolvesTo});

  factory EvolutionNode.fromJson(Map<String, dynamic> json) {
    final speciesUrlParts = json['species']['url'].toString().split('/');
    final id = int.parse(speciesUrlParts[speciesUrlParts.length - 2]);
    
    var evolvesTo = <EvolutionNode>[];
    if (json['evolves_to'] != null) {
      evolvesTo = (json['evolves_to'] as List)
          .map((e) => EvolutionNode.fromJson(e))
          .toList();
    }

    return EvolutionNode(
      speciesName: json['species']['name'],
      speciesId: id,
      evolvesTo: evolvesTo,
    );
  }
}

// ==========================================
// 2. CONSTANTS & HELPERS (Updated Gen 6-9)
// ==========================================

const Map<String, List<int>> generationRanges = {
  'All': [1, 1025],
  'Gen 1': [1, 151],
  'Gen 2': [152, 251],
  'Gen 3': [252, 386],
  'Gen 4': [387, 494],
  'Gen 5': [495, 649],
  'Gen 6': [650, 721],  // Kalos
  'Gen 7': [722, 809],  // Alola
  'Gen 8': [810, 905],  // Galar
  'Gen 9': [906, 1025], // Paldea
};

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
    default: return const Color(0xFFA8A878);
  }
}

// ==========================================
// 3. MAIN APP
// ==========================================

void main() {
  runApp(const PokedexApp());
}

class PokedexApp extends StatelessWidget {
  const PokedexApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Ultimate Pokedex',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.redAccent),
        scaffoldBackgroundColor: const Color(0xFFF5F5F5),
        fontFamily: 'Roboto',
      ),
      home: const PokemonListScreen(),
    );
  }
}

// ==========================================
// 4. HOME SCREEN
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
  String _selectedGen = 'All';
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _fetchInitialData();
  }

  // อัปเดต Limit เป็น 1025 เพื่อดึงข้อมูลถึง Gen 9
  Future<void> _fetchInitialData() async {
    try {
      final response = await http.get(
          Uri.parse('https://pokeapi.co/api/v2/pokemon?limit=1025'));
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final results = data['results'] as List;
        
        setState(() {
          _allPokemon = results.map((e) => PokemonListEntry.fromJson(e)).toList();
          _filterData();
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint("Error: $e");
    }
  }

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
    double screenWidth = MediaQuery.of(context).size.width;
    int crossAxisCount = screenWidth > 600 ? 6 : 3;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Pokedex', style: TextStyle(fontWeight: FontWeight.w900)),
        centerTitle: true,
        backgroundColor: Colors.redAccent,
        foregroundColor: Colors.white,
      ),
      body: Column(
        children: [
          // Filter & Search
          Container(
            padding: const EdgeInsets.all(16),
            color: Colors.redAccent,
            child: Column(
              children: [
                TextField(
                  controller: _searchController,
                  onChanged: (value) => _filterData(),
                  decoration: InputDecoration(
                    hintText: 'Search...',
                    prefixIcon: const Icon(Icons.search),
                    filled: true,
                    fillColor: Colors.white,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(30), borderSide: BorderSide.none),
                    contentPadding: EdgeInsets.zero,
                  ),
                ),
                const SizedBox(height: 10),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: generationRanges.keys.map((gen) {
                      return Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: ChoiceChip(
                          label: Text(gen),
                          selected: _selectedGen == gen,
                          onSelected: (bool selected) {
                            if (selected) {
                              setState(() {
                                _selectedGen = gen;
                                _searchController.clear();
                                _filterData();
                              });
                            }
                          },
                          selectedColor: Colors.white,
                          backgroundColor: Colors.redAccent.shade200,
                          labelStyle: TextStyle(color: _selectedGen == gen ? Colors.red : Colors.white),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20), side: BorderSide.none),
                        ),
                      );
                    }).toList(),
                  ),
                )
              ],
            ),
          ),
          
          // Grid
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : GridView.builder(
                    padding: const EdgeInsets.all(12),
                    gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: crossAxisCount,
                      childAspectRatio: 0.7,
                      crossAxisSpacing: 10,
                      mainAxisSpacing: 10,
                    ),
                    itemCount: _filteredPokemon.length,
                    itemBuilder: (context, index) {
                      return PokemonCard(pokemon: _filteredPokemon[index], screenWidth: screenWidth);
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

// ==========================================
// 5. POKEMON CARD (With Type Fetching)
// ==========================================

class PokemonCard extends StatefulWidget {
  final PokemonListEntry pokemon;
  final double screenWidth;

  const PokemonCard({super.key, required this.pokemon, required this.screenWidth});

  @override
  State<PokemonCard> createState() => _PokemonCardState();
}

class _PokemonCardState extends State<PokemonCard> {
  List<String>? _types; 

  @override
  void initState() {
    super.initState();
    _fetchTypes();
  }

  Future<void> _fetchTypes() async {
    try {
      final response = await http.get(Uri.parse(widget.pokemon.url));
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (mounted) {
          setState(() {
            _types = (data['types'] as List)
                .map((t) => t['type']['name'].toString())
                .toList();
          });
        }
      }
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final imageUrl = 'https://raw.githubusercontent.com/PokeAPI/sprites/master/sprites/pokemon/other/official-artwork/${widget.pokemon.id}.png';

    return GestureDetector(
      onTap: () {
        Navigator.push(context, MaterialPageRoute(
            builder: (context) => PokemonDetailScreen(pokemonEntry: widget.pokemon),
        ));
      },
      child: Card(
        elevation: 3,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
        color: Colors.white,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Expanded(
              flex: 3,
              child: Hero(
                tag: 'pokemon-img-${widget.pokemon.id}',
                child: Image.network(imageUrl, fit: BoxFit.contain),
              ),
            ),
            Expanded(
              flex: 2,
              child: Column(
                children: [
                  Text(
                    widget.pokemon.name.toUpperCase(),
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: widget.screenWidth > 600 ? 14 : 11,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    '#${widget.pokemon.id.toString().padLeft(3, '0')}',
                    style: TextStyle(color: Colors.grey, fontSize: 10),
                  ),
                  const SizedBox(height: 4),
                  if (_types != null)
                    Wrap(
                      spacing: 4,
                      alignment: WrapAlignment.center,
                      children: _types!.map((type) => Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: getTypeColor(type),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          type.toUpperCase(),
                          style: const TextStyle(fontSize: 8, color: Colors.white, fontWeight: FontWeight.bold),
                        ),
                      )).toList(),
                    )
                  else
                    const SizedBox(height: 10, width: 10, child: CircularProgressIndicator(strokeWidth: 2)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ==========================================
// 6. DETAIL SCREEN (With Evolutions & Matchups)
// ==========================================

class PokemonDetailScreen extends StatefulWidget {
  final PokemonListEntry pokemonEntry;

  const PokemonDetailScreen({super.key, required this.pokemonEntry});

  @override
  State<PokemonDetailScreen> createState() => _PokemonDetailScreenState();
}

class _PokemonDetailScreenState extends State<PokemonDetailScreen> {
  late Future<Map<String, dynamic>> _fullDataFuture;

  @override
  void initState() {
    super.initState();
    _fullDataFuture = _fetchAllData();
  }

  Future<Map<String, dynamic>> _fetchAllData() async {
    // 1. Fetch Basic Detail
    final detailResp = await http.get(Uri.parse(widget.pokemonEntry.url));
    final detailJson = json.decode(detailResp.body);
    final detail = PokemonDetail.fromJson(detailJson);

    // 2. Fetch Species (เพื่อเอา Evolution URL)
    final speciesResp = await http.get(Uri.parse(detail.speciesUrl));
    final speciesJson = json.decode(speciesResp.body);
    final evolutionUrl = speciesJson['evolution_chain']['url'];

    // 3. Fetch Evolution Chain
    final evoResp = await http.get(Uri.parse(evolutionUrl));
    final evoJson = json.decode(evoResp.body);
    final evolutionChain = EvolutionNode.fromJson(evoJson['chain']);

    // 4. Fetch Type Effectiveness (Matchups)
    List<String> weaknesses = [];
    List<String> strengths = [];
    
    for (String type in detail.types) {
      final typeResp = await http.get(Uri.parse('https://pokeapi.co/api/v2/type/$type'));
      final typeJson = json.decode(typeResp.body);
      
      (typeJson['damage_relations']['double_damage_from'] as List).forEach((e) {
        String t = e['name'];
        if (!weaknesses.contains(t)) weaknesses.add(t);
      });

      (typeJson['damage_relations']['double_damage_to'] as List).forEach((e) {
        String t = e['name'];
        if (!strengths.contains(t)) strengths.add(t);
      });
    }

    return {
      'detail': detail,
      'evolution': evolutionChain,
      'weaknesses': weaknesses,
      'strengths': strengths,
    };
  }

  List<EvolutionNode> _flattenEvolution(EvolutionNode node) {
    List<EvolutionNode> list = [node];
    for (var child in node.evolvesTo) {
      list.addAll(_flattenEvolution(child));
    }
    return list;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: const BackButton(color: Colors.black),
      ),
      body: FutureBuilder<Map<String, dynamic>>(
        future: _fullDataFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }
          if (!snapshot.hasData) return const SizedBox();

          final PokemonDetail detail = snapshot.data!['detail'];
          final EvolutionNode evoRoot = snapshot.data!['evolution'];
          final List<String> weaknesses = snapshot.data!['weaknesses'];
          final List<String> strengths = snapshot.data!['strengths'];

          final primaryColor = getTypeColor(detail.types.first);

          return SingleChildScrollView(
            child: Column(
              children: [
                // --- Header Image ---
                SizedBox(
                  height: 250,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      Container(
                        decoration: BoxDecoration(
                          color: primaryColor.withOpacity(0.1),
                          borderRadius: const BorderRadius.vertical(bottom: Radius.circular(100)),
                        ),
                      ),
                      Hero(
                        tag: 'pokemon-img-${detail.id}',
                        child: Image.network(
                          'https://raw.githubusercontent.com/PokeAPI/sprites/master/sprites/pokemon/other/official-artwork/${detail.id}.png',
                          height: 200,
                        ),
                      ),
                    ],
                  ),
                ),
                
                Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Text(detail.name.toUpperCase(), style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: primaryColor)),
                      const SizedBox(height: 10),
                      
                      // --- Types ---
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: detail.types.map((type) => Container(
                          margin: const EdgeInsets.symmetric(horizontal: 5),
                          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                          decoration: BoxDecoration(color: getTypeColor(type), borderRadius: BorderRadius.circular(20)),
                          child: Text(type.toUpperCase(), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                        )).toList(),
                      ),
                      const SizedBox(height: 30),

                      // --- Matchups (Winning/Losing) ---
                      _buildSectionTitle("Type Effectiveness"),
                      const SizedBox(height: 10),
                      _buildMatchupRow("Weak Against (แพ้ทาง)", weaknesses, Colors.red.shade100),
                      const SizedBox(height: 10),
                      _buildMatchupRow("Strong Against (ชนะทาง)", strengths, Colors.green.shade100),

                      const SizedBox(height: 30),

                      // --- Evolutions ---
                      _buildSectionTitle("Evolution Chain"),
                      const SizedBox(height: 15),
                      SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          children: _flattenEvolution(evoRoot).map((node) {
                            bool isCurrent = node.speciesId == detail.id;
                            return Row(
                              children: [
                                Column(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.all(10),
                                      decoration: BoxDecoration(
                                        shape: BoxShape.circle,
                                        border: isCurrent ? Border.all(color: primaryColor, width: 3) : null,
                                        color: Colors.grey.shade100,
                                      ),
                                      child: Image.network(
                                        'https://raw.githubusercontent.com/PokeAPI/sprites/master/sprites/pokemon/${node.speciesId}.png',
                                        width: 60,
                                        height: 60,
                                      ),
                                    ),
                                    const SizedBox(height: 5),
                                    Text(node.speciesName, style: TextStyle(fontWeight: isCurrent ? FontWeight.bold : FontWeight.normal)),
                                  ],
                                ),
                                if (node.evolvesTo.isNotEmpty) 
                                  const Padding(
                                    padding: EdgeInsets.symmetric(horizontal: 10),
                                    child: Icon(Icons.arrow_forward, color: Colors.grey),
                                  ),
                              ],
                            );
                          }).toList(),
                        ),
                      ),
                      
                      const SizedBox(height: 30),

                      // --- Stats ---
                      _buildSectionTitle("Base Stats"),
                      ...detail.stats.entries.map((e) => Padding(
                        padding: const EdgeInsets.symmetric(vertical: 5),
                        child: Row(
                          children: [
                            SizedBox(width: 80, child: Text(e.key.toUpperCase(), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Colors.grey))),
                            SizedBox(width: 40, child: Text('${e.value}', style: const TextStyle(fontWeight: FontWeight.bold))),
                            Expanded(
                              child: LinearProgressIndicator(
                                value: e.value / 150,
                                color: primaryColor,
                                backgroundColor: Colors.grey.shade200,
                                minHeight: 8,
                                borderRadius: BorderRadius.circular(4),
                              ),
                            ),
                          ],
                        ),
                      )),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Text(title, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
    );
  }

  Widget _buildMatchupRow(String label, List<String> types, Color bgColor) {
    if (types.isEmpty) return const SizedBox.shrink();
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: types.map((type) => Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: getTypeColor(type),
                borderRadius: BorderRadius.circular(5),
              ),
              child: Text(type.toUpperCase(), style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
            )).toList(),
          ),
        ],
      ),
    );
  }
}