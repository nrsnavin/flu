import 'package:flutter/material.dart';

import '../../PurchaseOrder/services/theme.dart';
import '../models/gstin_models.dart';
import '../services/gstin_api.dart';

// ══════════════════════════════════════════════════════════════
//  THE GSTIN FIELD WITH "VERIFY" BESIDE IT
//
//  One tap asks the GST system (through the server) who the number is
//  registered to, where, and whether it is still active — and fills the
//  form it sits in.
//
//  What is filled, and what is not:
//    • an empty field takes the registration's value;
//    • what somebody typed is kept and listed, with one tap to take the
//      registration's value instead;
//    • what Verify itself filled in earlier is Verify's to replace: a
//      second number does not leave the first one's address behind, and
//      where it would, the form says whose details it still holds;
//    • a registration that is cancelled, suspended or inactive fills
//      nothing by itself: it says so, and offers the details;
//    • opening a party that was checked before shows that check, and
//      changes nothing.
//
//  The result belongs to the number it was made for: change the GSTIN
//  and it is no longer shown.
// ══════════════════════════════════════════════════════════════

/// One field of the form this sits in, and the part of the registration
/// that goes in it.
class GstinFieldTarget {
  /// What the form calls it ("Customer name").
  final String label;

  /// name, address, fullAddress, city, pincode, stateCode or pan.
  final String part;
  final TextEditingController controller;
  const GstinFieldTarget({required this.label, required this.part, required this.controller});
}

class GstinVerifyField extends StatefulWidget {
  /// "customer" or "supplier": whose form this is, and so whose route is asked.
  final String kind;
  final TextEditingController controller;
  final List<GstinFieldTarget> targets;

  /// What the form holds that is not text — a choice, a switch. Called
  /// when the form is filled; returns what it changed, in words.
  final List<String> Function(GstinFill fill)? facts;

  /// An existing party: show the check kept for its GSTIN, if any.
  final bool showEarlier;
  final String label;
  final String? hint;
  final FormFieldValidator<String>? validator;

  const GstinVerifyField({
    super.key,
    required this.kind,
    required this.controller,
    required this.targets,
    this.facts,
    this.showEarlier = false,
    this.label = 'GSTIN',
    this.hint,
    this.validator,
  });

  @override
  State<GstinVerifyField> createState() => _GstinVerifyFieldState();
}

class _GstinVerifyFieldState extends State<GstinVerifyField> {
  bool _busy = false;
  String _error = '';
  String _errorFor = '';
  GstinAnswer? _answer;
  bool _fromEarlier = false;
  bool _applied = false;
  List<String> _filled = const [];
  List<KeptField> _kept = const [];

  /// What Verify put in each field, and for which GSTIN.
  final Map<String, Wrote> _wrote = {};

  /// The newest request wins: an answer for a number since changed, or
  /// one overtaken by "Check again", is dropped.
  int _turn = 0;

  String get _gstin => normalGstin(widget.controller.text);
  bool get _canVerify => gstinInfo(_gstin).valid;

  // Each target is known to the plan by its place in the form.
  String _field(int i) => 't$i';
  List<FillTarget> get _targets =>
      [for (var i = 0; i < widget.targets.length; i++) FillTarget(_field(i), widget.targets[i].label, widget.targets[i].part)];
  Map<String, String> get _current => {for (var i = 0; i < widget.targets.length; i++) _field(i): widget.targets[i].controller.text};
  TextEditingController _controllerOf(String field) => widget.targets[int.parse(field.substring(1))].controller;

  void _redraw() {
    if (mounted) setState(() {});
  }

  /// The state of the GSTIN that stood in the field before this one.
  String _stateOfGstin = '';

  /// The state code follows the GSTIN: filled when it is empty, and
  /// moved when it still holds the state of the number that was here
  /// before. That one was read off a number, not typed — left behind
  /// under a GSTIN of another state it would put the wrong tax (IGST or
  /// CGST+SGST) on every invoice. A code somebody typed is not touched.
  void _onGstin() {
    final i = gstinInfo(_gstin);
    if (i.valid) {
      final at = widget.targets.indexWhere((t) => t.part == 'stateCode');
      if (at >= 0) {
        final c = widget.targets[at].controller;
        final now = c.text.trim();
        if ((now.isEmpty || now == _stateOfGstin) && now != i.stateCode) c.text = i.stateCode;
      }
      _stateOfGstin = i.stateCode;
    }
    _redraw();
  }

