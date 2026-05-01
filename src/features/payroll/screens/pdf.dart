// ══════════════════════════════════════════════════════════════
//  PAYSLIP PDF SERVICE
//  File: lib/src/features/payroll/services/payslip_pdf_service.dart
//
//  Generates a full A4 payslip PDF matching the sample layout:
//    1. Header        — company + payslip label
//    2. Employee Info — name, dept, ID, period, rate, status
//    3. Net Pay Banner
//    4. Attendance Summary  |  Shift Breakdown  (side-by-side)
//    5. Attendance Calendar — colour-coded day grid
//    6. Earnings / Deductions / Bonuses  (3-column)
//    7. Salary Calculation — itemised workings with net pay
//    8. Footer
//
//  USAGE (from payslip page "Download PDF" button):
//    final bytes = await PayslipPdfService.generate(ps, attendance: att);
//    await PayslipPdfService.openOrShare(bytes, ps);
//
//  pubspec.yaml:
//    pdf: ^3.11.0
//    printing: ^5.13.0
//    path_provider: ^2.1.0
//    open_file: ^3.3.2
// ══════════════════════════════════════════════════════════════
import 'dart:io';
import 'package:intl/intl.dart';
import 'package:open_file/open_file.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../models/payroll_models.dart';

// ── Palette ───────────────────────────────────────────────────
const _navy   = PdfColor.fromInt(0xFF0B2040);
const _navy2  = PdfColor.fromInt(0xFF0F2D55);
const _blue   = PdfColor.fromInt(0xFF2563EB);
const _blueLt = PdfColor.fromInt(0xFF60A5FA);
const _green  = PdfColor.fromInt(0xFF10B981);
const _grLt   = PdfColor.fromInt(0xFF34D399);
const _amber  = PdfColor.fromInt(0xFFF59E0B);
const _red    = PdfColor.fromInt(0xFFEF4444);
const _purp   = PdfColor.fromInt(0xFF8B5CF6);
const _teal   = PdfColor.fromInt(0xFF14B8A6);
const _sil    = PdfColor.fromInt(0xFF94A3B8);
const _lgray  = PdfColor.fromInt(0xFFE2E8F0);
const _bgLt   = PdfColor.fromInt(0xFFF8FAFC);
const _bgSep  = PdfColor.fromInt(0xFFF1F5F9);
const _slate  = PdfColor.fromInt(0xFF334155);
const _dark   = PdfColor.fromInt(0xFF0F172A);
const _white  = PdfColors.white;
const _rowE   = PdfColor.fromInt(0xFFECFDF5);
const _rowD   = PdfColor.fromInt(0xFFFEF2F2);
const _rowB   = PdfColor.fromInt(0xFFFFFBEB);
const _calHdr = PdfColor.fromInt(0xFFEFF6FF);
const _bgPresent = PdfColor.fromInt(0xFFF0FDF4);
const _bgLate    = PdfColor.fromInt(0xFFFFFBEB);
const _bgHalf    = PdfColor.fromInt(0xFFEFF6FF);
const _bgAbsent  = PdfColor.fromInt(0xFFFEF2F2);
const _bgLeave   = PdfColor.fromInt(0xFFF0FDFA);

class PayslipPdfService {
  PayslipPdfService._();

  static const _mm = PdfPageFormat.mm;

  // ── Format helpers ────────────────────────────────────────
  static String _rp(double v) =>
      NumberFormat('#,##0.00').format(v.abs());

  static pw.TextStyle _ts({
    double sz = 9,
    PdfColor color = _dark,
    bool bold = false,
  }) =>
      pw.TextStyle(
        fontSize: sz,
        color: color,
        fontWeight:
        bold ? pw.FontWeight.bold : pw.FontWeight.normal,
      );

  // ── Public API ────────────────────────────────────────────

