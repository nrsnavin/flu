import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../PurchaseOrder/services/theme.dart';
import '../floor_api.dart';
import '../floor_models.dart';
import '../floor_rules.dart';

// ══════════════════════════════════════════════════════════════
//  FLOOR ENTRY — production loom by loom, opened with a shift PIN
//
//  The third door on the welcome screen, beside the office and the
//  employee sign-ins, and the same flow as the web's /floor page:
//
//    1. Open the shift: date, day or night, your name, and the shift's
//       four-digit PIN (the office sees it on the shift card and can
//       change it). No login: the floor supervisor's phone may be
//       signed in as nobody.
//    2. The looms on the shift, what is still to enter first. Scan a
//       loom's label, type its ID, or tap it in the list.
//    3. On a loom: who ran it (that puts it on the shift if the office
//       planned none), the run time off its timer — which fills the
//       metres a head from the loom's own rate — and a remark. Saved
//       entries wait for the office to verify, unless the server's rule
//       verifies them (the run time and the loom's rate agree).
//    4. When nobody planned the shift, "Create shift plan" turns what
//       the floor noted into the plan, for the office to confirm.
//
//  A 401 anywhere means the shift's session ended or its PIN changed:
//  the PIN is asked for again where the supervisor stands, and nothing
//  typed is lost.
// ══════════════════════════════════════════════════════════════

enum _Phase { booting, open, shift, entry }

class FloorPage extends StatefulWidget {
  const FloorPage({super.key});

  @override
  State<FloorPage> createState() => _FloorPageState();
}

class _FloorPageState extends State<FloorPage> {
  final _api = FloorApi.instance;
  _Phase _phase = _Phase.booting;
  FloorState? _state;
  FloorMachine? _machine;
  bool _refreshing = false;

  @override
  void initState() {
    super.initState();
    _boot();
  }

  Future<void> _boot() async {
    final kept = await _api.restore();
    if (kept == null) {
      if (mounted) setState(() => _phase = _Phase.open);
      return;
    }
    try {
      final s = await _api.shift();
      if (!mounted) return;
      setState(() {
        _state = s;
        _phase = _Phase.shift;
      });
    } catch (_) {
      await _api.forget();
      if (mounted) setState(() => _phase = _Phase.open);
    }
  }

  Future<void> _refresh() async {
    setState(() => _refreshing = true);
    try {
      final s = await _api.shift();
      if (mounted) setState(() => _state = s);
    } on FloorError catch (e) {
      if (e.pinAgain) {
        await _pinAgain();
      } else {
        _toast(e.message, error: true);
      }
    } finally {
      if (mounted) setState(() => _refreshing = false);
    }
  }

  /// The shift's session ended or its PIN changed: ask again, here.
  Future<bool> _pinAgain() async {
    final session = _api.session;
    if (session == null || !mounted) {
      setState(() => _phase = _Phase.open);
      return false;
    }
    final state = await showDialog<FloorState>(
      context: context,
      barrierDismissible: false,
      builder: (_) => _PinAgainDialog(session: session),
    );
    if (!mounted) return false;
    if (state == null) {
      await _changeShift();
      return false;
    }
    setState(() => _state = state);
    return true;
  }

  Future<void> _changeShift() async {
    await _api.forget();
    if (!mounted) return;
    setState(() {
      _state = null;
      _machine = null;
      _phase = _Phase.open;
    });
  }

  void _toast(String text, {bool error = false}) {
    Get.snackbar(
      error ? 'Not saved' : 'Floor entry',
      text,
      snackPosition: SnackPosition.BOTTOM,
      margin: const EdgeInsets.all(12),
      backgroundColor: error ? ErpColors.solidError : ErpColors.solidSuccess,
      colorText: Colors.white,
      duration: const Duration(seconds: 4),
    );
  }

  Future<void> _openMachine(String raw) async {
    final read = readLoomCode(raw);
    if (read.problem != null) {
      _toast(read.problem!, error: true);
      return;
    }
    try {
      final m = await _api.machine(read.code!);
      if (!mounted) return;
      setState(() {
        _machine = m;
        _phase = _Phase.entry;
      });
    } on FloorError catch (e) {
      if (e.pinAgain) {
        if (await _pinAgain()) await _openMachine(raw);
      } else {
        _toast(e.message, error: true);
      }
    }
  }

