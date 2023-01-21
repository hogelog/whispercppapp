# whispercppapp
speech recognition app powered by whisper.cpp

![image](https://user-images.githubusercontent.com/50920/209566929-4665873c-d227-4d00-a7f8-bf73ece1ec19.png)

whispercppapp contains some external programs binaries.

- whisper.cpp
  - All source code available at <https://github.com/ggerganov/whisper.cpp>
- FFmpeg
  - All source code available at <https://github.com/FFmpeg/FFmpeg>


## Install
Download and extract release archvie from <https://github.com/hogelog/whispercppapp/releases>.

## Development
### Required
- macOS (Apple silicon macOS)
- Flutter

### Launch from source
```console
$ git clone https://github.com/hogelog/whispercppapp.git --recurse-submodules
$ cd whispercppapp
$ ./run.sh setup
$ flutter run -d macos
```

### Release
```console
$ ./run.sh build
$ ./run.sh submit
```
