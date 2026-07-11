import 'dart:convert';

import 'package:test/test.dart';

import '../src/release_planner.dart';

void main() {
  group('BumpLevel', () {
    test('parse accepts patch, minor, major', () {
      expect(BumpLevel.parse('patch'), BumpLevel.patch);
      expect(BumpLevel.parse('minor'), BumpLevel.minor);
      expect(BumpLevel.parse('major'), BumpLevel.major);
    });

    test('parse throws on invalid value', () {
      expect(() => BumpLevel.parse('huge'), throwsFormatException);
    });

    test('max returns highest bump', () {
      expect(
        BumpLevel.max([BumpLevel.patch, BumpLevel.minor]),
        BumpLevel.minor,
      );
      expect(
        BumpLevel.max([BumpLevel.patch, BumpLevel.major]),
        BumpLevel.major,
      );
      expect(
        BumpLevel.max([BumpLevel.minor, BumpLevel.patch, BumpLevel.major]),
        BumpLevel.major,
      );
    });

    test('max throws on empty list', () {
      expect(() => BumpLevel.max([]), throwsStateError);
    });
  });

  group('Changeset', () {
    test('parses valid changeset with front matter and notes', () {
      const content = '''
---
explicit_outcome: minor
explicit: patch
---

- Add typed outcome API improvements.
''';
      final changeset = Changeset.parse(content);
      expect(changeset.bumps, {
        'explicit_outcome': BumpLevel.minor,
        'explicit': BumpLevel.patch,
      });
      expect(
        changeset.notes,
        contains('Add typed outcome API improvements.'),
      );
    });

    test('parses changeset with single package', () {
      const content = '''
---
explicit_outcome: patch
---

- Fix edge case in outcome mapping.
''';
      final changeset = Changeset.parse(content);
      expect(changeset.bumps, {'explicit_outcome': BumpLevel.patch});
      expect(
        changeset.notes,
        contains('Fix edge case in outcome mapping.'),
      );
    });

    test('throws on missing front matter', () {
      const content = 'No front matter here.';
      expect(() => Changeset.parse(content), throwsFormatException);
    });

    test('throws on empty front matter', () {
      const content = '''
---
---

Some notes.
''';
      expect(() => Changeset.parse(content), throwsFormatException);
    });

    test('throws on invalid bump level', () {
      const content = '''
---
explicit_outcome: huge
---

Notes.
''';
      expect(() => Changeset.parse(content), throwsFormatException);
    });

    test('handles multiline notes', () {
      const content = '''
---
explicit: minor
---

- First change.
- Second change.
- Third change.
''';
      final changeset = Changeset.parse(content);
      expect(changeset.notes, contains('First change.'));
      expect(changeset.notes, contains('Second change.'));
      expect(changeset.notes, contains('Third change.'));
    });
  });

  group('PublishableClassifier', () {
    test('lib files are publishable', () {
      expect(
        PublishableClassifier.isPublishable(
          'packages/explicit_outcome/lib/src/option/opt.dart',
        ),
        isTrue,
      );
      expect(
        PublishableClassifier.isPublishable('packages/explicit/lib/main.dart'),
        isTrue,
      );
    });

    test('package pubspec.yaml is publishable', () {
      expect(
        PublishableClassifier.isPublishable(
          'packages/explicit_outcome/pubspec.yaml',
        ),
        isTrue,
      );
      expect(
        PublishableClassifier.isPublishable('packages/explicit/pubspec.yaml'),
        isTrue,
      );
    });

    test('public example files are publishable', () {
      expect(
        PublishableClassifier.isPublishable(
          'packages/explicit/example/main.dart',
        ),
        isTrue,
      );
    });

    test('test files are not publishable', () {
      expect(
        PublishableClassifier.isPublishable(
          'packages/explicit/test/src/some_test.dart',
        ),
        isFalse,
      );
      expect(
        PublishableClassifier.isPublishable(
          'packages/explicit_outcome/test/outcome_test.dart',
        ),
        isFalse,
      );
    });

    test('docs are not publishable', () {
      expect(
        PublishableClassifier.isPublishable('docs/setup.md'),
        isFalse,
      );
      expect(
        PublishableClassifier.isPublishable('packages/explicit/README.md'),
        isFalse,
      );
    });

    test('tool files are not publishable', () {
      expect(
        PublishableClassifier.isPublishable('tool/quality_gate.dart'),
        isFalse,
      );
    });

    test('workflow files are not publishable', () {
      expect(
        PublishableClassifier.isPublishable('.github/workflows/ci.yaml'),
        isFalse,
      );
    });

    test('root config files are not publishable', () {
      expect(
        PublishableClassifier.isPublishable('pubspec.yaml'),
        isFalse,
      );
      expect(
        PublishableClassifier.isPublishable('analysis_options.yaml'),
        isFalse,
      );
    });

    test('changeset files are not publishable', () {
      expect(
        PublishableClassifier.isPublishable('.changesets/my-change.md'),
        isFalse,
      );
    });

    test('detects package name from publishable path', () {
      expect(
        PublishableClassifier.packageName(
          'packages/explicit_outcome/lib/src/option/opt.dart',
        ),
        'explicit_outcome',
      );
      expect(
        PublishableClassifier.packageName(
          'packages/explicit/lib/main.dart',
        ),
        'explicit',
      );
    });

    test('packageName returns null for non-package paths', () {
      expect(PublishableClassifier.packageName('tool/foo.dart'), isNull);
      expect(PublishableClassifier.packageName('docs/bar.md'), isNull);
    });

    test('findPublishablePackages returns unique package names', () {
      final files = [
        'packages/explicit_outcome/lib/src/a.dart',
        'packages/explicit_outcome/lib/src/b.dart',
        'packages/explicit/lib/main.dart',
        'tool/foo.dart',
        'docs/bar.md',
      ];
      final packages = PublishableClassifier.findPublishablePackages(files);
      expect(packages, containsAll(['explicit_outcome', 'explicit']));
      expect(packages, hasLength(2));
    });

    test('findPublishablePackages returns empty for non-publishable files', () {
      final files = [
        'tool/foo.dart',
        'docs/bar.md',
        '.github/workflows/ci.yaml',
      ];
      final packages = PublishableClassifier.findPublishablePackages(files);
      expect(packages, isEmpty);
    });
  });

  group('ReleasePlanner', () {
    group('plan', () {
      test('returns candidates from changesets only', () {
        final changesets = [
          const Changeset(
            bumps: {'explicit_outcome': BumpLevel.minor},
            notes: '- Add outcome map.',
          ),
        ];
        final plan = ReleasePlanner.plan(changesets);
        expect(plan.candidates, hasLength(1));
        expect(plan.candidates.first.packageName, 'explicit_outcome');
        expect(plan.candidates.first.bump, BumpLevel.minor);
      });

      test('no changeset means no candidate', () {
        final plan = ReleasePlanner.plan([]);
        expect(plan.candidates, isEmpty);
      });

      test('merges bumps across changesets taking max', () {
        final changesets = [
          const Changeset(
            bumps: {'explicit_outcome': BumpLevel.patch},
            notes: '- Fix bug.',
          ),
          const Changeset(
            bumps: {'explicit_outcome': BumpLevel.minor},
            notes: '- Add feature.',
          ),
        ];
        final plan = ReleasePlanner.plan(changesets);
        expect(plan.candidates, hasLength(1));
        expect(plan.candidates.first.bump, BumpLevel.minor);
      });

      test('ordering keeps explicit_outcome before explicit', () {
        final changesets = [
          const Changeset(
            bumps: {
              'explicit': BumpLevel.patch,
              'explicit_outcome': BumpLevel.minor,
            },
            notes: '- Both changed.',
          ),
        ];
        final plan = ReleasePlanner.plan(changesets);
        expect(plan.candidates, hasLength(2));
        expect(plan.candidates[0].packageName, 'explicit_outcome');
        expect(plan.candidates[1].packageName, 'explicit');
      });

      test('dependency propagation: both selected bumps explicit dep', () {
        final changesets = [
          const Changeset(
            bumps: {
              'explicit_outcome': BumpLevel.minor,
              'explicit': BumpLevel.patch,
            },
            notes: '- Both released.',
          ),
        ];
        final plan = ReleasePlanner.plan(changesets);
        expect(plan.dependencyUpdates, hasLength(1));
        expect(plan.dependencyUpdates.first.packageName, 'explicit');
        expect(
          plan.dependencyUpdates.first.dependencyName,
          'explicit_outcome',
        );
      });

      test(
        'dependency propagation: only explicit_outcome selected '
        'does not release explicit',
        () {
          final changesets = [
            const Changeset(
              bumps: {'explicit_outcome': BumpLevel.minor},
              notes: '- Only outcome.',
            ),
          ];
          final plan = ReleasePlanner.plan(changesets);
          expect(plan.candidates, hasLength(1));
          expect(plan.candidates.first.packageName, 'explicit_outcome');
          expect(plan.dependencyUpdates, isEmpty);
        },
      );

      test('collects notes from all changesets per package', () {
        final changesets = [
          const Changeset(
            bumps: {'explicit_outcome': BumpLevel.patch},
            notes: '- Fix A.',
          ),
          const Changeset(
            bumps: {'explicit_outcome': BumpLevel.minor},
            notes: '- Add B.',
          ),
        ];
        final plan = ReleasePlanner.plan(changesets);
        expect(plan.candidates.first.notes, contains('- Fix A.'));
        expect(plan.candidates.first.notes, contains('- Add B.'));
      });
    });

    group('check', () {
      test('passes when publishable changes have matching changeset', () {
        final changedFiles = [
          'packages/explicit_outcome/lib/src/option/opt.dart',
        ];
        final changesets = [
          const Changeset(
            bumps: {'explicit_outcome': BumpLevel.minor},
            notes: '- Add option.',
          ),
        ];
        final result = ReleasePlanner.check(
          changedFiles: changedFiles,
          changesets: changesets,
        );
        expect(result.passed, isTrue);
        expect(result.missingPackages, isEmpty);
      });

      test('fails when publishable change has no changeset', () {
        final changedFiles = [
          'packages/explicit_outcome/lib/src/option/opt.dart',
        ];
        final result = ReleasePlanner.check(
          changedFiles: changedFiles,
          changesets: [],
        );
        expect(result.passed, isFalse);
        expect(result.missingPackages, contains('explicit_outcome'));
      });

      test('fails with remediation message', () {
        final changedFiles = [
          'packages/explicit/lib/src/utils.dart',
        ];
        final result = ReleasePlanner.check(
          changedFiles: changedFiles,
          changesets: [],
        );
        expect(result.passed, isFalse);
        expect(result.remediation, isNotEmpty);
        expect(result.remediation, contains('explicit'));
      });

      test('passes when only non-publishable files changed', () {
        final changedFiles = [
          'tool/quality_gate.dart',
          'docs/setup.md',
          '.github/workflows/ci.yaml',
        ];
        final result = ReleasePlanner.check(
          changedFiles: changedFiles,
          changesets: [],
        );
        expect(result.passed, isTrue);
      });

      test('passes when changeset covers one of two changed packages', () {
        final changedFiles = [
          'packages/explicit_outcome/lib/src/a.dart',
        ];
        final changesets = [
          const Changeset(
            bumps: {'explicit_outcome': BumpLevel.patch},
            notes: '- Fix.',
          ),
        ];
        final result = ReleasePlanner.check(
          changedFiles: changedFiles,
          changesets: changesets,
        );
        expect(result.passed, isTrue);
      });

      test('fails when one package covered and one not', () {
        final changedFiles = [
          'packages/explicit_outcome/lib/src/a.dart',
          'packages/explicit/lib/src/b.dart',
        ];
        final changesets = [
          const Changeset(
            bumps: {'explicit_outcome': BumpLevel.patch},
            notes: '- Fix.',
          ),
        ];
        final result = ReleasePlanner.check(
          changedFiles: changedFiles,
          changesets: changesets,
        );
        expect(result.passed, isFalse);
        expect(result.missingPackages, contains('explicit'));
        expect(
          result.missingPackages,
          isNot(contains('explicit_outcome')),
        );
      });
    });
  });

  group('ReleasePlan rendering', () {
    test('renderMarkdown includes candidates and bumps', () {
      final changesets = [
        const Changeset(
          bumps: {
            'explicit_outcome': BumpLevel.minor,
            'explicit': BumpLevel.patch,
          },
          notes: '- Changes.',
        ),
      ];
      final plan = ReleasePlanner.plan(changesets);
      final md = plan.renderMarkdown();
      expect(md, contains('explicit_outcome'));
      expect(md, contains('minor'));
      expect(md, contains('explicit'));
      expect(md, contains('patch'));
    });

    test('renderMarkdown shows no candidates when plan is empty', () {
      final plan = ReleasePlanner.plan([]);
      final md = plan.renderMarkdown();
      expect(md, contains('No release candidates'));
    });

    test('renderJson produces valid JSON structure', () {
      final changesets = [
        const Changeset(
          bumps: {'explicit_outcome': BumpLevel.minor},
          notes: '- Add feature.',
        ),
      ];
      final plan = ReleasePlanner.plan(changesets);
      final json = plan.renderJson();
      expect(json, contains('"candidates"'));
      expect(json, contains('"explicit_outcome"'));
      expect(json, contains('"minor"'));
    });

    test('renderMarkdown includes handoff state for publishing', () {
      final changesets = [
        const Changeset(
          bumps: {'explicit_outcome': BumpLevel.minor},
          notes: '- Feature.',
        ),
      ];
      final plan = ReleasePlanner.plan(changesets);
      final md = plan.renderMarkdown();
      expect(md, contains('publish'));
    });

    test('renderMarkdown includes future tag names', () {
      final changesets = [
        const Changeset(
          bumps: {'explicit_outcome': BumpLevel.minor},
          notes: '- Feature.',
        ),
      ];
      final plan = ReleasePlanner.plan(changesets);
      final md = plan.renderMarkdown();
      expect(md, contains('explicit_outcome'));
    });
  });

  group('ReleaseProvenance', () {
    test('toJson produces deterministic JSON with all fields', () {
      const provenance = ReleaseProvenance(
        packageName: 'explicit_outcome',
        version: '0.1.0',
        bump: 'minor',
        changesetHashes: ['abc123', 'def456'],
        changelogNotesHash: 'hash789',
      );
      final json = provenance.toJson();
      final decoded = jsonDecode(json) as Map<String, dynamic>;
      expect(decoded['package'], 'explicit_outcome');
      expect(decoded['version'], '0.1.0');
      expect(decoded['bump'], 'minor');
      expect(decoded['changesetHashes'], ['abc123', 'def456']);
      expect(decoded['changelogNotesHash'], 'hash789');
    });

    test('fromJson parses valid provenance manifest', () {
      const jsonStr = '''
{
  "package": "explicit",
  "version": "0.0.2",
  "bump": "patch",
  "changesetHashes": ["aaa"],
  "changelogNotesHash": "bbb"
}
''';
      final provenance = ReleaseProvenance.fromJson(jsonStr);
      expect(provenance.packageName, 'explicit');
      expect(provenance.version, '0.0.2');
      expect(provenance.bump, 'patch');
      expect(provenance.changesetHashes, ['aaa']);
      expect(provenance.changelogNotesHash, 'bbb');
    });

    test('fromJson throws on malformed JSON', () {
      expect(
        () => ReleaseProvenance.fromJson('not json'),
        throwsFormatException,
      );
    });

    test('fromJson throws on missing required fields', () {
      const incomplete = '{"package": "explicit"}';
      expect(
        () => ReleaseProvenance.fromJson(incomplete),
        throwsFormatException,
      );
    });

    test('toJson roundtrip preserves all fields', () {
      const original = ReleaseProvenance(
        packageName: 'explicit_outcome',
        version: '1.0.0',
        bump: 'major',
        changesetHashes: ['h1', 'h2'],
        changelogNotesHash: 'notes_hash',
      );
      final restored = ReleaseProvenance.fromJson(original.toJson());
      expect(restored.packageName, original.packageName);
      expect(restored.version, original.version);
      expect(restored.bump, original.bump);
      expect(restored.changesetHashes, original.changesetHashes);
      expect(restored.changelogNotesHash, original.changelogNotesHash);
    });

    test('computeContentHash produces deterministic hash', () {
      final hash1 = ReleaseProvenance.computeContentHash('hello world');
      final hash2 = ReleaseProvenance.computeContentHash('hello world');
      expect(hash1, hash2);
      expect(hash1, isNotEmpty);
    });

    test('computeContentHash differs for different inputs', () {
      final hash1 = ReleaseProvenance.computeContentHash('input A');
      final hash2 = ReleaseProvenance.computeContentHash('input B');
      expect(hash1, isNot(hash2));
    });
  });

  group('TagParser', () {
    test('parses valid explicit_outcome tag', () {
      final result = TagParser.parse('explicit_outcome/v1.2.3');
      expect(result.packageName, 'explicit_outcome');
      expect(result.version, '1.2.3');
    });

    test('parses valid explicit tag', () {
      final result = TagParser.parse('explicit/v0.4.0');
      expect(result.packageName, 'explicit');
      expect(result.version, '0.4.0');
    });

    test('rejects unknown package name', () {
      expect(
        () => TagParser.parse('unknown_pkg/v1.0.0'),
        throwsFormatException,
      );
    });

    test('rejects malformed semver (two parts)', () {
      expect(
        () => TagParser.parse('explicit/v1.0'),
        throwsFormatException,
      );
    });

    test('rejects malformed semver (non-numeric)', () {
      expect(
        () => TagParser.parse('explicit/v1.abc.3'),
        throwsFormatException,
      );
    });

    test('rejects tag without v prefix', () {
      expect(
        () => TagParser.parse('explicit/1.0.0'),
        throwsFormatException,
      );
    });

    test('rejects tag without slash separator', () {
      expect(
        () => TagParser.parse('explicit_v1.0.0'),
        throwsFormatException,
      );
    });

    test('rejects empty tag', () {
      expect(() => TagParser.parse(''), throwsFormatException);
    });

    test('parses tag with pre-release suffix', () {
      final result = TagParser.parse('explicit_outcome/v1.0.0-dev.1');
      expect(result.packageName, 'explicit_outcome');
      expect(result.version, '1.0.0-dev.1');
    });
  });

  group('ReleaseValidator.validateRelease', () {
    test('passes when tag, pubspec, changelog, provenance all agree', () {
      const pubspec = '''
name: explicit_outcome
version: 0.1.0
description: Test.
''';
      const changelog = '''
# Changelog

## 0.1.0 (2026-07-09)

- Add feature.

## 0.0.1

- Initial release.
''';
      const provenanceJson = '''
{
  "package": "explicit_outcome",
  "version": "0.1.0",
  "bump": "minor",
  "changesetHashes": ["abc"],
  "changelogNotesHash": "def"
}
''';
      final result = ReleaseValidator.validateRelease(
        tag: 'explicit_outcome/v0.1.0',
        pubspecContent: pubspec,
        changelogContent: changelog,
        provenanceJson: provenanceJson,
      );
      expect(result.isValid, isTrue);
      expect(result.errors, isEmpty);
      expect(result.packageName, 'explicit_outcome');
      expect(result.version, '0.1.0');
    });

    test('fails closed when provenance is absent', () {
      const pubspec = '''
name: explicit_outcome
version: 0.1.0
description: Test.
''';
      const changelog = '''
# Changelog

## 0.1.0 (2026-07-09)

- Feature.
''';
      final result = ReleaseValidator.validateRelease(
        tag: 'explicit_outcome/v0.1.0',
        pubspecContent: pubspec,
        changelogContent: changelog,
        provenanceJson: null,
      );
      expect(result.isValid, isFalse);
      expect(result.errors, isNotEmpty);
      expect(
        result.errors.any((e) => e.contains('provenance')),
        isTrue,
      );
    });

    test('fails closed when provenance is malformed', () {
      final result = ReleaseValidator.validateRelease(
        tag: 'explicit_outcome/v0.1.0',
        pubspecContent: 'name: explicit_outcome\nversion: 0.1.0\n',
        changelogContent: '# Changelog\n\n## 0.1.0\n\n- Note.\n',
        provenanceJson: 'not json at all',
      );
      expect(result.isValid, isFalse);
      expect(
        result.errors.any((e) => e.contains('provenance')),
        isTrue,
      );
    });

    test('fails when tag version disagrees with pubspec', () {
      const pubspec = '''
name: explicit_outcome
version: 0.2.0
description: Test.
''';
      const changelog = '''
# Changelog

## 0.2.0 (2026-07-09)

- Feature.
''';
      const provenanceJson = '''
{
  "package": "explicit_outcome",
  "version": "0.2.0",
  "bump": "minor",
  "changesetHashes": ["abc"],
  "changelogNotesHash": "def"
}
''';
      final result = ReleaseValidator.validateRelease(
        tag: 'explicit_outcome/v0.1.0',
        pubspecContent: pubspec,
        changelogContent: changelog,
        provenanceJson: provenanceJson,
      );
      expect(result.isValid, isFalse);
      expect(
        result.errors.any((e) => e.contains('version')),
        isTrue,
      );
    });

    test('fails when provenance version disagrees with tag', () {
      const pubspec = '''
name: explicit_outcome
version: 0.1.0
description: Test.
''';
      const changelog = '''
# Changelog

## 0.1.0 (2026-07-09)

- Feature.
''';
      const provenanceJson = '''
{
  "package": "explicit_outcome",
  "version": "0.9.9",
  "bump": "minor",
  "changesetHashes": ["abc"],
  "changelogNotesHash": "def"
}
''';
      final result = ReleaseValidator.validateRelease(
        tag: 'explicit_outcome/v0.1.0',
        pubspecContent: pubspec,
        changelogContent: changelog,
        provenanceJson: provenanceJson,
      );
      expect(result.isValid, isFalse);
    });

    test('fails when changelog heading missing for version', () {
      const pubspec = '''
name: explicit_outcome
version: 0.1.0
description: Test.
''';
      const changelog = '''
# Changelog

## 0.0.1

- Initial release.
''';
      const provenanceJson = '''
{
  "package": "explicit_outcome",
  "version": "0.1.0",
  "bump": "minor",
  "changesetHashes": ["abc"],
  "changelogNotesHash": "def"
}
''';
      final result = ReleaseValidator.validateRelease(
        tag: 'explicit_outcome/v0.1.0',
        pubspecContent: pubspec,
        changelogContent: changelog,
        provenanceJson: provenanceJson,
      );
      expect(result.isValid, isFalse);
      expect(
        result.errors.any((e) => e.contains('changelog')),
        isTrue,
      );
    });

    test(
      'validateRelease runs dependency preflight for explicit package '
      'and fails when explicit_outcome version is missing',
      () {
        const explicitPubspec = '''
name: explicit
version: 0.0.2
description: Test.
dependencies:
  explicit_outcome: ^0.2.0
''';
        const changelog = '''
# Changelog

## 0.0.2 (2026-07-09)

- Feature.
''';
        const provenanceJson = '''
{
  "package": "explicit",
  "version": "0.0.2",
  "bump": "patch",
  "changesetHashes": ["abc"],
  "changelogNotesHash": "def"
}
''';
        final result = ReleaseValidator.validateRelease(
          tag: 'explicit/v0.0.2',
          pubspecContent: explicitPubspec,
          changelogContent: changelog,
          provenanceJson: provenanceJson,
          metadataFetcher: (_) => const PubDevMetadata(
            packageName: 'explicit_outcome',
            versions: ['0.0.1', '0.1.0'],
          ),
        );
        expect(result.isValid, isFalse);
        expect(
          result.errors.any((e) => e.contains('explicit_outcome')),
          isTrue,
          reason: 'Preflight should block when required dep version missing',
        );
      },
    );

    test(
      'validateRelease passes preflight when explicit_outcome version '
      'is available',
      () {
        const explicitPubspec = '''
name: explicit
version: 0.0.2
description: Test.
dependencies:
  explicit_outcome: ^0.1.0
''';
        const changelog = '''
# Changelog

## 0.0.2 (2026-07-09)

- Feature.
''';
        const provenanceJson = '''
{
  "package": "explicit",
  "version": "0.0.2",
  "bump": "patch",
  "changesetHashes": ["abc"],
  "changelogNotesHash": "def"
}
''';
        final result = ReleaseValidator.validateRelease(
          tag: 'explicit/v0.0.2',
          pubspecContent: explicitPubspec,
          changelogContent: changelog,
          provenanceJson: provenanceJson,
          metadataFetcher: (_) => const PubDevMetadata(
            packageName: 'explicit_outcome',
            versions: ['0.0.1', '0.1.0'],
          ),
        );
        expect(result.isValid, isTrue);
        expect(result.errors, isEmpty);
      },
    );

    test(
      'validateRelease fails closed on preflight metadata error',
      () {
        const explicitPubspec = '''
name: explicit
version: 0.0.2
description: Test.
dependencies:
  explicit_outcome: ^0.1.0
''';
        const changelog = '''
# Changelog

## 0.0.2 (2026-07-09)

- Feature.
''';
        const provenanceJson = '''
{
  "package": "explicit",
  "version": "0.0.2",
  "bump": "patch",
  "changesetHashes": ["abc"],
  "changelogNotesHash": "def"
}
''';
        final result = ReleaseValidator.validateRelease(
          tag: 'explicit/v0.0.2',
          pubspecContent: explicitPubspec,
          changelogContent: changelog,
          provenanceJson: provenanceJson,
          metadataFetcher: (_) {
            throw Exception('Network timeout');
          },
        );
        expect(result.isValid, isFalse);
        expect(
          result.errors.any((e) => e.contains('metadata')),
          isTrue,
        );
      },
    );

    test(
      'validateRelease skips preflight for explicit_outcome package',
      () {
        const pubspec = '''
name: explicit_outcome
version: 0.1.0
description: Test.
''';
        const changelog = '''
# Changelog

## 0.1.0 (2026-07-09)

- Feature.
''';
        const provenanceJson = '''
{
  "package": "explicit_outcome",
  "version": "0.1.0",
  "bump": "minor",
  "changesetHashes": ["abc"],
  "changelogNotesHash": "def"
}
''';
        // metadataFetcher should never be called for explicit_outcome.
        var fetcherCalled = false;
        final result = ReleaseValidator.validateRelease(
          tag: 'explicit_outcome/v0.1.0',
          pubspecContent: pubspec,
          changelogContent: changelog,
          provenanceJson: provenanceJson,
          metadataFetcher: (_) {
            fetcherCalled = true;
            throw Exception('Should not be called');
          },
        );
        expect(result.isValid, isTrue);
        expect(fetcherCalled, isFalse);
      },
    );

    test(
      'validateRelease detects major from provenance bump field',
      () {
        const pubspec = '''
name: explicit_outcome
version: 1.0.0
description: Test.
''';
        const changelog = '''
# Changelog

## 1.0.0 (2026-07-09)

- Breaking change.
''';
        const provenanceJson = '''
{
  "package": "explicit_outcome",
  "version": "1.0.0",
  "bump": "major",
  "changesetHashes": ["abc"],
  "changelogNotesHash": "def"
}
''';
        final result = ReleaseValidator.validateRelease(
          tag: 'explicit_outcome/v1.0.0',
          pubspecContent: pubspec,
          changelogContent: changelog,
          provenanceJson: provenanceJson,
        );
        expect(result.isValid, isTrue);
        expect(result.isMajor, isTrue);
      },
    );

    test(
      'validateRelease non-major when provenance bump is minor',
      () {
        const pubspec = '''
name: explicit_outcome
version: 0.2.0
description: Test.
''';
        const changelog = '''
# Changelog

## 0.2.0 (2026-07-09)

- Feature.
''';
        const provenanceJson = '''
{
  "package": "explicit_outcome",
  "version": "0.2.0",
  "bump": "minor",
  "changesetHashes": ["abc"],
  "changelogNotesHash": "def"
}
''';
        final result = ReleaseValidator.validateRelease(
          tag: 'explicit_outcome/v0.2.0',
          pubspecContent: pubspec,
          changelogContent: changelog,
          provenanceJson: provenanceJson,
        );
        expect(result.isValid, isTrue);
        expect(result.isMajor, isFalse);
      },
    );
  });

  group('MajorDetector', () {
    test('detects major when provenance bump is major', () {
      final isMajor = MajorDetector.isMajorRelease(
        tagVersion: '1.0.0',
        pubspecContent: 'name: explicit_outcome\nversion: 1.0.0\n',
        provenanceBump: 'major',
      );
      expect(isMajor, isTrue);
    });

    test('non-major when provenance bump is minor', () {
      final isMajor = MajorDetector.isMajorRelease(
        tagVersion: '0.2.0',
        pubspecContent: 'name: explicit_outcome\nversion: 0.2.0\n',
        provenanceBump: 'minor',
      );
      expect(isMajor, isFalse);
    });

    test('non-major when provenance bump is patch', () {
      final isMajor = MajorDetector.isMajorRelease(
        tagVersion: '0.1.1',
        pubspecContent: 'name: explicit_outcome\nversion: 0.1.1\n',
        provenanceBump: 'patch',
      );
      expect(isMajor, isFalse);
    });

    test('detects major from 0.x to 1.0.0 via provenance', () {
      final isMajor = MajorDetector.isMajorRelease(
        tagVersion: '1.0.0',
        pubspecContent: 'name: explicit\nversion: 1.0.0\n',
        provenanceBump: 'major',
      );
      expect(isMajor, isTrue);
    });

    test('detects major from 1.x to 2.0.0 via provenance', () {
      final isMajor = MajorDetector.isMajorRelease(
        tagVersion: '2.0.0',
        pubspecContent: 'name: explicit\nversion: 2.0.0\n',
        provenanceBump: 'major',
      );
      expect(isMajor, isTrue);
    });

    test('falls back to tag/pubspec comparison when no provenance', () {
      // Legacy fallback: when provenance bump is not available,
      // compare tag major to pubspec major.
      final isMajor = MajorDetector.isMajorRelease(
        tagVersion: '1.0.0',
        pubspecContent: 'name: explicit_outcome\nversion: 0.1.0\n',
      );
      expect(isMajor, isTrue);
    });

    test('non-major fallback when tag and pubspec majors agree', () {
      final isMajor = MajorDetector.isMajorRelease(
        tagVersion: '1.2.3',
        pubspecContent: 'name: explicit_outcome\nversion: 1.0.0\n',
      );
      expect(isMajor, isFalse);
    });
  });

  group('DependencyPreflight', () {
    test(
      'passes when required explicit_outcome version exists in metadata',
      () {
        const explicitPubspec = '''
name: explicit
version: 0.0.2
dependencies:
  explicit_outcome: ^0.1.0
''';
        // Simulate pub.dev metadata with version 0.1.0 available.
        const metadata = PubDevMetadata(
          packageName: 'explicit_outcome',
          versions: ['0.0.1', '0.1.0'],
        );
        final result = DependencyPreflight.check(
          explicitPubspecContent: explicitPubspec,
          metadataFetcher: (_) => metadata,
        );
        expect(result.isSatisfied, isTrue);
        expect(result.errors, isEmpty);
      },
    );

    test(
      'fails when required explicit_outcome version absent from metadata',
      () {
        const explicitPubspec = '''
name: explicit
version: 0.0.2
dependencies:
  explicit_outcome: ^0.2.0
''';
        const metadata = PubDevMetadata(
          packageName: 'explicit_outcome',
          versions: ['0.0.1', '0.1.0'],
        );
        final result = DependencyPreflight.check(
          explicitPubspecContent: explicitPubspec,
          metadataFetcher: (_) => metadata,
        );
        expect(result.isSatisfied, isFalse);
        expect(result.errors, isNotEmpty);
        expect(
          result.errors.any((e) => e.contains('explicit_outcome')),
          isTrue,
        );
      },
    );

    test('fails closed on metadata fetch error', () {
      const explicitPubspec = '''
name: explicit
version: 0.0.2
dependencies:
  explicit_outcome: ^0.1.0
''';
      final result = DependencyPreflight.check(
        explicitPubspecContent: explicitPubspec,
        metadataFetcher: (_) {
          throw Exception('Network error');
        },
      );
      expect(result.isSatisfied, isFalse);
      expect(
        result.errors.any((e) => e.contains('metadata')),
        isTrue,
      );
    });

    test('skips preflight when explicit has no explicit_outcome dep', () {
      const explicitPubspec = '''
name: explicit
version: 0.0.2
dependencies:
  meta: ^1.18.3
''';
      final result = DependencyPreflight.check(
        explicitPubspecContent: explicitPubspec,
        metadataFetcher: (_) {
          throw Exception('Should not be called');
        },
      );
      expect(result.isSatisfied, isTrue);
      expect(result.errors, isEmpty);
    });

    test('passes with injected fixture metadata satisfying constraint', () {
      const explicitPubspec = '''
name: explicit
version: 0.0.2
dependencies:
  explicit_outcome: ^0.1.0
''';
      const fixture = PubDevMetadata(
        packageName: 'explicit_outcome',
        versions: ['0.1.0', '0.1.1', '0.2.0'],
      );
      final result = DependencyPreflight.check(
        explicitPubspecContent: explicitPubspec,
        metadataFetcher: (_) => fixture,
      );
      expect(result.isSatisfied, isTrue);
    });
  });
}