  Future<void> _saved(FloorSaved saved) async {
    final m = saved.machine;
    final per = m.detail?.submitted?.production;
    final words = StringBuffer('${m.code} saved — ${per == null ? '' : '${_num(per)} m a head'}');
    if (saved.autoVerified) words.write(' · verified: the run time and the loom’s rate agree');
    final r = saved.remark;
    if (r != null && r.kind != 'other') words.write(' · ${remarkWords(r.kind, r.minutes)}');
    _toast(words.toString());
    setState(() {
      _state = _state?.withMachine(m, plan: saved.plan);
      _machine = null;
      _phase = _Phase.shift;
    });
    // A fault in the remark: offer it to the fitter.
    if (r != null && r.machineFault && r.issue == null && m.detail != null && mounted) {
      final raise = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Text('A fault on ${m.code}?'),
          content: Text(
            'The remark — “${m.detail!.submitted?.feedback ?? ''}” — sounds like '
            '${remarkWords(r.kind, r.minutes).toLowerCase()}. Raise it for the fitter '
            'as a machine issue? An open issue it repeats is linked instead.',
          ),
          actions: [
            TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('Not now')),
            FilledButton(onPressed: () => Navigator.of(ctx).pop(true), child: const Text('Raise for the fitter')),
          ],
        ),
      );
      if (raise == true) {
        try {
          final out = await _api.raiseRemarkIssue(m.detail!.id);
          _toast(out.duplicate
              ? 'Already reported on ${m.code}: ${out.title} — this entry is linked to it'
              : 'Raised for the fitter: ${out.title}');
        } on FloorError catch (e) {
          _toast(e.message, error: true);
        }
      }
    }
    _refresh();
  }

  @override
  Widget build(BuildContext context) {
    final session = _api.session;
    return PopScope(
      // Back from a loom goes back to the list, not out of the shift.
      canPop: _phase != _Phase.entry,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && _phase == _Phase.entry) {
          setState(() {
            _machine = null;
            _phase = _Phase.shift;
          });
        }
      },
      child: Scaffold(
        backgroundColor: ErpColors.bgBase,
        appBar: ErpAppBar(
          title: _state?.label.isNotEmpty == true
              ? _state!.label
              : (session != null ? '${session.shift == 'DAY' ? 'Day' : 'Night'} shift · ${session.dateKey}' : 'Floor entry'),
          subtitle: session?.name ?? 'Production, loom by loom',
          actions: [
            if (session != null && _phase != _Phase.open)
              TextButton.icon(
                onPressed: _changeShift,
                icon: Icon(Icons.swap_horiz_rounded, size: 16, color: ErpColors.textOnDark),
                label: Text('Change shift', style: TextStyle(color: ErpColors.textOnDark, fontSize: 12)),
              ),
          ],
        ),
        body: SafeArea(
          child: switch (_phase) {
            _Phase.booting => Center(child: CircularProgressIndicator(color: ErpColors.accentBlue)),
            _Phase.open => _OpenForm(
                initial: session,
                onOpened: (s) => setState(() {
                  _state = s;
                  _phase = _Phase.shift;
                }),
              ),
            _Phase.shift => _ShiftView(
                state: _state!,
                refreshing: _refreshing,
                onRefresh: _refresh,
                onLoom: _openMachine,
                onPinAgain: _pinAgain,
                onCompleted: (plan, free) {
                  _toast('Shift plan created — the office confirms it. '
                      '${free.isEmpty ? 'No loom was free.' : '${free.length} loom${free.length == 1 ? '' : 's'} free: ${free.join(', ')}.'}');
                  _refresh();
                },
              ),
            _Phase.entry => _EntryView(
                key: ValueKey(_machine!.id),
                machine: _machine!,
                state: _state!,
                onBack: () => setState(() {
                  _machine = null;
                  _phase = _Phase.shift;
                }),
                onSaved: _saved,
                onPinAgain: _pinAgain,
                onPlanMade: () {
                  _toast('Draft started with this loom — press Create shift plan when every machine is entered');
                  _refresh();
                },
              ),
          },
        ),
      ),
    );
  }
}

String _num(double v) => v == v.roundToDouble() ? v.toInt().toString() : v.toString();

// ── 1. Open the shift ─────────────────────────────────────────
class _OpenForm extends StatefulWidget {
  final FloorSession? initial;
  final void Function(FloorState) onOpened;
  const _OpenForm({required this.initial, required this.onOpened});

  @override
  State<_OpenForm> createState() => _OpenFormState();
}

