// ══════════════════════════════════════════════════════════════
//  SAMPLE REQUEST MODELS
//
//  Mirrors what /api/v2/sample hands back (prod/api/sample.js). The
//  request itself is written once and never edited; everything after it
//  is an appended log entry carrying its author and time, so these are
//  read-only value objects with no setters to tempt anyone.
// ══════════════════════════════════════════════════════════════

const kSampleStatuses = ['open', 'in_progress', 'completed', 'closed'];

/// The two an admin sets. Neither takes further entries until reopened.
const kSampleTerminalStatuses = ['completed', 'closed'];

bool isSampleTerminal(String status) => kSampleTerminalStatuses.contains(status);

String sampleStatusLabel(String status) {
  switch (status) {
    case 'in_progress':
      return 'In progress';
    case 'completed':
      return 'Completed';
    case 'closed':
      return 'Closed';
    case 'open':
      return 'Open';
    default:
      return status.replaceAll('_', ' ');
  }
}

double _d(dynamic v) => (v as num?)?.toDouble() ?? 0;
String _s(dynamic v) => v?.toString() ?? '';

DateTime? _date(dynamic v) {
  if (v == null) return null;
  return DateTime.tryParse(v.toString())?.toLocal();
}

class SampleLogEntry {
  final String id;

  /// created · update · status · photo · photo_removed
  final String kind;
  final String note;

  /// Set on a status entry — where it moved to, and from.
  final String? status;
  final String? fromStatus;

  /// Set on a photo entry — the SamplePhoto it is about.
  final String? photoId;

  final String byName;
  final DateTime? at;

  const SampleLogEntry({
    required this.id,
    required this.kind,
    required this.note,
    required this.byName,
    this.status,
    this.fromStatus,
    this.photoId,
    this.at,
  });

  factory SampleLogEntry.fromJson(Map<String, dynamic> j) => SampleLogEntry(
        id: _s(j['_id']),
        kind: _s(j['kind']).isEmpty ? 'update' : _s(j['kind']),
        note: _s(j['note']),
        status: j['status']?.toString(),
        fromStatus: j['fromStatus']?.toString(),
        photoId: j['photo']?.toString(),
        byName: _s(j['byName']),
        at: _date(j['at']),
      );

  /// What the entry is, said in the same words the web log uses.
  String get title {
    switch (kind) {
      case 'created':
        return 'Sample raised';
      case 'status':
        final to = sampleStatusLabel(status ?? '');
        return fromStatus != null && fromStatus!.isNotEmpty
            ? '${sampleStatusLabel(fromStatus!)} → $to'
            : 'Marked $to';
      case 'photo':
        return 'Photo added';
      case 'photo_removed':
        return 'Photo removed';
      default:
        return 'Update';
    }
  }
}

class SamplePhoto {
  final String id;
  final String caption;
  final String filename;
  final String uploadedByName;
  final DateTime? createdAt;

  /// A removed photo keeps its row — the log said it was put here, and a
  /// gallery that quietly lost one would contradict it.
  final bool removed;
  final String removalReason;

  const SamplePhoto({
    required this.id,
    required this.caption,
    required this.filename,
    required this.uploadedByName,
    required this.removed,
    required this.removalReason,
    this.createdAt,
  });

  factory SamplePhoto.fromJson(Map<String, dynamic> j) => SamplePhoto(
        id: _s(j['_id']),
        caption: _s(j['caption']),
        filename: _s(j['filename']),
        uploadedByName: _s(j['uploadedByName']),
        removed: j['removed'] == true,
        removalReason: _s(j['removalReason']),
        createdAt: _date(j['createdAt']),
      );

  String get label =>
      caption.isNotEmpty ? caption : (filename.isNotEmpty ? filename : 'Photo');
}

/// One row of the list. Carries the last thing that happened, so a row
/// says something more useful than a date.
class SampleRow {
  final String id;
  final int sampleNo;
  final String title;
  final String customerName;
  final String details;
  final double quantity;
  final String priority;
  final String status;
  final String raisedByName;
  final DateTime? createdAt;
  final int logCount;
  final int photoCount;
  final SampleLogEntry? lastEntry;

  const SampleRow({
    required this.id,
    required this.sampleNo,
    required this.title,
    required this.customerName,
    required this.details,
    required this.quantity,
    required this.priority,
    required this.status,
    required this.raisedByName,
    required this.logCount,
    required this.photoCount,
    this.createdAt,
    this.lastEntry,
  });

