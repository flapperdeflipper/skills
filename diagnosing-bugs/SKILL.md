---
name: diagnosing-bugs
description: Diagnosis loop for hard bugs, failures and performance regressions. Use when the user says "diagnose" or "debug this", or reports something broken, throwing, failing, flaky or slow.
---

# Diagnosing Bugs

A discipline for hard bugs. Skip phases only when explicitly justified.

Adapted from [mattpocock/skills](https://github.com/mattpocock/skills).

## Phase 1: Build a feedback loop

**This is the skill.** Everything else is mechanical. If you have a **tight** pass/fail signal for the bug, one that goes red on _this_ bug, you will find the cause. Bisection, hypothesis-testing and instrumentation all just consume it. If you don't have one, no amount of staring at code will save you.

Spend disproportionate effort here. **Be aggressive. Be creative. Refuse to give up.**

### Ways to construct one, in roughly this order

1. **Failing test** at whatever seam reaches the bug: unit, integration, e2e.
2. **CLI invocation** with a fixture input, diffing stdout against a known-good snapshot.
3. **Curl / HTTP script** against a running service, or `kubectl port-forward` to the pod.
4. **Render-and-diff.** For Helm, Kustomize or Terraform: `helm template`, `kustomize build`, `terraform plan -out` then `terraform show -json`, diffed against a known-good render. Config bugs die here.
5. **Container run.** `docker run` or `podman run` the image with the failing env, so the loop is one command with no cluster in it.
6. **Replay a captured artifact.** Save the real request, payload, event or log line to disk, replay it through the code path in isolation.
7. **Throwaway harness.** Spin up a minimal subset of the system (one service, mocked deps) that exercises the bug path with a single call.
8. **Property / fuzz loop.** If the bug is "sometimes wrong output", run 1000 random inputs and look for the failure mode.
9. **Bisection harness.** If the bug appeared between two known states (commit, image tag, chart version, dataset), automate "boot at state X, check, repeat" so `git bisect run` can drive it.
10. **Differential loop.** Run the same input through old-version vs new-version, or two configs, and diff outputs.
11. **HITL bash script.** Last resort. If a human must click or touch hardware, drive _them_ with `scripts/hitl-loop.template.sh` so the loop is still structured. Captured output feeds back to you.

Build the right feedback loop and the bug is 90% fixed.

### Tighten the loop

Treat the loop as a product. Once you have _a_ loop, **tighten** it:

- Can I make it faster? Cache setup, skip unrelated init, narrow the scope.
- Can I make the signal sharper? Assert on the specific symptom, not "didn't crash".
- Can I make it more deterministic? Pin time, seed RNG, isolate filesystem, freeze network, pin image digests instead of tags.

A 30-second flaky loop is barely better than no loop. A 2-second deterministic one is a debugging superpower.

### Non-deterministic bugs

The goal is not a clean repro but a **higher reproduction rate**. Loop the trigger 100x, parallelise, add stress, narrow timing windows, inject sleeps. A 50%-flake bug is debuggable, 1% is not. Keep raising the rate until it is.

### When you genuinely cannot build a loop

Stop and say so explicitly. List what you tried. Ask the user for one of: access to an environment that reproduces it, a captured artifact (HAR, log dump, core dump, `kubectl describe` output, screen recording with timestamps), or permission to add temporary production instrumentation. Do **not** proceed to hypothesise without a loop.

### Completion criterion: a tight loop that goes red

Phase 1 is done when the loop is **tight** and **red-capable**. You can name **one command**, a script path, a test invocation, a curl, that you have **already run at least once** (paste the invocation and its output), and that is:

- [ ] **Red-capable.** It drives the actual bug code path and asserts the **user's exact symptom**, so it can go red on this bug and green once fixed. Not "runs without erroring": it must catch _this_ bug.
- [ ] **Deterministic.** Same verdict every run. For flaky bugs, a pinned, high reproduction rate per above.
- [ ] **Fast.** Seconds, not minutes.
- [ ] **Agent-runnable.** You can run it unattended. A human in the loop only via `scripts/hitl-loop.template.sh`.

If you catch yourself reading code to build a theory before this command exists, **stop. Jumping straight to a hypothesis is the exact failure this skill prevents.** No red-capable command, no Phase 2.

## Phase 2: Reproduce and minimise

Run the loop. Watch it go red.

Confirm:

- [ ] The loop produces the failure mode the **user** described, not a different failure that happens to be nearby. Wrong bug, wrong fix.
- [ ] The failure is reproducible across multiple runs, or for non-deterministic bugs at a high enough rate to debug against.
- [ ] You captured the exact symptom (error message, wrong output, slow timing) so later phases can verify the fix addresses it.

### Minimise

Once it is red, shrink the repro to the **smallest scenario that still goes red**. Cut inputs, callers, config, data and steps **one at a time**, re-running the loop after each cut. Keep only what is required for the failure.

Why bother: a minimal repro shrinks the hypothesis space in Phase 3 and becomes the clean regression test in Phase 5.

Done when **every remaining element is required**: removing any one of them makes the loop go green.

Do not proceed until you have reproduced **and** minimised.

## Phase 3: Hypothesise

Generate **3 to 5 ranked hypotheses** before testing any of them. Single-hypothesis generation anchors on the first plausible idea.

Each hypothesis must be **falsifiable**: state the prediction it makes.

> Format: "If X is the cause, then changing Y will make the bug disappear / changing Z will make it worse."

If you cannot state the prediction, the hypothesis is a vibe. Discard or sharpen it.

**Show the ranked list to the user before testing.** They often have context that re-ranks it instantly ("we just rolled a node pool upgrade, that's #3"), or know hypotheses already ruled out. Cheap checkpoint, big time saver. Don't block on it: proceed with your ranking if the user is away.

## Phase 4: Instrument

Each probe must map to a specific prediction from Phase 3. **Change one variable at a time.**

Tool preference:

1. **Debugger or REPL inspection** if the environment supports it. One breakpoint beats ten logs.
2. **Targeted logs** at the boundaries that distinguish hypotheses.
3. Never "log everything and grep".

**Tag every debug log** with a unique prefix, e.g. `[DEBUG-a4f2]`. Cleanup then becomes a single grep. Untagged logs survive, tagged logs die.

**Perf branch.** For performance regressions, logs are usually wrong. Establish a baseline measurement first (timing harness, profiler, query plan, `time`), then bisect. Measure first, fix second.

**Infra branch.** For cluster and cloud failures, the probe is usually a read, not a log: events (`kubectl get events --sort-by=.lastTimestamp`), the previous container's logs, admission webhook responses, IAM policy simulation, VPC flow logs. Read-only probes first, always.

## Phase 5: Fix and regression test

Write the regression test **before the fix**, but only if there is a **correct seam** for it.

A correct seam is one where the test exercises the **real bug pattern** as it occurs at the call site. If the only available seam is too shallow (a single-caller test when the bug needs multiple callers, a unit test that cannot replicate the chain that triggered the bug), a regression test there gives false confidence.

**If no correct seam exists, that itself is the finding.** Note it. The architecture is preventing the bug from being locked down.

If a correct seam exists:

1. Turn the minimised repro into a failing test at that seam.
2. Watch it fail.
3. Apply the fix.
4. Watch it pass.
5. Re-run the Phase 1 feedback loop against the original, un-minimised scenario.

## Phase 6: Cleanup and post-mortem

Required before declaring done:

- [ ] Original repro no longer reproduces (re-run the Phase 1 loop)
- [ ] Regression test passes, or the absence of a seam is documented
- [ ] All `[DEBUG-...]` instrumentation removed (grep the prefix)
- [ ] Throwaway prototypes, scratch manifests and temporary IAM grants deleted
- [ ] The hypothesis that turned out correct is stated in the commit or PR message, so the next debugger learns

**Then ask: what would have prevented this bug?** If the answer is architectural (no good test seam, tangled callers, hidden coupling, missing guardrail in the pipeline) say so with specifics. Make that recommendation **after** the fix is in, not before: you know more now than when you started.
