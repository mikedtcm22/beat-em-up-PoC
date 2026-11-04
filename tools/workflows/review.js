export const meta = {
  name: 'milestone-review',
  description: 'Milestone review round: one reviewer per lens (Opus for visual lenses, Sonnet for code lenses), one Sonnet skeptic per medium or high finding, a Sonnet partition, Sonnet fixers; every launch usage-gated',
  phases: [
    { title: 'Review', detail: 'one reviewer per lens, each in its own detached worktree' },
    { title: 'Verify', detail: 'one Sonnet skeptic per medium or high finding; lows go to the lead' },
    { title: 'Partition', detail: 'survivors into fix packages with disjoint files' },
    { title: 'Fix', detail: 'one Sonnet fixer per package in its own worktree' },
  ],
}

// The review runner for every milestone from M5 on (docs/HANDOFF.md, "Usage rules for the working
// session"). Run inline as a Workflow (scriptPath: this file) with args saved in
// docs/reviews/M<N>/args-review-<round>.json:
//   milestone: 5               worktrees .worktrees/m<N>-review-<round>-<lens>, fix branches
//                              m<N>/fix-<round>-<package>, finding ids <round>-<lens>-NN
//   summary: "<text>"          one line on the milestone's scope
//   round: "final"             the round's name
//   base: "<sha>"              the commit every reviewer worktree is detached at (the merged head)
//   base_branch: "m5/<topic>"  the branch fixers cut from
//   read_first: [...]          the files and sections every agent reads (keep it short)
//   captures_dir: "<path>"     the lead's shared recordings: reviewers judge from these and record
//                              only what's missing
//   image_budget: 30           the most images a reviewer reads
//   lenses: [{ key, brief, est?, model?, effort? }]   key [a-z0-9]; brief: what to judge and how. A
//                              visual lens (art, motion, feel, judged from images) keeps the default
//                              (the session's Opus, effort "high"); a code, test or pipeline lens
//                              sets model "sonnet"
//   common_note: "<text>"      added to every prompt (state, known items)
//   reviews / verdicts / packages   skip those agents (from an earlier, cut-off run)
//   skeptic_severities: ["high", "medium"]   findings that get a skeptic; the rest are returned in
//                              for_lead_triage, and the lead promotes any with verdicts
//   partition: true            false: stop after the skeptics and return the survivors (the lead
//                              partitions inline, which is cheaper for a handful of findings)
//   no_fix: true               stop after the partition
//   findings_path: "<file>"    with packages and no lenses: run only the fixers, which read their
//                              findings from the file
//   max_packages: 3, fix_concurrency: 2, review_concurrency: 3
//   costs: { reviewer, skeptic, partition, fixer }   gate estimates in % of a 5-hour window

const ROOT = '/Users/arachne/repos/beat-em-up-PoC'
const LIMIT = 90
const A = args || {}
const N = A.milestone
const ROUND = A.round || 'r1'
const BASE = A.base
const BASE_BRANCH = A.base_branch
if (!N || !BASE || !BASE_BRANCH) return { error: 'args.milestone, args.base and args.base_branch are required' }
const COST = Object.assign({ reviewer: 5, skeptic: 1, partition: 1, fixer: 5 }, A.costs || {})
const IMAGES = A.image_budget || 30
const SEVERITIES = A.skeptic_severities || ['high', 'medium']
const TRAILER = 'Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>'

