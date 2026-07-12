import 'dart:io';

import 'package:test/test.dart';

import '../src/release_planner.dart';
import '../src/version_editor.dart';

void main() {
  group('VersionEditor', () {
    group('computeNextVersion', () {
      test('patch bump increments patch', () {
        expect(
          VersionEditor.computeNextVersion('0.0.1', BumpLevel.patch),
          '0.0.2',
        );
      });

      test('minor bump resets patch', () {
        expect(
          VersionEditor.computeNextVersion('0.0.1', BumpLevel.minor),
          '0.1.0',
        );
      });

      test('major bump resets minor and patch', () {
        expect(
          VersionEditor.computeNextVersion('0.0.1', BumpLevel.major),
          '1.0.0',
        );
      });

      test('patch bump on higher version', () {
        expect(
          VersionEditor.computeNextVersion('1.2.3', BumpLevel.patch),
          '1.2.4',
        );
      });

      test('minor bump on higher version resets patch', () {
        expect(
          VersionEditor.computeNextVersion('1.2.3', BumpLevel.minor),
          '1.3.0',
        );
      });

      test('major bump on higher version resets minor and patch', () {
        expect(
          VersionEditor.computeNextVersion('1.2.3', BumpLevel.major),
          '2.0.0',
        );
      });

      test('throws on invalid version format', () {
        expect(
          () => VersionEditor.computeNextVersion('abc', BumpLevel.patch),
          throwsFormatException,
        );
      });

      test('throws on two-part version', () {
        expect(
          () => VersionEditor.computeNextVersion('1.2', BumpLevel.patch),
          throwsFormatException,
        );
      });
    });

    group('bumpPubspecVersion', () {
      test('replaces version line in pubspec content', () {
        const pubspec = '''
name: explicit_outcome
version: 0.0.1
description: Some package.
''';
        final result = VersionEditor.bumpPubspecVersion(pubspec, '0.1.0');
        expect(result, contains('version: 0.1.0'));
        expect(result, isNot(contains('version: 0.0.1')));
      });

      test('preserves other pubspec fields', () {
        const pubspec = '''
name: explicit_outcome
version: 0.0.1
description: Some package.
license: MPL-2.0
''';
        final result = VersionEditor.bumpPubspecVersion(pubspec, '0.0.2');
        expect(result, contains('name: explicit_outcome'));
        expect(result, contains('description: Some package.'));
        expect(result, contains('license: MPL-2.0'));
      });

      test('is idempotent when version already matches', () {
        const pubspec = '''
name: explicit_outcome
version: 0.1.0
description: Some package.
''';
        final result = VersionEditor.bumpPubspecVersion(pubspec, '0.1.0');
        expect(result, contains('version: 0.1.0'));
        // Should not duplicate or alter content.
        expect(result, pubspec);
      });

      test('handles pubspec with dependencies after version', () {
        const pubspec = '''
name: explicit
version: 0.0.1
dependencies:
  explicit_outcome: ^0.0.1
  meta: ^1.18.3
''';
        final result = VersionEditor.bumpPubspecVersion(pubspec, '0.0.2');
        expect(result, contains('version: 0.0.2'));
        expect(result, contains('explicit_outcome: ^0.0.1'));
        expect(result, contains('meta: ^1.18.3'));
      });
    });

    group('prependChangelogEntry', () {
      test('inserts version heading after Changelog title', () {
        const changelog = '''
# Changelog

## 0.0.1

- Initial release.
''';
        final result = VersionEditor.prependChangelogEntry(
          changelog,
          '0.1.0',
          '- Add new feature.',
          DateTime(2026, 7, 9),
        );
        expect(result, contains('## 0.1.0'));
        expect(result, contains('- Add new feature.'));
        // New entry should appear before the old one.
        final newIdx = result.indexOf('## 0.1.0');
        final oldIdx = result.indexOf('## 0.0.1');
        expect(newIdx, lessThan(oldIdx));
      });

      test('includes date in version heading', () {
        const changelog = '''
# Changelog

## 0.0.1

- Initial release.
''';
        final result = VersionEditor.prependChangelogEntry(
          changelog,
          '0.0.2',
          '- Fix bug.',
          DateTime(2026, 7, 9),
        );
        expect(result, contains('2026-07-09'));
      });

      test('preserves existing entries', () {
        const changelog = '''
# Changelog

## 0.0.1

- Initial release of `explicit_outcome`.
- `Result<T, E>` sealed type.
''';
        final result = VersionEditor.prependChangelogEntry(
          changelog,
          '0.1.0',
          '- Add feature.',
          DateTime(2026, 7, 9),
        );
        expect(result, contains('## 0.0.1'));
        expect(result, contains('Initial release of `explicit_outcome`.'));
        expect(result, contains('`Result<T, E>` sealed type.'));
      });

      test('handles multiline notes', () {
        const changelog = '''
# Changelog

## 0.0.1

- Initial release.
''';
        const notes = '- First change.\n- Second change.\n- Third change.';
        final result = VersionEditor.prependChangelogEntry(
          changelog,
          '0.1.0',
          notes,
          DateTime(2026, 7, 9),
        );
        expect(result, contains('- First change.'));
        expect(result, contains('- Second change.'));
        expect(result, contains('- Third change.'));
      });
    });

    group('updateDependencyVersion', () {
      test('updates caret range for named dependency', () {
        const pubspec = '''
name: explicit
version: 0.0.2
dependencies:
  explicit_outcome: ^0.0.1
  meta: ^1.18.3
''';
        final result = VersionEditor.updateDependencyVersion(
          pubspec,
          'explicit_outcome',
          '0.1.0',
        );
        expect(result, contains('explicit_outcome: ^0.1.0'));
        expect(result, isNot(contains('explicit_outcome: ^0.0.1')));
      });

      test('does not modify other dependencies', () {
        const pubspec = '''
name: explicit
version: 0.0.2
dependencies:
  explicit_outcome: ^0.0.1
  meta: ^1.18.3
''';
        final result = VersionEditor.updateDependencyVersion(
          pubspec,
          'explicit_outcome',
          '0.1.0',
        );
        expect(result, contains('meta: ^1.18.3'));
      });

      test('no edit when dependency not present', () {
        const pubspec = '''
name: explicit_outcome
version: 0.1.0
dependencies:
  meta: ^1.18.3
''';
        final result = VersionEditor.updateDependencyVersion(
          pubspec,
          'explicit_outcome',
          '0.1.0',
        );
        // Content should be unchanged since explicit_outcome is not a dep.
        expect(result, pubspec);
      });

      test('updates dependency in dev_dependencies too', () {
        const pubspec = '''
name: some_app
version: 1.0.0
dev_dependencies:
  explicit_outcome: ^0.0.1
  test: ^1.0.0
''';
        final result = VersionEditor.updateDependencyVersion(
          pubspec,
          'explicit_outcome',
          '0.1.0',
        );
        expect(result, contains('explicit_outcome: ^0.1.0'));
      });
    });

    group('applyVersionEdits', () {
      late Directory tempDir;

      setUp(() {
        tempDir = Directory.systemTemp.createTempSync('version_editor_test_');
        // Create workspace structure.
        Directory(
          '${tempDir.path}/packages/explicit_outcome',
        ).createSync(recursive: true);
        Directory(
          '${tempDir.path}/packages/explicit',
        ).createSync(recursive: true);

        File(
          '${tempDir.path}/packages/explicit_outcome/pubspec.yaml',
        ).writeAsStringSync('''
name: explicit_outcome
version: 0.0.1
description: Dart typed outcomes.
''');

        File(
          '${tempDir.path}/packages/explicit_outcome/CHANGELOG.md',
        ).writeAsStringSync('''
# Changelog

## 0.0.1

- Initial release.
''');

        File(
          '${tempDir.path}/packages/explicit/pubspec.yaml',
        ).writeAsStringSync('''
name: explicit
version: 0.0.1
description: Declarative Dart utilities.
dependencies:
  explicit_outcome: ^0.0.1
''');

        File(
          '${tempDir.path}/packages/explicit/CHANGELOG.md',
        ).writeAsStringSync('''
# Changelog

## 0.0.1

- Initial release.
''');
      });

      tearDown(() {
        tempDir.deleteSync(recursive: true);
      });

      test('bumps both packages when both are candidates', () {
        const plan = ReleasePlan(
          candidates: [
            ReleaseCandidate(
              packageName: 'explicit_outcome',
              bump: BumpLevel.minor,
              notes: '- Add typed outcome API.',
            ),
            ReleaseCandidate(
              packageName: 'explicit',
              bump: BumpLevel.patch,
              notes: '- Update re-exports.',
            ),
          ],
          dependencyUpdates: [
            DependencyUpdate(
              packageName: 'explicit',
              dependencyName: 'explicit_outcome',
            ),
          ],
        );

        final edits = VersionEditor.applyVersionEdits(plan, tempDir.path);

        // Verify explicit_outcome pubspec bumped.
        final outcomePubspec = File(
          '${tempDir.path}/packages/explicit_outcome/pubspec.yaml',
        ).readAsStringSync();
        expect(outcomePubspec, contains('version: 0.1.0'));

        // Verify explicit pubspec bumped.
        final explicitPubspec = File(
          '${tempDir.path}/packages/explicit/pubspec.yaml',
        ).readAsStringSync();
        expect(explicitPubspec, contains('version: 0.0.2'));

        // Verify dependency propagation: explicit depends on ^0.1.0.
        expect(explicitPubspec, contains('explicit_outcome: ^0.1.0'));

        // Verify changelogs updated.
        final outcomeChangelog = File(
          '${tempDir.path}/packages/explicit_outcome/CHANGELOG.md',
        ).readAsStringSync();
        expect(outcomeChangelog, contains('## 0.1.0'));
        expect(outcomeChangelog, contains('- Add typed outcome API.'));

        final explicitChangelog = File(
          '${tempDir.path}/packages/explicit/CHANGELOG.md',
        ).readAsStringSync();
        expect(explicitChangelog, contains('## 0.0.2'));
        expect(explicitChangelog, contains('- Update re-exports.'));

        // Verify edits list is non-empty and describes changes.
        expect(edits, isNotEmpty);
      });

      test('bumps only explicit_outcome when it is the sole candidate', () {
        const plan = ReleasePlan(
          candidates: [
            ReleaseCandidate(
              packageName: 'explicit_outcome',
              bump: BumpLevel.patch,
              notes: '- Fix edge case.',
            ),
          ],
          dependencyUpdates: [],
        );

        VersionEditor.applyVersionEdits(plan, tempDir.path);

        // explicit_outcome bumped.
        final outcomePubspec = File(
          '${tempDir.path}/packages/explicit_outcome/pubspec.yaml',
        ).readAsStringSync();
        expect(outcomePubspec, contains('version: 0.0.2'));

        // explicit NOT bumped.
        final explicitPubspec = File(
          '${tempDir.path}/packages/explicit/pubspec.yaml',
        ).readAsStringSync();
        expect(explicitPubspec, contains('version: 0.0.1'));
        // Dependency NOT updated (no propagation when only outcome released).
        expect(explicitPubspec, contains('explicit_outcome: ^0.0.1'));
      });

      test('produces no edits when plan has no candidates', () {
        const plan = ReleasePlan(
          candidates: [],
          dependencyUpdates: [],
        );

        final edits = VersionEditor.applyVersionEdits(plan, tempDir.path);
        expect(edits, isEmpty);
      });

      test('emits provenance manifest per candidate', () {
        const plan = ReleasePlan(
          candidates: [
            ReleaseCandidate(
              packageName: 'explicit_outcome',
              bump: BumpLevel.minor,
              notes: '- Add typed outcome API.',
            ),
            ReleaseCandidate(
              packageName: 'explicit',
              bump: BumpLevel.patch,
              notes: '- Update re-exports.',
            ),
          ],
          dependencyUpdates: [
            DependencyUpdate(
              packageName: 'explicit',
              dependencyName: 'explicit_outcome',
            ),
          ],
        );

        // Create changesets dir with provenance source data.
        final changesetsDir = Directory('${tempDir.path}/.changesets')
          ..createSync();
        File('${changesetsDir.path}/feature.md').writeAsStringSync('''
---
explicit_outcome: minor
explicit: patch
---

- Add typed outcome API.
- Update re-exports.
''');

        VersionEditor.applyVersionEdits(
          plan,
          tempDir.path,
          changesetsDir: changesetsDir.path,
        );

        // Verify provenance manifests exist.
        final outcomeProvenance = File(
          '${changesetsDir.path}/releases/'
          'explicit_outcome-0.1.0.json',
        );
        expect(
          outcomeProvenance.existsSync(),
          isTrue,
          reason:
              'Provenance manifest should be emitted for '
              'explicit_outcome',
        );

        final explicitProvenance = File(
          '${changesetsDir.path}/releases/explicit-0.0.2.json',
        );
        expect(
          explicitProvenance.existsSync(),
          isTrue,
          reason: 'Provenance manifest should be emitted for explicit',
        );

        // Verify provenance content.
        final outcomeProv = ReleaseProvenance.fromJson(
          outcomeProvenance.readAsStringSync(),
        );
        expect(outcomeProv.packageName, 'explicit_outcome');
        expect(outcomeProv.version, '0.1.0');
        expect(outcomeProv.bump, 'minor');
        expect(outcomeProv.changesetHashes, isNotEmpty);
        expect(outcomeProv.changelogNotesHash, isNotEmpty);

        final explicitProv = ReleaseProvenance.fromJson(
          explicitProvenance.readAsStringSync(),
        );
        expect(explicitProv.packageName, 'explicit');
        expect(explicitProv.version, '0.0.2');
        expect(explicitProv.bump, 'patch');
      });

      test('provenance emission is idempotent', () {
        const plan = ReleasePlan(
          candidates: [
            ReleaseCandidate(
              packageName: 'explicit_outcome',
              bump: BumpLevel.patch,
              notes: '- Fix edge case.',
            ),
          ],
          dependencyUpdates: [],
        );

        final changesetsDir = Directory('${tempDir.path}/.changesets')
          ..createSync();
        const changesetContent = '''
---
explicit_outcome: patch
---

- Fix edge case.
''';
        File('${changesetsDir.path}/fix.md').writeAsStringSync(
          changesetContent,
        );

        // Run twice — should produce identical provenance.
        File('${changesetsDir.path}/fix.md').writeAsStringSync(
          changesetContent,
        );

        VersionEditor.applyVersionEdits(
          plan,
          tempDir.path,
          changesetsDir: changesetsDir.path,
        );
        final firstContent = File(
          '${changesetsDir.path}/releases/'
          'explicit_outcome-0.0.2.json',
        ).readAsStringSync();

        File(
          '${tempDir.path}/packages/explicit_outcome/pubspec.yaml',
        ).writeAsStringSync('''
name: explicit_outcome
version: 0.0.1
description: Dart typed outcomes.
''');
        File('${changesetsDir.path}/fix.md').writeAsStringSync(
          changesetContent,
        );

        VersionEditor.applyVersionEdits(
          plan,
          tempDir.path,
          changesetsDir: changesetsDir.path,
        );
        final secondContent = File(
          '${changesetsDir.path}/releases/'
          'explicit_outcome-0.0.2.json',
        ).readAsStringSync();

        expect(firstContent, secondContent);
      });

      test(
        'provenance captures changesets in deterministic filename order',
        () {
          const plan = ReleasePlan(
            candidates: [
              ReleaseCandidate(
                packageName: 'explicit_outcome',
                bump: BumpLevel.minor,
                notes: '- First.\n- Second.',
              ),
            ],
            dependencyUpdates: [],
          );

          final changesetsDir = Directory('${tempDir.path}/.changesets')
            ..createSync();
          File('${changesetsDir.path}/b-second.md').writeAsStringSync('''
---
explicit_outcome: patch
---

- Second.
''');
          File('${changesetsDir.path}/a-first.md').writeAsStringSync('''
---
explicit_outcome: minor
---

- First.
''');

          VersionEditor.applyVersionEdits(
            plan,
            tempDir.path,
            changesetsDir: changesetsDir.path,
          );

          final provenance = ReleaseProvenance.fromJson(
            File(
              '${changesetsDir.path}/releases/explicit_outcome-0.1.0.json',
            ).readAsStringSync(),
          );

          expect(provenance.changesetContents, [
            '''
---
explicit_outcome: minor
---

- First.
''',
            '''
---
explicit_outcome: patch
---

- Second.
''',
          ]);
          expect(provenance.changesetHashes, [
            ReleaseProvenance.computeContentHash(
              provenance.changesetContents[0],
            ),
            ReleaseProvenance.computeContentHash(
              provenance.changesetContents[1],
            ),
          ]);
        },
      );

      test(
        'removes consumed changeset markdown after provenance is emitted',
        () {
          const plan = ReleasePlan(
            candidates: [
              ReleaseCandidate(
                packageName: 'explicit_outcome',
                bump: BumpLevel.patch,
                notes: '- Fix.',
              ),
            ],
            dependencyUpdates: [],
          );

          final changesetsDir = Directory('${tempDir.path}/.changesets')
            ..createSync();
          final consumed = File('${changesetsDir.path}/fix.md')
            ..writeAsStringSync('''
---
explicit_outcome: patch
---

- Fix.
''');
          final readme = File('${changesetsDir.path}/README.md')
            ..writeAsStringSync('# Changesets\n');

          VersionEditor.applyVersionEdits(
            plan,
            tempDir.path,
            changesetsDir: changesetsDir.path,
          );

          expect(consumed.existsSync(), isFalse);
          expect(readme.existsSync(), isTrue);
          expect(
            File(
              '${changesetsDir.path}/releases/explicit_outcome-0.0.2.json',
            ).existsSync(),
            isTrue,
          );
        },
      );

      test(
        'removes stale release provenance before writing current output',
        () {
          const plan = ReleasePlan(
            candidates: [
              ReleaseCandidate(
                packageName: 'explicit_outcome',
                bump: BumpLevel.patch,
                notes: '- Fix.',
              ),
            ],
            dependencyUpdates: [],
          );

          final changesetsDir = Directory('${tempDir.path}/.changesets')
            ..createSync();
          final releasesDir = Directory('${changesetsDir.path}/releases')
            ..createSync();
          File(
            '${releasesDir.path}/explicit_outcome-0.0.1.json',
          ).writeAsStringSync('{"stale": true}');
          const changesetContent = '''
---
explicit_outcome: patch
---

- Fix.
''';
          File('${changesetsDir.path}/fix.md').writeAsStringSync(
            changesetContent,
          );

          VersionEditor.applyVersionEdits(
            plan,
            tempDir.path,
            changesetsDir: changesetsDir.path,
          );

          final releaseFiles =
              releasesDir
                  .listSync()
                  .whereType<File>()
                  .map((file) => file.path.split(Platform.pathSeparator).last)
                  .toList()
                ..sort();
          expect(releaseFiles, ['explicit_outcome-0.0.2.json']);
        },
      );

      test('maintains publish order: explicit_outcome edited first', () {
        const plan = ReleasePlan(
          candidates: [
            ReleaseCandidate(
              packageName: 'explicit_outcome',
              bump: BumpLevel.minor,
              notes: '- Feature.',
            ),
            ReleaseCandidate(
              packageName: 'explicit',
              bump: BumpLevel.patch,
              notes: '- Fix.',
            ),
          ],
          dependencyUpdates: [
            DependencyUpdate(
              packageName: 'explicit',
              dependencyName: 'explicit_outcome',
            ),
          ],
        );

        final edits = VersionEditor.applyVersionEdits(plan, tempDir.path);

        // First edits should be for explicit_outcome (publish order).
        final outcomeEdits = edits.where(
          (e) => e.packageName == 'explicit_outcome',
        );
        final explicitEdits = edits.where(
          (e) => e.packageName == 'explicit',
        );
        expect(outcomeEdits, isNotEmpty);
        expect(explicitEdits, isNotEmpty);
        // Outcome edits come before explicit edits in the list.
        expect(
          edits.indexOf(outcomeEdits.first),
          lessThan(edits.indexOf(explicitEdits.first)),
        );
      });

      // Corrective Slice 2: provenance includes previousVersion and tag.
      test('provenance includes previousVersion and intended tag', () {
        const plan = ReleasePlan(
          candidates: [
            ReleaseCandidate(
              packageName: 'explicit_outcome',
              bump: BumpLevel.minor,
              notes: '- Add feature.',
            ),
          ],
          dependencyUpdates: [],
        );

        final changesetsDir = Directory('${tempDir.path}/.changesets')
          ..createSync();
        File('${changesetsDir.path}/feature.md').writeAsStringSync('''
---
explicit_outcome: minor
---

- Add feature.
''');

        VersionEditor.applyVersionEdits(
          plan,
          tempDir.path,
          changesetsDir: changesetsDir.path,
        );

        final provenanceFile = File(
          '${changesetsDir.path}/releases/'
          'explicit_outcome-0.1.0.json',
        );
        expect(provenanceFile.existsSync(), isTrue);

        final provenance = ReleaseProvenance.fromJson(
          provenanceFile.readAsStringSync(),
        );
        expect(provenance.previousVersion, '0.0.1');
        expect(provenance.version, '0.1.0');
        expect(provenance.tag, 'explicit_outcome/v0.1.0');
        expect(provenance.bump, 'minor');
      });

      test(
        'provenance emitted only for plan candidates (not all changesets)',
        () {
          // Plan has only explicit_outcome as candidate.
          // Changeset declares intent for both packages, but only
          // explicit_outcome is a reconciled candidate.
          const plan = ReleasePlan(
            candidates: [
              ReleaseCandidate(
                packageName: 'explicit_outcome',
                bump: BumpLevel.patch,
                notes: '- Fix.',
              ),
            ],
            dependencyUpdates: [],
          );

          final changesetsDir = Directory('${tempDir.path}/.changesets')
            ..createSync();
          // Changeset declares intent for both packages.
          File('${changesetsDir.path}/mixed.md').writeAsStringSync('''
---
explicit_outcome: patch
explicit: patch
---

- Fix.
''');

          VersionEditor.applyVersionEdits(
            plan,
            tempDir.path,
            changesetsDir: changesetsDir.path,
          );

          // Provenance should exist only for explicit_outcome (candidate).
          final outcomeProvenance = File(
            '${changesetsDir.path}/releases/'
            'explicit_outcome-0.0.2.json',
          );
          expect(
            outcomeProvenance.existsSync(),
            isTrue,
            reason: 'Provenance should be emitted for reconciled candidate',
          );

          // Provenance should NOT exist for explicit (not a candidate).
          final explicitProvenance = File(
            '${changesetsDir.path}/releases/explicit-0.0.2.json',
          );
          expect(
            explicitProvenance.existsSync(),
            isFalse,
            reason:
                'Provenance should NOT be emitted for non-candidate '
                'packages (changeset intent without real impact)',
          );
        },
      );

      test('provenance previousVersion is deterministic across runs', () {
        const plan = ReleasePlan(
          candidates: [
            ReleaseCandidate(
              packageName: 'explicit_outcome',
              bump: BumpLevel.patch,
              notes: '- Fix.',
            ),
          ],
          dependencyUpdates: [],
        );

        final changesetsDir = Directory('${tempDir.path}/.changesets')
          ..createSync();
        const changesetContent = '''
---
explicit_outcome: patch
---

- Fix.
''';
        File('${changesetsDir.path}/fix.md').writeAsStringSync(
          changesetContent,
        );

        // Run twice — provenance should be identical.
        VersionEditor.applyVersionEdits(
          plan,
          tempDir.path,
          changesetsDir: changesetsDir.path,
        );
        final first = File(
          '${changesetsDir.path}/releases/'
          'explicit_outcome-0.0.2.json',
        ).readAsStringSync();

        // Reset pubspec to original version for second run.
        File(
          '${tempDir.path}/packages/explicit_outcome/pubspec.yaml',
        ).writeAsStringSync('''
name: explicit_outcome
version: 0.0.1
description: Dart typed outcomes.
''');
        File('${changesetsDir.path}/fix.md').writeAsStringSync(
          changesetContent,
        );

        VersionEditor.applyVersionEdits(
          plan,
          tempDir.path,
          changesetsDir: changesetsDir.path,
        );
        final second = File(
          '${changesetsDir.path}/releases/'
          'explicit_outcome-0.0.2.json',
        ).readAsStringSync();

        expect(first, second);
      });
    });
  });
}
