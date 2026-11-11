"""Assemble the trailer from video/edit.json (docs/video/PLAN.md section 6, Phase 3: the EDIT package).

Usage: ~/.venvs/beat-em-up-video/bin/python -I tools/video/assemble.py [--no-audio] [--name NAME]
For each shot in the edit: its source (the newest Runway take in captures/video/planb/restyle/<tNN>_r<N>/, a named 'take', or our
1080p render for 'source': 'render'), trimmed to [in, out) frames, with its title overlay (an RGBA PNG from
captures/video/planb/titles/, faded in and out on its alpha) and any black frames after it. The sound is each shot's effects stem
(captures/video/planb/audio/<key>.wav, tools/video/planb_sound.py) trimmed the same way, short fades at every cut, silence on
black, then loudness-normalised in two passes (ffmpeg loudnorm) to the edit's target.
Writes captures/video/planb/final/<NAME>_1080p.mp4 (H.264 High at the edit's bitrate, AAC) and <NAME>_720p_labelled.mp4 (each
shot labelled, for notes), plus <NAME>_edl.txt (the cut list with the sources and the timecodes). Default NAME: planb_trailer_final.
"""
import argparse
import glob
import json
import os
import re
import subprocess
import sys

REPO = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
PLANB = os.path.join(REPO, "captures", "video", "planb")
FONT = "/System/Library/Fonts/Supplemental/Arial.ttf"


def run(cmd: list) -> None:
	subprocess.run(cmd, check=True)


def source_of(shot: dict) -> tuple:
	"""The shot's video and a name for it: a named take, the newest take, or our render."""
	key, short = shot["key"], shot["key"].split("_")[0]
	if shot.get("source") == "render":
		return os.path.join(PLANB, "inputs", f"{key}_1080.mp4"), "our render"
	if shot.get("take"):
		take = shot["take"]
	else:
		takes = [os.path.basename(d) for d in glob.glob(os.path.join(PLANB, "restyle", f"{short}_r*"))
			if os.path.isfile(os.path.join(d, os.path.basename(d) + ".mp4"))]
		if not takes:
			sys.exit(f"{key}: no Runway take and no 'source': 'render'")
		take = max(takes, key=lambda t: int(re.search(r"_r(\d+)$", t).group(1)))
	return os.path.join(PLANB, "restyle", take, take + ".mp4"), take


def timecode(frames: int, fps: int) -> str:
	return f"{frames // fps // 60:02d}:{frames // fps % 60:02d}:{frames % fps:02d}"


def video_segments(edit: dict, work: str) -> tuple:
	"""One intermediate file per shot (and per black gap), near-lossless; the list file; the EDL lines."""
	fps = edit["fps"]
	w, h = edit["size"]
	parts, edl, t = [], [], 0
	for i, shot in enumerate(edit["shots"]):
		src, name = source_of(shot)
		n = shot["out"] - shot["in"]
		out = os.path.join(work, f"{i:02d}_{shot['key']}.mp4")
		chain = (f"[0:v]trim=start_frame={shot['in']}:end_frame={shot['out']},setpts=PTS-STARTPTS,"
			f"scale={w}:{h}:flags=lanczos,fps={fps},format=yuv420p[v]")
		inputs = ["-i", src]
		ov = shot.get("overlay")
		if ov:
			image = os.path.join(PLANB, "titles", ov["image"])
			if not os.path.isfile(image):
				sys.exit(f"{shot['key']}: no title image {image} (tools/video/planb_titles.py)")
			start = ov["in"] - shot["in"]
			dur = (ov["out"] - ov["in"]) / fps
			fade = ov["fade"] / fps
			inputs += ["-loop", "1", "-framerate", str(fps), "-i", image]
			chain += (f";[1:v]format=rgba,trim=end_frame={n},setpts=PTS-STARTPTS,"
				f"fade=t=in:st={start / fps}:d={fade}:alpha=1,fade=t=out:st={start / fps + dur - fade}:d={fade}:alpha=1[o];"
				f"[v][o]overlay=0:0:shortest=1:format=auto,format=yuv420p[v]")
		run(["ffmpeg", "-v", "error", "-y", *inputs, "-filter_complex", chain, "-map", "[v]", "-frames:v", str(n),
			"-c:v", "libx264", "-crf", "10", "-preset", "medium", "-an", out])
		parts.append(out)
		edl.append(f"{timecode(t, fps)}  {shot['key']:<18} {name:<12} frames {shot['in']}-{shot['out']} ({n / fps:.2f} s)"
			+ (f"  + {ov['image']}" if ov else ""))
		t += n
		black = shot.get("black_after", 0)
		if black:
			out = os.path.join(work, f"{i:02d}_black.mp4")
			run(["ffmpeg", "-v", "error", "-y", "-f", "lavfi", "-i", f"color=c=black:s={w}x{h}:r={fps}", "-frames:v", str(black),
				"-c:v", "libx264", "-crf", "10", "-pix_fmt", "yuv420p", out])
			parts.append(out)
			edl.append(f"{timecode(t, fps)}  black              {black} frames")
			t += black
	listing = os.path.join(work, "video_list.txt")
	with open(listing, "w") as f:
		f.writelines(f"file '{p}'\n" for p in parts)
	return listing, edl, t


