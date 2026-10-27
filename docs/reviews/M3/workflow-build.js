export const meta = {
  name: 'm3-build',
  description: 'M3 builders: one Sonnet builder per package of docs/milestones/M3-plan.md, each in its own worktree, usage-gated, resumable from branch state',
  phases: [
    { title: 'Load', detail: 'Haiku reads which package branches are done, wip or new' },
    { title: 'Build', detail: 'one builder per package, gated, at most `concurrency` at once' },
  ],
}

// Run inline as a Workflow (scriptPath: this file) with args saved in docs/reviews/M3/args-<phase>.json:
//   packages: [{ key, section, est, model?, base?, note? }]
//     key      the package key, e.g. "S0-scaffold" or "P1-ai"; branch m3/<key lower-case>,
//              worktree .worktrees/m3-<key lower-case>
//     section  where its brief is in docs/milestones/M3-plan.md, e.g.
//              'Part C §4 "S0-scaffold", as amended by Part A §A1-§A2'
//     est      the gate's estimate in % of a 5-hour window
//     model    default "sonnet" (Game-boy, 2026-10-25: Opus plans and reviews, Sonnet codes)
//     base     the branch to cut from (default args.base, then "m3/enemy-ai")
//     note     a lead's note for this package only
//   base: "m3/enemy-ai"     default base branch
//   concurrency: 4          builders at once (8 GB of RAM: never more than 4 Godot-bound agents)
//   note: "<text>"          a lead's note added to every brief (merge state, known failures)
//   only: ["<key>", ...]    run just these packages, in this order
// A package is done when its branch has a commit whose subject starts "M3 <key>:" (any case of
// the key); wip when the branch exists without one (the builder reuses it and goes on from its
// newest wip: commit); new otherwise. Rerunning the same args after a cut-off resumes.

const ROOT = '/Users/arachne/repos/beat-em-up-PoC'
const LIMIT = 90
const A = args || {}
const BASE = A.base || 'm3/enemy-ai'
const TRAILER = 'Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>'
const slug = k => k.toLowerCase()

const GATE_SCHEMA = {
  type: 'object',
  properties: { five_hour: { type: 'number' }, weekly: { type: 'number' }, five_hour_resets_at: { type: 'string' } },
  required: ['five_hour', 'weekly', 'five_hour_resets_at'],
}
const LOAD_SCHEMA = {
  type: 'object',
  properties: {
    states: {
      type: 'array',
      items: {
        type: 'object',
        properties: { key: { type: 'string' }, state: { type: 'string', enum: ['done', 'wip', 'new'] }, head: { type: 'string' } },
        required: ['key', 'state', 'head'],
      },
    },
  },
  required: ['states'],
}
const BUILD_SCHEMA = {
  type: 'object',
  properties: {
    package: { type: 'string' },
    branch: { type: 'string' },
    commit: { type: 'string', description: 'sha of the final "M3 <key>: ..." commit' },
    pushed: { type: 'boolean' },
    tests_passed: { type: 'number' },
    tests_total: { type: 'number' },
    script_errors: { type: 'boolean', description: 'true if the full run printed SCRIPT ERROR or ERROR' },
    summary: { type: 'string', description: 'what you built, in a short paragraph' },
    interfaces: { type: 'array', items: { type: 'string' }, description: 'public APIs provided or changed, with signatures' },
    tunables_added: { type: 'array', items: { type: 'string' } },
    captures: { type: 'array', items: { type: 'object', properties: { path: { type: 'string' }, description: { type: 'string' } }, required: ['path', 'description'] } },
    feel_judgement: { type: 'string', description: 'what the first-person sheets show, honestly' },
    requests: { type: 'array', items: { type: 'string' }, description: 'changes needed in files you do not own' },
    departures: { type: 'array', items: { type: 'string' }, description: 'anything that would depart from SPEC, not implemented' },
    open_risks: { type: 'array', items: { type: 'string' } },
  },
  required: ['package', 'branch', 'commit', 'pushed', 'tests_passed', 'tests_total', 'script_errors', 'summary', 'interfaces', 'tunables_added', 'captures', 'feel_judgement', 'requests', 'departures', 'open_risks'],
}

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
const slot = semaphore(A.concurrency || 4)

