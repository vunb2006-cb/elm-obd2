class DtcCode {
  final String code;       // e.g. "P0171"
  final String rawHex;     // raw hex bytes from OBD
  final String? description;
  final bool isPending;    // mode 07 vs mode 03

  const DtcCode({
    required this.code,
    required this.rawHex,
    this.description,
    this.isPending = false,
  });

  @override
  String toString() => '$code${description != null ? ' - $description' : ''}';
}
