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

    test('renderMarkdown describes manual tag publishing boundary', () {
      final changesets = [
        const Changeset(
          bumps: {'explicit_outcome': BumpLevel.minor},
          notes: '- Feature.',
        ),
      ];
      final plan = ReleasePlanner.plan(changesets);
      final md = plan.renderMarkdown();
      expect(
        md,
        contains('Version PR merge prepares validated release provenance'),
      );
      expect(
        md,
        contains('Tags then trigger OIDC publishing via publish.yaml'),
      );
      expect(md, contains('maintainer manually creates release tags'));
      expect(
        md,
        isNot(
          contains(
            'hand'
            'off',
          ),
        ),
      );
    });

    test('renderMarkdown includes post-merge tag names', () {
      final changesets = [
        const Changeset(
          bumps: {'explicit_outcome': BumpLevel.minor},
          notes: '- Feature.',
        ),
      ];
      final plan = ReleasePlanner.plan(changesets);
      final md = plan.renderMarkdown();
      expect(md, contains('### Post-Merge Tag Names'));
      expect(md, contains('explicit_outcome/v<next-version>'));
      expect(
        md,
        isNot(
          contains(
            'Future'
            ' Tag'
            ' Names',
          ),
        ),
      );
    });

    test('renderJson describes manual tag and publish flow', () {
      final changesets = [
        const Changeset(
          bumps: {'explicit_outcome': BumpLevel.minor},
          notes: '- Feature.',
        ),
      ];
      final plan = ReleasePlanner.plan(changesets);
      final decoded = jsonDecode(plan.renderJson()) as Map<String, dynamic>;
      expect(
        decoded['publishFlow'],
        'version PR merge prepares validated provenance; maintainer manually '
        'creates tags; tags trigger OIDC publishing via publish.yaml',
      );
      expect(
        decoded.containsKey(
          'publish'
          'Hand'
          'off',
        ),
        isFalse,
      );
    });
  });

  group('ReleaseProvenance', () {
    test('toJson produces deterministic JSON with all fields', () {
      const provenance = ReleaseProvenance(
        packageName: 'explicit_outcome',
        version: '0.1.0',
        previousVersion: '0.0.1',
        nextVersion: '0.1.0',
        bump: 'minor',
        changesetHashes: ['abc123', 'def456'],
        changelogNotesHash: 'hash789',
        tag: 'explicit_outcome/v0.1.0',
      );
      final json = provenance.toJson();
      final decoded = jsonDecode(json) as Map<String, dynamic>;
      expect(decoded['package'], 'explicit_outcome');
      expect(decoded['version'], '0.1.0');
      expect(decoded['previousVersion'], '0.0.1');
      expect(decoded['bump'], 'minor');
      expect(decoded['changesetHashes'], ['abc123', 'def456']);
      expect(decoded['impactProof'], isEmpty);
      expect(decoded['changelogNotesHash'], 'hash789');
      expect(decoded['tag'], 'explicit_outcome/v0.1.0');
      expect(
        decoded['provenanceSource'],
        ReleaseProvenance.expectedProvenanceSource,
      );
    });

    test('fromJson parses valid provenance manifest', () {
      const jsonStr = '''
{
  "package": "explicit",
  "version": "0.0.2",
  "previousVersion": "0.0.1",
  "nextVersion": "0.0.2",
  "bump": "patch",
  "changesetHashes": ["aaa"],
  "changelogNotesHash": "bbb",
  "tag": "explicit/v0.0.2",
  "provenanceSource": "release_version_pr.version-pr.v1"
}
''';
      final provenance = ReleaseProvenance.fromJson(jsonStr);
      expect(provenance.packageName, 'explicit');
      expect(provenance.version, '0.0.2');
      expect(provenance.bump, 'patch');
      expect(provenance.changesetHashes, ['aaa']);
      expect(provenance.impactProof, isEmpty);
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
        previousVersion: '0.9.0',
        nextVersion: '1.0.0',
        bump: 'major',
        changesetHashes: ['h1', 'h2'],
        changelogNotesHash: 'notes_hash',
        tag: 'explicit_outcome/v1.0.0',
      );
      final restored = ReleaseProvenance.fromJson(original.toJson());
      expect(restored.packageName, original.packageName);
      expect(restored.version, original.version);
      expect(restored.previousVersion, original.previousVersion);
      expect(restored.nextVersion, original.nextVersion);
      expect(restored.bump, original.bump);
      expect(restored.changesetHashes, original.changesetHashes);
      expect(restored.changelogNotesHash, original.changelogNotesHash);
      expect(restored.tag, original.tag);
      expect(restored.provenanceSource, original.provenanceSource);
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

    // Corrective Slice 2: previousVersion and tag fields.
    test('toJson includes previousVersion and tag fields', () {
      const provenance = ReleaseProvenance(
        packageName: 'explicit_outcome',
        version: '0.1.0',
        previousVersion: '0.0.1',
        nextVersion: '0.1.0',
        bump: 'minor',
        changesetHashes: ['abc123'],
        changelogNotesHash: 'hash789',
        tag: 'explicit_outcome/v0.1.0',
      );
      final json = provenance.toJson();
      final decoded = jsonDecode(json) as Map<String, dynamic>;
      expect(decoded['previousVersion'], '0.0.1');
      expect(decoded['nextVersion'], '0.1.0');
      expect(decoded['tag'], 'explicit_outcome/v0.1.0');
      expect(
        decoded['provenanceSource'],
        ReleaseProvenance.expectedProvenanceSource,
      );
    });

    test('fromJson parses provenance with previousVersion and tag', () {
      const jsonStr = '''
{
  "package": "explicit",
  "version": "0.0.2",
  "previousVersion": "0.0.1",
  "nextVersion": "0.0.2",
  "bump": "patch",
  "changesetHashes": ["aaa"],
  "changelogNotesHash": "bbb",
  "tag": "explicit/v0.0.2",
  "provenanceSource": "release_version_pr.version-pr.v1"
}
''';
      final provenance = ReleaseProvenance.fromJson(jsonStr);
      expect(provenance.previousVersion, '0.0.1');
      expect(provenance.nextVersion, '0.0.2');
      expect(provenance.tag, 'explicit/v0.0.2');
      expect(
        provenance.provenanceSource,
        ReleaseProvenance.expectedProvenanceSource,
      );
    });

    test('fromJson throws when previousVersion is missing', () {
      const jsonStr = '''
{
  "package": "explicit",
  "version": "0.0.2",
  "bump": "patch",
  "changesetHashes": ["aaa"],
  "changelogNotesHash": "bbb",
  "tag": "explicit/v0.0.2"
}
''';
      expect(
        () => ReleaseProvenance.fromJson(jsonStr),
        throwsFormatException,
      );
    });

    test('fromJson throws when tag is missing', () {
      const jsonStr = '''
{
  "package": "explicit",
  "version": "0.0.2",
  "previousVersion": "0.0.1",
  "nextVersion": "0.0.2",
  "bump": "patch",
  "changesetHashes": ["aaa"],
  "changelogNotesHash": "bbb"
}
''';
      expect(
        () => ReleaseProvenance.fromJson(jsonStr),
        throwsFormatException,
      );
    });

    test('toJson roundtrip preserves previousVersion and tag', () {
      const original = ReleaseProvenance(
        packageName: 'explicit_outcome',
        version: '1.0.0',
        previousVersion: '0.9.0',
        nextVersion: '1.0.0',
        bump: 'major',
        changesetHashes: ['h1'],
        changelogNotesHash: 'notes_hash',
        tag: 'explicit_outcome/v1.0.0',
      );
      final restored = ReleaseProvenance.fromJson(original.toJson());
      expect(restored.previousVersion, original.previousVersion);
      expect(restored.nextVersion, original.nextVersion);
      expect(restored.tag, original.tag);
      expect(restored.provenanceSource, original.provenanceSource);
    });

    test('fromJson throws when provenanceSource is missing', () {
      const jsonStr = '''
{
  "package": "explicit",
  "version": "0.0.2",
  "previousVersion": "0.0.1",
  "nextVersion": "0.0.2",
  "bump": "patch",
  "changesetHashes": ["aaa"],
  "changelogNotesHash": "bbb",
  "tag": "explicit/v0.0.2"
}
''';
      expect(
        () => ReleaseProvenance.fromJson(jsonStr),
        throwsFormatException,
      );
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
    String provenanceJson({
      String packageName = 'explicit_outcome',
      String version = '0.1.0',
      String previousVersion = '0.0.1',
      String nextVersion = '0.1.0',
      String bump = 'minor',
      List<String> impactProof = const [
        'packages/explicit_outcome/lib/src/option.dart',
      ],
      String notes = '- Add feature.',
      List<String> changesetContents = const [
        '---\nexplicit_outcome: minor\n---\n\n- Add feature.',
      ],
      String? changelogNotesHash,
      List<String>? changesetHashes,
      String? tag,
    }) {
      final hashes =
          changesetHashes ??
          changesetContents.map(ReleaseProvenance.computeContentHash).toList();
      final data = {
        'package': packageName,
        'version': version,
        'previousVersion': previousVersion,
        'nextVersion': nextVersion,
        'bump': bump,
        'changesetHashes': hashes,
        'changesetContents': changesetContents,
        'impactProof': impactProof,
        'changelogNotesHash':
            changelogNotesHash ?? ReleaseProvenance.computeContentHash(notes),
        'tag': tag ?? '$packageName/v$version',
        'provenanceSource': ReleaseProvenance.expectedProvenanceSource,
      };
      return jsonEncode(data);
    }

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
      final validProvenanceJson = provenanceJson();
      final result = ReleaseValidator.validateRelease(
        tag: 'explicit_outcome/v0.1.0',
        pubspecContent: pubspec,
        changelogContent: changelog,
        provenanceJson: validProvenanceJson,
      );
      expect(result.isValid, isTrue);
      expect(result.errors, isEmpty);
      expect(result.packageName, 'explicit_outcome');
      expect(result.version, '0.1.0');
    });

    test('fails when impactProof is missing', () {
      const pubspec = 'name: explicit_outcome\nversion: 0.1.0\n';
      const changelog = '# Changelog\n\n## 0.1.0\n\n- Add feature.\n';
      final data = jsonDecode(provenanceJson()) as Map<String, dynamic>
        ..remove('impactProof');

      final result = ReleaseValidator.validateRelease(
        tag: 'explicit_outcome/v0.1.0',
        pubspecContent: pubspec,
        changelogContent: changelog,
        provenanceJson: jsonEncode(data),
      );

      expect(result.isValid, isFalse);
      expect(result.errors.any((e) => e.contains('impactProof')), isTrue);
    });

    test(
      'fails when provenance was not generated by the version PR workflow',
      () {
        const pubspec = 'name: explicit_outcome\nversion: 0.1.0\n';
        const changelog = '# Changelog\n\n## 0.1.0\n\n- Add feature.\n';
        final data = jsonDecode(provenanceJson()) as Map<String, dynamic>
          ..['provenanceSource'] = 'manual-tag';

        final result = ReleaseValidator.validateRelease(
          tag: 'explicit_outcome/v0.1.0',
          pubspecContent: pubspec,
          changelogContent: changelog,
          provenanceJson: jsonEncode(data),
        );

        expect(result.isValid, isFalse);
        expect(
          result.errors.any((e) => e.contains('approved version PR source')),
          isTrue,
        );
      },
    );

    test('fails when impactProof is empty', () {
      const pubspec = 'name: explicit_outcome\nversion: 0.1.0\n';
      const changelog = '# Changelog\n\n## 0.1.0\n\n- Add feature.\n';

      final result = ReleaseValidator.validateRelease(
        tag: 'explicit_outcome/v0.1.0',
        pubspecContent: pubspec,
        changelogContent: changelog,
        provenanceJson: provenanceJson(impactProof: const []),
      );

      expect(result.isValid, isFalse);
      expect(result.errors.any((e) => e.contains('impactProof')), isTrue);
    });

    test('fails when impactProof belongs to another package', () {
      const pubspec = 'name: explicit_outcome\nversion: 0.1.0\n';
      const changelog = '# Changelog\n\n## 0.1.0\n\n- Add feature.\n';

      final result = ReleaseValidator.validateRelease(
        tag: 'explicit_outcome/v0.1.0',
        pubspecContent: pubspec,
        changelogContent: changelog,
        provenanceJson: provenanceJson(
          impactProof: const ['packages/explicit/lib/src/explicit.dart'],
        ),
      );

      expect(result.isValid, isFalse);
      expect(result.errors.any((e) => e.contains('impactProof')), isTrue);
    });

    test('fails when changelogNotesHash is stale', () {
      const pubspec = 'name: explicit_outcome\nversion: 0.1.0\n';
      const changelog = '# Changelog\n\n## 0.1.0\n\n- Tampered note.\n';

      final result = ReleaseValidator.validateRelease(
        tag: 'explicit_outcome/v0.1.0',
        pubspecContent: pubspec,
        changelogContent: changelog,
        provenanceJson: provenanceJson(),
      );

      expect(result.isValid, isFalse);
      expect(
        result.errors.any((e) => e.contains('changelogNotesHash')),
        isTrue,
      );
    });

    test('fails when changesetHashes do not match changesetContents', () {
      const pubspec = 'name: explicit_outcome\nversion: 0.1.0\n';
      const changelog = '# Changelog\n\n## 0.1.0\n\n- Add feature.\n';

      final result = ReleaseValidator.validateRelease(
        tag: 'explicit_outcome/v0.1.0',
        pubspecContent: pubspec,
        changelogContent: changelog,
        provenanceJson: provenanceJson(changesetHashes: const ['stale']),
      );

      expect(result.isValid, isFalse);
      expect(result.errors.any((e) => e.contains('changesetHashes')), isTrue);
    });

    test(
      'fails when copied provenance has matching version but wrong proof',
      () {
        const pubspec = 'name: explicit_outcome\nversion: 0.1.0\n';
        const changelog = '# Changelog\n\n## 0.1.0\n\n- Add feature.\n';

        final result = ReleaseValidator.validateRelease(
          tag: 'explicit_outcome/v0.1.0',
          pubspecContent: pubspec,
          changelogContent: changelog,
          provenanceJson: provenanceJson(
            impactProof: const ['packages/explicit/lib/src/explicit.dart'],
            changesetContents: const [
              '---\nexplicit: minor\n---\n\n- Add feature.',
            ],
          ),
        );

        expect(result.isValid, isFalse);
        expect(
          result.errors.any(
            (e) => e.contains('impactProof') || e.contains('changeset'),
          ),
          isTrue,
        );
      },
    );

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
  "previousVersion": "0.1.0",
  "nextVersion": "0.2.0",
  "bump": "minor",
  "changesetHashes": ["abc"],
  "changelogNotesHash": "def",
  "tag": "explicit_outcome/v0.2.0",
  "provenanceSource": "release_version_pr.version-pr.v1"
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
  "previousVersion": "0.9.0",
  "nextVersion": "0.9.9",
  "bump": "minor",
  "changesetHashes": ["abc"],
  "changelogNotesHash": "def",
  "tag": "explicit_outcome/v0.9.9",
  "provenanceSource": "release_version_pr.version-pr.v1"
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
  "previousVersion": "0.0.1",
  "nextVersion": "0.1.0",
  "bump": "minor",
  "changesetHashes": ["abc"],
  "changelogNotesHash": "def",
  "tag": "explicit_outcome/v0.1.0",
  "provenanceSource": "release_version_pr.version-pr.v1"
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
        final validProvenanceJson = provenanceJson(
          packageName: 'explicit',
          version: '0.0.2',
          nextVersion: '0.0.2',
          bump: 'patch',
          impactProof: const ['packages/explicit/lib/src/explicit.dart'],
          notes: '- Feature.',
          changesetContents: const [
            '---\nexplicit: patch\n---\n\n- Feature.',
          ],
        );
        final result = ReleaseValidator.validateRelease(
          tag: 'explicit/v0.0.2',
          pubspecContent: explicitPubspec,
          changelogContent: changelog,
          provenanceJson: validProvenanceJson,
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
        final validProvenanceJson = provenanceJson(
          packageName: 'explicit',
          version: '0.0.2',
          nextVersion: '0.0.2',
          bump: 'patch',
          impactProof: const ['packages/explicit/lib/src/explicit.dart'],
          notes: '- Feature.',
          changesetContents: const [
            '---\nexplicit: patch\n---\n\n- Feature.',
          ],
        );
        final result = ReleaseValidator.validateRelease(
          tag: 'explicit/v0.0.2',
          pubspecContent: explicitPubspec,
          changelogContent: changelog,
          provenanceJson: validProvenanceJson,
          metadataFetcher: (_) => const PubDevMetadata(
            packageName: 'explicit_outcome',
            versions: ['0.0.1', '0.1.0'],
          ),
        );
        expect(result.isValid, isTrue, reason: result.errors.join('\n'));
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
        final result = ReleaseValidator.validateRelease(
          tag: 'explicit/v0.0.2',
          pubspecContent: explicitPubspec,
          changelogContent: changelog,
          provenanceJson: provenanceJson(
            packageName: 'explicit',
            version: '0.0.2',
            nextVersion: '0.0.2',
            bump: 'patch',
            impactProof: const ['packages/explicit/lib/src/explicit.dart'],
            notes: '- Feature.',
            changesetContents: const [
              '---\nexplicit: patch\n---\n\n- Feature.',
            ],
          ),
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
        final validProvenanceJson = provenanceJson(notes: '- Feature.');
        // metadataFetcher should never be called for explicit_outcome.
        var fetcherCalled = false;
        final result = ReleaseValidator.validateRelease(
          tag: 'explicit_outcome/v0.1.0',
          pubspecContent: pubspec,
          changelogContent: changelog,
          provenanceJson: validProvenanceJson,
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
        final validProvenanceJson = provenanceJson(
          version: '1.0.0',
          previousVersion: '0.9.0',
          nextVersion: '1.0.0',
          bump: 'major',
          notes: '- Breaking change.',
          changesetContents: const [
            '---\nexplicit_outcome: major\n---\n\n- Breaking change.',
          ],
        );
        final result = ReleaseValidator.validateRelease(
          tag: 'explicit_outcome/v1.0.0',
          pubspecContent: pubspec,
          changelogContent: changelog,
          provenanceJson: validProvenanceJson,
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
        final validProvenanceJson = provenanceJson(
          version: '0.2.0',
          previousVersion: '0.1.0',
          nextVersion: '0.2.0',
          notes: '- Feature.',
          changesetContents: const [
            '---\nexplicit_outcome: minor\n---\n\n- Feature.',
          ],
        );
        final result = ReleaseValidator.validateRelease(
          tag: 'explicit_outcome/v0.2.0',
          pubspecContent: pubspec,
          changelogContent: changelog,
          provenanceJson: validProvenanceJson,
        );
        expect(result.isValid, isTrue);
        expect(result.isMajor, isFalse);
      },
    );

    // Corrective Slice 2: provenance consistency validation.
    test(
      'fails when provenance previousVersion + bump does not produce version',
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
        // Provenance claims: previousVersion=0.0.1, bump=patch, version=0.1.0
        // But 0.0.1 + patch = 0.0.2, NOT 0.1.0.
        const provenanceJson = '''
{
  "package": "explicit_outcome",
  "version": "0.1.0",
  "previousVersion": "0.0.1",
  "nextVersion": "0.1.0",
  "bump": "patch",
  "changesetHashes": ["abc"],
  "changelogNotesHash": "def",
  "tag": "explicit_outcome/v0.1.0",
  "provenanceSource": "release_version_pr.version-pr.v1"
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
          result.errors.any((e) => e.contains('previousVersion')),
          isTrue,
          reason: 'Should fail when previousVersion + bump != version',
        );
      },
    );

    test(
      'fails when provenance bump is patch but versions imply major',
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
        // Provenance claims bump=patch but 0.9.0 → 1.0.0 is a major bump.
        const provenanceJson = '''
{
  "package": "explicit_outcome",
  "version": "1.0.0",
  "previousVersion": "0.9.0",
  "nextVersion": "1.0.0",
  "bump": "patch",
  "changesetHashes": ["abc"],
  "changelogNotesHash": "def",
  "tag": "explicit_outcome/v1.0.0",
  "provenanceSource": "release_version_pr.version-pr.v1"
}
''';
        final result = ReleaseValidator.validateRelease(
          tag: 'explicit_outcome/v1.0.0',
          pubspecContent: pubspec,
          changelogContent: changelog,
          provenanceJson: provenanceJson,
        );
        expect(result.isValid, isFalse);
        expect(
          result.errors.any(
            (e) => e.contains('major') || e.contains('bump'),
          ),
          isTrue,
          reason: 'Should detect major bypass via previousVersion/nextVersion',
        );
      },
    );

    test(
      'fails when provenance bump is minor but versions imply major',
      () {
        const pubspec = '''
name: explicit
version: 2.0.0
description: Test.
''';
        const changelog = '''
# Changelog

## 2.0.0 (2026-07-09)

- Breaking.
''';
        // Provenance claims bump=minor but 1.5.0 → 2.0.0 is major.
        const provenanceJson = '''
{
  "package": "explicit",
  "version": "2.0.0",
  "previousVersion": "1.5.0",
  "nextVersion": "2.0.0",
  "bump": "minor",
  "changesetHashes": ["abc"],
  "changelogNotesHash": "def",
  "tag": "explicit/v2.0.0",
  "provenanceSource": "release_version_pr.version-pr.v1"
}
''';
        final result = ReleaseValidator.validateRelease(
          tag: 'explicit/v2.0.0',
          pubspecContent: pubspec,
          changelogContent: changelog,
          provenanceJson: provenanceJson,
        );
        expect(result.isValid, isFalse);
        expect(
          result.errors.any(
            (e) => e.contains('major') || e.contains('bump'),
          ),
          isTrue,
        );
      },
    );

    test(
      'passes when provenance previousVersion + bump matches version',
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
        // Correct: 0.0.1 + minor = 0.1.0.
        final validProvenanceJson = provenanceJson(notes: '- Feature.');
        final result = ReleaseValidator.validateRelease(
          tag: 'explicit_outcome/v0.1.0',
          pubspecContent: pubspec,
          changelogContent: changelog,
          provenanceJson: validProvenanceJson,
        );
        expect(result.isValid, isTrue);
      },
    );

    test(
      'manual version edit without provenance fails closed',
      () {
        const pubspec = '''
name: explicit_outcome
version: 0.5.0
description: Test.
''';
        const changelog = '''
# Changelog

## 0.5.0 (2026-07-09)

- Manual edit.
''';
        // No provenance — simulates manual version edit.
        final result = ReleaseValidator.validateRelease(
          tag: 'explicit_outcome/v0.5.0',
          pubspecContent: pubspec,
          changelogContent: changelog,
          provenanceJson: null,
        );
        expect(result.isValid, isFalse);
        expect(
          result.errors.any((e) => e.contains('provenance')),
          isTrue,
        );
      },
    );

    test(
      'fails when provenance tag does not match release tag',
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
        // Provenance tag says explicit/v0.1.0 but release tag is
        // explicit_outcome/v0.1.0.
        const provenanceJson = '''
{
  "package": "explicit_outcome",
  "version": "0.1.0",
  "previousVersion": "0.0.1",
  "nextVersion": "0.1.0",
  "bump": "minor",
  "changesetHashes": ["abc"],
  "changelogNotesHash": "def",
  "tag": "explicit/v0.1.0",
  "provenanceSource": "release_version_pr.version-pr.v1"
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
          result.errors.any((e) => e.contains('tag')),
          isTrue,
        );
      },
    );

    test(
      'fails when provenance nextVersion does not match version',
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
  "previousVersion": "0.0.1",
  "nextVersion": "0.9.9",
  "bump": "minor",
  "changesetHashes": ["abc"],
  "changelogNotesHash": "def",
  "tag": "explicit_outcome/v0.1.0",
  "provenanceSource": "release_version_pr.version-pr.v1"
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
          result.errors.any((e) => e.contains('nextVersion')),
          isTrue,
        );
      },
    );

    test(
      'fails when provenance bump is not one of patch minor major',
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
  "previousVersion": "0.0.1",
  "nextVersion": "0.1.0",
  "bump": "security",
  "changesetHashes": ["abc"],
  "changelogNotesHash": "def",
  "tag": "explicit_outcome/v0.1.0",
  "provenanceSource": "release_version_pr.version-pr.v1"
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
          result.errors.any((e) => e.contains('bump')),
          isTrue,
        );
      },
    );
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

  // =========================================================================
  // Corrective Slice 1: Content-Aware Impact Classifier + Reconciliation
  // =========================================================================

  group('ChangedFile', () {
    test('stores path and optional diff content', () {
      const file = ChangedFile(path: 'packages/explicit/lib/src/a.dart');
      expect(file.path, 'packages/explicit/lib/src/a.dart');
      expect(file.diffContent, isNull);
    });

    test('stores diff content when provided', () {
      const file = ChangedFile(
        path: 'packages/explicit/lib/src/a.dart',
        diffContent: '+  final x = 1;',
      );
      expect(file.diffContent, '+  final x = 1;');
    });
  });

  group('DartDiffAnalyzer', () {
    test('detects real code token change in Dart diff', () {
      const diff = '''
@@ -1,3 +1,3 @@
-  final x = 1;
+  final x = 2;
''';
      expect(DartDiffAnalyzer.hasRealCodeChanges(diff), isTrue);
    });

    test('detects added function as real change', () {
      const diff = '''
@@ -0,0 +1,5 @@
+int add(int a, int b) {
+  return a + b;
+}
''';
      expect(DartDiffAnalyzer.hasRealCodeChanges(diff), isTrue);
    });

    test('comment-only diff has no real code changes', () {
      const diff = '''
@@ -1,3 +1,3 @@
-  // old comment
+  // new comment
''';
      expect(DartDiffAnalyzer.hasRealCodeChanges(diff), isFalse);
    });

    test('doc comment-only diff has no real code changes', () {
      const diff = '''
@@ -1,3 +1,4 @@
+  /// Documentation for the function.
+  /// More docs here.
''';
      expect(DartDiffAnalyzer.hasRealCodeChanges(diff), isFalse);
    });

    test('multi-line block comment diff has no real code changes', () {
      const diff = '''
@@ -1,3 +1,5 @@
+  /* This is a
+     block comment
+     that spans lines */
''';
      expect(DartDiffAnalyzer.hasRealCodeChanges(diff), isFalse);
    });

    test('whitespace-only diff has no real code changes', () {
      const diff = '''
@@ -1,3 +1,3 @@
-  final x = 1;
+    final x = 1;
''';
      expect(DartDiffAnalyzer.hasRealCodeChanges(diff), isFalse);
    });

    test('empty diff has no real code changes', () {
      expect(DartDiffAnalyzer.hasRealCodeChanges(''), isFalse);
    });

    test('diff with only header lines has no real code changes', () {
      const diff = '''
--- a/packages/explicit/lib/src/a.dart
+++ b/packages/explicit/lib/src/a.dart
@@ -1,3 +1,3 @@
''';
      expect(DartDiffAnalyzer.hasRealCodeChanges(diff), isFalse);
    });

    test('mixed comment and code change is real', () {
      const diff = '''
@@ -1,3 +1,4 @@
-  // old comment
+  // new comment
+  final y = 2;
''';
      expect(DartDiffAnalyzer.hasRealCodeChanges(diff), isTrue);
    });

    test('renamed variable is a real change', () {
      const diff = '''
@@ -1,3 +1,3 @@
-  final oldName = compute();
+  final newName = compute();
''';
      expect(DartDiffAnalyzer.hasRealCodeChanges(diff), isTrue);
    });

    test('format-only reordering is not a real change', () {
      const diff = '''
@@ -1,3 +1,3 @@
-  void foo(int a,int b,int c){}
+  void foo(int a, int b, int c) {}
''';
      expect(DartDiffAnalyzer.hasRealCodeChanges(diff), isFalse);
    });
  });

  group('ImpactClassifier', () {
    test('classifies lib Dart file with real code diff as real impact', () {
      const files = [
        ChangedFile(
          path: 'packages/explicit_outcome/lib/src/option/opt.dart',
          diffContent: '+  final int value;',
        ),
      ];
      final result = ImpactClassifier.classify(files);
      expect(result.classifications, hasLength(1));
      expect(
        result.classifications.first.category,
        ImpactCategory.realImpact,
      );
      expect(result.classifications.first.packageName, 'explicit_outcome');
    });

    test('classifies lib Dart file with comment-only diff as commentOnly', () {
      const files = [
        ChangedFile(
          path: 'packages/explicit/lib/src/utils.dart',
          diffContent: '+  // Updated documentation comment',
        ),
      ];
      final result = ImpactClassifier.classify(files);
      expect(result.classifications, hasLength(1));
      expect(
        result.classifications.first.category,
        ImpactCategory.commentOnly,
      );
    });

    test('classifies lib Dart file with whitespace-only diff', () {
      const files = [
        ChangedFile(
          path: 'packages/explicit/lib/src/utils.dart',
          diffContent: '-  final x = 1;\n+    final x = 1;',
        ),
      ];
      final result = ImpactClassifier.classify(files);
      expect(
        result.classifications.first.category,
        ImpactCategory.whitespaceOnly,
      );
    });

    test('classifies README.md as docsOnly', () {
      const files = [
        ChangedFile(path: 'packages/explicit/README.md'),
      ];
      final result = ImpactClassifier.classify(files);
      expect(
        result.classifications.first.category,
        ImpactCategory.docsOnly,
      );
    });

    test('classifies CHANGELOG.md as docsOnly', () {
      const files = [
        ChangedFile(path: 'packages/explicit_outcome/CHANGELOG.md'),
      ];
      final result = ImpactClassifier.classify(files);
      expect(
        result.classifications.first.category,
        ImpactCategory.docsOnly,
      );
    });

    test('classifies test files as testOnly', () {
      const files = [
        ChangedFile(
          path: 'packages/explicit/test/src/utils_test.dart',
        ),
      ];
      final result = ImpactClassifier.classify(files);
      expect(
        result.classifications.first.category,
        ImpactCategory.testOnly,
      );
    });

    test('classifies example files as exampleOnly', () {
      const files = [
        ChangedFile(
          path: 'packages/explicit/example/main.dart',
        ),
      ];
      final result = ImpactClassifier.classify(files);
      expect(
        result.classifications.first.category,
        ImpactCategory.exampleOnly,
      );
    });

    test('classifies non-package files as notPublishable', () {
      const files = [
        ChangedFile(path: 'tool/foo.dart'),
        ChangedFile(path: '.github/workflows/ci.yaml'),
      ];
      final result = ImpactClassifier.classify(files);
      expect(result.classifications, hasLength(2));
      for (final c in result.classifications) {
        expect(c.category, ImpactCategory.notPublishable);
        expect(c.packageName, isNull);
      }
    });

    test('classifies pubspec.yaml as real impact', () {
      const files = [
        ChangedFile(path: 'packages/explicit/pubspec.yaml'),
      ];
      final result = ImpactClassifier.classify(files);
      expect(
        result.classifications.first.category,
        ImpactCategory.realImpact,
      );
      expect(result.classifications.first.packageName, 'explicit');
    });

    test('lib file without diff falls back to path-based: real impact', () {
      const files = [
        ChangedFile(path: 'packages/explicit/lib/src/utils.dart'),
      ];
      final result = ImpactClassifier.classify(files);
      expect(
        result.classifications.first.category,
        ImpactCategory.realImpact,
      );
    });

    test('aggregates package impact correctly', () {
      const files = [
        ChangedFile(
          path: 'packages/explicit_outcome/lib/src/a.dart',
          diffContent: '+  final int value;',
        ),
        ChangedFile(
          path: 'packages/explicit_outcome/README.md',
        ),
        ChangedFile(
          path: 'packages/explicit/lib/src/b.dart',
          diffContent: '+  // just a comment',
        ),
        ChangedFile(path: 'tool/foo.dart'),
      ];
      final result = ImpactClassifier.classify(files);

      // explicit_outcome has real impact (lib/src/a.dart has code change)
      expect(result.packageImpacts.containsKey('explicit_outcome'), isTrue);
      expect(
        result.packageImpacts['explicit_outcome']!.hasRealImpact,
        isTrue,
      );

      // explicit has NO real impact (comment-only change)
      expect(result.packageImpacts.containsKey('explicit'), isTrue);
      expect(
        result.packageImpacts['explicit']!.hasRealImpact,
        isFalse,
      );
    });

    test('impactedPackages returns only packages with real impact', () {
      const files = [
        ChangedFile(
          path: 'packages/explicit_outcome/lib/src/a.dart',
          diffContent: '+  final int value;',
        ),
        ChangedFile(
          path: 'packages/explicit/lib/src/b.dart',
          diffContent: '+  // comment only',
        ),
      ];
      final result = ImpactClassifier.classify(files);
      expect(result.impactedPackages, contains('explicit_outcome'));
      expect(result.impactedPackages, isNot(contains('explicit')));
    });

    test('no impacted packages when all changes are non-impactful', () {
      const files = [
        ChangedFile(path: 'packages/explicit/README.md'),
        ChangedFile(
          path: 'packages/explicit/lib/src/a.dart',
          diffContent: '+  /// Doc comment only',
        ),
        ChangedFile(path: 'packages/explicit_outcome/CHANGELOG.md'),
      ];
      final result = ImpactClassifier.classify(files);
      expect(result.impactedPackages, isEmpty);
    });

    test('package-specific: only explicit_outcome impacted', () {
      const files = [
        ChangedFile(
          path: 'packages/explicit_outcome/lib/src/option.dart',
          diffContent: '+  T get value => _value;',
        ),
      ];
      final result = ImpactClassifier.classify(files);
      expect(result.impactedPackages, ['explicit_outcome']);
    });

    test('package-specific: only explicit impacted', () {
      const files = [
        ChangedFile(
          path: 'packages/explicit/lib/src/parser.dart',
          diffContent: '+  class Parser {}',
        ),
      ];
      final result = ImpactClassifier.classify(files);
      expect(result.impactedPackages, ['explicit']);
    });

    test('package-specific: both packages impacted', () {
      const files = [
        ChangedFile(
          path: 'packages/explicit_outcome/lib/src/option.dart',
          diffContent: '+  T get value => _value;',
        ),
        ChangedFile(
          path: 'packages/explicit/lib/src/parser.dart',
          diffContent: '+  class Parser {}',
        ),
      ];
      final result = ImpactClassifier.classify(files);
      expect(
        result.impactedPackages,
        containsAll(['explicit', 'explicit_outcome']),
      );
    });
  });

  group('ReleaseReconciler', () {
    test(
      'intent + impact produces release candidate',
      () {
        final changesets = [
          const Changeset(
            bumps: {'explicit_outcome': BumpLevel.minor},
            notes: '- Add option API.',
          ),
        ];
        const files = [
          ChangedFile(
            path: 'packages/explicit_outcome/lib/src/option.dart',
            diffContent: '+  T get value => _value;',
          ),
        ];
        final result = ReleaseReconciler.reconcile(
          changedFiles: files,
          changesets: changesets,
        );
        expect(result.releaseCandidates, hasLength(1));
        expect(
          result.releaseCandidates.first.packageName,
          'explicit_outcome',
        );
        expect(result.releaseCandidates.first.bump, BumpLevel.minor);
        expect(result.missingIntentFailures, isEmpty);
        expect(result.unusedIntentWarnings, isEmpty);
      },
    );

    test(
      'impact without changeset produces missingIntentFailure',
      () {
        const files = [
          ChangedFile(
            path: 'packages/explicit_outcome/lib/src/option.dart',
            diffContent: '+  T get value => _value;',
          ),
        ];
        final result = ReleaseReconciler.reconcile(
          changedFiles: files,
          changesets: [],
        );
        expect(result.releaseCandidates, isEmpty);
        expect(result.missingIntentFailures, hasLength(1));
        expect(
          result.missingIntentFailures.first.packageName,
          'explicit_outcome',
        );
        expect(
          result.missingIntentFailures.first.remediation,
          contains('explicit_outcome'),
        );
        expect(result.unusedIntentWarnings, isEmpty);
      },
    );

    test(
      'changeset without real impact produces unusedIntentWarning',
      () {
        final changesets = [
          const Changeset(
            bumps: {'explicit_outcome': BumpLevel.patch},
            notes: '- Fix something.',
          ),
        ];
        const files = [
          ChangedFile(path: 'packages/explicit_outcome/README.md'),
          ChangedFile(
            path: 'packages/explicit_outcome/lib/src/a.dart',
            diffContent: '+  // comment only change',
          ),
        ];
        final result = ReleaseReconciler.reconcile(
          changedFiles: files,
          changesets: changesets,
        );
        expect(result.releaseCandidates, isEmpty);
        expect(result.missingIntentFailures, isEmpty);
        expect(result.unusedIntentWarnings, hasLength(1));
        expect(
          result.unusedIntentWarnings.first.packageName,
          'explicit_outcome',
        );
        expect(
          result.unusedIntentWarnings.first.reason,
          contains('no real'),
        );
      },
    );

    test(
      'mixed: one package has intent+impact, other has impact only',
      () {
        final changesets = [
          const Changeset(
            bumps: {'explicit_outcome': BumpLevel.minor},
            notes: '- Add feature.',
          ),
        ];
        const files = [
          ChangedFile(
            path: 'packages/explicit_outcome/lib/src/a.dart',
            diffContent: '+  class NewApi {}',
          ),
          ChangedFile(
            path: 'packages/explicit/lib/src/b.dart',
            diffContent: '+  void newFunction() {}',
          ),
        ];
        final result = ReleaseReconciler.reconcile(
          changedFiles: files,
          changesets: changesets,
        );
        // explicit_outcome: intent + impact → candidate
        expect(result.releaseCandidates, hasLength(1));
        expect(
          result.releaseCandidates.first.packageName,
          'explicit_outcome',
        );
        // explicit: impact without intent → failure
        expect(result.missingIntentFailures, hasLength(1));
        expect(
          result.missingIntentFailures.first.packageName,
          'explicit',
        );
      },
    );

    test(
      'mixed: one package has intent+impact, other has intent only',
      () {
        final changesets = [
          const Changeset(
            bumps: {
              'explicit_outcome': BumpLevel.minor,
              'explicit': BumpLevel.patch,
            },
            notes: '- Changes.',
          ),
        ];
        const files = [
          ChangedFile(
            path: 'packages/explicit_outcome/lib/src/a.dart',
            diffContent: '+  class NewApi {}',
          ),
          // explicit has only docs changes → no real impact
          ChangedFile(path: 'packages/explicit/README.md'),
        ];
        final result = ReleaseReconciler.reconcile(
          changedFiles: files,
          changesets: changesets,
        );
        // explicit_outcome: intent + impact → candidate
        expect(result.releaseCandidates, hasLength(1));
        expect(
          result.releaseCandidates.first.packageName,
          'explicit_outcome',
        );
        // explicit: intent without impact → warning
        expect(result.unusedIntentWarnings, hasLength(1));
        expect(
          result.unusedIntentWarnings.first.packageName,
          'explicit',
        );
      },
    );

    test('hasFailures is true when missingIntentFailures exist', () {
      const files = [
        ChangedFile(
          path: 'packages/explicit/lib/src/a.dart',
          diffContent: '+  void foo() {}',
        ),
      ];
      final result = ReleaseReconciler.reconcile(
        changedFiles: files,
        changesets: [],
      );
      expect(result.hasFailures, isTrue);
    });

    test('hasFailures is false when no missingIntentFailures', () {
      final changesets = [
        const Changeset(
          bumps: {'explicit_outcome': BumpLevel.patch},
          notes: '- Fix.',
        ),
      ];
      const files = [
        ChangedFile(
          path: 'packages/explicit_outcome/lib/src/a.dart',
          diffContent: '+  void fix() {}',
        ),
      ];
      final result = ReleaseReconciler.reconcile(
        changedFiles: files,
        changesets: changesets,
      );
      expect(result.hasFailures, isFalse);
    });

    test(
      'no impact and no intent produces empty reconciliation',
      () {
        const files = [
          ChangedFile(path: 'tool/foo.dart'),
          ChangedFile(path: 'docs/bar.md'),
        ];
        final result = ReleaseReconciler.reconcile(
          changedFiles: files,
          changesets: [],
        );
        expect(result.releaseCandidates, isEmpty);
        expect(result.missingIntentFailures, isEmpty);
        expect(result.unusedIntentWarnings, isEmpty);
      },
    );

    test(
      'missingIntentFailure includes package-specific remediation',
      () {
        const files = [
          ChangedFile(
            path: 'packages/explicit/lib/src/parser.dart',
            diffContent: '+  class Parser {}',
          ),
        ];
        final result = ReleaseReconciler.reconcile(
          changedFiles: files,
          changesets: [],
        );
        expect(result.missingIntentFailures, hasLength(1));
        final failure = result.missingIntentFailures.first;
        expect(failure.packageName, 'explicit');
        expect(failure.remediation, contains('changeset'));
        expect(failure.remediation, contains('explicit'));
      },
    );

    test(
      'release candidates preserve publish order '
      '(explicit_outcome before explicit)',
      () {
        final changesets = [
          const Changeset(
            bumps: {
              'explicit': BumpLevel.patch,
              'explicit_outcome': BumpLevel.minor,
            },
            notes: '- Both changed.',
          ),
        ];
        const files = [
          ChangedFile(
            path: 'packages/explicit_outcome/lib/src/a.dart',
            diffContent: '+  class A {}',
          ),
          ChangedFile(
            path: 'packages/explicit/lib/src/b.dart',
            diffContent: '+  class B {}',
          ),
        ];
        final result = ReleaseReconciler.reconcile(
          changedFiles: files,
          changesets: changesets,
        );
        expect(result.releaseCandidates, hasLength(2));
        expect(
          result.releaseCandidates[0].packageName,
          'explicit_outcome',
        );
        expect(result.releaseCandidates[1].packageName, 'explicit');
      },
    );
  });
}
