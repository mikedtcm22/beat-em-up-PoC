# Milestone 5: inputs from Game-boy

Game-boy's calls for the next milestone, recorded as he made them, for the M5 planner. Each one changes the spec on his word. Record each in README's "Where M5 departs from the spec" when it's built.

## 1. Attack arcs: the trickier enemies may attack from more of the circle (2026-11-03)

**His words** (session chat, after passing M4):

> I don't think we need to have *EVERY* enemy's strategy be trying to get behind you before they attack. The player should see the basic street-punks (for example) try to just square up with the player and attack head-on...or maybe from a slight angle (I think circling to attack from behind is a bit higher-level enemy tactic — maybe just one sneaky enemy-type in particular who does that).

> instead of having the rule be "everyone spreads evenly out around the player," that if there are more enemies than there are room for to attack they way they normally do, they wait behind the action instead of finding an open slot. That's what makes a group of Street Punks still easy to fight in early levels — they attack head on and don't try to get behind you, so it's easier to take on a bunch of them.

> Maybe how we adjust the difficulty with these enemies is giving them a radius around the player that they default to attack from: if there's space within that radius the find a spot to come in and attack, but if not they stand back from the fray within their radius. For Street Punks, that radius is maybe 90-degrees (45 deg each way from the center line), for a next level enemy it might be more like 140-degrees, another could be 180-deg, another 270, then other enemies that have a 360-degree radius. So basically: the "trickier" enemies are so because they are allowed to attack from more spots around the player.

**What it replaces.** It replaces SPEC §7's director rule "Spread: posturing enemies spread around the player instead of bunching in front". Today M3's director:
- gives posture slots spread evenly all round;
- gives each grunt any free slot;
- seats the Kicker behind.

`blind_spot_priority` (1.0) also lets an out-of-view enemy jump the token queue. SPEC §7's own rows already say the Street Punk "approaches head-on" and the Kicker "actively circles to the player's blind side". The new rule makes the director match them.

**The rule as proposed (a draft for the M5 plan):**
- **Each archetype has an attack arc:** a sector of the posture ring centred on the center line, `arc_deg` wide (a tunable per archetype).
- **Room in the arc:** an enemy given a token takes a free attack slot inside its arc and comes in from there. Head-on for a Punk, or from a slight angle.
- **No room in the arc:** it doesn't go round to an open slot elsewhere. It waits behind the action, inside its arc, on an outer ring, back from the fray, until a slot inside its arc frees up.
- **Blind-spot priority:** only for enemies whose arc reaches the blind spot, so it stays the sneaky types' edge.

**Proposed arcs** (his five tiers onto the five archetypes, from least to most tricky):

| Archetype | Arc | Why |
| --- | --- | --- |
| Street Punk | 90° (±45°) | The basic grunt: squares up and attacks head-on or a little off it. |
| Pipe Thug | 140° (±70°) | A step up: comes in from the side of the view. |
| Bruiser | 180° (±90°) | The heavy: can step round to your flank, not behind. |
| Boss | 270° (±135°) | Charges from most angles, but not straight from behind. |
| Kicker | 360° | The one sneaky type: circles to your blind side (SPEC §7). |

**Open questions for the M5 plan (to put to Game-boy with the encounter plan):**
1. **The center line.** Is it where the player looks (the arc turns with him, so a Punk behind you walks round to your front), or is it fixed when the enemy engages (turning your back on a Punk lets him hit you from behind)? The first is gentler; the second makes facing a crowd a skill.
2. **The mapping above,** and whether later levels or enemy variants widen a type's arc (for example a "veteran Punk" at 140°).
3. **The rear warning.** With mostly front-arc grunts it will fire less often, mostly for Kickers and the boss. Should a crowd of Punks ever reach behind you, for example when you're surrounded and turn?

**Game-boy's answers (2026-11-03, session chat):**

> I think it has to be based on when he engages — and we can have a bit of a grace-period for the enemy AI in terms of deciding at what point the enemy engages (a half-second or something). Otherwise, the player can basically stun-lock lower level enemies just by turning quickly, which seems lame to me.

> I'm on board with later variants getting wider arcs ("veteran punk" as an example). As the game progresses, there are probably mostly enemies that can attack at all-angles. Just want there to be a progression to those enemies so that at early levels there are some strategically easier guys to warm up with.

**What they settle:**
1. **The center line is fixed when the enemy engages,** not tied to where the player looks. Turning your back on a Punk lets him hit you from behind.
   - The moment of engagement has a grace period of about 0.5 s (a tunable, `engage_commit_s` or similar). Within it, the enemy re-picks its line if the player turns, so a quick turn can't stun-lock a low-level enemy into endless repositioning.
   - After it, the line holds until the attack and its recovery end.
2. **Variants widen the arc.** For example, a "veteran Punk" at 140°. The arc is per archetype, or per variant, in data, so a later variant is a resource, not code.
3. **A difficulty progression across the game.** Early levels lean on narrow-arc grunts, the strategically easier warm-up. Later levels are mostly all-angle enemies. M5's encounter plan should show the progression level by level.
4. **The rear warning:** not answered yet. It follows from the above: it fires for wide-arc types and for any enemy whose fixed line ends up behind the player.

**Effects to re-measure:** M3's readability metrics (R1-R15) and the rear warning's tests (`tests/test_m3_done_when.gd`), since fewer attacks come from behind. The director's tunables live in the "Enemies" group in F1.
