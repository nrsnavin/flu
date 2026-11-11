// ══════════════════════════════════════════════════════════════
//  A PHOTO OF THE LOOM'S TIMER, TURNED INTO A RUN TIME
//
//  The server reads the photo (services/timerPhotoRead.js) and says what
//  numbers it saw: each display's text, what kind of display it looks
//  like, how sure it is, and other readings of digits it was unsure of.
//  Turning that into a run time is done here, one question at a time
//  when it cannot be sure. The same rules as the web's floor screen
//  (prod_web features/shifts/timerReading.ts), so the floor gets the same
//  questions on a phone and a tablet:
//
//    1. which display, when the photo shows more than one number;
//    2. which digits, when one could be read two ways;
//    3. what the text means: 7:45 / 7.45 (time or decimal hours?) /
//       745 (7:45?) / a total-hours meter (this shift is the difference
//       from where it stood when the shift started — taken from the
//       shift before's photo when that fits);
//    4. a check when the reading is unclear, or longer than a shift.
//
//  Anything it cannot make sense of ends in "type it", never a guess.
// ══════════════════════════════════════════════════════════════

/// The answer that means "I'll type it myself".
const typeIt = '__type__';

const _confident = 0.8;

class TimerDisplay {
  final String text;
  /// run_time | hour_meter | clock | counter | other
  final String kind;
  final String label;
  final double confidence;
  final List<String> alternatives;
  const TimerDisplay({
    required this.text,
    this.kind = 'run_time',
    this.label = '',
    this.confidence = 0.95,
    this.alternatives = const [],
  });

  factory TimerDisplay.from(Object? raw) {
    final j = raw is Map ? raw : const {};
    return TimerDisplay(
      text: j['text']?.toString() ?? '',
      kind: j['kind']?.toString() ?? 'other',
      label: j['label']?.toString() ?? '',
      confidence: (j['confidence'] is num) ? (j['confidence'] as num).toDouble() : 0,
      alternatives: (j['alternatives'] is List)
          ? (j['alternatives'] as List).map((e) => e.toString()).toList()
          : const [],
    );
  }
}

class TimerReading {
  final List<TimerDisplay> displays;
  final int? primary;
  /// blurry | glare | cut_off | too_dark | no_display
  final String? problem;
  const TimerReading({required this.displays, this.primary, this.problem});

  factory TimerReading.from(Object? raw) {
    final j = raw is Map ? raw : const {};
    return TimerReading(
      displays: (j['displays'] is List)
          ? (j['displays'] as List).map(TimerDisplay.from).toList()
          : const [],
      primary: j['primary'] is num ? (j['primary'] as num).toInt() : null,
      problem: j['problem']?.toString(),
    );
  }
}

class ReadingOption {
  final String label;
  final String value;
  const ReadingOption(this.label, this.value);
}

/// A question; [endHours] set (and no options) for the start reading of
/// a total-hours meter, which is typed.
class ReadingQuestion {
  final String id; // display | digits | start | decimal | mmss | confirm | long
  final String text;
  final List<ReadingOption> options;
  final double? endHours;
  const ReadingQuestion(this.id, this.text, {this.options = const [], this.endHours});
}

/// The total-hours meter readings a run time was worked out from.
class MeterReadings {
  final double start;
  final double end;
  /// The start is where the meter stood when the shift before ended.
  final bool fromPrevious;
  const MeterReadings(this.start, this.end, {required this.fromPrevious});
}

sealed class ReadingStep {
  const ReadingStep();
}

class AskStep extends ReadingStep {
  final ReadingQuestion question;
  final String? error;
  const AskStep(this.question, {this.error});
}

class DoneStep extends ReadingStep {
  final String runTime;
  final int seconds;
  final String text;
  final MeterReadings? meter;
  const DoneStep(this.runTime, this.seconds, this.text, {this.meter});
}

class TypeStep extends ReadingStep {
  final String reason;
  const TypeStep(this.reason);
}

