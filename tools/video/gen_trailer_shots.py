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


def card(points, pos, yaw=0.0, color=(0.035, 0.03, 0.06), drift=(0.0, 0.0, 0.0)):
    """A flat dark foreground mass (CineCard): `points` are (x right, y up) in metres in its vertical plane, `pos` the plane's origin, `yaw` its facing (0 faces +Z)."""
    return dict(points=points, pos=pos, yaw=yaw, color=color, drift=drift)


def facing(cam, look, dist):
    """Where a card stands, `dist` metres along the view from `cam` toward `look`, and the yaw that turns its front toward the camera."""
    import math
    d = [look[i] - cam[i] for i in range(3)]
    n = math.sqrt(sum(c * c for c in d))
    d = [c / n for c in d]
    pos = tuple(cam[i] + d[i] * dist for i in range(3))
    return pos, math.degrees(math.atan2(-d[0], -d[2]))


def aim(cam, az_deg, pitch_deg, dist=10.0):
    """A look-at point `dist` metres from `cam` along a heading `az_deg` (0 along +X, positive toward -Z) and a pitch (degrees)."""
    import math
    a, p = math.radians(az_deg), math.radians(pitch_deg)
    return (cam[0] + dist * math.cos(p) * math.cos(a), cam[1] + dist * math.sin(p), cam[2] - dist * math.cos(p) * math.sin(a))


# ---- the writer -----------------------------------------------------------------------------------------------------
def write_shot(s: dict) -> None:
    ids = {"shot": "1_shot", "actor": "2_actor", "beat": "3_beat", "key": "4_key", "prop": "5_prop", "card": "6_card"}
    scripts = {"shot": "res://video/cine/cine_shot.gd", "actor": "res://video/stage/still_actor.gd",
               "beat": "res://video/cine/cine_beat.gd", "key": "res://video/cine/cine_camera_key.gd",
               "prop": "res://video/cine/cine_prop.gd", "card": "res://video/cine/cine_card.gd"}
    used = ["shot", "actor"]
    if s["beats"]:
        used.append("beat")
    if s.get("keys"):
        used.append("key")
    if s.get("props"):
        used.append("prop")
    if s.get("cards"):
        used.append("card")
    out = []
    subs = []
    count = 1 + len(used) - 1
    names = {"actor": [], "beat": [], "key": [], "prop": [], "card": []}
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

    for i, c in enumerate(s.get("cards", [])):
        n = "Card_%d" % i
        names["card"].append(n)
        subs.append('[sub_resource type="Resource" id="%s"]\nscript = ExtResource("%s")\npoints = PackedVector2Array(%s)\nposition = %s\nyaw_deg = %g\n'
                    'color = Color(%g, %g, %g, 1)\ndrift = %s\n' % (n, ids["card"], ", ".join("%g, %g" % tuple(p) for p in c["points"]), v3(c["pos"]),
                                                              c["yaw"], c["color"][0], c["color"][1], c["color"][2], v3(c["drift"])))

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
    if s.get("cards"):
        body += "cards = %s\n" % arr("card", "card")
    if s.get("hide_kit"):
        body += "hide_kit = true\n"
    if "shake" in s:
        body += "shake_scale = %g\n" % s["shake"]
    if s["fp"]:
        # Round 5: the first-person view (CineViewRig): the lens up and back, a bank, the off-hand hidden unless it strikes.
        body += "view_lift_m = %g\nview_back_m = %g\nview_roll_deg = %g\n" % (s.get("lift", 0.0), s.get("back", 0.0), s.get("roll", 0.0))
        if s.get("off"):
            body += 'hide_off_hand = true\noff_hand = "%s"\n' % s["off"]
    if s.get("lamps"):
        body += "lamp_posts = PackedVector3Array(%s)\n" % ", ".join("%g, %g, %g" % tuple(p) for p in s["lamps"])
    (ROOT / "video/shots" / ("%s.tres" % s["key"])).write_text(head + body)
    (ROOT / "video/shots" / ("%s.tscn" % s["key"])).write_text(
        '[gd_scene load_steps=3 format=3]\n\n[ext_resource type="Script" path="res://video/stage/cine_bot.gd" id="1_bot"]\n'
        '[ext_resource type="Resource" path="res://video/shots/%s.tres" id="2_shot"]\n\n[node name="Shot" type="Node"]\n'
        'script = ExtResource("1_bot")\nshot = ExtResource("2_shot")\n' % s["key"])


