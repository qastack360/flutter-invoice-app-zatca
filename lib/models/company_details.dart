class CompanyDetails {
  final int id;
  final String ownerName1;
  final String ownerName2;
  final String otherName;
  final String phone;
  final String vatNo;

  CompanyDetails({
    required this.id,
    required this.ownerName1,
    required this.ownerName2,
    required this.otherName,
    required this.phone,
    required this.vatNo,
  });

  Map<String, dynamic> toMap() => {
    'id': id,
    'ownerName1': ownerName1,
    'ownerName2': ownerName2,
    'otherName': otherName,
    'phone': phone,
    'vatNo': vatNo,
  };

  factory CompanyDetails.fromMap(Map<String, dynamic> m) => CompanyDetails(
    id: m['id'] as int,
    ownerName1: m['ownerName1'] as String,
    ownerName2: m['ownerName2'] as String,
    otherName: m['otherName'] as String,
    phone: m['phone'] as String,
    vatNo: m['vatNo'] as String,
  );
}