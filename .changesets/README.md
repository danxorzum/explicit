# Changesets

Changesets declare **release intent** for publishable packages. Every PR that
modifies publishable package code MUST include a changeset.

## Format

Each changeset is a Markdown file with YAML front matter:

```markdown
---
explicit_outcome: minor
explicit: patch
---

- Describe the change in a short bullet list.
```

### Front matter

- Keys are **package names** (`explicit_outcome`, `explicit`).
- Values are **bump levels**: `patch`, `minor`, or `major`.
- Include only the packages you intend to release.
- Multiple packages can appear in one changeset.

### Notes section

The Markdown body below the front matter is the changelog note. Keep it
concise and user-facing.

## File naming

Use a descriptive slug: `.changesets/add-outcome-map.md`.

## When to create a changeset

| Change type | Changeset needed? |
|---|---|
| `packages/<name>/lib/**` source code | Yes |
| `packages/<name>/pubspec.yaml` dependency or metadata change | Yes |
| Public example files in a package | Yes |
| `packages/<name>/test/**` only | No |
| `docs/**` only | No |
| `tool/**` only | No |
| `.github/workflows/**` only | No |
| Root config files only | No |

## Generating a changeset

Use the CLI:

```bash
dart run tool/release_changeset.dart init \
  --package=explicit_outcome \
  --bump=minor \
  --summary="Add typed outcome map helper"
```

This creates a boilerplate file in `.changesets/`.

## Bump levels

| Level | When to use |
|---|---|
| `patch` | Bug fixes, internal refactors with no API change |
| `minor` | New backwards-compatible API additions |
| `major` | Breaking API changes (requires protected Environment approval) |

## Release flow

1. PR includes changeset(s) declaring release intent.
2. CI verifies publishable changes have matching changesets.
3. After merge, the release workflow converts changesets into a version PR.
4. Version PR updates `pubspec.yaml` versions and `CHANGELOG.md` entries.
5. Merging the version PR prepares for intentional tag-triggered publishing.
