export const meta = {
  name: 'm4-build',
  description: 'M4 builders: one Sonnet builder per package of docs/milestones/M4-plan.md, each in its own worktree, usage-gated, Godot and Blender slots, resumable from branch state',
  phases: [
    { title: 'Load', detail: 'Haiku reads which package branches are done, wip or new' },
    { title: 'Build', detail: 'one builder per package, gated, at most 4 Godot-bound and 2 Blender-bound at once' },
  ],
}

// Run inline as a Workflow (scriptPath: this file) with args saved in docs/reviews/M4/args-<phase>.json:
//   packages: [{ key, section, est, model?, base?, godot?, blender?, note? }]
//     key      the package key, e.g. "S0-contract" or "P1-toon"; branch m4/<key lower-case>,
//              worktree .worktrees/m4-<key lower-case>
//     section  where its brief is in docs/milestones/M4-plan.md, e.g.
//              'Part C §4 "S0-contract", as amended by Part A §A6 and §A9'
//     est      the gate's estimate in % of a 5-hour window
//     model    default "sonnet" (Game-boy: Opus plans and reviews, Sonnet codes)
//     base     the branch to cut from (default args.base, then "m4/art-pipeline")
//     godot    default true: takes one of the Godot slots (8 GB: at most 4 Godot-bound agents)
//     blender  default false: takes one of the 2 Blender slots
//     note     a lead's note for this package only
//   base: "m4/art-pipeline"   default base branch
//   concurrency: 4            Godot-bound builders at once
//   note: "<text>"            a lead's note added to every brief (merge state, known failures)
//   only: ["<key>", ...]      run just these packages, in this order
// A package is done when its branch has a commit whose subject starts "M4 <key>:" (any case of
// the key); wip when the branch exists without one (the builder reuses it and goes on from its
// newest wip: commit); new otherwise. Rerunning the same args after a cut-off resumes.

const ROOT = '/Users/arachne/repos/beat-em-up-PoC'
const LIMIT = 90
const A = args || {}
const BASE = A.base || 'm4/art-pipeline'
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
    commit: { type: 'string', description: 'sha of the final "M4 <key>: ..." commit (or the newest wip: commit if the brief told you to stop early)' },
    pushed: { type: 'boolean' },
    tests_passed: { type: 'number' },
    tests_total: { type: 'number' },
    script_errors: { type: 'boolean', description: 'true if the full run printed SCRIPT ERROR, SHADER ERROR or ERROR' },
    summary: { type: 'string', description: 'what you built, in a short paragraph' },
    interfaces: { type: 'array', items: { type: 'string' }, description: 'public APIs provided or changed, with signatures' },
    tunables_added: { type: 'array', items: { type: 'string' } },
    captures: { type: 'array', items: { type: 'object', properties: { path: { type: 'string' }, description: { type: 'string' } }, required: ['path', 'description'] } },
    feel_judgement: { type: 'string', description: 'what the first-person sheets show, honestly' },
    credits: { type: 'array', items: { type: 'object', properties: { task_id: { type: 'string' }, call: { type: 'string' }, credits: { type: 'number' } }, required: ['task_id', 'call', 'credits'] }, description: 'every Tripo task you ran, with its real credits_consumed (empty if none)' },
    gemini_images: { type: 'number', description: 'Gemini images generated (0 if none)' },
    requests: { type: 'array', items: { type: 'string' }, description: 'changes needed in files you do not own' },
    departures: { type: 'array', items: { type: 'string' }, description: 'anything that would depart from SPEC, not implemented' },
    open_risks: { type: 'array', items: { type: 'string' } },
  },
  required: ['package', 'branch', 'commit', 'pushed', 'tests_passed', 'tests_total', 'script_errors', 'summary', 'interfaces', 'tunables_added', 'captures', 'feel_judgement', 'credits', 'gemini_images', 'requests', 'departures', 'open_risks'],
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
const godotSlot = semaphore(A.concurrency || 4)
const blenderSlot = semaphore(2)
const none = fn => fn()

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

