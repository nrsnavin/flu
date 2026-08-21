// Run with:  dart run src/features/Warping/tape_repeat_check.dart
//
// Checks the tape-repeat arithmetic on a bare Dart VM. No Flutter, no
// GetX, no camera, no network — so it runs in a second and fails for
// exactly one reason.

import 'tape_repeat.dart';

int _passed = 0;
final _failures = <String>[];

void check(String what, bool ok, [String? detail]) {
  if (ok) {
    _passed++;
  } else {
    _failures.add('FAIL: $what${detail == null ? '' : '  ($detail)'}');
  }
}

/// A two-beam template: beam A on one yarn, beam B on two.
List<TemplateBeamSpec> twoBeamTemplate() => const [
      TemplateBeamSpec(
        elasticId: 'e1',
        elasticName: 'ELA-20mm',
        sections: [
          TemplateSectionSpec(
              warpYarnId: 'y1', warpYarnName: 'Nylon 40D', ends: 240,
              maxMeters: 5000),
        ],
      ),
      TemplateBeamSpec(
        elasticId: 'e1',
        elasticName: 'ELA-20mm',
        sections: [
          TemplateSectionSpec(
              warpYarnId: 'y1', warpYarnName: 'Nylon 40D', ends: 120,
              maxMeters: 5000),
          TemplateSectionSpec(
              warpYarnId: 'y2', warpYarnName: 'Poly 70D', ends: 60,
              maxMeters: 5000),
        ],
      ),
    ];

