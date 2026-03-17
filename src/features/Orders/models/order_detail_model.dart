class OrderElasticView {
  final String name;
  final int ordered;
  final int produced;
  final int packed;
  final int pending;

  OrderElasticView({
    required this.name,
    required this.ordered,
    required this.produced,
    required this.packed,
    required this.pending,
  });
}

class JobOrderView {
  final String id;
  final int jobNo;
  final String status;
  final String stage;

  JobOrderView({
    required this.id,
    required this.jobNo,
    required this.status,
    required this.stage,
  });
}

class OrderDetailView {
  final String id;
  final int orderNo;
  final String customer;
  final String status;
  final List<OrderElasticView> elastics;
  final List<JobOrderView> jobs;

  OrderDetailView({
    required this.id,
    required this.orderNo,
    required this.customer,
    required this.status,
    required this.elastics,
    required this.jobs,
  });
}
