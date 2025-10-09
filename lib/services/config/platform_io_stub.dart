// Stub for dart:io on Web platform
// This file provides dummy implementations when dart:io is not available

class File {
  File(String path);

  bool existsSync() {
    throw UnsupportedError('File operations are not supported on Web');
  }

  String readAsStringSync() {
    throw UnsupportedError('File operations are not supported on Web');
  }

  Directory get parent => Directory('');

  IOSink openWrite({FileMode? mode}) {
    throw UnsupportedError('File operations are not supported on Web');
  }
}

class Directory {
  static Directory get current => throw UnsupportedError('Directory.current is not supported on Web');
  final String path;

  Directory(this.path);

  bool existsSync() {
    throw UnsupportedError('Directory operations are not supported on Web');
  }

  void createSync({bool recursive = false}) {
    throw UnsupportedError('Directory operations are not supported on Web');
  }
}

class Platform {
  static Map<String, String> get environment => {};
}

enum FileMode {
  append,
  write,
  read,
}

abstract class IOSink {
  void write(String data);
  Future flush();
  Future close();
}

// Stub stdout for Web
class _StdoutStub {
  void writeln(String line) {
    throw UnsupportedError('stdout is not supported on Web platform');
  }
}

final stdout = _StdoutStub();
