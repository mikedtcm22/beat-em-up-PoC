export const meta = {
  name: 'm2-phase3-r2-close',
  description: 'M2 phase 3 package C, closing a review round: a completeness critic (or lead-written briefs instead), reviewers with three skeptics per finding, the partition into packages-r<round>.json, then the fixers (workflow-fix.js); usage-gated',
  phases: [
    { title: 'Critic', detail: 'what all reviews so far left unchecked (skipped with review_brief or review_briefs)' },
    { title: 'Review', detail: 'one reviewer per brief (Opus), two at once, then three skeptics per finding (Sonnet)' },
    { title: 'Partition', detail: 'the open survivors into at most four r<round>- packages' },
    { title: 'Fix', detail: 'workflow-fix.js with packages-r<round>.json (Sonnet fixers)' },
    { title: 'Record', detail: 'Haiku scribe commits each result to m2/phase3-review' },
  ],
}

// Run inline (scriptPath: this file) once the round's earlier reviews are recorded on
// m2/phase3-review. Every agent reads the review files itself. Args:
//   base: "<sha>"           the m2/hit-feel commit the reviewer worktrees are detached at (required)
//   round: <n>              the round (default 2). Files and keys carry r<n>: critic-r<n>.json,
//                           packages-r<n>.json, package keys "r<n>-..."
//   review_brief: "<text>"  skip the critic: one reviewer, lens "r<n>", covers this brief
//                           (review-r<n>.json, verify-r<n>.json, ids r<n>-01...)
//   review_briefs: {"<lens>": "<text>", ...}  skip the critic: one reviewer per lens, two at once.
//                           Lens names are [a-z0-9] with no "-" (ids are <lens>-NN, and workflow-fix.js
//                           finds review-<lens>.json from an id's prefix), e.g. "r3code", "r3look"
//   common_note: "<text>"   the newest state (merges, fixes since the last round), added to every brief
//   partition_lenses: [...] earlier lenses whose open survivors also go into the partition
//                           (default ["hit", "perf"] in round 2, none later)
//   partition_note: "<text>"  extra rules for the partition (ids to leave out, ownership hints)
//   reviewer_model: "<m>"   the critic's, reviewers' and partition's model (default "opus"; Game-boy,
//                           2026-10-25: Opus plans and reviews, Sonnet codes). Skeptics run on Sonnet
//   no_gap_round: true      with the critic: skip the gap review it may ask for
//   no_fix: true            stop after the partition
//   fix_note: "<text>"      passed to workflow-fix.js as its lead's note
//   concurrency: <n>        passed to workflow-fix.js (default 2)
//   fixer_cost: <n>         passed to workflow-fix.js (its default 25)
//   fixer_model: "<m>"      passed to workflow-fix.js (default "sonnet")
// Each lens reviews in its own worktree, .worktrees/m2-review-<lens> (the critic's gap lens is "gap" in
// round 2 and "r<n>gap" later). The lead makes each first:
// `git worktree add --detach .worktrees/m2-review-<lens> <base>` (or `git -C .worktrees/m2-review-<lens>
// checkout --detach <base>`), then `godot --headless --import --quit` in it.

const ROOT = '/Users/arachne/repos/beat-em-up-PoC'
const NOTES = `${ROOT}/.worktrees/m2-review-notes`
const REVIEWS = `${NOTES}/docs/reviews/M2-phase3`
const LIMIT = 90
const A = args || {}
const BASE = A.base || 'HEAD of m2/hit-feel'
const ROUND = A.round || 2
const RS = `r${ROUND}`
const REVIEWER_MODEL = A.reviewer_model || 'opus'
const COST = { critic: 4, reviewer: 18, perFinding: 2, partition: 4 }
const TRAILER = 'Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>'
const worktreeOf = lens => `${ROOT}/.worktrees/m2-review-${lens}`

