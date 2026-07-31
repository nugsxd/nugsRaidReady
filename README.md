# RaidReady

A World of Warcraft **retail** addon that lets a raid leader check whether raiders
have the required addons installed at the required versions — no external program,
no filesystem access, no server.

## How it works

WoW addons run in a sandbox and cannot read the AddOns folder directly. They don't
need to: the game client already indexes every installed addon and exposes it
through the `C_AddOns` API. This addon reads its **own** machine's list that way,
and members share the relevant slice with each other over WoW's addon-message
channels.

1. Every raider installs this addon. It listens silently.
2. The leader opens the window (`/rr`), sets the **required addons** (folder name
   + optional minimum version), and clicks **Check Raid**.
3. The leader broadcasts just the required names over the `RAID` channel.
4. Each raider's copy replies (whispered back, staggered to respect Blizzard's
   message throttle) with its version for only those addons.
5. The leader sees a roster: **OK / Outdated / Missing / No version info /
   No response**.

**"No response"** means that player either doesn't have RaidReady installed
or is offline — which is itself a useful compliance signal.

## Install

Copy the `nugsRaidReady` folder into:

```
World of Warcraft\_retail_\Interface\AddOns\nugsRaidReady\
```

The folder must contain `nugsRaidReady.toc`, `Core.lua`, `Comm.lua`, `UI.lua`.
Restart the game (or `/reload`) and enable it on the character-select AddOns list.

If the game marks it **out of date**, bump `## Interface:` in the `.toc` to your
current patch. Find the number in-game with:

```
/run print((select(4, GetBuildInfo())))
```

## Usage

- `/rr` — open/close the window
- `/rr check` — run a check immediately

Only the **raid leader or an assistant** can run a check (the button is greyed
out otherwise). When solo, it's always enabled so you can test yourself.

When the leader runs a check, every raider running this addon sees a **pop-up
box on their own screen** listing the required addons and whether each one is
OK / Outdated / Missing for them — no message needed. The box tells them exactly
what to update.

Raiders on the roster who don't answer are shown as **"No addon"** (they're
online but never replied — they almost certainly don't have this addon installed)
or **"Offline"** (grey, not counted as an issue).

Optionally, tick **"Whisper players to update or install"** to whisper, when a
check finishes: out-of-date/missing raiders get *"You have out of date addons,
type /rr to view"*, and **"No addon"** players get *"Please install the Raid
Addon Audit addon..."*. Offline players are skipped (no whisper errors). Whispers
are staggered to avoid the spam filter. Off by default.

**Adding a required addon:** click **Browse...** to pick from a searchable list of
your own installed addons (this fills in the exact folder name for you), set an
optional minimum version, and click **Add**. You can also type the folder name
directly. Use the on-disk folder name, not the display name — e.g. Deadly Boss
Mods is `DBM-Core`, WeakAuras is `WeakAuras`, Details! is `Details`.

## Known limitations (v1)

- Only players running this addon can be checked (can't remotely inspect a client).
- Version strings are compared numerically (`11.2.3` → 11, 2, 3). Non-numeric
  schemes (e.g. `v1.0-beta`) fall back to "installed = OK".
- A determined user could spoof a reported version. This is a cooperation tool for
  a guild raid, not tamper-proof enforcement.
- Required list is stored per-character (SavedVariables). It is not auto-shared to
  raiders — each person just needs the addon installed; the leader defines the list.
- Duplicate first names across realms in one raid could collide (keyed by name
  without realm).

## Roadmap ideas

- Per-boss / per-role required lists
- Chunked comms if a required list ever exceeds one message
