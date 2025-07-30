class CompanyDetails {
  final int id;
  final String ownerName1;
  final String ownerName2;
  final String otherName;
  final String phone;
  final String vatNo;
  final String crNumber;
  final String address;
  final String city;
  final String email;

  CompanyDetails({
    required this.id,
    required this.ownerName1,
    required this.ownerName2,
    required this.otherName,
    required this.phone,
    required this.vatNo,
    this.crNumber = '',
    this.address = '',
    this.city = '',
    this.email = '',
  });

  Map<String, dynamic> toMap() => {
    'id': id,
    'ownerName1': ownerName1,
    'ownerName2': ownerName2,
    'otherName': otherName,
    'phone': phone,
    'vatNo': vatNo,
    'crNumber': crNumber,
    'address': address,
    'city': city,
    'email': email,
  };

  factory CompanyDetails.fromMap(Map<String, dynamic> m) => CompanyDetails(
    id: m['id'] as int,
    ownerName1: m['ownerName1'] as String,
    ownerName2: m['ownerName2'] as String,
    otherName: m['otherName'] as String,
    phone: m['phone'] as String,
    vatNo: m['vatNo'] as String,
    crNumber: m['crNumber'] as String? ?? '',
    address: m['address'] as String? ?? '',
    city: m['city'] as String? ?? '',
    email: m['email'] as String? ?? '',
  );
}