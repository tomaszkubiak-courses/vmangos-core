# VMaNGOS chat command reference

Every in-game / console command registered in `ChatHandler::getCommandTable()`
(`src/game/Chat/Chat.cpp`), generated from the source of this fork. 817 commands in total,
757 of which take arguments or run something directly; the rest are parent nodes that only
group sub-commands.

## How to read this document

* Commands are typed in the chat window prefixed with a dot (`.additem 2589 5`), or on the
  `mangosd` console / RA session without the dot.
* **Lvl** is the minimum account security level required (`account.gmlevel` in the realm DB):

  | Lvl | Name | 
  |-----|------|
  | 0 | Player |
  | 1 | Moderator |
  | 2 | Ticketmaster |
  | 3 | Gamemaster |
  | 4 | Basic admin |
  | 5 | Developer |
  | 6 | Administrator |
  | 7 | Console only |

  Levels and help text can be overridden per command in the world DB `command` table
  (`name`, `security`, `help`, `flags`), which is read once at startup; the values below are
  the hardcoded defaults. `.reload command` re-reads that table.
* **C** marks commands that also work from the server console or an RA connection. Commands
  without it need a logged-in character (they use your selection or your position).
* Syntax conventions: `<required>`, `[optional]`, `a|b` = pick one. Most commands that take an
  item / creature / gameobject / spell / quest / area-trigger id also accept the shift-clicked
  chat link instead of the raw id. A `[player]` argument defaults to your current target when
  omitted, and accepts an offline character name for many commands.
* Examples use placeholder ids (item 2589 = Linen Cloth, creature 299 = Defias Smuggler,
  spell 133 = Fireball). Substitute your own.

## Frequently used

```
.gm on                      # enter GM mode (immune, no aggro)
.gm fly on                  # GM flight
.gm visible off             # hide from players
.tele name Bobmage ironforge
.go xyz -8949.95 -132.49 83.53 0
.additem 2589 20            # 20x Linen Cloth into your bags
.npc spawn add 299          # spawn creature 299 permanently at your position
.gobject add 3239           # spawn gameobject 3239 permanently
.lookup creature defias     # find creature ids by name
.lookup item linen
.character level Bobmage 60
.modify speed 3             # 3x run speed on the selected player
.revive                     # resurrect the selected player
.reload creature_template   # reload one world DB table without a restart
.server info                # uptime, player count, revision
```

## Contents

