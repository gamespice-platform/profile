extends RefCounted

## GameSpice Profile's API level. The rule for bumping it is on [GSAddonApi].
## LEVEL rises by one for anything new a game could call; OLDEST is raised to LEVEL when something callable is removed
## or changes meaning, because every pack built before then no longer compiles against this addon.

# 1: GSProfileSet, GSProfile, GSProfileRuntime and tools/profile_check.gd, moved out of
#    GameSpice Core (API level 22) with their class names, cfg paths and file formats unchanged.
# 2: GSBoxProfiles (the `box` kind).
const LEVEL := 2
const OLDEST := 1
