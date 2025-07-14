import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:path_provider/path_provider.dart';
import 'package:dropdown_button2/dropdown_button2.dart';
import 'package:http/http.dart' as http;
import 'package:file_picker/file_picker.dart';

void main() {
  runApp(const SudoApp());
}

class SudoApp extends StatelessWidget {
  const SudoApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      home: SplashScreen(),
      debugShowCheckedModeBanner: false,
    );
  }
}

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    Timer(Duration(seconds: 3), () {
      Navigator.pushReplacement(
          context, MaterialPageRoute(builder: (context) => Sudo()));
    });
  }

  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Image.asset('assets/sudo.png', height: 150),
      ),
    );
  }
}

class Sudo extends StatefulWidget {
  const Sudo({super.key});

  @override
  State<StatefulWidget> createState() {
    return SudoState();
  }
}

class SudoState extends State<Sudo> {
  final TextEditingController commandController = TextEditingController();
  final TextEditingController targetController = TextEditingController();
  final TextEditingController serverController = TextEditingController();
  String? selectedInput;
  String? selectedSource;
  String? selectedFilter;
  String? selectedRateLimit;
  String? selectedOutput;
  String? selectedConfig;
  String? selectedDebug;
  String? selectedOptimization;
  String serverAddress = '';
  String? pickedFilePath;
  bool isScanning = false;
  final List<String> inputOptions = ['-d', '-dL'];
  final List<String> sourceOptions = ['-s', '-recursive', '-all', '-es'];
  final List<String> filterOptions = ['-m', '-f'];
  final List<String> rateLimitOptions = ['-rl', '-rls', '-t'];
  final List<String> outputOptions = ['-o', '-oJ', '-oD', '-cs', '-oI'];
  final List<String> configOptions = [
    '-config',
    '-pc',
    '-r',
    '-rL',
    '-nW',
    '-ei',
    '-proxy'
  ];
  final List<String> debugOptions = ['-silent', '-version', '-v', '-nc', '-ls'];
  final List<String> optimizationOptions = ['-timeout', '-max-time'];

  void updateCommand() {
    String command = 'sudo subfinder';
    if (selectedInput != null) command += ' $selectedInput';
    if (selectedSource != null) command += ' $selectedSource';
    if (selectedFilter != null) command += ' $selectedFilter';
    if (selectedRateLimit != null) command += ' $selectedRateLimit';
    if (selectedOutput != null) command += ' $selectedOutput';
    if (selectedConfig != null) command += ' $selectedConfig';
    if (selectedDebug != null) command += ' $selectedDebug';
    if (selectedOptimization != null) command += ' $selectedOptimization';
    commandController.text = command;
  }

