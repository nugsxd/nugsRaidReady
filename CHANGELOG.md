# Changelog

Bump `## Version:` in `RaidReady.toc` with every change so the in-game
header reflects the loaded build.

## 0.32.6

- **Lists have a scroll bar you can grab.** They were wheel-only, which looked clean
  and meant a raid-sized list took a while to get through. Drag the thumb, or click
  the track to page toward the click. The wheel is unchanged.
- **Flyouts close when you click away from them.** The addon browser and the
  preferred-setup pickers stayed open until something was selected or the button was
  pressed again.
- Fixed: the preferred-setup picker attached itself to whichever frame its button sat
  in. When that was a scrolling pane the list was cut off at the pane edge, because a
  scroll frame clips its children.

## 0.32.5

- Whispers now go through `C_ChatInfo.SendChatMessage` rather than the bare
  `SendChatMessage` global, which retail has deprecated. Same signature, so
  behaviour is unchanged - but the global is what disappears in a later patch,
  and it is the readiness whisper that would stop working.
- Gold display prefers `C_CurrencyInfo.GetCoinTextureString` over the deprecated
  global, with the plain "%dg" formatting still there as a last resort.
- Both were found by running lua-language-server against Ketho's WoW API
  annotations - the same analysis the r/wowaddons moderators audit with. Neither
  was in the hand-written deprecation list used until now, which only ever knew
  what somebody had remembered to type into it.

## 0.32.4

- A single line in the options window - "Part of the nugs suite" - shown only when
  nugsSuite is not installed. A note, not a warning, and not a dependency: this
  addon works exactly the same on its own, and the suite is only worth having once
  you run more than one of them.
- The settings panel grows by 20px when that line is shown, since it is laid out
  in absolute offsets from the top with no bottom bar to tuck it under.

## 0.32.3

- Reports itself to nugsSuite as **nugsRaidReady** rather than RaidReady, matching
  the title change in 0.32.2.
- The minimap button no longer shows a sliver of the world between the icon and the
  tracking border. The border's hole is slightly wider than the icon was, leaving a
  thin see-through ring; there is now a dark disc behind the icon, and the icon
  itself went from 19 to 21 pixels.

## 0.32.2
- Window title bars now read "nugsRaidReady vX.Y.Z" (gold name, storm-blue version)
  to match the nugsCastBars / nugsCooldownPulse family header, replacing the old
  "RaidReady by nugs".

## 0.32.1

- Registers with **nugsSuite**, the new hub addon: it can now list this addon, open
  it, fold this minimap button into its own, and carry these settings to another
  character as part of one profile string.
- The registration is a single entry written into a plain global table. nugsSuite
  does not have to be installed for it to be harmless, and does not have to load
  first for it to be found - so nothing here changes if you never install it.
- The gold-tracking opt-in answer is marked as never exported. It is a first-launch
  question rather than a preference, and importing somebody else's answer would
  silently skip it.

## 0.32.0
- Renamed the addon folder to nugsRaidReady to match the nugs family, and the icon
  file to icon.blp. AddOns-list title is now "nugsRaidReady". Same CurseForge
  project (id unchanged), same /rr command, same in-window "RaidReady" branding.
- Note: the folder rename means WoW loads fresh SavedVariables, so settings reset
  once. Remove the old RaidReady folder when installing.

## 0.31.0
- New icon matching the nugs addon family (dark tile, accent-blue outline, bright
  glyph): a checkbox with the N and a checkmark breaking out of the corner.

## 0.30.1
- Docked popups are now anchored to the window they dock to, so they follow it when
  you move it (clamping is disabled while docked to avoid the anchor/clamp shake;
  dragging a popup loose re-enables its clamp).

## 0.30.0
- Minimap icon now uses a circular mask so it can't poke past the round border.
- Removed the animated lightning header bar (now a static accent line) to keep the
  addon lightweight - no per-frame OnUpdate on window headers.
