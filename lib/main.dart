// Copyright (C) hogelog <konbu.komuro@gmail.com>
//
// This file is part of whispercppapp
//
// whispercppapp is free software: you can redistribute it and/or modify
// it under the terms of the GNU General Public License as published by
// the Free Software Foundation, either version 3 of the License, or
// (at your option) any later version.
//
// whispercppapp is distributed in the hope that it will be useful,
// but WITHOUT ANY WARRANTY; without even the implied warranty of
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
// GNU General Public License for more details.
//
// You should have received a copy of the GNU General Public License
// along with this program.  If not, see <https://www.gnu.org/licenses/>.

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

const APPNAME = 'org.hogel.whispercppapp';

const ASSETS_PATH_DARWIN = 'Frameworks/App.framework/Versions/Current/Resources/flutter_assets/';

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

const LANGS = const [
  "en",
  "zh",
  "de",
  "es",
  "ru",
  "ko",
  "fr",
  "ja",
  "pt",
  "tr",
  "pl",
  "ca",
  "nl",
  "ar",
  "sv",
  "it",
  "id",
  "hi",
  "fi",
  "vi",
  "iw",
  "uk",
  "el",
  "ms",
  "cs",
  "ro",
  "da",
  "hu",
  "ta",
  "no",
  "th",
  "ur",
  "hr",
  "bg",
  "lt",
  "la",
  "mi",
  "ml",
  "cy",
  "sk",
  "te",
  "fa",
  "lv",
  "bn",
  "sr",
  "az",
  "sl",
  "kn",
  "et",
  "mk",
  "br",
  "eu",
  "is",
  "hy",
  "ne",
  "mn",
  "bs",
  "kk",
  "sq",
  "sw",
  "gl",
  "mr",
  "pa",
  "si",
  "km",
  "sn",
  "yo",
  "so",
  "af",
  "oc",
  "ka",
  "be",
  "tg",
  "sd",
  "gu",
  "am",
  "yi",
  "lo",
  "uz",
  "fo",
  "ht",
  "ps",
  "tk",
  "nn",
  "mt",
  "sa",
  "lb",
  "my",
  "bo",
  "tl",
  "mg",
  "as",
  "tt",
  "haw",
  "ln",
  "ha",
  "ba",
  "jw",
  "su",
];

