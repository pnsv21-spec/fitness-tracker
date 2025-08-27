import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:fl_chart/fl_chart.dart';

void main() {
  runApp(const MyApp());
}

/* ========================= APP SHELL ========================= */

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

/* ========================= DATA MODELS ========================= */

class TrainingEntry {
  final DateTime date;
  final String type; // Muay Thai, Boxing, Strength, Rest/Walk, Rest/Stretch
  final int minutes;

  TrainingEntry({required this.date, required this.type, required this.minutes});

  Map<String, dynamic> toJson() => {
        'date': date.toIso8601String(),
        'type': type,
        'minutes': minutes,
      };
  factory TrainingEntry.fromJson(Map<String, dynamic> j) => TrainingEntry(
        date: DateTime.tryParse(j['date'] ?? '') ?? DateTime.now(),
        type: j['type'] ?? 'Rest/Walk',
        minutes: (j['minutes'] as num?)?.toInt() ?? 0,
      );
}

class MealEntry {
  final DateTime date;
  final String mealType; // Breakfast, Lunch, Dinner, Snack 1, Snack 2
  final String plate;
  final int calories;

  MealEntry({required this.date, required this.mealType, required this.plate, required this.calories});

  Map<String, dynamic> toJson() => {
        'date': date.toIso8601String(),
        'mealType': mealType,
        'plate': plate,
        'calories': calories,
      };
  factory MealEntry.fromJson(Map<String, dynamic> j) => MealEntry(
        date: DateTime.tryParse(j['date'] ?? '') ?? DateTime.now(),
        mealType: j['mealType'] ?? 'Breakfast',
        plate: j['plate'] ?? '',
        calories: (j['calories'] as num?)?.toInt() ?? 0,
      );
}

class DailyProgress {
  final DateTime date;
  final double? weightKg;
  final int? proteinG;
  final bool measurementsTaken;
  final double? waistCm;
  final double? chestCm;
  final double? hipsCm;

  DailyProgress({
    required this.date,
    this.weightKg,
    this.proteinG,
    this.measurementsTaken = false,
    this.waistCm,
    this.chestCm,
    this.hipsCm,
  });

  Map<String, dynamic> toJson() => {
        'date': date.toIso8601String(),
        'weightKg': weightKg,
        'proteinG': proteinG,
        'measurementsTaken': measurementsTaken,
        'waistCm': waistCm,
        'chestCm': chestCm,
        'hipsCm': hipsCm,
      };
  factory DailyProgress.fromJson(Map<String, dynamic> j) => DailyProgress(
        date: DateTime.tryParse(j['date'] ?? '') ?? DateTime.now(),
        weightKg: (j['weightKg'] as num?)?.toDouble(),
        proteinG: (j['proteinG'] as num?)?.toInt(),
        measurementsTaken: j['measurementsTaken'] == true,
        waistCm: (j['waistCm'] as num?)?.toDouble(),
        chestCm: (j['chestCm'] as num?)?.toDouble(),
        hipsCm: (j['hipsCm'] as num?)?.toDouble(),
      );
}

class Profile {
  final int? age;
  final int? heightCm;
  Profile({this.age, this.heightCm});

  Map<String, dynamic> toJson() => {'age': age, 'heightCm': heightCm};
  factory Profile.fromJson(Map<String, dynamic> j) =>
      Profile(age: (j['age'] as num?)?.toInt(), heightCm: (j['heightCm'] as num?)?.toInt());
}

class AppData {
  Profile profile;
  List<TrainingEntry> trainings;
  List<MealEntry> meals;
  List<DailyProgress> progress;

  AppData({
    required this.profile,
    required this.trainings,
    required this.meals,
    required this.progress,
  });

  Map<String, dynamic> toJson() => {
        'profile': profile.toJson(),
        'trainings': trainings.map((e) => e.toJson()).toList(),
        'meals': meals.map((e) => e.toJson()).toList(),
        'progress': progress.map((e) => e.toJson()).toList(),
      };