class _OpenFormState extends State<_OpenForm> {
  static const _kName = 'floor.name';
  late String _dateKey;
  late String _shift;
  final _name = TextEditingController();
  final _pin = TextEditingController();
  bool _busy = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    final now = shiftNow();
    _dateKey = widget.initial?.dateKey ?? now.dateKey;
    _shift = widget.initial?.shift ?? now.shift;
    _name.text = widget.initial?.name ?? '';
    if (_name.text.isEmpty) {
      SharedPreferences.getInstance().then((p) {
        final n = p.getString(_kName) ?? '';
        if (mounted && _name.text.isEmpty) setState(() => _name.text = n);
      }).catchError((_) {});
    }
  }

  @override
  void dispose() {
    _name.dispose();
    _pin.dispose();
    super.dispose();
  }

  String _dateWords(String key) {
    final d = DateTime.tryParse(key);
    if (d == null) return key;
    const days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    return '${days[d.weekday - 1]} ${d.day} ${months[d.month - 1]}';
  }

  Future<void> _pickDate() async {
    final current = DateTime.tryParse(_dateKey) ?? DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: current,
      firstDate: DateTime.now().subtract(const Duration(days: 30)),
      lastDate: DateTime.now().add(const Duration(days: 1)),
    );
    if (picked == null) return;
    setState(() => _dateKey =
        '${picked.year}-${picked.month.toString().padLeft(2, '0')}-${picked.day.toString().padLeft(2, '0')}');
  }

  Future<void> _submit() async {
    setState(() => _error = null);
    final name = _name.text.trim();
    if (name.length < 2) {
      setState(() => _error = 'Type your name, so the entries say who made them.');
      return;
    }
    if (!RegExp(r'^\d{4}$').hasMatch(_pin.text)) {
      setState(() => _error = 'The PIN is four digits.');
      return;
    }
    setState(() => _busy = true);
    try {
      final state = await FloorApi.instance.open(dateKey: _dateKey, shift: _shift, pin: _pin.text, name: name);
      try {
        final p = await SharedPreferences.getInstance();
        await p.setString(_kName, name);
      } catch (_) {}
      widget.onOpened(state);
    } on FloorError catch (e) {
      _pin.clear(); // a wrong PIN is typed again, not edited
      if (mounted) setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final now = shiftNow();
    final notNow = _dateKey != now.dateKey || _shift != now.shift;
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 18, 16, 32),
      children: [
        Text('Open the shift',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: ErpColors.textPrimary)),
        const SizedBox(height: 4),
        Text('Ask the office for this shift’s PIN — it is on the shift card.',
            style: TextStyle(fontSize: 13, color: ErpColors.textSecondary)),
        const SizedBox(height: 18),
        Row(children: [
          Expanded(
            child: OutlinedButton.icon(
              onPressed: _pickDate,
              icon: const Icon(Icons.calendar_today_outlined, size: 16),
              label: Text(_dateWords(_dateKey)),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: SegmentedButton<String>(
              segments: const [
                ButtonSegment(value: 'DAY', label: Text('Day'), icon: Icon(Icons.wb_sunny_outlined, size: 16)),
                ButtonSegment(value: 'NIGHT', label: Text('Night'), icon: Icon(Icons.nights_stay_outlined, size: 16)),
              ],
              selected: {_shift},
              showSelectedIcon: false,
              onSelectionChanged: (s) => setState(() => _shift = s.first),
            ),
          ),
        ]),
        if (notNow) ...[
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: ErpColors.warningAmber.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(children: [
              Expanded(
                child: Text(
                  'The shift running now is the ${now.shift == 'DAY' ? 'day' : 'night'} shift of ${_dateWords(now.dateKey)}.',
                  style: TextStyle(fontSize: 12, color: ErpColors.textPrimary),
                ),
              ),
              TextButton(
                onPressed: () => setState(() {
                  _dateKey = now.dateKey;
                  _shift = now.shift;
                }),
                child: const Text('Use it'),
              ),
            ]),
          ),
        ],
        const SizedBox(height: 16),
        TextField(
          controller: _name,
          textCapitalization: TextCapitalization.words,
          style: ErpTextStyles.fieldValue,
          decoration: ErpDecorations.formInput('Your name', hint: 'Supervisor on this shift'),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _pin,
          keyboardType: TextInputType.number,
          obscureText: true,
          textAlign: TextAlign.center,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(4)],
          style: ErpTextStyles.fieldValue.copyWith(fontSize: 20, letterSpacing: 10),
          decoration: ErpDecorations.formInput('Shift PIN', hint: '••••'),
          onSubmitted: (_) => _submit(),
        ),
        if (_error != null) ...[
          const SizedBox(height: 12),
          _ErrorBox(_error!),
        ],
        const SizedBox(height: 20),
        SizedBox(
          height: 50,
          child: FilledButton.icon(
            onPressed: _busy ? null : _submit,
            icon: _busy
                ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2.4, color: Colors.white))
                : const Icon(Icons.lock_open_rounded, size: 18),
            label: const Text('Open shift', style: TextStyle(fontWeight: FontWeight.w800)),
          ),
        ),
      ],
    );
  }
}

// ── 2. The looms on the shift ─────────────────────────────────
class _ShiftView extends StatefulWidget {
  final FloorState state;
  final bool refreshing;
  final Future<void> Function() onRefresh;
  final Future<void> Function(String code) onLoom;
  final Future<bool> Function() onPinAgain;
  final void Function(FloorPlan? plan, List<String> freeLooms) onCompleted;
  const _ShiftView({
    required this.state,
    required this.refreshing,
    required this.onRefresh,
    required this.onLoom,
    required this.onPinAgain,
    required this.onCompleted,
  });

  @override
  State<_ShiftView> createState() => _ShiftViewState();
}

class _ShiftViewState extends State<_ShiftView> {
  final _typed = TextEditingController();
  bool _creating = false;

  @override
  void dispose() {
    _typed.dispose();
    super.dispose();
  }

