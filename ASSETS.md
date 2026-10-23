# Asset log

Every asset in the repo gets one row: where it came from, which service or tool made it, and its license (Spec §10, step 7).

| Asset | Path | Source / service | License | Notes |
| --- | --- | --- | --- | --- |
| DD2 NES Mission 1 screenshots | `reference/dd2-nes-mission1/*.jpg` | Game-boy's captures of the original game | © Technos Japan; reference only | Layout and pacing reference. Never traced, copied or shipped. |

## Effects (VFX)

The comic effect set (Spec §6 and §10, "2D effects"; Milestone 2). Claude drew every piece as SVG with `tools/gen_fx.gd` (shapes from a seeded random generator; the lettering uses an original block alphabet defined in that script, no font outlines). The same script rasterizes each SVG to a 512 px PNG (long side, transparent) with Godot's built-in SVG rasterizer. Redraw and re-export with `godot --headless -s tools/gen_fx.gd`, then `godot --headless --import --quit`; after editing an SVG by hand, add `-- --raster-only`. Red is used only for blood, the rear-warning burst and finisher accents (Spec §10).

| Asset | Path | Source / service | License | Notes |
| --- | --- | --- | --- | --- |
| Impact burst, small (light hits) | `assets/source/fx/burst_small.svg` → `assets/export/fx/burst_small.png` | Drawn by Claude as SVG (`tools/gen_fx.gd`), rasterized by Godot | Original, project-owned | |
| Impact burst, medium (heavy hits) | `assets/source/fx/burst_medium.svg` → `assets/export/fx/burst_medium.png` | Drawn by Claude as SVG (`tools/gen_fx.gd`), rasterized by Godot | Original, project-owned | |
| Impact burst, large (finishers; red finisher accent) | `assets/source/fx/burst_large.svg` → `assets/export/fx/burst_large.png` | Drawn by Claude as SVG (`tools/gen_fx.gd`), rasterized by Godot | Original, project-owned | |
| Speed lines: four tapered streaks, one per row | `assets/source/fx/speed_lines.svg` → `assets/export/fx/speed_lines.png` | Drawn by Claude as SVG (`tools/gen_fx.gd`), rasterized by Godot | Original, project-owned | |
| Blood droplet (comic red) | `assets/source/fx/blood_drop.svg` → `assets/export/fx/blood_drop.png` | Drawn by Claude as SVG (`tools/gen_fx.gd`), rasterized by Godot | Original, project-owned | |
| Blood splat 1 | `assets/source/fx/blood_splat_1.svg` → `assets/export/fx/blood_splat_1.png` | Drawn by Claude as SVG (`tools/gen_fx.gd`), rasterized by Godot | Original, project-owned | |
| Blood splat 2 | `assets/source/fx/blood_splat_2.svg` → `assets/export/fx/blood_splat_2.png` | Drawn by Claude as SVG (`tools/gen_fx.gd`), rasterized by Godot | Original, project-owned | |
| Blood splat 3 | `assets/source/fx/blood_splat_3.svg` → `assets/export/fx/blood_splat_3.png` | Drawn by Claude as SVG (`tools/gen_fx.gd`), rasterized by Godot | Original, project-owned | |
| Blood splash at the contact point | `assets/source/fx/blood_spray.svg` → `assets/export/fx/blood_spray.png` | Drawn by Claude as SVG (`tools/gen_fx.gd`), rasterized by Godot | Original, project-owned | |
| Spit droplet (head finishers) | `assets/source/fx/spit.svg` → `assets/export/fx/spit.png` | Drawn by Claude as SVG (`tools/gen_fx.gd`), rasterized by Godot | Original, project-owned | |
| Tooth (head finishers) | `assets/source/fx/tooth.svg` → `assets/export/fx/tooth.png` | Drawn by Claude as SVG (`tools/gen_fx.gd`), rasterized by Godot | Original, project-owned | |
| Block spark | `assets/source/fx/block_spark.svg` → `assets/export/fx/block_spark.png` | Drawn by Claude as SVG (`tools/gen_fx.gd`), rasterized by Godot | Original, project-owned | |
| Parry spark (perfect block) | `assets/source/fx/parry_spark.svg` → `assets/export/fx/parry_spark.png` | Drawn by Claude as SVG (`tools/gen_fx.gd`), rasterized by Godot | Original, project-owned | |
| Guard-break burst | `assets/source/fx/guard_break.svg` → `assets/export/fx/guard_break.png` | Drawn by Claude as SVG (`tools/gen_fx.gd`), rasterized by Godot | Original, project-owned | |
| Rear-attack warning burst (used in Milestone 3) | `assets/source/fx/rear_warning.svg` → `assets/export/fx/rear_warning.png` | Drawn by Claude as SVG (`tools/gen_fx.gd`), rasterized by Godot | Original, project-owned | |
| Damage look: bruises, seamless tile (skin) | `assets/source/fx/damage_bruised.svg` → `assets/export/fx/damage_bruised.png` | Drawn by Claude as SVG (`tools/gen_fx.gd`), rasterized by Godot | Original, project-owned | |
| Damage look: blood splats, seamless tile (clothes) | `assets/source/fx/damage_blood.svg` → `assets/export/fx/damage_blood.png` | Drawn by Claude as SVG (`tools/gen_fx.gd`), rasterized by Godot | Original, project-owned | |
| Damage look: bruises and blood, seamless tile (skin) | `assets/source/fx/damage_bloodied.svg` → `assets/export/fx/damage_bloodied.png` | Drawn by Claude as SVG (`tools/gen_fx.gd`), rasterized by Godot | Original, project-owned | |
| Comic lettering "POW!" | `assets/source/fx/word_pow.svg` → `assets/export/fx/word_pow.png` | Drawn by Claude as SVG (`tools/gen_fx.gd`), rasterized by Godot | Original, project-owned |  |
| Comic lettering "BAM!" | `assets/source/fx/word_bam.svg` → `assets/export/fx/word_bam.png` | Drawn by Claude as SVG (`tools/gen_fx.gd`), rasterized by Godot | Original, project-owned |  |
| Comic lettering "SMAK!" | `assets/source/fx/word_smak.svg` → `assets/export/fx/word_smak.png` | Drawn by Claude as SVG (`tools/gen_fx.gd`), rasterized by Godot | Original, project-owned |  |
| Comic lettering "WHAM!" | `assets/source/fx/word_wham.svg` → `assets/export/fx/word_wham.png` | Drawn by Claude as SVG (`tools/gen_fx.gd`), rasterized by Godot | Original, project-owned |  |
| Comic lettering "THUD" | `assets/source/fx/word_thud.svg` → `assets/export/fx/word_thud.png` | Drawn by Claude as SVG (`tools/gen_fx.gd`), rasterized by Godot | Original, project-owned |  |
| Comic lettering "BOFF!" | `assets/source/fx/word_boff.svg` → `assets/export/fx/word_boff.png` | Drawn by Claude as SVG (`tools/gen_fx.gd`), rasterized by Godot | Original, project-owned |  |
| Comic lettering "KRAK!" | `assets/source/fx/word_krak.svg` → `assets/export/fx/word_krak.png` | Drawn by Claude as SVG (`tools/gen_fx.gd`), rasterized by Godot | Original, project-owned | Finisher style (red extrusion accent) |
| Comic lettering "CRUNCH!" | `assets/source/fx/word_crunch.svg` → `assets/export/fx/word_crunch.png` | Drawn by Claude as SVG (`tools/gen_fx.gd`), rasterized by Godot | Original, project-owned | Finisher style (red extrusion accent) |
| Comic lettering "WHUMP!" | `assets/source/fx/word_whump.svg` → `assets/export/fx/word_whump.png` | Drawn by Claude as SVG (`tools/gen_fx.gd`), rasterized by Godot | Original, project-owned | Finisher style (red extrusion accent) |
| Comic lettering "KAPOW!" | `assets/source/fx/word_kapow.svg` → `assets/export/fx/word_kapow.png` | Drawn by Claude as SVG (`tools/gen_fx.gd`), rasterized by Godot | Original, project-owned | Finisher style (red extrusion accent) |
