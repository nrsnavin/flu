class JobRefModel {
  final String jobId;
  final int jobNo;

  JobRefModel({
    required this.jobId,
    required this.jobNo,
  });

  factory JobRefModel.fromJson(Map<String, dynamic> json) {
    return JobRefModel(
      jobId: json['job'],
      jobNo: json['no'] ?? 0,
    );
  }
}
