class AppUser {
  final int userId;
  final String authUid;
  final String username;
  final String displayName;
  final DateTime createdAt;

  const AppUser({
    required this.userId,
    required this.authUid,
    required this.username,
    required this.displayName,
    required this.createdAt,
  });

  factory AppUser.fromJson(Map<String, dynamic> json) {
    return AppUser(
      userId: json['user_id'] as int,
      authUid: json['auth_uid'] as String,
      username: json['username'] as String,
      displayName: json['display_name'] as String,
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'] as String)
          : DateTime.now(),
    );
  }
}