def audio_track(edit: dict, work: str, total_frames: int) -> str:
	"""The effects stems cut like the picture, faded at every cut, silence on black; then loudness-normalised."""
	fps = edit["fps"]
	fade = edit["audio"]["edge_fade_ms"] / 1000
	parts = []
	for i, shot in enumerate(edit["shots"]):
		stem = os.path.join(PLANB, "audio", f"{shot['key']}.wav")
		start, dur = shot["in"] / fps, (shot["out"] - shot["in"]) / fps
		out = os.path.join(work, f"{i:02d}_{shot['key']}.wav")
		if os.path.isfile(stem):
			run(["ffmpeg", "-v", "error", "-y", "-i", stem, "-af", f"atrim=start={start}:duration={dur},asetpts=PTS-STARTPTS,"
				f"apad=whole_dur={dur},afade=t=in:d={fade},afade=t=out:st={max(0.0, dur - fade)}:d={fade},aresample=48000",
				"-ac", "2", "-c:a", "pcm_s24le", out])
		else:
			print(f"  {shot['key']}: no stem, silence")
			run(["ffmpeg", "-v", "error", "-y", "-f", "lavfi", "-i", "anullsrc=r=48000:cl=stereo", "-t", str(dur),
				"-c:a", "pcm_s24le", out])
		parts.append(out)
		black = shot.get("black_after", 0)
		if black:
			out = os.path.join(work, f"{i:02d}_black.wav")
			run(["ffmpeg", "-v", "error", "-y", "-f", "lavfi", "-i", "anullsrc=r=48000:cl=stereo", "-t", str(black / fps),
				"-c:a", "pcm_s24le", out])
			parts.append(out)
	listing = os.path.join(work, "audio_list.txt")
	with open(listing, "w") as f:
		f.writelines(f"file '{p}'\n" for p in parts)
	raw = os.path.join(work, "audio_raw.wav")
	run(["ffmpeg", "-v", "error", "-y", "-f", "concat", "-safe", "0", "-i", listing, "-t", str(total_frames / fps),
		"-c:a", "pcm_s24le", raw])
	# Effects alone are short hits over a quiet bed: their peaks sit about 20 dB over their loudness, and -14 LUFS under -1 dBTP
	# allows about 13. So, as trailers are mixed: gain into a brick-wall limiter first, then loudnorm in two passes (measure,
	# then apply with the measured values; linear when it can be), aiming the true peak a little lower for the AAC encode.
	a = edit["audio"]
	target, tp = a["lufs"], a["true_peak_db"] - a["encode_margin_db"]
	dyn = os.path.join(work, "audio_dyn.wav")
	run(["ffmpeg", "-v", "error", "-y", "-i", raw, "-af", f"volume={a['pre_gain_db']}dB,alimiter=limit={a['limit']}:attack=1:"
		f"release=60:level=false", "-c:a", "pcm_s24le", dyn])
	probe = subprocess.run(["ffmpeg", "-hide_banner", "-i", dyn, "-af", f"loudnorm=I={target}:TP={tp}:LRA=11:print_format=json",
		"-f", "null", "-"], capture_output=True, text=True).stderr
	m = json.loads(probe[probe.rindex("{"):probe.rindex("}") + 1])
	final = os.path.join(work, "audio_final.wav")
	run(["ffmpeg", "-v", "error", "-y", "-i", dyn, "-af",
		f"loudnorm=I={target}:TP={tp}:LRA=11:measured_I={m['input_i']}:measured_TP={m['input_tp']}:measured_LRA={m['input_lra']}:"
		f"measured_thresh={m['input_thresh']}:offset={m['target_offset']}:linear=true,aresample=48000",
		"-c:a", "pcm_s24le", final])
	print(f"  sound: measured {m['input_i']} LUFS, true peak {m['input_tp']} dBTP; normalised to {target} LUFS")
	return final