# ---- the shot list (PLAN.md section 5) ------------------------------------------------------------------------------
SHOTS = []

# 1. The street at night (round 5): a tilt-down from a fixed point 7 m up at the left side of the street, onto a fight in the lamp's pool: a three-quarter
# view with the vanishing point off-centre, a dark foreground mass (a fire escape's corner and rail, cards), the figures small and silhouetted.
CAM1 = (-4.9, 6.6, 0.2)
END1 = (-0.4, 0.8, -11.5)
_c1_pos, _c1_yaw = facing(CAM1, END1, 2.4)
SHOTS.append(dict(
    key="t01_crane_street", number=1, edit_start=0.0, section=0, fp=False, player=((3, 0, -2), 0, 0), window=(0, 3.0),
    note="Shot 1 (0:00-0:03, round 5): a tilt-down from a fixed point 7 m up at the street's left side onto a fight in the lamp's pool; a fire escape's dark mass in the foreground, the figures small.",
    actors=[actor("punk", (-1.6, 0, -11.0), yaw=-80, anim="block", hold=12, live=False),
            actor("thug", (-0.1, 0, -11.3), yaw=95, anim="stagger_back", hold=10, live=False),
            actor("punk_veteran", (-4.2, 0, -12.6), yaw=120, anim="taunt", hold=40, live=False),
            actor("kicker", (2.4, 0, -12.2), yaw=170, anim="brace", hold=20, live=False)],
    beats=[],
    keys=[key(0.0, CAM1, (3.0, 4.6, -40.0), fov=48),
          key(1.5, CAM1, (1.5, 2.2, -21.0), fov=45, focus=14, rng=8),
          key(3.0, CAM1, END1, fov=42, focus=13, rng=6)],
    cards=[card([(-1.3, -1.0), (0.05, -1.0), (-0.05, -0.9), (-0.6, -0.84), (-1.3, -0.7)], _c1_pos, _c1_yaw),
           card([(-1.3, -0.5), (-1.3, -0.45), (-0.5, 0.25), (-0.45, 0.2)], _c1_pos, _c1_yaw),
           card([(-1.3, -0.72), (-1.3, -0.67), (-0.22, 0.14), (-0.17, 0.09)], _c1_pos, _c1_yaw),
           card([(-0.62, -0.84), (-0.6, -0.4), (-0.57, -0.4), (-0.56, -0.84)], _c1_pos, _c1_yaw),
           card([(-0.3, -0.88), (-0.29, -0.5), (-0.26, -0.5), (-0.25, -0.88)], _c1_pos, _c1_yaw)]))

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
    key="t04_block_spin", number=4, edit_start=8.0, section=0, fp=True, player=((0.2, 0, -2.0), 0, -2), window=(0, 2.7),
    note="Shot 4 (0:08-0:10): a perfect block on a Kicker's jump kick, then the spin kick (jump, K at the top), the view spinning with it.",
    actors=[actor("kicker", (0.2, 0, -3.9), yaw=None, health=200)],
    beats=[attack(0, 0, 0.2), down("DODGE", 0.0, False, trigger="ACTOR_STRIKE", lead=7), up("DODGE", 0.35, True),
           press("JUMP", 0.1, True), press("K", 0.0, True, trigger="PLAYER_JUMP_PEAK", timeout=1.0),
           pitch(-16, 0.5, 0.35, True)]))

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

# 7. The roofs at dusk, cine at 0.25x (round 5): a Kicker knocked up and back off the top roof's west end, against the sun. A camera fixed at the roof's east
# edge, low, on the sun's line; the near water tower is the big foreground silhouette (the other is behind it), the parapet starts beyond.
CAM7 = (21.0, 7.6, -18.4)
SHOTS.append(dict(
    key="t07_roof_knockoff", number=7, edit_start=14.0, section=1, fp=False, player=((14.7, 7.5, -16.0), 90, 0), window=(0, 3.6),
    edit_speed=0.25,
    note="Shot 7 (0:14-0:17, 0.25x, round 5): a Kicker knocked off the top roof's west end toward the low sun; a fixed low camera on the sun's line, one water tower in the foreground; the slow-motion is TimeController's.",
    actors=[actor("kicker", (13.2, 7.5, -16.0), yaw=None, health=60)],
    beats=[press("P", 0.3), press("P", 0.4, True), press("P", 0.4, True), press("P", 0.4, True), slowmo(0.25, 2.0, 0.1, True)],
    keys=[key(0.0, CAM7, (11.0, 9.2, -16.8), fov=46, roll=-5.0),
          key(3.6, CAM7, (11.0, 9.6, -16.2), fov=42, roll=-5.0)]))

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

