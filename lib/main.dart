import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:cross_file/cross_file.dart';
import 'package:desktop_drop/desktop_drop.dart';
import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;

const APPDIR = 'org.hogel.whispercppapp';
const TRANSCRIPT_NAME = 'transcript.txt';

final PATTERN_TIMINGS = RegExp(r'^\[[^\]]+\]  ', multiLine: true);

const MODELS = const [
  'tiny.en',
  'tiny',
  'base.en',
  'base',
  'small.en',
  'small',
  'medium.en',
  'medium',
  'large',
];

const PREF_KEY_MODEL = 'MODEL';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      home: HomeWidget(),
    );
  }
}

class HomeWidget extends StatefulWidget {
  const HomeWidget({Key? key}) : super(key: key);

  @override
  _HomeWidgetState createState() => _HomeWidgetState();
}

class _HomeWidgetState extends State<HomeWidget> {
  XFile? _dropFile = null;
  bool _dragging = false;
  bool _converting = false;
  String _consoleText = '';
  String _transcriptText = '';
  String _transcriptTextWithTimings = '';

  Directory? _appTempDir;

  String _model = MODELS.first;

  SharedPreferences? _prefs = null;

  @override
  Widget build(BuildContext context) {
    _initialize();
    return Scaffold(
      appBar: AppBar(
        title: Text('Speech recognition'),
      ),
      body: Container(
        margin: EdgeInsets.all(20),
        child: Scrollbar(
          child: SingleChildScrollView(
            scrollDirection: Axis.vertical,
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    DropTarget(
                      onDragDone: (detail) {
                        setState(() {
                          _dropFile = detail.files.first;
                          _dragging = false;
                        });
                      },
                      onDragEntered: (detail) {
                        setState(() {
                          _dragging = true;
                        });
                      },
                      onDragExited: (detail) {
                        setState(() {
                          _dragging = false;
                        });
                      },
                      child: Expanded(child:
                      Container(
                        height: 100,
                        color: _dragging ? Colors.blue.withOpacity(0.4) : Colors.black12,
                        child: TextButton(
                          onPressed: _selectFile,
                          child: Text(_dropFile == null ? "Drop audio file here" : _dropFile!.path),
                        ),
                      )
                      ),
                    ),
                    Container(width: 10),
                    Container(
                      child: Column(
                        children: [
                          Label(label: 'Model name'),
                          DropdownButton<String>(
                            value: _model,
                            items: MODELS.map<DropdownMenuItem<String>>((String value) {
                              return DropdownMenuItem<String>(
                                value: value,
                                child: Container(padding: EdgeInsets.all(2), child: Text(value)),
                              );
                            }).toList(),
                            onChanged: (value) {
                              if (value != null) {
                                _prefs?.setString(PREF_KEY_MODEL, value);
                                setState(() {
                                  _model = value;
                                });
                              }
                            },
                          ),
                        ],
                      ),
                    ),
                    Container(width: 10),
                    ElevatedButton(
                      onPressed: _runnable() ? _runRecognition : null,
                      child: _converting ? const CircularProgressIndicator(color: Colors.blue) : const Icon(Icons.play_arrow),
                    ),
                  ],
                ),
                LabeledTextArea(
                  label: 'Console output',
                  text: _consoleText,
                  height: 150,
                ),
                LabeledTextArea(
                  label: 'Transcript',
                  text: _transcriptText,
                  height: 200,
                ),
                SaveButton(_transcriptText),
                LabeledTextArea(
                  label: 'Transcript with timings',
                  text: _transcriptTextWithTimings,
                  height: 200,
                ),
                SaveButton(_transcriptTextWithTimings),
              ],
            )
          ),
        ),
      ),
    );
  }

  bool _runnable() => !_converting && _dropFile != null;

  File? _modelFile() => _appTempDir != null ? File(path.join(_appTempDir!.path, 'app', 'ggml-$_model.bin')) : null;

  Future<void> _initialize() async {
    Directory userTempDir = await getTemporaryDirectory();
    _appTempDir = await Directory(path.join(userTempDir.path, APPDIR)).create();

    _prefs = await SharedPreferences.getInstance();
    var model = (_prefs!.getString(PREF_KEY_MODEL));
    if (model != null) {
      setState(() {
        _model = model;
      });
    }
  }

  void _runRecognition() async {
    await _initialize();

    setState(() {
      _converting = true;
      _consoleText = '';
    });
    try {
      await _downloadModel();
      File wavfile = await _convertWavfile(_dropFile!.path);
      await _transcript(wavfile);
    } catch (e) {
      _consoleWrite(e.toString());
    } finally {
      setState(() {
        _dropFile = null;
        _converting = false;
      });
    }
  }

  Future<File?> _downloadModel() async {
    File? modelfile = _modelFile();
    if (modelfile == null) {
      return null;
    } else if (modelfile.existsSync()) {
      _consoleWrite('Skip download $modelfile\n');
      return modelfile;
    }
    final uri = Uri.https('huggingface.co', 'datasets/ggerganov/whisper.cpp/resolve/main/ggml-$_model.bin');
    _consoleWrite('Downloading $uri...\n');
    var response = await http.get(uri);
    if (response.statusCode >= 300) {
      throw response.body;
    }
    await modelfile.writeAsBytes(response.bodyBytes);
    _consoleWrite('Download ${modelfile.path} (${response.contentLength} bytes)\n');
    return modelfile;
  }

  Future<File> _convertWavfile(String sourceFile) async {
    File wavfile = File(path.join(_appTempDir!.path, "input.wav"));
    if (wavfile.existsSync()) {
      wavfile.deleteSync();
    }
    var args = ['-i', _dropFile!.path, '-ar', '16000', '-ac', '1', '-c:a', 'pcm_s16le', wavfile.path];
    await _runCommand('ffmpeg', args);
    return wavfile;
  }

  Future<String> _transcript(File wavfile) async {
    String whisperPath = path.join(_appTempDir!.path, 'app', 'whispercpp');
    var args = ['-m', _modelFile()!.path, '-l', 'ja', '-f', wavfile.path];

    var result = await _runCommand(whisperPath, args);

    var textWithTimings = result.stdout.trim();
    setState(() {
      _transcriptTextWithTimings = textWithTimings;
      _transcriptText = textWithTimings.replaceAll(PATTERN_TIMINGS, '');
    });
    return _transcriptTextWithTimings;
  }

  Future<ProcessResult> _runCommand(String command, List<String> args) async {
    _consoleWrite("\$ $command ${ args.join(' ') }\n");
    var process = await Process.start(command, args);
    var stdout = '';
    var stderr = '';
    process.stderr.transform(utf8.decoder).forEach((line) {
      stderr += line;
      _consoleWrite(line);
    });
    process.stdout.transform(utf8.decoder).forEach((line) {
      stdout += line;
      _consoleWrite(line);
    });

    var exitCode = await process.exitCode;
    _consoleWrite('\n');

    return ProcessResult(process.pid, exitCode, stdout, stderr);
  }

  void _consoleWrite(String line) {
    setState(() {
      _consoleText += line;
    });
  }

  Future<void> _selectFile() async {
    final XFile? file = await openFile();
    if (file != null) {
      setState(() {
        _dropFile = file;
      });
    }
  }
}

