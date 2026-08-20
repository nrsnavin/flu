import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

// ══════════════════════════════════════════════════════════════
//  TAKING A PHOTO OF THE THING IN FRONT OF YOU
//
//  Every capture in this app went through FilePicker: service bills,
//  QC images, sample photos. On a phone that means leaving the app,
//  opening the camera, shooting, coming back, and finding the picture
//  in the gallery — five steps for the one action a phone is
//  unambiguously better at than a laptop, and the reason somebody
//  reaches for the phone in the first place.
//
//  A service bill is a piece of paper a technician hands you at the
//  machine. A QC image is the defect on the reel you are holding. A
//  sample photo is the sample. All three are "point and shoot".
//
//  ── Files are still allowed, and must be ───────────────────────
//  A bill often arrives as a PDF by email, and a PDF cannot be
//  photographed. So this offers a choice rather than replacing one
//  door with another: Camera, Gallery, or Files.
//
//  ── withData, always ───────────────────────────────────────────
//  Every upload path in this app posts bytes, not paths — the server
//  stores a data URL. A picker result without bytes is useless here,
//  and on Android a content:// path is not readable as a File anyway.
//
//  ── The extension is load-bearing ──────────────────────────────
//  api/machine.js resolveBillType falls back to the file EXTENSION
//  when a client sends no content type, which Dio does by default.
//  A camera shot has no filename at all, so one is minted with a real
//  extension rather than letting the server guess at "image".
// ══════════════════════════════════════════════════════════════

/// A picked file, normalised: bytes plus a name that keeps a usable
/// extension.
class CapturedFile {
  final Uint8List bytes;
  final String name;

  const CapturedFile({required this.bytes, required this.name});

  int get sizeBytes => bytes.length;
}

enum CaptureSource { camera, gallery, files }

/// Ask how they want to supply it. Null when dismissed.
Future<CaptureSource?> askCaptureSource(
  BuildContext context, {
  bool allowFiles = true,
  String cameraLabel = 'Take a photo',
}) {
  return showModalBottomSheet<CaptureSource>(
    context: context,
    builder: (ctx) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            leading: const Icon(Icons.photo_camera_outlined),
            title: Text(cameraLabel),
            onTap: () => Navigator.pop(ctx, CaptureSource.camera),
          ),
          ListTile(
            leading: const Icon(Icons.photo_library_outlined),
            title: const Text('Choose from gallery'),
            onTap: () => Navigator.pop(ctx, CaptureSource.gallery),
          ),
          if (allowFiles)
            ListTile(
              leading: const Icon(Icons.folder_open_outlined),
              title: const Text('Choose a file (PDF)'),
              onTap: () => Navigator.pop(ctx, CaptureSource.files),
            ),
        ],
      ),
    ),
  );
}

/// Capture from the chosen source. Null means cancelled — which is a
/// normal outcome and never an error to report.
///
/// Throws nothing: a picker that will not open reports as null so the
/// call site can say something useful instead of showing a stack.
Future<CapturedFile?> capture(
  CaptureSource source, {
  List<String> fileExtensions = const ['pdf', 'jpg', 'jpeg', 'png', 'webp', 'heic'],
  /// Cameras produce very large images; the upload limit is the
  /// server's and a 12-megapixel shot of an A5 bill helps nobody.
  double maxImageWidth = 2000,
  int imageQuality = 85,
}) async {
  try {
    switch (source) {
      case CaptureSource.camera:
      case CaptureSource.gallery:
        final picker = ImagePicker();
        final shot = await picker.pickImage(
          source: source == CaptureSource.camera
              ? ImageSource.camera
              : ImageSource.gallery,
          maxWidth: maxImageWidth,
          imageQuality: imageQuality,
        );
        if (shot == null) return null;
        final bytes = await shot.readAsBytes();
        return CapturedFile(bytes: bytes, name: _named(shot.name));

      case CaptureSource.files:
        final picked = await FilePicker.pickFiles(
          type: FileType.custom,
          allowedExtensions: fileExtensions,
          withData: true,
        );
        if (picked == null || picked.files.isEmpty) return null;
        final f = picked.files.first;
        if (f.bytes == null) return null;
        return CapturedFile(bytes: f.bytes!, name: _named(f.name));
    }
  } catch (_) {
    return null;
  }
}

/// A name the server can resolve a type from. A camera shot may arrive
/// as "image_picker_1234" with no extension at all, and the upload
/// routes fall back to the extension when the client sends no content
/// type — so a bare name would be refused as an unknown type.
String _named(String raw) {
  final name = raw.trim().isEmpty ? 'photo' : raw.trim();
  return name.contains('.') ? name : '$name.jpg';
}