const PREF_KEY_MODEL = 'MODEL';
const PREF_KEY_LANG = 'LANG';

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
  bool _withTimings = false;

  Directory? _contentsDir;
  Directory? _tempDir;
  Directory? _tempAppDir;
  Directory? _assetsDir;
  File? _modelFile;
  String? _ffmpeg;
  String? _whispercpp;

  String _model = MODELS.first;
  String _lang = LANGS.first;

  SharedPreferences? _prefs = null;

  ScrollController _consoleScrollController = ScrollController();

  @override
  Widget build(BuildContext context) {
    _initialize();
    return Scaffold(
      appBar: AppBar(
        title: Text('Speech recognition'),
      ),
      body: Container(
        margin: EdgeInsets.all(20),
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
                    Column(
                      children: [
                        Label(label: 'Model name'),
                        Dropdown(
                          items: MODELS,
                          value: _model,
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
                    Container(width: 10),
                    Column(
                      children: [
                        Label(label: 'Language'),
                        Dropdown(
                          items: LANGS,
                          value: _lang,
                          onChanged: (value) {
                            if (value != null) {
                              _prefs?.setString(PREF_KEY_LANG, value);
                              setState(() {
                                _lang = value;
                              });
                            }
                          },
                        ),
                      ],
                    ),
                    Container(width: 10),
                    ElevatedButton(
                      onPressed: _runnable() ? _runRecognition : null,
                      child: _converting ? const CircularProgressIndicator(color: Colors.blue) : const Icon(Icons.play_arrow),
                    ),
                  ],
                ),
                Container(height: 20),
                Label(label: 'Console output'),
                TextArea(
                  text: _consoleText,
                  height: 150,
                  scrollController: _consoleScrollController,
                ),
                Container(height: 10),
                Row(
                  children: [
                    Label(label: 'Transcript'),
                    SizedBox(
                      width: 200,
                      child: SwitchListTile(
                        value: _withTimings,
                        onChanged: (value) {
                          _withTimings = value == true;
                        },
                        title: Text('with timings', style: Theme.of(context).textTheme.bodySmall),
                        controlAffinity: ListTileControlAffinity.leading,
                      ),
                    ),
                  ],
                ),
                TextArea(
                  text: _withTimings ? _transcriptTextWithTimings : _transcriptText,
                  height: 200,
                ),
                Container(height: 10),
                SaveButton(_withTimings ? _transcriptTextWithTimings : _transcriptText),
              ],
            )
        ),
      ),
    );
  }

  bool _runnable() => !_converting && _dropFile != null;

  Future<void> _initialize() async {
    Directory userTempDir = await getTemporaryDirectory();
    _tempDir = await Directory(path.join(userTempDir.path, APPNAME));
    _tempAppDir = await Directory(path.join(_tempDir!.path, 'app')).create(recursive: true);

    _prefs = await SharedPreferences.getInstance();
    var model = (_prefs!.getString(PREF_KEY_MODEL));
    var lang = (_prefs!.getString(PREF_KEY_LANG));
    setState(() {
      _model = model ?? MODELS.first;
      _lang = lang ?? LANGS.first;
    });

    _contentsDir = Directory(path.dirname(path.dirname(Platform.executable)));
    _assetsDir = Directory(path.join(_contentsDir!.path, ASSETS_PATH_DARWIN));

    _modelFile = File(path.join(_tempAppDir!.path, 'ggml-$_model.bin'));

    if (bool.fromEnvironment('dart.vm.product')) {
      var ffmpegAssetFile = File(path.join(_assetsDir!.path, 'exe', 'ffmpeg'));
      var whispercppAssetFile = File(path.join(_assetsDir!.path, 'exe', 'whispercpp'));
      _ffmpeg = ffmpegAssetFile.path;
      _whispercpp = whispercppAssetFile.path;
    } else {
      _ffmpeg = path.join(Directory.current.path, 'exe', 'ffmpeg');
      _whispercpp = path.join(Directory.current.path, 'exe', 'whispercpp');
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

  Future<void> _downloadModel() async {
    if (_modelFile == null) {
      return;
    } else if (_modelFile!.existsSync()) {
      _consoleWrite('Skip download $_modelFile\n');
      return;
    }
    final uri = Uri.https('huggingface.co', 'datasets/ggerganov/whisper.cpp/resolve/main/ggml-$_model.bin');
    _consoleWrite('Downloading $uri...\n');

    var client = http.Client();
    var response = await client.send(http.Request('GET', uri));
    if (response.statusCode >= 300) {
      throw response.stream.toString();
    }
    var writer = _modelFile!.openWrite();
    await writer.addStream(response.stream);
    await writer.close();
    _consoleWrite('Download ${_modelFile!.path} (${response.contentLength} bytes)\n');
  }

  Future<File> _convertWavfile(String sourceFile) async {
    File wavfile = File(path.join(_tempDir!.path, "input.wav"));
    if (wavfile.existsSync()) {
      wavfile.deleteSync();
    }
    var args = ['-i', _dropFile!.path, '-ar', '16000', '-ac', '1', '-c:a', 'pcm_s16le', wavfile.path];
    await _runCommand(_ffmpeg!, args);
    return wavfile;
  }

  Future<void> _transcript(File wavfile) async {
    var args = [
      '-m', _modelFile!.path,
      '-l', _lang,
      '-f', wavfile.path,
      '-pp',
    ];
    var result = await _runCommand(_whispercpp!, args);

    var textWithTimings = result.stdout.trim();
    var text = textWithTimings.replaceAll(PATTERN_TIMINGS, '');
    setState(() {
      _transcriptText = text;
      _transcriptTextWithTimings = textWithTimings;
    });
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
    _consoleScrollController.jumpTo(_consoleScrollController.position.maxScrollExtent);
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
class TextArea extends StatelessWidget {
  const TextArea({
    super.key,
    required this.text,
    this.height = null,
    this.scrollController = null,
  });

  final String text;
  final double? height;
  final ScrollController? scrollController;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
        height: height,
        width: double.infinity,
        child: Column(
          children: [
            Container(
              height: height,
              width: double.infinity,
              padding: EdgeInsets.all(4),
              decoration: BoxDecoration(color: Colors.white, border: Border.all(color: Colors.black45)),
              child: SingleChildScrollView(
                controller: scrollController,
                child: SelectableText(
                  text,
                ),
              ),
            ),
          ],
        ),
    );
  }
}

class Dropdown extends StatelessWidget {
  const Dropdown({super.key, required this.items, required this.value, required this.onChanged});

  final List<String> items;
  final String value;
  final ValueChanged<String?> onChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        DropdownButton<String>(
          value: value,
          items: items.map<DropdownMenuItem<String>>((String value) {
            return DropdownMenuItem<String>(
              value: value,
              child: Container(padding: EdgeInsets.all(2), child: Text(value)),
            );
          }).toList(),
          onChanged: onChanged,
        ),
      ],
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