const GATE_SCHEMA = {
  type: 'object',
  properties: { five_hour: { type: 'number' }, weekly: { type: 'number' } },
  required: ['five_hour', 'weekly'],
}
const FINDINGS_SCHEMA = {
  type: 'object',
  properties: {
    summary: { type: 'string' },
    checked: { type: 'array', items: { type: 'string' }, description: 'every act, metric, code area and edge case you checked, one short line each' },
    sheets: { type: 'array', items: { type: 'string' }, description: 'absolute paths of the most telling sheets (at most 8)' },
    passes: { type: 'array', items: { type: 'string' }, description: 'gate or rubric items that passed, each with its evidence' },
    scores: {
      type: 'array',
      description: 'every rubric item your brief names, scored 0 (fails), 1 (acceptable) or 2 (production); empty if your brief names none',
      items: {
        type: 'object',
        properties: {
          item: { type: 'string' },
          score: { type: 'number', enum: [0, 1, 2] },
          evidence: { type: 'string', description: 'the frame, still or crop that decides it, and what it shows' },
        },
        required: ['item', 'score', 'evidence'],
      },
    },
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
  required: ['summary', 'checked', 'sheets', 'passes', 'scores', 'also_noticed', 'findings'],
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
const skepticSlot = semaphore(4)
const fixSlot = semaphore(A.fix_concurrency || 2)

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

const COMMON = `Milestone ${N}${A.summary ? ` (${A.summary})` : ''} of a Godot 4.7.2 first-person beat-em-up proof of concept at ${ROOT} (GDScript, static typing, Forward+, Jolt, 60 Hz). Game-boy, the owner, plays and signs off milestones; he isn't available: never ask or message him. Only first-person looks count; side view and free fly are debug views (use them for mechanics).
READ ONLY WHAT YOU NEED: ${(A.read_first || []).length ? A.read_first.join('; ') : `docs/milestones/M${N}-plan.md`}, and your brief. Search (grep) instead of reading whole documents. The builders' calls are in docs/milestones/M${N}-calls/*.md: don't re-litigate them unless they break the spec or the done-when.
Tools: tools/run_tests.sh (full suite, about 5 minutes; -gselect=<file> for one) — read the output for SCRIPT ERROR, SHADER ERROR and ERROR. ${A.captures_dir ? `The lead's recordings for this round are in ${A.captures_dir} (one folder per act, with sheets): judge from them and record only what's missing. ` : ''}tools/capture_bot.sh <bot scene> <out dir> "<act filter>" [stills fps] records a bot with Movie Maker (a lock allows two at once); tools/look_sheets.sh <avi> <out dir> cuts stills and crops. IMAGE BUDGET: at most ${IMAGES} image reads in all; scan contact sheets at about 1000 px wide and read a full-resolution crop only for the item you judge. The Blender chain is tools/pipeline/run.py (headless Blender only: never the Blender MCP). The machine has 8 GB of RAM and other agents run at once: one Godot process at a time; never leave one running.
${A.common_note || ''}`

// ---------- review ----------
phase('Review')
const lenses = A.lenses || []
function reviewerPrompt(l) {
  const wt = `${ROOT}/.worktrees/m${N}-review-${ROUND}-${l.key}`
  return `${COMMON}
YOU ARE AN ADVERSARIAL REVIEWER, lens "${l.key}". ${l.brief}
SETUP: \`cd ${ROOT} && git fetch -q origin && (git worktree add --detach .worktrees/m${N}-review-${ROUND}-${l.key} ${BASE} || git -C .worktrees/m${N}-review-${ROUND}-${l.key} checkout -q --detach ${BASE})\` (if git reports a lock, wait 10 s and retry), then \`cd ${wt} && godot --headless --import --quit\`. Work only there (run EVERY command as \`cd ${wt} && ...\`), and put any recordings in ${wt}/captures/review/. You may write probe scripts or temporary tests there, but never commit or push anything.
Find real defects against the spec, the plan and the done-when: things Game-boy would see or feel in first person, mechanics that break, rule violations in the code. Each finding needs concrete evidence (a frame in a sheet, a log line, a metric, a test you ran, file:line) and a repro. Rank them; at most 10; don't pad, and mark cosmetic or taste items low. List what you checked and what passed, briefly.`
}
const reviewed = await pipeline(lenses,
  l => A.reviews && A.reviews[l.key] ? A.reviews[l.key] : reviewSlot(() => launch(`review:${l.key}`, 'Review', l.est || COST.reviewer,
    () => agent(reviewerPrompt(l), { label: `review:${l.key}`, phase: 'Review', schema: FINDINGS_SCHEMA, model: l.model, effort: l.effort || 'high' })))
    .then(r => r.skipped ? null : r.result),
  (rev, l) => {
    if (!rev) return { lens: l.key, review: null, verified: [] }
    const findings = rev.findings.map((f, i) => ({ id: `${ROUND}-${l.key}-${String(i + 1).padStart(2, '0')}`, lens: l.key, ...f }))
    return parallel(findings.map(f => () => {
      if (A.verdicts && A.verdicts[f.id]) return Promise.resolve({ ...f, ...A.verdicts[f.id] })
      if (!SEVERITIES.includes(f.severity)) return Promise.resolve({ ...f, votes: [], survives: false, triage: 'lead' })
      return skepticSlot(() => launch(`skeptic:${f.id}`, 'Verify', COST.skeptic,
        () => agent(`${COMMON}
YOU ARE A SKEPTIC. Try to REFUTE this finding; default to refuted=true if you can't confirm it. REPRODUCE it (run the repro, probe or test at the reviewed commit), check it against the SPEC and the plan (a real defect, or an approved departure, a logged call, out of scope?), and read the CODE path: name the root cause and the files a fix must touch.
Work in the reviewer's worktree ${ROOT}/.worktrees/m${N}-review-${ROUND}-${l.key} (detached at ${BASE}; run every command as \`cd <it> && ...\`; never commit). Its recordings are in captures/review/ there.
FINDING ${f.id} (${f.severity}): ${f.title}
${f.detail}
Evidence: ${f.evidence}
Repro: ${f.repro}
Suggested fix: ${f.suggested_fix}`, { label: `skeptic:${f.id}`, phase: 'Verify', schema: VOTE_SCHEMA, model: 'sonnet', effort: 'medium' })))
        .then(r => r.skipped ? { ...f, votes: [], survives: false, triage: 'skipped' } : { ...f, votes: [r.result], survives: !r.result.refuted })
    })).then(verified => ({ lens: l.key, review: rev, verified }))
  })
const allVerified = reviewed.filter(Boolean).flatMap(r => r.verified)
const survivors = allVerified.filter(f => f.survives)
const forLead = allVerified.filter(f => f.triage)
log(`${allVerified.length} findings: ${survivors.length} survive, ${forLead.length} for the lead's triage`)

// ---------- partition ----------
phase('Partition')
let packages = A.packages || null
if (!packages && survivors.length && A.partition !== false) {
  const p = await launch('partition', 'Partition', COST.partition, () => agent(`${COMMON}
PARTITION the surviving findings below into fix packages for parallel Sonnet fixers, each in its own worktree. Packages must touch DISJOINT files (the shared tuning_data.gd only inside each package's own subgroup; tuning/default.json is regenerated by the lead). Group findings with a shared root cause, and batch small fixes into one package rather than many. Order packages by severity. Leave a finding unassigned only if it needs Game-boy (a spec change) or is out of scope, with the reason. At most ${A.max_packages || 3} packages.
${JSON.stringify(survivors.map(f => ({ id: f.id, severity: f.severity, title: f.title, detail: f.detail, suggested_fix: f.suggested_fix, files: f.files, root_causes: f.votes.map(v => v.root_cause), files_to_change: f.votes.flatMap(v => v.files_to_change), spec_change: f.spec_change || f.votes.some(v => v.fix_needs_spec_change) })), null, 1)}`,
    { label: 'partition', phase: 'Partition', schema: PARTITION_SCHEMA, model: 'sonnet', effort: 'medium' }))
  packages = p.skipped ? null : p.result
}

// ---------- fix ----------
phase('Fix')
let fixes = []
if (packages && !A.no_fix) {
  fixes = await parallel(packages.packages.map(pk => () => fixSlot(() => launch(`fix:${pk.key}`, 'Fix', COST.fixer, () => {
    const s = `${ROUND}-${pk.key}`
    const wt = `${ROOT}/.worktrees/m${N}-fix-${s}`
    const branch = `m${N}/fix-${s}`
    const fs = pk.finding_ids.map(id => survivors.find(f => f.id === id)).filter(Boolean)
    const findingsText = A.findings_path
      ? `Your findings are ${pk.finding_ids.join(', ')} in ${A.findings_path} (read the file's "findings" entries with those ids: the reviewer's detail, evidence, repro and suggested fix, and the skeptic's verdict with its root cause and files; "lead_overrides" holds the lead's rulings, which win).`
      : JSON.stringify(fs.map(f => ({ id: f.id, severity: f.severity, title: f.title, detail: f.detail, evidence: f.evidence, repro: f.repro, suggested_fix: f.suggested_fix, skeptics: f.votes.map(v => ({ refuted: v.refuted, reason: v.reason, root_cause: v.root_cause, files: v.files_to_change })) })), null, 1)
    return agent(`${COMMON}
YOU ARE A FIXER for package "${pk.key}" (${pk.title}). Partition notes: ${pk.notes}
OWNED FILES: ${pk.files.join(', ')}. Other fixers work on other files at the same time; touch other files only if unavoidable, and in tuning_data.gd only inside your own subgroup.
SETUP: \`cd ${ROOT} && git fetch -q origin && git worktree add .worktrees/m${N}-fix-${s} -b ${branch} origin/${BASE_BRANCH}\` (if the branch or worktree already exists from a cut-off run, reuse it and continue from its newest wip: commit; if git reports a lock, wait 10 s and retry), then \`cd ${wt} && godot --headless --import --quit && git push -u origin ${branch}\`. Run EVERY command as \`cd ${wt} && ...\`.
For each finding: confirm it, fix the root cause, add a test that fails without the fix where it's testable, and for visual or feel fixes re-record only the affected acts into ${wt}/captures/fix/ and LOOK at them (within the image budget). A fix that needs a spec change: don't implement it; report it (outcome spec_question) with a proposal and a default. New tunables need \`godot --headless -s tools/gen_default_preset.gd\`. Run the full suite at the end (all pass, no SCRIPT ERROR, SHADER ERROR or ERROR). Log each judgement call (decision, an alternative not taken, why) in docs/milestones/M${N}-calls/fix-${s}.md.
Commit "wip: ..." and push every 15-20 minutes. Finish with a commit whose subject is "M${N} fix-${s}: <short list>", then push. Every commit message ends with the line "${TRAILER}". Never merge; never edit docs/HANDOFF.md, README.md or docs/SPEC.md; never commit captures/. Report briefly.
FINDINGS:
${findingsText}`,
      { label: `fix:${pk.key}`, phase: 'Fix', schema: FIX_SCHEMA, model: 'sonnet', effort: 'high' })
  })).then(r => ({ key: pk.key, ...r }))))
}

return {
  round: ROUND,
  base: BASE,
  reviews: Object.fromEntries(reviewed.filter(Boolean).map(r => [r.lens, r.review])),
  verdicts: Object.fromEntries(allVerified.map(f => [f.id, { survives: f.survives, votes: f.votes, triage: f.triage || null }])),
  findings: allVerified.map(f => ({ id: f.id, severity: f.severity, title: f.title, survives: f.survives, triage: f.triage || null, files: f.files })),
  for_lead_triage: forLead.map(f => ({ id: f.id, severity: f.severity, title: f.title, detail: f.detail, suggested_fix: f.suggested_fix, files: f.files })),
  survivors: A.partition === false ? survivors.map(f => ({ id: f.id, severity: f.severity, title: f.title, files: f.files, root_causes: f.votes.map(v => v.root_cause) })) : undefined,
  packages,
  fixes: fixes.filter(Boolean).map(r => r.skipped ? { key: r.key, skipped: true } : r.result ? { key: r.key, ...r.result } : { key: r.key, died: true }),
  usage: usageLog,
}