const _problemWords = {
  'blurry': 'The photo is blurry.',
  'glare': "There's glare on the display.",
  'cut_off': 'The display is cut off at the edge of the photo.',
  'too_dark': 'The photo is too dark.',
  'no_display': 'No timer could be seen in the photo.',
};

String formatHMS(num totalSeconds) {
  final s = totalSeconds < 0 ? 0 : totalSeconds.round();
  final h = s ~/ 3600;
  final m = (s % 3600) ~/ 60;
  final sec = s % 60;
  return '$h:${m.toString().padLeft(2, '0')}:${sec.toString().padLeft(2, '0')}';
}

/// "7 h 45 min", for questions.
String spoken(num totalSeconds) {
  final h = (totalSeconds / 3600).floor();
  final m = ((totalSeconds % 3600) / 60).round();
  if (h != 0 && m != 0) return '$h h $m min';
  if (h != 0) return '$h h';
  return '$m min';
}

/// What a display's text is, before its meaning is decided.
sealed class ParsedText {
  const ParsedText();
}

class ColonText extends ParsedText {
  final List<int> parts;
  const ColonText(this.parts);
}

class DecimalText extends ParsedText {
  final double value;
  const DecimalText(this.value);
}

class IntegerText extends ParsedText {
  final int value;
  const IntegerText(this.value);
}

ParsedText? parseText(String text) {
  final t = text.trim().replaceAll(RegExp(r'\s+'), '').replaceFirst(RegExp(r'[hH]$'), '');
  if (RegExp(r'^\d{1,5}(:\d{2}){1,2}$').hasMatch(t)) {
    return ColonText(t.split(':').map(int.parse).toList());
  }
  if (RegExp(r'^\d+\.\d+$').hasMatch(t)) return DecimalText(double.parse(t));
  if (RegExp(r'^\d+$').hasMatch(t)) return IntegerText(int.parse(t));
  return null;
}

const _typeOption = ReadingOption("None of these, I'll type it", typeIt);

String _describe(TimerDisplay d) => d.label.isNotEmpty ? '${d.text}  (${d.label})' : d.text;

/// "1226.85" for a meter reading, as typed — not "1226.850000001".
String _num(double v) {
  final s = v.toString();
  return s.endsWith('.0') ? s.substring(0, s.length - 2) : s;
}