  factory AppData.fromJson(Map<String, dynamic> j) => AppData(
        profile: Profile.fromJson((j['profile'] as Map?)?.cast<String, dynamic>() ?? {}),
        trainings: ((j['trainings'] as List?) ?? []).map((e) => TrainingEntry.fromJson((e as Map).cast<String, dynamic>())).toList(),
        meals: ((j['meals'] as List?) ?? []).map((e) => MealEntry.fromJson((e as Map).cast<String, dynamic>())).toList(),
        progress: ((j['progress'] as List?) ?? []).map((e) => DailyProgress.fromJson((e as Map).cast<String, dynamic>())).toList(),
      );
}

/* ========================= STORAGE ========================= */

class DataStore {
  static Future<File> _file() async {
    final dir = await getApplicationDocumentsDirectory();
    return File('${dir.path}/app_data.json');
  }

  static Future<AppData> load() async {
    try {
      final f = await _file();
      if (await f.exists()) {
        final m = jsonDecode(await f.readAsString());
        return AppData.fromJson((m as Map).cast<String, dynamic>());
      }
    } catch (_) {}
    return AppData(profile: Profile(), trainings: [], meals: [], progress: []);
  }

  static Future<void> save(AppData data) async {
    final f = await _file();
    await f.writeAsString(const JsonEncoder.withIndent('  ').convert(data.toJson()));
  }
}

/* ========================= HOME PAGE / TABS ========================= */

class HomePage extends StatefulWidget {
  final bool darkMode;
  final VoidCallback onToggleTheme;
  const HomePage({super.key, required this.darkMode, required this.onToggleTheme});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> with TickerProviderStateMixin {
  late TabController _tab;
  AppData _data = AppData(profile: Profile(), trainings: [], meals: [], progress: []);
  bool _loading = true;

  // Shared helpers
  void _snack(String msg) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));

  @override
  void initState() {
    super.initState();
    _tab = TabController(length: 4, vsync: this);
    _load();
  }

  Future<void> _load() async {
    final d = await DataStore.load();
    setState(() {
      _data = d;
      _loading = false;
    });
  }

  Future<void> _save() async {
    await DataStore.save(_data);
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
          controller: _tab,
          tabs: const [
            Tab(icon: Icon(Icons.fitness_center), text: 'Training'),
            Tab(icon: Icon(Icons.restaurant), text: 'Meals'),
            Tab(icon: Icon(Icons.assignment), text: 'Progress'),
            Tab(icon: Icon(Icons.show_chart), text: 'Charts'),
          ],
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : TabBarView(
              controller: _tab,
              children: [
                TrainingTab(data: _data, onChanged: (d) => setState(() => _data = d).._save()),
                MealsTab(data: _data, onChanged: (d) => setState(() => _data = d).._save()),
                ProgressTab(data: _data, onChanged: (d) => setState(() => _data = d).._save()),
                ChartsTab(data: _data),
              ],
            ),
    );
  }
}

/* ========================= TRAINING TAB ========================= */

const trainingTypes = [
  'Muay Thai',
  'Boxing',
  'Strength',
  'Rest/Walk',
  'Rest/Stretch',
];

class TrainingTab extends StatefulWidget {
  final AppData data;
  final ValueChanged<AppData> onChanged;
  const TrainingTab({super.key, required this.data, required this.onChanged});

  @override
  State<TrainingTab> createState() => _TrainingTabState();
}

class _TrainingTabState extends State<TrainingTab> {
  DateTime _selected = DateTime.now();
  String _type = trainingTypes.first;
  final TextEditingController _minutes = TextEditingController();

  @override
  void dispose() {
    _minutes.dispose();
    super.dispose();
  }

