#!/usr/bin/env python3
"""Writes the trailer's shots (PLAN.md section 5, the shot list) to video/shots/<key>.tres and .tscn.

The shot table below is the source: edit a shot here and run
    ~/.venvs/beat-em-up-video/bin/python -I tools/video/gen_trailer_shots.py
The generator reads the enum orders of video/cine/cine_beat.gd and video/cine/cine_camera_key.gd, so the numbers in the .tres
follow the scripts. It writes only the shots of the table (t01..t14); the Gate 2 shots (moving_punk, crane_street, the stills) stay
hand-written. Run from the repository root. Positions are in the space of the shot's section; yaw 0 looks along -Z, -90 along +X,
90 along -X.
"""
import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]


def enum_of(path: str, name: str) -> dict:
    text = (ROOT / path).read_text()
    body = re.search(r"enum %s\s*\{(.*?)\n\}" % name, text, re.S).group(1)
    out, index = {}, 0
    for line in body.splitlines():
        line = line.split("##")[0].strip().rstrip(",")
        if not line:
            continue
        out[line.split("=")[0].strip()] = index
        index += 1
    return out


KIND = enum_of("video/cine/cine_beat.gd", "Kind")
TRIGGER = enum_of("video/cine/cine_beat.gd", "Trigger")
EASE = enum_of("video/cine/cine_camera_key.gd", "Ease")
FACING = {"YAW": 0, "VIEWER": 1}


def v3(v) -> str:
    return "Vector3(%g, %g, %g)" % tuple(v)


# ---- beats ----------------------------------------------------------------------------------------------------------
def beat(kind, at=0.0, rel=False, trigger="CLOCK", timeout=3.0, actor=0, lead=8, button="P", hold=2, stick=(0, 0), degrees=0.0,
         seconds=0.0, scale=0.3, attack=0, label=""):
    return dict(kind=kind, at=at, rel=rel, trigger=trigger, timeout=timeout, actor=actor, lead=lead, button=button, hold=hold,
                stick=stick, degrees=degrees, seconds=seconds, scale=scale, attack=attack, label=label)


def press(button, at=0.0, rel=False, **kw):
    return beat("PRESS", at, rel, button=button, **kw)


def down(button, at=0.0, rel=False, **kw):
    return beat("DOWN", at, rel, button=button, **kw)


def up(button, at=0.0, rel=False, **kw):
    return beat("UP", at, rel, button=button, **kw)


def move(x, y, at=0.0, rel=False, **kw):
    return beat("MOVE", at, rel, stick=(x, y), **kw)


def turn(degrees, seconds, at=0.0, rel=False, **kw):
    return beat("TURN", at, rel, degrees=degrees, seconds=seconds, **kw)


def pitch(degrees, seconds, at=0.0, rel=False, **kw):
    return beat("PITCH", at, rel, degrees=degrees, seconds=seconds, **kw)


def slowmo(scale, seconds, at=0.0, rel=False, **kw):
    return beat("SLOWMO", at, rel, scale=scale, seconds=seconds, **kw)


def face(actor, seconds, at=0.0, rel=False, **kw):
    return beat("ACTOR_FACE", at, rel, actor=actor, seconds=seconds, **kw)


def attack(actor, index=0, at=0.0, rel=False, **kw):
    return beat("ATTACK", at, rel, actor=actor, attack=index, **kw)


def anim(actor, name, at=0.0, rel=False, **kw):
    return beat("ACTOR_ANIM", at, rel, actor=actor, label=name, **kw)


def mark(label, at=0.0, rel=False, **kw):
    return beat("MARK", at, rel, label=label, **kw)


# ---- actors, keys, props --------------------------------------------------------------------------------------------
def actor(id, pos, yaw=None, anim="idle", hold=0, live=True, health=0.0, share=0.0):
    """An enemy of the catalog. `yaw` None: faces the viewer."""
    return dict(id=id, pos=pos, facing="VIEWER" if yaw is None else "YAW", yaw=yaw or 0.0, anim=anim, hold=hold, live=live,
                health=health, share=share)


