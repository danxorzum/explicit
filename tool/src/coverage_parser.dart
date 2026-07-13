/// Result of parsing an lcov.info file.
class CoverageResult {
  const CoverageResult({required this.linesFound, required this.linesHit});

  /// Total lines of instrumentable code found.
  final int linesFound;

  /// Lines that were executed at least once.
  final int linesHit;

  /// Coverage percentage (0.0 - 100.0).
  double get coveragePercent {
    if (linesFound == 0) return 100;
    return (linesHit / linesFound) * 100;
  }

  /// True when coverage is 100% (or no lines to cover).
  bool get isFullCoverage => linesHit == linesFound;
}

/// Parses lcov.info content into a [CoverageResult].
class CoverageParser {
  /// Parses lcov content and returns aggregated coverage stats.
  ///
  /// Reads LF (lines found) and LH (lines hit) from each record
  /// and aggregates across all source files.
  static CoverageResult parseLcov(String content) {
    if (content.trim().isEmpty) {
      return const CoverageResult(linesFound: 0, linesHit: 0);
    }

    var totalFound = 0;
    var totalHit = 0;

    for (final line in content.split('\n')) {
      if (line.startsWith('LF:')) {
        totalFound += int.tryParse(line.substring(3)) ?? 0;
      } else if (line.startsWith('LH:')) {
        totalHit += int.tryParse(line.substring(3)) ?? 0;
      }
    }

    return CoverageResult(linesFound: totalFound, linesHit: totalHit);
  }
}
