import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:open_filex/open_filex.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final store = AppStore();
  await store.initialize();
  runApp(StudyVaultApp(store: store));
}

// -----------------------------------------------------------------------------
// Models
// -----------------------------------------------------------------------------

class Course {
  final String id;
  String name;
  final DateTime createdAt;

  Course({required this.id, required this.name, required this.createdAt});

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'createdAt': createdAt.toIso8601String(),
      };

  factory Course.fromJson(Map<String, dynamic> json) => Course(
        id: json['id'] as String,
        name: json['name'] as String,
        createdAt: DateTime.parse(json['createdAt'] as String),
      );
}

class Semester {
  final String id;
  final String courseId;
  String name;
  final DateTime createdAt;

  Semester({
    required this.id,
    required this.courseId,
    required this.name,
    required this.createdAt,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'courseId': courseId,
        'name': name,
        'createdAt': createdAt.toIso8601String(),
      };

  factory Semester.fromJson(Map<String, dynamic> json) => Semester(
        id: json['id'] as String,
        courseId: json['courseId'] as String,
        name: json['name'] as String,
        createdAt: DateTime.parse(json['createdAt'] as String),
      );
}

class Subject {
  final String id;
  final String semesterId;
  String name;
  final DateTime createdAt;

  Subject({
    required this.id,
    required this.semesterId,
    required this.name,
    required this.createdAt,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'semesterId': semesterId,
        'name': name,
        'createdAt': createdAt.toIso8601String(),
      };

  factory Subject.fromJson(Map<String, dynamic> json) => Subject(
        id: json['id'] as String,
        semesterId: json['semesterId'] as String,
        name: json['name'] as String,
        createdAt: DateTime.parse(json['createdAt'] as String),
      );
}

class MaterialItem {
  final String id;
  final String subjectId;
  String name;
  String originalName;
  String category;
  String extension;
  String filePath;
  int sizeBytes;
  bool favorite;
  DateTime createdAt;
  DateTime? lastOpenedAt;

  MaterialItem({
    required this.id,
    required this.subjectId,
    required this.name,
    required this.originalName,
    required this.category,
    required this.extension,
    required this.filePath,
    required this.sizeBytes,
    required this.favorite,
    required this.createdAt,
    this.lastOpenedAt,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'subjectId': subjectId,
        'name': name,
        'originalName': originalName,
        'category': category,
        'extension': extension,
        'filePath': filePath,
        'sizeBytes': sizeBytes,
        'favorite': favorite,
        'createdAt': createdAt.toIso8601String(),
        'lastOpenedAt': lastOpenedAt?.toIso8601String(),
      };

  factory MaterialItem.fromJson(Map<String, dynamic> json) => MaterialItem(
        id: json['id'] as String,
        subjectId: json['subjectId'] as String,
        name: json['name'] as String,
        originalName: json['originalName'] as String,
        category: json['category'] as String,
        extension: json['extension'] as String,
        filePath: json['filePath'] as String,
        sizeBytes: (json['sizeBytes'] as num).toInt(),
        favorite: json['favorite'] as bool? ?? false,
        createdAt: DateTime.parse(json['createdAt'] as String),
        lastOpenedAt: json['lastOpenedAt'] == null
            ? null
            : DateTime.parse(json['lastOpenedAt'] as String),
      );
}

// -----------------------------------------------------------------------------
// Local storage / application state
// -----------------------------------------------------------------------------

class AppStore extends ChangeNotifier {
  static const categories = <String>[
    'Books / PDFs',
    'Notes',
    'Question Papers',
    'Important Questions',
    'PPTs',
    'Images',
    'Other',
  ];

  final List<Course> courses = [];
  final List<Semester> semesters = [];
  final List<Subject> subjects = [];
  final List<MaterialItem> materials = [];

  Directory? _appDirectory;
  File? _databaseFile;

  bool ready = false;
  String? errorMessage;

  String _newId() {
    final r = Random().nextInt(1 << 30);
    return '${DateTime.now().microsecondsSinceEpoch}_$r';
  }

