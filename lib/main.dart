import 'dart:developer';

import 'package:cross_file/cross_file.dart';
import 'package:desktop_drop/desktop_drop.dart';
import 'package:flutter/material.dart';

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
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _dropFile == null ? null : _runRecognition,
        tooltip: 'Run recognition',
        child: const Icon(Icons.play_arrow),
        backgroundColor: _dropFile == null ? Colors.black38 : Colors.blue,
      ),
    );
  }

  void _runRecognition() {
    log(_dropFile!.path);
  }
}
