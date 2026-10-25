# Milestone 3: judgement calls

A running log of the calls the lead (and the builders) made without asking Game-boy during M3, each with at least one alternative not taken and why. The Slack digest at the end of M3 is drawn from this file. Add an entry whenever a call shapes what Game-boy will play or how the work runs; keep each one short.

## Process and delivery
- **Resume after a usage limit wakes the same working session first.** A one-time scheduled task fires 10 minutes after the window resets and messages the session titled "Beat-em-up: working session"; only if that session is gone does it start a takeover session from HANDOFF.md. *Alternative:* always start a fresh takeover session, as M2 did at account switches. *Why not:* the same session keeps its context and Game-boy's ultracode opt-in, and a fresh one would re-read everything.
- **The watcher checks every 30 / 15 / 5 minutes (below 70%, to 85%, above)**, against 20 / 10 / 5 before the 5x premium seat. *Alternative:* keep the old cadence. *Why not:* the same work now moves the needle a fifth as fast; the fast-burn rule still pulls a check in when a big workflow runs.
- **The playable build is a release export with scripts kept as text.** *Alternative:* binary-token scripts (the default), a slightly smaller pack. *Why not:* the F1 panel's tooltips read the `##` doc comments from the script source, so binary tokens would leave only the default and the range.
- **Universal (Intel and Apple Silicon) macOS binary, ad-hoc signed.** *Alternative:* arm64 only, about half the size. *Why not:* it costs nothing that matters and runs on any Mac Game-boy picks up. Without an Apple Developer ID the app can't be notarized either way, so the first launch needs right-click → Open.
