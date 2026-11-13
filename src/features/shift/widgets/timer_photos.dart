import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../core/api_client.dart';
import '../../../core/app_config.dart';
import '../../PurchaseOrder/services/theme.dart';

// ══════════════════════════════════════════════════════════════
//  TIMER PHOTOS OF A SHIFT — fetched only when asked for
//
//  The photos of the loom's timer taken while a shift's production
//  was entered, kept with the entry by the server (api/timerOcr.js),
//  so whoever checks the entry can see the display the run time came
//  from. The web shows them on its verify screen.
//
//  Here nothing is fetched until "View photos" is tapped — not the
//  list, not one image. A supervisor going down forty entries on the
//  factory's connection pays for the one they open, not for all of
//  them. Once open: the list, then each photo as its page comes up;
//  swiping on fetches the next. Closing the viewer drops the bytes.
// ══════════════════════════════════════════════════════════════

/// One photo kept with a shift: what the server's list sends (no bytes).
class TimerPhotoMeta {
  final String id;
  final DateTime? takenAt;
  final String takenBy;
  final String? readText;
  final String? readProblem;
  final bool used;
  final String? runTimeUsed;

  /// A total-hours meter: the readings the run time was worked out from.
  final num? meterStart;
  final num? meterEnd;

  /// A metre counter on the same panel, as it read in this photo.
  final num? counterEnd;

  const TimerPhotoMeta({
    required this.id,
    this.takenAt,
    this.takenBy = '',
    this.readText,
    this.readProblem,
    this.used = false,
    this.runTimeUsed,
    this.meterStart,
    this.meterEnd,
    this.counterEnd,
  });

  factory TimerPhotoMeta.fromJson(Map<String, dynamic> j) {
    String? text(Object? v) {
      final t = v?.toString().trim() ?? '';
      return t.isEmpty ? null : t;
    }

    num? number(Object? v) => v is num ? v : null;

    return TimerPhotoMeta(
      id: j['id']?.toString() ?? '',
      takenAt: DateTime.tryParse(j['takenAt']?.toString() ?? '')?.toLocal(),
      takenBy: text(j['takenBy']) ?? '',
      readText: text(j['readText']),
      readProblem: text(j['readProblem']),
      used: j['used'] == true,
      runTimeUsed: text(j['runTimeUsed']),
      meterStart: number(j['meterStart']),
      meterEnd: number(j['meterEnd']),
      counterEnd: number(j['counterEnd']),
    );
  }

  /// What the photo says, in a few words. The web's wording
  /// (prod_web TimerPhotos.tsx), so both apps describe a photo alike.
  String get summary {
    if (used && runTimeUsed != null) {
      return 'Run time $runTimeUsed filled from this photo';
    }
    if (readText != null) return 'Read “$readText”, not used';
    return _problemWords[readProblem] ?? 'Not read';
  }
}

const _problemWords = <String, String>{
  'not_set_up': "Not read: reading photos isn't set up",
  'not_read': 'Not read: reading failed',
  'blurry': 'Too blurry to read',
  'glare': 'Glare on the display',
  'cut_off': 'Display cut off',
  'too_dark': 'Too dark to read',
  'no_display': 'No timer seen',
};

/// GET /api/v2/ocr/timer/… — the photo list and the photos themselves.
///
/// Through ApiClient.buildClient so the sign-in cookie rides along. The
/// file route is behind the sign-in, and Image.network has no cookie: it
/// would come back 401 and draw an empty box (see sample_api.dart).
class TimerPhotoApi {
  TimerPhotoApi._();

  static final Dio _dio = ApiClient.buildClient(
    baseUrl: '${ApiConfig.baseUrl}/ocr/timer',
    // A photo is a few hundred KB (the phone shrinks it to 1600 px
    // before sending), over whatever the factory's signal is.
    timeout: const Duration(seconds: 30),
  );

  /// The photos kept for a shift entry (a ShiftDetail id), newest first.
  static Future<List<TimerPhotoMeta>> forShift(String shiftId) async {
    final res =
        await _dio.get('/shift/${Uri.encodeComponent(shiftId)}/photos');
    final data = res.data;
    final list = data is Map ? data['photos'] : null;
    if (list is! List) return const [];
    return list
        .whereType<Map>()
        .map((e) => TimerPhotoMeta.fromJson(Map<String, dynamic>.from(e)))
        .where((p) => p.id.isNotEmpty)
        .toList();
  }