let reserved = 0
const usageLog = []
async function gate(label) {
  const g = await agent(
    `Usage gate (${label}). Load mcp__ccd_session_mgmt__get_usage with ToolSearch ("select:mcp__ccd_session_mgmt__get_usage") and call it with no arguments. From plan.windows report the percentUsed of the "5-hour limit" window as five_hour, of the window labelled "Weekly · all models" (or the first whose label starts with "Weekly") as weekly, and the 5-hour window's resetsAt as five_hour_resets_at. Do nothing else.`,
    { label: `gate:${label}`, phase: 'Build', schema: GATE_SCHEMA, model: 'haiku', effort: 'low' })
  if (!g) { log(`gate ${label}: no answer`); return null }
  const used = Math.max(g.five_hour, g.weekly)
  const headroom = LIMIT - used - reserved
  usageLog.push({ label, five_hour: g.five_hour, weekly: g.weekly, reserved, headroom })
  return { ...g, used, headroom }
}
async function launch(label, est, fn) {
  const g = await gate(label)
  if (!g || est > g.headroom) {
    log(`${label}: needs ~${est}%, headroom ${g ? g.headroom : '?'}% -> SKIPPED (rerun the same args after the reset)`)
    return { skipped: true }
  }
  reserved += est
  log(`${label}: 5-hour ${g.five_hour}%, weekly ${g.weekly}%, headroom ${g.headroom}% -> launch (~${est}%)`)
  try { return { result: await fn() } } finally { reserved -= est }
}

const COMMON = `You are a BUILDER on Milestone 3 (enemy AI and the rear-attack warning) of a Godot 4.7.2 first-person beat-em-up proof of concept at ${ROOT} (GDScript with static typing, Forward+, Jolt, 60 Hz). Game-boy, the owner, plays and signs off each milestone; he is not available: never ask him anything, take the default that changes least, and log the call.
READ FIRST, in full: docs/milestones/M3-plan.md Part A (binding amendments; they override Part C), then Part C §1 (rules every package follows), §2 (pinned contracts) and §3 (hot spots: who owns what, when), then YOUR package's section (below) and Part B where your package touches the warning or readability. Then the codemaps in docs/milestones/M3-codemap/ that your files touch, and docs/ARCHITECTURE.md's sections for them. CLAUDE.md's rules apply (static types, tabs, ## docs, no numbers in scripts, layer rules).
WORK RULES (Part C §1 as amended):
- Work ONLY in your worktree; run EVERY command as \`cd <your worktree> && ...\`; edit only files under it. Never touch the main checkout or another worktree. Never merge into ${BASE} or main.
- Own only your package's files. A change you need elsewhere goes in "requests"; don't make it.
- Tunables: S0 declared them; append only inside your own @export_subgroup if you need more. After any TuningData change: \`godot --headless --import --quit && godot --headless -s tools/gen_default_preset.gd\`.
- Moves: edit tools/gen_moves.gd (your own function only), then \`godot --headless --import --quit && godot --headless -s tools/gen_moves.gd && godot --headless --import --quit\`; check for the line "gen_moves: wrote N moves" (a parse error still exits 0) and that git status shows only your own .tres changing.
- Tests: tools/run_tests.sh -gselect=<file> while developing; the FULL tools/run_tests.sh (about 90 s) before your final commit. Read the whole output for "SCRIPT ERROR" and "ERROR". All must pass. Keep new tests short and seeded. Wait 5 physics frames after a room's _ready() before anything that paths.
- Look at visual work: record with tools/capture_bot.sh (once S0 has added it; before that, \`godot --path <worktree> --write-movie <worktree>/captures/<key>/bot.avi --fixed-fps 60 --resolution 1280x720 <bot scene> -- --act=<filter> > <worktree>/captures/<key>/bot.log 2>&1\`), tile stills with ffmpeg (\`ffmpeg -loglevel error -y -ss <t> -t <d> -i <avi> -vf "fps=12,scale=480:-1,tile=5x4" -frames:v 1 <sheet>.png\`), and LOOK at the sheets with the Read tool. Judge first person only (side view and F3 are for mechanics). Never commit captures/.
- The machine has 8 CPUs and 8 GB of RAM and up to three other builders run at once: one Godot process at a time, never leave one running, and no more than one Movie Maker window at a time (capture_bot.sh takes a lock).
- Commits: "wip: <key> ..." every 15-20 minutes, pushed, so a usage halt loses little. The final commit's subject is "M3 <key>: <summary>", pushed. Every commit message ends with the line "${TRAILER}".
- Judgement calls: write each call you make (decision; at least one alternative not taken; why) to docs/milestones/M3-calls/<key>.md (your own file).
- Spec departures: don't implement one; report it in "departures".`