  Future<void> _scan() async {
    final code = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const _LoomScanSheet(),
    );
    if (code != null) await widget.onLoom(code);
  }

  Future<void> _create({bool force = false}) async {
    setState(() => _creating = true);
    try {
      final out = await FloorApi.instance.complete(force: force);
      widget.onCompleted(out.plan, out.freeLooms);
    } on FloorError catch (e) {
      if (e.pinAgain) {
        if (await widget.onPinAgain()) await _create(force: force);
        return;
      }
      if (e.code == 'FLOOR_LOOMS_TO_ENTER' && mounted) {
        final looms = (e.details['looms'] is List)
            ? (e.details['looms'] as List).map((m) => m is Map ? '${m['ID']}' : '').where((s) => s.isNotEmpty).toList()
            : <String>[];
        final go = await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('Create the shift plan now?'),
            content: Text('${looms.length} loom${looms.length == 1 ? ' is' : 's are'} still to enter: '
                '${looms.join(', ')}. They stay on the shift to enter later.'),
            actions: [
              TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('Cancel')),
              FilledButton(onPressed: () => Navigator.of(ctx).pop(true), child: const Text('Create anyway')),
            ],
          ),
        );
        if (go == true) await _create(force: true);
        return;
      }
      Get.snackbar('Not created', e.message, snackPosition: SnackPosition.BOTTOM, margin: const EdgeInsets.all(12));
    } finally {
      if (mounted) setState(() => _creating = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.state;
    final plan = s.plan;
    final done = s.entered;
    final total = s.toEnter + done;
    final looms = [...s.machines]..sort((a, b) => listOrder(a.entry, a.code, b.entry, b.code));
    return RefreshIndicator(
      onRefresh: widget.onRefresh,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(14, 14, 14, 40),
        children: [
          if (!s.isCurrent)
            _Notice('This is not the shift running now. Entries go to ${s.label}.', tone: _Tone.warning),
          if (plan?.finalized == true)
            _Notice('This shift is finalised — nothing more can be entered. Ask the office to reopen it if something is missing.',
                tone: _Tone.danger),
          if (plan == null || plan.isDraft)
            _Notice(plan == null
                ? 'No plan for this shift yet. Scan a loom and choose who ran it — what you enter is noted as a draft, and Create shift plan makes it the plan.'
                : 'No plan was made for this shift: what you enter is noted as a draft the office can see. Press Create shift plan when every machine’s production is in.'),
          if (plan?.completed == true)
            _Notice('Shift plan created — the office confirms it.'
                '${plan!.freeLooms.isEmpty ? '' : ' Free: ${plan.freeLooms.join(', ')}.'}', tone: _Tone.success),
          // Progress
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: ErpColors.bgSurface,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: ErpColors.borderLight),
            ),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Expanded(
                  child: Text('$done of $total entered',
                      style: TextStyle(fontWeight: FontWeight.w800, color: ErpColors.textPrimary)),
                ),
                TextButton.icon(
                  onPressed: widget.refreshing ? null : widget.onRefresh,
                  icon: const Icon(Icons.refresh_rounded, size: 16),
                  label: const Text('Refresh'),
                ),
              ]),
              const SizedBox(height: 4),
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: total == 0 ? 0 : done / total,
                  minHeight: 8,
                  color: ErpColors.successGreen,
                  backgroundColor: ErpColors.borderLight,
                ),
              ),
              if (s.toEnter == 0 && total > 0) ...[
                const SizedBox(height: 6),
                Text('Every loom on this shift is entered.',
                    style: TextStyle(fontSize: 12, color: ErpColors.successGreen)),
              ],
            ]),
          ),
          if (plan?.isDraft == true) ...[
            const SizedBox(height: 10),
            SizedBox(
              height: 48,
              child: FilledButton.icon(
                onPressed: (done == 0 || _creating) ? null : () => _create(),
                icon: const Icon(Icons.fact_check_outlined, size: 18),
                label: const Text('Create shift plan', style: TextStyle(fontWeight: FontWeight.w800)),
              ),
            ),
            const SizedBox(height: 4),
            Text('Press when every machine’s production is entered. The looms noted become the shift plan, for the office to confirm.',
                textAlign: TextAlign.center, style: TextStyle(fontSize: 11, color: ErpColors.textSecondary)),
          ],
          const SizedBox(height: 14),
          // Find a loom
          SizedBox(
            height: 50,
            child: FilledButton.icon(
              onPressed: _scan,
              icon: const Icon(Icons.qr_code_scanner_rounded, size: 20),
              label: const Text('Scan a loom', style: TextStyle(fontWeight: FontWeight.w800)),
            ),
          ),
          const SizedBox(height: 10),
          Row(children: [
            Expanded(
              child: TextField(
                controller: _typed,
                textCapitalization: TextCapitalization.characters,
                style: ErpTextStyles.fieldValue,
                decoration: ErpDecorations.formInput('Or type the loom ID', hint: 'e.g. L-02'),
                onSubmitted: (v) {
                  widget.onLoom(v);
                  _typed.clear();
                },
              ),
            ),
            const SizedBox(width: 8),
            SizedBox(
              height: 48,
              child: OutlinedButton(
                onPressed: () {
                  widget.onLoom(_typed.text);
                  _typed.clear();
                },
                child: const Text('Find'),
              ),
            ),
          ]),
          const SizedBox(height: 16),
          Text('LOOMS', style: ErpTextStyles.sectionHeader),
          const SizedBox(height: 8),
          if (looms.isEmpty)
            Text('No looms on this shift yet.', style: TextStyle(color: ErpColors.textSecondary)),
          for (final m in looms) _LoomTile(machine: m, onTap: () => widget.onLoom(m.id)),
        ],
      ),
    );
  }
}