class LabeledTextArea extends StatelessWidget {
  const LabeledTextArea({super.key, required this.label, required this.text, this.height = null});

  final String label;
  final String text;
  final double? height;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
        height: height,
        width: double.infinity,
        child: Column(
          children: [
            Container(height: 10),
            Label(label: label),
            Scrollbar(
              child: SingleChildScrollView(
                child: Container(
                  height: height != null ? height! - 40.0 : null,
                  width: double.infinity,
                  padding: EdgeInsets.all(4),
                  decoration: BoxDecoration(color: Colors.white, border: Border.all(color: Colors.black45)),
                  child: SelectableText(
                    text,
                  ),
                  // child: SelectableText(_consoleText),
                ),
              ),
            )
          ],
        ),
    );
  }
}

class Label extends StatelessWidget {
  const Label({super.key, required this.label});

  final String label;
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.only(top: 4, bottom: 4),
      child: Align(
        alignment: AlignmentDirectional.topStart,
        child: Text(label, style: Theme.of(context).textTheme.bodySmall),
      ),
    );
  }
}

class SaveButton extends StatelessWidget {
  const SaveButton(String this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: AlignmentDirectional.centerEnd,
      child: ElevatedButton(
        onPressed: text.length > 0 ? _saveTranscript : null,
        child: Text('Save'),
      ),
    );
  }

  void _saveTranscript() async {
    final String? path = await getSavePath(suggestedName: TRANSCRIPT_NAME);
    if (path == null) {
      return;
    }

    final Uint8List fileData = Uint8List.fromList(utf8.encode(text));
    final XFile textFile = XFile.fromData(fileData, mimeType: 'text/plain', name: TRANSCRIPT_NAME);
    await textFile.saveTo(path);
  }
}