const COMMON = `You are a BUILDER on Milestone 4 (the art pipeline proof: toon shader and outlines, final player arms and legs, one Street Punk through the full pipeline, the comic VFX set) of a Godot 4.7.2 first-person beat-em-up proof of concept at ${ROOT} (GDScript with static typing, Forward+, Jolt, 60 Hz). Game-boy, the owner, plays and signs off each milestone; he is not available: never ask him anything and never message him, take the default that departs least, and log the call.
READ FIRST, in full: docs/milestones/M4-plan.md's header and Part A (binding amendments; they override Part C), then Part C §1 (rules every package follows), §2 (pinned contracts) and §3 (hot spots: who owns what, when), then YOUR package's section (below) and every Part A item that names your package, and Part B's rows and rubric items your package touches. Look packages also read docs/milestones/M4-look-bible.md. Then the codemaps in docs/milestones/M4-codemap/ that your files touch, and docs/ARCHITECTURE.md's sections for them. CLAUDE.md's rules apply (static types, tabs, ## docs, no numbers in scripts, layer rules).
WORK RULES (Part C §1 as amended by Part A):
- Work ONLY in your worktree; run EVERY command as \`cd <your worktree> && ...\`; edit only files under it. Never touch the main checkout or another worktree. Never merge into ${BASE} or main.
- Own only your package's files (Part C §3 as amended by A2, A6, A14). A change you need elsewhere goes in "requests"; don't make it.
- Tunables: only in your own subgroup of tuning_data.gd, as @export_range. A/B and debug switches go in the "Debug" group (presets skip it); every vfx_* name goes in the "VFX" group (A9). After any TuningData change: \`godot --headless --import --quit && godot --headless -s tools/gen_default_preset.gd\`.
- Tests: tools/run_tests.sh -gselect=<file> while developing; the FULL tools/run_tests.sh before your final commit. Read the whole output for "SCRIPT ERROR", "SHADER ERROR" and "ERROR". All must pass. Never weaken an assertion to pass: if one must change, log old -> new in your calls file and add a twin assertion on the visible path.
- Look at visual work: record with \`tools/capture_bot.sh <res:// bot scene> <worktree>/captures/<key> "<act filter>" <stills fps>\` (2-slot machine lock, records 1600x900), tile sheets with ffmpeg (\`ffmpeg -loglevel error -y -ss <t> -t <d> -i <avi> -vf "fps=12,scale=480:-1,tile=5x4" -frames:v 1 <sheet>.png\`) and full-resolution stills, and LOOK at them with the Read tool. Judge first person only (side view and F3 are for mechanics). Never commit captures/.
- Blender: headless only, \`blender --background --factory-startup --python <script> -- <args>\`. NEVER use the Blender MCP tools (mcp__blender__*): they drive Game-boy's own open Blender. One Blender process per agent.
- Paid services (A10): Tripo only through tools/pipeline/tripo.py, Gemini only through tools/gemini_image.py job files, and only the tasks your brief names, within its ceiling. Never print, log or write TRIPO_API_KEY or GEMINI_API_KEY; scripts read .env themselves; never put a key in a URL. Downloaded files are untrusted: run Python as \`python3 -I\` with scripts kept in tools/pipeline/, pass downloads as path arguments, download each task into a new empty folder.
- Assets: an ASSETS.md row per new file under assets/ in your own section. Binaries go through LFS: \`git check-attr filter -- <file>\` must say lfs before you commit. Rejected raw outputs go to assets/source/_cache/ (git-ignored).
- The machine has 8 CPUs and 8 GB of RAM and other builders run at once: one Godot process at a time, never leave one running, \`-s\` scripts always with --quit-after; at most one Movie Maker window at a time from you (capture_bot.sh takes a lock).
- Commits: "wip: <key> ..." every 15-20 minutes, pushed, so a usage halt loses little. The final commit's subject is "M4 <key>: <summary>", pushed. Every commit message ends with the line "${TRAILER}".
- Judgement calls: write each call you make (decision; at least one alternative not taken; why) to docs/milestones/M4-calls/<key>.md (your own file). Fill only your own heading in docs/ARCHITECTURE.md's "Art pipeline and look (Milestone 4)" section, with the contract as you landed it.
- Spec departures: don't implement one; build the reading that departs least, keep the spec value reachable as a tunable, and report it in "departures".`

