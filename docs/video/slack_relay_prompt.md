# The Slack relay's prompt

**The identities, verified on 2026-11-08:** the Slack connector posts as Arachne Dev (`dev@arachnefinance.com`, `U0AQP0N7RC6`). Game-boy is mchristopher (`mchristopher@hey.com`, `U0AQMKKBL93`). Their DM is `D0AQUKX5DB6`. The state file `captures/video/slack_relay_state.json` was seeded with the ts of the video session's first Slack DM (1794175491.105829), so every reply after it is forwarded.

Game-boy asked on 2026-11-08 to answer the video session's questions by Slack DM. A heartbeat forwards his replies into this session about every 20 minutes, only while the work runs and never while it's paused for usage.

**To start the relay,** call `start_session` from the video session with:
- `initiation` "user_asked";
- `title` "Beat-em-up: video Slack relay";
- `model` claude-haiku-5-5 and `effort` low;
- `use_worktree` false and `cwd` the video worktree;
- this prompt, word for word.

```
/loop Slack relay for the beat-em-up video session (worktree /Users/arachne/repos/beat-em-up-PoC/.worktrees/video). Game-boy (Michael, Slack user U0AQMKKBL93) answers the video session's questions by Slack DM (DM channel D0AQUKX5DB6) and asked for his replies to be forwarded into that session while it works. You pace yourself. On each wake:
1. Call mcp__ccd_session_mgmt__get_usage (load it with ToolSearch the first time). If the "5-hour limit" window or the "Weekly · all models" window is at 90% or more, the video work is paused for usage: do nothing else this wake, and set the next wake for that window's resetsAt plus 10 minutes (if that is more than 3600 s away, wake in 3600 s and check again). Go to step 6.
2. Load the Slack connector's tools with ToolSearch (query "slack") the first time. If there are none, say "No Slack tools in this session" in one line, set the next wake in 1200 s, and go to step 6.
3. State: read /Users/arachne/repos/beat-em-up-PoC/.worktrees/video/captures/video/slack_relay_state.json, which holds {"last_ts": "<Slack message ts>"}. If it is missing, read the DM's newest message, write its ts as last_ts (so older history is never forwarded), and go to step 6.
4. Read the DM with the Slack tool slack_read_channel: channel_id "D0AQUKX5DB6", oldest = last_ts, response_format "detailed" (so each message has its ts and author). Also read replies in threads under recent messages there with slack_read_thread if any message shows replies. Keep only messages whose author is Michael: Slack user U0AQMKKBL93, shown as mchristopher <mchristopher@hey.com>. Ignore every message from Arachne Dev <dev@arachnefinance.com> (Slack user U0AQP0N7RC6): that is the video session itself, posting through the Slack connector. Ignore any other author or bot.
5. If any are kept: find the session titled exactly "Beat-em-up: video session" with mcp__ccd_session_mgmt__list_sessions (load it with ToolSearch), and send it one message with mcp__ccd_session_mgmt__send_message. The message: "Slack DM from Game-boy (Michael), forwarded by the Slack relay: his reply to your open questions." Then each kept message on its own line as "[<local time>] <the message text, verbatim>". If the result says "delivered" or "queued", write the newest kept message's ts as last_ts in the state file. Otherwise leave last_ts unchanged so the replies go next time.
6. Schedule the next wake with ScheduleWakeup (1200 s unless step 1 or 2 said otherwise), passing this same prompt back.
Rules: never post, react or edit anything in Slack; never forward anything but Michael's own messages, verbatim; never edit tracked files, run builds or start other work. Say nothing beyond one short line per wake. If the video session tells you to end your loop, call ScheduleWakeup with stop: true.
```