- Rebranded to "RaidReady by nugs" (dropped "Odyns Chosen"); title, AddOns list,
  and settings footer updated.
- Fixed secondary windows (Settings, player previews) not docking beside the open
  window; docking now runs after Show so measurements are final.
- Gold tracking is opt-in on first launch, with a consent prompt; declining hides
  the Gold row entirely, and re-enabling it in Settings asks for confirmation.
- New "Check Raid Readiness" button on the Character tab (leader/assist): queries
  each raider's readiness score and shows a class-coloured roster (lowest first,
  with the group average) - just the number, not the breakdown.

## 0.29.0
- Settings: "Count gold toward readiness" toggle (Scoring section). On by default;
  turn it off to drop gold from the score and its factors renormalize.

## 0.28.2
- Item level now scores on the gap to your best gear with a 2-ilvl tolerance, so
  wearing your best reads a true 100% (the old equipped/overall ratio never hit
  exactly 100 and kept showing in the ready-check popup). Scales to zero at 15
  ilvls below your best.

## 0.28.1
- Ready-check warning popup now lists only the checks below 100% (the ones costing
  you points); fully-passed checks are hidden and the box sizes to what's left.

## 0.28.0
- Item level scoring is now self-referential: equipped vs your best available
  (overall) item level, so there's no per-tier maximum to maintain. Removed the
  "Max item level this tier" setting entirely.
- Empowerment check now scores weapons/trinkets against your own highest equipped
  item level instead of a hardcoded ceiling, so it also needs no per-patch update.

## 0.27.2
- Readiness score's consumables factor no longer counts Augment Runes or
  Healthstones (gold- and warlock-dependent). Leaders can still require and check
  them on the Consumables tab; they just don't affect the personal score.

## 0.27.1
- Readiness score now updates live on the Character panel and the standalone bar.
  Driven by events (gear, bags, durability, gold, spec, talents, equipment sets,
  group changes), debounced so bursts collapse into one recompute; both surfaces
  share a single snapshot so tooltips are only scanned once.

## 0.27.0
- Standalone readiness bar: a small always-on HUD showing your score, draggable
  and lockable, position saved. Hover for the full breakdown, click to open the
  Character tab. Toggle and lock it in Settings.
- Ready check integration: when a ready check fires, your client scores you and
  pops a warning listing your weakest checks if you're below your threshold.
- Leaders can optionally auto-whisper raiders who report below the threshold
  (off by default). Each raider is whispered at most once per ready check.
- Settings gained "Readiness bar" and "Ready check" sections (threshold defaults
  to 700).

## 0.26.1
- Added the CurseForge project id (1620095) to the .toc.

## 0.26.0
- Equipment set and talent loadout are now scored against the group you're
  actually in. Solo is no longer scored against the raid preference (you may be on
  a questing build on purpose); the tooltip shows them as "solo - not scored".
- Character tab reorganized from one flat list into Gear / Setup / Resources
  sections.

## 0.25.0
- Tier set tracking: a "Tier Set" row showing pieces equipped out of 5 and whether
  the 2pc/4pc bonus is active (green at 4pc, yellow at 2pc, orange below).
- Tier counts toward the readiness score (125 pts), scored on actual benefit -
  nothing under 2 pieces, half at 2pc, full at 4pc - since that's where the
  bonuses land.
- Reweighted to 1000: Item level 175, Consumables 175, Enchants 125, Tier set 125,
  Gems 100, Empowerment 100, Durability 75, Equipment set 50, Talent loadout 50,
  Gold 25.

## 0.24.0
- Updated for patch 12.0.7: the item level ceiling is now 298 (Mythic Sporefall,
  and Ascendant Voidcore empowered weapons/trinkets), not 289.
- Settings now takes a single "Max item level this tier" number (default 298);
  the item-level scoring target derives from it, so it's one field to bump.
- New Empowerment check (100 pts): weapons and trinkets are scored against the
  ceiling, since those slots only reach it through Voidcore empowerment.