  void _listen(GstinVerifyField w) {
    w.controller.addListener(_onGstin);
    for (final t in w.targets) {
      t.controller.addListener(_redraw);
    }
  }

  void _unlisten(GstinVerifyField w) {
    w.controller.removeListener(_onGstin);
    for (final t in w.targets) {
      t.controller.removeListener(_redraw);
    }
  }

  @override
  void initState() {
    super.initState();
    _stateOfGstin = gstinInfo(_gstin).stateCode;
    _listen(widget);
    if (widget.showEarlier) _loadEarlier();
  }

  @override
  void didUpdateWidget(GstinVerifyField old) {
    super.didUpdateWidget(old);
    // A page that builds its controllers afresh hands this new ones.
    _unlisten(old);
    _listen(widget);
  }

  @override
  void dispose() {
    _unlisten(widget);
    super.dispose();
  }

  /// An existing party: what the last check of its GSTIN said. Asked
  /// once, for the number the form opened with; it fills nothing.
  Future<void> _loadEarlier() async {
    final g = _gstin;
    if (!gstinInfo(g).valid) return;
    final mine = _turn;
    try {
      final kept = await GstinApi.lastCheck(widget.kind, g);
      if (!mounted || mine != _turn || kept == null || !kept.portal.checked) return;
      setState(() {
        _answer = kept;
        _fromEarlier = true;
      });
    } catch (_) {
      // No earlier check to show: the form is as usable without it.
    }
  }

  /// Put [parts] in the form. [whole] is the registration they came
  /// from, or null when they are only what the number itself gives.
  void _apply(Map<String, String> parts, GstinFill? whole, String forGstin) {
    final plan = planFill(targets: _targets, parts: parts, current: _current, wrote: _wrote);
    for (final f in plan.adopted) {
      _wrote[f] = Wrote(cleanText(_controllerOf(f).text), forGstin);
    }
    plan.writes.forEach((field, value) {
      _controllerOf(field).text = value;
      _wrote[field] = Wrote(value, forGstin);
    });
    final done = [...plan.filled, if (whole != null) ...?widget.facts?.call(whole)];
    setState(() {
      _filled = done;
      _kept = plan.kept;
      _applied = whole != null;
    });
  }

  Future<void> _verify({bool fresh = false}) async {
    if (!_canVerify || _busy) return;
    FocusManager.instance.primaryFocus?.unfocus();
    final g = _gstin;
    final mine = ++_turn;
    setState(() {
      _busy = true;
      _error = '';
    });
    try {
      final a = await GstinApi.verify(widget.kind, g, fresh: fresh);
      if (!mounted || mine != _turn) return;
      setState(() {
        _answer = a;
        _fromEarlier = false;
        _filled = const [];
        _kept = const [];
        _applied = false;
      });
      if (a.fill != null && a.portal.live) {
        _apply(a.fill!.parts, a.fill, a.gstin);
      } else if (!a.portal.checked && a.checksumOk) {
        // Nobody was asked, but the number itself gives two of the fields.
        _apply(a.fromTheNumber, null, a.gstin);
      }
    } catch (e) {
      if (!mounted || mine != _turn) return;
      setState(() {
        _answer = null;
        _error = gstinMessage(e, 'The GSTIN could not be checked. Try again.');
        _errorFor = g;
      });
    } finally {
      if (mounted && mine == _turn) setState(() => _busy = false);
    }
  }

  void _use(String field, String value, String label) {
    _controllerOf(field).text = value;
    _wrote[field] = Wrote(cleanText(value), _gstin);
    setState(() {
      _kept = _kept.where((k) => k.field != field).toList();
      if (!_filled.contains(label)) _filled = [..._filled, label];
    });
  }

  /// Said once a whole other GSTIN stands in the field, not at every
  /// keystroke on the way to it.
  List<FillTarget> get _stale =>
      _canVerify ? staleTargets(targets: _targets, current: _current, wrote: _wrote, gstin: _gstin) : const [];

  void _clearStale() {
    for (final t in _stale) {
      _controllerOf(t.field).text = '';
      _wrote.remove(t.field);
    }
    _redraw();
  }

