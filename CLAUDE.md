# GameSpice Profile

`GSProfileSet`, `GSProfile` and `GSProfileRuntime`: per-entity yml profiles, split out of gs-core at its API level 22. Read the family [CLAUDE.md](../../CLAUDE.md) first; this file is only what is specific here.

**Only GameSpice Core is a dependency** (>= 21), linked in `.gitignore` for the suites. GameSpice Core must never name these classes; what both need (`GSAddonConfig.merge`, `set_nested`, `is_finite_value`, `check_field`, `GSYaml.emit`, the user-tier flag) lives in GameSpice Core.

## Read before

| Read | Before |
| --- | --- |
| [docs/README.md](docs/README.md) | the index |
| [docs/profiles.md](docs/profiles.md) | any change to tiers, `extends`, folders, overrides, the user tier or the validator |

## Layout

| Path | What |
| --- | --- |
| `addons/gs_profile/core/gs_profile_set.gd`, `gs_profile.gd` | the set (tiers read weakest first, schema, `extends`, `extra:`, folders, overrides) and one loaded profile |
| `addons/gs_profile/core/gs_profile_runtime.gd` | permission-gated, validated, replicated live edits; save to the server layer |
| | `add` and `delete` ops: a new profile lives in the runtime layer until saved; a delete removes the server file and, for a profile a lower tier ships, writes a `<id>.deleted` marker beside it that hides it (adding the id again removes the marker) |
| `addons/gs_profile/tools/profile_check.gd` | headless validator (no `class_name`): `-- <repo> [--schema script] [--skip-unknown]`; gs-ci `profiles: true` |
| `examples/` | `profile_selftest`, `profile_runtime_selftest`, `profile_check_selftest`, `user_tier_selftest` |

`GSProfileSet.user_tier_enabled` reads `GSAddonConfig.user_tier_enabled`; there is one flag.