  static Future<List<int>> generate(
      PayrollDoc ps, {
        DailyAttendance? attendance,
      }) async {
    final pdf = pw.Document(
      title:
      'Payslip ${ps.employeeName} ${ps.monthLabel} ${ps.year}',
    );
    pdf.addPage(pw.MultiPage(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.all(12 * PdfPageFormat.mm),
      build: (ctx) {
        final items = <pw.Widget>[
          _header(ps),
          pw.SizedBox(height: 4 * _mm),
          _employeeInfo(ps),
          pw.SizedBox(height: 4 * _mm),
          _netBanner(ps),
          pw.SizedBox(height: 5 * _mm),
          _attShiftRow(ps),
          pw.SizedBox(height: 5 * _mm),
        ];
        if (attendance != null) {
          items
            ..add(_calendar(ps, attendance))
            ..add(pw.SizedBox(height: 5 * _mm));
        }
        items
          ..add(_payTables(ps))
          ..add(pw.SizedBox(height: 5 * _mm))
          ..add(_calcTable(ps))
          ..add(pw.SizedBox(height: 5 * _mm))
          ..add(_footer(ps));
        return items;
      },
    ));
    return pdf.save();
  }

  static Future<void> openOrShare(
      List<int> bytes, PayrollDoc ps) async {
    final dir = Platform.isIOS
        ? await getApplicationDocumentsDirectory()
        : (await getDownloadsDirectory()) ??
        await getApplicationDocumentsDirectory();
    final name =
        'Payslip_${ps.employeeName.replaceAll(' ', '_')}'
        '_${ps.monthLabel}_${ps.year}.pdf';
    final file = File('${dir.path}/$name');
    await file.writeAsBytes(bytes);
    await OpenFile.open(file.path);
  }