  Future<String?> pickFile() async {
    FilePickerResult? result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['txt'],
    );
    if (result != null && result.files.single.path != null) {
      return result.files.single.path!;
    } else {
      return null;
    }
  }

  Future<String> sendCommandToServer({
    required String command,
    String? filePath,
  }) async {
    final uri = Uri.parse(serverAddress);

    if (filePath != null) {
      final request = http.MultipartRequest("POST", uri);

      request.fields["command"] = command;

      request.files.add(await http.MultipartFile.fromPath("file", filePath));

      final streamedResponse = await request.send();
      final responseBody = await streamedResponse.stream.bytesToString();

      if (streamedResponse.statusCode == 200) {
        return responseBody;
      } else {
        showToast("Error: ${streamedResponse.statusCode}");
        throw Exception("Failed to execute command with file.");
      }
    } else {
      final response = await http.post(uri, body: {
        'command': command,
      });

      if (response.statusCode == 200) {
        return response.body;
      } else {
        showToast("Error: ${response.statusCode}");
        throw Exception("Failed to execute command.");
      }
    }
  }

  Future<void> startScan() async {
    String target = targetController.text.trim();

    if (selectedInput == '-d' && target.isEmpty) {
      showToast("Please enter a target.");
      return;
    }

    if (selectedInput == '-dL' && pickedFilePath == null) {
      showToast("Please select a file.");
      return;
    }

    String command = commandController.text;

    if (selectedInput == '-d') {
      if (command.contains('-d')) {
        command = command.replaceAll(RegExp(r'-d(\s+\S+)?'), '');
        command += ' -d $target';
      }
    }

    if (selectedInput == '-dL') {
      if (command.contains('-dL')) {
        command = command.replaceAll(RegExp(r'-dL(\s+\S+)?'), '');
      }
      String fileName = pickedFilePath!.split('/').last;
      command += ' -dL /tmp/sudo/$fileName';
    }

    setState(() {
      isScanning = true;
    });

    try {
      showToast("Scan started $target");
      final output = await sendCommandToServer(
        command: command,
        filePath: selectedInput == '-dL' ? pickedFilePath : null,
      );
      await saveScan(output);
    } catch (e) {
      showToast("Error executing scan: $e");
    } finally {
      setState(() {
        isScanning = false;
      });
    }
  }

  Future<void> saveScan(String Output) async {
    String output = selectedOutput ?? 'txt';
    String fileExtension = '.txt';
    final outputFolder = await getApplicationDocumentsDirectory();
    final String outputFolderPath = outputFolder.path;
    switch (output) {
      case '-o':
        fileExtension = '.txt';
        break;
      case '-oJ':
        fileExtension = '.json';
        break;
    }
    final now = DateTime.now();
    final fileName = 'scan_result_${now.millisecondsSinceEpoch}$fileExtension';
    final filePath = '${outputFolder.path}/$fileName';
    final file = File(filePath);
    try {
      await file.create(recursive: true);
      await file.writeAsString(Output);
      showToast('File Saved to $outputFolderPath');
    } catch (e) {
      showToast("Scan Failed");
    }
  }

  void showToast(String message) {
    Fluttertoast.showToast(
      msg: message,
      toastLength: Toast.LENGTH_SHORT,
      gravity: ToastGravity.BOTTOM,
      backgroundColor: Colors.black.withOpacity(0.8),
      textColor: Colors.white,
      fontSize: 16.0,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Sudo"),
        actions: [
          IconButton(
            icon: const Icon(Icons.terminal_outlined),
            onPressed: () async {
              final newServer = await showDialog<String>(
                context: context,
                builder: (context) => AlertDialog(
                  title: const Text('Server Address'),
                  content: TextField(
                    controller: serverController,
                    decoration:
                        const InputDecoration(hintText: "Enter server address"),
                  ),
                  actions: [
                    TextButton(
                      child: const Text('Cancel'),
                      onPressed: () => Navigator.pop(context),
                    ),
                    TextButton(
                      child: const Text('Save'),
                      onPressed: () =>
                          Navigator.pop(context, serverController.text),
                    ),
                  ],
                ),
              );
              if (newServer != null) {
                setState(() {
                  serverAddress = newServer;
                });
              }
            },
          ),
        ],
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.only(
                top: 6.0,
                left: 6.0,
                right: 6.0,
                bottom: 0.0,
              ),
              child: TextField(
                controller: commandController,
                decoration: InputDecoration(
                  labelText: 'Command',
                  contentPadding: const EdgeInsets.all(16.0),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10.0),
                    borderSide:
                        const BorderSide(color: Colors.grey, width: 1.0),
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(6.0),
              child: TextField(
                controller: targetController,
                decoration: InputDecoration(
                  hintText: 'ip.of.the.target or domain name',
                  labelText: 'Target',
                  contentPadding: const EdgeInsets.all(16.0),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10.0),
                    borderSide:
                        const BorderSide(color: Colors.grey, width: 1.0),
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(
                  top: 0.0, bottom: 6.0, left: 6.0, right: 6.0),
              child: InkWell(
                onTap: () async {
                  final path = await pickFile();
                  if (path != null) {
                    setState(() {
                      pickedFilePath = path;
                    });
                    showToast("File Selected: ${path.split('/').last}");
                  }
                },
                child: Container(
                  padding: const EdgeInsets.all(16.0),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(10.0),
                    border: Border.all(color: Colors.grey, width: 1.0),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Icon(Icons.upload_file),
                      Text("Select File to be uploaded"),
                    ],
                  ),
                ),
              ),
            ),
            buildDropdownRow('Input', inputOptions, 'Source', sourceOptions,
                (value) {
              setState(() {
                selectedInput = value;
                updateCommand();
              });
            }, (value) {
              setState(() {
                selectedSource = value;
                updateCommand();
              });
            }),
            buildDropdownRow(
                'Filter', filterOptions, 'Rate-Limit', rateLimitOptions,
                (value) {
              setState(() {
                selectedFilter = value;
                updateCommand();
              });
            }, (value) {
              setState(() {
                selectedRateLimit = value;
                updateCommand();
              });
            }),
            buildDropdownRow(
                'Output', outputOptions, 'Configurations', configOptions,
                (value) {
              setState(() {
                selectedOutput = value;
                updateCommand();
              });
            }, (value) {
              setState(() {
                selectedConfig = value;
                updateCommand();
              });
            }),
            buildDropdownRow(
                'Debug', debugOptions, 'Optimization', optimizationOptions,
                (value) {
              setState(() {
                selectedDebug = value;
                updateCommand();
              });
            }, (value) {
              setState(() {
                selectedOptimization = value;
                updateCommand();
              });
            }),
            Padding(
              padding: const EdgeInsets.only(top: 6.0),
              child: ElevatedButton(
                onPressed: () {
                  startScan();
                },
                style: ElevatedButton.styleFrom(
                  fixedSize: const Size(200, 60),
                  backgroundColor: Colors.green,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: isScanning
                    ? CircularProgressIndicator(color: Colors.white)
                    : Text('Scan',
                        style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 20)),
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: BottomNavigationBar(
        items: const [
          BottomNavigationBarItem(
            icon: Icon(
              Icons.dns,
              color: Colors.grey,
            ),
            label: "Subfinder",
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.article_outlined),
            label: "SCAN RESULT",
          ),
        ],
        currentIndex: 0,
        onTap: (index) {
          if (index == 0) {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(builder: (context) => const Sudo()),
            );
          } else if (index == 1) {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(builder: (context) => const ScanResult()),
            );
          }
        },
      ),
    );
  }

  Widget buildDropdownRow(
      String label1,
      List<String> options1,
      String label2,
      List<String> options2,
      ValueChanged<String?> onChanged1,
      ValueChanged<String?> onChanged2) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        children: [
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 6.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label1),
                  DropdownButtonFormField2<String>(
                    decoration: InputDecoration(
                      isDense: true,
                      contentPadding: EdgeInsets.zero,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(5),
                      ),
                    ),
                    isExpanded: true,
                    hint: const Text('Select'),
                    items: options1
                        .map((item) => DropdownMenuItem<String>(
                              value: item,
                              child: Text(item),
                            ))
                        .toList(),
                    onChanged: onChanged1,
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 6.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label2),
                  DropdownButtonFormField2<String>(
                    decoration: InputDecoration(
                      isDense: true,
                      contentPadding: EdgeInsets.zero,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(5),
                      ),
                    ),
                    isExpanded: true,
                    hint: const Text('Select'),
                    items: options2
                        .map((item) => DropdownMenuItem<String>(
                              value: item,
                              child: Text(item),
                            ))
                        .toList(),
                    onChanged: onChanged2,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class ScanResult extends StatefulWidget {
  const ScanResult({super.key});

  @override
  State<StatefulWidget> createState() {
    return ScanResultState();
  }
}