def key(t, pos, look, fov=60.0, focus=0.0, rng=3.0, roll=0.0, target=-1, ease="SMOOTH"):
    return dict(t=t, pos=pos, look=look, fov=fov, focus=focus, rng=rng, roll=roll, target=target, ease=ease)


def prop(id, pos, yaw=0.0):
    return dict(id=id, pos=pos, yaw=yaw)


# ---- the writer -----------------------------------------------------------------------------------------------------
def write_shot(s: dict) -> None:
    ids = {"shot": "1_shot", "actor": "2_actor", "beat": "3_beat", "key": "4_key", "prop": "5_prop"}
    scripts = {"shot": "res://video/cine/cine_shot.gd", "actor": "res://video/stage/still_actor.gd",
               "beat": "res://video/cine/cine_beat.gd", "key": "res://video/cine/cine_camera_key.gd",
               "prop": "res://video/cine/cine_prop.gd"}
    used = ["shot", "actor"]
    if s["beats"]:
        used.append("beat")
    if s.get("keys"):
        used.append("key")
    if s.get("props"):
        used.append("prop")
    out = []
    subs = []
    count = 1 + len(used) - 1
    names = {"actor": [], "beat": [], "key": [], "prop": []}
    for i, a in enumerate(s["actors"]):
        n = "Actor_%d" % i
        names["actor"].append(n)
        subs.append('[sub_resource type="Resource" id="%s"]\nscript = ExtResource("%s")\nid = &"%s"\nposition = %s\nfacing = %d\n'
                    'yaw_deg = %g\nanim = &"%s"\nhold_tick = %d\nlive = %s\nhealth = %g\nhealth_share = %g\n' % (
                        n, ids["actor"], a["id"], v3(a["pos"]), FACING[a["facing"]], a["yaw"], a["anim"], a["hold"],
                        "true" if a["live"] else "false", a["health"], a["share"]))
    for i, b in enumerate(s["beats"]):
        n = "Beat_%d" % i
        names["beat"].append(n)
        subs.append('[sub_resource type="Resource" id="%s"]\nscript = ExtResource("%s")\nat_s = %g\nrelative = %s\nkind = %d\n'
                    'trigger = %d\ntimeout_s = %g\nactor = %d\nlead_ticks = %d\nbutton = &"%s"\nhold_ticks = %d\nstick = Vector2(%g, %g)\n'
                    'degrees = %g\nseconds = %g\ntime_scale = %g\nattack_index = %d\nlabel = &"%s"\n' % (
                        n, ids["beat"], b["at"], "true" if b["rel"] else "false", KIND[b["kind"]], TRIGGER[b["trigger"]],
                        b["timeout"], b["actor"], b["lead"], b["button"], b["hold"], b["stick"][0], b["stick"][1], b["degrees"],
                        b["seconds"], b["scale"], b["attack"], b["label"]))
    for i, k in enumerate(s.get("keys", [])):
        n = "Key_%d" % i
        names["key"].append(n)
        subs.append('[sub_resource type="Resource" id="%s"]\nscript = ExtResource("%s")\ntime_s = %g\nposition = %s\nlook_at = %s\n'
                    'target_actor = %d\nfov_deg = %g\nfocus_m = %g\nfocus_range_m = %g\nroll_deg = %g\nease = %d\n' % (
                        n, ids["key"], k["t"], v3(k["pos"]), v3(k["look"]), k["target"], k["fov"], k["focus"], k["rng"], k["roll"],
                        EASE[k["ease"]]))
    for i, p in enumerate(s.get("props", [])):
        n = "Prop_%d" % i
        names["prop"].append(n)
        subs.append('[sub_resource type="Resource" id="%s"]\nscript = ExtResource("%s")\nid = &"%s"\nposition = %s\nyaw_deg = %g\n' % (
            n, ids["prop"], p["id"], v3(p["pos"]), p["yaw"]))

    def arr(kind, ext):
        return "Array[ExtResource(\"%s\")]([%s])" % (ids[ext], ", ".join('SubResource("%s")' % n for n in names[kind]))

    head = '[gd_resource type="Resource" script_class="CineShot" load_steps=%d format=3]\n\n' % (len(used) + len(subs) + 1)
    for u in used:
        head += '[ext_resource type="Script" path="%s" id="%s"]\n' % (scripts[u], ids[u])
    head += "\n" + "\n".join(subs) + "\n[resource]\n"
    body = 'script = ExtResource("1_shot")\nkey = &"%s"\nnote = "%s"\nsection = %d\nlocation = &"%s"\n' % (
        s["key"], s["note"].replace('"', "'"), s["section"], s.get("location", ""))
    body += "number = %d\nedit_start_s = %g\nedit_speed = %g\n" % (s["number"], s["edit_start"], s.get("edit_speed", 1.0))
    body += "player_pos = %s\nplayer_yaw_deg = %g\nplayer_pitch_deg = %g\nfirst_person = %s\n" % (
        v3(s["player"][0]), s["player"][1], s["player"][2], "true" if s["fp"] else "false")
    if s.get("fov"):
        body += "first_person_fov_deg = %g\n" % s["fov"]
    body += "actors = %s\nwarmup_ticks = %d\nwindow_from_s = %g\nwindow_to_s = %g\nrng_seed = %d\n" % (
        arr("actor", "actor"), s.get("warmup", 40), s["window"][0], s["window"][1], s.get("seed", 1))
    if s["beats"]:
        body += "beats = %s\n" % arr("beat", "beat")
    if s.get("keys"):
        body += "camera_keys = %s\n" % arr("key", "key")
    if s.get("props"):
        body += "props = %s\n" % arr("prop", "prop")
    if "shake" in s:
        body += "shake_scale = %g\n" % s["shake"]
    if s.get("lamps"):
        body += "lamp_posts = PackedVector3Array(%s)\n" % ", ".join("%g, %g, %g" % tuple(p) for p in s["lamps"])
    (ROOT / "video/shots" / ("%s.tres" % s["key"])).write_text(head + body)
    (ROOT / "video/shots" / ("%s.tscn" % s["key"])).write_text(
        '[gd_scene load_steps=3 format=3]\n\n[ext_resource type="Script" path="res://video/stage/cine_bot.gd" id="1_bot"]\n'
        '[ext_resource type="Resource" path="res://video/shots/%s.tres" id="2_shot"]\n\n[node name="Shot" type="Node"]\n'
        'script = ExtResource("1_bot")\nshot = ExtResource("2_shot")\n' % s["key"])


