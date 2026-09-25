# Cloud session prompt: workspace model

Prompt given to a Claude Code cloud session (claude.ai/code) to implement
`docs/prd-workspace-model.md` unattended. Kept here as a record of what was
asked. Paste everything below the line.

---

You're implementing the workspace instrument model for aion, a Flutter desktop astrology app. Nobody will be around to answer questions during this session. Work through the whole task list on your own, and leave a clean, reviewable trail.

## 1. Set up the environment

Flutter isn't preinstalled. From the repo root:

```bash
bash scripts/cloud-setup.sh
```

This installs Flutter 3.47.4, puts `flutter`/`dart` on PATH, and resolves all dependencies. It is idempotent. If `flutter` is already on PATH, run it anyway. Then establish the baseline before changing anything:

```bash
flutter analyze
flutter test --exclude-tags integration
```

Both should be clean apart from a handful of pre-existing info/warning lints. Note the baseline test count. If setup fails, fix the script: the environment is Ubuntu 24.04 x86_64 and you have root. Commit the fix as `cloud-setup: <what>`. Don't start feature work until the tests run.

## 2. Read, in this order

1. `CLAUDE.md`: build commands, architecture, theming rule.
2. `CONTEXT.md`: domain glossary.
3. `docs/code-map.md`: directory index, key types, providers, data flow.
4. `docs/prd-workspace-model.md`: the design. It's the source of truth for intent.
5. `docs/workspace-model-tasks.md`: the task list, working rules, definition of done, codebase conventions, and a log. It's the source of truth for scope and order. **Follow its working rules exactly.**

## 3. Do the work

Work the tasks in `docs/workspace-model-tasks.md` top to bottom: aion/61, then phases 1–5. For each task:

- Read the code you're about to change first. Understand the existing pattern before adding to it, and extend existing types rather than building parallel ones.
- Implement it, and add pure-logic tests for the new model/logic.
- Run `flutter analyze` and `flutter test --exclude-tags integration`. Don't commit on red.
- Tick its acceptance criteria in the tasks doc, and log any decisions or deviations in the log section.
- Commit: `aion/N: <task title>`.

**Push after each phase** so progress survives if the session is interrupted.

If your context gets compacted or the session resumes, the ticked checkboxes, the log, and `git log` are your state. Re-read the tasks doc and carry on from the first unticked task.

Things that will come up:

- **You can't run the app.** There's no display, and chart computation needs the drishti plugin from another repo. Everything UI-facing is verified by a human afterwards. So keep widget code simple and conventional, and list in the log every UI behavior you couldn't verify.
- **Ambiguity:** don't stop and don't ask. Choose the most conservative reading consistent with the PRD, log it, and continue.
- **Genuinely blocked:** mark the task `BLOCKED` with the reason, skip it and its dependents, and continue with whatever is still reachable.
- **Tooling references:** docs may mention yojana, sutra, or `.sutra/rules.toml`. That tooling is local-only and not available here. Ignore those instructions, but do honor the layering constraints the tasks doc spells out.
- **Scope:** implement what the tasks say. Don't refactor unrelated code, don't upgrade dependencies, and don't touch time-cursor work (aion/78, aion/79).
- **Hygiene:** never use `--no-verify`. Don't modify or delete existing tests to make them pass unless the task changes the behavior they test, and log it when you do.

## 4. Finish

When every task is done, blocked, or skipped:

1. Update `docs/code-map.md` for the new directories, types, and providers.
2. Write `docs/reviews/workspace-model-cloud-run.md` covering:
   - a per-task table: status (done / partial / blocked), commit(s), one line on what was built
   - deviations from the PRD, and why
   - **a manual test script:** numbered click-through steps a human runs with `flutter run -d linux` to check the UI work, starting with PRD user story 1 (load a chart into a slot, every bound card updates)
   - known gaps, stubs, and TODOs
   - the final analyze/test output summary compared with the baseline
3. Commit, push, and open a PR against `main` titled `Workspace instrument model (aion/61, 63–80)`, with the review doc's summary as the description.
