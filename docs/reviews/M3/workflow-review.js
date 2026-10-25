export const meta = {
  name: 'm3-review',
  description: 'M3 review round: Opus reviewers per lens in detached worktrees, three Sonnet skeptics per finding, partition into disjoint packages, Sonnet fixers; every launch usage-gated',
  phases: [
    { title: 'Review', detail: 'one Opus reviewer per lens, each in its own detached worktree' },
    { title: 'Verify', detail: 'three Sonnet skeptics per finding: reproduce, spec, code' },
    { title: 'Partition', detail: 'survivors into fix packages with disjoint files' },
    { title: 'Fix', detail: 'one Sonnet fixer per package in its own worktree' },
  ],
}

// Run inline as a Workflow (scriptPath: this file) with args saved in docs/reviews/M3/args-review-<round>.json:
//   round: "slice"            names worktrees (.worktrees/m3-review-<round>-<lens>), fix branches
//                             (m3/fix-<round>-<package>) and finding ids (<round>-<lens>-NN)
//   base: "<sha>"             the commit every reviewer worktree is detached at (the merged head)
//   base_branch: "m3/enemy-ai" the branch fixers cut from
//   lenses: [{ key, brief, est? }]   key [a-z0-9]; brief: what to judge and how (the lead writes it)
//   common_note: "<text>"     added to every reviewer, skeptic and fixer prompt (state, known items)
//   reviews: { <lens>: <FINDINGS object> }   skip these reviewers (from an earlier, cut-off run)
//   verdicts: { <finding id>: { survives, votes } }   skip these skeptics
//   packages: <PARTITION object>   skip the partition
//   no_fix: true              stop after the partition
//   fix_concurrency: 3, review_concurrency: 3
//   costs: { reviewer, skeptic, partition, fixer }   gate estimates in % of a 5-hour window

const ROOT = '/Users/arachne/repos/beat-em-up-PoC'
const LIMIT = 90
const A = args || {}
const ROUND = A.round || 'r1'
const BASE = A.base
const BASE_BRANCH = A.base_branch || 'm3/enemy-ai'
const COST = Object.assign({ reviewer: 4, skeptic: 1, partition: 1, fixer: 5 }, A.costs || {})
const TRAILER = 'Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>'
if (!BASE) return { error: 'args.base (the commit to review) is required' }