  void _save() {
    final mins = int.tryParse(_minutes.text.trim());
    if (mins == null || mins <= 0) {
      _snack('Enter training time in minutes.');
      return;
    }
    final entry = TrainingEntry(date: _selected, type: _type, minutes: mins);

    // Replace if same date & type? Keep simple: append new; allow multiple sessions/day.
    widget.data.trainings.add(entry);
    widget.onChanged(widget.data);
    _minutes.clear();
    _snack('Training saved for ${_fmtDate(_selected)}.');
  }

  void _delete(TrainingEntry e) {
    widget.data.trainings.remove(e);
    widget.onChanged(widget.data);
  }

  @override
  Widget build(BuildContext context) {
    final dayItems = widget.data.trainings.where((t) => _isSameDay(t.date, _selected)).toList()
      ..sort((a, b) => a.type.compareTo(b.type));

    return ListView(
      padding: const EdgeInsets.all(12),
      children: [
        CalendarDatePicker(
          initialDate: _selected,
          firstDate: DateTime(DateTime.now().year - 2),
          lastDate: DateTime(DateTime.now().year + 2),
          onDateChanged: (d) => setState(() => _selected = d),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: DropdownButtonFormField<String>(
                value: _type,
                items: trainingTypes.map((t) => DropdownMenuItem(value: t, child: Text(t))).toList(),
                decoration: const InputDecoration(labelText: 'Training Type'),
                onChanged: (v) => setState(() => _type = v ?? trainingTypes.first),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: TextField(
                controller: _minutes,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'Time (min)'),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        ElevatedButton.icon(
          onPressed: _save,
          icon: const Icon(Icons.save),
          label: const Text('Save Training'),
        ),
        const Divider(height: 24),
        Text('Sessions on ${_fmtDate(_selected)}', style: const TextStyle(fontWeight: FontWeight.w600)),
        const SizedBox(height: 6),
        if (dayItems.isEmpty) const Text('No sessions yet.')
        else ...dayItems.map((e) => ListTile(
              leading: const Icon(Icons.fitness_center),
              title: Text('${e.type} • ${e.minutes} min'),
              trailing: IconButton(icon: const Icon(Icons.delete), onPressed: () => _delete(e)),
            )),
      ],
    );
  }

  void _snack(String m) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m)));
}

/* ========================= MEALS TAB ========================= */

const mealTypes = ['Breakfast', 'Lunch', 'Dinner', 'Snack 1', 'Snack 2'];

const platesByMeal = {
  'Breakfast': [
    '3 eggs + whole-grain bread + apple',
    'Greek yogurt + honey + walnuts',
    'Oats + whey + banana',
    'Egg white omelet + veggies',
    'Cottage cheese + berries',
    'Protein pancakes',
    'Smoked salmon + rye toast'
  ],
  'Lunch': [
    'Chicken breast + quinoa + salad',
    'Lean beef + rice + veggies',
    'Tuna salad + olive oil',
    'Turkey wrap + veggies',
    'Lentils + brown rice',
    'Grilled shrimp + couscous',
    'Tofu stir-fry + basmati'
  ],
  'Dinner': [
    'Salmon + veggies + sweet potato',
    'Chicken thighs + salad',
    'Beef steak + asparagus',
    'Turkey meatballs + pasta',
    'Baked cod + quinoa',
    'Omelet + salad',
    'Tofu curry + rice'
  ],
  'Snack 1': [
    'Whey shake + almonds',
    'Apple + peanut butter',
    'Protein bar',
    'Cottage cheese + pineapple',
    'Greek yogurt + granola',
    'Rice cakes + turkey',
    'Carrots + hummus'
  ],
  'Snack 2': [
    'Banana + Greek yogurt',
    'Casein shake',
    'Handful of nuts',
    'Protein pudding',
    'Boiled eggs (2)',
    'Dark chocolate (20g) + nuts',
    'Toast + avocado'
  ],
};

class MealsTab extends StatefulWidget {
  final AppData data;
  final ValueChanged<AppData> onChanged;
  const MealsTab({super.key, required this.data, required this.onChanged});