* [`.account`](#account) — 13
* [`.additem`](#additem) — 1
* [`.additemset`](#additemset) — 1
* [`.ahbot`](#ahbot) — 3
* [`.angle`](#angle) — 1
* [`.announce`](#announce) — 1
* [`.anticheat`](#anticheat) — 1
* [`.antispam`](#antispam) — 5
* [`.aoedamage`](#aoedamage) — 1
* [`.auction`](#auction) — 4
* [`.aura`](#aura) — 1
* [`.ban`](#ban) — 7
* [`.baninfo`](#baninfo) — 4
* [`.bank`](#bank) — 1
* [`.banlist`](#banlist) — 4
* [`.battlebot`](#battlebot) — 9
* [`.bg`](#bg) — 4
* [`.bot`](#bot) — 9
* [`.cast`](#cast) — 5
* [`.channel`](#channel) — 3
* [`.character`](#character) — 26
* [`.charge`](#charge) — 1
* [`.cheat`](#cheat) — 21
* [`.cinematic`](#cinematic) — 4
* [`.combatstop`](#combatstop) — 1
* [`.cometome`](#cometome) — 1
* [`.commands`](#commands) — 1
* [`.cooldown`](#cooldown) — 4
* [`.damage`](#damage) — 1
* [`.debug`](#debug) — 65
* [`.deleteitem`](#deleteitem) — 1
* [`.demorph`](#demorph) — 1
* [`.deplenish`](#deplenish) — 1
* [`.die`](#die) — 1
* [`.dismount`](#dismount) — 1
* [`.distance`](#distance) — 1
* [`.escort`](#escort) — 7
* [`.event`](#event) — 6
* [`.explorecheat`](#explorecheat) — 1
* [`.fear`](#fear) — 1
* [`.freeze`](#freeze) — 1
* [`.gm`](#gm) — 7
* [`.go`](#go) — 18
* [`.gobject`](#gobject) — 21
* [`.gocorpse`](#gocorpse) — 1
* [`.gold`](#gold) — 3
* [`.goname`](#goname) — 1
* [`.gps`](#gps) — 1
* [`.group`](#group) — 5
* [`.groupgo`](#groupgo) — 1
* [`.groupinfo`](#groupinfo) — 1
* [`.groupspell`](#groupspell) — 3
* [`.guid`](#guid) — 1
* [`.guild`](#guild) — 8
* [`.help`](#help) — 1
* [`.hidearea`](#hidearea) — 1
* [`.honor`](#honor) — 6
* [`.hover`](#hover) — 1
* [`.instance`](#instance) — 12
* [`.itemmove`](#itemmove) — 1
* [`.kick`](#kick) — 1
* [`.knockback`](#knockback) — 1
* [`.learn`](#learn) — 13
* [`.levelup`](#levelup) — 1
* [`.linkgrave`](#linkgrave) — 1
* [`.list`](#list) — 13
* [`.log`](#log) — 1
* [`.lookup`](#lookup) — 28
* [`.maxskill`](#maxskill) — 1
* [`.mmap`](#mmap) — 9
* [`.modify`](#modify) — 54
* [`.mount`](#mount) — 1
* [`.movegens`](#movegens) — 1
* [`.mute`](#mute) — 1
* [`.nameaura`](#nameaura) — 1
* [`.namedie`](#namedie) — 1
* [`.namego`](#namego) — 1
* [`.neargrave`](#neargrave) — 1
* [`.notify`](#notify) — 1
* [`.npc`](#npc) — 54
* [`.partybot`](#partybot) — 20
* [`.pbcast`](#pbcast) — 3
* [`.pdump`](#pdump) — 3
* [`.pet`](#pet) — 8
* [`.pinfo`](#pinfo) — 1
* [`.pool`](#pool) — 4
* [`.possess`](#possess) — 1
* [`.pvp`](#pvp) — 1
* [`.quest`](#quest) — 5
* [`.quit`](#quit) — 1
* [`.recall`](#recall) — 1
* [`.reload`](#reload) — 113
* [`.removeriding`](#removeriding) — 1
* [`.repairitems`](#repairitems) — 1
* [`.replenish`](#replenish) — 1
* [`.reset`](#reset) — 8
* [`.respawn`](#respawn) — 1
* [`.revive`](#revive) — 1
* [`.save`](#save) — 1
* [`.saveall`](#saveall) — 1
* [`.send`](#send) — 9
* [`.server`](#server) — 20
* [`.service`](#service) — 2
* [`.setskill`](#setskill) — 1
* [`.showarea`](#showarea) — 1
* [`.sniff`](#sniff) — 1
* [`.spamer`](#spamer) — 4
* [`.spell`](#spell) — 5
* [`.stable`](#stable) — 1
* [`.start`](#start) — 1
* [`.taxicheat`](#taxicheat) — 1
* [`.tele`](#tele) — 5
* [`.ticket`](#ticket) — 25
* [`.trigger`](#trigger) — 3
* [`.unaura`](#unaura) — 1
* [`.unban`](#unban) — 4
* [`.unfreeze`](#unfreeze) — 1
* [`.unit`](#unit) — 25
* [`.unlearn`](#unlearn) — 4
* [`.unmute`](#unmute) — 1
* [`.unstuck`](#unstuck) — 1
* [`.variable`](#variable) — 1
* [`.video`](#video) — 3
* [`.wareffort`](#wareffort) — 6
* [`.wchange`](#wchange) — 1
* [`.whispers`](#whispers) — 1
* [`.world`](#world) — 4
* [`.wp`](#wp) — 5
* [`.wr`](#wr) — 1

## account

| Command | Lvl | C | Syntax | Example |
|---|---|---|---|---|
| `.account` | 0 | yes | `.account` (also a sub-command group) | |
| `.account characters` | 3 | yes | `.account characters <account>` | `.account characters testacc` |
| `.account cleardata` | 0 |  | `.account cleardata` |  |
| `.account create` | 7 | yes | `.account create <account> <password>` | `.account create testacc secret123` |
| `.account delete` | 7 | yes | `.account delete <account>` | `.account delete testacc` |
| `.account onlinelist` | 7 | yes | `.account onlinelist [limit]` | `.account onlinelist 10` |
| `.account lock` | 0 | yes | `.account lock on\|off` | `.account lock on` |
| `.account set` | 6 | yes | *(sub-commands only)* | |
| `.account set addon` | 7 | yes | `.account set addon [account] <addon level>` | `.account set addon testacc 1` |
| `.account set gmlevel` | 7 | yes | `.account set gmlevel [account] <gm level 0-7>` | `.account set gmlevel testacc 3` |
| `.account set password` | 7 | yes | `.account set password <account> <password> <password again>` | `.account set password testacc secret123 secret123` |
| `.account set locked` | 6 | yes | `.account set locked [account] <value>` | `.account set locked testacc 1` |
| `.account password` | 0 | yes | `.account password <old password> <new password> <new password again>` | `.account password secret123 secret123 secret123` |

## additem

| Command | Lvl | C | Syntax | Example |
|---|---|---|---|---|
| `.additem` | 3 |  | `.additem <item> [count]` | `.additem 2589 5` |

## additemset

| Command | Lvl | C | Syntax | Example |
|---|---|---|---|---|
| `.additemset` | 3 |  | `.additemset <itemset id>` | `.additemset 181` |

## ahbot

| Command | Lvl | C | Syntax | Example |
|---|---|---|---|---|
| `.ahbot` | 6 | yes | *(sub-commands only)* | |
| `.ahbot reload` | 6 | yes | `.ahbot reload` |  |
| `.ahbot update` | 6 | yes | `.ahbot update` |  |

## angle

| Command | Lvl | C | Syntax | Example |
|---|---|---|---|---|
| `.angle` | 1 |  | `.angle [player or creature link]` | `.angle 1` |

## announce

| Command | Lvl | C | Syntax | Example |
|---|---|---|---|---|
| `.announce` | 4 | yes | `.announce <message>` | `.announce Server restart in 5 minutes` |

## anticheat

| Command | Lvl | C | Syntax | Example |
|---|---|---|---|---|
| `.anticheat` | 2 |  | `.anticheat [player]` | `.anticheat Bobmage` |

## antispam

| Command | Lvl | C | Syntax | Example |
|---|---|---|---|---|
| `.antispam` | 2 | yes | *(sub-commands only)* | |
| `.antispam add` | 2 | yes | `.antispam add "<word>"` | `.antispam add "badword"` |
| `.antispam remove` | 4 | yes | `.antispam remove "<word>"` | `.antispam remove "badword"` |
| `.antispam replace` | 2 | yes | `.antispam replace "<from>" "<to>"` | `.antispam replace "a" "b"` |
| `.antispam removereplace` | 4 | yes | `.antispam removereplace "<from>"` | `.antispam removereplace "a"` |

## aoedamage

| Command | Lvl | C | Syntax | Example |
|---|---|---|---|---|
| `.aoedamage` | 3 |  | `.aoedamage <damage int> <max range>` | `.aoedamage 1 1` |

## auction

| Command | Lvl | C | Syntax | Example |
|---|---|---|---|---|
| `.auction` | 2 |  | `.auction` (also a sub-command group) | |
| `.auction alliance` | 2 |  | `.auction alliance` |  |
| `.auction goblin` | 2 |  | `.auction goblin` |  |
| `.auction horde` | 2 |  | `.auction horde` |  |

## aura

| Command | Lvl | C | Syntax | Example |
|---|---|---|---|---|
| `.aura` | 4 |  | `.aura <spell id> [duration ms]` | `.aura 133 30000` |

## ban

| Command | Lvl | C | Syntax | Example |
|---|---|---|---|---|
| `.ban` | 2 | yes | *(sub-commands only)* | |
| `.ban account` | 3 | yes | `.ban account <account> <ban duration> <reason>` | `.ban account testacc 30d Exploiting` |
| `.ban allip` | 6 | yes | `.ban allip <ip> [reason]` | `.ban allip 192.168.0.10 Exploiting` |
| `.ban character` | 3 | yes | `.ban character <player> <ban duration> <reason>` | `.ban character Bobmage 30d Exploiting` |
| `.ban ip` | 6 | yes | `.ban ip <ip> <ban duration> <reason>` | `.ban ip 192.168.0.10 30d Exploiting` |
| `.ban note` | 2 | yes | `.ban note [player] <reason>` | `.ban note Bobmage Exploiting` |
| `.ban warn` | 2 | yes | `.ban warn [player] <reason>` | `.ban warn Bobmage Exploiting` |

## baninfo

| Command | Lvl | C | Syntax | Example |
|---|---|---|---|---|
| `.baninfo` | 2 |  | *(sub-commands only)* | |
| `.baninfo account` | 2 | yes | `.baninfo account <account>` | `.baninfo account testacc` |
| `.baninfo character` | 2 | yes | `.baninfo character [player]` | `.baninfo character Bobmage` |
| `.baninfo ip` | 3 | yes | `.baninfo ip <ip>` | `.baninfo ip 192.168.0.10` |

## bank

| Command | Lvl | C | Syntax | Example |
|---|---|---|---|---|
| `.bank` | 2 |  | `.bank` |  |

## banlist

| Command | Lvl | C | Syntax | Example |
|---|---|---|---|---|
| `.banlist` | 2 | yes | *(sub-commands only)* | |
| `.banlist account` | 2 | yes | `.banlist account [name filter]` | `.banlist account bob` |
| `.banlist character` | 2 | yes | `.banlist character [name filter]` | `.banlist character bob` |
| `.banlist ip` | 3 | yes | `.banlist ip [ip filter]` | `.banlist ip 192.168` |

## battlebot

| Command | Lvl | C | Syntax | Example |
|---|---|---|---|---|
| `.battlebot` | 6 | yes | *(sub-commands only)* | |
| `.battlebot add` | 6 | yes | *(sub-commands only)* | |
| `.battlebot add alterac` | 6 | yes | `.battlebot add alterac <bot count>` | `.battlebot add alterac 10` |
| `.battlebot add arathi` | 6 | yes | `.battlebot add arathi <bot count>` | `.battlebot add arathi 10` |
| `.battlebot add warsong` | 6 | yes | `.battlebot add warsong <bot count>` | `.battlebot add warsong 10` |
| `.battlebot remove` | 6 |  | `.battlebot remove` |  |
| `.battlebot removeall` | 6 | yes | `.battlebot removeall` |  |
| `.battlebot showpath` | 6 |  | `.battlebot showpath` |  |
| `.battlebot showallpaths` | 6 |  | `.battlebot showallpaths` |  |

## bg

| Command | Lvl | C | Syntax | Example |
|---|---|---|---|---|
| `.bg` | 3 |  | `.bg <battleground specific command>` | `.bg start` |
| `.bg status` | 3 |  | `.bg status` |  |
| `.bg start` | 3 |  | `.bg start` |  |
| `.bg stop` | 3 |  | `.bg stop` |  |

## bot

| Command | Lvl | C | Syntax | Example |
|---|---|---|---|---|
| `.bot` | 6 | yes | *(sub-commands only)* | |
| `.bot add` | 6 | yes | `.bot add <player name>` | `.bot add Bobmage` |
| `.bot add_all` | 6 | yes | `.bot add_all` |  |
| `.bot delete` | 6 | yes | `.bot delete <player name>` | `.bot delete Bobmage` |
| `.bot info` | 6 | yes | `.bot info` |  |
| `.bot reload` | 6 | yes | `.bot reload` |  |
| `.bot stop` | 6 | yes | `.bot stop` |  |
| `.bot start` | 6 | yes | `.bot start` |  |
| `.bot ranadd` | 6 | yes | `.bot ranadd <count>` | `.bot ranadd 5` |

## cast

| Command | Lvl | C | Syntax | Example |
|---|---|---|---|---|
| `.cast` | 5 |  | `.cast <spell id> [triggered]` | `.cast 133 1` |
| `.cast back` | 5 |  | `.cast back <spell id> [triggered]` | `.cast back 133 1` |
| `.cast dist` | 5 |  | `.cast dist <spell id> <distance> [triggered]` | `.cast dist 133 2.0 1` |
| `.cast self` | 5 |  | `.cast self <spell id> [triggered]` | `.cast self 133 1` |
| `.cast target` | 5 |  | `.cast target <spell id> [triggered]` | `.cast target 133 1` |

## channel

| Command | Lvl | C | Syntax | Example |
|---|---|---|---|---|
| `.channel` | 1 |  | *(sub-commands only)* | |
| `.channel join` | 1 |  | `.channel join <channel name>` | `.channel join World` |
| `.channel leave` | 1 |  | `.channel leave <channel name>` | `.channel leave World` |

## character

| Command | Lvl | C | Syntax | Example |
|---|---|---|---|---|
| `.character` | 2 | yes | *(sub-commands only)* | |
| `.character aiinfo` | 1 | yes | `.character aiinfo` |  |
| `.character deleted` | 3 | yes | *(sub-commands only)* | |
| `.character deleted delete` | 7 | yes | `.character deleted delete <name search string>` | `.character deleted delete 1` |
| `.character deleted list` | 3 | yes | *(sub-commands only)* | |
| `.character deleted list account` | 3 | yes | `.character deleted list account <account name search string>` | `.character deleted list account 10` |
| `.character deleted list name` | 3 | yes | `.character deleted list name <character name search string>` | `.character deleted list name 1` |
| `.character deleted restore` | 4 | yes | `.character deleted restore <name search string> [new name] [account]` | `.character deleted restore 1 1 testacc` |
| `.character deleted old` | 7 | yes | `.character deleted old [keep days]` | `.character deleted old 1` |
| `.character erase` | 7 | yes | `.character erase <player>` | `.character erase Bobmage` |
| `.character level` | 5 | yes | `.character level [player] <level>` | `.character level Bobmage 60` |
| `.character rename` | 3 | yes | `.character rename [player]` | `.character rename Bobmage` |
| `.character reputation` | 2 | yes | `.character reputation [player]` | `.character reputation Bobmage` |
| `.character hasitem` | 2 | yes | `.character hasitem <item id> [player]` | `.character hasitem 2589 Bobmage` |
| `.character race` | 4 | yes | `.character race <race id>` | `.character race 1` |
| `.character skin` | 4 | yes | `.character skin <player>` | `.character skin Bobmage` |
| `.character fillflys` | 3 | yes | `.character fillflys` |  |
| `.character premade` | 4 |  | *(sub-commands only)* | |
| `.character premade gear` | 4 |  | `.character premade gear [template id]` | `.character premade gear 1` |
| `.character premade spec` | 4 |  | `.character premade spec [template id]` | `.character premade spec 1` |
| `.character premade savegear` | 5 |  | `.character premade savegear <template name>` | `.character premade savegear warrior_t1` |
| `.character premade savespec` | 5 |  | `.character premade savespec <template name>` | `.character premade savespec warrior_t1` |
| `.character clean` | 6 | yes | *(sub-commands only)* | |
| `.character clean todelete` | 6 | yes | `.character clean todelete` |  |
| `.character clean items` | 6 | yes | `.character clean items` |  |
| `.character citytitle` | 6 |  | `.character citytitle on\|off` | `.character citytitle on` |

## charge

| Command | Lvl | C | Syntax | Example |
|---|---|---|---|---|
| `.charge` | 3 |  | `.charge` |  |

## cheat

| Command | Lvl | C | Syntax | Example |
|---|---|---|---|---|
| `.cheat` | 3 |  | *(sub-commands only)* | |
| `.cheat fly` | 3 |  | `.cheat fly on\|off` | `.cheat fly on` |
| `.cheat fixedz` | 3 |  | `.cheat fixedz on\|off` | `.cheat fixedz on` |
| `.cheat beastmaster` | 3 |  | `.cheat beastmaster on\|off [player]` | `.cheat beastmaster on Bobmage` |
| `.cheat god` | 3 |  | `.cheat god on\|off [player]` | `.cheat god on Bobmage` |
| `.cheat cooldown` | 3 |  | `.cheat cooldown on\|off [player]` | `.cheat cooldown on Bobmage` |
| `.cheat casttime` | 3 |  | `.cheat casttime on\|off [player]` | `.cheat casttime on Bobmage` |
| `.cheat powercost` | 3 |  | `.cheat powercost on\|off [player]` | `.cheat powercost on Bobmage` |
| `.cheat debuffs` | 3 |  | `.cheat debuffs on\|off [player]` | `.cheat debuffs on Bobmage` |
| `.cheat criticals` | 3 |  | `.cheat criticals on\|off [player]` | `.cheat criticals on Bobmage` |
| `.cheat castchecks` | 3 |  | `.cheat castchecks on\|off [player]` | `.cheat castchecks on Bobmage` |
| `.cheat procs` | 3 |  | `.cheat procs on\|off [player]` | `.cheat procs on Bobmage` |
| `.cheat triggerpass` | 3 |  | `.cheat triggerpass on\|off [player]` | `.cheat triggerpass on Bobmage` |
| `.cheat ignoretriggers` | 3 |  | `.cheat ignoretriggers on\|off [player]` | `.cheat ignoretriggers on Bobmage` |
| `.cheat immunepc` | 3 |  | `.cheat immunepc on\|off [player]` | `.cheat immunepc on Bobmage` |
| `.cheat immunenpc` | 3 |  | `.cheat immunenpc on\|off [player]` | `.cheat immunenpc on Bobmage` |
| `.cheat untargetable` | 3 |  | `.cheat untargetable on\|off [player]` | `.cheat untargetable on Bobmage` |
| `.cheat waterwalk` | 3 |  | `.cheat waterwalk on\|off` | `.cheat waterwalk on` |
| `.cheat wallclimb` | 3 |  | `.cheat wallclimb on\|off` | `.cheat wallclimb on` |
| `.cheat debugtargetinfo` | 3 |  | `.cheat debugtargetinfo on\|off [player]` | `.cheat debugtargetinfo on Bobmage` |
| `.cheat status` | 3 |  | `.cheat status [player]` | `.cheat status Bobmage` |

## cinematic

| Command | Lvl | C | Syntax | Example |
|---|---|---|---|---|
| `.cinematic` | 5 |  | *(sub-commands only)* | |
| `.cinematic addwp` | 5 |  | `.cinematic addwp <cinematic id> <timer ms> <comment>` | `.cinematic addwp 1 5000 start of scene` |
| `.cinematic gotime` | 5 |  | `.cinematic gotime <cinematic id> <time ms>` | `.cinematic gotime 1 5000` |
| `.cinematic listwp` | 5 |  | `.cinematic listwp` |  |

## combatstop

| Command | Lvl | C | Syntax | Example |
|---|---|---|---|---|
| `.combatstop` | 3 |  | `.combatstop [player]` | `.combatstop Bobmage` |

## cometome

| Command | Lvl | C | Syntax | Example |
|---|---|---|---|---|
| `.cometome` | 3 |  | `.cometome` |  |

## commands

| Command | Lvl | C | Syntax | Example |
|---|---|---|---|---|
| `.commands` | 0 | yes | `.commands` |  |

## cooldown

| Command | Lvl | C | Syntax | Example |
|---|---|---|---|---|
| `.cooldown` | 3 |  | *(sub-commands only)* | |
| `.cooldown list` | 3 |  | `.cooldown list` |  |
| `.cooldown clear` | 3 |  | `.cooldown clear [spell id]` | `.cooldown clear 133` |
| `.cooldown clearclientside` | 3 |  | `.cooldown clearclientside` |  |

## damage

| Command | Lvl | C | Syntax | Example |
|---|---|---|---|---|
| `.damage` | 3 |  | `.damage <damage int> <school>` | `.damage 1 1` |

## debug

| Command | Lvl | C | Syntax | Example |
|---|---|---|---|---|
| `.debug` | 2 | yes | *(sub-commands only)* | |
| `.debug anim` | 3 |  | `.debug anim <emote id>` | `.debug anim 4` |
| `.debug bg` | 6 | yes | `.debug bg` |  |
| `.debug bytes1` | 5 | yes | `.debug bytes1 <offset> <value>` | `.debug bytes1 1 1` |
| `.debug bytes2` | 5 | yes | `.debug bytes2 <offset> <value>` | `.debug bytes2 1 1` |
| `.debug condition` | 2 |  | `.debug condition <condition id>` | `.debug condition 1` |
| `.debug getitemstate` | 5 |  | `.debug getitemstate unchanged\|changed\|new\|removed\|queue\|all` | `.debug getitemstate unchanged` |
| `.debug lrecipient` | 3 |  | `.debug lrecipient` |  |
| `.debug getitemvalue` | 5 |  | `.debug getitemvalue <item guid> <field index>` | `.debug getitemvalue 1 10` |
| `.debug getvaluebyindex` | 5 |  | `.debug getvaluebyindex <field index>` | `.debug getvaluebyindex 10` |
| `.debug getvaluebyname` | 5 |  | `.debug getvaluebyname <field name>` | `.debug getvaluebyname UNIT_FIELD_HEALTH` |
| `.debug getprevplaytime` | 5 |  | `.debug getprevplaytime` |  |
| `.debug moditemvalue` | 5 |  | `.debug moditemvalue <item guid> <field index> <value>` | `.debug moditemvalue 1 10 1` |
| `.debug modvalue` | 5 |  | `.debug modvalue <field index> <u\|i\|f> <value>` | `.debug modvalue 10 u 1` |
| `.debug play` | 2 |  | *(sub-commands only)* | |
| `.debug play cinematic` | 2 |  | `.debug play cinematic <cinematic id>` | `.debug play cinematic 1` |
| `.debug play sound` | 2 |  | `.debug play sound <sound id>` | `.debug play sound 1204` |
| `.debug play text` | 2 |  | `.debug play text <text id>` | `.debug play text 1` |
| `.debug play music` | 2 |  | `.debug play music <sound id> [player]` | `.debug play music 1204 Bobmage` |
| `.debug send` | 3 |  | *(sub-commands only)* | |
| `.debug send buyerror` | 5 |  | `.debug send buyerror <buy error id>` | `.debug send buyerror 1` |
| `.debug send channelnotify` | 5 |  | `.debug send channelnotify <notify code>` | `.debug send channelnotify 1` |
| `.debug send chatmmessage` | 5 |  | `.debug send chatmmessage <type>` | `.debug send chatmmessage 1` |
| `.debug send equiperror` | 5 |  | `.debug send equiperror <equip error id>` | `.debug send equiperror 1` |
| `.debug send opcode` | 5 |  | `.debug send opcode` |  |
| `.debug send poi` | 5 |  | `.debug send poi <icon> <flags>` | `.debug send poi 1 1` |
| `.debug send qpartymsg` | 5 |  | `.debug send qpartymsg <message id>` | `.debug send qpartymsg 1` |
| `.debug send qinvalidmsg` | 5 |  | `.debug send qinvalidmsg <invalid quest message id>` | `.debug send qinvalidmsg 1` |
| `.debug send mailerror` | 5 |  | `.debug send mailerror <mail id> <mail action> <mail error>` | `.debug send mailerror 1 1 1` |
| `.debug send sellerror` | 5 |  | `.debug send sellerror <sell error id>` | `.debug send sellerror 1` |
| `.debug send spellfail` | 5 |  | `.debug send spellfail <failnum> [failarg1] [failarg2]` | `.debug send spellfail 10 1 1` |
| `.debug send visual` | 5 | yes | `.debug send visual <spell id>` | `.debug send visual 133` |
| `.debug send chanvisual` | 5 | yes | `.debug send chanvisual <spell id, 0 = stop>` | `.debug send chanvisual 1` |
| `.debug send chanvisualnext` | 5 | yes | `.debug send chanvisualnext <spell id, -1 = stop>` | `.debug send chanvisualnext 1` |
| `.debug send impact` | 5 | yes | `.debug send impact <spell id>` | `.debug send impact 133` |
| `.debug send openbag` | 3 |  | `.debug send openbag` |  |
| `.debug send worldstate` | 5 |  | `.debug send worldstate <field> <value>` | `.debug send worldstate 10 1` |
| `.debug setaurastate` | 5 |  | `.debug setaurastate <state>` | `.debug setaurastate 1` |
| `.debug setitemvalue` | 5 |  | `.debug setitemvalue <item guid> <field index> <value>` | `.debug setitemvalue 1 10 1` |
| `.debug setvaluebyindex` | 5 |  | `.debug setvaluebyindex <field index> <u\|i\|f> <value>` | `.debug setvaluebyindex 10 u 1` |
| `.debug setvaluebyname` | 5 |  | `.debug setvaluebyname <field name> <value>` | `.debug setvaluebyname UNIT_FIELD_HEALTH 1` |
| `.debug setprevplaytime` | 5 |  | `.debug setprevplaytime <seconds>` | `.debug setprevplaytime 1` |
| `.debug spellcheck` | 7 | yes | `.debug spellcheck` |  |
| `.debug spellcoefs` | 5 | yes | `.debug spellcoefs <spell id>` | `.debug spellcoefs 133` |
| `.debug spellmods` | 5 |  | `.debug spellmods <type> <effect index> <spellmodop> <value>` | `.debug spellmods 1 10 1 1` |
| `.debug forceupdate` | 5 |  | `.debug forceupdate <field index>` | `.debug forceupdate 10` |
| `.debug los` | 5 |  | `.debug los` |  |
| `.debug los check` | 5 |  | `.debug los check` |  |
| `.debug los allow` | 5 |  | `.debug los allow on\|off` | `.debug los allow on` |
| `.debug moveto` | 3 |  | `.debug moveto <move flags, hex>` | `.debug moveto 1` |
| `.debug movedistance` | 5 |  | `.debug movedistance <distance>` | `.debug movedistance 2.0` |
| `.debug faceme` | 3 |  | `.debug faceme` |  |
| `.debug assert` | 6 | yes | `.debug assert` |  |
| `.debug pvpcredit` | 5 |  | `.debug pvpcredit` |  |
| `.debug unitstate` | 3 |  | `.debug unitstate <unit stat>` | `.debug unitstate 1` |
| `.debug control` | 3 |  | `.debug control on\|off` | `.debug control on` |
| `.debug monster` | 3 |  | `.debug monster <chat type>` | `.debug monster 1` |
| `.debug time` | 6 | yes | `.debug time <rate>` | `.debug time 2.0` |
| `.debug moveflags` | 3 |  | `.debug moveflags <flags>` | `.debug moveflags 1` |
| `.debug movespline` | 3 |  | `.debug movespline` |  |
| `.debug movemotion` | 5 |  | `.debug movemotion <movetype>` | `.debug movemotion 1` |
| `.debug factionchange_items` | 6 | yes | `.debug factionchange_items` |  |
| `.debug loottable` | 5 | yes | `.debug loottable <loot table name> <loot id> [simulation count]` | `.debug loottable 1 1 10` |
| `.debug utf8overflow` | 6 | yes | `.debug utf8overflow` |  |
| `.debug chatfreeze` | 6 | yes | `.debug chatfreeze` |  |

## deleteitem

| Command | Lvl | C | Syntax | Example |
|---|---|---|---|---|
| `.deleteitem` | 3 |  | `.deleteitem <item> [count] [player]` | `.deleteitem 2589 5 Bobmage` |

## demorph

| Command | Lvl | C | Syntax | Example |
|---|---|---|---|---|
| `.demorph` | 3 |  | `.demorph` |  |

## deplenish

| Command | Lvl | C | Syntax | Example |
|---|---|---|---|---|
| `.deplenish` | 3 |  | `.deplenish` |  |

## die

| Command | Lvl | C | Syntax | Example |
|---|---|---|---|---|
| `.die` | 0 |  | `.die` | requires `Command.DieForPlayers = 1` below gamemaster level, and `Command.DieSelfKill = 1` to target yourself |

## dismount

| Command | Lvl | C | Syntax | Example |
|---|---|---|---|---|
| `.dismount` | 0 |  | `.dismount` |  |

## distance

| Command | Lvl | C | Syntax | Example |
|---|---|---|---|---|
| `.distance` | 1 |  | `.distance [player or creature link]` | `.distance 1` |

## escort

| Command | Lvl | C | Syntax | Example |
|---|---|---|---|---|
| `.escort` | 2 |  | *(sub-commands only)* | |
| `.escort create` | 5 |  | `.escort create <creature id> <quest id> <faction>` | `.escort create 299 45 1` |
| `.escort addwp` | 5 |  | `.escort addwp [creature id] [wait time ms] [waypoint id]` | `.escort addwp 299 5000 3` |
| `.escort modwp` | 5 |  | `.escort modwp <creature id> <waypoint id> [new wait time ms]` | `.escort modwp 299 1 5000` |
| `.escort clearwp` | 5 |  | `.escort clearwp <creature id>` | `.escort clearwp 299` |
| `.escort showwp` | 2 |  | `.escort showwp <creature id>` | `.escort showwp 299` |
| `.escort hidewp` | 2 |  | `.escort hidewp` |  |

## event

| Command | Lvl | C | Syntax | Example |
|---|---|---|---|---|
| `.event` | 3 | yes | `.event <event id>` | `.event 1` |
| `.event list` | 3 | yes | `.event list [all]` | `.event list 1` |
| `.event start` | 4 | yes | `.event start <event id>` | `.event start 1` |
| `.event stop` | 4 | yes | `.event stop <event id>` | `.event stop 1` |
| `.event enable` | 5 | yes | `.event enable <event id>` | `.event enable 1` |
| `.event disable` | 5 | yes | `.event disable <event id>` | `.event disable 1` |

## explorecheat

| Command | Lvl | C | Syntax | Example |
|---|---|---|---|---|
| `.explorecheat` | 2 |  | `.explorecheat 0\|1` | `.explorecheat 0` |

## fear

| Command | Lvl | C | Syntax | Example |
|---|---|---|---|---|
| `.fear` | 3 |  | `.fear <duration>` | `.fear 10000` |

## freeze

| Command | Lvl | C | Syntax | Example |
|---|---|---|---|---|
| `.freeze` | 2 |  | `.freeze` |  |

## gm

| Command | Lvl | C | Syntax | Example |
|---|---|---|---|---|
| `.gm` | 2 |  | `.gm on\|off` | `.gm on` |
| `.gm chat` | 1 |  | `.gm chat on\|off` | `.gm chat on` |
| `.gm fly` | 3 |  | `.gm fly on\|off` | `.gm fly on` |
| `.gm ingame` | 0 | yes | `.gm ingame` |  |
| `.gm list` | 6 | yes | `.gm list` |  |
| `.gm visible` | 2 |  | `.gm visible on\|off\|<visibility level>` | `.gm visible on 60` |
| `.gm setview` | 2 |  | `.gm setview` |  |

## go

| Command | Lvl | C | Syntax | Example |
|---|---|---|---|---|
| `.go` | 2 |  | `.go <x> <y> <z> [map id]` | `.go -8949.95 -132.49 83.53 0` |
| `.go creature` | 2 |  | `.go creature <creature guid or creature id>` | `.go creature 299` |
| `.go graveyard` | 2 |  | `.go graveyard <graveyard id>` | `.go graveyard 1` |
| `.go grid` | 2 |  | `.go grid <grid x> <grid y> [mapid]` | `.go grid 32 32 0` |
| `.go object` | 2 |  | `.go object <gameobject guid or gameobject id>` | `.go object 3239` |
| `.go target` | 2 |  | `.go target` |  |
| `.go taxinode` | 2 |  | `.go taxinode <node id>` | `.go taxinode 2` |
| `.go trigger` | 2 |  | `.go trigger <area trigger id>` | `.go trigger 1` |
| `.go zonexy` | 2 |  | `.go zonexy <x> <y> <area>` | `.go zonexy -8949.95 -132.49 1519` |
| `.go xy` | 2 |  | `.go xy <x> <y> [mapid]` | `.go xy -8949.95 -132.49 0` |
| `.go xyz` | 2 |  | `.go xyz <x> <y> <z> [mapid]` | `.go xyz -8949.95 -132.49 83.53 0` |
| `.go xyzo` | 2 |  | `.go xyzo <x> <y> <z> <orientation> [mapid]` | `.go xyzo -8949.95 -132.49 83.53 3.14 0` |
| `.go forward` | 2 |  | `.go forward <distance>` | `.go forward 2.0` |
| `.go up` | 2 |  | `.go up <distance>` | `.go up 2.0` |
| `.go relative` | 2 |  | `.go relative <forward/back> <left/right> <up/down>` | `.go relative 10 0 0` |
| `.go warsong` | 2 |  | `.go warsong` |  |
| `.go arathi` | 2 |  | `.go arathi` |  |
| `.go alterac` | 2 |  | `.go alterac` |  |

## gobject

| Command | Lvl | C | Syntax | Example |
|---|---|---|---|---|
| `.gobject` | 2 |  | *(sub-commands only)* | |
| `.gobject add` | 5 |  | `.gobject add <gameobject id> [spawntime secs]` | `.gobject add 3239 5000` |
| `.gobject tmpadd` | 3 |  | `.gobject tmpadd <gameobject id>` | `.gobject tmpadd 3239` |
| `.gobject delete` | 5 |  | `.gobject delete <gameobject guid>` | `.gobject delete 12345` |
| `.gobject move` | 3 |  | `.gobject move <gameobject guid> <x> <y> <z>` | `.gobject move 12345 -8949.95 -132.49 83.53` |
| `.gobject near` | 2 |  | `.gobject near [distance]` | `.gobject near 2.0` |
| `.gobject target` | 3 |  | `.gobject target <gameobject id>` | `.gobject target 3239` |
| `.gobject turn` | 3 |  | `.gobject turn <gameobject guid> [o]` | `.gobject turn 12345 1` |
| `.gobject info` | 2 |  | `.gobject info <gameobject guid>` | `.gobject info 12345` |
| `.gobject ufinfo` | 5 |  | `.gobject ufinfo <gameobject guid>` | `.gobject ufinfo 12345` |
| `.gobject select` | 2 |  | `.gobject select` |  |
| `.gobject despawn` | 3 |  | `.gobject despawn` |  |
| `.gobject toggle` | 3 |  | `.gobject toggle <gameobject guid>` | `.gobject toggle 12345` |
| `.gobject reset` | 3 |  | `.gobject reset` |  |
| `.gobject respawn` | 3 |  | `.gobject respawn` |  |
| `.gobject use` | 3 |  | `.gobject use` |  |
| `.gobject setgostate` | 3 |  | `.gobject setgostate <gameobject guid> <go state>` | `.gobject setgostate 12345 1` |
| `.gobject setlootstate` | 3 |  | `.gobject setlootstate <gameobject guid> <loot state>` | `.gobject setlootstate 12345 1` |
| `.gobject customanim` | 3 |  | `.gobject customanim <gameobject guid> <anim id>` | `.gobject customanim 12345 1` |
| `.gobject spawnanim` | 3 |  | `.gobject spawnanim <gameobject guid>` | `.gobject spawnanim 12345` |
| `.gobject despawnanim` | 3 |  | `.gobject despawnanim <gameobject guid>` | `.gobject despawnanim 12345` |

## gocorpse

| Command | Lvl | C | Syntax | Example |
|---|---|---|---|---|
| `.gocorpse` | 2 |  | `.gocorpse [player]` | `.gocorpse Bobmage` |

## gold

| Command | Lvl | C | Syntax | Example |
|---|---|---|---|---|
| `.gold` | 4 | yes | *(sub-commands only)* | |
| `.gold add` | 4 |  | `.gold add <player name> <gold> <silver> <copper>` | `.gold add Bobmage 5 20 50` |
| `.gold remove` | 4 |  | `.gold remove <player name> <gold> <silver> <copper>` | `.gold remove Bobmage 5 20 50` |

## goname

| Command | Lvl | C | Syntax | Example |
|---|---|---|---|---|
| `.goname` | 2 |  | `.goname [player]` | `.goname Bobmage` |

## gps

| Command | Lvl | C | Syntax | Example |
|---|---|---|---|---|
| `.gps` | 1 |  | `.gps [player or creature link]` | `.gps 1` |

## group

| Command | Lvl | C | Syntax | Example |
|---|---|---|---|---|
| `.group` | 3 | yes | *(sub-commands only)* | |
| `.group additem` | 3 |  | `.group additem <item id> [count]` | `.group additem 2589 5` |
| `.group revive` | 3 |  | `.group revive` |  |
| `.group replenish` | 3 |  | `.group replenish` |  |
| `.group summon` | 3 |  | `.group summon` |  |

## groupgo

| Command | Lvl | C | Syntax | Example |
|---|---|---|---|---|
| `.groupgo` | 2 |  | `.groupgo [player]` | `.groupgo Bobmage` |

## groupinfo

| Command | Lvl | C | Syntax | Example |
|---|---|---|---|---|
| `.groupinfo` | 2 | yes | `.groupinfo [player]` | `.groupinfo Bobmage` |

## groupspell

| Command | Lvl | C | Syntax | Example |
|---|---|---|---|---|
| `.groupspell` | 6 | yes | *(sub-commands only)* | |
| `.groupspell add` | 6 | yes | `.groupspell add <spell id> <group id>` | `.groupspell add 133 1` |
| `.groupspell rule` | 6 | yes | `.groupspell rule <group id> <rule id>` | `.groupspell rule 1 1` |

## guid

| Command | Lvl | C | Syntax | Example |
|---|---|---|---|---|
| `.guid` | 1 |  | `.guid` |  |

## guild

| Command | Lvl | C | Syntax | Example |
|---|---|---|---|---|
| `.guild` | 3 | yes | *(sub-commands only)* | |
| `.guild create` | 3 | yes | `.guild create [player] "<guild name>"` | `.guild create Bobmage "My Guild"` |
| `.guild delete` | 4 | yes | `.guild delete "<guild name>"` | `.guild delete "My Guild"` |
| `.guild invite` | 3 | yes | `.guild invite [player] "<guild name>"` | `.guild invite Bobmage "My Guild"` |
| `.guild uninvite` | 3 | yes | `.guild uninvite [player]` | `.guild uninvite Bobmage` |
| `.guild rank` | 3 | yes | `.guild rank [player] <rank>` | `.guild rank Bobmage 0` |
| `.guild rename` | 4 | yes | `.guild rename "<current name>" "<new name>"` | `.guild rename "Old Name" "New Name"` |
| `.guild showlog` | 3 | yes | `.guild showlog "<guild name>"` | `.guild showlog "My Guild"` |

## help

| Command | Lvl | C | Syntax | Example |
|---|---|---|---|---|
| `.help` | 0 | yes | `.help [command]` | `.help 1` |

## hidearea

| Command | Lvl | C | Syntax | Example |
|---|---|---|---|---|
| `.hidearea` | 2 |  | `.hidearea <area id>` | `.hidearea 12` |

## honor

| Command | Lvl | C | Syntax | Example |
|---|---|---|---|---|
| `.honor` | 3 |  | *(sub-commands only)* | |
| `.honor add` | 4 |  | `.honor add <honor amount>` | `.honor add 10` |
| `.honor addkill` | 4 |  | `.honor addkill` |  |
| `.honor show` | 2 |  | `.honor show` |  |
| `.honor setrp` | 4 |  | `.honor setrp <value>` | `.honor setrp 1` |
| `.honor reset` | 4 |  | `.honor reset` |  |

## hover

| Command | Lvl | C | Syntax | Example |
|---|---|---|---|---|
| `.hover` | 2 |  | `.hover [flag]` | `.hover 1` |

## instance

| Command | Lvl | C | Syntax | Example |
|---|---|---|---|---|
| `.instance` | 2 | yes | *(sub-commands only)* | |
| `.instance continents` | 4 | yes | `.instance continents` |  |
| `.instance getdata` | 3 |  | `.instance getdata <index>` | `.instance getdata 10` |
| `.instance setdata` | 3 |  | `.instance setdata <index> <value>` | `.instance setdata 10 1` |
| `.instance listbinds` | 3 |  | `.instance listbinds` |  |
| `.instance unbind` | 3 |  | `.instance unbind all\|<map id>` | `.instance unbind all 1` |
| `.instance groupunbind` | 4 |  | `.instance groupunbind all\|<map id>` | `.instance groupunbind all 1` |
| `.instance stats` | 4 | yes | `.instance stats` |  |
| `.instance savedata` | 4 |  | `.instance savedata` |  |
| `.instance switch` | 4 |  | `.instance switch <new instance id>` | `.instance switch 1` |
| `.instance perfinfos` | 4 |  | `.instance perfinfos` |  |
| `.instance smartrebind` | 2 |  | `.instance smartrebind on\|off` | `.instance smartrebind on` |

## itemmove

| Command | Lvl | C | Syntax | Example |
|---|---|---|---|---|
| `.itemmove` | 3 |  | `.itemmove <source slot> <destination slot>` | `.itemmove 1 1` |

## kick

| Command | Lvl | C | Syntax | Example |
|---|---|---|---|---|
| `.kick` | 2 | yes | `.kick [player]` | `.kick Bobmage` |

## knockback

| Command | Lvl | C | Syntax | Example |
|---|---|---|---|---|
| `.knockback` | 3 |  | `.knockback <horizontal speed> <vertical speed>` | `.knockback 2.0 2.0` |

## learn

| Command | Lvl | C | Syntax | Example |
|---|---|---|---|---|
| `.learn` | 5 |  | `.learn <spell id> [all]` | `.learn 133 1` |
| `.learn all` | 6 |  | `.learn all` |  |
| `.learn all_gm` | 3 |  | `.learn all_gm` |  |
| `.learn all_crafts` | 3 |  | `.learn all_crafts` |  |
| `.learn all_default` | 2 |  | `.learn all_default [player]` | `.learn all_default Bobmage` |
| `.learn all_lang` | 1 |  | `.learn all_lang` |  |
| `.learn all_myclass` | 5 |  | `.learn all_myclass` |  |
| `.learn all_myspells` | 5 |  | `.learn all_myspells` |  |
| `.learn all_mytalents` | 5 |  | `.learn all_mytalents` |  |
| `.learn all_mytaxis` | 2 |  | `.learn all_mytaxis` |  |
| `.learn all_recipes` | 3 |  | `.learn all_recipes <profession name>` | `.learn all_recipes blacksmithing` |
| `.learn all_trainer` | 3 |  | `.learn all_trainer <trainer id>` | `.learn all_trainer 1` |
| `.learn all_items` | 3 |  | `.learn all_items` |  |

## levelup

| Command | Lvl | C | Syntax | Example |
|---|---|---|---|---|
| `.levelup` | 3 |  | `.levelup [player] <levels>` | `.levelup Bobmage 5` |

## linkgrave

| Command | Lvl | C | Syntax | Example |
|---|---|---|---|---|
| `.linkgrave` | 5 |  | `.linkgrave <graveyard id> <team>` | `.linkgrave 1 alliance` |

## list

| Command | Lvl | C | Syntax | Example |
|---|---|---|---|---|
| `.list` | 2 | yes | *(sub-commands only)* | |
| `.list auras` | 2 |  | `.list auras` |  |
| `.list creature` | 2 | yes | `.list creature <creature id> [count]` | `.list creature 299 5` |
| `.list clicktomove` | 2 | yes | `.list clicktomove` |  |
| `.list exploredareas` | 2 |  | `.list exploredareas` |  |
| `.list item` | 2 | yes | `.list item <item> [count]` | `.list item 2589 5` |
| `.list object` | 2 | yes | `.list object <gameobject id> [count]` | `.list object 3239 5` |
| `.list talents` | 2 |  | `.list talents` |  |
| `.list maps` | 2 | yes | `.list maps` |  |
| `.list movegens` | 2 |  | `.list movegens` |  |
| `.list hostilerefs` | 2 |  | `.list hostilerefs` |  |
| `.list threat` | 2 |  | `.list threat` |  |
| `.list visibleguids` | 2 |  | `.list visibleguids` |  |

## log

| Command | Lvl | C | Syntax | Example |
|---|---|---|---|---|
| `.log` | 3 | yes | `.log <log id>` | `.log 1` |

## lookup

| Command | Lvl | C | Syntax | Example |
|---|---|---|---|---|
| `.lookup` | 1 | yes | *(sub-commands only)* | |
| `.lookup account` | 3 | yes | *(sub-commands only)* | |
| `.lookup account email` | 4 |  | `.lookup account email <email> [limit]` | `.lookup account email 1 10` |
| `.lookup account ip` | 4 |  | `.lookup account ip <ip search string> [limit]` | `.lookup account ip 1 10` |
| `.lookup account iponline` | 4 |  | `.lookup account iponline <ip search string> [limit]` | `.lookup account iponline 1 10` |
| `.lookup account name` | 3 |  | `.lookup account name <account> [limit]` | `.lookup account name testacc 10` |
| `.lookup area` | 2 | yes | `.lookup area <name part>` | `.lookup area linen` |
| `.lookup creature` | 2 | yes | `.lookup creature <name part>` | `.lookup creature linen` |
| `.lookup creaturemodel` | 2 | yes | `.lookup creaturemodel <display id> [export]` | `.lookup creaturemodel 448 1` |
| `.lookup event` | 2 | yes | `.lookup event <name part>` | `.lookup event linen` |
| `.lookup faction` | 2 | yes | `.lookup faction <name part>` | `.lookup faction linen` |
| `.lookup item` | 2 | yes | `.lookup item <name part>` | `.lookup item linen` |
| `.lookup itemset` | 2 | yes | `.lookup itemset <name part>` | `.lookup itemset linen` |
| `.lookup object` | 2 | yes | `.lookup object <name part>` | `.lookup object linen` |
| `.lookup quest` | 2 | yes | `.lookup quest <name part>` | `.lookup quest linen` |
| `.lookup player` | 1 | yes | *(sub-commands only)* | |
| `.lookup player account` | 3 |  | `.lookup player account <account> [limit]` | `.lookup player account testacc 10` |
| `.lookup player email` | 4 |  | `.lookup player email <email> [limit]` | `.lookup player email 1 10` |
| `.lookup player ip` | 4 |  | `.lookup player ip <ip> [limit]` | `.lookup player ip 192.168.0.10 10` |
| `.lookup player name` | 1 |  | `.lookup player name <name> [limit]` | `.lookup player name 1 10` |
| `.lookup player character` | 2 |  | `.lookup player character <name> [limit]` | `.lookup player character 1 10` |
| `.lookup pool` | 2 | yes | `.lookup pool <name part>` | `.lookup pool linen` |
| `.lookup skill` | 2 | yes | `.lookup skill <name part>` | `.lookup skill linen` |
| `.lookup spell` | 2 | yes | `.lookup spell <name part>` | `.lookup spell linen` |
| `.lookup sound` | 2 | yes | `.lookup sound <name part>` | `.lookup sound linen` |
| `.lookup taxinode` | 2 | yes | `.lookup taxinode <name part>` | `.lookup taxinode linen` |
| `.lookup tele` | 2 | yes | `.lookup tele <name part>` | `.lookup tele linen` |
| `.lookup guild` | 1 | yes | `.lookup guild "<guild name>"` | `.lookup guild "My Guild"` |

## maxskill

| Command | Lvl | C | Syntax | Example |
|---|---|---|---|---|
| `.maxskill` | 3 |  | `.maxskill` |  |

## mmap

| Command | Lvl | C | Syntax | Example |
|---|---|---|---|---|
| `.mmap` | 6 |  | `.mmap on\|off` | `.mmap on` |
| `.mmap path` | 3 |  | `.mmap path [straight]` | `.mmap path 1` |
| `.mmap loc` | 3 |  | `.mmap loc` |  |
| `.mmap loadedtiles` | 3 |  | `.mmap loadedtiles` |  |
| `.mmap stats` | 3 |  | `.mmap stats` |  |
| `.mmap testarea` | 3 |  | `.mmap testarea <radius>` | `.mmap testarea 2.0` |
| `.mmap connect` | 6 |  | `.mmap connect <radius> [cancel]` | `.mmap connect 2.0 1` |
| `.mmap reload` | 6 |  | `.mmap reload` |  |
| `.mmap unload` | 6 |  | `.mmap unload` |  |

## modify

| Command | Lvl | C | Syntax | Example |
|---|---|---|---|---|
| `.modify` | 2 |  | *(sub-commands only)* | |
| `.modify hp` | 3 |  | `.modify hp <hp> <max hp>` | `.modify hp 5000 5000` |
| `.modify mana` | 3 |  | `.modify mana <mana> <max mana>` | `.modify mana 3000 3000` |
| `.modify rage` | 3 |  | `.modify rage <rage min> <rage max>` | `.modify rage 100 100` |
| `.modify energy` | 3 |  | `.modify energy <energy min> <energy max>` | `.modify energy 100 100` |
| `.modify money` | 4 |  | `.modify money <copper>` | `.modify money 50` |
| `.modify speed` | 2 |  | `.modify speed <rate 0.1-10>` | `.modify speed 2.0` |
| `.modify swim` | 2 |  | `.modify swim <rate 0.1-10>` | `.modify swim 2.0` |
| `.modify scale` | 3 |  | `.modify scale <scale 0.1-10>` | `.modify scale 2.0` |
| `.modify bwalk` | 2 |  | `.modify bwalk <rate 0.1-10>` | `.modify bwalk 2.0` |
| `.modify fly` | 2 |  | `.modify fly <rate 0.1-10>` | `.modify fly 2.0` |
| `.modify aspeed` | 2 |  | `.modify aspeed <rate 0.1-10>` | `.modify aspeed 2.0` |
| `.modify faction` | 3 |  | `.modify faction <faction id> [flag] [npcflag] [dyflag]` | `.modify faction 72 1 1 1` |
| `.modify tp` | 4 |  | `.modify tp <talent points>` | `.modify tp 1` |
| `.modify mount` | 3 |  | `.modify mount <mount display id>` | `.modify mount 2410` |
| `.modify honor` | 4 |  | `.modify honor <points\|rank\|todaykills\|yesterdaykills\|yesterdayhonor\|thisweekkills\|thisweekhonor\|lastweekkills\|lastweekhonor\|lastweekstanding\|lifetimedishonorablekills\|lifetimehonorablekills> <amount>` | `.modify honor lifetimehonorablekills 100` |
| `.modify rep` | 4 |  | `.modify rep <faction id> <amount or rank name> [delta]` | `.modify rep 72 100 1` |
| `.modify drunk` | 2 |  | `.modify drunk <drunk level 0-100>` | `.modify drunk 60` |
| `.modify exhaustion` | 3 |  | `.modify exhaustion <rest state>` | `.modify exhaustion 1` |
| `.modify emotestate` | 3 |  | `.modify emotestate <emote id>` | `.modify emotestate 4` |
| `.modify morph` | 3 |  | `.modify morph <display id>` | `.modify morph 448` |
| `.modify gender` | 3 |  | `.modify gender male\|female` | `.modify gender male` |
| `.modify strength` | 4 |  | `.modify strength <amount>` | `.modify strength 100` |
| `.modify agility` | 4 |  | `.modify agility <amount>` | `.modify agility 100` |
| `.modify stamina` | 4 |  | `.modify stamina <amount>` | `.modify stamina 100` |
| `.modify intellect` | 4 |  | `.modify intellect <amount>` | `.modify intellect 100` |
| `.modify spirit` | 4 |  | `.modify spirit <amount>` | `.modify spirit 100` |
| `.modify armor` | 4 |  | `.modify armor <amount>` | `.modify armor 100` |
| `.modify holy` | 4 |  | `.modify holy <amount>` | `.modify holy 100` |
| `.modify fire` | 4 |  | `.modify fire <amount>` | `.modify fire 100` |
| `.modify nature` | 4 |  | `.modify nature <amount>` | `.modify nature 100` |
| `.modify frost` | 4 |  | `.modify frost <amount>` | `.modify frost 100` |
| `.modify shadow` | 4 |  | `.modify shadow <amount>` | `.modify shadow 100` |
| `.modify arcane` | 4 |  | `.modify arcane <amount>` | `.modify arcane 100` |
| `.modify ap` | 4 |  | `.modify ap <amount>` | `.modify ap 100` |
| `.modify rangeap` | 4 |  | `.modify rangeap <amount>` | `.modify rangeap 100` |
| `.modify spellpower` | 4 |  | `.modify spellpower <amount>` | `.modify spellpower 100` |
| `.modify crit` | 4 |  | `.modify crit <amount>` | `.modify crit 100` |
| `.modify rangecrit` | 4 |  | `.modify rangecrit <amount>` | `.modify rangecrit 100` |
| `.modify spellcrit` | 4 |  | `.modify spellcrit <amount>` | `.modify spellcrit 100` |
| `.modify mainspeed` | 4 |  | `.modify mainspeed <amount>` | `.modify mainspeed 100` |
| `.modify offspeed` | 4 |  | `.modify offspeed <amount>` | `.modify offspeed 100` |
| `.modify rangespeed` | 4 |  | `.modify rangespeed <amount>` | `.modify rangespeed 100` |
| `.modify castspeed` | 4 |  | `.modify castspeed <amount>` | `.modify castspeed 100` |
| `.modify block` | 4 |  | `.modify block <amount>` | `.modify block 100` |
| `.modify dodge` | 4 |  | `.modify dodge <amount>` | `.modify dodge 100` |
| `.modify parry` | 4 |  | `.modify parry <amount>` | `.modify parry 100` |
| `.modify combreach` | 4 |  | `.modify combreach <value>` | `.modify combreach 1` |
| `.modify boundrad` | 4 |  | `.modify boundrad <value>` | `.modify boundrad 1` |
| `.modify xprate` | 0 |  | `.modify xprate <xp rate>` | `.modify xprate 2.0` |
| `.modify hairstyle` | 4 |  | `.modify hairstyle <hair style id>` | `.modify hairstyle 1` |
| `.modify haircolor` | 4 |  | `.modify haircolor <hair color id>` | `.modify haircolor 1` |
| `.modify skincolor` | 4 |  | `.modify skincolor <skin color id>` | `.modify skincolor 1` |
| `.modify accessories` | 4 |  | `.modify accessories <facial feature id>` | `.modify accessories 1` |

## mount

| Command | Lvl | C | Syntax | Example |
|---|---|---|---|---|
| `.mount` | 3 |  | `.mount` |  |

## movegens

| Command | Lvl | C | Syntax | Example |
|---|---|---|---|---|
| `.movegens` | 2 |  | `.movegens` |  |

## mute

| Command | Lvl | C | Syntax | Example |
|---|---|---|---|---|
| `.mute` | 1 | yes | `.mute [player] <minutes> [reason]` | `.mute Bobmage 30 Exploiting` |

## nameaura

| Command | Lvl | C | Syntax | Example |
|---|---|---|---|---|
| `.nameaura` | 4 |  | `.nameaura [player] <spell id> [duration ms]` | `.nameaura Bobmage 133 30000` |

## namedie

| Command | Lvl | C | Syntax | Example |
|---|---|---|---|---|
| `.namedie` | 3 |  | `.namedie <player>` | `.namedie Bobmage` |

## namego

| Command | Lvl | C | Syntax | Example |
|---|---|---|---|---|
| `.namego` | 2 |  | `.namego [player]` | `.namego Bobmage` |

## neargrave

| Command | Lvl | C | Syntax | Example |
|---|---|---|---|---|
| `.neargrave` | 2 |  | `.neargrave [alliance\|horde]` | `.neargrave alliance` |

## notify

| Command | Lvl | C | Syntax | Example |
|---|---|---|---|---|
| `.notify` | 4 | yes | `.notify <message>` | `.notify Server restart in 5 minutes` |

## npc

| Command | Lvl | C | Syntax | Example |
|---|---|---|---|---|
| `.npc` | 1 |  | *(sub-commands only)* | |
| `.npc additem` | 5 |  | `.npc additem <item> [maxcount] [incrtime] [itemflags]` | `.npc additem 2589 10 5000 1` |
| `.npc addweapon` | 3 |  | `.npc addweapon <item id> <slot 0-2: melee, offhand, ranged>` | `.npc addweapon 2589 0` |
| `.npc aiinfo` | 1 |  | `.npc aiinfo` |  |
| `.npc allowmove` | 3 |  | `.npc allowmove on\|off` | `.npc allowmove on` |
| `.npc allowattack` | 3 |  | `.npc allowattack on\|off` | `.npc allowattack on` |
| `.npc despawn` | 3 |  | `.npc despawn` |  |
| `.npc delitem` | 5 |  | `.npc delitem <item>` | `.npc delitem 2589` |
| `.npc evade` | 3 |  | `.npc evade` |  |
| `.npc follow` | 3 |  | `.npc follow` |  |
| `.npc unfollow` | 3 |  | `.npc unfollow` |  |
| `.npc info` | 1 |  | `.npc info` |  |
| `.npc move` | 3 |  | `.npc move [creature guid]` | `.npc move 12345` |
| `.npc playemote` | 2 |  | `.npc playemote <emote id>` | `.npc playemote 4` |
| `.npc say` | 2 |  | `.npc say <text>` | `.npc say Hello there` |
| `.npc summon` | 3 |  | `.npc summon <creature id>` | `.npc summon 299` |
| `.npc textemote` | 2 |  | `.npc textemote <text>` | `.npc textemote Hello there` |
| `.npc whisper` | 2 |  | `.npc whisper [player]` | `.npc whisper Bobmage` |
| `.npc yell` | 2 |  | `.npc yell <text>` | `.npc yell Hello there` |
| `.npc tame` | 3 |  | `.npc tame` |  |
| `.npc spawn` | 1 |  | *(sub-commands only)* | |
| `.npc spawn add` | 5 |  | `.npc spawn add <creature id>` | `.npc spawn add 299` |
| `.npc spawn addentry` | 5 |  | `.npc spawn addentry <creature id>` | `.npc spawn addentry 299` |
| `.npc spawn delete` | 5 |  | `.npc spawn delete <creature guid>` | `.npc spawn delete 12345` |
| `.npc spawn info` | 1 |  | `.npc spawn info` |  |
| `.npc spawn set` | 5 |  | *(sub-commands only)* | |
| `.npc spawn set entry` | 5 |  | `.npc spawn set entry <creature id>` | `.npc spawn set entry 299` |
| `.npc spawn set displayid` | 5 |  | `.npc spawn set displayid <display id>` | `.npc spawn set displayid 448` |
| `.npc spawn set emotestate` | 5 |  | `.npc spawn set emotestate <emote id>` | `.npc spawn set emotestate 4` |
| `.npc spawn set standstate` | 5 |  | `.npc spawn set standstate <stand state>` | `.npc spawn set standstate 1` |
| `.npc spawn set sheathstate` | 5 |  | `.npc spawn set sheathstate <sheath state>` | `.npc spawn set sheathstate 1` |
| `.npc spawn set movetype` | 5 |  | `.npc spawn set movetype idle\|random\|waypoint\|cyclic` | `.npc spawn set movetype idle` |
| `.npc spawn set wanderdistance` | 5 |  | `.npc spawn set wanderdistance <wander distance>` | `.npc spawn set wanderdistance 2.0` |
| `.npc spawn set respawntime` | 5 |  | `.npc spawn set respawntime <min seconds> <max seconds>` | `.npc spawn set respawntime 1 1` |
| `.npc spawn set deathstate` | 5 |  | `.npc spawn set deathstate on\|off` | `.npc spawn set deathstate on` |
| `.npc spawn set auras` | 5 |  | `.npc spawn set auras <spell id> [spell id ...]` | `.npc spawn set auras 133 1` |
| `.npc spawn move` | 5 |  | `.npc spawn move [creature guid]` | `.npc spawn move 12345` |
| `.npc spawn load` | 3 |  | `.npc spawn load <creature guid>` | `.npc spawn load 12345` |
| `.npc spawn unload` | 3 |  | `.npc spawn unload <creature guid>` | `.npc spawn unload 12345` |
| `.npc set` | 3 |  | *(sub-commands only)* | |
| `.npc set entry` | 3 |  | `.npc set entry <creature id>` | `.npc set entry 299` |
| `.npc set level` | 3 |  | `.npc set level <level>` | `.npc set level 60` |
| `.npc set faction` | 3 |  | `.npc set faction <faction id>` | `.npc set faction 72` |
| `.npc set flag` | 3 |  | `.npc set flag <npc flags>` | `.npc set flag 1` |
| `.npc set displayid` | 3 |  | `.npc set displayid <display id>` | `.npc set displayid 448` |
| `.npc set movetype` | 3 |  | `.npc set movetype idle\|random\|waypoint\|cyclic` | `.npc set movetype idle` |
| `.npc set wanderdistance` | 3 |  | `.npc set wanderdistance <wander distance>` | `.npc set wanderdistance 2.0` |
| `.npc set respawntime` | 3 |  | `.npc set respawntime <seconds>` | `.npc set respawntime 1` |
| `.npc set reactstate` | 3 |  | `.npc set reactstate <react state>` | `.npc set reactstate 1` |
| `.npc group` | 5 |  | *(sub-commands only)* | |
| `.npc group add` | 5 |  | `.npc group add <leader guid> [options mask]` | `.npc group add 1 1` |
| `.npc group addrel` | 5 |  | `.npc group addrel <leader guid> [options mask]` | `.npc group addrel 1 1` |
| `.npc group del` | 5 |  | `.npc group del` |  |
| `.npc group link` | 5 |  | `.npc group link <leader guid> [options mask]` | `.npc group link 1 1` |

## partybot

| Command | Lvl | C | Syntax | Example |
|---|---|---|---|---|
| `.partybot` | 6 |  | *(sub-commands only)* | |
| `.partybot add` | 6 |  | `.partybot add <value> <bot level>` | `.partybot add 1 60` |
| `.partybot clone` | 6 |  | `.partybot clone` |  |
| `.partybot load` | 6 |  | `.partybot load <player name>` | `.partybot load Bobmage` |
| `.partybot setrole` | 6 |  | `.partybot setrole tank\|healer\|dps\|meleedps\|rangedps` | `.partybot setrole tank` |
| `.partybot attackstart` | 6 |  | `.partybot attackstart` |  |
| `.partybot attackstop` | 6 |  | `.partybot attackstop` |  |
| `.partybot pull` | 6 |  | `.partybot pull <duration>` | `.partybot pull 10000` |
| `.partybot aoe` | 6 |  | `.partybot aoe` |  |
| `.partybot caststart` | 6 |  | `.partybot caststart` |  |
| `.partybot caststop` | 6 |  | `.partybot caststop` |  |
| `.partybot ccmark` | 6 |  | `.partybot ccmark star\|circle\|diamond\|triangle\|moon\|square\|cross\|skull` | `.partybot ccmark star` |
| `.partybot focusmark` | 6 |  | `.partybot focusmark star\|circle\|diamond\|triangle\|moon\|square\|cross\|skull` | `.partybot focusmark star` |
| `.partybot clearmarks` | 6 |  | `.partybot clearmarks` |  |
| `.partybot cometome` | 6 |  | `.partybot cometome` |  |
| `.partybot usegobject` | 6 |  | `.partybot usegobject` |  |
| `.partybot pause` | 6 |  | `.partybot pause` |  |
| `.partybot unpause` | 6 |  | `.partybot unpause` |  |
| `.partybot unequip` | 6 |  | `.partybot unequip <item>` | `.partybot unequip 2589` |
| `.partybot remove` | 6 |  | `.partybot remove` |  |

## pbcast

| Command | Lvl | C | Syntax | Example |
|---|---|---|---|---|
| `.pbcast` | 6 | yes | `.pbcast` |  |
| `.pbcast stats` | 6 | yes | `.pbcast stats` |  |
| `.pbcast setthreads` | 6 | yes | `.pbcast setthreads <num threads after>` | `.pbcast setthreads 10` |

## pdump

| Command | Lvl | C | Syntax | Example |
|---|---|---|---|---|
| `.pdump` | 6 | yes | *(sub-commands only)* | |
| `.pdump load` | 6 | yes | `.pdump load <file name> <account> [new character name] [new guid]` | `.pdump load dump.txt testacc Newname 42` |
| `.pdump write` | 6 | yes | `.pdump write <file name> <player name or guid>` | `.pdump write dump.txt Bobmage` |

## pet

| Command | Lvl | C | Syntax | Example |
|---|---|---|---|---|
| `.pet` | 3 | yes | *(sub-commands only)* | |
| `.pet learnspell` | 5 |  | `.pet learnspell [spell id]` | `.pet learnspell 133` |
| `.pet unlearnspell` | 5 |  | `.pet unlearnspell [spell id]` | `.pet unlearnspell 133` |
| `.pet list` | 3 | yes | `.pet list <player name>` | `.pet list Bobmage` |
| `.pet rename` | 3 | yes | `.pet rename <pet id>` | `.pet rename 1` |
| `.pet delete` | 3 | yes | `.pet delete <pet id>` | `.pet delete 1` |
| `.pet loyalty` | 3 |  | `.pet loyalty [loyalty points]` | `.pet loyalty 1` |
| `.pet info` | 1 |  | `.pet info` |  |

## pinfo

| Command | Lvl | C | Syntax | Example |
|---|---|---|---|---|
| `.pinfo` | 2 |  | `.pinfo [player]` | `.pinfo Bobmage` |

## pool

| Command | Lvl | C | Syntax | Example |
|---|---|---|---|---|
| `.pool` | 3 | yes | `.pool <pool id>` | `.pool 1` |
| `.pool list` | 3 |  | `.pool list` |  |
| `.pool update` | 6 |  | `.pool update <pool id>` | `.pool update 1` |
| `.pool spawns` | 3 |  | `.pool spawns <pool id>` | `.pool spawns 1` |

## possess

| Command | Lvl | C | Syntax | Example |
|---|---|---|---|---|
| `.possess` | 3 |  | `.possess` |  |

## pvp

| Command | Lvl | C | Syntax | Example |
|---|---|---|---|---|
| `.pvp` | 3 |  | `.pvp on\|off` | `.pvp on` |

## quest

| Command | Lvl | C | Syntax | Example |
|---|---|---|---|---|
| `.quest` | 3 |  | *(sub-commands only)* | |
| `.quest add` | 4 |  | `.quest add <quest id> [player]` | `.quest add 45 Bobmage` |
| `.quest complete` | 4 |  | `.quest complete <quest id> [player]` | `.quest complete 45 Bobmage` |
| `.quest status` | 3 |  | `.quest status <quest id> [player]` | `.quest status 45 Bobmage` |
| `.quest remove` | 3 |  | `.quest remove <quest id> [player]` | `.quest remove 45 Bobmage` |

## quit

| Command | Lvl | C | Syntax | Example |
|---|---|---|---|---|
| `.quit` | 7 | yes | `.quit` |  |

## recall

| Command | Lvl | C | Syntax | Example |
|---|---|---|---|---|
| `.recall` | 1 |  | `.recall [player]` | `.recall Bobmage` |

## reload

| Command | Lvl | C | Syntax | Example |
|---|---|---|---|---|
| `.reload` | 5 | yes | *(sub-commands only)* | |
| `.reload all` | 6 | yes | `.reload all` |  |
| `.reload all_area` | 6 | yes | `.reload all_area` |  |
| `.reload all_gossips` | 6 | yes | `.reload all_gossips` |  |
| `.reload all_item` | 6 | yes | `.reload all_item` |  |
| `.reload all_locales` | 6 | yes | `.reload all_locales` |  |
| `.reload all_loot` | 6 | yes | `.reload all_loot` |  |
| `.reload all_npc` | 6 | yes | `.reload all_npc` |  |
| `.reload all_quest` | 6 | yes | `.reload all_quest` |  |
| `.reload all_scripts` | 6 | yes | `.reload all_scripts` |  |
| `.reload all_spell` | 6 | yes | `.reload all_spell` |  |
| `.reload anticheat` | 6 | yes | `.reload anticheat` |  |
| `.reload config` | 6 | yes | `.reload config` |  |
| `.reload account_banned` | 6 | yes | `.reload account_banned` |  |
| `.reload areatrigger_involvedrelation` | 5 | yes | `.reload areatrigger_involvedrelation` |  |
| `.reload areatrigger_tavern` | 5 | yes | `.reload areatrigger_tavern` |  |
| `.reload areatrigger_teleport` | 5 | yes | `.reload areatrigger_teleport` |  |
| `.reload autobroadcast` | 6 | yes | `.reload autobroadcast` |  |
| `.reload character_pet` | 6 | yes | `.reload character_pet <pet id>` | `.reload character_pet 1` |
| `.reload cinematic_waypoints` | 5 | yes | `.reload cinematic_waypoints` |  |
| `.reload command` | 6 | yes | `.reload command` |  |
| `.reload conditions` | 5 | yes | `.reload conditions` |  |
| `.reload creature` | 5 | yes | `.reload creature` |  |
| `.reload creature_ai_events` | 5 | yes | `.reload creature_ai_events` |  |
| `.reload creature_battleground` | 5 | yes | `.reload creature_battleground` |  |
| `.reload creature_display_info_addon` | 5 | yes | `.reload creature_display_info_addon` |  |
| `.reload creature_groups` | 5 | yes | `.reload creature_groups` |  |
| `.reload creature_involvedrelation` | 5 | yes | `.reload creature_involvedrelation` |  |
| `.reload creature_loot_template` | 5 | yes | `.reload creature_loot_template` |  |
| `.reload creature_onkill_reputation` | 5 | yes | `.reload creature_onkill_reputation` |  |
| `.reload creature_questrelation` | 5 | yes | `.reload creature_questrelation` |  |
| `.reload creature_spells` | 5 | yes | `.reload creature_spells` |  |
| `.reload creature_spells_scripts` | 5 | yes | `.reload creature_spells_scripts` |  |
| `.reload creature_template` | 5 | yes | `.reload creature_template <entry id>` | `.reload creature_template 1` |
| `.reload disenchant_loot_template` | 5 | yes | `.reload disenchant_loot_template` |  |
| `.reload event_scripts` | 5 | yes | `.reload event_scripts` |  |
| `.reload exploration_basexp` | 5 | yes | `.reload exploration_basexp` |  |
| `.reload fishing_loot_template` | 5 | yes | `.reload fishing_loot_template` |  |
| `.reload game_graveyard_zone` | 5 | yes | `.reload game_graveyard_zone` |  |
| `.reload game_tele` | 5 | yes | `.reload game_tele` |  |
| `.reload game_weather` | 5 | yes | `.reload game_weather` |  |
| `.reload gameobject` | 5 | yes | `.reload gameobject` |  |
| `.reload gameobject_battleground` | 5 | yes | `.reload gameobject_battleground` |  |
| `.reload gameobject_involvedrelation` | 5 | yes | `.reload gameobject_involvedrelation` |  |
| `.reload gameobject_loot_template` | 5 | yes | `.reload gameobject_loot_template` |  |
| `.reload gameobject_questrelation` | 5 | yes | `.reload gameobject_questrelation` |  |
| `.reload gameobject_requirement` | 5 | yes | `.reload gameobject_requirement` |  |
| `.reload gameobject_scripts` | 5 | yes | `.reload gameobject_scripts` |  |
| `.reload gameobject_template` | 5 | yes | `.reload gameobject_template <entry id>` | `.reload gameobject_template 1` |
| `.reload generic_scripts` | 5 | yes | `.reload generic_scripts` |  |
| `.reload gossip_menu` | 5 | yes | `.reload gossip_menu` |  |
| `.reload gossip_menu_option` | 5 | yes | `.reload gossip_menu_option` |  |
| `.reload gossip_scripts` | 5 | yes | `.reload gossip_scripts` |  |
| `.reload instance_buff_removal` | 5 | yes | `.reload instance_buff_removal` |  |
| `.reload ip_banned` | 6 | yes | `.reload ip_banned` |  |
| `.reload item_enchantment_template` | 5 | yes | `.reload item_enchantment_template` |  |
| `.reload item_loot_template` | 5 | yes | `.reload item_loot_template` |  |
| `.reload item_required_target` | 5 | yes | `.reload item_required_target` |  |
| `.reload item_template` | 5 | yes | `.reload item_template` |  |
| `.reload locales_creature` | 5 | yes | `.reload locales_creature` |  |
| `.reload locales_gameobject` | 5 | yes | `.reload locales_gameobject` |  |
| `.reload locales_gossip_menu_option` | 5 | yes | `.reload locales_gossip_menu_option` |  |
| `.reload locales_item` | 5 | yes | `.reload locales_item` |  |
| `.reload locales_page_text` | 5 | yes | `.reload locales_page_text` |  |
| `.reload locales_points_of_interest` | 5 | yes | `.reload locales_points_of_interest` |  |
| `.reload locales_quest` | 5 | yes | `.reload locales_quest` |  |
| `.reload mail_loot_template` | 5 | yes | `.reload mail_loot_template` |  |
| `.reload mangos_string` | 5 | yes | `.reload mangos_string` |  |
| `.reload map_loot_disabled` | 5 | yes | `.reload map_loot_disabled` |  |
| `.reload map_template` | 5 | yes | `.reload map_template` |  |
| `.reload npc_gossip` | 5 | yes | `.reload npc_gossip` |  |
| `.reload npc_text` | 5 | yes | `.reload npc_text` |  |
| `.reload npc_trainer` | 5 | yes | `.reload npc_trainer` |  |
| `.reload npc_vendor` | 5 | yes | `.reload npc_vendor` |  |
| `.reload page_text` | 5 | yes | `.reload page_text` |  |
| `.reload pet_name_generation` | 5 | yes | `.reload pet_name_generation` |  |
| `.reload petitions` | 6 | yes | `.reload petitions` |  |
| `.reload pickpocketing_loot_template` | 5 | yes | `.reload pickpocketing_loot_template` |  |
| `.reload player_factionchange_items` | 5 | yes | `.reload player_factionchange_items` |  |
| `.reload player_factionchange_mounts` | 5 | yes | `.reload player_factionchange_mounts` |  |
| `.reload player_factionchange_quests` | 5 | yes | `.reload player_factionchange_quests` |  |
| `.reload player_factionchange_reputations` | 5 | yes | `.reload player_factionchange_reputations` |  |
| `.reload player_factionchange_spells` | 5 | yes | `.reload player_factionchange_spells` |  |
| `.reload points_of_interest` | 5 | yes | `.reload points_of_interest` |  |
| `.reload quest_end_scripts` | 5 | yes | `.reload quest_end_scripts` |  |
| `.reload quest_greeting` | 5 | yes | `.reload quest_greeting` |  |
| `.reload quest_start_scripts` | 5 | yes | `.reload quest_start_scripts` |  |
| `.reload quest_template` | 5 | yes | `.reload quest_template` |  |
| `.reload reference_loot_template` | 5 | yes | `.reload reference_loot_template` |  |
| `.reload reputation_reward_rate` | 5 | yes | `.reload reputation_reward_rate` |  |
| `.reload reputation_spillover_template` | 5 | yes | `.reload reputation_spillover_template` |  |
| `.reload reserved_name` | 6 | yes | `.reload reserved_name` |  |
| `.reload skill_fishing_base_level` | 5 | yes | `.reload skill_fishing_base_level` |  |
| `.reload skinning_loot_template` | 5 | yes | `.reload skinning_loot_template` |  |
| `.reload spell_area` | 5 | yes | `.reload spell_area` |  |
| `.reload spell_chain` | 5 | yes | `.reload spell_chain` |  |
| `.reload spell_disabled` | 5 | yes | `.reload spell_disabled` |  |
| `.reload spell_elixir` | 5 | yes | `.reload spell_elixir` |  |
| `.reload spell_group` | 5 | yes | `.reload spell_group` |  |
| `.reload spell_group_stack_rules` | 5 | yes | `.reload spell_group_stack_rules` |  |
| `.reload spell_learn_spell` | 5 | yes | `.reload spell_learn_spell` |  |
| `.reload spell_mod` | 5 | yes | `.reload spell_mod` |  |
| `.reload spell_pet_auras` | 5 | yes | `.reload spell_pet_auras` |  |
| `.reload spell_proc_event` | 5 | yes | `.reload spell_proc_event` |  |
| `.reload spell_proc_item_enchant` | 5 | yes | `.reload spell_proc_item_enchant` |  |
| `.reload spell_script_target` | 5 | yes | `.reload spell_script_target` |  |
| `.reload spell_scripts` | 5 | yes | `.reload spell_scripts` |  |
| `.reload spell_target_position` | 5 | yes | `.reload spell_target_position` |  |
| `.reload spell_template` | 5 | yes | `.reload spell_template` |  |
| `.reload spell_threats` | 5 | yes | `.reload spell_threats` |  |
| `.reload taxi_path_transitions` | 5 | yes | `.reload taxi_path_transitions` |  |
| `.reload trainer_greeting` | 5 | yes | `.reload trainer_greeting` |  |
| `.reload variables` | 5 | yes | `.reload variables` |  |

## removeriding

| Command | Lvl | C | Syntax | Example |
|---|---|---|---|---|
| `.removeriding` | 3 |  | `.removeriding [player]` | `.removeriding Bobmage` |

## repairitems

| Command | Lvl | C | Syntax | Example |
|---|---|---|---|---|
| `.repairitems` | 3 | yes | `.repairitems [player]` | `.repairitems Bobmage` |

## replenish

| Command | Lvl | C | Syntax | Example |
|---|---|---|---|---|
| `.replenish` | 3 |  | `.replenish` |  |

## reset

| Command | Lvl | C | Syntax | Example |
|---|---|---|---|---|
| `.reset` | 3 | yes | *(sub-commands only)* | |
| `.reset honor` | 5 | yes | `.reset honor [player]` | `.reset honor Bobmage` |
| `.reset level` | 5 | yes | `.reset level [player]` | `.reset level Bobmage` |
| `.reset spells` | 5 | yes | `.reset spells` |  |
| `.reset stats` | 5 | yes | `.reset stats [player]` | `.reset stats Bobmage` |
| `.reset talents` | 3 | yes | `.reset talents [player]` | `.reset talents Bobmage` |
| `.reset items` | 6 | yes | `.reset items [player]` | `.reset items Bobmage` |
| `.reset all` | 6 | yes | `.reset all talents` | `.reset all 1` |

## respawn

| Command | Lvl | C | Syntax | Example |
|---|---|---|---|---|
| `.respawn` | 4 |  | `.respawn` |  |

## revive

| Command | Lvl | C | Syntax | Example |
|---|---|---|---|---|
| `.revive` | 3 | yes | `.revive [player]` | `.revive Bobmage` |

## save

| Command | Lvl | C | Syntax | Example |
|---|---|---|---|---|
| `.save` | 0 |  | `.save` |  |

## saveall

| Command | Lvl | C | Syntax | Example |
|---|---|---|---|---|
| `.saveall` | 6 | yes | `.saveall` |  |

## send

| Command | Lvl | C | Syntax | Example |
|---|---|---|---|---|
| `.send` | 1 | yes | *(sub-commands only)* | |
| `.send mass` | 6 | yes | *(sub-commands only)* | |
| `.send mass items` | 6 | yes | `.send mass items <race mask> "<subject>" "<text>" <item id[:count]> [more item ids]` | `.send mass items 0xFFFFFFFF "Hello" "Mail body" 2589:10 3299` |
| `.send mass mail` | 6 | yes | `.send mass mail <race mask> "<subject>" "<text>"` | `.send mass mail 0xFFFFFFFF "Hello" "Mail body"` |
| `.send mass money` | 6 | yes | `.send mass money <race mask> "<subject>" "<text>" <copper>` | `.send mass money 0xFFFFFFFF "Hello" "Mail body" 50` |
| `.send items` | 6 | yes | `.send items <player> "<subject>" "<text>" <item id[:count]> [more item ids]` | `.send items Bobmage "Hello" "Mail body" 2589:10 3299` |
| `.send mail` | 1 | yes | `.send mail <player> "<subject>" "<text>"` | `.send mail Bobmage "Hello" "Mail body"` |
| `.send message` | 6 | yes | `.send message <player> <message>` | `.send message Bobmage Server restart in 5 minutes` |
| `.send money` | 6 | yes | `.send money <player> "<subject>" "<text>" <copper>` | `.send money Bobmage "Hello" "Mail body" 50` |

## server

| Command | Lvl | C | Syntax | Example |
|---|---|---|---|---|
| `.server` | 0 | yes | *(sub-commands only)* | |
| `.server corpses` | 6 | yes | `.server corpses` |  |
| `.server exit` | 7 | yes | `.server exit` |  |
| `.server idlerestart` | 6 | yes | `.server idlerestart <delay seconds> [exit code]` | `.server idlerestart 300 0` |
| `.server idlerestart cancel` | 6 | yes | `.server idlerestart cancel` |  |
| `.server idleshutdown` | 6 | yes | `.server idleshutdown <delay seconds> [exit code]` | `.server idleshutdown 300 0` |
| `.server idleshutdown cancel` | 6 | yes | `.server idleshutdown cancel` |  |
| `.server info` | 0 | yes | `.server info` |  |
| `.server log` | 7 | yes | *(sub-commands only)* | |
| `.server log filter` | 7 | yes | `.server log filter [name filter] on\|off` | `.server log filter bob on` |
| `.server log level` | 7 | yes | `.server log level <console level 0-4> [file level 0-4]` | `.server log level 2 3` |
| `.server motd` | 0 | yes | `.server motd` |  |
| `.server plimit` | 6 | yes | `.server plimit [<max players>\|player\|moderator\|gamemaster\|administrator\|reset]` | `.server plimit max players>` |
| `.server resetallraids` | 6 | yes | `.server resetallraids` |  |
| `.server restart` | 6 | yes | `.server restart <delay seconds> [exit code]` | `.server restart 300 0` |
| `.server restart cancel` | 6 | yes | `.server restart cancel` |  |
| `.server shutdown` | 6 | yes | `.server shutdown <delay seconds> [exit code]` | `.server shutdown 300 0` |
| `.server shutdown cancel` | 6 | yes | `.server shutdown cancel` |  |
| `.server set` | 6 | yes | *(sub-commands only)* | |
| `.server set motd` | 6 | yes | `.server set motd <message>` | `.server set motd Server restart in 5 minutes` |

## service

| Command | Lvl | C | Syntax | Example |
|---|---|---|---|---|
| `.service` | 6 | yes | *(sub-commands only)* | |
| `.service del_characters` | 6 | yes | `.service del_characters <flags> <max level> <max money> <max items> <max played time> <logout time>` | `.service del_characters 1 60 10000 1 5000 5000` |

## setskill

| Command | Lvl | C | Syntax | Example |
|---|---|---|---|---|
| `.setskill` | 3 |  | `.setskill <skill id> <level> [maxskill]` | `.setskill 164 60 1` |

## showarea

| Command | Lvl | C | Syntax | Example |
|---|---|---|---|---|
| `.showarea` | 2 |  | `.showarea <area id>` | `.showarea 12` |

## sniff

| Command | Lvl | C | Syntax | Example |
|---|---|---|---|---|
| `.sniff` | 6 |  | `.sniff on\|off` | `.sniff on` |

## spamer

| Command | Lvl | C | Syntax | Example |
|---|---|---|---|---|
| `.spamer` | 1 | yes | *(sub-commands only)* | |
| `.spamer mute` | 1 | yes | `.spamer mute <player name>` | `.spamer mute Bobmage` |
| `.spamer unmute` | 2 | yes | `.spamer unmute <player name>` | `.spamer unmute Bobmage` |
| `.spamer list` | 2 | yes | `.spamer list` |  |

## spell

| Command | Lvl | C | Syntax | Example |
|---|---|---|---|---|
| `.spell` | 3 | yes | *(sub-commands only)* | |
| `.spell effects` | 3 | yes | `.spell effects <spell id>` | `.spell effects 133` |
| `.spell info` | 3 | yes | `.spell info <spell id>` | `.spell info 133` |
| `.spell search` | 3 | yes | `.spell search <spell family name> <spell family flags, hex>` | `.spell search 1 1` |
| `.spell iconfix` | 5 | yes | `.spell iconfix <spell id>` | `.spell iconfix 133` |

## stable

| Command | Lvl | C | Syntax | Example |
|---|---|---|---|---|
| `.stable` | 2 |  | `.stable` |  |

## start

| Command | Lvl | C | Syntax | Example |
|---|---|---|---|---|
| `.start` | 0 |  | `.start` |  |

## taxicheat

| Command | Lvl | C | Syntax | Example |
|---|---|---|---|---|
| `.taxicheat` | 2 |  | `.taxicheat on\|off` | `.taxicheat on` |

## tele

| Command | Lvl | C | Syntax | Example |
|---|---|---|---|---|
| `.tele` | 2 |  | `.tele <location name>` | `.tele ironforge` |
| `.tele add` | 5 |  | `.tele add <location name>` | `.tele add ironforge` |
| `.tele del` | 5 | yes | `.tele del <location name>` | `.tele del ironforge` |
| `.tele name` | 2 | yes | `.tele name [player] <location name>` | `.tele name Bobmage ironforge` |
| `.tele group` | 2 |  | `.tele group <location name>` | `.tele group ironforge` |

## ticket

| Command | Lvl | C | Syntax | Example |
|---|---|---|---|---|
| `.ticket` | 2 | yes | `.ticket <ticket id or player name>` | `.ticket 1` |
| `.ticket assign` | 2 | yes | `.ticket assign <ticket id> <gm name>` | `.ticket assign 1 1` |
| `.ticket close` | 2 | yes | `.ticket close <ticket id>` | `.ticket close 1` |
| `.ticket closedlist` | 2 | yes | `.ticket closedlist` |  |
| `.ticket counter` | 2 |  | `.ticket counter <counter>` | `.ticket counter 0` |
| `.ticket comment` | 2 | yes | `.ticket comment <ticket id> <comment>` | `.ticket comment 1 start of scene` |
| `.ticket complete` | 2 | yes | `.ticket complete <ticket id> <response>` | `.ticket complete 1 1` |
| `.ticket delete` | 3 | yes | `.ticket delete <ticket id>` | `.ticket delete 1` |
| `.ticket escalate` | 2 |  | `.ticket escalate <ticket id>` | `.ticket escalate 1` |
| `.ticket escalatedlist` | 3 | yes | `.ticket escalatedlist` |  |
| `.ticket list` | 2 | yes | `.ticket list [category]` | `.ticket list 1` |
| `.ticket next` | 2 |  | `.ticket next` |  |
| `.ticket notify` | 2 |  | `.ticket notify on\|off` | `.ticket notify on` |
| `.ticket onlinelist` | 2 | yes | `.ticket onlinelist [category]` | `.ticket onlinelist 1` |
| `.ticket previous` | 2 |  | `.ticket previous` |  |
| `.ticket reload` | 2 | yes | `.ticket reload <ticket id>` | `.ticket reload 1` |
| `.ticket reset` | 6 | yes | `.ticket reset` |  |
| `.ticket response` | 2 | yes | *(sub-commands only)* | |
| `.ticket response reset` | 3 | yes | `.ticket response reset <ticket id>` | `.ticket response reset 1` |
| `.ticket response append` | 2 | yes | `.ticket response append <ticket id> <text>` | `.ticket response append 1 Hello there` |
| `.ticket response appendln` | 2 | yes | `.ticket response appendln <ticket id> <text>` | `.ticket response appendln 1 Hello there` |
| `.ticket togglesystem` | 6 | yes | `.ticket togglesystem` |  |
| `.ticket unassign` | 2 | yes | `.ticket unassign <ticket id>` | `.ticket unassign 1` |
| `.ticket viewid` | 2 | yes | `.ticket viewid <ticket id>` | `.ticket viewid 1` |
| `.ticket viewname` | 2 | yes | `.ticket viewname <player name>` | `.ticket viewname Bobmage` |

## trigger

| Command | Lvl | C | Syntax | Example |
|---|---|---|---|---|
| `.trigger` | 2 | yes | `.trigger <area trigger id>` | `.trigger 1` |
| `.trigger active` | 2 |  | `.trigger active` |  |
| `.trigger near` | 2 |  | `.trigger near [distance]` | `.trigger near 2.0` |

## unaura

| Command | Lvl | C | Syntax | Example |
|---|---|---|---|---|
| `.unaura` | 3 |  | `.unaura <spell id>\|all` | `.unaura 133 ` |

## unban

| Command | Lvl | C | Syntax | Example |
|---|---|---|---|---|
| `.unban` | 6 | yes | *(sub-commands only)* | |
| `.unban account` | 6 | yes | `.unban account <account> <reason>` | `.unban account testacc Exploiting` |
| `.unban character` | 6 | yes | `.unban character <player> <reason>` | `.unban character Bobmage Exploiting` |
| `.unban ip` | 6 | yes | `.unban ip <ip> <reason>` | `.unban ip 192.168.0.10 Exploiting` |

## unfreeze

| Command | Lvl | C | Syntax | Example |
|---|---|---|---|---|
| `.unfreeze` | 2 |  | `.unfreeze` |  |

## unit

| Command | Lvl | C | Syntax | Example |
|---|---|---|---|---|
| `.unit` | 1 |  | *(sub-commands only)* | |
| `.unit aiinfo` | 1 |  | `.unit aiinfo` |  |
| `.unit info` | 1 |  | `.unit info` |  |
| `.unit moveinfo` | 1 |  | `.unit moveinfo` |  |
| `.unit speedinfo` | 1 |  | `.unit speedinfo` |  |
| `.unit statinfo` | 1 |  | `.unit statinfo` |  |
| `.unit ufinfo` | 5 |  | `.unit ufinfo` |  |
| `.unit factioninfo` | 1 |  | `.unit factioninfo` |  |
| `.unit show` | 1 |  | *(sub-commands only)* | |
| `.unit show race` | 1 |  | `.unit show race` |  |
| `.unit show class` | 1 |  | `.unit show class` |  |
| `.unit show gender` | 1 |  | `.unit show gender` |  |
| `.unit show powertype` | 1 |  | `.unit show powertype` |  |
| `.unit show form` | 1 |  | `.unit show form` |  |
| `.unit show visflags` | 1 |  | `.unit show visflags` |  |
| `.unit show miscflags` | 1 |  | `.unit show miscflags` |  |
| `.unit show emotestate` | 1 |  | `.unit show emotestate` |  |
| `.unit show standstate` | 1 |  | `.unit show standstate` |  |
| `.unit show sheathstate` | 1 |  | `.unit show sheathstate` |  |
| `.unit show unitstate` | 1 |  | `.unit show unitstate` |  |
| `.unit show unitflags` | 1 |  | `.unit show unitflags` |  |
| `.unit show npcflags` | 1 |  | `.unit show npcflags` |  |
| `.unit show moveflags` | 1 |  | `.unit show moveflags` |  |
| `.unit show createspell` | 1 |  | `.unit show createspell` |  |
| `.unit show combattimer` | 1 |  | `.unit show combattimer` |  |

## unlearn

| Command | Lvl | C | Syntax | Example |
|---|---|---|---|---|
| `.unlearn` | 3 |  | `.unlearn <spell id> [all]` | `.unlearn 133 1` |
| `.unlearn all_gm` | 3 |  | `.unlearn all_gm` |  |
| `.unlearn all_crafts` | 3 |  | `.unlearn all_crafts` |  |
| `.unlearn all_recipes` | 3 |  | `.unlearn all_recipes <profession name>` | `.unlearn all_recipes blacksmithing` |

## unmute

| Command | Lvl | C | Syntax | Example |
|---|---|---|---|---|
| `.unmute` | 2 | yes | `.unmute [player]` | `.unmute Bobmage` |

## unstuck

| Command | Lvl | C | Syntax | Example |
|---|---|---|---|---|
| `.unstuck` | 0 |  | `.unstuck` |  |

## variable

| Command | Lvl | C | Syntax | Example |
|---|---|---|---|---|
| `.variable` | 5 | yes | `.variable <index> [value]` | `.variable 10 1` |

## video

| Command | Lvl | C | Syntax | Example |
|---|---|---|---|---|
| `.video` | 3 |  | `.video` (also a sub-command group) | |
| `.video expendables` | 3 |  | `.video expendables` |  |
| `.video turn` | 3 |  | `.video turn` |  |

## wareffort

| Command | Lvl | C | Syntax | Example |
|---|---|---|---|---|
| `.wareffort` | 5 | yes | *(sub-commands only)* | |
| `.wareffort info` | 5 | yes | `.wareffort info` |  |
| `.wareffort setgongtime` | 5 | yes | `.wareffort setgongtime <gong time>` | `.wareffort setgongtime 5000` |
| `.wareffort setstage` | 5 | yes | `.wareffort setstage <stage>` | `.wareffort setstage 1` |
| `.wareffort getresource` | 5 | yes | `.wareffort getresource <resource id> <team>` | `.wareffort getresource 1 alliance` |
| `.wareffort setresource` | 5 | yes | `.wareffort setresource <resource id> <resource amount> <team>` | `.wareffort setresource 1 10 alliance` |

## wchange

| Command | Lvl | C | Syntax | Example |
|---|---|---|---|---|
| `.wchange` | 4 |  | `.wchange <type> <grade>` | `.wchange 1 1` |

## whispers

| Command | Lvl | C | Syntax | Example |
|---|---|---|---|---|
| `.whispers` | 1 |  | `.whispers on\|off` | `.whispers on` |

## world

| Command | Lvl | C | Syntax | Example |
|---|---|---|---|---|
| `.world` | 6 |  | *(sub-commands only)* | |
| `.world update` | 6 |  | `.world update <world mask>` | `.world update 1` |
| `.world cansee` | 6 |  | `.world cansee` |  |
| `.world detail` | 6 |  | `.world detail` |  |

## wp

| Command | Lvl | C | Syntax | Example |
|---|---|---|---|---|
| `.wp` | 2 |  | *(sub-commands only)* | |
| `.wp show` | 2 |  | `.wp show on\|off\|info\|first\|last [db guid] [path id] [path source]` | `.wp show on 12345 1 0` |
| `.wp add` | 5 |  | `.wp add [db guid] [path id] [path source]` | `.wp add 12345 1 0` |
| `.wp modify` | 5 |  | `.wp modify waittime\|scriptid\|orientation\|del\|move [db guid] [waypoint id] [value]` | `.wp modify waittime 12345 3 1` |
| `.wp export` | 6 |  | `.wp export <file name> [db guid] [path id] [path source]` | `.wp export dump.txt 12345 1 0` |

## wr

| Command | Lvl | C | Syntax | Example |
|---|---|---|---|---|
| `.wr` | 0 |  | `.wr on\|off` | `.wr on` |