# ---- the shot list (PLAN.md section 5) ------------------------------------------------------------------------------
SHOTS = []

# 1. The street at night: a slow crane down from roof height; four idle figures, none alike (a Punk, a veteran, a Thug, a Kicker).
SHOTS.append(dict(
    key="t01_crane_street", number=1, edit_start=0.0, section=0, fp=False, player=((3, 0, -2), 0, 0), window=(0, 3.0),
    note="Shot 1 (0:00-0:03): a slow crane down from roof height to the street; steam, sodium lamps, a burning barrel; four idle figures in silhouette, no two alike.",
    actors=[actor("punk", (0.5, 0, -8.5), yaw=-20),
            actor("punk_veteran", (3.0, 0, -10.4), yaw=150, anim="taunt", hold=40, live=False),
            actor("thug", (-2.4, 0, -11.2), yaw=60),
            actor("kicker", (0.4, 0, -14.6), yaw=-170, anim="brace", hold=20, live=False)],
    beats=[],
    keys=[key(0.0, (-0.6, 8.6, 2.0), (0.5, 1.8, -22.0), fov=75),
          key(1.6, (-0.5, 5.4, 1.0), (0.5, 1.7, -16.0), fov=68, focus=14, rng=5),
          key(3.0, (0.2, 2.4, 0.0), (0.6, 1.5, -10.0), fov=60, focus=10, rng=5)]))

