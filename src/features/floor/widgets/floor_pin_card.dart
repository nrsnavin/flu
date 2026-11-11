import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../core/api_client.dart';
import '../../../core/app_config.dart';
import '../../PurchaseOrder/services/theme.dart';
import '../floor_rules.dart';

// ══════════════════════════════════════════════════════════════
//  THE SHIFT'S FLOOR PIN — for the office
//
//  The floor supervisor opens floor entry (the app's third door, or the
//  web's /floor page) with the shift's four-digit PIN. This card is
//  where the office reads it out, and makes a new one when it has gone
//  round further than it should: anyone holding the old PIN then has to
//  enter the new one. It also lists who opened the shift with it.
//
//    GET  /shift/floor-pin?date=&shift=      (made on first ask)
//    POST /shift/floor-pin/rotate {date, shift}
// ══════════════════════════════════════════════════════════════

class FloorPinCard extends StatefulWidget {
  const FloorPinCard({super.key});

  @override
  State<FloorPinCard> createState() => _FloorPinCardState();
}

class _FloorPinCardState extends State<FloorPinCard> {
  final _dio = ApiClient.buildClient(baseUrl: '${ApiConfig.baseUrl}/shift');
  late String _dateKey;
  late String _shift;
  String? _pin;
  List<String> _opens = const [];
  bool _shown = false;
  bool _busy = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    final now = shiftNow();
    _dateKey = now.dateKey;
    _shift = now.shift;
  }

  String _message(DioException e) {
    final d = e.response?.data;
    if (d is Map && d['message'] != null) return d['message'].toString();
    return e.response == null ? 'Could not reach the server.' : 'Could not load the PIN.';
  }

  void _take(dynamic data) {
    final m = data is Map ? data : const {};
    _pin = m['pin']?.toString();
    final opens = m['opens'];
    _opens = opens is List
        ? opens.whereType<Map>().map((o) {
            final at = DateTime.tryParse(o['at']?.toString() ?? '')?.toLocal();
            final when = at == null
                ? ''
                : '${at.hour.toString().padLeft(2, '0')}:${at.minute.toString().padLeft(2, '0')}';
            return '${o['name'] ?? 'Someone'}${when.isEmpty ? '' : ' at $when'}';
          }).toList()
        : const [];
  }

  Future<void> _load() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final res = await _dio.get('/floor-pin', queryParameters: {'date': _dateKey, 'shift': _shift});
      _take(res.data);
      _shown = true;
    } on DioException catch (e) {
      _error = _message(e);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _rotate() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Make a new PIN?'),
        content: const Text('Anyone on the floor with the old PIN will have to enter the new one.'),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.of(ctx).pop(true), child: const Text('Make a new PIN')),
        ],
      ),
    );
    if (ok != true) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final res = await _dio.post('/floor-pin/rotate', data: {'date': _dateKey, 'shift': _shift});
      _take(res.data);
      _shown = true;
      Get.snackbar('New PIN made', 'Anyone on the floor with the old one has to enter this one.',
          snackPosition: SnackPosition.BOTTOM, margin: const EdgeInsets.all(12));
    } on DioException catch (e) {
      _error = _message(e);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _setShift(String shift) {
    setState(() {
      _shift = shift;
      _pin = null;
      _opens = const [];
      _shown = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return ErpSectionCard(
      title: 'FLOOR ENTRY PIN',
      icon: Icons.pin_outlined,
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('The floor supervisor opens floor entry with this PIN. Read it out; make a new one if it has gone round.',
            style: TextStyle(fontSize: 11, color: ErpColors.textSecondary)),
        const SizedBox(height: 10),
        Row(children: [
          Text(_dateKey, style: TextStyle(fontWeight: FontWeight.w700, color: ErpColors.textPrimary)),
          const Spacer(),
          SegmentedButton<String>(
            segments: const [
              ButtonSegment(value: 'DAY', label: Text('Day')),
              ButtonSegment(value: 'NIGHT', label: Text('Night')),
            ],
            selected: {_shift},
            showSelectedIcon: false,
            onSelectionChanged: (s) => _setShift(s.first),
          ),
        ]),
        const SizedBox(height: 10),
        if (_shown && _pin != null)
          Row(children: [
            Text(_pin!,
                style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 8,
                    color: ErpColors.textPrimary,
                    fontFeatures: const [FontFeature.tabularFigures()])),
            const Spacer(),
            TextButton(onPressed: () => setState(() => _shown = false), child: const Text('Hide')),
            OutlinedButton(onPressed: _busy ? null : _rotate, child: const Text('New PIN')),
          ])
        else
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: _busy ? null : _load,
              icon: const Icon(Icons.visibility_outlined, size: 16),
              label: Text(_busy ? 'Loading…' : 'Show the PIN'),
            ),
          ),
        if (_shown && _opens.isNotEmpty) ...[
          const SizedBox(height: 8),
          Text('Opened by ${_opens.join(', ')}',
              style: TextStyle(fontSize: 11, color: ErpColors.textSecondary)),
        ],
        if (_error != null) ...[
          const SizedBox(height: 8),
          Text(_error!, style: TextStyle(fontSize: 12, color: ErpColors.errorRed)),
        ],
      ]),
    );
  }
}

/// The PIN card on a page of its own, in the menu under Shift
/// Management: where the office goes when the floor rings for it.
class FloorPinPage extends StatelessWidget {
  const FloorPinPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: ErpColors.bgBase,
      appBar: const ErpAppBar(title: 'Floor Entry PIN', subtitle: 'For the shift supervisor'),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(14, 14, 14, 32),
        children: [
          const FloorPinCard(),
          const SizedBox(height: 12),
          Text(
            'Floor entry is on the app’s first screen — “Floor entry with the shift PIN” — '
            'and on the web at /floor. The supervisor opens the shift with this PIN, '
            'scans or picks each loom, and enters who ran it, the run time and the metres. '
            'Entries wait under Pending Verifications until you verify them.',
            style: TextStyle(fontSize: 12, color: ErpColors.textSecondary, height: 1.4),
          ),
        ],
      ),
    );
  }
}