  /// The bytes of one photo.
  static Future<Uint8List> bytes(String photoId) async {
    final res = await _dio.get<List<int>>(
      '/photo/${Uri.encodeComponent(photoId)}/file',
      options: Options(responseType: ResponseType.bytes),
    );
    return Uint8List.fromList(res.data ?? const []);
  }
}

/// Opens the viewer for a shift entry. Fetches nothing before this.
Future<void> openTimerPhotos(
  BuildContext context, {
  required String shiftId,
  String subtitle = '',
}) {
  return Navigator.of(context).push(MaterialPageRoute<void>(
    fullscreenDialog: true,
    builder: (_) => TimerPhotosPage(shiftId: shiftId, subtitle: subtitle),
  ));
}

/// "View photos". Shown on every entry, since whether it has photos is
/// only known by asking, and asking is what this waits for.
class TimerPhotosButton extends StatelessWidget {
  /// The shift entry (ShiftDetail) id.
  final String shiftId;

  /// A line under the viewer's title: the loom and shift, say.
  final String subtitle;

  /// A text button, for a row that already has a main action.
  final bool compact;

  const TimerPhotosButton({
    super.key,
    required this.shiftId,
    this.subtitle = '',
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    if (shiftId.isEmpty) return const SizedBox.shrink();
    void open() =>
        openTimerPhotos(context, shiftId: shiftId, subtitle: subtitle);
    const icon = Icon(Icons.photo_camera_outlined, size: 16);
    const label = Text('View photos');
    if (compact) {
      return TextButton.icon(
        onPressed: open,
        style: TextButton.styleFrom(
          foregroundColor: ErpColors.accentBlue,
          textStyle:
              const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
          padding: const EdgeInsets.symmetric(horizontal: 10),
          minimumSize: const Size(0, 40),
        ),
        icon: icon,
        label: label,
      );
    }
    return OutlinedButton.icon(
      onPressed: open,
      style: OutlinedButton.styleFrom(
        foregroundColor: ErpColors.accentBlue,
        side: BorderSide(color: ErpColors.accentBlue),
      ),
      icon: icon,
      label: label,
    );
  }
}

/// The photos, one to a page: pinch or double-tap to zoom, swipe for the
/// next. Opens on the photo the run time was filled from, as the web
/// does: that is the one to check the entry against.
class TimerPhotosPage extends StatefulWidget {
  final String shiftId;
  final String subtitle;

  const TimerPhotosPage({
    super.key,
    required this.shiftId,
    this.subtitle = '',
  });

  @override
  State<TimerPhotosPage> createState() => _TimerPhotosPageState();
}

class _TimerPhotosPageState extends State<TimerPhotosPage> {
  late Future<List<TimerPhotoMeta>> _list;

  /// Photos fetched while the viewer is open, so swiping back to one
  /// doesn't fetch it again. Dropped with the viewer.
  final Map<String, Future<Uint8List>> _bytes = {};

  PageController? _pager;
  int _index = 0;

  /// While a photo is zoomed in, a drag pans it instead of turning the page.
  bool _zoomed = false;

  @override
  void initState() {
    super.initState();
    _list = _load();
  }

  @override
  void dispose() {
    _pager?.dispose();
    super.dispose();
  }

  Future<List<TimerPhotoMeta>> _load() async {
    final photos = await TimerPhotoApi.forShift(widget.shiftId);
    final used = photos.indexWhere((p) => p.used);
    _index = used < 0 ? 0 : used;
    _pager?.dispose();
    _pager = PageController(initialPage: _index);
    return photos;
  }

