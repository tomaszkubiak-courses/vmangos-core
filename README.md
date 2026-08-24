# Progressive Vanilla
This project is an independent continuation of the Elysium / LightsHope codebases, focused on delivering the most complete and accurate content progression system possible, including support for the patch appropriate game clients.

### Currently supported builds
- 1.12.1.5875+
- 1.11.2.5464
- 1.10.2.5302
- 1.9.4.5086
- 1.8.4.4878
- 1.7.1.4695
- 1.6.1.4544
- 1.5.1.4449
<!--- 1.4.2.4375
- 1.3.1.4297
- 1.2.4.4222-->

### Project guidelines
- Accuracy: The point of an emulator is to recreate the functionality of that which it is emulating as closely as possible. Therefore any custom behaviour should be behind a config option and off by default.
- DB Scripting: Content should be separate from the core itself, so hardcoding scripts should be avoided where possible. When database scripting functionality is insufficient, we simply expand it.
- Full progression: The ultimate goal of this project is to have complete progression starting from patch 1.2 through 1.12. This means every piece of data must be marked with the patch in which it was added or changed to it's current state.
- Tools are great: Content creation should not require programming knowledge. We hope to eventually provide tools that allow for user-friendly editing of database scripts and content, with all data presented in human-readable form.

### Downloads
- [Latest development build](https://github.com/vmangos/core/releases/tag/latest) (Linux, macOS, and Windows)
- [Latest MySQL 5.6 development database snapshot](https://github.com/vmangos/core/releases/tag/db_latest); no updates required

### Useful Links
- [Wiki](https://github.com/vmangos/wiki)
- [Discord](https://discord.gg/x9a2jt7)
- [Script Editor](https://github.com/brotalnia/scripteditor)
- [Script Converter](https://github.com/vmangos/ScriptConverter)

### Changes

How this fork differs from upstream VMaNGOS.

**New commands**
- `.gold add <name> #g #s #c` — grants money, mirroring the existing `.gold remove`. Works on
  online and offline characters, at the same security level. Both commands now share their
  argument parsing and saturate at the money cap instead of overflowing.

**Changed commands**
- `.die` is registered at player level instead of gamemaster level, so that server owners can
  hand it out without a database edit. It is refused below gamemaster level unless the new
  `Command.DieForPlayers` option is enabled, and that option defaults to off. Behaviour is
  otherwise unchanged: it kills the selected unit, still refuses a target of equal or higher
  security, and still honours `GM.CreditOnDie`. Note that enabling it lets any player kill any
  other player they can select; setting `flags` = 1 on the `die` row of the world DB `command`
  table restricts it to the caller's own character.
- `.die` no longer kills your own character by default. The command falls back to the caller when
  nothing is selected, so that case is now refused at every security level unless the new
  `Command.DieSelfKill` option is enabled. Killing another selected unit is unaffected.

**New options**
- `Death.LockInventory` (default off) refuses every item move inside the inventory while the
  character is dead. Without it only moves involving an equipment, bag or bank slot are
  refused, and items can still be rearranged inside the bags, which is how retail behaved.
  The option covers dragging, splitting and auto storing a stack into a bag.

**Updated libraries**

The Windows dependencies vendored under `dep/windows` were badly out of date:

| Library | Was | Now |
| --- | --- | --- |
| MySQL client | 5.5.62 | 26.7.0 |
| OpenSSL | 1.0.2k (Jan 2017) | 3.5.7 |

The old MySQL client could only speak `mysql_native_password`, which newer MySQL servers no
longer offer, so connecting failed outright. OpenSSL 1.0.2 has been unsupported upstream since
the end of 2019.

Because the vendored headers are shared between architectures and cannot match two client
versions at once, the 32-bit Windows libraries were dropped rather than left stale. A 32-bit
build now fails at configure time with an explanation. `MYSQL_ROOT_DIR` was added for pointing
the build at an external MySQL client.

**Fixes**
- Out of combat health regeneration no longer stops completely at low spirit. The per class
  formula in `Unit::GetRegenHPPerSpirit` is a straight line fitted to the level 60 stat range,
  and its negative constant term drove the result below zero — where it was clamped to zero —
  for any warrior, rogue, hunter or shaman whose spirit fell far enough. Resurrection sickness
  cuts all stats by 75% and did exactly that, so a sick character regenerated no health at all;
  low level characters had the same problem without any debuff. The first 50 points of spirit
  now regenerate at their own rate and everything above them at the published slope, the way
  the client tables the fit came from are shaped. Values from 50 spirit upwards are unchanged.

**Merged upstream pull requests**

Pull requests that are still open against upstream VMaNGOS are merged here ahead of it. Several
needed corrections to apply cleanly or to work at all; those are noted with the pull request they
belong to. Six of them carry a world database migration, which has to be applied before the
server will start.

- [#1766](https://github.com/vmangos/core/pull/1766) — Alterac Valley quest rewards. Migration
  `20230114192701` gives 21 Horde quests their Frostwolf, Orgrimmar and Undercity reputation and
  corrects the experience on two of them. One statement set quest 7182's `entry` to 7181, which
  would have collided with the row that already has it; it now assigns its own entry.
- [#1903](https://github.com/vmangos/core/pull/1903) — Cenarion Circle reputation. Migration
  `20230526183338` gives the Twin Emperors and the qiraji in their room reputation, awards the
  Ahn'Qiraj Ruins adds 5 each, and retunes the bosses there to 100 for Ossirian and 50 for the
  rest, Rajaxx included, who previously gave none.
- [#2130](https://github.com/vmangos/core/pull/2130) — migration `20230727181109` renames warden
  scan 31 to record that it catches multiboxing bots as well as noclip.
- [#2150](https://github.com/vmangos/core/pull/2150) — Skeram no longer casts spell 26526 with
  True Fulfillment. The mechanic immunity it applies is not part of the 1.12 version of the
  ability.
- [#2173](https://github.com/vmangos/core/pull/2173) — auras the client hides still occupy a buff
  or debuff slot on the server, which is how the retail cap behaved. `IsNeedVisibleSlot` becomes
  `IsNeedSlot` and only passive auras without a visual are exempt, so persistent area auras that
  merely deal damage, such as Blizzard, Rain of Fire and Volley, now take a debuff slot. Merged
  against the newer aura limit code here, which counts buffs and debuffs separately.
- [#2426](https://github.com/vmangos/core/pull/2426) — party bots switch to the marked target or
  the one the party leader is attacking. As written the bot only stopped attacking on the update
  that chose the new target and picked it up on a later one, idling in between and skipping its
  class abilities for that tick; `Unit::Attack` drops the previous victim by itself, so the swap
  now happens in one update.
- [#2583](https://github.com/vmangos/core/pull/2583) — migration `20240413233003` puts the Venom
  and Necro Stalkers on a script that charges the farthest player every 8 to 12 seconds. The
  script was indented with tabs, which `.clang-format` forbids.
- [#2615](https://github.com/vmangos/core/pull/2615) — the optional GM island vendor content in
  `sql/custom` updated to the current `creature_template` layout, which it predated by enough
  columns that it could no longer be applied. [#3278](https://github.com/vmangos/core/pull/3278)
  is the same file with identical contents.
- [#2616](https://github.com/vmangos/core/pull/2616) — a race change resets the appearance,
  because the old skin, face and hair are not valid for the new race. Three corrections: the race
  is set before the default spells are relearned, since the spell list is looked up by race and
  the character was being given the spells of the race it was leaving; a `ResetSpells` call that
  discarded every trained rank, profession and recipe is gone, as the racial spells are already
  exchanged a few lines above; and clearing the facial style no longer takes the paid for bank bag
  slots with it. The appearance is now also carried over rather than reset to the first option of
  each, by mapping every component to the entry at the same position in the list of the new race,
  falling back to a random valid look when the character sections do not offer the combination.
- [#3207](https://github.com/vmangos/core/pull/3207) — waypoint movement builds one spline across
  several waypoints instead of one per waypoint, fires arrival events as the creature passes each
  recorded spline index, and lets formation members path against the leader's spline. A helper was
  declared `static` in the header, giving nine translation units a declaration of an internal
  function that only one of them defines; it now lives in the source file.
- [#3219](https://github.com/vmangos/core/pull/3219) — page text could be read for any page id,
  without owning the book or standing near the object. The code in the pull request predates the
  structured packet handler and read the trailing guid unconditionally, which throws on the client
  builds that omit it and has the anticheat kick the player, so the check was written against the
  packet instead: the guid is read only when sent, and the page must belong to an item the player
  carries or to a nearby text or goober object.
- [#3279](https://github.com/vmangos/core/pull/3279) — applying a premade gear template destroys
  what the character is wearing instead of moving it to the bags, and removes an existing copy of
  each item before granting it. Reachable from the `.premade gear` command as well as from bots
  and the test realm vendor.
- [#3290](https://github.com/vmangos/core/pull/3290) — a world buffs gossip NPC for test realms,
  handing out world buffs and consumables per class and role, with group, fire resistance and
  weapon enchant options. Its warrior tank test read as Shield Slam or both Bloodthirst and Last
  Stand, because `&&` binds tighter than `||`, and so treated a fury warrior as a tank; both
  protection talents are tested on their own now. Each greater blessing needs a caster of its own,
  since a paladin may only keep one blessing on a target, but the summon used for it was the
  vendor itself and was left visible, spawning a copy of the vendor beside itself for every
  blessing; it is hidden now.
- [#3293](https://github.com/vmangos/core/pull/3293) and
  [#3297](https://github.com/vmangos/core/pull/3297) — the warrior set and melee weapon vendor
  lists in the same optional file rewritten with explicit slots, so the items appear in a
  deliberate order.
- [#3330](https://github.com/vmangos/core/pull/3330) — battlegrounds bots drop their mount or
  shapeshift form when standing on a Warsong Gulch flag, which they previously could not pick up
  at all while shifted.
- [#3336](https://github.com/vmangos/core/pull/3336) — mage, priest and warlock bots stop wanding
  once they are back above 20% mana. The update returned early for as long as the wand was firing,
  so a bot that started wanding never reached its class abilities again for the rest of the fight.
- [#3345](https://github.com/vmangos/core/pull/3345) — hunter bot pets are drawn from the tameable
  creatures in the database rather than a list of seventeen hardcoded entries, bot pets have their
  autocastable spells switched on, and warlock bots below the level where a premade spec exists
  fall back to the summon their level allows.
- [#3515](https://github.com/vmangos/core/pull/3515) — migration `20260731074614` respawns the
  Jadefire Run with 40 spawns and a patrol. It deleted the old waypoints by creature id where
  `creature_movement` is keyed by creature guid, which emptied the waypoints of whatever unrelated
  creatures hold those guids and left the real ones behind, pointing at guids that no longer exist
  and ready to be inherited by whatever spawns there next; the guids are looked up now.
- [#3540](https://github.com/vmangos/core/pull/3540) — migration `20260823080903` splits the
  Badlands mining nodes into twelve geographic pools of one node each, in place of the two master
  pools that let seven nodes spawn anywhere in the zone.

**Other**
- `doc/BUILDING_WINDOWS.md` — a full Windows build and setup guide.
- `doc/COMMANDS.md` — every chat command with its security level, argument syntax and an example.
- The GitHub workflows and JetBrains project files were removed; this fork runs no CI.
- `sql/world_full_*.sql` is ignored, so a world database dump kept in `sql/` is not committed.