# 2. First person: the wrapped fists come up into guard; a Punk turns, rim-lit by the key lamp behind him.
SHOTS.append(dict(
    key="t02_guard_up", number=2, edit_start=3.0, section=0, fp=True, player=((-0.1, 0, -3.4), 0, -2), window=(0, 2.0),
    note="Shot 2 (0:03-0:05): first person; the fists come up into guard, a Punk turns toward you, rim-lit by the lamp behind him.",
    actors=[actor("punk", (-0.2, 0, -5.6), yaw=0, live=False)],
    beats=[down("DODGE", 0.2), face(0, 0.8, 0.3)]))

# 3. First person: P P P P on a Punk; the last hit launches him into the chain-link fence.
SHOTS.append(dict(
    key="t03_punk_combo", number=3, edit_start=5.0, section=0, fp=True, player=((-3.0, 0, -10.2), 0, 0), window=(0, 3.4),
    note="Shot 3 (0:05-0:08): P P P P on a Punk with impact frames; the finisher launches him backward into the chain-link fence.",
    actors=[actor("punk", (-3.0, 0, -12.0), yaw=None, health=60)],
    beats=[press("P", 0.3), press("P", 0.4, True), press("P", 0.4, True), press("P", 0.4, True)]))

# 4. First person: a perfect block on a Kicker, then the spin kick (jump, K at the top).
SHOTS.append(dict(
    key="t04_block_spin", number=4, edit_start=8.0, section=0, fp=True, player=((0.2, 0, -2.0), 0, -2), window=(0, 3.0),
    note="Shot 4 (0:08-0:10): a perfect block on a Kicker's jump kick, then the spin kick (jump, K at the top), the view spinning with it.",
    actors=[actor("kicker", (0.2, 0, -3.9), yaw=None, health=200)],
    beats=[attack(0, 0, 0.2), down("DODGE", 0.0, False, trigger="ACTOR_STRIKE", lead=7), up("DODGE", 0.35, True),
           press("JUMP", 0.1, True), press("K", 0.0, True, trigger="PLAYER_JUMP_PEAK", timeout=1.0)]))

# 5. First person: grab a Pipe Thug, knee, knee, throw him into the crates.
SHOTS.append(dict(
    key="t05_grab_throw", number=5, edit_start=10.0, section=0, fp=True, player=((1.0, 0, -5.4), -90, -3), window=(0, 3.8),
    note="Shot 5 (0:10-0:12): a jab staggers a Pipe Thug, grab him, knee, knee, throw him into the crates.",
    actors=[actor("thug", (2.1, 0, -5.4), yaw=None, health=300)],
    beats=[press("P", 0.2), press("P", 0.4, True), press("P", 0.4, True),
           press("GRAB", 0.0, True, trigger="PLAYER_FREE", timeout=1.0),
           press("P", 0.2, True, trigger="PLAYER_HOLDING", timeout=1.0), press("P", 0.35, True), move(0, 1, 0.3, True),
           press("K", 0.05, True)]))

# 6. First person: pick up a dropped pipe, the three-hit chain into a Bruiser's steel plates.
SHOTS.append(dict(
    key="t06_pipe_chain", number=6, edit_start=12.0, section=0, fp=True, player=((2.0, 0, -9.0), 0, -3), window=(0, 3.0),
    note="Shot 6 (0:12-0:14): pick up a dropped pipe; the three-hit chain into a Bruiser's steel plates, with sparks.",
    actors=[actor("bruiser", (2.0, 0, -12.2), yaw=None, health=500)],
    props=[prop("pipe", (2.0, 0, -9.9), 20)],
    beats=[pitch(-45, 0.25, 0.1), press("GRAB", 0.15, True), pitch(-3, 0.3, 0.3, True),
           move(0, 1, 0.1, True), move(0, 0, 0.45, True),
           press("P", 0.1, True), press("P", 0.4, True), press("P", 0.4, True)]))

