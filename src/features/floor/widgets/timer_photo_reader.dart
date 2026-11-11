import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/capture.dart';
import '../../PurchaseOrder/services/theme.dart';
import '../floor_api.dart';
import '../timer_reading.dart';

// ══════════════════════════════════════════════════════════════
//  THE RUN TIME FROM A PHOTO OF THE LOOM'S TIMER
//
//  On the floor every entry should come with a photo of the display:
//  the supervisor photographs it, the server reads it, and the run time
//  is filled from what it read. Where the reading is unclear the
//  questions in timer_reading.dart are asked — which display, which
//  digits, where a total-hours meter started — and "type it" is always
//  there. The photo is kept with the loom's entry (when the loom is on
//  the shift), so whoever verifies it can see the display themselves.
//
//  The same flow as the web's floor screen (TimerPhotoReader.tsx).
// ══════════════════════════════════════════════════════════════

enum _Phase { idle, reading, steps, failed, used }

class TimerPhotoReader extends StatefulWidget {
  /// The loom's row on the shift; the photo is kept with it. Null before
  /// an operator puts the loom on the shift: the photo is read, not kept.
  final String? detailId;

  /// Where a total-hours meter stood when the shift before ended (its
  /// photo): the start of this shift.
  final double? startHours;

  /// Where a metre counter stood when the shift before ended.
  final double? previousMetres;

  final void Function(String runTime) onUse;
  final void Function(double metres) onMetres;

  /// The floor session ended: ask for the PIN again.
  final Future<bool> Function() onPinAgain;

  const TimerPhotoReader({
    super.key,
    required this.detailId,
    required this.onUse,
    required this.onMetres,
    required this.onPinAgain,
    this.startHours,
    this.previousMetres,
  });

  @override
  State<TimerPhotoReader> createState() => _TimerPhotoReaderState();
}

class _TimerPhotoReaderState extends State<TimerPhotoReader> {
  static const _kept = 'The photo is saved with this shift for whoever verifies it.';

  _Phase _phase = _Phase.idle;
  Uint8List? _photo;
  TimerReading? _reading;
  String? _photoId;
  final Map<String, String> _answers = {};
  String? _failure;
  bool _keptAnyway = false;
  String? _usedRunTime;
  MetreCounter? _counter;
  double? _counterUsed;
  final _start = TextEditingController();

  @override
  void dispose() {
    _start.dispose();
    super.dispose();
  }

  Future<void> _take(CaptureSource source) async {
    // A display needs far less than a phone's 12 megapixels.
    final shot = await capture(source, maxImageWidth: 1600, imageQuality: 85);
    if (shot == null || !mounted) return;
    setState(() {
      _photo = shot.bytes;
      _phase = _Phase.reading;
      _answers.clear();
      _start.clear();
      _counter = null;
      _counterUsed = null;
      _failure = null;
      _keptAnyway = false;
    });
    try {
      final out = await FloorApi.instance.readTimerPhoto(shot.bytes, detailId: widget.detailId);
      if (!mounted) return;
      setState(() {
        _reading = out.reading;
        _photoId = out.photoId;
        _counter = metreCounter(out.reading);
        _phase = _Phase.steps;
      });
    } on FloorError catch (e) {
      if (!mounted) return;
      if (e.pinAgain) {
        setState(() => _phase = _Phase.idle);
        await widget.onPinAgain();
        return;
      }
      setState(() {
        _failure = e.message;
        _keptAnyway = e.details['photoId'] is String;
        _phase = _Phase.failed;
      });
    }
  }

  void _answer(String id, String value) {
    setState(() {
      _answers[id] = value;
      _start.clear();
    });
  }

  void _use(String runTime, MeterReadings? meter) {
    final id = _photoId;
    if (id != null) {
      FloorApi.instance.photoUsed(id, runTime, meter: meter, counter: _counter?.value);
    }
    widget.onUse(runTime);
    setState(() {
      _usedRunTime = runTime;
      _phase = _Phase.used;
    });
  }

  void _fillMetres(double m) {
    widget.onMetres(m);
    setState(() => _counterUsed = m);
  }