  Future<Uint8List> _photo(String id) =>
      _bytes.putIfAbsent(id, () => TimerPhotoApi.bytes(id));

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _Dark.ground,
      appBar: AppBar(
        backgroundColor: _Dark.ground,
        foregroundColor: _Dark.text,
        elevation: 0,
        titleSpacing: 0,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Timer photos',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
            if (widget.subtitle.isNotEmpty)
              Text(widget.subtitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 11, color: _Dark.sub)),
          ],
        ),
      ),
      body: FutureBuilder<List<TimerPhotoMeta>>(
        future: _list,
        builder: (context, snap) {
          if (snap.connectionState != ConnectionState.done) {
            return const Center(
                child: CircularProgressIndicator(color: _Dark.text));
          }
          if (snap.hasError) {
            return _Message(
              icon: Icons.cloud_off_outlined,
              text: _listError(snap.error),
              action: 'Try again',
              onAction: () => setState(() => _list = _load()),
            );
          }
          final photos = snap.data ?? const <TimerPhotoMeta>[];
          if (photos.isEmpty) {
            return const _Message(
              icon: Icons.no_photography_outlined,
              text: 'No photo of the timer was taken for this entry.',
            );
          }
          final at = _index.clamp(0, photos.length - 1);
          return SafeArea(
            top: false,
            child: Column(
              children: [
                Expanded(
                  child: PageView.builder(
                    controller: _pager,
                    physics: _zoomed
                        ? const NeverScrollableScrollPhysics()
                        : const PageScrollPhysics(),
                    itemCount: photos.length,
                    onPageChanged: (i) => setState(() => _index = i),
                    itemBuilder: (_, i) {
                      final id = photos[i].id;
                      return _PhotoPage(
                        key: ValueKey(id),
                        bytes: _photo(id),
                        onRetry: () => setState(() => _bytes.remove(id)),
                        onZoomChanged: (z) {
                          if (z != _zoomed) setState(() => _zoomed = z);
                        },
                      );
                    },
                  ),
                ),
                _Caption(
                  photo: photos[at],
                  position: at + 1,
                  count: photos.length,
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  String _listError(Object? e) {
    if (e is DioException) {
      final code = e.response?.statusCode;
      if (code == 404) {
        return "This entry wasn't found, or its photos aren't yours to see.";
      }
      if (code == 401) return 'Sign in again to see the photos.';
      if (code == 403) return "Your account can't see timer photos.";
    }
    return "Couldn't load the photos. Check the connection and try again.";
  }
}

/// One photo, fetched when its page first comes up.
class _PhotoPage extends StatefulWidget {
  final Future<Uint8List> bytes;
  final VoidCallback onRetry;
  final ValueChanged<bool> onZoomChanged;

  const _PhotoPage({
    super.key,
    required this.bytes,
    required this.onRetry,
    required this.onZoomChanged,
  });

  @override
  State<_PhotoPage> createState() => _PhotoPageState();
}

class _PhotoPageState extends State<_PhotoPage> {
  final _zoom = TransformationController();
  bool _zoomed = false;
  Offset _tapAt = Offset.zero;

  @override
  void initState() {
    super.initState();
    _zoom.addListener(_onZoom);
  }

  @override
  void dispose() {
    _zoom.removeListener(_onZoom);
    _zoom.dispose();
    super.dispose();
  }

  void _onZoom() {
    final z = _zoom.value.getMaxScaleOnAxis() > 1.01;
    if (z == _zoomed) return;
    _zoomed = z;
    widget.onZoomChanged(z);
  }

  /// Double-tap: in on the spot tapped, or back out.
  void _toggleZoom() {
    if (_zoomed) {
      _zoom.value = Matrix4.identity();
      return;
    }
    // Scale about the tapped point, so it stays under the finger.
    const scale = 2.5;
    _zoom.value = Matrix4.translationValues(
        -_tapAt.dx * (scale - 1), -_tapAt.dy * (scale - 1), 0)
      ..multiply(Matrix4.diagonal3Values(scale, scale, 1));
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Uint8List>(
      future: widget.bytes,
      builder: (context, snap) {
        if (snap.connectionState != ConnectionState.done) {
          return const Center(
              child: CircularProgressIndicator(color: _Dark.text));
        }
        final data = snap.data;
        if (snap.hasError || data == null || data.isEmpty) {
          return _Message(
            icon: Icons.broken_image_outlined,
            text: "Couldn't load this photo.",
            action: 'Try again',
            onAction: widget.onRetry,
          );
        }
        return GestureDetector(
          onDoubleTapDown: (d) => _tapAt = d.localPosition,
          onDoubleTap: _toggleZoom,
          child: InteractiveViewer(
            transformationController: _zoom,
            minScale: 1,
            maxScale: 6,
            child: SizedBox.expand(
              child: Image.memory(
                data,
                fit: BoxFit.contain,
                gaplessPlayback: true,
                semanticLabel: "The loom's timer",
                errorBuilder: (_, __, ___) => const _Message(
                  icon: Icons.broken_image_outlined,
                  text: "This photo couldn't be shown.",
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

/// Under the photo: what was read off it, when and by whom it was taken.
class _Caption extends StatelessWidget {
  final TimerPhotoMeta photo;
  final int position;
  final int count;

  const _Caption({
    required this.photo,
    required this.position,
    required this.count,
  });

  static final _when = DateFormat('dd MMM, hh:mm a');
  static final _figure = NumberFormat.decimalPattern('en_IN');

  @override
  Widget build(BuildContext context) {
    final taken = [
      if (photo.takenAt != null) 'Taken ${_when.format(photo.takenAt!)}',
      if (photo.takenBy.isNotEmpty) 'by ${photo.takenBy}',
    ].join(' ');
    final readings = [
      if (photo.meterStart != null && photo.meterEnd != null)
        'Hour meter ${_figure.format(photo.meterStart)} → '
            '${_figure.format(photo.meterEnd)}',
      if (photo.counterEnd != null)
        'Metre counter ${_figure.format(photo.counterEnd)}',
    ];
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 14),
      decoration: const BoxDecoration(
        color: _Dark.panel,
        border: Border(top: BorderSide(color: _Dark.rule)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (photo.used) ...[
                Container(
                  margin: const EdgeInsets.only(top: 1, right: 8),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: ErpColors.successGreen,
                    borderRadius: BorderRadius.circular(3),
                  ),
                  child: const Text('USED',
                      style: TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.6)),
                ),
              ],
              Expanded(
                child: Text(photo.summary,
                    style: const TextStyle(
                        color: _Dark.text,
                        fontSize: 14,
                        fontWeight: FontWeight.w700)),
              ),
              if (count > 1) ...[
                const SizedBox(width: 12),
                Text('$position of $count',
                    style: const TextStyle(
                        color: _Dark.sub,
                        fontSize: 12,
                        fontFeatures: [FontFeature.tabularFigures()])),
              ],
            ],
          ),
          if (readings.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(readings.join('  ·  '),
                style: const TextStyle(
                    color: _Dark.text,
                    fontSize: 12,
                    fontFeatures: [FontFeature.tabularFigures()])),
          ],
          if (taken.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(taken,
                style: const TextStyle(color: _Dark.sub, fontSize: 12)),
          ],
          if (count > 1) ...[
            const SizedBox(height: 4),
            const Text('Swipe for the other photos',
                style: TextStyle(color: _Dark.faint, fontSize: 11)),
          ],
        ],
      ),
    );
  }
}

class _Message extends StatelessWidget {
  final IconData icon;
  final String text;
  final String? action;
  final VoidCallback? onAction;

  const _Message({
    required this.icon,
    required this.text,
    this.action,
    this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 40, color: _Dark.sub),
            const SizedBox(height: 10),
            Text(text,
                textAlign: TextAlign.center,
                style: const TextStyle(color: _Dark.text, fontSize: 13)),
            if (action != null && onAction != null) ...[
              const SizedBox(height: 12),
              OutlinedButton(
                onPressed: onAction,
                style: OutlinedButton.styleFrom(
                  foregroundColor: _Dark.text,
                  side: const BorderSide(color: _Dark.sub),
                ),
                child: Text(action!),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// The viewer is dark in either theme: a photo reads best on black.
class _Dark {
  static const ground = Color(0xFF0B0F14);
  static const panel = Color(0xFF151B23);
  static const rule = Color(0xFF26303B);
  static const text = Color(0xFFE8EDF2);
  static const sub = Color(0xFF9AA7B4);
  static const faint = Color(0xFF6B7885);
}