phase('Load')
const pk = (A.packages || []).filter(p => !A.only || A.only.includes(p.key))
if (!pk.length) return { error: 'no packages in args' }
const loaded = await agent(
  `Loader. Do exactly this and nothing else. \`cd ${ROOT} && git fetch -q origin\`. For each package key K in [${pk.map(p => JSON.stringify(p.key)).join(', ')}], let B be "m3/" + K in lower case. Run \`git log --format='%h %s' origin/B 2>/dev/null | head -80\` (and, if that prints nothing, the same for the local branch B). state is "done" if a subject starts with "M3 " + K + ":" (compare case-insensitively), "wip" if the branch exists without one, "new" if it doesn't exist. head is the newest commit's sha (or ""). Return every key, in the given order.`,
  { label: 'load:states', phase: 'Load', schema: LOAD_SCHEMA, model: 'haiku', effort: 'low' })
const stateOf = k => (loaded && loaded.states.find(s => s.key === k)) || { state: 'new', head: '' }
const todo = pk.filter(p => stateOf(p.key).state !== 'done')
log(`load: ${pk.map(p => `${p.key}=${stateOf(p.key).state}`).join(', ')}`)

phase('Build')
function builderPrompt(p) {
  const s = slug(p.key)
  const wt = `${ROOT}/.worktrees/m3-${s}`
  const branch = `m3/${s}`
  const base = p.base || BASE
  const st = stateOf(p.key)
  return `${COMMON}

YOUR PACKAGE: ${p.key}. Its brief: docs/milestones/M3-plan.md, ${p.section}.${A.note ? `\nLEAD'S NOTE (all packages): ${A.note}` : ''}${p.note ? `\nLEAD'S NOTE (${p.key}): ${p.note}` : ''}
SETUP (state: ${st.state}${st.head ? `, head ${st.head}` : ''}):
- new: \`cd ${ROOT} && git fetch -q origin && git worktree add .worktrees/m3-${s} -b ${branch} origin/${base}\` (if git reports a lock, wait 10 s and retry).
- wip: reuse it. If .worktrees/m3-${s} is missing, \`cd ${ROOT} && git fetch -q origin && git worktree add .worktrees/m3-${s} ${branch}\` (or \`-b ${branch} origin/${branch}\` if only the remote branch exists), then read \`git log --oneline origin/${base}..HEAD\` and the diff, and continue from the newest wip: commit.
Then \`cd ${wt} && godot --headless --import --quit && git push -u origin ${branch}\`. Your worktree is ${wt}.
Finish with the final commit and push, then return the structured result: the final commit's sha, test counts from the full run, the sheets you looked at and what they show, interfaces, tunables, requests, departures and open risks.`
}

const results = await parallel(todo.map(p => () => slot(() => launch(`build:${p.key}`, p.est || 8,
  () => agent(builderPrompt(p), { label: `build:${p.key}`, phase: 'Build', schema: BUILD_SCHEMA, model: p.model || 'sonnet' })))
  .then(r => ({ key: p.key, ...r }))))

return {
  states_before: pk.map(p => ({ key: p.key, ...stateOf(p.key) })),
  builds: results.filter(Boolean).map(r => r.skipped ? { key: r.key, skipped: true } : r.result ? { key: r.key, ...r.result } : { key: r.key, died: true }),
  usage: usageLog,
}
