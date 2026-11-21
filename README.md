[![Profile - GameSpice addon](docs/banner.png)](https://moddingcommunity.com/a/110-gs-profile)

One YAML file per NPC, weapon or player class, instead of one big config.

- `GSProfileSet` lists, loads and validates all profiles of one kind.
- `GSProfile` is one loaded profile.
- `GSProfileRuntime` applies live edits on a server, gated by permission.

Features: tiers (addon, game, user, server), `extends`, `extra:` values, folder profiles with child sets, environment and command-line overrides, and a headless validator (`tools/profile_check.gd`).

## Install

1. Copy `addons/gs_profile/` and GameSpice Core's `addons/gs_core/` into your project.
2. Enable them in *Project > Project Settings > Plugins*.

Only GameSpice Core is required. Config paths and file formats are GameSpice Core's:

| Tier | Path |
| --- | --- |
| Addon | `cfg/addon/<addon>/` |
| Game | `cfg/game/<game>/` |
| Server addon | `cfg/server/addon/<addon>/` |
| Server game | `cfg/server/game/<game>/` |

These classes used to live in GameSpice Core (before API level 22); their names did not change. Full reference: [docs/profiles.md](docs/profiles.md).

## Develop

Link gs-core (`ln -s ../../gs-core/addons/gs_core addons/gs_core`), import the project once, then run the scenes in `examples/`: `profile_selftest`, `profile_runtime_selftest`, `profile_check_selftest` and `user_tier_selftest`.

## Status and licence

Part of the [**GameSpice**](https://gamespice.net) platform: a family of Godot addons. Written with Claude Code and maintained by `gamemann`. Every addon has headless tests, but little of this has been played by real users yet, so expect rough edges and please [open an issue](https://github.com/gamespice-platform/profile/issues) when you hit one.

MIT licence, see [LICENSE](LICENSE). The only closed part of the [**GameSpice**](https://gamespice.net) platform is the web back end; you can use your own instead of GameSpice's.
