# Mission 1 encounter plan (draft for Game-boy's approval)

SPEC §9's encounter table, from the reference screens in `dd2-nes-mission1/` (layout and pacing only). One block per arena, in level order. "Behind" means a spawn point behind the player as he walks in.

**Arcs** (Game-boy's attack arcs): Punk 90°, veteran Punk 140°, Pipe Thug 140°, Bruiser 180°, Boss 270°, Kicker 360° (the one that circles behind you).

**Barriers:** every arena closes ahead and behind and opens on the last wave's clear with a "GO →" cue. Where a stair joins two arenas, the barrier is at the top of the stair, so the stair belongs to the arena below.

**Spawns:** every spawn point is inside its own arena, between its barriers.

**Climbing:** each higher roof is set back from the one below, so you look down at the drop.

---

**A1 · Loading dock** (screen 01)
- Size: 14 m long, 12 m wide. Street level.
- Barriers: a parked car behind (the start), a chain-link gate ahead.
- Wave 1: 2 Punks (90°).
- Spawns: the dock's rolling-shutter doorway and the crate alley, both ahead. None behind.
- Pickups: none. Hazards: none.

**A2 · Crate yard by the fence** (screen 02)
- Size: 16 x 12 m. Street level.
- Barriers: the chain-link gate behind, a parked car rolling across ahead.
- Wave 1: 3 Punks (90°). One comes from behind, as in the screen.
- Wave 2: 2 Punks (90°), 1 Pipe Thug (140°).
- Spawns: the crate alley (behind), an office doorway (side), a parked van's back doors (ahead, this side of the car).
- Pickups: the Thug's pipe when he goes down. Hazards: none (the fence is the edge).

**A3 · Warehouse front and its stair** (screens 03-04)
- Size: 14 x 12 m of street, then a stair up 4.5 m along the wall.
- Barriers: the parked car behind, a rolling shutter at the top of the stair ahead.
- Wave 1: 2 Punks (90°) come down the stair at you (the screen's ladder).
- Wave 2: 2 Punks (90°), 1 Pipe Thug (140°). One Punk from behind.
- Spawns: the landing at the top of the stair (ahead), the warehouse's rolling shutter (side), a brick doorway (behind).
- Pickups: the Thug's pipe. Hazards: none (the landing is railed).

**A4 · First terrace** (screens 05-07)
- Size: 28 x 10 m, 4.5 m up, a 1 m step halfway (a short flight of steps).
- Barriers: the shutter behind, a chain-link gate at the top of the next stair ahead.
- Wave 1: 1 Punk (90°) from a door, 1 Kicker (360°) from behind (the screen's fighter leaping down; a door in graybox).
- Wave 2: 2 Punks (90°), 1 Kicker (360°) from behind.
- Spawns: two terrace doors (ahead, and past the step), a roof door beside the stair you came up (behind).
- Pickups: none. Hazards: the open front edge, a 4.5 m drop to the street. Enemies knocked off are KO'd.

**A5 · Catwalk** (screens 08-09)
- Size: 20 x 10 m, 9 m up, set back above the terrace. You walk back the way you came. Screen 08 is the arrival, 09 the fight.
- Barriers: the gate behind, a rolling shutter at the top of the last stair ahead.
- Wave 1: 2 Punks (90°), one ahead and one behind (the screen's sandwich).
- Wave 2: 1 Bruiser (180°) ahead, 1 Punk (90°) behind.
- Spawns: a door at the far end (ahead), a door in the wall (side), a door beside the stair you came up (behind).
- Pickups: none. Hazards: the whole open side, a drop to the terrace. This is the knock-off arena.

**A6 · Top roof, the crowd** (screens 10-11)
- Size: 24 x 14 m, 12 m up, set back above the catwalk.
- Barriers: the shutter behind, a gate in the chain-link fence ahead.
- Wave 1, six at once: 1 Pipe Thug (140°), 2 Punks (90°), 1 veteran Punk (140°), 1 Kicker (360°), 1 Bruiser (180°). Two come from behind.
- Wave 2: 2 Punks (90°), 1 Kicker (360°).
- Spawns: the big rolling shutter (ahead), the crate-stack alley (side), a roof-access door (side), a door beside the stair you came up (behind).
- Pickups: a pipe lying in front of the big shutter (the screen's weapon on the floor), and the Thug's.
- Hazards: the far roof edge, a low rail with gaps. Through a gap is a 12 m drop.

**A7 · Boss roof** (screen 12 and past it)
- Size: 20 x 20 m, 12 m up, fenced.
- Barriers: the fence gate behind, which stays closed. Nothing ahead.
- Wave 1: the Boss (270°). At half health he calls in 2 Punks (90°) from the doors nearest him.
- Spawns: the roof door (ahead, his entrance), a service door (side), a door by the gate (behind).
- Pickups: none. Hazards: one open edge with a gap in the rail. The rest is fenced.
- The Boss and his adds down: "CLEAR!".

---

## Difficulty, arena by arena

| Arena | Most at once | New this arena |
| --- | --- | --- |
| A1 | 2 | Punks only: they square up in front |
| A2 | 3 | the first spawn behind; the Thug (140°) |
| A3 | 3 | enemies down the stair |
| A4 | 3 | the Kicker (360°); the first drop |
| A5 | 2 | the Bruiser (180°); knock them off |
| A6 | 6 | the crowd: every type and the veteran Punk (140°) |
| A7 | 3 | the Boss (270°) and his adds |

Wide-arc enemies (180° or more): none in A1-A3, then about a third of each arena from A4 on.

## Later levels (not built in the PoC)

Each level opens with a narrow-arc warm-up arena, then:
- **Level 2:** veteran Punks (140°) replace most plain Punks; Thugs common; Kickers in pairs. About 30% of enemies at 180° or more.
- **Level 3:** veteran Thugs (220°), Bruiser pairs, Kickers. About half at 180° or more.
- **Level 4 on:** mostly 270-360° types. Plain Punks only as fodder in the opening arena.

## Totals

- **34 enemies:** 21 Punks, 1 veteran Punk, 3 Pipe Thugs, 4 Kickers, 2 Bruisers, the Boss and his 2 adds.
- **First run: about 9-10 minutes.** Fights about 8 minutes (A1 0:30, A2 1:05, A3 1:00, A4 1:00, A5 1:00, A6 2:05, the Boss 2:00), walking and stairs about 1 minute. The bot measures it in Milestone 5.

## How the reference converts

- **Counts.** The stills show 1-2 enemies at a time (about 15 plus the boss), but a still catches one moment. Per SPEC §9 the order is the reference's and the counts follow the ramp: two Punks to open, six at once in A6 (the last screen before the boss), the Boss with two adds.
- **Screens to arenas.** 03 and 04 are one spot, before and after the fight. 05 to 07 are one terrace, 08-09 the catwalk, 10-11 the top roof. 12 is the boss roof.
- **Roles.** The vest-and-jeans grunt is the Punk. The shirtless brawler in fatigues is a Punk early (02) and the Bruiser on the catwalk (09). The agile fighter who leaps down is the Kicker. The armed grunt is the Pipe Thug. The masked heavy is the Boss.
- **Layout.** As on the fan map: the street, then each roof higher and set back from the one below, the catwalk walked back the other way.
- **Climbs.** The ladders become stairs (no new controls). The leap down from a ledge becomes a door behind you.
- **Weapons.** Screen 11's chain-like weapon is the pipe until Milestone 6 designs an original one.
- **Falls.** You can't fall off: an invisible guard holds you at every edge. Enemies knocked down, launched or thrown over one are KO'd.