phase('Load')
const pk = (A.packages || []).filter(p => !A.only || A.only.includes(p.key))
if (!pk.length) return { error: 'no packages in args' }
const loaded = await agent(
  `Loader. Do exactly this and nothing else. \`cd ${ROOT} && git fetch -q origin\`. For each package key K in [${pk.map(p => JSON.stringify(p.key)).join(', ')}], let B be "m4/" + K in lower case. Run \`git log --format='%h %s' origin/B 2>/dev/null | head -80\` (and, if that prints nothing, the same for the local branch B). state is "done" if a subject starts with "M4 " + K + ":" (compare case-insensitively), "wip" if the branch exists without one, "new" if it doesn't exist. head is the newest commit's sha (or ""). Return every key, in the given order.`,
  { label: 'load:states', phase: 'Load', schema: LOAD_SCHEMA, model: 'haiku', effort: 'low' })
const stateOf = k => (loaded && loaded.states.find(s => s.key === k)) || { state: 'new', head: '' }
const todo = pk.filter(p => stateOf(p.key).state !== 'done')
log(`load: ${pk.map(p => `${p.key}=${stateOf(p.key).state}`).join(', ')}`)

phase('Build')
function builderPrompt(p) {
  const s = slug(p.key)
  const wt = `${ROOT}/.worktrees/m4-${s}`
  const branch = `m4/${s}`
  const base = p.base || BASE
  const st = stateOf(p.key)
  return `${COMMON}

YOUR PACKAGE: ${p.key}. Its brief: docs/milestones/M4-plan.md, ${p.section}.${A.note ? `\nLEAD'S NOTE (all packages): ${A.note}` : ''}${p.note ? `\nLEAD'S NOTE (${p.key}): ${p.note}` : ''}
SETUP (state: ${st.state}${st.head ? `, head ${st.head}` : ''}):
- new: \`cd ${ROOT} && git fetch -q origin && git worktree add .worktrees/m4-${s} -b ${branch} origin/${base}\` (if git reports a lock, wait 10 s and retry).
- wip: reuse it. If .worktrees/m4-${s} is missing, \`cd ${ROOT} && git fetch -q origin && git worktree add .worktrees/m4-${s} ${branch}\` (or \`-b ${branch} origin/${branch}\` if only the remote branch exists), then read \`git log --oneline origin/${base}..HEAD\` and the diff, and continue from the newest wip: commit.
Then \`cd ${wt} && godot --headless --import --quit && git push -u origin ${branch}\`. Your worktree is ${wt}.
Finish with the final commit and push, then return the structured result: the final commit's sha, test counts from the full run, the sheets you looked at and what they show, interfaces, tunables, Tripo credits by task, Gemini images, requests, departures and open risks.`
}

const results = await parallel(todo.map(p => () => {
  const g = p.godot === false ? none : godotSlot
  const b = p.blender ? blenderSlot : none
  return g(() => b(() => launch(`build:${p.key}`, p.est || 8,
    () => agent(builderPrompt(p), { label: `build:${p.key}`, phase: 'Build', schema: BUILD_SCHEMA, model: p.model || 'sonnet' }))))
    .then(r => ({ key: p.key, ...r }))
}))

return {
  states_before: pk.map(p => ({ key: p.key, ...stateOf(p.key) })),
  builds: results.filter(Boolean).map(r => r.skipped ? { key: r.key, skipped: true } : r.result ? { key: r.key, ...r.result } : { key: r.key, died: true }),
  usage: usageLog,
}