  // ════════════════════════════════════════════════════════════
  //  1. HEADER
  // ════════════════════════════════════════════════════════════
  static pw.Widget _header(PayrollDoc ps) => pw.Container(
    color: _navy,
    padding:
    const pw.EdgeInsets.symmetric(horizontal: 14, vertical: 12),
    child: pw.Row(
      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
      children: [
        pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Text('SUPREME STITCH',
                style: _ts(sz: 17, color: _white, bold: true)),
            pw.Text('Elastic & Textile Manufacturing',
                style: _ts(sz: 8, color: _blueLt)),
          ],
        ),
        pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.end,
          children: [
            pw.Text('EMPLOYEE PAYSLIP',
                style: _ts(sz: 14, color: _white, bold: true)),
            pw.Text('${ps.monthLabel} ${ps.year}',
                style: _ts(sz: 9, color: _blueLt)),
          ],
        ),
      ],
    ),
  );

  // ════════════════════════════════════════════════════════════
  //  2. EMPLOYEE INFO
  // ════════════════════════════════════════════════════════════
  static pw.Widget _employeeInfo(PayrollDoc ps) {
    final sc = ps.status == 'finalized'
        ? _green
        : ps.status == 'paid'
        ? _teal
        : _amber;

    pw.Widget lbl(String t) => pw.Padding(
        padding:
        const pw.EdgeInsets.symmetric(horizontal: 7, vertical: 4),
        child: pw.Text(t, style: _ts(sz: 8, color: _sil)));
    pw.Widget val(String t, {PdfColor c = _dark}) =>
        pw.Padding(
            padding: const pw.EdgeInsets.symmetric(
                horizontal: 7, vertical: 4),
            child:
            pw.Text(t, style: _ts(sz: 9, bold: true, color: c)));

    return pw.Table(
      border: pw.TableBorder.all(color: _lgray, width: 0.4),
      columnWidths: const {
        0: pw.FlexColumnWidth(1.8),
        1: pw.FlexColumnWidth(3),
        2: pw.FlexColumnWidth(1.8),
        3: pw.FlexColumnWidth(3),
      },
      // decoration: const pw.BoxDecoration(color: _bgLt),
      children: [
        pw.TableRow(children: [
          lbl('Employee Name'), val(ps.employeeName),
          lbl('Employee ID'),
          val(ps.id.length > 10
              ? ps.id.substring(0, 10).toUpperCase()
              : ps.id.toUpperCase()),
        ]),
        pw.TableRow(children: [
          lbl('Department'), val(ps.department),
          lbl('Pay Period'),
          val('${ps.monthLabel} ${ps.year}'),
        ]),
        pw.TableRow(children: [
          lbl('Hourly Rate'),
          val('Rs.${_rp(ps.hourlyRate)}/hr'),
          lbl('Status'),
          val(ps.status.toUpperCase(), c: sc),
        ]),
      ],
    );
  }

  // ════════════════════════════════════════════════════════════
  //  3. NET PAY BANNER
  // ════════════════════════════════════════════════════════════
  static pw.Widget _netBanner(PayrollDoc ps) => pw.Container(
    color: _navy,
    padding: const pw.EdgeInsets.symmetric(horizontal: 12, vertical: 10),
    child: pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.center,
      children: [
        pw.Text('NET PAY', style: _ts(sz: 8, color: _sil)),
        pw.SizedBox(height: 4),
        pw.Text('Rs. ${_rp(ps.netPay)}',
            style: _ts(sz: 26, color: _grLt, bold: true)),
        pw.SizedBox(height: 4),
        pw.Text(
          'Gross  Rs.${_rp(ps.grossEarnings)}'
              '   \u2212   Deductions  Rs.${_rp(ps.totalDeductions)}'
              '   +   Bonuses  Rs.${_rp(ps.totalBonuses)}',
          style: _ts(sz: 8, color: _sil),
        ),
      ],
    ),
  );

  // ════════════════════════════════════════════════════════════
  //  4. ATTENDANCE SUMMARY  |  SHIFT BREAKDOWN
  // ════════════════════════════════════════════════════════════
  static pw.Widget _attShiftRow(PayrollDoc ps) {
    pw.Widget block(String title, List<_KvItem> items,
        {required int f1, required int f2}) =>
        pw.Column(children: [
          _hdr(title),
          pw.Table(
            border: pw.TableBorder.all(color: _lgray, width: 0.3),
            // decoration: const pw.BoxDecoration(color: _bgLt),
            columnWidths: {
              0: pw.FlexColumnWidth(f1.toDouble()),
              1: pw.FlexColumnWidth(f2.toDouble()),
            },
            children: items
                .map((kv) => pw.TableRow(children: [
              _p(pw.Text(kv.label,
                  style: _ts(sz: 8, color: _sil))),
              _p(pw.Text(kv.val,
                  textAlign: pw.TextAlign.right,
                  style: _ts(
                      sz: 8.5,
                      bold: true,
                      color: kv.col))),
            ]))
                .toList(),
          ),
        ]);

    return pw.Row(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Expanded(
          flex: 53,
          child: block('ATTENDANCE SUMMARY', [
            _KvItem('Total Shifts Scheduled', '${ps.totalShifts}'),
            _KvItem('Present / Late', '${ps.presentShifts}', _green),
            _KvItem('Half Day', '${ps.halfDayShifts}', _amber),
            _KvItem('Approved Leave (paid)',
                '${ps.approvedLeaveShifts}', _teal),
            _KvItem('Unapproved Absent', '${ps.unapprovedAbsents}',
                ps.unapprovedAbsents > 0 ? _red : _sil),
            _KvItem('Excess Absents (penalised)',
                '${ps.excessAbsents}',
                ps.excessAbsents > 0 ? _red : _sil),
            _KvItem('Total Late Minutes',
                '${ps.totalLateMinutes} min', _amber),
            _KvItem('Longest Work Streak',
                '${ps.longestStreak} days', _purp),
          ], f1: 70, f2: 30),
        ),
        pw.SizedBox(width: 4 * _mm),
        pw.Expanded(
          flex: 44,
          child: block('SHIFT BREAKDOWN', [
            _KvItem('DAY shifts (12h each)',
                '${ps.dayShiftsWorked}'),
            _KvItem('DAY earnings',
                'Rs.${_rp(ps.dayShiftEarnings)}', _green),
            _KvItem('NIGHT shifts (12h each)',
                '${ps.nightShiftsWorked}'),
            _KvItem('NIGHT earnings',
                'Rs.${_rp(ps.nightShiftEarnings)}', _blueLt),
            _KvItem('Overtime minutes',
                '${ps.totalOvertimeMinutes} min', _purp),
            _KvItem('Overtime earnings',
                'Rs.${_rp(ps.overtimeEarnings)}', _purp),
          ], f1: 62, f2: 38),
        ),
      ],
    );
  }

  // ════════════════════════════════════════════════════════════
  //  5. ATTENDANCE CALENDAR
  // ════════════════════════════════════════════════════════════
  static pw.Widget _calendar(
      PayrollDoc ps, DailyAttendance att) {
    final year = ps.year;
    final month = ps.month;
    final days = DateTime(year, month + 1, 0).day;
    final start = DateTime(year, month, 1).weekday - 1;

    final Map<int, AttendanceDay> byDay = {};
    for (final d in att.days) {
      final n = int.tryParse(d.date.split('-').last) ?? 0;
      byDay.putIfAbsent(n, () => d);
    }

    // Legend
    final legend = pw.Row(children: [
      for (final entry in [
        ['P',  _green, 'Present'],
        ['L',  _amber, 'Late'],
        ['H',  _blue,  'Half Day'],
        ['A',  _red,   'Absent'],
        ['AL', _teal,  'Appr.Leave'],
        ['OT', _purp,  'Overtime'],
      ])
        pw.Expanded(
          child: pw.Row(children: [
            pw.Container(
              width: 8,
              height: 8,
              decoration: pw.BoxDecoration(
                color: PdfColor(
                    (entry[1] as PdfColor).red,
                    (entry[1] as PdfColor).green,
                    (entry[1] as PdfColor).blue,
                    0.25),
                border: pw.Border.all(
                    color: entry[1] as PdfColor, width: 0.5),
              ),
            ),
            pw.SizedBox(width: 2),
            pw.Text(
                '${entry[0]}=${entry[2]}',
                style: _ts(sz: 6, color: _sil)),
          ]),
        ),
    ]);

    // Build flat cells
    final flat = <_DayCell>[
      for (int i = 0; i < start; i++) _DayCell(null, null),
      for (int d = 1; d <= days; d++) _DayCell(d, byDay[d]),
    ];
    while (flat.length % 7 != 0) flat.add(_DayCell(null, null));

    const dows = ['MON','TUE','WED','THU','FRI','SAT','SUN'];
    final gridRows = <pw.TableRow>[
      pw.TableRow(
        decoration: const pw.BoxDecoration(color: _calHdr),
        children: dows
            .map((h) => pw.Container(
          padding:
          const pw.EdgeInsets.symmetric(vertical: 4),
          child: pw.Text(h,
              textAlign: pw.TextAlign.center,
              style:
              _ts(sz: 7.5, bold: true, color: _sil)),
        ))
            .toList(),
      ),
    ];

    for (int r = 0; r < flat.length ~/ 7; r++) {
      final week = flat.sublist(r * 7, r * 7 + 7);
      gridRows.add(pw.TableRow(
          children: week.map(_dayWidget).toList()));
    }

    return pw.Column(children: [
      _hdr(
        'ATTENDANCE CALENDAR'
            ' — ${ps.monthLabel.toUpperCase()} ${ps.year}',
        col: _blue,
      ),
      pw.SizedBox(height: 1.5 * _mm),
      pw.Container(
        color: _calHdr,
        padding: const pw.EdgeInsets.symmetric(
            horizontal: 6, vertical: 4),
        child: legend,
      ),
      pw.SizedBox(height: 1.5 * _mm),
      pw.Table(
        border: pw.TableBorder.all(color: _lgray, width: 0.3),
        children: gridRows,
      ),
    ]);
  }

  static pw.Widget _dayWidget(_DayCell c) {
    if (c.day == null) {
      return pw.Container(
          color: _white,
          padding: const pw.EdgeInsets.all(2));
    }
    final rec = c.rec;
    if (rec == null) {
      return pw.Container(
        color: _white,
        padding: const pw.EdgeInsets.all(2),
        child: pw.Text('${c.day}',
            textAlign: pw.TextAlign.center,
            style: _ts(sz: 7, color: _sil)),
      );
    }
    final st = rec.attStatus;
    final fg = _fg(st);
    final bg = _bg(st);
    final sym = _sym(st);
    final sl = rec.shift == 'DAY' ? 'D' : 'N';
    final ot = rec.hasOvertime ? ' OT' : '';
    return pw.Container(
      color: bg,
      padding: const pw.EdgeInsets.all(2),
      child: pw.Column(
        mainAxisAlignment: pw.MainAxisAlignment.center,
        children: [
          pw.Text('${c.day}',
              textAlign: pw.TextAlign.center,
              style: _ts(sz: 7.5, bold: true, color: _slate)),
          pw.Text(sym,
              textAlign: pw.TextAlign.center,
              style: _ts(sz: 8, bold: true, color: fg)),
          pw.Text('$sl$ot',
              textAlign: pw.TextAlign.center,
              style: _ts(sz: 5.5,
                  color: rec.hasOvertime ? _purp : _sil)),
        ],
      ),
    );
  }

  static PdfColor _fg(AttendanceStatus s) {
    switch (s) {
      case AttendanceStatus.present:       return _green;
      case AttendanceStatus.late:          return _amber;
      case AttendanceStatus.halfDay:       return _blue;
      case AttendanceStatus.absent:        return _red;
      case AttendanceStatus.approvedLeave: return _teal;
      default:                             return _sil;
    }
  }

  static PdfColor _bg(AttendanceStatus s) {
    switch (s) {
      case AttendanceStatus.present:       return _bgPresent;
      case AttendanceStatus.late:          return _bgLate;
      case AttendanceStatus.halfDay:       return _bgHalf;
      case AttendanceStatus.absent:        return _bgAbsent;
      case AttendanceStatus.approvedLeave: return _bgLeave;
      default:                             return _bgLt;
    }
  }

  static String _sym(AttendanceStatus s) {
    switch (s) {
      case AttendanceStatus.present:       return 'P';
      case AttendanceStatus.late:          return 'L';
      case AttendanceStatus.halfDay:       return 'H';
      case AttendanceStatus.absent:        return 'A';
      case AttendanceStatus.approvedLeave: return 'AL';
      default:                             return '?';
    }
  }

  // ════════════════════════════════════════════════════════════
  //  6. EARNINGS / DEDUCTIONS / BONUSES
  // ════════════════════════════════════════════════════════════
  static pw.Widget _payTables(PayrollDoc ps) => pw.Row(
    crossAxisAlignment: pw.CrossAxisAlignment.start,
    children: [
      pw.Expanded(
          flex: 36,
          child: _paySection('EARNINGS', ps.earnings, _green)),
      pw.SizedBox(width: 3 * _mm),
      pw.Expanded(
          flex: 30,
          child: _paySection('DEDUCTIONS', ps.deductions, _red)),
      pw.SizedBox(width: 3 * _mm),
      pw.Expanded(
          flex: 27,
          child: _paySection('BONUSES', ps.bonuses, _amber)),
    ],
  );

  static pw.Widget _paySection(
      String title, List<PayrollLineItem> items, PdfColor col) {
    double total = 0;
    final rows = <pw.TableRow>[
      pw.TableRow(
        decoration: pw.BoxDecoration(color: col),
        children: [
          _p(pw.Text('Description',
              style: _ts(sz: 7.5, bold: true, color: _white))),
          _p(pw.Text('Amount',
              textAlign: pw.TextAlign.right,
              style: _ts(sz: 7.5, bold: true, color: _white))),
        ],
      ),
    ];
    for (final item in items) {
      total += item.amount.abs();
      final s = item.amount >= 0 ? '+' : '\u2212';
      rows.add(pw.TableRow(
        decoration: const pw.BoxDecoration(color: _bgLt),
        children: [
          _p(pw.Text(item.label, style: _ts(sz: 7, color: _slate))),
          _p(pw.Text('$s Rs.${_rp(item.amount)}',
              textAlign: pw.TextAlign.right,
              style: _ts(sz: 7, bold: true, color: col))),
        ],
      ));
    }
    rows.add(pw.TableRow(
      decoration: const pw.BoxDecoration(color: _bgSep),
      children: [
        _p(pw.Text('TOTAL',
            style: _ts(sz: 8, bold: true, color: col))),
        _p(pw.Text('Rs.${_rp(total)}',
            textAlign: pw.TextAlign.right,
            style: _ts(sz: 8, bold: true, color: col))),
      ],
    ));
    return pw.Column(children: [
      _hdr(title, col: col),
      pw.Table(
        border: pw.TableBorder.all(color: _lgray, width: 0.3),
        columnWidths: const {
          0: pw.FlexColumnWidth(7),
          1: pw.FlexColumnWidth(3),
        },
        children: rows,
      ),
    ]);
  }

  // ════════════════════════════════════════════════════════════
  //  7. SALARY CALCULATION
  // ════════════════════════════════════════════════════════════
  static pw.Widget _calcTable(PayrollDoc ps) {
    final r = ps.hourlyRate;

    final lines = <_Calc>[
      _Calc('E', 'DAY Shifts (12h each)',
          'Rs.${_rp(r)} x 12h = Rs.${_rp(r * 12)}',
          '${ps.dayShiftsWorked} shifts',
          '+Rs.${_rp(ps.dayShiftEarnings)}', _green),
      _Calc('E', 'NIGHT Shifts (12h each)',
          'Rs.${_rp(r)} x 12h = Rs.${_rp(r * 12)}',
          '${ps.nightShiftsWorked} shifts',
          '+Rs.${_rp(ps.nightShiftEarnings)}', _green),
      if (ps.overtimeEarnings > 0)
        _Calc('E',
            'Overtime (${ps.totalOvertimeMinutes}min total, 60min grace free)',
            'Rs.${_rp(r)} x 1.5',
            '${ps.totalOvertimeMinutes - 60}min paid',
            '+Rs.${_rp(ps.overtimeEarnings)}', _purp),
      if (ps.totalLateMinutes > 0)
        _Calc('D', 'Late Deductions (${ps.totalLateMinutes} min total)',
            'Billable min / 60 x rate',
            '${ps.totalLateMinutes} min',
            '\u2212Rs.${_rp(ps.totalDeductions - (ps.unapprovedAbsents * r * 12))}',
            _red),
      if (ps.unapprovedAbsents > 0)
        _Calc('D', 'Unapproved Absents',
            'Rs.${_rp(r * 12)} x ${ps.unapprovedAbsents}',
            '${ps.unapprovedAbsents} shifts',
            '\u2212Rs.${_rp(ps.unapprovedAbsents * r * 12)}', _red),
      if (ps.totalAdvanceDeduction > 0)
        _Calc('D', 'Advance Salary Recovery', '\u2014', '\u2014',
            '\u2212Rs.${_rp(ps.totalAdvanceDeduction)}', _red),
      if (ps.noLeaveBonus > 0)
        _Calc('B', 'No-Leave Bonus', '\u2014', '\u2014',
            '+Rs.${_rp(ps.noLeaveBonus)}', _amber),
      if (ps.perfectAttendanceBonus > 0)
        _Calc('B', 'Perfect Attendance Bonus', '\u2014', '\u2014',
            '+Rs.${_rp(ps.perfectAttendanceBonus)}', _amber),
      if (ps.totalStreakBonus > 0)
        _Calc('B',
            '${ps.longestStreak}-Day Streak Bonus',
            'Rs.100 per 7-day set',
            '${ps.longestStreak ~/ 7} sets',
            '+Rs.${_rp(ps.totalStreakBonus)}', _amber),
    ];

    final typeCol = {'E': _rowE, 'D': _rowD, 'B': _rowB};
    final typeFg  = {'E': _green, 'D': _red, 'B': _amber};

    pw.TableRow sumRow(String lbl, String val, PdfColor c) =>
        pw.TableRow(
          decoration: const pw.BoxDecoration(color: _bgSep),
          children: [
            _p(pw.Text('', style: _ts(sz: 8))),
            _p(pw.Text(lbl,
                style: _ts(sz: 9, bold: true, color: c))),
            _p(pw.Text('', style: _ts(sz: 8))),
            _p(pw.Text('', style: _ts(sz: 8))),
            _p(pw.Text(val,
                textAlign: pw.TextAlign.right,
                style: _ts(sz: 9, bold: true, color: c))),
          ],
        );

    return pw.Column(children: [
      _hdr('SALARY CALCULATION — DETAILED WORKINGS'),
      pw.SizedBox(height: 1.5 * _mm),
      pw.Table(
        border: pw.TableBorder.all(color: _lgray, width: 0.3),
        columnWidths: const {
          0: pw.FixedColumnWidth(14),
          1: pw.FlexColumnWidth(4.0),
          2: pw.FlexColumnWidth(2.8),
          3: pw.FlexColumnWidth(1.5),
          4: pw.FlexColumnWidth(2.2),
        },
        children: [
          // Header
          pw.TableRow(
            decoration: pw.BoxDecoration(color: _navy2),
            children: [
              for (final h in [
                '',
                'Component',
                'Rate / Basis',
                'Qty',
                'Amount',
              ])
                _p(pw.Text(h,
                    textAlign: h == 'Amount' || h == 'Qty'
                        ? pw.TextAlign.right
                        : pw.TextAlign.left,
                    style:
                    _ts(sz: 8, bold: true, color: _sil))),
            ],
          ),
          // Data rows
          ...lines.map((l) => pw.TableRow(
            decoration: pw.BoxDecoration(
                color: typeCol[l.type] ?? _bgLt),
            children: [
              _p(pw.Text(l.type,
                  style: _ts(sz: 8, bold: true,
                      color: typeFg[l.type] ?? _sil))),
              _p(pw.Text(l.desc,
                  style: _ts(sz: 8, color: _slate))),
              _p(pw.Text(l.basis,
                  style: _ts(sz: 7.5, color: _sil))),
              _p(pw.Text(l.qty,
                  textAlign: pw.TextAlign.right,
                  style: _ts(sz: 7.5, color: _sil))),
              _p(pw.Text(l.amount,
                  textAlign: pw.TextAlign.right,
                  style: _ts(sz: 8, bold: true,
                      color: l.amtCol))),
            ],
          )),
          sumRow('GROSS EARNINGS',
              'Rs.${_rp(ps.grossEarnings)}', _green),
          sumRow('TOTAL DEDUCTIONS',
              '\u2212Rs.${_rp(ps.totalDeductions)}', _red),
          sumRow('TOTAL BONUSES',
              '+Rs.${_rp(ps.totalBonuses)}', _amber),
          // Net pay
          pw.TableRow(
            decoration: pw.BoxDecoration(color: _navy),
            children: [
              _p(pw.Text('', style: _ts(sz: 8))),
              _p(pw.Text('NET PAY',
                  style: _ts(
                      sz: 12, bold: true, color: _white))),
              _p(pw.Text('', style: _ts(sz: 8))),
              _p(pw.Text('', style: _ts(sz: 8))),
              _p(pw.Text('Rs.${_rp(ps.netPay)}',
                  textAlign: pw.TextAlign.right,
                  style: _ts(
                      sz: 12, bold: true, color: _grLt))),
            ],
          ),
        ],
      ),
    ]);
  }

  // ════════════════════════════════════════════════════════════
  //  8. FOOTER
  // ════════════════════════════════════════════════════════════
  static pw.Widget _footer(PayrollDoc ps) {
    final gen =
    DateFormat('dd MMM yyyy HH:mm').format(DateTime.now());
    return pw.Column(children: [
      pw.Divider(color: _lgray, thickness: 0.5),
      pw.SizedBox(height: 2 * _mm),
      pw.Row(
        mainAxisAlignment:
        pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text('Generated: $gen',
              style: _ts(sz: 7.5, color: _sil)),
          pw.Text(
            'Computer-generated payslip. No signature required.',
            style: _ts(sz: 7.5, color: _sil),
          ),
          pw.Text('SUPREME STITCH — CONFIDENTIAL',
              style: _ts(sz: 7.5, color: _sil)),
        ],
      ),
    ]);
  }

  // ── Micro helpers ─────────────────────────────────────────

  static pw.Widget _hdr(String txt, {PdfColor col = _navy2}) =>
      pw.Container(
        width: double.infinity,
        color: col,
        padding: const pw.EdgeInsets.symmetric(
            horizontal: 8, vertical: 5),
        child: pw.Text(txt,
            style: _ts(sz: 9, bold: true, color: _white)),
      );

  static pw.Widget _p(pw.Widget child) => pw.Padding(
      padding: const pw.EdgeInsets.symmetric(
          horizontal: 7, vertical: 4),
      child: child);
}

// ── Internal DTOs ─────────────────────────────────────────────
class _KvItem {
  final String label, val;
  final PdfColor col;
  const _KvItem(this.label, this.val, [this.col = _dark]);
}

class _DayCell {
  final int? day;
  final AttendanceDay? rec;
  const _DayCell(this.day, this.rec);
}

class _Calc {
  final String type, desc, basis, qty, amount;
  final PdfColor amtCol;
  const _Calc(this.type, this.desc, this.basis, this.qty,
      this.amount, this.amtCol);
}