- Reweighted to keep the total at 1000: Item level 200, Consumables 200,
  Enchants 150, Gems 100, Empowerment 100, Durability 75, Equipment set 75,
  Talent loadout 50, Gold 50.

## 0.23.1
- Readiness is now a score out of 1000 instead of a percentage.
- Added equipped item level to the score (200 pts), measured against a target item
  level that defaults to 285 (Midnight S1 caps at 289) and is editable in Settings
  so it can be retuned each tier.
- Gold reweighted: below 5000g scores zero, ramping to full credit at 25000g.
- New weights: Item level 200, Consumables 200, Enchants 175, Gems 125,
  Durability 100, Equipment set 75, Talent loadout 75, Gold 50.

## 0.23.0
- Raid Readiness summary at the top of the Character tab: a colored percentage and
  bar scoring enchants (20), consumables (25), gems (15), durability (10),
  equipment set (10), talent loadout (10) and gold (10). Hover the bar for a
  per-check breakdown.
- Only applicable checks are scored - unset preferences, no required consumables,
  or unloaded socket data are skipped and the rest are renormalized, so the score
  is never dragged down by something you haven't configured.

## 0.22.1
- Dropped wrist and cloak from the enchant check (not enchantable in Midnight).
- Gems row now detects when item tooltips aren't cached yet and shows "Hover your
  gear to load, then Refresh" in neutral blue, instead of falsely reporting no
  empty sockets from missing data.

## 0.22.0
- Character tab now checks gear: an "Enchants" row listing any enchantable slots
  missing an enchant, and a "Gems" row listing items with empty sockets. Green
  when clean, orange with the offending slot names when not.
- Enchants read from the item link; empty sockets read from tooltip data using the
  EMPTY_SOCKET_* globals, so socket detection is locale-independent and picks up
  new socket types automatically.

## 0.21.3
- Fixed docked windows shaking/stuttering. They were anchored to the other window
  while also using SetClampedToScreen, so the clamp and the anchor corrected each
  other every frame. Docking now computes an absolute on-screen position and
  anchors to UIParent, which the clamp has no reason to touch.

## 0.21.2
- Fixed the Settings window ignoring the UI scale (every other window applied it),
  which showed up as a size mismatch once Settings docked beside a scaled window.
  Its scale is applied on open so its own slider doesn't rescale mid-drag.

## 0.21.1
- Closing a secondary window now clears its manual-drag position, so reopening it
  docks beside the main window again.

## 0.21.0
- Secondary windows (Settings, and the player preview opened from the leader) now
  dock beside the open window instead of overlapping it: to the right when it fits
  on screen, flipping to the left when it doesn't, and clamped on screen either way.
- Once you drag a window yourself, it stays where you put it and is no longer
  auto-positioned.

## 0.20.2
- Dropped the tab row 8px and thickened the lightning bar to 3px so it reads as a
  feature line instead of a hairline. Window content shifted to match.

## 0.20.1
- Title bars now read "RaidReady by Odyns Chosen" as one aligned line (was a
  separate, smaller tag that sat visually offset). All windows share the title;
  the tabs convey which section you're on.

## 0.20.0
- Branded "RaidReady by Odyns Chosen" in game (AddOns list title, window headers,
  and the settings footer). Game folder name unchanged.
- Storm theme: accent recolored to lightning blue, titles to Valarjar gold, and
  header accent bars are now animated - a slow storm pulse with an occasional
  lightning strike-flash.

## 0.19.1
- Added a mismatch banner above the preferred-setup controls: warns in orange when
  your current equipment set / talent loadout doesn't match the preference for the
  group you're in, and confirms in green when it does.

## 0.19.0
- Talent Loadout(s) Ex support: reads its TalentLoadoutEx global and identifies the
  running loadout by matching the current build's export string against each saved
  loadout, since the addon stores no "active" flag. The Talent Loadout row shows
  that name, and the preferred-loadout picker lists TLE's loadouts.
