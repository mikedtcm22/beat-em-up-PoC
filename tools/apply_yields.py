#!/usr/bin/env python3
"""Write tools/solve_insets.gd's YIELD lines into the Mission 1 section scenes (M6 VFIX-WORLD).

Usage: tools/apply_yields.py <solver output file>

Every block named in a line becomes an InsetBlock with its `yields_to`; an InsetBlock the output does not name goes back to a
plain LevelBlock. Run it on scenes whose `yields_to` lines are removed (it replaces them either way). To strip the scenes for a
fresh solve, delete the lines (`sed -i '' '/^yields_to = /d' <scene>`); don't run this tool on an empty output for that.
The InsetBlock ext_resource is kept, or put back, whenever a block uses it.
"""
import re
import sys
from collections import defaultdict

FILES = {
    "Street": "game/level/mission1/street.tscn",
    "Roofs": "game/level/mission1/roofs.tscn",
    "BossRoof": "game/level/mission1/boss_roof.tscn",
}


def main() -> None:
    wanted: dict[str, dict[str, list[str]]] = defaultdict(lambda: defaultdict(list))
    for line in open(sys.argv[1]):
        if not line.startswith("YIELD "):
            continue
        section, node, target = line[6:].rstrip("\n").split("|")
        wanted[section][node].append(target)
    for section, path in FILES.items():
        text = open(path).read()
        plain_id = re.search(r'path="res://game/level/kit/level_block.gd" id="([^"]+)"', text).group(1)
        # Split into node blocks: a header line and the lines up to the next header.
        parts = re.split(r"(?m)^(?=\[node |\[ext_resource |\[connection |\[sub_resource )", text)
        out = []
        for part in parts:
            header = re.match(r'\[node name="([^"]+)" type="[^"]+" parent="([^"]+)"', part)
            if header and 'script = ExtResource("inset_blk")' in part or (header and header.group(2).startswith("Geometry") and wanted[section].get(header.group(2) + "/" + header.group(1)) is not None):
                node = header.group(2) + "/" + header.group(1)
                targets = wanted[section].get(node)
                part = re.sub(r"(?m)^yields_to = .*\n", "", part)
                if targets:
                    part = part.replace('script = ExtResource("%s")' % plain_id, 'script = ExtResource("inset_blk")')
                    arr = ", ".join('NodePath("%s")' % t for t in targets)
                    part = re.sub(r'(?m)^(script = ExtResource\("inset_blk"\)\n)', r"\1yields_to = Array[NodePath]([%s])\n" % arr, part, count=1)
                else:
                    part = part.replace('script = ExtResource("inset_blk")', 'script = ExtResource("%s")' % plain_id)
            out.append(part)
        text = "".join(out)
        used = 'ExtResource("inset_blk")' in text
        declared = re.search(r'(?m)^\[ext_resource [^\n]*id="inset_blk"\]\n', text) is not None
        if not used:
            text = re.sub(r'(?m)^\[ext_resource [^\n]*id="inset_blk"\]\n', "", text)
        elif not declared:
            # Put the declaration back after the LevelBlock one, so a scene stripped earlier still parses.
            text = re.sub(r'(?m)^(\[ext_resource [^\n]*path="res://game/level/kit/level_block.gd"[^\n]*\]\n)',
                    r'\1[ext_resource type="Script" path="res://game/level/kit/inset_block.gd" id="inset_blk"]\n', text, count=1)
        open(path, "w").write(text)
        print(section, sum(len(v) for v in wanted[section].values()), "yields")


main()