  @override
  Widget build(BuildContext context) {
    switch (_phase) {
      case _Phase.idle:
        return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          SizedBox(
            height: 48,
            child: OutlinedButton.icon(
              onPressed: () => _take(CaptureSource.camera),
              icon: const Icon(Icons.photo_camera_outlined, size: 20),
              label: const Text('Take a photo of this shift’s timer',
                  style: TextStyle(fontWeight: FontWeight.w700)),
            ),
          ),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton(
              onPressed: () => _take(CaptureSource.gallery),
              child: const Text('or choose a photo', style: TextStyle(fontSize: 12)),
            ),
          ),
        ]);
      case _Phase.used:
        return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Icon(Icons.check_circle_rounded, size: 16, color: ErpColors.successGreen),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                'Filled from the photo: $_usedRunTime${_photoId != null ? '  (photo saved with the shift)' : ''}',
                style: TextStyle(fontSize: 12.5, color: ErpColors.textPrimary),
              ),
            ),
            TextButton(onPressed: () => _take(CaptureSource.camera), child: const Text('Retake')),
          ]),
          if (_counter != null) _counterOffer(),
        ]);
      case _Phase.reading:
      case _Phase.steps:
      case _Phase.failed:
        return Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: ErpColors.bgMuted,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: ErpColors.borderLight),
          ),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            if (_photo != null)
              ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: Image.memory(_photo!, width: 72, height: 72, fit: BoxFit.cover,
                    semanticLabel: 'The timer photo'),
              ),
            const SizedBox(width: 10),
            Expanded(child: _body()),
          ]),
        );
    }
  }

  Widget _body() {
    final text = TextStyle(fontSize: 12.5, color: ErpColors.textPrimary, height: 1.35);
    final again = TextButton.icon(
      onPressed: () => _take(CaptureSource.camera),
      icon: const Icon(Icons.refresh_rounded, size: 16),
      label: const Text('Take another photo', style: TextStyle(fontSize: 12)),
    );
    if (_phase == _Phase.reading) {
      return Row(children: [
        SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: ErpColors.accentBlue)),
        const SizedBox(width: 8),
        Text('Reading the timer…', style: text),
      ]);
    }
    if (_phase == _Phase.failed) {
      return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(_failure ?? 'Could not read the photo.', style: text.copyWith(color: ErpColors.errorRed)),
        if (_keptAnyway) ...[
          const SizedBox(height: 4),
          Text(_kept, style: TextStyle(fontSize: 11, color: ErpColors.textSecondary)),
        ],
        again,
      ]);
    }
    final step = nextStep(_reading!, _answers, startHours: widget.startHours);
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      if (_counter != null) _counterOffer(),
      switch (step) {
        TypeStep(:final reason) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(reason, style: text),
            if (_photoId != null) ...[
              const SizedBox(height: 4),
              Text(_kept, style: TextStyle(fontSize: 11, color: ErpColors.textSecondary)),
            ],
          ]),
        DoneStep(:final runTime, text: final read, :final meter) =>
          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text.rich(TextSpan(style: text, children: [
              const TextSpan(text: 'Run time '),
              TextSpan(text: runTime, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
              if (read != runTime) TextSpan(text: '  from “$read”', style: TextStyle(fontSize: 11, color: ErpColors.textMuted)),
            ])),
            if (meter != null && meter.fromPrevious)
              Wrap(crossAxisAlignment: WrapCrossAlignment.center, children: [
                Text('Meter ${_n(meter.start)} h at the start — where it stood when the shift before ended — to ${_n(meter.end)} h now.',
                    style: TextStyle(fontSize: 11, color: ErpColors.textSecondary)),
                TextButton(
                  onPressed: () => _answer('prevStart', 'no'),
                  child: const Text('Different start reading', style: TextStyle(fontSize: 12)),
                ),
              ]),
            const SizedBox(height: 4),
            FilledButton.icon(
              onPressed: () => _use(runTime, meter),
              icon: const Icon(Icons.check_rounded, size: 16),
              label: const Text('Use this'),
            ),
          ]),
        AskStep(:final question, :final error) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(question.text, style: text.copyWith(fontWeight: FontWeight.w700)),
            const SizedBox(height: 6),
            if (question.options.isNotEmpty)
              for (final o in question.options)
                Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: o.value == typeIt
                      ? TextButton(
                          onPressed: () => _answer(question.id, o.value),
                          child: Text(o.label, style: TextStyle(fontSize: 12, color: ErpColors.textSecondary)),
                        )
                      : SizedBox(
                          width: double.infinity,
                          child: OutlinedButton(
                            style: OutlinedButton.styleFrom(alignment: Alignment.centerLeft),
                            onPressed: () => _answer(question.id, o.value),
                            child: Text(o.label),
                          ),
                        ),
                )
            else
              Row(children: [
                Expanded(
                  child: TextField(
                    controller: _start,
                    autofocus: true,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]'))],
                    decoration: ErpDecorations.formInput('Meter at the start of the shift', hint: 'e.g. 1226.9'),
                    onSubmitted: (v) {
                      if (v.trim().isNotEmpty) _answer('start', v.replaceAll(',', '.'));
                    },
                  ),
                ),
                const SizedBox(width: 8),
                FilledButton(
                  onPressed: () {
                    if (_start.text.trim().isNotEmpty) _answer('start', _start.text.replaceAll(',', '.'));
                  },
                  child: const Text('Next'),
                ),
              ]),
            if (error != null) ...[
              const SizedBox(height: 4),
              Text(error, style: TextStyle(fontSize: 12, color: ErpColors.errorRed)),
            ],
          ]),
      },
      again,
    ]);
  }

  /// A metre counter seen in the photo: offered for the metres a head —
  /// as it reads, or less where it stood when the shift before ended.
  Widget _counterOffer() {
    final c = _counter!;
    final prev = widget.previousMetres;
    final since = (prev != null && c.value > prev) ? ((c.value - prev) * 100).round() / 100 : null;
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: ErpColors.bgSurface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: ErpColors.borderLight),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('The photo also shows a metre counter: ${c.text} ${c.label}',
            style: TextStyle(fontSize: 12, color: ErpColors.textPrimary)),
        if (_counterUsed != null)
          Text('Metres a head filled: ${_n(_counterUsed!)}',
              style: TextStyle(fontSize: 11, color: ErpColors.successGreen))
        else
          Wrap(spacing: 6, children: [
            if (since != null)
              OutlinedButton(
                onPressed: () => _fillMetres(since),
                child: Text('Use ${_n(since)} m — since the shift before', style: const TextStyle(fontSize: 12)),
              ),
            OutlinedButton(
              onPressed: () => _fillMetres(c.value),
              child: Text('Use ${_n(c.value)} m', style: const TextStyle(fontSize: 12)),
            ),
          ]),
      ]),
    );
  }

  static String _n(double v) => v == v.roundToDouble() ? v.toInt().toString() : v.toString();
}