- Loadout Addon row shows "(no match)" if the manager is installed but the current
  build doesn't correspond to any saved loadout.

## 0.18.0
- Character tab: set a preferred equipment set and talent loadout for Dungeon
  (party) and Raid. Based on the group you're actually in, the current Equipment
  Set / Talent Loadout rows turn green when they match and orange with
  "(want: X)" when they don't.
- Detects an installed loadout-manager addon (Talent Loadout Ex etc.) and shows
  it as "Loadout Addon".
- Added "/rr tle" (alias /rr loadoutscan): dumps a loadout addon's SavedVariables
  structure so its active loadout can be read in a future build.

## 0.17.0
- New third tab, "Character", on both leader and player sides: equipped and overall
  item level, specialization, talent loadout, equipped equipment-manager set,
  durability, and gold on this character. Has a Refresh button.
- Tabs relabeled (Addons / Consumables / Character) and now size to their window;
  player windows widened to fit three tabs.

## 0.16.3
- Player check view now shows only the consumables you actually have per category
  (like My Consumables); if you have none in a required category, it lists that
  category's items as options so you know what qualifies.

## 0.16.2
- Removed the version from window headers (still shown in Settings).
- Player consumable windows now size to actual content pixels, so the category
  list no longer scrolls a few px short.
- Trimmed dead space below the last category on the leader consumables config.

## 0.16.1
- Settings pane polished: icon + title, Display section, version, "Developed by
  nugs", and a copyright line. UI scale range widened to 75%-200% (default 100%).
- Removed "by nugs" from window headers and moved the gear next to the close button.

## 0.16.0
- Settings panel (gear icon in the window header, or /rr settings): toggle the
  minimap button and set a UI scale (70-160%) for the whole addon.
- Result lists now fit up to a 40-person raid and add a little slack so the last
  row isn't clipped into a scroll. Re-fits as responses arrive.
- Moved the minimap toggle out of the main window into Settings.

## 0.15.0
- Player/raider windows (addon check, consumable check, and the pre-raid view) now
  auto-size to their content so they don't scroll unless very long (capped at 30).
- Player names in the leader roster are colored by class.

## 0.14.0
- Leader results area now auto-sizes to the group: a few rows solo, ~5 in a party,
  and up to a full 20-25 raid roster without scrolling. Applies to both the addon
  and consumables result lists.

## 0.13.2
- Merged Weapon Oils and Sharpening/Weightstones into one "Weapon Enhancement"
  category (pass with any oil or stone).

## 0.13.1
- Pre-raid "My Consumables" view: lists every category, showing only the items you
  actually have; a category you have nothing in just shows "none". Added a
  "My Consumables" button on the leader's consumables tab to open it, and it's the
  player tab's default before any check.

## 0.13.0
- Consumables are now required by CATEGORY, not individual item. Leader ticks a
  category (e.g. Flasks); a raider passes it by carrying any item in it, and only
  fails with none.
- Player view groups by category and lists the items that qualify (with counts),
  so raiders can see what they're missing before a raid.
- Leader can preview their own via Preview Player View. (SavedVariables changed to
  requiredCategories — reselect your categories once.)

## 0.12.1
- Player Consumables tab now defaults to showing what's in your bags (before any
  check is run), switching to the required/pass-fail view once a check happens.
- Fixed the rank icon showing as a box: uses WoW's crafting-quality star atlas
  with a "5*"/"4*" text fallback.

## 0.12.0
- Raid Consumables checking. Both the leader window and the player window are now
  tabbed: **Raid Addons** / **Raid Consumables**.
- Leader picks required consumables from curated preset lists (Flasks, Combat
  Potions, Healing Potions, Weapon Oils, Sharpening/Weightstones, Augment Runes,
  Healthstones). Check Raid reports who is missing what.
- Player view shows each required consumable with the count of the highest rank
  they carry (5* else 4*); compliant if they have at least one.
