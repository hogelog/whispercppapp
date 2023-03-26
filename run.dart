#!/usr/bin/env dart

import 'dart:io';
import 'package:path/path.dart' as p;

var rootDir;

void main(List<String> args) {
  rootDir = Directory.current.path;
  switch (args[0]) {
    case "setup":
      setup();
      break;
    case "build":
      build();
      break;
    case "submit":
      submit();
      break;
  }
}

Future<void> setup() async {
  await setupFFmpeg();
  await setupWhisper();
  await flutter(["doctor"]);
}

Future<void> setupFFmpeg() async {
  switch (Platform.operatingSystem) {
    case "windows":
      if (File("exe/ffmpeg.exe").existsSync()) {
        print("Skip download ffmpeg.");
        return;
      }
      print("Download ffmpeg...");
      await wget("https://github.com/GyanD/codexffmpeg/releases/download/6.0/ffmpeg-6.0-essentials_build.7z", "exe/ffmpeg.7z");
      await sh(["7z", "x", "-oexe", "exe/ffmpeg.7z"]);
      await sh(["powershell", "Copy-Item", "exe/ffmpeg-*/bin/ffmpeg.exe", "exe/"]);
      await sh(["powershell", "Remove-Item", "-Recurse", "exe/ffmpeg-*"]);
      await sh(["powershell", "Remove-Item", "exe/ffmpeg.7z"]);
      break;
    case "macos":
      if (File("exe/ffmpeg").existsSync()) {
        print("Skip download ffmpeg.");
        return;
      }
      print("Download ffmpeg...");
      await wget("https://evermeet.cx/ffmpeg/ffmpeg-6.0.7z", "exe/ffmpeg.7z");
      await sh(["7z", "x", "-oexe", "exe/ffmpeg.7z"]);
      await sh(["rm", "exe/ffmpeg.7z"]);
      break;
  }
}

Future<void> setupWhisper() async {
  switch (Platform.operatingSystem) {
    case "windows":
      if (File("exe/whispercpp.exe").existsSync()) {
        print("Skip download whisper.cpp.");
        return;
      }
      print("Download whisper.cpp...");
      await wget("https://github.com/ggerganov/whisper.cpp/releases/download/v1.2.1/whisper-bin-x64.zip", "exe/whisper.zip");
      await sh(["7z", "x", "-oexe", "exe/whisper.zip", "main.exe", "whisper.dll"]);
      await sh(["powershell", "Rename-Item", "exe/main.exe", "whispercpp.exe"]);
      await sh(["powershell", "Remove-Item", "exe/whisper.zip"]);
      break;
    case "macos":
      if (File("exe/whispercpp").existsSync()) {
        print("Skip download whisper.cpp.");
        return;
      }
      print("Build whisper.cpp...");
      Directory.current = "whisper.cpp";

      await sh(["make", "clean", "main"]);
      await sh(["cp", "main", "main.arm64"]);

      await sh(["arch", "-x86_64", "make", "clean", "main"]);
      await sh(["cp", "main", "main.x86_64"]);
      await sh(["lipo", "-create", "-output", "../exe/whispercpp", "main.arm64", "main.x86_64"]);
      await sh(["rm", "main.arm64", "main.x86_64"]);
      await sh(["make", "clean"]);
      break;
  }
}

Future<void> build() async {
  switch (Platform.operatingSystem) {
    case "windows":
      await flutter(["build", "windows", "--release"]);
      Directory.current = "build/windows/runner";
      if (File(appZipName()).existsSync()) {
        await sh(["powershell", "Remove-Item", appZipName()]);
      }
      if (Directory("whispercppapp").existsSync()) {
        await sh(["powershell", "Remove-Item", "-Recurse", "whispercppapp"]);
      }
      await sh(["powershell", "Copy-Item", "-Recurse", "Release", "whispercppapp"]);
      await sh(["powershell", "Compress-Archive", "-Path", "whispercppapp", "-DestinationPath", appZipName()]);
      break;
    case "macos":
      await sign_binary("exe/ffmpeg");
      await sign_binary("exe/whispercpp");
      await flutter(["build", "macos", "--release"]);
      Directory.current = "build/macos/Build/Products/Release";
      await sh(["rm", "-f", appZipName()]);
      await sh(["ditto", "-c", "-k", "--keepParent", "whispercppapp.app", appZipName()]);
      break;
  }
}

Future<void> submit() async {
  switch (Platform.operatingSystem) {
    case "windows":
      break;
    case "macos":
      await sh([
        "echo",
        "xcrun",
        "notarytool",
        "submit",
        "build/macos/Build/Products/Release/${appZipName()}",
        "--apple-id", env("APPLE_DEVELOPER_ID"),
        "--password", env("APPLE_DEVELOPER_PASSWORD"),
        "--team-id", env("APPLE_DEVELOPER_TEAM_ID"),
        "--wait",
      ]);
      break;
  }
}

String appVersion() {
  return File(p.join(rootDir, "pubspec.yaml"))
      .readAsStringSync()
      .split("\n")
      .firstWhere((line) => line.startsWith("version: "))
      .replaceFirst("version: ", "")
      .replaceAll("\r", "");
}

String appZipName() {
  return "whispercppapp-${Platform.operatingSystem}-${appVersion()}.zip";
}

Future<void> sign_binary(String binary) async {
  await sh(["codesign", "-f", "-s", "Developer ID Application: Komuro Sunao (QMQNVXM7VQ)", "--options=runtime", binary]);
}

Future<void> wget(String url, String outfile) async {
  switch (Platform.operatingSystem) {
    case "windows":
      await sh(["powershell", "Invoke-WebRequest", url, "-Outfile", outfile]);
      break;
    case "macos":
      await sh(["wget", "--quiet", "--show-progress", "-O", outfile, url]);
      break;
  }
}

Future<void> sh(List<String> commands) async {
  Process process = await Process.start(commands[0], commands.sublist(1));
  stdout.addStream(process.stdout);
  stderr.addStream(process.stderr);
  int exitCode = await process.exitCode;
  if (exitCode != 0) {
    throw commands;
  }
}

Future<void> flutter(List<String> args) async {
  switch (Platform.operatingSystem) {
    case "windows":
      await sh(["flutter.bat", ...args]);
      break;
    case "macos":
      await sh(["flutter", ...args]);
      break;
  }
}

String env(String key) {
  return Platform.environment[key]!;
}
