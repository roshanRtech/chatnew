class AdminModel {
  final String uid;
  final String name;
  final String email;
  final String role;

  AdminModel({
    required this.uid,
    required this.name,
    required this.email,
    required this.role,
  });

  factory AdminModel.fromJson(Map<String, dynamic> json) {
    return AdminModel(
      uid: json['uid'],
      name: json['name'],
      email: json['email'],
      role: json['userRole'],
    );
  }

  Map<String, dynamic> toJson() => {
        'uid': uid,
        'name': name,
        'email': email,
        'userRole': role,
      };
}