# 10. The boss roof, cine (round 5): a low camera fixed on the roof, three-quarter on Ox against the brightest part of the fire (pitched up, so no facade is in frame),
# a zoom in (the plate holds the camera's position) while he raises his gloves; the name card.
CAM10 = (1.4, 0.4, -9.4)
SHOTS.append(dict(
    key="t10_ox_reveal", number=10, edit_start=21.0, section=2, fp=False, player=((0, 0, -1.5), 0, 0), window=(0, 4.0),
    note="Shot 10 (0:21-0:25, round 5): a low fixed camera, three-quarter on Ox Pellerin against the fire, a slow zoom in; he raises his gloves. The name card OX PELLERIN is the edit's (mark at 2.2 s).",
    actors=[actor("boss", (8, 0, -10), yaw=None, live=False)],
    beats=[anim(0, "taunt", 1.2), mark("name_card", 1.0, True)],
    keys=[key(0.0, CAM10, aim(CAM10, -8.0, 17.0), fov=48), key(4.0, CAM10, aim(CAM10, -6.0, 19.0), fov=38)]))

# 11. First person: block Ox's charge, then a perfect block, the spinning backfist (P P . P), the haymaker held and released.
SHOTS.append(dict(
    key="t11_ox_fight", number=11, edit_start=25.0, section=2, fp=True, player=((1.5, 0, -10.0), -90, -2), window=(0, 8.1),
    note="Shot 11 (0:25-0:31): block Ox's heavy, a perfect block on the next, the spinning backfist (P P . P), then the haymaker held and released as he gets up (the cut to shot 12 is on the release).",
    actors=[actor("boss", (5.3, 0, -10.0), yaw=None, health=900)],
    beats=[attack(0, 0, 0.2), down("DODGE", 0.0, False, trigger="ACTOR_STRIKE", lead=22), up("DODGE", 0.8, True),
           attack(0, 0, 0.3, True), down("DODGE", 0.0, False, trigger="ACTOR_STRIKE", lead=7), up("DODGE", 0.7, True),
           pitch(22, 0.4, 0.0, True), press("P", 0.1, True), press("P", 0.35, True), press("P", 0.8, True),
           mark("ox_down", 0.0, True, trigger="ACTOR_DOWN", timeout=2.0), pitch(-10, 0.4, 0.1, True), move(0, 1, 0.8, True), move(0, 0, 0.2, True),
           pitch(16, 0.5, 0.0, True), down("P", 0.0, True, trigger="ACTOR_FREE", timeout=4.0), up("P", 0.6, True)]))

# 12. The boss roof, cine at 0.25x (round 5): the haymaker lands. A three-quarter close-up from behind the player's shoulder, low, one glove a dark foreground shape,
# Ox's face against the fire; the camera fixed, a slow zoom, a fixed bank.
CAM12 = (2.3, 0.7, -11.2)
SHOTS.append(dict(
    key="t12_haymaker", number=12, edit_start=31.0, section=2, fp=False, player=((4.0, 0, -10.0), -90, 0), window=(0, 3.0),
    edit_speed=0.25,
    note="Shot 12 (0:31-0:34, 0.25x, round 5): the haymaker lands; a three-quarter close-up over the player's shoulder, one glove a dark foreground shape, Ox's face against the fire.",
    actors=[actor("boss", (6.2, 0, -10.0), yaw=None, health=900)],
    beats=[down("P", 0.2), up("P", 0.55, True), slowmo(0.25, 1.8, 0.0, True)],
    keys=[key(0.0, CAM12, (6.1, 2.0, -10.0), fov=42, roll=-6.0), key(3.0, CAM12, (6.3, 2.1, -10.0), fov=36, roll=-6.0)]))