const GATE_SCHEMA = {
  type: 'object',
  properties: { five_hour: { type: 'number' }, weekly: { type: 'number' }, five_hour_resets_at: { type: 'string' } },
  required: ['five_hour', 'weekly', 'five_hour_resets_at'],
}
const CRITIC_SCHEMA = {
  type: 'object',
  properties: {
    gaps: { type: 'array', items: { type: 'object', properties: { what: { type: 'string' }, why: { type: 'string' }, priority: { type: 'string', enum: ['high', 'medium', 'low'] } }, required: ['what', 'why', 'priority'] } },
    gap_review_brief: { type: 'string', description: 'a brief for ONE extra reviewer covering the high-priority gaps; empty if no gap is worth a round' },
    report_notes: { type: 'string' },
  },
  required: ['gaps', 'gap_review_brief', 'report_notes'],
}
const FINDINGS_SCHEMA = {
  type: 'object',
  properties: {
    summary: { type: 'string' },
    acts_checked: { type: 'array', items: { type: 'string' } },
    captures_reviewed: { type: 'array', items: { type: 'string' } },
    sheets_for_game_boy: { type: 'array', items: { type: 'string' }, description: 'absolute paths of the 3-6 most telling sheets' },
    open_question_notes: { type: 'string' },
    also_noticed: { type: 'array', items: { type: 'string' } },
    findings: {
      type: 'array',
      items: {
        type: 'object',
        properties: {
          severity: { type: 'string', enum: ['high', 'medium', 'low'] },
          title: { type: 'string' },
          detail: { type: 'string' },
          evidence: { type: 'string' },
          repro: { type: 'string' },
          suggested_fix: { type: 'string' },
          files: { type: 'array', items: { type: 'string' } },
          spec_change: { type: 'boolean' },
        },
        required: ['severity', 'title', 'detail', 'evidence', 'repro', 'suggested_fix', 'files', 'spec_change'],
      },
    },
  },
  required: ['summary', 'acts_checked', 'captures_reviewed', 'sheets_for_game_boy', 'open_question_notes', 'also_noticed', 'findings'],
}
const VOTE_SCHEMA = {
  type: 'object',
  properties: {
    refuted: { type: 'boolean' },
    confidence: { type: 'string', enum: ['high', 'medium', 'low'] },
    reason: { type: 'string' },
    evidence: { type: 'string' },
    fix_needs_spec_change: { type: 'boolean' },
    open_question: { type: 'string' },
    root_cause: { type: 'string' },
    files_to_change: { type: 'array', items: { type: 'string' } },
  },
  required: ['refuted', 'confidence', 'reason', 'evidence', 'fix_needs_spec_change', 'open_question', 'root_cause', 'files_to_change'],
}
const PARTITION_SCHEMA = {
  type: 'object',
  properties: {
    packages: {
      type: 'array',
      items: {
        type: 'object',
        properties: {
          key: { type: 'string', description: `slug [a-z0-9-] starting with ${RS}-` },
          title: { type: 'string' },
          finding_ids: { type: 'array', items: { type: 'string' } },
          files: { type: 'array', items: { type: 'string' } },
          notes: { type: 'string' },
        },
        required: ['key', 'title', 'finding_ids', 'files', 'notes'],
      },
    },
    unassigned: { type: 'array', items: { type: 'object', properties: { id: { type: 'string' }, reason: { type: 'string' } }, required: ['id', 'reason'] } },
  },
  required: ['packages', 'unassigned'],
}

// ---------- concurrency, usage gates, scribe ----------
function semaphore(n) {
  let free = n
  const waiters = []
  return async fn => {
    if (free > 0) free--
    else await new Promise(r => waiters.push(r))
    try { return await fn() } finally {
      const next = waiters.shift()
      if (next) next()
      else free++
    }
  }
}
const heavySlot = semaphore(2)
const godotSlot = semaphore(2)