const GATE_SCHEMA = {
  type: 'object',
  properties: { five_hour: { type: 'number' }, weekly: { type: 'number' } },
  required: ['five_hour', 'weekly'],
}
const FINDINGS_SCHEMA = {
  type: 'object',
  properties: {
    summary: { type: 'string' },
    checked: { type: 'array', items: { type: 'string' }, description: 'every act (title, view) you recorded and judged, every metric or log you read, every code area and edge case you checked' },
    sheets: { type: 'array', items: { type: 'string' }, description: 'absolute paths of the most telling sheets' },
    passes: { type: 'array', items: { type: 'string' }, description: 'gate or rubric items that passed, each with its evidence' },
    also_noticed: { type: 'array', items: { type: 'string' } },
    findings: {
      type: 'array',
      items: {
        type: 'object',
        properties: {
          severity: { type: 'string', enum: ['high', 'medium', 'low'] },
          title: { type: 'string' },
          detail: { type: 'string' },
          evidence: { type: 'string', description: 'file:line, metric or log line, test output, or capture path with time or frame' },
          repro: { type: 'string' },
          suggested_fix: { type: 'string' },
          files: { type: 'array', items: { type: 'string' } },
          spec_change: { type: 'boolean' },
        },
        required: ['severity', 'title', 'detail', 'evidence', 'repro', 'suggested_fix', 'files', 'spec_change'],
      },
    },
  },
  required: ['summary', 'checked', 'sheets', 'passes', 'also_noticed', 'findings'],
}
const VOTE_SCHEMA = {
  type: 'object',
  properties: {
    refuted: { type: 'boolean' },
    confidence: { type: 'string', enum: ['high', 'medium', 'low'] },
    reason: { type: 'string' },
    evidence: { type: 'string' },
    root_cause: { type: 'string' },
    files_to_change: { type: 'array', items: { type: 'string' } },
    fix_needs_spec_change: { type: 'boolean' },
  },
  required: ['refuted', 'confidence', 'reason', 'evidence', 'root_cause', 'files_to_change', 'fix_needs_spec_change'],
}
const PARTITION_SCHEMA = {
  type: 'object',
  properties: {
    packages: {
      type: 'array',
      items: {
        type: 'object',
        properties: {
          key: { type: 'string', description: 'slug [a-z0-9-]' },
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
const FIX_SCHEMA = {
  type: 'object',
  properties: {
    package: { type: 'string' },
    branch: { type: 'string' },
    commit: { type: 'string' },
    pushed: { type: 'boolean' },
    verdicts: { type: 'array', items: { type: 'object', properties: { id: { type: 'string' }, outcome: { type: 'string', enum: ['fixed', 'partial', 'not_fixed', 'refuted_on_fix', 'spec_question'] }, what_changed: { type: 'string' }, tests: { type: 'string' } }, required: ['id', 'outcome', 'what_changed', 'tests'] } },
    tests_passed: { type: 'number' },
    tests_total: { type: 'number' },
    script_errors: { type: 'boolean' },
    tunables_added: { type: 'array', items: { type: 'string' } },
    captures: { type: 'array', items: { type: 'object', properties: { path: { type: 'string' }, description: { type: 'string' } }, required: ['path', 'description'] } },
    feel_judgement: { type: 'string' },
    judgement_calls: { type: 'array', items: { type: 'string' } },
    remaining: { type: 'array', items: { type: 'string' } },
  },
  required: ['package', 'branch', 'commit', 'pushed', 'verdicts', 'tests_passed', 'tests_total', 'script_errors', 'tunables_added', 'captures', 'feel_judgement', 'judgement_calls', 'remaining'],
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
const reviewSlot = semaphore(A.review_concurrency || 3)
const skepticSlot = semaphore(6)
const fixSlot = semaphore(A.fix_concurrency || 3)

let reserved = 0
const usageLog = []
async function launch(label, phaseTitle, est, fn) {
  const g = await agent(
    `Usage gate (${label}). Load mcp__ccd_session_mgmt__get_usage with ToolSearch ("select:mcp__ccd_session_mgmt__get_usage") and call it with no arguments. From plan.windows report the percentUsed of the "5-hour limit" window as five_hour and of the window labelled "Weekly · all models" (or the first whose label starts with "Weekly") as weekly. Do nothing else.`,
    { label: `gate:${label}`, phase: phaseTitle, schema: GATE_SCHEMA, model: 'haiku', effort: 'low' })
  const headroom = g ? LIMIT - Math.max(g.five_hour, g.weekly) - reserved : -1
  if (g) usageLog.push({ label, five_hour: g.five_hour, weekly: g.weekly, reserved, headroom })
  if (!g || est > headroom) {
    log(`${label}: needs ~${est}%, headroom ${headroom}% -> SKIPPED (rerun with the saved results after the reset)`)
    return { skipped: true }
  }
  reserved += est
  try { return { result: await fn() } } finally { reserved -= est }
}

const COMMON = `Milestone 3 (enemy AI and the rear-attack warning) of a Godot 4.7.2 first-person beat-em-up proof of concept at ${ROOT} (GDScript, static typing, Forward+, Jolt, 60 Hz). Game-boy, the owner, plays and signs off milestones; he isn't available, and fine grey-block look or feel questions take their defaults (he can't judge them before the art). Only first-person looks count; side view and free fly are debug views (use them for mechanics).
Read: docs/milestones/M3-plan.md (Part A binds, Part B is the checkable done-when: the warning's truth table B1, metrics R1-R15 B2, the evidence pack B3, the lenses and the L2 rubric B4; Part C is the base plan), docs/SPEC.md §5, §7, §8, §11, §12, docs/ARCHITECTURE.md's "Enemy AI and the rear warning (Milestone 3)" section, docs/milestones/M3-judgement-calls.md and docs/milestones/M3-calls/*.md (calls already made by default: don't re-litigate them unless they break the spec or the done-when), and README's departures.
Tools: tools/run_tests.sh (full suite, about 90 s; -gselect=<file> for one) — read the whole output for SCRIPT ERROR and ERROR. tools/capture_bot.sh <bot scene> <out dir> "<act filter>" [stills fps] records a bot with Movie Maker (a lock allows two at once). Tile sheets: ffmpeg -loglevel error -y -ss <t> -t <d> -i <avi> -vf "fps=12,scale=480:-1,tile=5x4" -frames:v 1 <sheet>.png; corner crops with crop=iw*0.3:ih*0.3:0:0 (top left) and crop=iw*0.3:ih*0.3:iw*0.7:0 (top right). LOOK at sheets with the Read tool. Bots: tests/bot/*.tscn; the crowd bot's acts are in tests/bot/acts/*_acts.gd. The machine has 8 GB of RAM and other agents run at once: one Godot process at a time; never leave one running.
${A.common_note || ''}`

// ---------- review ----------
phase('Review')
const lenses = A.lenses || []
function reviewerPrompt(l) {
  const wt = `${ROOT}/.worktrees/m3-review-${ROUND}-${l.key}`
  return `${COMMON}

YOU ARE AN ADVERSARIAL REVIEWER, lens "${l.key}". ${l.brief}
SETUP: \`cd ${ROOT} && git fetch -q origin && (git worktree add --detach .worktrees/m3-review-${ROUND}-${l.key} ${BASE} || git -C .worktrees/m3-review-${ROUND}-${l.key} checkout -q --detach ${BASE})\` (if git reports a lock, wait 10 s and retry), then \`cd ${wt} && godot --headless --import --quit\`. Work only there (run EVERY command as \`cd ${wt} && ...\`), and put your recordings in ${wt}/captures/review/. You may write probe scripts or temporary tests there, but never commit or push anything.
Find real defects against the spec, the plan's Part A/B and the done-when: things Game-boy would see or feel in first person, mechanics that break, rule violations in the code. Each finding needs concrete evidence (a frame in a sheet, a log line, a metric, a test you ran, file:line) and a repro. Rank them; at most 12; don't pad. Also list what you checked and what passed, with evidence, so the gate can cite it.`
}
const reviewKeys = lenses.map(l => l.key)
const reviewed = await pipeline(lenses,
  l => A.reviews && A.reviews[l.key] ? A.reviews[l.key] : reviewSlot(() => launch(`review:${l.key}`, 'Review', l.est || COST.reviewer,
    () => agent(reviewerPrompt(l), { label: `review:${l.key}`, phase: 'Review', schema: FINDINGS_SCHEMA })))
    .then(r => r.skipped ? null : r.result),
  (rev, l) => {
    if (!rev) return { lens: l.key, review: null, verified: [] }
    const findings = rev.findings.map((f, i) => ({ id: `${ROUND}-${l.key}-${String(i + 1).padStart(2, '0')}`, lens: l.key, ...f }))
    const SKEPTIC_ANGLES = [
      'REPRODUCE it: run the repro (record, probe or test) at the reviewed commit and see whether it really happens.',
      'Check it against the SPEC and the plan: is it really a defect, or an approved departure, a logged default call, or out of M3 scope?',
      'Read the CODE path: is the claimed cause real, and is the suggested fix right? Name the root cause and the files a fix must touch.',
    ]
    return parallel(findings.map(f => () => {
      if (A.verdicts && A.verdicts[f.id]) return Promise.resolve({ ...f, ...A.verdicts[f.id] })
      return parallel(SKEPTIC_ANGLES.map((angle, k) => () => skepticSlot(() => launch(`skeptic:${f.id}:${k}`, 'Verify', COST.skeptic,
        () => agent(`${COMMON}

YOU ARE A SKEPTIC. Try to REFUTE this finding; default to refuted=true if you can't confirm it. ${angle}
Work in the reviewer's worktree ${ROOT}/.worktrees/m3-review-${ROUND}-${l.key} (detached at ${BASE}; run every command as \`cd <it> && ...\`; never commit). Its recordings are in captures/review/ there.
FINDING ${f.id} (${f.severity}): ${f.title}
${f.detail}
Evidence: ${f.evidence}
Repro: ${f.repro}
Suggested fix: ${f.suggested_fix}`, { label: `skeptic:${f.id}:${k}`, phase: 'Verify', schema: VOTE_SCHEMA, model: 'sonnet' })))
        .then(r => r.skipped ? null : r.result)))
        .then(votes => {
          const vs = votes.filter(Boolean)
          const confirms = vs.filter(v => !v.refuted).length
          return { ...f, votes: vs, survives: vs.length >= 2 && confirms >= 2 }
        })
    })).then(verified => ({ lens: l.key, review: rev, verified }))
  })

const allVerified = reviewed.filter(Boolean).flatMap(r => r.verified)
const survivors = allVerified.filter(f => f.survives)
log(`${allVerified.length} findings, ${survivors.length} survive`)

// ---------- partition ----------
phase('Partition')
let packages = A.packages || null
if (!packages && survivors.length) {
  const p = await launch('partition', 'Partition', COST.partition, () => agent(`${COMMON}

PARTITION the surviving findings below into fix packages for parallel Sonnet fixers, each in its own worktree. Packages must touch DISJOINT files (the shared tuning_data.gd only inside each package's own subgroup; tuning/default.json is regenerated by the lead). Group findings with a shared root cause. Order packages by severity. Leave a finding unassigned only if it needs Game-boy (a spec change) or is out of scope, with the reason. Keep the number of packages small (at most 4).
${JSON.stringify(survivors.map(f => ({ id: f.id, severity: f.severity, title: f.title, detail: f.detail, suggested_fix: f.suggested_fix, files: f.files, root_causes: f.votes.map(v => v.root_cause), files_to_change: f.votes.flatMap(v => v.files_to_change), spec_change: f.spec_change || f.votes.some(v => v.fix_needs_spec_change) })), null, 1)}`,
    { label: 'partition', phase: 'Partition', schema: PARTITION_SCHEMA }))
  packages = p.skipped ? null : p.result
}

// ---------- fix ----------
phase('Fix')
let fixes = []
if (packages && !A.no_fix) {
  fixes = await parallel(packages.packages.map(pk => () => fixSlot(() => launch(`fix:${pk.key}`, 'Fix', COST.fixer, () => {
    const s = `${ROUND}-${pk.key}`
    const wt = `${ROOT}/.worktrees/m3-fix-${s}`
    const branch = `m3/fix-${s}`
    const fs = pk.finding_ids.map(id => survivors.find(f => f.id === id)).filter(Boolean)
    return agent(`${COMMON}

YOU ARE A FIXER for package "${pk.key}" (${pk.title}). Partition notes: ${pk.notes}
OWNED FILES: ${pk.files.join(', ')}. Other fixers work on other files at the same time; touch other files only if unavoidable, and in tuning_data.gd only inside your own subgroup.
SETUP: \`cd ${ROOT} && git fetch -q origin && git worktree add .worktrees/m3-fix-${s} -b ${branch} origin/${BASE_BRANCH}\` (if the branch or worktree already exists from a cut-off run, reuse it and continue from its newest wip: commit; if git reports a lock, wait 10 s and retry), then \`cd ${wt} && godot --headless --import --quit && git push -u origin ${branch}\`. Run EVERY command as \`cd ${wt} && ...\`.
For each finding: confirm it, fix the root cause, add a test that fails without the fix where it's testable, and for visual or feel fixes re-record the affected acts into ${wt}/captures/fix/, tile sheets and LOOK at them. A fix that needs a spec change: don't implement it; report it (outcome spec_question) with a proposal and a default. Moves go through tools/gen_moves.gd; new tunables need \`godot --headless -s tools/gen_default_preset.gd\`. Run the full suite at the end (all pass, no SCRIPT ERROR or ERROR). Log each judgement call (decision, an alternative not taken, why) in docs/milestones/M3-calls/fix-${s}.md.
Commit "wip: ..." and push every 15-20 minutes. Finish with a commit whose subject is "M3 fix-${s}: <short list>", then push. Every commit message ends with the line "${TRAILER}". Never merge; never edit docs/HANDOFF.md, README.md or docs/SPEC.md; never commit captures/.
FINDINGS:
${JSON.stringify(fs.map(f => ({ id: f.id, severity: f.severity, title: f.title, detail: f.detail, evidence: f.evidence, repro: f.repro, suggested_fix: f.suggested_fix, skeptics: f.votes.map(v => ({ refuted: v.refuted, reason: v.reason, root_cause: v.root_cause, files: v.files_to_change })) })), null, 1)}`,
      { label: `fix:${pk.key}`, phase: 'Fix', schema: FIX_SCHEMA, model: 'sonnet' })
  })).then(r => ({ key: pk.key, ...r }))))
}

return {
  round: ROUND,
  base: BASE,
  reviews: Object.fromEntries(reviewed.filter(Boolean).map(r => [r.lens, r.review])),
  verdicts: Object.fromEntries(allVerified.map(f => [f.id, { survives: f.survives, votes: f.votes }])),
  findings: allVerified.map(f => ({ id: f.id, severity: f.severity, title: f.title, survives: f.survives, files: f.files })),
  packages,
  fixes: fixes.filter(Boolean).map(r => r.skipped ? { key: r.key, skipped: true } : r.result ? { key: r.key, ...r.result } : { key: r.key, died: true }),
  usage: usageLog,
}
