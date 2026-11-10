# Runway ledger (Plan B)

Game-boy's cap for the Plan B test: **$15** of Runway credits (2026-11-09, in the chat; [PLAN_B_TEST.md](PLAN_B_TEST.md)), at $0.01 a credit, spent only through `tools/video/runway_restyle.py`. The full cut (about $31, capped at $40) needs his go after the test.

**How the tool keeps this table:**
- It writes a row before each submit and fills in the result after.
- It refuses a job when the counted total plus the job's estimate would pass 1500 credits.
- **The estimate:** aleph2's price (28 credits a second, at least 56 a generation; [the price list](https://docs.dev.runwayml.com/guides/pricing.md), checked 2026-11-09), with the input's seconds rounded up, so it's never under the real charge.
- **Counted:** a row's charged credits (the task's `cost`, else the change in the project's credit balance), or its estimate while the charge is unknown. A request the API answered with an error made no task, so it counts 0.
- Edit a row by hand only to correct it from the developer portal's usage page, and keep the columns.

| When (CST) | Job | Task | Input s | Estimate (credits) | Status | Charged (credits) | Counted total (credits) |
| --- | --- | --- | --- | --- | --- | --- | --- |
| 2026-11-09 21:12:34 | t03_r1 | a868cd90-4e5f-44fa-8433-4248d1e2ab54 | 3.42 | 112 | SUCCEEDED | 84 | 84 |
| 2026-11-09 21:14:09 | t11_r1 | cabced9c-1003-47be-af7c-82a8f1ce18e0 | 8.12 | 252 | SUCCEEDED | 224 | 308 |
