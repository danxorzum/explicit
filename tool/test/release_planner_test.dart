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

    test('renderMarkdown includes handoff state for slice one', () {
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
}