def main() -> None:
	ap = argparse.ArgumentParser()
	ap.add_argument("--no-audio", action="store_true")
	ap.add_argument("--name", default="planb_trailer_final")
	ap.add_argument("--reuse-picture", action="store_true", help="keep work/picture.mp4 from the last run (a sound-only change)")
	args = ap.parse_args()
	with open(os.path.join(REPO, "video", "edit.json")) as f:
		edit = json.load(f)
	fps = edit["fps"]
	final_dir = os.path.join(PLANB, "final")
	work = os.path.join(final_dir, "work")
	os.makedirs(work, exist_ok=True)
	picture = os.path.join(work, "picture.mp4")
	if args.reuse_picture and os.path.isfile(picture):
		total = sum(s["out"] - s["in"] + s.get("black_after", 0) for s in edit["shots"])
		edl = [f"(picture reused from the last run: {total} frames)"]
	else:
		listing, edl, total = video_segments(edit, work)
		fin, fout = edit["fade_in_frames"] / fps, edit["fade_out_frames"] / fps
		run(["ffmpeg", "-v", "error", "-y", "-f", "concat", "-safe", "0", "-i", listing, "-vf",
			f"fade=t=in:st=0:d={fin},fade=t=out:st={total / fps - fout}:d={fout}", "-c:v", "libx264", "-crf", "10",
			"-preset", "medium", "-pix_fmt", "yuv420p", picture])
	ex = edit["export"]
	out = os.path.join(final_dir, f"{args.name}_1080p.mp4")
	enc = ["-c:v", "libx264", "-profile:v", "high", "-b:v", ex["video_bitrate"], "-maxrate", ex["maxrate"], "-bufsize", ex["bufsize"],
		"-preset", "slow", "-pix_fmt", "yuv420p", "-movflags", "+faststart"]
	if args.no_audio:
		run(["ffmpeg", "-v", "error", "-y", "-i", picture, *enc, "-an", out])
	else:
		sound = audio_track(edit, work, total)
		run(["ffmpeg", "-v", "error", "-y", "-i", picture, "-i", sound, "-map", "0:v", "-map", "1:a", *enc, "-c:a", "aac",
			"-b:a", ex["audio_bitrate"], "-ar", "48000", "-shortest", out])
	# The labelled 720p copy for notes: each shot's key over its stretch (PIL labels; this ffmpeg has no drawtext).
	from PIL import Image, ImageDraw, ImageFont
	font = ImageFont.truetype(FONT, 22)
	inputs, chain, last, t = ["-i", out], "[0:v]scale=1280:720[v0]", "v0", 0
	for i, shot in enumerate(edit["shots"]):
		n = shot["out"] - shot["in"]
		text = f"{shot['key']}  ·  {source_of(shot)[1]}"
		image = os.path.join(work, f"label_{i:02d}.png")
		im = Image.new("RGBA", (int(font.getlength(text)) + 24, 36), (0, 0, 0, 150))
		ImageDraw.Draw(im).text((12, 6), text, font=font, fill=(255, 255, 255, 235))
		im.save(image)
		inputs += ["-i", image]
		chain += f";[{last}][{i + 1}:v]overlay=16:main_h-overlay_h-12:enable='between(n,{t},{t + n - 1})'[v{i + 1}]"
		last = f"v{i + 1}"
		t += n + shot.get("black_after", 0)
	labelled = os.path.join(final_dir, f"{args.name}_720p_labelled.mp4")
	run(["ffmpeg", "-v", "error", "-y", *inputs, "-filter_complex", chain, "-map", f"[{last}]", "-map", "0:a?", "-c:v", "libx264",
		"-crf", "20", "-preset", "medium", "-c:a", "copy", labelled])
	with open(os.path.join(final_dir, f"{args.name}_edl.txt"), "w") as f:
		f.write("\n".join(edl) + f"\nend {timecode(total, fps)} ({total / fps:.2f} s)\n")
	print("\n".join(edl))
	if not args.no_audio:
		# The check on the encoded file: integrated loudness and true peak (ebur128).
		r = subprocess.run(["ffmpeg", "-hide_banner", "-nostats", "-i", out, "-af", "ebur128=peak=true", "-f", "null", "-"],
			capture_output=True, text=True).stderr
		summary = r[r.rindex("Summary:"):]
		i = re.search(r"I:\s+(-?[\d.]+) LUFS", summary).group(1)
		peak = re.search(r"True peak:\s+Peak:\s+(-?[\d.]+) dBFS", summary).group(1)
		print(f"  the encoded file: {i} LUFS integrated, true peak {peak} dBTP")
	print(f"wrote {os.path.relpath(out, REPO)} and {os.path.relpath(labelled, REPO)} ({total / fps:.2f} s)")


if __name__ == "__main__":
	main()