  factory SampleRow.fromJson(Map<String, dynamic> j) => SampleRow(
        id: _s(j['_id']),
        sampleNo: (j['sampleNo'] as num?)?.toInt() ?? 0,
        title: _s(j['title']),
        customerName: _s(j['customerName']),
        details: _s(j['details']),
        quantity: _d(j['quantity']),
        priority: _s(j['priority']).isEmpty ? 'normal' : _s(j['priority']),
        status: _s(j['status']).isEmpty ? 'open' : _s(j['status']),
        raisedByName: _s(j['raisedByName']),
        logCount: (j['logCount'] as num?)?.toInt() ?? 0,
        photoCount: (j['photoCount'] as num?)?.toInt() ?? 0,
        createdAt: _date(j['createdAt']),
        lastEntry: j['lastEntry'] is Map
            ? SampleLogEntry.fromJson(Map<String, dynamic>.from(j['lastEntry']))
            : null,
      );

  String get code => 'S-$sampleNo';

  /// The last entry, read back as a sentence for the list row.
  String get lastLine {
    final e = lastEntry;
    if (e == null) return '—';
    switch (e.kind) {
      case 'status':
        final marked = 'Marked ${sampleStatusLabel(e.status ?? '').toLowerCase()}';
        return e.note.isEmpty ? marked : '$marked — ${e.note}';
      case 'photo':
        return e.note.isEmpty ? 'Photo added' : 'Photo — ${e.note}';
      case 'photo_removed':
        return 'Photo removed — ${e.note}';
      case 'created':
        return e.note.isEmpty ? 'Raised' : e.note;
      default:
        return e.note;
    }
  }
}

class SampleDetail extends SampleRow {
  final List<SampleLogEntry> log;
  final List<SamplePhoto> photos;
  final DateTime? targetDate;
  final DateTime? closedAt;

  const SampleDetail({
    required super.id,
    required super.sampleNo,
    required super.title,
    required super.customerName,
    required super.details,
    required super.quantity,
    required super.priority,
    required super.status,
    required super.raisedByName,
    required super.logCount,
    required super.photoCount,
    required this.log,
    required this.photos,
    super.createdAt,
    super.lastEntry,
    this.targetDate,
    this.closedAt,
  });

  factory SampleDetail.fromJson(Map<String, dynamic> j) {
    final row = SampleRow.fromJson(j);
    return SampleDetail(
      id: row.id,
      sampleNo: row.sampleNo,
      title: row.title,
      customerName: row.customerName,
      details: row.details,
      quantity: row.quantity,
      priority: row.priority,
      status: row.status,
      raisedByName: row.raisedByName,
      logCount: row.logCount,
      photoCount: row.photoCount,
      createdAt: row.createdAt,
      lastEntry: row.lastEntry,
      targetDate: _date(j['targetDate']),
      closedAt: _date(j['closedAt']),
      log: (j['log'] as List? ?? const [])
          .whereType<Map>()
          .map((e) => SampleLogEntry.fromJson(Map<String, dynamic>.from(e)))
          .toList(),
      photos: (j['photos'] as List? ?? const [])
          .whereType<Map>()
          .map((e) => SamplePhoto.fromJson(Map<String, dynamic>.from(e)))
          .toList(),
    );
  }

  bool get ended => isSampleTerminal(status);
}

/// Counts for the filter chips, over EVERY request rather than the
/// filtered page — a tab reading 0 because the search excluded it lies.
class SampleCounts {
  final int open;
  final int inProgress;
  final int completed;
  final int closed;

  const SampleCounts({
    this.open = 0,
    this.inProgress = 0,
    this.completed = 0,
    this.closed = 0,
  });

  factory SampleCounts.fromJson(Map<String, dynamic> j) => SampleCounts(
        open: (j['open'] as num?)?.toInt() ?? 0,
        inProgress: (j['in_progress'] as num?)?.toInt() ?? 0,
        completed: (j['completed'] as num?)?.toInt() ?? 0,
        closed: (j['closed'] as num?)?.toInt() ?? 0,
      );

  int get live => open + inProgress;

  int forFilter(String filter) {
    switch (filter) {
      case 'active':
        return live;
      case 'open':
        return open;
      case 'in_progress':
        return inProgress;
      case 'completed':
        return completed;
      case 'closed':
        return closed;
      default:
        return 0;
    }
  }
}