# 7. The roofs at dusk, cine at 0.25x: a Kicker knocked over the west parapet of the top roof, a silhouette against the sun.
SHOTS.append(dict(
    key="t07_roof_knockoff", number=7, edit_start=14.0, section=1, fp=False, player=((4.5, 4.5, -17.0), 90, 0), window=(0, 3.6),
    edit_speed=0.25,
    note="Shot 7 (0:14-0:17, 0.25x): a Kicker knocked off the catwalk's west edge toward the low sun (the roof's parapet is solid: a launch stops at it); the slow-motion is TimeController's.",
    actors=[actor("kicker", (3.1, 4.5, -17.0), yaw=None, health=60)],
    beats=[press("P", 0.3), press("P", 0.4, True), press("P", 0.4, True), press("P", 0.4, True), slowmo(0.25, 2.0, 0.1, True)],
    keys=[key(0.0, (9.0, 4.9, -19.2), (1.0, 6.2, -17.2), fov=60),
          key(3.6, (8.0, 5.2, -18.8), (0.0, 6.6, -17.2), fov=52)]))

# 8. First person, the roofs: the bike chain's whip on two Punks, the padlock landing last.
SHOTS.append(dict(
    key="t08_chain_whip", number=8, edit_start=17.0, section=1, fp=True, player=((-3.0, 0, -2.4), 0, -3), window=(0, 2.8),
    note="Shot 8 (0:17-0:19): the bike chain's three-hit whip on two Punks, the padlock landing last.",
    actors=[actor("punk", (-3.25, 0, -4.2), yaw=None, health=200), actor("punk_veteran", (-2.55, 0, -4.4), yaw=135, health=200)],
    props=[prop("bike_chain", (-3.0, 0, -3.1), 0)],
    beats=[pitch(-45, 0.25, 0.1), press("GRAB", 0.15, True), pitch(-3, 0.3, 0.3, True),
           press("P", 0.15, True), press("P", 0.4, True), press("P", 0.4, True)]))

# 9. First person: the rear warning flashes; the back elbow (RB) turns the view 150 degrees into the attacker.
SHOTS.append(dict(
    key="t09_back_elbow", number=9, edit_start=19.0, section=1, fp=True, player=((-3.0, 0, -7.0), 0, -2), window=(0, 2.0),
    note="Shot 9 (0:19-0:21): the rear warning flashes for a Punk behind; the back elbow turns the view 150 degrees into him.",
    actors=[actor("punk", (-3.0, 0, -5.9), yaw=None, health=200), actor("kicker", (-3.6, 0, -11.5), yaw=None, anim="idle", live=False)],
    beats=[attack(0, 0, 0.3), press("RB", 0.0, True, trigger="ACTOR_STRIKE", lead=9)]))

# 10. The boss roof, cine: low angle, slow push-in on Ox, hooded and rim-lit; he raises his gloves; the name card.
SHOTS.append(dict(
    key="t10_ox_reveal", number=10, edit_start=21.0, section=2, fp=False, player=((0, 0, -1.5), 0, 0), window=(0, 4.0),
    note="Shot 10 (0:21-0:25): a low angle, slow push-in on Ox Pellerin, rim-lit against fire and smoke; he raises his gloves. The name card OX PELLERIN is the edit's (mark at 2.2 s).",
    actors=[actor("boss", (8, 0, -10), yaw=None, live=False)],
    beats=[anim(0, "taunt", 1.2), mark("name_card", 1.0, True)],
    keys=[key(0.0, (2.6, 0.45, -10.6), (8, 1.7, -10), fov=58), key(4.0, (4.5, 0.4, -10.2), (8, 2.0, -10), fov=46)]))

