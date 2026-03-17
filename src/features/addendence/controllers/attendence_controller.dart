// ══════════════════════════════════════════════════════════════
//  ATTENDANCE CONTROLLER
//  File: lib/src/features/attendance/controllers/attendance_controller.dart
// ══════════════════════════════════════════════════════════════
import 'package:dio/dio.dart';
import 'package:get/get.dart';
import '../models/attendence_model.dart';

final _dio = Dio(BaseOptions(
  baseUrl:        'http://13.233.117.153:2701/api/v2/attendance',
  connectTimeout: const Duration(seconds: 15),
  receiveTimeout: const Duration(seconds: 15),
));

enum AttendanceView { markShift, summary, calendar }

class AttendanceController extends GetxController {
  // ── Active view ────────────────────────────────────────────
  final activeView = AttendanceView.markShift.obs;

  // ── Date / shift selectors ────────────────────────────────
  late final Rx<DateTime> selectedDate;
  final selectedShift = 'DAY'.obs;   // DAY | NIGHT

  // ── Mark-shift state ──────────────────────────────────────
  final isLoadingDaily  = false.obs;
  final dailyData       = Rxn<DailyAttendanceData>();
  final dailyError      = RxnString();

  // Draft edits: employeeId → AttendanceRecord (pending save)
  final draftMap        = <String, AttendanceRecord>{}.obs;
  final isSaving        = false.obs;
  final saveError       = RxnString();
  final saveSuccess     = false.obs;

  // ── Summary state ─────────────────────────────────────────
  final isLoadingSummary = false.obs;
  final summaryError     = RxnString();
  final factorySummary   = Rxn<FactorySummary>();
  final summaryList      = <EmployeeSummaryRow>[].obs;
  late final Rx<DateTime> summaryStart;
  late final Rx<DateTime> summaryEnd;
  final summaryShift     = 'all'.obs;

  // ── Calendar state ────────────────────────────────────────
  final isLoadingCalendar = false.obs;
  final calendarError     = RxnString();
  final calendarDays      = <CalendarDay>[].obs;
  final calendarEmployee  = Rxn<Map<String, dynamic>>();
  final calendarEmpId     = RxnString();
  final calendarYear      = DateTime.now().year.obs;
  final calendarMonth     = DateTime.now().month.obs;

  // ── Lifecycle ──────────────────────────────────────────────
  @override
  void onInit() {
    super.onInit();
    final now   = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    selectedDate  = today.obs;
    summaryStart  = today.subtract(const Duration(days: 29)).obs;
    summaryEnd    = today.obs;
    fetchDailyAttendance();
    fetchSummary();
  }

  // ── Fetch daily attendance ────────────────────────────────
  Future<void> fetchDailyAttendance() async {
    isLoadingDaily.value = true;
    dailyError.value     = null;
    draftMap.clear();
    saveSuccess.value    = false;

    try {
      final res = await _dio.get('/date', queryParameters: {
        'date':  _fmtDate(selectedDate.value),
        'shift': selectedShift.value,
      });
      dailyData.value = DailyAttendanceData.fromJson(
          res.data as Map<String, dynamic>);

      // Pre-fill drafts with existing records
      for (final r in dailyData.value!.records) {
        draftMap[r.employeeId] = r;
      }
      // Unmarked employees get a default draft of 'present'
      for (final emp in dailyData.value!.unmarked) {
        draftMap[emp.id] = AttendanceRecord(
          id: null, employeeId: emp.id, name: emp.name,
          department: emp.department, skill: emp.skill, role: emp.role,
          date: _fmtDate(selectedDate.value), dateLabel: '',
          dayOfWeek: '', shift: selectedShift.value,
          status: AttendanceStatus.present, checkIn: '',
          checkOut: '', lateMinutes: 0, leaveType: '', notes: '',
        );
      }
    } on DioException catch (e) {
      dailyError.value = e.response?.data?['message']?.toString()
          ?? 'Failed to load attendance';
    } catch (e) {
      dailyError.value = e.toString();
    } finally {
      isLoadingDaily.value = false;
    }
  }

  // ── Update a single draft record ──────────────────────────
  void setStatus(String empId, AttendanceStatus status) {
    final existing = draftMap[empId];
    if (existing != null) {
      draftMap[empId] = existing.copyWith(
        status:      status,
        lateMinutes: status != AttendanceStatus.late ? 0 : existing.lateMinutes,
        leaveType:   status != AttendanceStatus.on_leave ? '' : existing.leaveType,
      );
    }
  }

  void setCheckIn(String empId, String time) {
    final e = draftMap[empId];
    if (e != null) draftMap[empId] = e.copyWith(checkIn: time);
  }

  void setCheckOut(String empId, String time) {
    final e = draftMap[empId];
    if (e != null) draftMap[empId] = e.copyWith(checkOut: time);
  }

  void setLateMinutes(String empId, int mins) {
    final e = draftMap[empId];
    if (e != null) draftMap[empId] = e.copyWith(lateMinutes: mins);
  }