class _LoomTile extends StatelessWidget {
  final FloorMachine machine;
  final VoidCallback onTap;
  const _LoomTile({required this.machine, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final m = machine;
    final sub = m.detail?.submitted;
    final line = [
      if (m.detail?.operator?.name.isNotEmpty == true) m.detail!.operator!.name,
      if (sub?.production != null) '${_num(sub!.production!)} m a head',
      if (sub?.timer?.isNotEmpty == true) sub!.timer!,
      if (m.detail == null && m.why != null) m.why!,
    ].join(' · ');
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: ErpColors.bgSurface,
        borderRadius: BorderRadius.circular(10),
        child: InkWell(
          borderRadius: BorderRadius.circular(10),
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: ErpColors.borderLight),
            ),
            child: Row(children: [
              SizedBox(
                width: 64,
                child: Text(m.code,
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: ErpColors.textPrimary)),
              ),
              Expanded(
                child: Text(line.isEmpty ? (m.jobNo != null ? 'Job ${m.jobNo}' : '—') : line,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 12, color: ErpColors.textSecondary)),
              ),
              const SizedBox(width: 8),
              _EntryChip(m.entry),
            ]),
          ),
        ),
      ),
    );
  }
}

class _EntryChip extends StatelessWidget {
  final String entry;
  const _EntryChip(this.entry);

  @override
  Widget build(BuildContext context) {
    final color = switch (entry) {
      'ready' || 'unplanned' => ErpColors.warningAmber,
      'entered' => ErpColors.accentBlue,
      'verified' => ErpColors.successGreen,
      'locked' => ErpColors.errorRed,
      _ => ErpColors.textMuted,
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(entryLabels[entry] ?? entry,
          style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: color)),
    );
  }
}

// ── 3. One loom ───────────────────────────────────────────────
class _EntryView extends StatefulWidget {
  final FloorMachine machine;
  final FloorState state;
  final VoidCallback onBack;
  final Future<void> Function(FloorSaved) onSaved;
  final Future<bool> Function() onPinAgain;
  final VoidCallback onPlanMade;
  const _EntryView({
    super.key,
    required this.machine,
    required this.state,
    required this.onBack,
    required this.onSaved,
    required this.onPinAgain,
    required this.onPlanMade,
  });

  @override
  State<_EntryView> createState() => _EntryViewState();
}

class _EntryViewState extends State<_EntryView> {
  late String? _operator = widget.machine.detail?.operator?.id;
  late String? _detailId = widget.machine.detail?.id;
  final _timer = TextEditingController();
  final _metres = TextEditingController();
  final _remark = TextEditingController();
  String? _filled; // the metres the run time filled in, while untouched
  bool _placing = false;
  bool _busy = false;
  String? _error;
  String? _placed;
  FloorPreviousTimer? _previous;
  bool _previousLoaded = false;

  FloorMachine get m => widget.machine;
  bool get _loading => m.entry == 'loading';
  bool get _locked => m.detail?.operatorLocked == true;

  @override
  void initState() {
    super.initState();
    final prior = m.detail?.submitted;
    _timer.text = prior?.timer ?? '';
    _metres.text = prior?.production == null ? '' : _num(prior!.production!);
    _remark.text = prior?.feedback ?? '';
    FloorApi.instance.previousTimer(m.id).then((p) {
      if (!mounted) return;
      setState(() {
        _previous = p;
        _previousLoaded = true;
      });
    }).catchError((_) {
      if (mounted) setState(() => _previousLoaded = true);
    });
  }

  @override
  void dispose() {
    _timer.dispose();
    _metres.dispose();
    _remark.dispose();
    super.dispose();
  }

  void _runTimeChanged(String next) {
    final auto = perHeadText(next, cmPerMin: m.cmPerMin);
    if (auto.isNotEmpty && (_metres.text.isEmpty || _metres.text == _filled)) {
      _metres.text = auto;
      _filled = auto;
    }
    setState(() {});
  }