  Future<void> initialize() async {
    try {
      _appDirectory = await getApplicationDocumentsDirectory();
      _databaseFile = File(p.join(_appDirectory!.path, 'study_vault_data.json'));

      if (await _databaseFile!.exists()) {
        final raw = await _databaseFile!.readAsString();
        if (raw.trim().isNotEmpty) {
          final data = jsonDecode(raw) as Map<String, dynamic>;
          courses
            ..clear()
            ..addAll((data['courses'] as List? ?? [])
                .map((e) => Course.fromJson(Map<String, dynamic>.from(e))));
          semesters
            ..clear()
            ..addAll((data['semesters'] as List? ?? [])
                .map((e) => Semester.fromJson(Map<String, dynamic>.from(e))));
          subjects
            ..clear()
            ..addAll((data['subjects'] as List? ?? [])
                .map((e) => Subject.fromJson(Map<String, dynamic>.from(e))));
          materials
            ..clear()
            ..addAll((data['materials'] as List? ?? [])
                .map((e) => MaterialItem.fromJson(Map<String, dynamic>.from(e))));
        }
      }

      final filesDir = Directory(p.join(_appDirectory!.path, 'library_files'));
      if (!await filesDir.exists()) {
        await filesDir.create(recursive: true);
      }

      ready = true;
    } catch (e) {
      errorMessage = 'Could not load the local library: $e';
      ready = true;
    }
    notifyListeners();
  }

  Future<void> _save() async {
    if (_databaseFile == null) return;
    final data = {
      'version': 1,
      'courses': courses.map((e) => e.toJson()).toList(),
      'semesters': semesters.map((e) => e.toJson()).toList(),
      'subjects': subjects.map((e) => e.toJson()).toList(),
      'materials': materials.map((e) => e.toJson()).toList(),
    };
    final temp = File('${_databaseFile!.path}.tmp');
    await temp.writeAsString(jsonEncode(data));
    await temp.rename(_databaseFile!.path);
  }

  Course? courseById(String id) {
    for (final c in courses) {
      if (c.id == id) return c;
    }
    return null;
  }

  Semester? semesterById(String id) {
    for (final s in semesters) {
      if (s.id == id) return s;
    }
    return null;
  }

  Subject? subjectById(String id) {
    for (final s in subjects) {
      if (s.id == id) return s;
    }
    return null;
  }

  List<Semester> semestersFor(String courseId) =>
      semesters.where((e) => e.courseId == courseId).toList()
        ..sort((a, b) => a.createdAt.compareTo(b.createdAt));

  List<Subject> subjectsFor(String semesterId) =>
      subjects.where((e) => e.semesterId == semesterId).toList()
        ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));

  List<MaterialItem> materialsFor(String subjectId) =>
      materials.where((e) => e.subjectId == subjectId).toList()
        ..sort((a, b) => b.createdAt.compareTo(a.createdAt));

  Future<void> addCourse(String name) async {
    final clean = name.trim();
    if (clean.isEmpty) return;
    courses.add(Course(id: _newId(), name: clean, createdAt: DateTime.now()));
    await _save();
    notifyListeners();
  }

  Future<void> renameCourse(Course course, String name) async {
    final clean = name.trim();
    if (clean.isEmpty) return;
    course.name = clean;
    await _save();
    notifyListeners();
  }

  Future<void> deleteCourse(Course course) async {
    final semesterIds =
        semesters.where((e) => e.courseId == course.id).map((e) => e.id).toSet();
    final subjectIds = subjects
        .where((e) => semesterIds.contains(e.semesterId))
        .map((e) => e.id)
        .toSet();
    final toDelete =
        materials.where((e) => subjectIds.contains(e.subjectId)).toList();

    for (final item in toDelete) {
      await _deleteMaterialFile(item);
    }
    materials.removeWhere((e) => subjectIds.contains(e.subjectId));
    subjects.removeWhere((e) => semesterIds.contains(e.semesterId));
    semesters.removeWhere((e) => e.courseId == course.id);
    courses.removeWhere((e) => e.id == course.id);

    await _save();
    notifyListeners();
  }

  Future<void> addSemester(String courseId, String name) async {
    final clean = name.trim();
    if (clean.isEmpty) return;
    semesters.add(Semester(
      id: _newId(),
      courseId: courseId,
      name: clean,
      createdAt: DateTime.now(),
    ));
    await _save();
    notifyListeners();
  }

  Future<void> renameSemester(Semester semester, String name) async {
    final clean = name.trim();
    if (clean.isEmpty) return;
    semester.name = clean;
    await _save();
    notifyListeners();
  }

  Future<void> deleteSemester(Semester semester) async {
    final subjectIds = subjects
        .where((e) => e.semesterId == semester.id)
        .map((e) => e.id)
        .toSet();
    final toDelete =
        materials.where((e) => subjectIds.contains(e.subjectId)).toList();

    for (final item in toDelete) {
      await _deleteMaterialFile(item);
    }
    materials.removeWhere((e) => subjectIds.contains(e.subjectId));
    subjects.removeWhere((e) => e.semesterId == semester.id);
    semesters.removeWhere((e) => e.id == semester.id);

    await _save();
    notifyListeners();
  }