  void setLeaveType(String empId, String type) {
    final e = draftMap[empId];
    if (e != null) draftMap[empId] = e.copyWith(leaveType: type);
  }

  void setNotes(String empId, String notes) {
    final e = draftMap[empId];
    if (e != null) draftMap[empId] = e.copyWith(notes: notes);
  }

  // ── Mark all drafts as present ────────────────────────────
  void markAllPresent() {
    for (final id in draftMap.keys.toList()) {
      draftMap[id] = draftMap[id]!.copyWith(status: AttendanceStatus.present);
    }
  }

  // ── Save attendance ───────────────────────────────────────
  Future<void> saveAttendance() async {
    isSaving.value    = true;
    saveError.value   = null;
    saveSuccess.value = false;

    try {
      final records = draftMap.values.map((r) => {
        'employeeId':  r.employeeId,
        'status':      r.status.value,
        'checkIn':     r.checkIn,
        'checkOut':    r.checkOut,
        'lateMinutes': r.lateMinutes,
        'leaveType':   r.leaveType,
        'notes':       r.notes,
      }).toList();

      await _dio.post('/mark', data: {
        'date':     _fmtDate(selectedDate.value),
        'shift':    selectedShift.value,
        'records':  records,
        'markedBy': 'admin',
      });

      saveSuccess.value = true;
      await fetchDailyAttendance();  // refresh
    } on DioException catch (e) {
      saveError.value = e.response?.data?['message']?.toString() ?? 'Save failed';
    } catch (e) {
      saveError.value = e.toString();
    } finally {
      isSaving.value = false;
    }
  }

  // ── Fetch summary ──────────────────────────────────────────
  Future<void> fetchSummary() async {
    isLoadingSummary.value = true;
    summaryError.value     = null;

    try {
      final res = await _dio.get('/summary', queryParameters: {
        'startDate': _fmtDate(summaryStart.value),
        'endDate':   _fmtDate(summaryEnd.value),
        'shift':     summaryShift.value,
      });
      final body = res.data as Map<String, dynamic>;
      factorySummary.value = FactorySummary.fromJson(
          body['factory'] as Map<String, dynamic>? ?? {});
      summaryList.value = (body['employees'] as List? ?? [])
          .map((e) => EmployeeSummaryRow.fromJson(e as Map<String, dynamic>))
          .toList();
    } on DioException catch (e) {
      summaryError.value = e.response?.data?['message']?.toString()
          ?? 'Failed to load summary';
    } catch (e) {
      summaryError.value = e.toString();
    } finally {
      isLoadingSummary.value = false;
    }
  }

  // ── Fetch monthly calendar ────────────────────────────────
  Future<void> fetchCalendar() async {
    if (calendarEmpId.value == null) return;
    isLoadingCalendar.value = true;
    calendarError.value     = null;

    try {
      final res = await _dio.get(
        '/monthly/${calendarEmpId.value}',
        queryParameters: {
          'year':  calendarYear.value,
          'month': calendarMonth.value,
        },
      );
      final body = res.data as Map<String, dynamic>;
      calendarEmployee.value = body['employee'] as Map<String,dynamic>?;
      calendarDays.value = (body['calendar'] as List? ?? [])
          .map((e) => CalendarDay.fromJson(e as Map<String, dynamic>))
          .toList();
    } on DioException catch (e) {
      calendarError.value = e.response?.data?['message']?.toString()
          ?? 'Failed to load calendar';
    } catch (e) {
      calendarError.value = e.toString();
    } finally {
      isLoadingCalendar.value = false;
    }
  }

  void openCalendar(String empId) {
    calendarEmpId.value = empId;
    activeView.value    = AttendanceView.calendar;
    fetchCalendar();
  }

  void prevMonth() {
    if (calendarMonth.value == 1) {
      calendarMonth.value = 12;
      calendarYear.value--;
    } else {
      calendarMonth.value--;
    }
    fetchCalendar();
  }

  void nextMonth() {
    if (calendarMonth.value == 12) {
      calendarMonth.value = 1;
      calendarYear.value++;
    } else {
      calendarMonth.value++;
    }
    fetchCalendar();
  }

  // ── Helper ────────────────────────────────────────────────
  String _fmtDate(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2,'0')}-${d.day.toString().padLeft(2,'0')}';

  int get totalEmployeesInDraft => draftMap.length;
  int get presentCount  => draftMap.values.where((r)=>r.status==AttendanceStatus.present).length;
  int get absentCount   => draftMap.values.where((r)=>r.status==AttendanceStatus.absent).length;
  int get lateCount     => draftMap.values.where((r)=>r.status==AttendanceStatus.late).length;
  int get halfDayCount  => draftMap.values.where((r)=>r.status==AttendanceStatus.half_day).length;
  int get onLeaveCount  => draftMap.values.where((r)=>r.status==AttendanceStatus.on_leave).length;
}