  @override
  State<MealsTab> createState() => _MealsTabState();
}

class _MealsTabState extends State<MealsTab> {
  DateTime _selected = DateTime.now();
  String _mealType = mealTypes.first;
  String _plate = platesByMeal[mealTypes.first]!.first;
  final TextEditingController _calCtrl = TextEditingController();

  @override
  void dispose() {
    _calCtrl.dispose();
    super.dispose();
  }

  void _saveMeal() {
    final cals = int.tryParse(_calCtrl.text.trim());
    if (cals == null || cals <= 0) {
      _snack('Enter calories for the meal.');
      return;
    }
    widget.data.meals.add(MealEntry(date: _selected, mealType: _mealType, plate: _plate, calories: cals));
    widget.onChanged(widget.data);
    _calCtrl.clear();
    _snack('Meal saved for ${_fmtDate(_selected)}.');
  }

  void _delete(MealEntry e) {
    widget.data.meals.remove(e);
    widget.onChanged(widget.data);
  }

  @override
  Widget build(BuildContext context) {
    final dayMeals = widget.data.meals.where((m) => _isSameDay(m.date, _selected)).toList()
      ..sort((a, b) => a.mealType.compareTo(b.mealType));
    final totalCalories = dayMeals.fold<int>(0, (sum, m) => sum + m.calories);

    return ListView(
      padding: const EdgeInsets.all(12),
      children: [
        CalendarDatePicker(
          initialDate: _selected,
          firstDate: DateTime(DateTime.now().year - 2),
          lastDate: DateTime(DateTime.now().year + 2),
          onDateChanged: (d) => setState(() => _selected = d),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: DropdownButtonFormField<String>(
                value: _mealType,
                items: mealTypes.map((t) => DropdownMenuItem(value: t, child: Text(t))).toList(),
                decoration: const InputDecoration(labelText: 'Meal Type'),
                onChanged: (v) {
                  final nextType = v ?? mealTypes.first;
                  setState(() {
                    _mealType = nextType;
                    _plate = platesByMeal[nextType]!.first;
                  });
                },
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: DropdownButtonFormField<String>(
                value: _plate,
                items: (platesByMeal[_mealType] ?? []).map((p) => DropdownMenuItem(value: p, child: Text(p))).toList(),
                decoration: const InputDecoration(labelText: 'Plate'),
                onChanged: (v) => setState(() => _plate = v ?? _plate),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _calCtrl,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'Calories'),
              ),
            ),
            const SizedBox(width: 12),
            ElevatedButton.icon(onPressed: _saveMeal, icon: const Icon(Icons.add), label: const Text('Add Meal')),
          ],
        ),
        const Divider(height: 24),
        Text('Meals on ${_fmtDate(_selected)}', style: const TextStyle(fontWeight: FontWeight.w600)),
        const SizedBox(height: 6),
        if (dayMeals.isEmpty) const Text('No meals yet.')
        else ...dayMeals.map((m) => ListTile(
              leading: const Icon(Icons.restaurant_menu),
              title: Text('${m.mealType} • ${m.plate}'),
              subtitle: Text('${m.calories} kcal'),
              trailing: IconButton(icon: const Icon(Icons.delete), onPressed: () => _delete(m)),
            )),
        const SizedBox(height: 8),
        Align(
          alignment: Alignment.centerRight,
          child: Text('Total calories: $totalCalories kcal', style: const TextStyle(fontWeight: FontWeight.w700)),
        ),
      ],
    );
  }

  void _snack(String m) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m)));
}

/* ========================= PROGRESS TAB ========================= */

class ProgressTab extends StatefulWidget {
  final AppData data;
  final ValueChanged<AppData> onChanged;
  const ProgressTab({super.key, required this.data, required this.onChanged});

  @override
  State<ProgressTab> createState() => _ProgressTabState();
}

class _ProgressTabState extends State<ProgressTab> {
  // Profile
  final TextEditingController _ageCtrl = TextEditingController();
  final TextEditingController _heightCtrl = TextEditingController();