  Future<void> _chooseOperator(String? next) async {
    setState(() => _operator = next);
    if ((_detailId != null && !_loading) || next == null) return;
    setState(() {
      _error = null;
      _placing = true;
    });
    try {
      final placed = await FloorApi.instance.setOperator(m.id, next);
      if (!mounted) return;
      setState(() {
        _detailId = placed.detailId;
        _placed = next;
      });
      if (placed.planCreated) widget.onPlanMade();
    } on FloorError catch (e) {
      if (!mounted) return;
      setState(() => _operator = null);
      if (e.pinAgain) {
        if (await widget.onPinAgain()) await _chooseOperator(next);
      } else {
        setState(() => _error = e.message);
      }
    } finally {
      if (mounted) setState(() => _placing = false);
    }
  }

  Future<void> _save() async {
    setState(() => _error = null);
    if (_detailId == null || _operator == null) {
      setState(() => _error = 'Choose who ran this loom — that puts it on the shift.');
      return;
    }
    final metres = double.tryParse(_metres.text.trim());
    if (metres == null || metres < 0) {
      setState(() => _error = 'Enter the metres produced a head, 0 or more.');
      return;
    }
    final runTime = tidyRunTime(_timer.text);
    setState(() => _busy = true);
    try {
      final saved = await FloorApi.instance.enter(
        detailId: _detailId!,
        production: metres,
        timer: runTime,
        feedback: _remark.text.trim(),
        operator: _locked ? null : _operator,
      );
      await widget.onSaved(saved);
    } on FloorError catch (e) {
      if (!mounted) return;
      if (e.pinAgain) {
        if (await widget.onPinAgain()) await _save();
      } else {
        setState(() => _error = e.message);
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final finalized = widget.state.plan?.finalized == true;
    final enterable = canEnter(m.entry) && !finalized;
    final prior = m.detail?.submitted;
    final metres = double.tryParse(_metres.text.trim());
    final total = metres == null ? null : metres * m.headsRunning;
    final options = widget.state.operators;
    final rateWords = m.metresPerHeadHour == null
        ? '${defaultCmPerMin.toInt()} cm a minute'
        : 'this loom’s rate, ${_num(m.metresPerHeadHour!)} m a head an hour'
            '${m.rateBasis == 'machine' ? ' (from ${m.rateShifts ?? 0} shifts)' : ' (the plant’s, until it has its own)'}';

    Widget operatorField(String label) => _locked
        ? Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: ErpColors.bgMuted, borderRadius: BorderRadius.circular(8)),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Operator: ${m.detail?.operator?.name ?? '—'}',
                  style: TextStyle(fontWeight: FontWeight.w700, color: ErpColors.textPrimary)),
              Text('Put on this loom by the office — ask them to change it.',
                  style: TextStyle(fontSize: 11, color: ErpColors.textSecondary)),
            ]),
          )
        : DropdownButtonFormField<String>(
            value: options.any((o) => o.id == _operator) ? _operator : null,
            isExpanded: true,
            decoration: ErpDecorations.formInput(label),
            items: [for (final o in options) DropdownMenuItem(value: o.id, child: Text(o.label))],
            onChanged: _placing ? null : _chooseOperator,
          );

    return ListView(
      padding: const EdgeInsets.fromLTRB(14, 10, 14, 40),
      children: [
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton.icon(
            onPressed: widget.onBack,
            icon: const Icon(Icons.arrow_back_rounded, size: 16),
            label: const Text('Back to the looms'),
          ),
        ),
        // The loom
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: ErpColors.bgSurface,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: ErpColors.borderLight),
          ),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Expanded(
                child: Text(m.code,
                    style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900, color: ErpColors.textPrimary)),
              ),
              _EntryChip(m.entry),
            ]),
            Text('${m.manufacturer.isEmpty ? '—' : m.manufacturer} · ${m.hooks ?? '?'} hooks · ${m.heads ?? '?'} heads',
                style: TextStyle(fontSize: 12, color: ErpColors.textSecondary)),
            const SizedBox(height: 8),
            Text('Job: ${m.jobNo == null ? 'none' : '${m.jobNo} · ${m.jobStatus ?? ''}'}',
                style: TextStyle(fontSize: 13, color: ErpColors.textPrimary)),
            Text('Heads running: ${m.headsRunning} of ${m.heads ?? '?'}',
                style: TextStyle(fontSize: 13, color: ErpColors.textPrimary)),
          ]),
        ),
        const SizedBox(height: 10),
        if (prior != null)
          _Notice('${m.entry == 'verified' ? 'Verified' : 'Entered'}'
              '${prior.production != null ? ': ${_num(prior.production!)} m a head' : ''}'
              '${prior.timer?.isNotEmpty == true ? ' · ${prior.timer}' : ''}'
              '${prior.byName.isNotEmpty ? ' by ${prior.byName}' : ''}'
              '${m.entry == 'entered' ? '. Saving again replaces it.' : ''}'),
        if (_loading && !finalized) ...[
          _Notice('Being loaded for its job — no production to enter. The operator loading it is on the shift, so the work is recorded.'),
          operatorField('Operator loading it'),
          if (_placed != null && _operator == _placed) ...[
            const SizedBox(height: 8),
            Text('${options.firstWhereOrNull((o) => o.id == _placed)?.label ?? 'The operator'} is on this loom this shift.',
                style: TextStyle(color: ErpColors.successGreen, fontSize: 13)),
          ],
          if (_error != null) ...[const SizedBox(height: 10), _ErrorBox(_error!)],
          const SizedBox(height: 14),
          OutlinedButton(onPressed: widget.onBack, child: const Text('Back to the looms')),
        ] else if (!enterable) ...[
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(color: ErpColors.bgMuted, borderRadius: BorderRadius.circular(10)),
            child: Text(finalized ? 'This shift is finalised.' : (m.why ?? 'Nothing to enter on this loom.'),
                style: TextStyle(fontWeight: FontWeight.w700, color: ErpColors.textPrimary)),
          ),
          const SizedBox(height: 14),
          OutlinedButton(onPressed: widget.onBack, child: const Text('Back to the looms')),
        ] else ...[
          operatorField(_detailId != null ? 'Operator' : 'Operator — puts this loom on the shift'),
          const SizedBox(height: 14),
          // The timer
          Text('THE LOOM’S TIMER', style: ErpTextStyles.sectionHeader),
          const SizedBox(height: 6),
          if (!_previousLoaded)
            Text('Looking up the shift before…', style: TextStyle(fontSize: 12, color: ErpColors.textMuted))
          else if (_previous != null)
            Text(
              _previous!.runTime == null
                  ? 'Shift before (${_previous!.shiftLabel}): ${_previous!.operator == null ? 'this loom was not on it.' : 'no run time was entered (${_previous!.operator}).'}'
                  : 'Shift before (${_previous!.shiftLabel}): timer read ${_previous!.runTime}'
                      '${_previous!.operator == null ? '' : ' · ${_previous!.operator}'}'
                      ' — ${_previous!.verified ? 'verified by the office' : 'not verified yet'}.',
              style: TextStyle(fontSize: 12, color: ErpColors.textSecondary),
            ),
          if (m.sensorRunTime != null) ...[
            const SizedBox(height: 6),
            Row(children: [
              Icon(Icons.speed_rounded, size: 16, color: ErpColors.textMuted),
              const SizedBox(width: 6),
              Expanded(
                child: Text('The loom’s sensor: ran ${m.sensorRunTime} this shift',
                    style: TextStyle(fontSize: 12, color: ErpColors.textPrimary)),
              ),
              if (_timer.text != m.sensorRunTime)
                TextButton(
                  onPressed: () {
                    _timer.text = m.sensorRunTime!;
                    _runTimeChanged(_timer.text);
                  },
                  child: const Text('Use it'),
                ),
            ]),
          ],
          const SizedBox(height: 8),
          TextField(
            controller: _timer,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            style: ErpTextStyles.fieldValue,
            decoration: ErpDecorations.formInput('Run time', hint: '7:30 or 7.30'),
            onChanged: _runTimeChanged,
            onEditingComplete: () {
              _timer.text = tidyRunTime(_timer.text);
              _runTimeChanged(_timer.text);
              FocusScope.of(context).nextFocus();
            },
          ),
          const SizedBox(height: 4),
          Text('Hours and minutes the loom ran this shift. Fills the metres a head at $rateWords.',
              style: TextStyle(fontSize: 11, color: ErpColors.textSecondary)),
          const SizedBox(height: 12),
          TextField(
            controller: _metres,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*'))],
            style: ErpTextStyles.fieldValue,
            decoration: ErpDecorations.formInput('Metres a head'),
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 4),
          Text(
            total != null
                ? '${_metres.text == _filled ? 'Filled from the run time — change it if the counter says otherwise. ' : ''}'
                    '× ${m.headsRunning} heads running = ${_num(double.parse(total.toStringAsFixed(1)))} m'
                : 'Counted on the ${m.headsRunning} heads running.',
            style: TextStyle(fontSize: 11, color: ErpColors.textSecondary),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _remark,
            maxLines: 2,
            maxLength: 500,
            style: ErpTextStyles.fieldValue,
            decoration: ErpDecorations.formInput('Remarks', hint: 'Beam change 40 min, motor noise, yarn short…'),
          ),
          if (_error != null) ...[const SizedBox(height: 6), _ErrorBox(_error!)],
          const SizedBox(height: 12),
          SizedBox(
            height: 50,
            child: FilledButton.icon(
              onPressed: (_busy || _placing) ? null : _save,
              icon: _busy
                  ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2.4, color: Colors.white))
                  : const Icon(Icons.check_rounded, size: 18),
              label: Text(m.entry == 'entered' ? 'Save the correction' : 'Save',
                  style: const TextStyle(fontWeight: FontWeight.w800)),
            ),
          ),
        ],
      ],
    );
  }
}

