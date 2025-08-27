import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:fl_chart/fl_chart.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  bool _darkMode = false;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Fitness Tracker',
      themeMode: _darkMode ? ThemeMode.dark : ThemeMode.light,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.teal),
        useMaterial3: true,
      ),
      darkTheme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.teal, brightness: Brightness.dark),
        useMaterial3: true,
      ),
      home: HomePage(
        darkMode: _darkMode,
        onToggleTheme: () => setState(() => _darkMode = !_darkMode),
      ),
    );
  }
}

class HomePage extends StatefulWidget {
  final bool darkMode;
  final VoidCallback onToggleTheme;
  const HomePage({super.key, required this.darkMode, required this.onToggleTheme});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> with TickerProviderStateMixin {
  late TabController _tabController;

  final List<Map<String, dynamic>> _trainingPlan = _defaultTrainingPlan;
  final List<Map<String, String>> _mealPlan = _defaultMealPlan;
  List<ProgressEntry> _entries = [];

  final TextEditingController _dateCtrl = TextEditingController();
  DateTime? _selectedDate;
  final TextEditingController _weightCtrl = TextEditingController();
  final TextEditingController _caloriesCtrl = TextEditingController();
  final TextEditingController _proteinCtrl = TextEditingController();
  String _trainingDone = 'Muay Thai';

  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _selectedDate = DateTime.now();
    _dateCtrl.text = _fmtDate(_selectedDate!);
    _loadEntries();
  }

  Future<File> _getDataFile() async {
    final dir = await getApplicationDocumentsDirectory();
    return File('${dir.path}/progress.json');
  }

  Future<void> _loadEntries() async {
    try {
      final file = await _getDataFile();
      if (await file.exists()) {
        final data = jsonDecode(await file.readAsString()) as List;
        _entries = data.map((e) => ProgressEntry.fromJson(e)).toList();
      }
    } catch (_) {}
    setState(() {
      _loading = false;
    });
  }

  Future<void> _saveEntries() async {
    final file = await _getDataFile();
    final jsonList = _entries.map((e) => e.toJson()).toList();
    await file.writeAsString(const JsonEncoder.withIndent('  ').convert(jsonList));
  }

  void _addEntry() async {
    if (_selectedDate == null) return;
    final weight = double.tryParse(_weightCtrl.text.trim());
    final calories = int.tryParse(_caloriesCtrl.text.trim());
    final protein = int.tryParse(_proteinCtrl.text.trim());

    if (weight == null || calories == null || protein == null) {
      _snack('Please fill weight, calories, and protein with valid numbers.');
      return;
    }

    final existingIndex = _entries.indexWhere((e) => _isSameDay(e.date, _selectedDate!));
    final newEntry = ProgressEntry(
      date: _selectedDate!,
      weight: weight,
      training: _trainingDone,
      calories: calories,
      protein: protein,
    );

    setState(() {
      if (existingIndex >= 0) {
        _entries[existingIndex] = newEntry;
      } else {
        _entries.add(newEntry);
      }
      _entries.sort((a, b) => a.date.compareTo(b.date));
    });
    await _saveEntries();
    _snack('Entry saved.');
  }

  void _snack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Fitness Tracker'),
        actions: [
          IconButton(
            tooltip: widget.darkMode ? 'Light mode' : 'Dark mode',
            onPressed: widget.onToggleTheme,
            icon: Icon(widget.darkMode ? Icons.dark_mode : Icons.light_mode),
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(icon: Icon(Icons.fitness_center), text: 'Training'),
            Tab(icon: Icon(Icons.restaurant), text: 'Meals'),
            Tab(icon: Icon(Icons.show_chart), text: 'Progress'),
          ],
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : TabBarView(
              controller: _tabController,
              children: [
                _buildTrainingPlanTab(),
                _buildMealPlanTab(),
                _buildProgressTab(),
              ],
            ),
      floatingActionButton: _tabController.index == 2
          ? FloatingActionButton.extended(
              onPressed: _addEntry,
              icon: const Icon(Icons.save),
              label: const Text('Save Entry'),
            )
          : null,
    );
  }

  Widget _buildTrainingPlanTab() {
    return ListView(
      children: _trainingPlan
          .map((t) => ListTile(title: Text(t['day']), subtitle: Text("${t['training']} • ${t['duration']} min")))
          .toList(),
    );
  }

  Widget _buildMealPlanTab() {
    return ListView(
      children: _mealPlan
          .map((m) => ListTile(title: Text(m['meal']!), subtitle: Text(m['example']!)))
          .toList(),
    );
  }

  Widget _buildProgressTab() {
    return Center(child: Text("Charts + logging go here (simplified for demo)"));
  }
}

class ProgressEntry {
  final DateTime date;
  final double weight;
  final String training;
  final int calories;
  final int protein;

  ProgressEntry({
    required this.date,
    required this.weight,
    required this.training,
    required this.calories,
    required this.protein,
  });

  Map<String, dynamic> toJson() => {
        'date': date.toIso8601String(),
        'weight': weight,
        'training': training,
        'calories': calories,
        'protein': protein,
      };

  factory ProgressEntry.fromJson(Map<String, dynamic> json) {
    return ProgressEntry(
      date: DateTime.tryParse(json['date'] ?? '') ?? DateTime.now(),
      weight: (json['weight'] as num).toDouble(),
      training: json['training'] ?? 'Rest',
      calories: (json['calories'] as num).toInt(),
      protein: (json['protein'] as num).toInt(),
    );
  }
}

String _fmtDate(DateTime d) => "${d.year}-${d.month}-${d.day}";
bool _isSameDay(DateTime a, DateTime b) => a.year == b.year && a.month == b.month && a.day == b.day;

const List<Map<String, dynamic>> _defaultTrainingPlan = [
  {'day': 'Monday', 'training': 'Muay Thai', 'duration': 60},
  {'day': 'Tuesday', 'training': 'Strength (Day A)', 'duration': 50},
  {'day': 'Wednesday', 'training': 'Boxing', 'duration': 60},
  {'day': 'Thursday', 'training': 'Rest / Walk', 'duration': 30},
  {'day': 'Friday', 'training': 'Strength (Day B)', 'duration': 50},
  {'day': 'Saturday', 'training': 'Muay Thai', 'duration': 70},
  {'day': 'Sunday', 'training': 'Rest / Stretch', 'duration': 30},
];

const List<Map<String, String>> _defaultMealPlan = [
  {'meal': 'Breakfast', 'example': '3 eggs + bread + apple'},
  {'meal': 'Snack', 'example': 'Whey shake + almonds'},
  {'meal': 'Lunch', 'example': 'Chicken + rice + salad'},
  {'meal': 'Snack 2', 'example': 'Banana + yogurt'},
  {'meal': 'Dinner', 'example': 'Fish + veggies + sweet potato'},
  {'meal': 'Late snack', 'example': 'Cottage cheese'},
];