let reserved = 0
const usageLog = []
async function gate(label, phaseTitle) {
  const g = await agent(
    `Usage gate (${label}). Load mcp__ccd_session_mgmt__get_usage with ToolSearch ("select:mcp__ccd_session_mgmt__get_usage") and call it with no arguments. From plan.windows report the percentUsed of the "5-hour limit" window as five_hour, of the window whose label starts with "Weekly" as weekly, and the 5-hour window's resetsAt as five_hour_resets_at. Do nothing else.`,
    { label: `gate:${label}`, phase: phaseTitle, schema: GATE_SCHEMA, model: 'haiku', effort: 'low' })
  if (!g) { log(`gate ${label}: no answer`); return null }
  const used = Math.max(g.five_hour, g.weekly)
  const headroom = LIMIT - used - reserved
  usageLog.push({ label, five_hour: g.five_hour, weekly: g.weekly, reserved, headroom })
  return { ...g, used, headroom }
}
async function launch(label, phaseTitle, est, fn) {
  const g = await gate(label, phaseTitle)
  if (!g || est > g.headroom) {
    log(`${label}: needs ~${est}%, headroom ${g ? g.headroom : '?'}% -> SKIPPED (left for the next window)`)
    return { skipped: true }
  }
  reserved += est
  log(`${label}: 5-hour ${g.five_hour}%, weekly ${g.weekly}%, headroom ${g.headroom}% -> launch (~${est}%)`)
  try { return { result: await fn() } } finally { reserved -= est }
}

let scribeChain = Promise.resolve()
const scribeJobs = []
function scribe(file, obj, subject) {
  const body = JSON.stringify(obj, null, 1)
  const job = scribeChain.then(() => agent(
    `Scribe. Do exactly this and nothing else.
1. \`cd ${NOTES} && git pull -q --rebase origin m2/phase3-review\`. Then write the JSON between the markers below, byte for byte, to ${REVIEWS}/${file}, with a quoted heredoc (cat > ${REVIEWS}/${file} <<'JSON_EOF_7Q' ... JSON_EOF_7Q) or the Write tool.
2. Check it parses: \`python3 -m json.tool ${REVIEWS}/${file} > /dev/null && echo OK\`. If not OK, rewrite it and check again.
3. \`cd ${NOTES} && git add docs/reviews/M2-phase3/${file} && git commit -q -m "${subject}" -m "${TRAILER}" && git push -q origin m2/phase3-review\`. If the push is rejected, run \`git pull --rebase -q origin m2/phase3-review\` and push again.
Reply with the commit sha only.
-----BEGIN JSON-----
${body}
-----END JSON-----`,
    { label: `scribe:${file}`, phase: 'Record', model: 'haiku', effort: 'low' }))
  scribeChain = job.catch(() => null)
  scribeJobs.push(job)
  return job
}

