import 'dart:typed_data';

import 'package:crypto/crypto.dart';

/// SHA-256 hex digest of raw file bytes.
String contentHash(Uint8List bytes) => sha256.convert(bytes).toString();