class ScanResultState extends State<ScanResult> {
  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text("Sudo"),
          bottom: const TabBar(
            isScrollable: true,
            tabs: [
              Tab(
                icon: Icon(Icons.list_alt),
                text: "TEXT",
              ),
              Tab(
                icon: Icon(Icons.javascript),
                text: "JSON",
              ),
            ],
          ),
        ),
        body: const TabBarView(
          children: [
            ScanFileList(extension: 'txt'),
            ScanFileList(extension: 'json'),
          ],
        ),
        bottomNavigationBar: BottomNavigationBar(
          items: const [
            BottomNavigationBarItem(
              icon: Icon(
                Icons.dns,
                color: Colors.grey,
              ),
              label: "Subfinder",
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.article_outlined),
              label: "SCAN RESULT",
            ),
          ],
          currentIndex: 0,
          onTap: (index) {
            if (index == 0) {
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(builder: (context) => const Sudo()),
              );
            } else if (index == 1) {
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(builder: (context) => const ScanResult()),
              );
            }
          },
        ),
      ),
    );
  }
}

class ScanFileList extends StatelessWidget {
  final String extension;
  const ScanFileList({required this.extension, Key? key}) : super(key: key);

  Future<List<File>> getScanFiles(String extension) async {
    final directory = await getApplicationDocumentsDirectory();
    final files = directory
        .listSync()
        .whereType<File>()
        .where((file) => file.path.endsWith(extension))
        .toList();
    return files;
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<File>>(
      future: getScanFiles(extension),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final files = snapshot.data!;
        return ListView.builder(
          itemCount: files.length,
          itemBuilder: (context, index) {
            final file = files[index];
            return ListTile(
              title: Text(file.path.split('/').last),
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => ScanDetailPage(file: file),
                  ),
                );
              },
            );
          },
        );
      },
    );
  }
}

class ScanDetailPage extends StatelessWidget {
  final File file;
  const ScanDetailPage({required this.file, Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final extension = file.path.split('.').last;
    return Scaffold(
      appBar: AppBar(
        title: Text(file.path.split('/').last),
      ),
      body: FutureBuilder<String>(
        future: file.readAsString(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final content = snapshot.data!;
          if (extension == 'txt') {
            return SingleChildScrollView(child: Text(content));
          } else if (extension == 'json') {
            return SingleChildScrollView(child: Text(content));
          } else {
            return const Center(child: Text("Unsupported format"));
          }
        },
      ),
    );
  }
}
