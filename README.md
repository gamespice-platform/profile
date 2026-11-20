[![dot-profile - GameSpice addon](docs/banner.png)](https://moddingcommunity.com/a/270-dot-profile)

One YAML file per NPC, weapon or player class, instead of one big config.

- `DotProfileSet` lists, loads and validates all profiles of one kind.
- `DotProfile` is one loaded profile.
- `DotProfileRuntime` applies live edits on a server, gated by permission.

Features: tiers (addon, game, user, server), `extends`, `extra:` values, folder profiles with child sets, environment and command-line overrides, and a headless validator (`tools/profile_check.gd`).

## Install

1. Copy `addons/dot_profile/` and dot-core's `addons/dot_core/` into your project.
2. Enable them in *Project > Project Settings > Plugins*.

Only dot-core is required. Config paths and file formats are dot-core's:

| Tier | Path |
| --- | --- |
| Addon | `cfg/addon/<addon>/` |
| Game | `cfg/game/<game>/` |
| Server addon | `cfg/server/addon/<addon>/` |
| Server game | `cfg/server/game/<game>/` |

These classes used to live in dot-core (before API level 22); their names did not change. Full reference: [docs/profiles.md](docs/profiles.md).

## Develop

Link dot-core (`ln -s ../../dot-core/addons/dot_core addons/dot_core`), import the project once, then run the scenes in `examples/`: `profile_selftest`, `profile_runtime_selftest`, `profile_check_selftest` and `user_tier_selftest`.

## Status and licence

Part of the [**GameSpice**](https://gamespice.net) platform: a family of Godot addons. Written with Claude Code and maintained by `gamemann`. Every addon has headless tests, but little of this has been played by real users yet, so expect rough edges and please [open an issue](https://github.com/gamespice-platform/profile/issues) when you hit one.

MIT licence, see [LICENSE](LICENSE). The only closed part of the [**GameSpice**](https://gamespice.net) platform is the web back end; you can use your own instead of GameSpice's.