# 13. First person: Ox falls (ragdoll); the embers settle; the edit cuts to black on the hit sound.
SHOTS.append(dict(
    key="t13_ox_falls", number=13, edit_start=34.0, section=2, fp=True, player=((3.4, 0, -10.0), -90, 14), window=(0, 3.4),
    note="Shot 13 (0:34-0:37): the haymaker puts Ox down; he falls (ragdoll), the embers settle. The cut to black is the edit's (mark at 3.0 s).",
    actors=[actor("boss", (5.8, 0, -10.0), yaw=None, health=14)],
    beats=[down("P", 0.2), up("P", 0.55, True), pitch(-16, 0.7, 0.1, True), mark("cut_to_black", 2.4, True)]))

# 14. The title card's background (round 5): pure multiplane. The world look's own backdrops (the fire, the smoke, the skyline mattes) with no 3D kit,
# and a foreground roof-edge card with its chimney and antenna; the camera trucks slowly so the layers drift at their own speeds.
CAM14A = (2.0, 1.6, -10.4)
CAM14B = (2.0, 1.7, -8.4)
SHOTS.append(dict(
    key="t14_title_embers", number=14, edit_start=37.0, section=2, fp=False, player=((0, 0, -1.5), 0, 0), window=(0, 4.0),
    note="Shot 14 (0:37-0:41, round 5): the title card's background, a multiplane: the backdrops, no 3D kit, a foreground roof-edge card, a slow truck; the title is set in the edit.",
    actors=[], hide_kit=True,
    beats=[mark("title_in", 0.5)],
    keys=[key(0.0, CAM14A, (14.0, 4.6, -10.4), fov=60), key(4.0, CAM14B, (14.0, 5.4, -8.4), fov=54)],
    cards=[card([(-6.0, -1.0), (6.0, -1.0), (6.0, 1.8), (5.2, 1.85), (5.15, 2.4), (4.6, 2.42), (4.55, 1.9), (3.2, 1.95), (3.0, 1.7), (1.5, 1.7), (1.43, 2.9), (1.3, 3.0), (1.25, 3.12), (1.1, 3.12), (1.08, 3.0), (0.95, 2.9), (0.88, 1.75), (-0.4, 1.7), (-0.7, 2.1), (-1.9, 1.9), (-2.0, 1.6), (-3.6, 1.8), (-3.63, 2.4), (-3.66, 4.4), (-3.72, 2.45), (-3.9, 2.4), (-4.0, 1.9), (-5.2, 1.85), (-6.0, 1.7)], (6.0, 0.0, -9.4), -90.0, color=(0.07, 0.03, 0.07), drift=(0.0, 0.0, -0.2))]))


# ---- round 5: the first-person view of every first-person shot (CineViewRig) ------------------------------------------
# fov: the horizontal lens (55-60 degrees: below Tuning's floor of 75, written at run time); lift and back: the camera's own up and back (m), which
# lower the guard fist into the bottom edge and give the opponent's framing room; roll: a fixed bank (the fight set-ups alternate in sign, the
# establishing shot has none); off: the arm that shows only when a move strikes with it (the weapon shots hide the left one: the pipe is in the right hand).
FP_VIEW = {
    "t02_guard_up": dict(fov=58, lift=-0.04, back=0.06, roll=0.0, off="Right"),
    "t03_punk_combo": dict(fov=58, lift=-0.04, back=0.06, roll=-5.0, off="Right"),
    "t04_block_spin": dict(fov=58, lift=-0.04, back=0.08, roll=5.0, off="Right"),
    "t05_grab_throw": dict(fov=58, lift=-0.04, back=0.06, roll=-4.0, off="Right"),
    "t06_pipe_chain": dict(fov=58, lift=-0.04, back=0.06, roll=4.0, off="Left"),
    "t08_chain_whip": dict(fov=58, lift=-0.04, back=0.06, roll=5.0, off="Left"),
    "t09_back_elbow": dict(fov=58, lift=-0.04, back=0.06, roll=-5.0, off="Right"),
    "t11_ox_fight": dict(fov=58, lift=-0.03, back=0.15, roll=5.0, off="Right"),
    "t13_ox_falls": dict(fov=58, lift=-0.03, back=0.15, roll=4.0, off="Right"),
}

if __name__ == "__main__":
    for shot in SHOTS:
        shot.update(FP_VIEW.get(shot["key"], {}))
        write_shot(shot)
        print("wrote", shot["key"])