  // Day selection + progress
  DateTime _selected = DateTime.now();
  final TextEditingController _weightCtrl = TextEditingController();
  final TextEditingController _proteinCtrl = TextEditingController();
  bool _measurementsTaken = false;
  final TextEditingController _waistCtrl = TextEditingController();
  final TextEditingController _chestCtrl = TextEditingController();
  final TextEditingController _hipsCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    // Load current profile
    final p = widget.data.profile;
    if (p.age != null) _ageCtrl.text = p.age.toString();
    if (p.heightCm != null) _heightCtrl.text = p.heightCm.toString();
    _loadDay();
  }

  void _loadDay() {
    final dp = widget.data.progress.firstWhere(
      (e) => _isSameDay(e.date, _selected),
      orElse: () => DailyProgress(date: _selected),
    );
    _weightCtrl.text = dp.weightKg?.toString() ?? '';
    _proteinCtrl.text = dp.proteinG?.toString() ?? '';
    _measurementsTaken = dp.measurementsTaken;
    _waistCtrl.text = dp.waistCm?.toString() ?? '';
    _chestCtrl.text = dp.chestCm?.toString() ?? '';
    _hipsCtrl.text = dp.hipsCm?.toString() ?? '';
    setState(() {});
  }

  int _dayCalories() {
    return widget.data.meals.where((m) => _isSameDay(m.date, _selected)).fold(0, (sum, m) => sum + m.calories);
    }

  void _saveProfile() {
    final age = int.tryParse(_ageCtrl.text.trim());
    final height = int.tryParse(_heightCtrl.text.trim());
    widget.data.profile = Profile(age: age, heightCm: height);
    widget.onChanged(widget.data);
    _snack('Profile saved.');
  }

  void _saveDay() {
    final weight = double.tryParse(_weightCtrl.text.trim());
    final protein = int.tryParse(_proteinCtrl.text.trim());
    final waist = _waistCtrl.text.trim().isEmpty ? null : double.tryParse(_waistCtrl.text.trim());
    final chest = _chestCtrl.text.trim().isEmpty ? null : double.tryParse(_chestCtrl.text.trim());
    final hips = _hipsCtrl.text.trim().isEmpty ? null : double.tryParse(_hipsCtrl.text.trim());

    // Find existing or add
    final idx = widget.data.progress.indexWhere((e) => _isSameDay(e.date, _selected));
    final dp = DailyProgress(
      date: _selected,
      weightKg: weight,
      proteinG: protein,
      measurementsTaken: _measurementsTaken,
      waistCm: waist,
      chestCm: chest,
      hipsCm: hips,
    );
    if (idx >= 0) {
      widget.data.progress[idx] = dp;
    } else {
      widget.data.progress.add(dp);
    }
    widget.onChanged(widget.data);
    _snack('Day progress saved for ${_fmtDate(_selected)}.');
  }

  @override
  Widget build(BuildContext context) {
    final cals = _dayCalories();

    return ListView(
      padding: const EdgeInsets.all(12),
      children: [
        Text('Your Profile', style: Theme.of(context).textTheme.titleMedium),
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _ageCtrl,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'Age (years)'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: TextField(
                controller: _heightCtrl,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'Height (cm)'),
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        Align(
          alignment: Alignment.centerRight,
          child: ElevatedButton.icon(onPressed: _saveProfile, icon: const Icon(Icons.save), label: const Text('Save Profile')),
        ),
        const Divider(height: 24),

        Text('Daily Progress', style: Theme.of(context).textTheme.titleMedium),
        CalendarDatePicker(
          initialDate: _selected,
          firstDate: DateTime(DateTime.now().year - 2),
          lastDate: DateTime(DateTime.now().year + 2),
          onDateChanged: (d) {
            setState(() => _selected = d);
            _loadDay();
          },
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _weightCtrl,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecorat
