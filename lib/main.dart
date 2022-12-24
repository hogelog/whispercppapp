import 'dart:developer';
import 'dart:io';

import 'package:cross_file/cross_file.dart';
import 'package:desktop_drop/desktop_drop.dart';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;

const APPDIR = 'org.hogel.whispercppapp';

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
  String _consoleText = "";

  Directory? _appTempDir;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Speech recognition powered by whisper.cpp'),
      ),
      body: Center(
        child: Wrap(
          direction: Axis.vertical,
          children: [
            DropTarget(
              onDragDone: (detail) {
                log("done");
                setState(() {
                  _dropFile = detail.files.first;
                  _dragging = false;
                });
              },
              onDragEntered: (detail) {
                log("enter");
                setState(() {
                  _dragging = true;
                });
              },
              onDragExited: (detail) {
                log("exit");
                setState(() {
                  _dragging = false;
                });
              },
              child: Container(
                height: 100,
                width: 600,
                color: _dragging ? Colors.blue.withOpacity(0.4) : Colors.black12,
                child: Center(
                    child: Text(_dropFile == null ? "Drop audio file here" : _dropFile!.path)
                ),
              ),
            ),
            SingleChildScrollView(
              scrollDirection: Axis.vertical,
              child: SelectableText(
                _consoleText,
              ),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _runnable() ? _runRecognition : null,
        tooltip: 'Run recognition',
        child: _converting ? const CircularProgressIndicator(color: Colors.blue) : const Icon(Icons.play_arrow),
        backgroundColor: _runnable() ? Colors.blue : Colors.black38,
      ),
    );
  }

  bool _runnable() => !_converting && _dropFile != null;

  Future<Directory?> _setup() async {
    Directory userTempDir = await getTemporaryDirectory();
    _appTempDir = await Directory(path.join(userTempDir.path, APPDIR)).create();
    return _appTempDir;
  }

  void _runRecognition() async {
    await _setup();

    setState(() {
      _converting = true;
      _consoleText = "";
    });
    try {
      File wavfile = await _convertWavfile(_dropFile!.path);
      await _transcript(wavfile);
    } finally {
      setState(() {
        _dropFile = null;
        _converting = false;
      });
    }
  }

  Future<File> _convertWavfile(String sourceFile) async {
    File wavfile = File(path.join(_appTempDir!.path, "input.wav"));
    if (wavfile.existsSync()) {
      wavfile.deleteSync();
    }
    var args = ['-i', _dropFile!.path, '-ar', '16000', '-ac', '1', '-c:a', 'pcm_s16le', wavfile.path];
    setState(() {
      _consoleText += "\$ ffmpeg ${ args.join(' ') }\n";
    });
    var result = await Process.run('ffmpeg', args);
    setState(() {
      _consoleText += result.stderr + result.stdout + '\n';
    });
    return wavfile;
  }

  Future<String> _transcript(File wavfile) async {
    String whisperPath = path.join(_appTempDir!.path, 'app', 'whispercpp');
    String modelPath = path.join(_appTempDir!.path, 'app', 'ggml-medium.bin');
    var args = ['-m', modelPath, '-l', 'ja', '-f', wavfile.path];
    setState(() {
      _consoleText += "\$ $whisperPath ${ args.join(' ') }\n";
    });
    var result = await Process.run(whisperPath, args);
    var resultText = result.stderr + result.stdout;
    setState(() {
      _consoleText += resultText + '\n';
    });
    return resultText;
  }
}