# 11. First person: block Ox's charge, then a perfect block, the spinning backfist (P P . P), the haymaker held and released.
SHOTS.append(dict(
    key="t11_ox_fight", number=11, edit_start=25.0, section=2, fp=True, player=((1.5, 0, -10.0), -90, -2), window=(0, 8.1),
    note="Shot 11 (0:25-0:31): block Ox's heavy, a perfect block on the next, the spinning backfist (P P . P), then the haymaker held and released as he gets up (the cut to shot 12 is on the release).",
    actors=[actor("boss", (5.3, 0, -10.0), yaw=None, health=900)],
    beats=[attack(0, 0, 0.2), down("DODGE", 0.0, False, trigger="ACTOR_STRIKE", lead=22), up("DODGE", 0.8, True),
           attack(0, 0, 0.3, True), down("DODGE", 0.0, False, trigger="ACTOR_STRIKE", lead=7), up("DODGE", 0.7, True),
           pitch(8, 0.4, 0.0, True), press("P", 0.1, True), press("P", 0.35, True), press("P", 0.8, True),
           mark("ox_down", 0.0, True, trigger="ACTOR_DOWN", timeout=2.0), move(0, 1, 0.8, True), move(0, 0, 0.2, True),
           down("P", 0.0, True, trigger="ACTOR_FREE", timeout=4.0), up("P", 0.6, True)]))

# 12. The boss roof, cine at 0.25x: the haymaker lands, a backlit silhouette of fist and head against the fire.
SHOTS.append(dict(
    key="t12_haymaker", number=12, edit_start=31.0, section=2, fp=False, player=((4.0, 0, -10.0), -90, 0), window=(0, 3.0),
    edit_speed=0.25,
    note="Shot 12 (0:31-0:34, 0.25x): the haymaker lands; a backlit silhouette of fist and head against the fire, the impact frame.",
    actors=[actor("boss", (6.2, 0, -10.0), yaw=None, health=900)],
    beats=[down("P", 0.2), up("P", 0.55, True), slowmo(0.25, 1.8, 0.0, True)],
    keys=[key(0.0, (2.4, 1.5, -11.2), (6.0, 1.9, -10.0), fov=52), key(3.0, (3.0, 1.55, -11.0), (6.4, 1.9, -10.0), fov=44)]))

# 13. First person: Ox falls (ragdoll); the embers settle; the edit cuts to black on the hit sound.
SHOTS.append(dict(
    key="t13_ox_falls", number=13, edit_start=34.0, section=2, fp=True, player=((3.4, 0, -10.0), -90, -2), window=(0, 3.4),
    note="Shot 13 (0:34-0:37): the haymaker puts Ox down; he falls (ragdoll), the embers settle. The cut to black is the edit's (mark at 3.0 s).",
    actors=[actor("boss", (5.8, 0, -10.0), yaw=None, health=14)],
    beats=[down("P", 0.2), up("P", 0.55, True), mark("cut_to_black", 2.4, True)]))

# 14. The title card's background: drifting embers over the burning skyline (the title is the edit's).
SHOTS.append(dict(
    key="t14_title_embers", number=14, edit_start=37.0, section=2, fp=False, player=((0, 0, -1.5), 0, 0), window=(0, 4.0),
    note="Shot 14 (0:37-0:41): the title card's background, a slow drift across the burning skyline with embers; the title is set in the edit.",
    actors=[],
    beats=[mark("title_in", 0.5)],
    keys=[key(0.0, (2.0, 1.6, -10.0), (14, 5.0, -10.0), fov=70), key(4.0, (3.0, 2.2, -10.0), (14, 6.5, -9.0), fov=64)]))


if __name__ == "__main__":
    for shot in SHOTS:
        write_shot(shot)
        print("wrote", shot["key"])