// ── The PIN again ─────────────────────────────────────────────
class _PinAgainDialog extends StatefulWidget {
  final FloorSession session;
  const _PinAgainDialog({required this.session});

  @override
  State<_PinAgainDialog> createState() => _PinAgainDialogState();
}

class _PinAgainDialogState extends State<_PinAgainDialog> {
  final _pin = TextEditingController();
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _pin.dispose();
    super.dispose();
  }

  Future<void> _go() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final s = await FloorApi.instance.open(
        dateKey: widget.session.dateKey,
        shift: widget.session.shift,
        pin: _pin.text,
        name: widget.session.name,
      );
      if (mounted) Navigator.of(context).pop(s);
    } on FloorError catch (e) {
      _pin.clear();
      if (mounted) setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Enter the PIN again'),
      content: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('This floor session has ended, or the shift PIN was changed. '
            'Nothing is lost — enter the current PIN to carry on.'),
        const SizedBox(height: 12),
        TextField(
          controller: _pin,
          autofocus: true,
          obscureText: true,
          keyboardType: TextInputType.number,
          textAlign: TextAlign.center,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(4)],
          style: const TextStyle(fontSize: 20, letterSpacing: 10),
          decoration: const InputDecoration(labelText: 'Shift PIN'),
          onChanged: (_) => setState(() {}),
          onSubmitted: (_) => _pin.text.length == 4 ? _go() : null,
        ),
        if (_error != null) ...[const SizedBox(height: 10), _ErrorBox(_error!)],
      ]),
      actions: [
        TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Open a different shift')),
        FilledButton(
          onPressed: (_busy || _pin.text.length != 4) ? null : _go,
          child: const Text('Carry on'),
        ),
      ],
    );
  }
}