  Future<void> addSubject(String semesterId, String name) async {
    final clean = name.trim();
    if (clean.isEmpty) return;
    subjects.add(Subject(
      id: _newId(),
      semesterId: semesterId,
      name: clean,
      createdAt: DateTime.now(),
    ));
    await _save();
    notifyListeners();
  }

  Future<void> renameSubject(Subject subject, String name) async {
    final clean = name.trim();
    if (clean.isEmpty) return;
    subject.name = clean;
    await _save();
    notifyListeners();
  }

  Future<void> deleteSubject(Subject subject) async {
    final toDelete = materialsFor(subject.id);
    for (final item in toDelete) {
      await _deleteMaterialFile(item);
    }
    materials.removeWhere((e) => e.subjectId == subject.id);
    subjects.removeWhere((e) => e.id == subject.id);

    await _save();
    notifyListeners();
  }

  /// FIXED: `FilePicker.pickFiles` is not a real API.
  /// The correct call is `FilePicker.platform.pickFiles(...)`, which
  /// returns a nullable `FilePickerResult` — the picked files live on
  /// its `.files` property, not on the result itself.
  Future<int> addFiles({
    required String subjectId,
    required String category,
  }) async {
    final result = await FilePicker.platform.pickFiles(
      allowMultiple: true,
      type: FileType.custom,
      allowedExtensions: const [
        'pdf',
        'ppt',
        'pptx',
        'doc',
        'docx',
        'txt',
        'jpg',
        'jpeg',
        'png',
        'webp',
        'gif',
        'xls',
        'xlsx',
        'csv',
        'zip',
      ],
    );

    if (result == null || result.files.isEmpty || _appDirectory == null) {
      return 0;
    }

    final targetDir =
        Directory(p.join(_appDirectory!.path, 'library_files', subjectId));
    if (!await targetDir.exists()) {
      await targetDir.create(recursive: true);
    }

    int added = 0;

    for (final picked in result.files) {
      final sourcePath = picked.path;
      if (sourcePath == null || sourcePath.isEmpty) continue;

      final source = File(sourcePath);
      if (!await source.exists()) continue;

      final original = p.basename(sourcePath);
      final extension = p.extension(original).replaceFirst('.', '').toLowerCase();
      final id = _newId();
      final safeName = _safeFileName(original);
      final destination = File(p.join(targetDir.path, '${id}_$safeName'));

      try {
        await source.copy(destination.path);
        final bytes = await destination.length();
        final baseName = p.basenameWithoutExtension(original);

        materials.add(MaterialItem(
          id: id,
          subjectId: subjectId,
          name: baseName,
          originalName: original,
          category: category,
          extension: extension,
          filePath: destination.path,
          sizeBytes: bytes,
          favorite: false,
          createdAt: DateTime.now(),
        ));
        added++;
      } catch (_) {
        // Skip a file that cannot be copied; keep other selected files.
      }
    }

    if (added > 0) {
      await _save();
      notifyListeners();
    }
    return added;
  }

  String _safeFileName(String value) {
    final cleaned = value.replaceAll(RegExp(r'[\\/:*?"<>|]'), '_').trim();
    return cleaned.isEmpty ? 'file' : cleaned;
  }

  Future<void> renameMaterial(MaterialItem item, String name) async {
    final clean = name.trim();
    if (clean.isEmpty) return;
    item.name = clean;
    await _save();
    notifyListeners();
  }

  Future<void> toggleFavorite(MaterialItem item) async {
    item.favorite = !item.favorite;
    await _save();
    notifyListeners();
  }

  Future<void> openMaterial(MaterialItem item) async {
    final file = File(item.filePath);
    if (!await file.exists()) {
      throw Exception('The saved file is missing from device storage.');
    }
    item.lastOpenedAt = DateTime.now();
    await _save();
    notifyListeners();
    await OpenFilex.open(item.filePath);
  }

  Future<void> deleteMaterial(MaterialItem item) async {
    await _deleteMaterialFile(item);
    materials.removeWhere((e) => e.id == item.id);
    await _save();
    notifyListeners();
  }

  Future<void> _deleteMaterialFile(MaterialItem item) async {
    try {
      final file = File(item.filePath);
      if (await file.exists()) await file.delete();
    } catch (_) {}
  }

