class LocalDevice {
  const LocalDevice({
    required this.id,
    required this.profileId,
    required this.name,
    required this.createdAt,
    this.lastConnectedAt,
  });

  final String id;
  final String profileId;
  final String name;
  final DateTime createdAt;
  final DateTime? lastConnectedAt;
}