// ── Scanning a loom's label ───────────────────────────────────
class _LoomScanSheet extends StatefulWidget {
  const _LoomScanSheet();

  @override
  State<_LoomScanSheet> createState() => _LoomScanSheetState();
}

class _LoomScanSheetState extends State<_LoomScanSheet> {
  final _controller = MobileScannerController(
    detectionSpeed: DetectionSpeed.noDuplicates,
    formats: const [BarcodeFormat.qrCode],
  );
  bool _handled = false;
  String? _problem;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onDetect(BarcodeCapture capture) {
    if (_handled) return;
    for (final b in capture.barcodes) {
      final read = readLoomCode(b.rawValue);
      if (read.code != null) {
        _handled = true;
        Navigator.of(context).pop(read.code);
        return;
      }
      if (mounted && read.problem != _problem) setState(() => _problem = read.problem);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.62,
      decoration: BoxDecoration(
        color: ErpColors.navyDark,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
      ),
      child: Column(children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 8, 8),
          child: Row(children: [
            Expanded(
              child: Text('Scan the loom’s label',
                  style: TextStyle(color: ErpColors.textOnDark, fontSize: 15, fontWeight: FontWeight.w800)),
            ),
            IconButton(
              tooltip: 'Torch',
              onPressed: _controller.toggleTorch,
              icon: Icon(Icons.flashlight_on_outlined, color: ErpColors.textOnDark),
            ),
            IconButton(
              tooltip: 'Close',
              onPressed: () => Navigator.of(context).pop(),
              icon: Icon(Icons.close, color: ErpColors.textOnDark),
            ),
          ]),
        ),
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: MobileScanner(
              controller: _controller,
              onDetect: _onDetect,
              errorBuilder: (_, error) => Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Text(
                    error.errorCode == MobileScannerErrorCode.permissionDenied
                        ? 'The camera is not allowed for this app. Allow it in the phone’s settings, or type the loom ID instead.'
                        : 'The camera could not be started. Type the loom ID instead.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: ErpColors.textOnDarkSub, fontSize: 13),
                  ),
                ),
              ),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 18),
          child: Text(_problem ?? 'Hold the square code on the loom inside the frame.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 12, color: _problem == null ? ErpColors.textOnDarkSub : ErpColors.warningAmber)),
        ),
      ]),
    );
  }
}

// ── Small pieces ──────────────────────────────────────────────
enum _Tone { info, warning, danger, success }

class _Notice extends StatelessWidget {
  final String text;
  final _Tone tone;
  const _Notice(this.text, {this.tone = _Tone.info});

  @override
  Widget build(BuildContext context) {
    final color = switch (tone) {
      _Tone.info => ErpColors.accentBlue,
      _Tone.warning => ErpColors.warningAmber,
      _Tone.danger => ErpColors.errorRed,
      _Tone.success => ErpColors.successGreen,
    };
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Text(text, style: TextStyle(fontSize: 12.5, color: ErpColors.textPrimary, height: 1.35)),
    );
  }
}

class _ErrorBox extends StatelessWidget {
  final String text;
  const _ErrorBox(this.text);

  @override
  Widget build(BuildContext context) => Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: ErpColors.errorRed.withValues(alpha: 0.07),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: ErpColors.errorRed.withValues(alpha: 0.25)),
        ),
        child: Text(text, style: TextStyle(color: ErpColors.errorRed, fontSize: 12.5, height: 1.4)),
      );
}
