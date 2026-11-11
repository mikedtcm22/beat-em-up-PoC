# Runway ledger (Plan B)

Game-boy's caps, at $0.01 a credit, spent only through `tools/video/runway_restyle.py`:
- **the Plan B test, $15** (2026-11-09, in the chat; [PLAN_B_TEST.md](PLAN_B_TEST.md)); it spent 308 credits;
- **the full cut, $40 more** (2026-11-10, in the chat: "Yes, full cut"), for the 13 character shots.

So the counted total stays at most **4308 credits** (the tool's `CAP_CREDITS`).

**How the tool keeps this table:**
- It writes a row before each submit and fills in the result after.
- It refuses a job when the counted total plus the job's estimate would pass the cap (4308 credits since the full cut's go; 1500 before).
- **The estimate:** aleph2's price (28 credits a second, at least 56 a generation; [the price list](https://docs.dev.runwayml.com/guides/pricing.md), checked 2026-11-09), with the input's seconds rounded up, so it's never under the real charge.
- **Counted:** a row's charged credits (the task's `cost`, else the change in the project's credit balance), or its estimate while the charge is unknown. A request the API answered with an error made no task, so it counts 0.
- Edit a row by hand only to correct it from the developer portal's usage page, and keep the columns.

| When (CST) | Job | Task | Input s | Estimate (credits) | Status | Charged (credits) | Counted total (credits) |
| --- | --- | --- | --- | --- | --- | --- | --- |
| 2026-11-09 21:12:34 | t03_r1 | a868cd90-4e5f-44fa-8433-4248d1e2ab54 | 3.42 | 112 | SUCCEEDED | 84 | 84 |
| 2026-11-09 21:14:09 | t11_r1 | cabced9c-1003-47be-af7c-82a8f1ce18e0 | 8.12 | 252 | SUCCEEDED | 224 | 308 |
| 2026-11-10 19:33:40 | t01_r1 | a03c7dc7-1a46-4897-a360-170bc312ba5a | 3.00 | 84 | SUCCEEDED | 84 | 392 |
| 2026-11-10 19:34:54 | t02_r1 | fed0854c-8597-4b31-b673-806540ff0fd7 | 2.00 | 56 | SUCCEEDED | 56 | 448 |
| 2026-11-10 19:36:08 | t04_r1 | 62a00101-18c6-4b2d-8510-00f2ff43cb06 | 2.71 | 84 | SUCCEEDED | 56 | 504 |
| 2026-11-10 19:37:51 | t05_r1 | b4b04b07-60ca-4747-85a2-b15bed1f4f17 | 3.79 | 112 | SUCCEEDED | 84 | 588 |
| 2026-11-10 19:39:05 | t06_r1 | 1f8f23e2-5977-4470-8ae5-f12fc1139cd9 | 3.00 | 84 | SUCCEEDED | 84 | 672 |
| 2026-11-10 19:40:50 | t07_r1 | ec830e17-ed32-4d0e-be50-1b06f56b4ee5 | 3.62 | 112 | SUCCEEDED | 84 | 756 |
| 2026-11-10 19:43:04 | t08_r1 | 90813b3f-08c1-4b7a-96c5-8bfe2afa79c8 | 2.79 | 84 | SUCCEEDED | 56 | 812 |
| 2026-11-10 19:45:17 | t09_r1 | 79edbd3b-3e41-47d4-96b1-1c89874fe00c | 2.00 | 56 | SUCCEEDED | 56 | 868 |
| 2026-11-10 19:47:32 | t10_r1 | f8a258de-6f53-459d-8412-c47e94d53259 | 4.00 | 112 | SUCCEEDED | 112 | 980 |
| 2026-11-10 19:50:16 | t12_r1 | 74bec20f-40d5-46bd-86c2-26cbbff26af0 | 3.00 | 84 | SUCCEEDED | 84 | 1064 |
| 2026-11-10 19:51:31 | t13_r1 | 1550ec1c-cd2f-4950-b8c4-edde0e11fc08 | 3.42 | 112 | SUCCEEDED | 84 | 1148 |
| 2026-11-10 20:00:28 | t03_r2 | dd044834-fcb4-4656-9292-0429be8e2100 | 3.42 | 112 | SUCCEEDED | 84 | 1232 |
| 2026-11-10 20:01:42 | t05_r2 | faed22f4-bc0b-4229-8dce-302f3d7e7b58 | 3.79 | 112 | SUCCEEDED | 84 | 1316 |
| 2026-11-10 20:03:25 | t09_r2 | f5c88ff3-612d-470f-93ec-4a03de69fea9 | 2.00 | 56 | SUCCEEDED | 56 | 1372 |
| 2026-11-10 20:05:39 | t13_r2 | 6330e346-88ea-4cca-a875-e28eab24712d | 3.42 | 112 | SUCCEEDED | 84 | 1456 |
