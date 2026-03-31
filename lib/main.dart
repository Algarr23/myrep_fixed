import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:excel/excel.dart';
import 'package:file_picker/file_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:uuid/uuid.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const MedApp());
}

class MedApp extends StatelessWidget {
  const MedApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Personal Med App',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.indigo),
        useMaterial3: true,
      ),
      home: const HomeScreen(),
    );
  }
}

class Doctor {
  final String id;
  final String firstName;
  final String lastName;
  final String specialization;
  final String brick;
  final String phone;
  final String email;

  Doctor({
    required this.id,
    required this.firstName,
    required this.lastName,
    required this.specialization,
    required this.brick,
    required this.phone,
    required this.email,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'firstName': firstName,
        'lastName': lastName,
        'specialization': specialization,
        'brick': brick,
        'phone': phone,
        'email': email,
      };

  factory Doctor.fromJson(Map<String, dynamic> json) => Doctor(
        id: json['id'],
        firstName: json['firstName'],
        lastName: json['lastName'],
        specialization: json['specialization'],
        brick: json['brick'],
        phone: json['phone'],
        email: json['email'],
      );
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  List<Doctor> _doctors = [];
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    final prefs = await SharedPreferences.getInstance();
    final String? doctorsJson = prefs.getString('doctors_list');
    if (doctorsJson != null) {
      final List<dynamic> decoded = jsonDecode(doctorsJson);
      setState(() {
        _doctors = decoded.map((item) => Doctor.fromJson(item)).toList();
      });
    }
  }

  Future<void> _saveData() async {
    final prefs = await SharedPreferences.getInstance();
    final String encoded = jsonEncode(_doctors.map((d) => d.toJson()).toList());
    await prefs.setString('doctors_list', encoded);
  }

  Future<void> _importExcel() async {
    FilePickerResult? result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['xlsx'],
    );

    if (result != null) {
      setState(() => _isLoading = true);

      try {
        var bytes = result.files.first.bytes;
        var excel = Excel.decodeBytes(bytes!);
        List<Doctor> newDoctors = [];

        for (var table in excel.tables.keys) {
          var rows = excel.tables[table]!.rows;

          for (var i = 1; i < rows.length; i++) {
            var row = rows[i];

            if (row.length >= 6) {
              newDoctors.add(
                Doctor(
                  id: const Uuid().v4(),
                  firstName: row[0]?.value?.toString() ?? '',
                  lastName: row[1]?.value?.toString() ?? '',
                  specialization: row[2]?.value?.toString() ?? '',
                  brick: row[3]?.value?.toString() ?? '',
                  phone: row[4]?.value?.toString() ?? '',
                  email: row[5]?.value?.toString() ?? '',
                ),
              );
            }
          }
        }

        setState(() {
          _doctors = newDoctors;
          _isLoading = false;
        });

        await _saveData();

        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Importazione completata!')),
        );
      } catch (e) {
        setState(() => _isLoading = false);

        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Errore: $e')),
        );
      }
    }
  }

  Future<void> _launchUrl(String url) async {
    final uri = Uri.parse(url);
    if (!await launchUrl(uri)) {
      throw Exception('Impossibile aprire $url');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('I Miei Medici'),
        backgroundColor: Colors.indigo,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.delete_sweep),
            onPressed: () async {
              setState(() => _doctors = []);
              await _saveData();
            },
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _doctors.isEmpty
              ? const Center(
                  child: Text('Nessun medico. Importa un file Excel.'),
                )
              : ListView.builder(
                  itemCount: _doctors.length,
                  itemBuilder: (context, index) {
                    final doctor = _doctors[index];

                    return Card(
                      margin: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 5),
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor: Colors.indigo,
                          child: Text(
                            doctor.lastName.isNotEmpty
                                ? doctor.lastName[0]
                                : '?',
                            style: const TextStyle(color: Colors.white),
                          ),
                        ),
                        title: Text('${doctor.firstName} ${doctor.lastName}'),
                        subtitle:
                            Text('${doctor.specialization} - ${doctor.brick}'),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: const Icon(Icons.phone,
                                  color: Colors.green),
                              onPressed: () =>
                                  _launchUrl('tel:${doctor.phone}'),
                            ),
                            IconButton(
                              icon: const Icon(Icons.email,
                                  color: Colors.blue),
                              onPressed: () =>
                                  _launchUrl('mailto:${doctor.email}'),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
      floatingActionButton: FloatingActionButton(
        onPressed: _importExcel,
        backgroundColor: Colors.indigo,
        child: const Icon(Icons.file_upload, color: Colors.white),
      ),
    );
  }
}