/// The next thing to ask, or the run time, from the reading and the
/// answers so far. [startHours]: where a total-hours meter stood when
/// the shift before ended on this loom, if its photo said.
ReadingStep nextStep(
  TimerReading reading,
  Map<String, String> answers, {
  double shiftHours = 12,
  double? startHours,
}) {
  final limit = (shiftHours + 1) * 3600;
  MeterReadings? meter;
  const typeFromDisplay = TypeStep('Type the run time from the display.');

  if (reading.problem != null && reading.displays.isEmpty) {
    final words = _problemWords[reading.problem] ?? _problemWords['no_display']!;
    return TypeStep('$words Take another photo, or type the run time.');
  }
  if (reading.displays.isEmpty) return TypeStep(_problemWords['no_display']!);

  // 1. Which display.
  final primary = (reading.primary != null &&
          reading.primary! >= 0 &&
          reading.primary! < reading.displays.length)
      ? reading.displays[reading.primary!]
      : null;
  final runTimes = reading.displays.where((d) => d.kind == 'run_time').length;
  final clearPrimary = primary != null &&
      primary.kind == 'run_time' &&
      primary.confidence >= _confident &&
      runTimes == 1;
  TimerDisplay? display;
  if (reading.displays.length == 1) {
    display = reading.displays.first;
  } else if (clearPrimary) {
    display = primary;
  } else if (!answers.containsKey('display')) {
    return AskStep(ReadingQuestion(
      'display',
      "The photo shows more than one number. Which is the loom's run time?",
      options: [
        for (var i = 0; i < reading.displays.length; i++)
          ReadingOption(_describe(reading.displays[i]), '$i'),
        _typeOption,
      ],
    ));
  } else if (answers['display'] == typeIt) {
    return typeFromDisplay;
  } else {
    final i = int.tryParse(answers['display']!);
    display = (i != null && i >= 0 && i < reading.displays.length) ? reading.displays[i] : null;
  }
  if (display == null) return typeFromDisplay;

  // 2. Which digits.
  var text = display.text;
  var askedAboutIt = false;
  if (display.alternatives.isNotEmpty) {
    if (!answers.containsKey('digits')) {
      return AskStep(ReadingQuestion(
        'digits',
        'Some digits are hard to make out. Which does the display show?',
        options: [
          for (final t in [display.text, ...display.alternatives]) ReadingOption(t, t),
          const ReadingOption("Neither, I'll type it", typeIt),
        ],
      ));
    }
    if (answers['digits'] == typeIt) return typeFromDisplay;
    text = answers['digits']!;
    askedAboutIt = true;
  }

  // 3–5. What the text means.
  final parsed = parseText(text);
  double seconds;
  if (parsed == null) {
    return TypeStep('"$text" doesn\'t look like a time. Type the run time instead.');
  }

  switch (parsed) {
    case ColonText(:final parts):
      final a = parts[0], b = parts[1], c = parts.length > 2 ? parts[2] : 0;
      if (parts.length == 2 && a * 3600 > limit) {
        // "45:12" can't be 45 hours in one shift: minutes and seconds?
        if (!answers.containsKey('mmss')) {
          return AskStep(ReadingQuestion(
            'mmss',
            '"$text" would be $a hours, longer than a shift. Is it $a minutes and $b seconds?',
            options: [ReadingOption('Yes, $a min $b s', 'yes'), const ReadingOption("No, I'll type it", typeIt)],
          ));
        }
        if (answers['mmss'] != 'yes') return typeFromDisplay;
        seconds = (a * 60 + b).toDouble();
        askedAboutIt = true;
      } else {
        seconds = (a * 3600 + b * 60 + c).toDouble();
      }
    case DecimalText(:final value) when display.kind == 'hour_meter' || value * 3600 > limit:
      // A total-hours meter: this shift is the difference from the start.
      // The shift before's end reading is the start, when it fits one shift.
      final known = (startHours != null && startHours.isFinite && answers['prevStart'] != 'no') ? startHours : null;
      final knownDiff = known != null ? (value - known) * 3600 : double.nan;
      final knownFits = knownDiff > 0 && knownDiff <= limit;
      final askStart = 'This looks like a total-hours meter reading ${_num(value)} h. '
          'What did it read when the shift started?'
          '${known != null && !knownFits ? " The shift before ended at ${_num(known)} h, which doesn't fit — was the meter reset?" : ''}';
      final fromPrevious = !answers.containsKey('start') && knownFits;
      if (!answers.containsKey('start') && !fromPrevious) {
        return AskStep(ReadingQuestion('start', askStart, endHours: value));
      }
      final startText = fromPrevious ? _num(known!) : answers['start']!;
      final start = double.tryParse(startText.trim());
      final diff = start == null ? double.nan : (value - start) * 3600;
      if (start == null || startText.trim().isEmpty || !(diff > 0) || diff > limit) {
        return AskStep(
          ReadingQuestion('start', askStart, endHours: value),
          error: diff.isFinite && diff > 0
              ? 'That makes ${spoken(diff)}, longer than a shift. Check the start reading.'
              : 'The start reading has to be lower than the reading now.',
        );
      }
      seconds = diff;
      meter = MeterReadings(start, value, fromPrevious: fromPrevious);
      // A start typed in is an answer about this reading; one taken from
      // the shift before is not, so an unclear photo is still asked about.
      if (!fromPrevious) askedAboutIt = true;
    case DecimalText(:final value):
      // "7.45": a time written with a dot, or decimal hours?
      final pieces = text.trim().split('.');
      final h = pieces[0].trim();
      final frac = pieces.length > 1 ? pieces[1] : '';
      final fracN = int.tryParse(frac);
      final asClock = (frac.length == 2 && fracN != null && fracN < 60)
          ? (int.parse(h) * 3600 + fracN * 60).toDouble()
          : null;
      final asHours = value * 3600;
      if (asClock == null) {
        seconds = asHours;
      } else if (!answers.containsKey('decimal')) {
        return AskStep(ReadingQuestion(
          'decimal',
          'Does $text mean ${spoken(asClock)}, or $text hours (${spoken(asHours)})?',
          options: [
            ReadingOption(spoken(asClock), 'clock'),
            ReadingOption('${spoken(asHours)} ($text hours)', 'hours'),
          ],
        ));
      } else {
        seconds = answers['decimal'] == 'hours' ? asHours : asClock;
        askedAboutIt = true;
      }
    case IntegerText(:final value):
      // A bare number: "745" as 7:45, if it can be one.
      final hh = value ~/ 100, mm = value % 100;
      if (display.kind == 'counter' || value < 100 || value > 2359 || mm >= 60) {
        return TypeStep('$text looks like a counter, not a time. Type the run time instead.');
      }
      if (!answers.containsKey('confirm')) {
        return AskStep(ReadingQuestion(
          'confirm',
          'Is $text a run time of ${spoken(hh * 3600 + mm * 60)}?',
          options: const [ReadingOption('Yes', 'yes'), ReadingOption("No, I'll type it", typeIt)],
        ));
      }
      if (answers['confirm'] != 'yes') return typeFromDisplay;
      seconds = (hh * 3600 + mm * 60).toDouble();
      askedAboutIt = true;
  }

  // 6. Unsure overall, and nothing has been asked about it yet.
  if (!askedAboutIt && display.confidence < _confident) {
    if (!answers.containsKey('confirm')) {
      return AskStep(ReadingQuestion(
        'confirm',
        "The photo isn't very clear. Is the run time ${formatHMS(seconds)}?",
        options: const [ReadingOption('Yes', 'yes'), ReadingOption("No, I'll type it", typeIt)],
      ));
    }
    if (answers['confirm'] != 'yes') return typeFromDisplay;
  }

  // 7. Longer than a shift.
  if (seconds > limit) {
    if (!answers.containsKey('long')) {
      return AskStep(ReadingQuestion(
        'long',
        '${spoken(seconds)} is longer than a ${_num(shiftHours)}-hour shift. Use it anyway?',
        options: const [ReadingOption('Use it anyway', 'yes'), ReadingOption("No, I'll type it", typeIt)],
      ));
    }
    if (answers['long'] != 'yes') return typeFromDisplay;
  }

  return DoneStep(formatHMS(seconds), seconds.round(), text, meter: meter);
}

// ── A metre counter on the same panel ─────────────────────────────

final _metreUnit = RegExp(r'^(m|mt|mtr|mtrs|metre|metres|meter|meters|length)\.?$', caseSensitive: false);

class MetreCounter {
  final String text;
  final double value;
  final String label;
  const MetreCounter(this.text, this.value, this.label);
}

/// A counter the photo shows whose printed unit is metres ("MTR", "M"),
/// as a number — the metres can be filled from it instead of worked out
/// from the run time. Null when there is none, or it is not a number. A
/// pick or piece counter is not metres.
MetreCounter? metreCounter(TimerReading reading) {
  for (final d in reading.displays) {
    if (d.kind != 'counter' || !_metreUnit.hasMatch(d.label.trim())) continue;
    final t = d.text.replaceAll(RegExp(r'[,\s]'), '');
    if (!RegExp(r'^\d+(\.\d+)?$').hasMatch(t)) continue;
    return MetreCounter(d.text, double.parse(t), d.label.trim());
  }
  return null;
}