- Consumable item IDs are drafted from Midnight data and STILL NEED IN-GAME
  VERIFICATION with /rr ids (Healthstone uses 5512 as a placeholder).

## 0.11.0
- Groundwork for Raid Consumables checking. Added a verification helper: "/rr ids"
  toggles item IDs onto item tooltips, for capturing exact consumable item IDs
  (including each quality rank) when building the preset lists.

## 0.10.1
- Minimap button now positions from the minimap's current size/shape instead of a
  fixed radius, so it works with resized/reshaped minimaps.

## 0.10.0
- Added a "Preview Player View" button to the leader window so you can see the
  player-facing check screen solo (uses your own required list + installed addons).
- The player-facing screen now shows the version in its header.
- Added a draggable minimap button (click to open; drag to reposition; position
  persists) with a "Minimap button" show/hide toggle in the leader window.

## 0.9.3
- New icon art (cleaner winged-RR + check, no small text) encoded to DXT5 BLP.

## 0.9.2
- Fixed the icon: the supplied art was actually an ICO (WoW can't read it). Converted
  to a true PNG, then encoded a proper DXT5 BLP2 with mipmaps using a real DXT
  compressor — the standard WoW UI-icon format. Verified by round-trip decode.

## 0.9.1
- Rebuilt the icon BLP from the 512px source PNG with a full mipmap chain
  (64/32/16/8/4/2/1). (Superseded by 0.9.2 — the earlier hand-rolled uncompressed
  BLP header wasn't read correctly by retail.)

## 0.9.0
- Renamed the addon to **RaidReady** (folder, .toc, frames, SavedVariables, and
  UI text). In-game command is now **/rr** (alias /raidready).
- Icon converted to native BLP (raidready.blp) for reliable rendering; the earlier
  TGA didn't load in retail.
- Note: SavedVariables key changed to RaidReadyDB, so required lists set under the
  old name won't carry over (re-add them once).

## 0.8.1
- Custom icon: converted the supplied raidready.ico to a 64x64 texture for the
  AddOns-list icon and both window headers. (Superseded by BLP in 0.9.0.)

## 0.8.0
- Non-responders are now split by online status: "No addon" (online but silent =
  almost certainly missing the addon) vs "Offline" (grey, neutral, not counted).
- Auto-whisper now also asks "No addon" players to install the addon; offline
  players are skipped so there are no whisper errors.
- Whisper toggle relabeled "Whisper players to update or install".

## 0.7.0
- Branding: authored by nugs; spyglass icon in the addon list and window headers.
- "by nugs" shown in both window headers.
- Added LICENSE (All Rights Reserved) and copyright notices in every source file
  and the .toc.

## 0.6.1
- Fixed having to type /rr twice on first open (windows now start hidden).

## 0.6.0
- Whisper to offenders simplified to: "You have out of date addons, type /rr to view".
- `/rr` is now role-aware: raid leaders/assistants get the full management window;
  regular raiders get only their own status box (with an empty state before any check).

## 0.5.0
- Raider self-view: when a leader runs a check, each raider sees a local pop-up
  listing required addons and their own OK / Outdated / Missing status.
- Leader broadcast now includes minimum versions so raiders can self-evaluate.
- Refactored evaluation into a shared `EvaluateAgainst(required, reported)`.
- Version now shown in the window header.

## 0.4.0
- Leader-only gate: "Check Raid" restricted to raid leader/assistant (live-updating).
- Optional auto-whisper offenders with a specific fix list (staggered; off by default).

## 0.3.0
- "Use mine" button and Browse picker now prefill the min version from your
  installed copy of the addon.

## 0.2.0
- Flat, ElvUI-style dark theme.
- "Browse..." installed-addon picker (searchable) to avoid folder-name typos.

## 0.1.0
- Initial build: enumerate installed addons via C_AddOns, in-game required list,
  addon-message request/report protocol, compliance roster UI.