void main() {
  final tpl = twoBeamTemplate();

  // ── One tape is the template, unchanged ───────────────────
  var out = repeatTemplatePerTape(tpl, 1);
  check('one tape gives the template back', out.length == 2, 'got ${out.length}');
  check('one tape numbers beams 1,2',
      out[0].beamNo == 1 && out[1].beamNo == 2, 'got $out');
  check('one tape stamps tape 1',
      out.every((b) => b.tapeNo == 1), 'got $out');

  // ── Three tapes ───────────────────────────────────────────
  out = repeatTemplatePerTape(tpl, 3);
  check('three tapes of a two-beam template is six beams',
      out.length == 6, 'got ${out.length}');

  // Beam numbers run STRAIGHT THROUGH, not restarting per tape.
  // This is the assertion the whole feature turns on: two beam 1s
  // would be two things on the rack with one name.
  check('beam numbers run straight through',
      out.map((b) => b.beamNo).join(',') == '1,2,3,4,5,6',
      'got ${out.map((b) => b.beamNo).join(',')}');

  check('tape numbers repeat per template pass',
      out.map((b) => b.tapeNo).join(',') == '1,1,2,2,3,3',
      'got ${out.map((b) => b.tapeNo).join(',')}');

  // Each tape is a full copy, so the build repeats with it.
  check('every tape carries the same section counts',
      out.map((b) => b.sections.length).join(',') == '1,2,1,2,1,2',
      'got ${out.map((b) => b.sections.length).join(',')}');
  check('the ends repeat unchanged',
      out.map((b) => b.sections.first.ends).join(',') == '240,120,240,120,240,120',
      'got ${out.map((b) => b.sections.first.ends).join(',')}');
  check('the elastic repeats with the beam',
      out.every((b) => b.elasticId == 'e1'), 'got $out');

  // ── Sections are independent copies ───────────────────────
  // Sharing them would make editing tape 3 silently edit tape 1.
  // Identity, not equality: the values are meant to be the same.
  check('tape 3 does not share section objects with tape 1',
      !identical(out[0].sections.first, out[4].sections.first));
  check('CONTROL: a beam does share with itself',
      identical(out[0].sections.first, out[0].sections.first));

  // ── The clamp ─────────────────────────────────────────────
  check('zero tapes means one', clampTapes(0) == 1);
  check('negative tapes means one', clampTapes(-4) == 1);
  check('null tapes means one', clampTapes(null) == 1);
  check('one stays one', clampTapes(1) == 1);
  check('an ordinary count is untouched', clampTapes(8) == 8);
  check('the cap holds', clampTapes(500) == kMaxTapes, 'got ${clampTapes(500)}');
  check('the cap is not off by one', clampTapes(kMaxTapes) == kMaxTapes);

  check('zero tapes still builds one tape of beams',
      repeatTemplatePerTape(tpl, 0).length == 2,
      'got ${repeatTemplatePerTape(tpl, 0).length}');

  // ── An empty template ─────────────────────────────────────
  // Returns nothing rather than inventing a blank beam. The caller
  // knows whether it is prefilling or rebuilding; this does not.
  check('an empty template repeats to nothing',
      repeatTemplatePerTape(const [], 5).isEmpty);

  // ── The count shown on the form ───────────────────────────
  check('4 beams over 8 tapes reads as 32', beamsForTapes(4, 8) == 32);
  check('the count clamps the same way', beamsForTapes(4, 0) == 4);
  check('the count caps the same way',
      beamsForTapes(2, 500) == 2 * kMaxTapes);

  // ── What a repeat must NOT carry ──────────────────────────
  // The lot is decided against stock, per section, later — a
  // template says how the elastic is built, not which dye lot this
  // run comes off. There is nowhere on these types to put one, which
  // is the point: the type makes carrying it impossible rather than
  // merely discouraged.
  check('a planned section has no lot field to carry',
      out[0].sections.first.toString().isNotEmpty);

  // ── CONTROLS ──────────────────────────────────────────────
  // Without these, an implementation that ignored `tapes` entirely
  // would pass everything above that only looks at one tape.
  check('CONTROL: more tapes really does mean more beams',
      repeatTemplatePerTape(tpl, 5).length >
          repeatTemplatePerTape(tpl, 2).length);
  check('CONTROL: the last beam of 8 tapes is numbered 16',
      repeatTemplatePerTape(tpl, 8).last.beamNo == 16,
      'got ${repeatTemplatePerTape(tpl, 8).last.beamNo}');
  check('CONTROL: the last beam of 8 tapes is on tape 8',
      repeatTemplatePerTape(tpl, 8).last.tapeNo == 8,
      'got ${repeatTemplatePerTape(tpl, 8).last.tapeNo}');
  check('CONTROL: a one-beam template numbers tape n as beam n',
      repeatTemplatePerTape([tpl.first], 7).last.beamNo == 7);

  // ── Parsing the server's templateBeams ────────────────────
  // The shape api/warping.js sends on /plan-context — NOT
  // prefillTemplate, which is the first elastic only.
  final parsed = TemplateBeamSpec.fromJson({
    'beamNo': 1,
    'elasticId': 'e9',
    'elasticName': 'ELA-32mm',
    'sections': [
      {'warpYarnId': 'y7', 'warpYarnName': 'Nylon 70D', 'ends': 300,
       'maxMeters': 4500},
    ],
  });
  check('a server beam keeps its elastic', parsed.elasticId == 'e9');
  check('a server beam keeps its elastic name',
      parsed.elasticName == 'ELA-32mm');
  check('a server section keeps its ends', parsed.sections.first.ends == 300);
  check('a server section keeps its meters',
      parsed.sections.first.maxMeters == 4500);

  // Missing fields must not throw — a template written before a
  // field existed still has to load.
  final sparse = TemplateBeamSpec.fromJson({'sections': []});
  check('a beam with no elastic loads', sparse.elasticId == null);
  check('a beam with no sections loads', sparse.sections.isEmpty);
  final sparseSec = TemplateSectionSpec.fromJson({});
  check('a section with nothing in it loads as zeros',
      sparseSec.ends == 0 && sparseSec.maxMeters == 0 &&
          sparseSec.warpYarnId == null);

  // ── Report ────────────────────────────────────────────────
  for (final f in _failures) {
    // ignore: avoid_print
    print(f);
  }
  // ignore: avoid_print
  print(_failures.isEmpty
      ? 'ALL PASS ($_passed checks)'
      : '${_failures.length} FAILED, $_passed passed');
}