  @override
  Widget build(BuildContext context) {
    final g = _gstin;
    final shown = _answer != null && _answer!.gstin == g ? _answer : null;
    final error = _errorFor == g ? _error : '';
    final stale = _stale;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: TextFormField(
                controller: widget.controller,
                style: ErpTextStyles.fieldValue,
                textCapitalization: TextCapitalization.characters,
                autocorrect: false,
                enableSuggestions: false,
                validator: widget.validator,
                decoration: ErpDecorations.formInput(
                  widget.label,
                  hint: widget.hint,
                  prefix: Icon(Icons.receipt_outlined, size: 18, color: ErpColors.textMuted),
                ),
              ),
            ),
            const SizedBox(width: 8),
            SizedBox(
              height: 48,
              child: OutlinedButton.icon(
                key: const Key('gstin-verify'),
                onPressed: _canVerify && !_busy ? () => _verify() : null,
                style: OutlinedButton.styleFrom(
                  foregroundColor: ErpColors.accentBlue,
                  side: BorderSide(color: _canVerify ? ErpColors.accentBlue : ErpColors.borderMid),
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                ),
                icon: _busy
                    ? SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: ErpColors.accentBlue))
                    : const Icon(Icons.verified_outlined, size: 16),
                label: const Text('Verify', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
              ),
            ),
          ],
        ),
        _hint(g),
        if (error.isNotEmpty) _Box(tone: _Tone.danger, children: [_line(error, bold: true)]),
        if (shown != null) _result(shown),
        if (stale.isNotEmpty)
          _Box(
            tone: _Tone.warning,
            children: [
              _line('The form still holds what was filled in from ${_wrote[stale.first.field]!.gstin}, a different GSTIN: '
                  '${stale.map((t) => t.label).join(', ')}.'),
              _link(stale.length == 1 ? 'Clear it' : 'Clear them', _clearStale),
            ],
          ),
      ],
    );
  }

  /// What the number itself says, as it is typed.
  Widget _hint(String g) {
    if (g.isEmpty) return const SizedBox.shrink();
    final i = gstinInfo(g);
    final ok = i.valid && i.checksumOk;
    final text = !i.valid
        ? 'Not a GSTIN: 15 characters, like 33AAECS1234F1Z5.'
        : 'State ${i.stateCode} · PAN ${i.pan}${i.checksumOk ? '' : ' · the last character does not match — check for a typo'}';
    return Padding(
      padding: const EdgeInsets.only(top: 4, left: 2),
      child: Text(text, style: TextStyle(fontSize: 11, color: ok ? ErpColors.textMuted : ErpColors.warningAmber)),
    );
  }

  Widget _result(GstinAnswer a) {
    final p = a.portal;

    // The GST system was not asked: a typo, or nobody is connected.
    if (!p.checked) {
      return _Box(
        tone: p.reason == 'checksum' ? _Tone.warning : _Tone.neutral,
        children: [
          _line(a.message),
          if (_filled.isNotEmpty) _line('Filled in from the number itself: ${_filled.join(', ')}.', small: true),
        ],
      );
    }

    if (!p.found) {
      return _Box(
        tone: _Tone.warning,
        children: [
          _line(a.message, bold: true),
          _line('Nothing was filled in. Compare the number with their invoice or registration certificate.', small: true),
          _footer(p),
        ],
      );
    }

    final f = a.fill;
    final tone = p.live
        ? (p.status == 'active' ? _Tone.success : _Tone.neutral)
        : (p.status == 'cancelled' ? _Tone.danger : _Tone.warning);
    final canFill = f != null && !_applied;

    // The other of its two names, offered when the form holds one of them.
    final nameAt = widget.targets.indexWhere((t) => t.part == 'name');
    ({String value, String what})? other;
    if (f != null && nameAt >= 0 && f.legalName.isNotEmpty && f.tradeName.isNotEmpty && !sameText(f.legalName, f.tradeName)) {
      final now = widget.targets[nameAt].controller.text;
      if (sameText(now, f.tradeName)) other = (value: f.legalName, what: 'legal name');
      if (sameText(now, f.legalName)) other = (value: f.tradeName, what: 'trade name');
    }

    return _Box(
      tone: tone,
      children: [
        _Chip(text: '${p.statusText.isEmpty ? 'Status not given' : p.statusText} on the GST portal', tone: tone),
        // A live registration: who it is. Otherwise said in full, with what it means.
        _line(p.live ? p.names : a.message, bold: true),
        if (p.about.isNotEmpty) _line(p.about, small: true),
        if (f != null && f.fullAddress.isNotEmpty) _line(f.fullAddress, small: true),
        if (p.einvoiceBlocked == true)
          _line('The e-invoice system has this GSTIN blocked: an IRN cannot be raised on it.', small: true, color: ErpColors.warningAmber),
        if (canFill) ...[
          _link('Fill the form from this', () => _apply(f.parts, f, a.gstin)),
          _line(p.live ? 'Empty fields are filled; what is typed stays.' : 'Nothing was filled in by itself.', small: true),
        ],
        if (!canFill && f != null)
          _line(
            _filled.isNotEmpty
                ? 'Filled in: ${_filled.join(', ')}.'
                : _kept.isNotEmpty
                    ? 'Nothing was empty to fill.'
                    : 'The form already matches the registration.',
            small: true,
          ),
        for (final k in _kept) ...[
          _line('${k.label} is kept as typed (“${k.current}”). The registration has “${k.value}”.', small: true),
          _link('Use the registration\'s ${k.label.toLowerCase()}', () => _use(k.field, k.value, k.label)),
        ],
        if (other != null) ...[
          _line('Its ${other.what} is “${other.value}”.', small: true),
          _link('Use the ${other.what}', () => _use(_field(nameAt), other!.value, widget.targets[nameAt].label)),
        ],
        _footer(p),
      ],
    );
  }

  Widget _footer(GstinPortal p) => Wrap(
        crossAxisAlignment: WrapCrossAlignment.center,
        spacing: 8,
        children: [
          Text('${p.checkedLine(earlier: _fromEarlier)}.', style: TextStyle(fontSize: 11, color: ErpColors.textMuted)),
          _link('Check again', _busy ? null : () => _verify(fresh: true)),
        ],
      );

  Widget _line(String text, {bool bold = false, bool small = false, Color? color}) => Text(
        text,
        style: TextStyle(
          fontSize: small ? 11.5 : 13,
          height: 1.35,
          fontWeight: bold ? FontWeight.w600 : FontWeight.w400,
          color: color ?? (small ? ErpColors.textSecondary : ErpColors.textPrimary),
        ),
      );

  /// A link-sized button: big enough to tap, small enough to sit in the text.
  Widget _link(String text, VoidCallback? onTap) => Align(
        alignment: Alignment.centerLeft,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(4),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 2),
            child: Text(
              text,
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w700,
                color: onTap == null ? ErpColors.textMuted : ErpColors.accentBlue,
                decoration: TextDecoration.underline,
                decorationColor: onTap == null ? ErpColors.textMuted : ErpColors.accentBlue,
              ),
            ),
          ),
        ),
      );
}

