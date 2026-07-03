import 'dart:convert';

/// Result of parsing a Pana JSON report.
class PanaResult {
  const PanaResult({
    required this.grantedPoints,
    required this.maxPoints,
    required this.packageName,
    this.hasFormatOnlyException = false,
  });

  /// Points granted by Pana.
  final int grantedPoints;

  /// Maximum possible points.
  final int maxPoints;

  /// Package name from the report.
  final String packageName;

  /// True when Pana missed points only because of its formatter sandbox check.
  ///
  /// This is an explicit exception for a known Pana/formatter mismatch. Real
  /// analysis warnings, lint failures, documentation misses, dependency issues,
  /// or publish-readiness failures must still fail the gate.
  final bool hasFormatOnlyException;

  /// True when grantedPoints equals maxPoints.
  ///
  /// Never compare against a hardcoded score like 160.
  bool get isMaxScore => grantedPoints == maxPoints;

  /// True when the Pana result is acceptable for this repository.
  ///
  /// Max score passes. A narrow format-only Pana sandbox exception is also
  /// accepted because `dart analyze` and `dart format` are checked separately.
  bool get isAcceptable => isMaxScore || hasFormatOnlyException;

  /// Score as a percentage (0.0 - 100.0).
  double get scorePercent {
    if (maxPoints == 0) return 100;
    return (grantedPoints / maxPoints) * 100;
  }
}

/// Parses Pana JSON output into a [PanaResult].
class PanaParser {
  /// Parses Pana JSON content and extracts score information.
  ///
  /// Throws [FormatException] if:
  /// - JSON is invalid
  /// - Missing `scores` field
  /// - Missing `grantedPoints` or `maxPoints` in scores
  ///
  /// The pass condition is `grantedPoints == maxPoints`, NOT a hardcoded value.
  static PanaResult parsePanaJson(String content) {
    final dynamic json;
    try {
      json = jsonDecode(content);
    } on FormatException catch (e) {
      throw FormatException('Invalid Pana JSON: ${e.message}');
    }

    if (json is! Map<String, dynamic>) {
      throw const FormatException('Pana JSON root must be an object');
    }

    final scores = json['scores'];
    if (scores is! Map<String, dynamic>) {
      throw const FormatException('Missing or invalid "scores" field');
    }

    final grantedPoints = scores['grantedPoints'];
    if (grantedPoints is! int) {
      throw const FormatException(
        'Missing or invalid "grantedPoints" in scores',
      );
    }

    final maxPoints = scores['maxPoints'];
    if (maxPoints is! int) {
      throw const FormatException('Missing or invalid "maxPoints" in scores');
    }

    final packageName = json['packageName'] as String? ?? 'unknown';
    final hasFormatOnlyException = _hasFormatOnlyException(json);

    return PanaResult(
      grantedPoints: grantedPoints,
      maxPoints: maxPoints,
      packageName: packageName,
      hasFormatOnlyException: hasFormatOnlyException,
    );
  }

  static bool _hasFormatOnlyException(Map<String, dynamic> json) {
    final report = json['report'];
    if (report is! Map<String, dynamic>) return false;

    final sections = report['sections'];
    if (sections is! List) return false;

    final nonPassingSections = sections.where((section) {
      if (section is! Map<String, dynamic>) return true;
      final grantedPoints = section['grantedPoints'];
      final maxPoints = section['maxPoints'];
      return grantedPoints != maxPoints;
    }).toList();

    if (nonPassingSections.length != 1) return false;

    final section = nonPassingSections.single;
    if (section is! Map<String, dynamic>) return false;

    final id = section['id'];
    final summary = section['summary'];

    return id == 'analysis' &&
        summary is String &&
        summary.contains("doesn't match the Dart formatter");
  }
}