  List<MaterialItem> get favoriteMaterials =>
      materials.where((e) => e.favorite).toList()
        ..sort((a, b) => b.createdAt.compareTo(a.createdAt));

  List<MaterialItem> get recentMaterials =>
      materials.where((e) => e.lastOpenedAt != null).toList()
        ..sort((a, b) => b.lastOpenedAt!.compareTo(a.lastOpenedAt!));

  List<MaterialItem> searchMaterials(String query) {
    final q = query.trim().toLowerCase();
    if (q.isEmpty) return [];
    return materials.where((m) {
      final subject = subjectById(m.subjectId)?.name.toLowerCase() ?? '';
      final category = m.category.toLowerCase();
      return m.name.toLowerCase().contains(q) ||
          m.originalName.toLowerCase().contains(q) ||
          subject.contains(q) ||
          category.contains(q);
    }).toList();
  }

  int get totalStoredBytes =>
      materials.fold(0, (sum, item) => sum + item.sizeBytes);

  Future<void> cleanupMissingFiles() async {
    final missing = <MaterialItem>[];
    for (final item in materials) {
      if (!await File(item.filePath).exists()) missing.add(item);
    }
    if (missing.isEmpty) return;
    materials.removeWhere((item) => missing.contains(item));
    await _save();
    notifyListeners();
  }
}

// -----------------------------------------------------------------------------
// App
// -----------------------------------------------------------------------------

class StudyVaultApp extends StatelessWidget {
  final AppStore store;

  const StudyVaultApp({super.key, required this.store});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: store,
      builder: (context, _) {
        return MaterialApp(
          debugShowCheckedModeBanner: false,
          title: 'StudyVault',
          theme: ThemeData(
            useMaterial3: true,
            colorSchemeSeed: Colors.indigo,
            brightness: Brightness.light,
            scaffoldBackgroundColor: const Color(0xFFF7F8FC),
            inputDecorationTheme: const InputDecorationTheme(
              border: OutlineInputBorder(),
            ),
          ),
          home: store.ready
              ? HomeScreen(store: store)
              : const Scaffold(
                  body: Center(child: CircularProgressIndicator()),
                ),
        );
      },
    );
  }
}

// -----------------------------------------------------------------------------
// Home
// -----------------------------------------------------------------------------

class HomeScreen extends StatefulWidget {
  final AppStore store;

  const HomeScreen({super.key, required this.store});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _tab = 0;
  String _search = '';

  @override
  Widget build(BuildContext context) {
    final store = widget.store;

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'StudyVault',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        actions: [
          IconButton(
            tooltip: 'Search',
            onPressed: () => _showSearch(context),
            icon: const Icon(Icons.search),
          ),
          IconButton(
            tooltip: 'Settings',
            onPressed: () => setState(() => _tab = 2),
            icon: const Icon(Icons.settings_outlined),
          ),
        ],
      ),
      body: IndexedStack(
        index: _tab,
        children: [
          _buildHome(context),
          _buildFavorites(context),
          _buildSettings(context),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _tab,
        onDestinationSelected: (index) => setState(() => _tab = index),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.menu_book_outlined),
            selectedIcon: Icon(Icons.menu_book),
            label: 'Library',
          ),
          NavigationDestination(
            icon: Icon(Icons.star_border),
            selectedIcon: Icon(Icons.star),
            label: 'Favorites',
          ),
          NavigationDestination(
            icon: Icon(Icons.settings_outlined),
            selectedIcon: Icon(Icons.settings),
            label: 'Settings',
          ),
        ],
      ),
      floatingActionButton: _tab == 0
          ? FloatingActionButton.extended(
              onPressed: () => _addCourse(context),
              icon: const Icon(Icons.add),
              label: const Text('Add Course'),
            )
          : null,
    );
  }

  Widget _buildHome(BuildContext context) {
    final store = widget.store;
    if (store.courses.isEmpty) {
      return _EmptyState(
        icon: Icons.library_books_outlined,
        title: 'Your study library is empty',
        message:
            'Start by creating a course. Then add semesters, subjects, and your study files.',
        actionLabel: 'Create Course',
        onAction: () => _addCourse(context),
      );
    }

    final query = _search.trim();
    final searchResults =
        query.isEmpty ? <MaterialItem>[] : store.searchMaterials(query);

    return RefreshIndicator(
      onRefresh: () async => store.cleanupMissingFiles(),
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 100),
        children: [
          if (query.isNotEmpty) ...[
            Text(
              'Search results',
              style: Theme.of(context).textTheme.titleLarge,
            ),