enum _Tone { success, warning, danger, neutral }

(Color bg, Color border, Color ink) _colours(_Tone t) => switch (t) {
      _Tone.success => (ErpColors.statusCompletedBg, ErpColors.statusCompletedBorder, ErpColors.statusCompletedText),
      _Tone.warning => (ErpColors.statusPartialBg, ErpColors.statusPartialBorder, ErpColors.statusPartialText),
      _Tone.danger => (ErpColors.statusCancelledBg, ErpColors.statusCancelledBorder, ErpColors.statusCancelledText),
      _Tone.neutral => (ErpColors.bgMuted, ErpColors.borderLight, ErpColors.textSecondary),
    };

/// The panel under the field: tinted by what the check found.
class _Box extends StatelessWidget {
  final _Tone tone;
  final List<Widget> children;
  const _Box({required this.tone, required this.children});

  @override
  Widget build(BuildContext context) {
    final (bg, border, _) = _colours(tone);
    return Container(
      margin: const EdgeInsets.only(top: 8),
      padding: const EdgeInsets.fromLTRB(10, 8, 10, 6),
      decoration: BoxDecoration(color: bg, border: Border.all(color: border), borderRadius: BorderRadius.circular(6)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (var i = 0; i < children.length; i++) ...[
            if (i > 0) const SizedBox(height: 4),
            children[i],
          ],
        ],
      ),
    );
  }
}

/// The status, as a shape as well as a colour.
class _Chip extends StatelessWidget {
  final String text;
  final _Tone tone;
  const _Chip({required this.text, required this.tone});

  @override
  Widget build(BuildContext context) {
    final (_, border, ink) = _colours(tone);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(color: ErpColors.bgSurface, border: Border.all(color: border), borderRadius: BorderRadius.circular(10)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(width: 6, height: 6, decoration: BoxDecoration(color: ink, shape: BoxShape.circle)),
          const SizedBox(width: 6),
          Flexible(child: Text(text, style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: ink))),
        ],
      ),
    );
  }
}
