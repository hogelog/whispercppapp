import 'dart:io';

void main(List<String> args) {
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

void setup() {
  setupFFmpeg();
  setupWhisper();
}

void setupFFmpeg() {
  switch (Platform.operatingSystem) {
    case "windows":
      if (File("exe/ffmpeg.exe").existsSync()) {
        print("Skip download ffmpeg.");
        return;
      }
      print("Download ffmpeg...");
      wget(
          "https://github.com/GyanD/codexffmpeg/releases/download/6.0/ffmpeg-6.0-essentials_build.7z",
          "exe/ffmpeg.7z");
      sh(["7z", "x", "-oexe", "exe/ffmpeg.7z"]);
      sh(["powershell", "Copy-Item", "exe/ffmpeg-*/bin/ffmpeg.exe", "exe/"]);
      sh(["powershell", "Remove-Item", "-Recurse", "exe/ffmpeg-*"]);
      sh(["powershell", "Remove-Item", "exe/ffmpeg.7z"]);
      break;
    case "macos":
      if (File("exe/ffmpeg").existsSync()) {
        print("Skip download ffmpeg.");
        return;
      }
      print("Download ffmpeg...");
      wget("https://evermeet.cx/ffmpeg/ffmpeg-6.0.7z", "exe/ffmpeg.7z");
      sh(["7z", "x", "-oexe", "exe/ffmpeg.7z"]);
      sh(["rm", "exe/ffmpeg.7z"]);
      break;
  }
}

void setupWhisper() {
  switch (Platform.operatingSystem) {
    case "windows":
      if (File("exe/whispercpp.exe").existsSync()) {
        print("Skip download whisper.cpp.");
        return;
      }
      print("Download whisper.cpp...");
      wget("https://github.com/ggerganov/whisper.cpp/releases/download/v1.2.1/whisper-bin-x64.zip", "exe/whisper.zip");
      sh(["7z", "x", "-oexe", "exe/whisper.zip", "main.exe", "whisper.dll"]);
      sh(["powershell", "Rename-Item", "exe/main.exe", "whispercpp.exe"]);
      sh(["powershell", "Remove-Item", "exe/whisper.zip"]);
      break;
    case "macos":
      break;
  }
}

void build() {}

void submit() {}

void wget(String url, String outfile) {
  switch (Platform.operatingSystem) {
    case "windows":
      sh(["powershell", "Invoke-WebRequest", url, "-Outfile", outfile]);
      break;
    case "macos":
      sh(["wget", "--quiet", "--show-progress", "-O", outfile, url]);
      break;
  }
}

void sh(List<String> commands) {
  ProcessResult result = Process.runSync(commands[0], commands.sublist(1));
  if (result.exitCode != 0) {
    throw result.stdout + result.stderr;
  }
}