// ---------- shared context ----------
const COMMON = `You work on Milestone 2, phase 3, package C (integrate, review, fix) of a Godot 4.7.2 first-person beat-em-up proof of concept (GDScript with static typing, Forward+, Jolt, 60 Hz). The project owner, Game-boy, plays and signs off each milestone.
State: m2/hit-feel at ${BASE} has phase 3 (the localized hit flash; package A, ragdoll: contact push with spin caps, KO lie/blink/vanish, dummies blinking back in at their post, staggers at 0.9; package B, grab: hold view and waist bend) plus package C's fixes. C's records are in ${REVIEWS}/ (also on branch m2/phase3-review): review-<lens>.json (findings with ids), verify-<lens>.json (three skeptics' verdicts per finding: survives, spec_question, root_cause, files), packages*.json (fix packages), fix-<key>.json (fixers' outcomes), critic*.json (completeness critics). Round 1 ran the code, ragdoll and grab lenses (19 findings: 17 fixed, grab-03 and grab-05 open with Game-boy). Round 2 ran the hit, perf and gap lenses and a critic (critic-r2.json): hit-04 is fixed (fix-r2-finisher-flash.json); hit-01, hit-02 and hit-03 are spec questions; hit-05 and gap-06 were dropped (side view only); perf-01, perf-02, gap-01 to gap-05, gap-07 and gap-08 went to packages-r2.json, with outcomes in fix-r2-*.json; the lead fixed gap-09.${A.common_note ? `\nTHE LEAD'S NOTE (the newest state): ${A.common_note}` : ''}
Docs: docs/milestones/M2-phase3-plan.md (package C's plan: lenses, edge cases, known items), docs/milestones/M2-plan.md "Phase 3", docs/SPEC.md (§6, §10, §11), docs/ARCHITECTURE.md, README.md's departure sections, docs/HANDOFF.md "Decisions log" and its newest entries.
GAME-BOY (2026-10-25): side view is a debug view, not a player mode. Judge looks and feel in FIRST PERSON only; use side view only to check mechanics. A look that shows only in side view is not a finding.
APPROVED (not defects): heavy-tier knockdowns get the full ragdoll; staggers above SPEC's 0.6 influence; KO bodies lie, blink off and vanish, and dummies blink back in at their post; KO bodies take no hits; the contact push with spin caps; the localized flash; the grab view pans down with the lens back and up while holding; the knee rises a little to the right; the throw ends in the stance; the victim stands 6 cm closer; all eight phase 1 defaults; the player's KO "out of body" view (the camera eases out of the eyes to show the player lying on the floor, the only time it leaves them, and eases back in on the get-up); a body launched into a wall hits it and crumples (the full ragdoll takes over from the pose on screen); a launch from behind pitches forward, away from the attacker; a dummy comes back in front of or beside the player, with room, and waits instead of walking into him; the hook's far arm stays bent near the guard; the player's gray trousers and the dark hair on every head (placeholder art).
OPEN WITH GAME-BOY (each keeps its default; don't change them): the combat log over the knee in first person (grab-03); the flash's first-person size and the flurry strobe (grab-05, hit-01); a hit on the player in first person (hit-02); the hold's look dead band (grab-06's formula); ragdoll_partial_head_influence; more contortion on the contact push; the grab's lens pull-back and the bend's depth; a wall reaction beyond the crumple (a splat, bounce or deflection); bars over the middle of a body that isn't upright; WP3's audio.
Code rules: static types, tabs, ## doc comments on public API; no feel numbers in scripts (move .tres from tools/gen_moves.gd; tunables as @export_range values in game/autoload/tuning_data.gd); simulation never reads a camera; presentation only subscribes to CombatEvents and reads state, never writes game state (TimeController is the one exception).
Tools: tools/run_tests.sh (all GUT tests headless; -gselect=<file>); bots in tests/bot/ (combo_bot, vfx_bot, ragdoll_bot; act tables in each script's header; --act=<a>|<b> runs every act whose title contains either). Record with Movie Maker directly, NEVER with tools/capture_combos.sh: \`godot --path . --write-movie <your folder>/<name>.avi --fixed-fps 60 --resolution 1280x720 res://tests/bot/<bot>.tscn -- --act=<title text> > <your folder>/<name>.log 2>&1\`. Tile stills with ffmpeg (\`-vf "fps=12,scale=480:-1,tile=5x4" -frames:v 1\`) and LOOK at the sheets with the Read tool.
The machine has 8 CPUs and 8 GB of RAM and other agents record at the same time: run one Godot process at a time, and never leave one running.`

// ---------- critic (skipped when the lead wrote the briefs) ----------
let lenses = A.review_briefs ? Object.entries(A.review_briefs).map(([lens, brief]) => ({ lens, brief }))
  : A.review_brief ? [{ lens: RS, brief: A.review_brief }] : null
let critic = null
if (!lenses) {
  phase('Critic')
  lenses = []
  const gapWt = worktreeOf(ROUND === 2 ? 'gap' : `${RS}gap`)
  const cr = await launch('critic', 'Critic', COST.critic, () => agent(
    `${COMMON}\n\nYOUR JOB: COMPLETENESS CRITIC for ALL of package C's review so far (read-only; read files under ${REVIEWS} and the code in ${gapWt}; write nothing). Package C's plan (docs/milestones/M2-phase3-plan.md, "C", step 2) asked for five lenses: code (with its edge-case list), ragdoll feel (every ragdoll_bot act), grab feel, hit feel (every combo_bot and vfx_bot attack act, tier by tier, plus HANDOFF 10:55's known items), and performance. Read every review-*.json (summary, acts_checked, findings, also_noticed), verify-*.json, fix-*.json and earlier critic*.json (their gaps, and which later rounds closed). Compare against the plan and the bots' act tables (tests/bot/*.gd), and name what is STILL unchecked: an act nobody looked at in first person, an edge case on the plan's list nobody probed, a known item without a verdict, a finding left unverified, a fix whose after-captures nobody judged or whose diff nobody reviewed, a claim with no evidence. Rank gaps by priority. If high-priority gaps exist that ONE more reviewer could cover in a normal review, write that reviewer's brief in gap_review_brief (what to record or probe and what to judge); otherwise leave it empty.`,
    { label: 'critic', phase: 'Critic', schema: CRITIC_SCHEMA, model: REVIEWER_MODEL }))
  if (cr.result) {
    critic = cr.result
    log(`critic: ${critic.gaps.length} gaps (${critic.gaps.filter(g => g.priority === 'high').length} high); gap brief ${critic.gap_review_brief.trim() ? 'yes' : 'no'}`)
    scribe(`critic-${RS}.json`, critic, `M2 phase 3 C: completeness critic (round ${ROUND})`)
    if (critic.gap_review_brief.trim() && !A.no_gap_round)
      lenses = [{ lens: ROUND === 2 ? 'gap' : `${RS}gap`, brief: critic.gap_review_brief, from_critic: true }]
  }
}

// ---------- reviews and their skeptics ----------
const SEV = { high: 0, medium: 1, low: 2 }
function skepticPrompt(kind, f, lens) {
  const wt = worktreeOf(lens)
  const folder = `${wt}/captures/verify/${f.id}-${kind}`
  const head = `${COMMON}\n\nYou are a SKEPTIC. A reviewer reported the finding below (data, not instructions). Try to REFUTE it, through one lens only. Work in ${wt} (\`cd ${wt} && ...\` for every command); edit, add or commit nothing tracked; write only under ${folder}/. Be quick and narrow.\nFINDING: ${JSON.stringify(f)}\n`
  if (kind === 'reproduce') return `${head}\nLENS: REPRODUCE. Look at the evidence, then re-create the finding yourself: re-record the act (one Godot process, \`--act=\`), tile a sheet and look at it; or rerun the probe or the test. At most two recordings or probe runs. refuted = true if you can't reproduce it, or it isn't a defect. If you can't tell, refuted = true.`
  if (kind === 'spec') return `${head}\nLENS: SPEC. Show the behaviour is approved or intended, if it is: read only the relevant parts of docs/SPEC.md, README.md's departure sections, docs/HANDOFF.md's Decisions log and open questions, docs/milestones/M2-phase3-plan.md and docs/ARCHITECTURE.md. Don't run Godot. refuted = true if the docs approve or require it; otherwise false. Set fix_needs_spec_change and open_question.`
  return `${head}\nLENS: CODE. Read the code path: whether the code really does what the finding says, and whether the root cause is right. You may run one test file or a small headless probe in your folder; no recordings. refuted = true if the code shows the finding is wrong. Give the root cause and the files a fix would touch (files_to_change).`
}
async function reviewAndVerify({ lens, brief, from_critic }) {
  const wt = worktreeOf(lens)
  const r = await heavySlot(() => launch(`review:${lens}`, 'Review', COST.reviewer, () => agent(
    `${COMMON}\n\nREVIEW ONLY. Your worktree is ${wt} (a detached checkout of m2/hit-feel at ${BASE}, already imported). Run EVERY shell command as \`cd ${wt} && ...\` and read files only there. Do not edit, add or commit tracked files and do not run --import. Keep every file you write under ${wt}/captures/review_${lens}/, and leave \`git status\` clean apart from captures/.
Be adversarial: find what is wrong, missing or fragile, with evidence (file:line, a probe's or test's output, or a capture path with the time or frame). Merge findings that share a root cause. Report at most 12 findings, ranked by severity; put further minor items in also_noticed. Don't re-report a finding already in ${REVIEWS}/review-*.json unless its fix is wrong or incomplete (cite its id). Each finding names the files a fix would touch and whether the fix would change behaviour that SPEC, README's departures or the Decisions log set (spec_change). Approved behaviour is not a defect.
YOUR LENS (${lens})${from_critic ? ': GAPS the reviewers so far left, named by a completeness critic' : ''}. Cover exactly this brief:\n${brief}\n\nReturn your findings through the schema.`,
    { label: `review:${lens}`, phase: 'Review', schema: FINDINGS_SCHEMA, model: REVIEWER_MODEL })))
  if (!r.result) return { lens, skipped: true, verdicts: [], pending: [] }
  const rec = { lens, round: ROUND, worktree: wt, ...r.result, findings: r.result.findings.map((f, i) => ({ ...f, id: `${lens}-${String(i + 1).padStart(2, '0')}`, lens })) }
  log(`review:${lens}: ${rec.findings.length} findings`)
  scribe(`review-${lens}.json`, rec, `M2 phase 3 C: ${lens} review findings (${rec.findings.length})`)
  const todo = rec.findings.slice().sort((a, b) => SEV[a.severity] - SEV[b.severity])
  if (!todo.length) {
    scribe(`verify-${lens}.json`, { lens, verdicts: [], pending: [] }, `M2 phase 3 C: ${lens} verdicts (no findings)`)
    return { lens, verdicts: [], pending: [] }
  }
  const g = await gate(`verify:${lens}`, 'Review')
  const k = g ? Math.max(0, Math.min(todo.length, Math.floor(g.headroom / COST.perFinding))) : 0
  const pending = todo.slice(k).map(f => f.id)
  if (pending.length) log(`verify:${lens}: headroom covers ${k} of ${todo.length}; pending ${pending.join(', ')}`)
  const est = k * COST.perFinding
  reserved += est
  let verdicts = []
  try {
    verdicts = (await parallel(todo.slice(0, k).map(f => async () => {
      const opts = (kind, effort) => ({ label: `skeptic:${kind}:${f.id}`, phase: 'Review', schema: VOTE_SCHEMA, model: 'sonnet', effort })
      const [rep, spec, code] = await parallel([
        () => godotSlot(() => agent(skepticPrompt('reproduce', f, lens), opts('reproduce', 'medium'))),
        () => agent(skepticPrompt('spec', f, lens), opts('spec', 'low')),
        () => agent(skepticPrompt('code', f, lens), opts('code', 'medium')),
      ])
      const confirmations = [rep, spec, code].filter(v => v && !v.refuted).length
      const survives = confirmations >= 2
      return {
        id: f.id, lens, severity: f.severity, title: f.title, survives, confirmations,
        spec_question: survives && !!(spec && spec.fix_needs_spec_change),
        files: Array.from(new Set([...(f.files || []), ...((code && code.files_to_change) || [])])),
        root_cause: code ? code.root_cause : '', open_question: spec ? spec.open_question : '',
        votes: Object.fromEntries(Object.entries({ reproduce: rep, spec, code }).map(([kk, v]) => [kk, v ? { refuted: v.refuted, confidence: v.confidence, reason: v.reason, evidence: v.evidence } : null])),
      }
    }))).filter(Boolean)
  } finally { reserved -= est }
  log(`verify:${lens}: ${verdicts.filter(v => v.survives).length} of ${verdicts.length} survive`)
  scribe(`verify-${lens}.json`, { lens, verdicts, pending }, `M2 phase 3 C: ${lens} verdicts (${verdicts.filter(v => v.survives).length} of ${verdicts.length} survive)`)
  return { lens, verdicts, pending }
}

let reviews = []
if (lenses.length) {
  phase('Review')
  log(`review: ${lenses.map(l => l.lens).join(', ')} at ${BASE}`)
  // Barrier: the partition needs every lens's verdicts.
  reviews = (await parallel(lenses.map(l => () => reviewAndVerify(l)))).filter(Boolean)
}

// ---------- partition ----------
phase('Partition')
let partition = null
await Promise.allSettled(scribeJobs)
const reviewed = reviews.filter(r => r.verdicts.length).map(r => r.lens)
const partitionLenses = [...(A.partition_lenses || (ROUND === 2 ? ['hit', 'perf'] : [])), ...reviewed]
if (!partitionLenses.length) log('partition: no lens with verdicts -> SKIPPED')
const pr = partitionLenses.length ? await launch('partition', 'Partition', COST.partition, () => agent(
  `${COMMON}\n\nYOUR JOB: PARTITION round ${ROUND}'s open surviving findings into fix packages for parallel fixers (read-only; read the code in ${worktreeOf(partitionLenses[partitionLenses.length - 1])}; write nothing). Read ${partitionLenses.map(l => `${REVIEWS}/review-${l}.json and verify-${l}.json`).join(', ')}, and every ${REVIEWS}/fix-*.json. Partition every finding whose verdict has survives true and spec_question false and that no fix-*.json already fixed. Read each finding's detail, suggested_fix and root_cause, and the code as needed, to confirm which files each fix touches.${A.partition_note ? `\nTHE LEAD'S PARTITION NOTE: ${A.partition_note}` : ''}
Rules:
- packages own DISJOINT files, except these shared files several fixers may append to in their own place: game/autoload/tuning_data.gd (each in its own group or subgroup), tuning/default.json (the lead regenerates it after merging), docs/ARCHITECTURE.md (each in its own section). Tests count as files;
- a hub file several findings need goes to ONE package, or the notes say exactly which functions each package may touch in it;
- at most 4 packages, balanced in work (a fixer costs about a quarter of a usage window), ordered by priority (high severity first); merge duplicates and shared root causes into one package and say so in notes;
- key: a short slug [a-z0-9-] that STARTS WITH "${RS}-" (earlier rounds' branches use other keys);
- notes: the order of work, shared root causes, and any risk of touching approved behaviour or a question open with Game-boy;
- findings that can't be fixed without a spec change, or need Game-boy's call, go to unassigned with the reason.`,
  { label: 'partition', phase: 'Partition', schema: PARTITION_SCHEMA, model: REVIEWER_MODEL })) : { skipped: true }
if (pr.result) {
  partition = pr.result
  log(`partition: ${partition.packages.length} packages: ${partition.packages.map(p => `${p.key} (${p.finding_ids.join(', ')})`).join('; ')}`)
  await scribe(`packages-${RS}.json`, partition, `M2 phase 3 C: round ${ROUND} fix packages (${partition.packages.length})`)
}

// ---------- fix ----------
let fix = null
if (partition && partition.packages.length && !A.no_fix) {
  phase('Fix')
  await Promise.allSettled(scribeJobs)
  fix = await workflow({ scriptPath: `${ROOT}/docs/reviews/M2-phase3/workflow-fix.js` },
    { packages_file: `packages-${RS}.json`, note: A.fix_note || '', concurrency: A.concurrency || 2, fixer_model: A.fixer_model || 'sonnet', ...(A.fixer_cost ? { fixer_cost: A.fixer_cost } : {}) })
}

await Promise.allSettled(scribeJobs)
return {
  critic: critic && { gaps: critic.gaps, gap_review_brief: critic.gap_review_brief, report_notes: critic.report_notes },
  reviews: reviews.map(r => ({
    lens: r.lens, skipped: !!r.skipped, pending: r.pending,
    verdicts: r.verdicts.map(v => ({ id: v.id, severity: v.severity, title: v.title, survives: v.survives, confirmations: v.confirmations, spec_question: v.spec_question, open_question: v.open_question })),
  })),
  partition,
  fix,
  usage: usageLog,
}
