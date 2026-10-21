# claude-skills

Nine [Claude Code](https://code.claude.com/docs/en/overview) skills I use every day, in the
[Agent Skills](https://agentskills.io) format: one folder per skill, a `SKILL.md` with `name`
and `description` in the frontmatter, and the instructions underneath.

Eight of them are about one problem: an agent that says "done" is not evidence that anything is
done. The house files give a project four plain Markdown files at its root (`PLAN.md`,
`TASKS.md`, `PROGRESS.md`, `DECISIONS.md`), and the skills are the verbs that write and check
them. Every outcome and task carries a command; it is ticked when that command exits 0, not when
somebody feels finished. The ninth skill, `frontend`, is unrelated: it is what I learned about
showing numbers you are not certain about.

```
skills/
  house-files/     the contracts for the four files, plus templates
  plan-md/         write or revise PLAN.md
  plan-together/   argue a plan out before anybody builds
  verify/          run a VERIFY command and report what happened
  state/           reconcile the files against disk and git
  handoff/         write the brief for whoever picks this up next
  decision/        record a decision, or a gotcha
  pulse-review/    fresh-context review of the diff against the plan
  frontend/        UI that shows measured quantities
agents/
  plan-reviewer.md the subagent pulse-review dispatches
```

## Install

**As personal skills.** Copy the folders into `~/.claude/skills/` and the agent into
`~/.claude/agents/`. They show up in the `/` menu of every project on that machine.

```bash
git clone https://github.com/agentwolf27/claude-skills.git
cp -R claude-skills/skills/* ~/.claude/skills/
cp claude-skills/agents/plan-reviewer.md ~/.claude/agents/
```

**As a plugin.** The repo is also a one-plugin marketplace. Inside Claude Code:

```
/plugin marketplace add agentwolf27/claude-skills
/plugin install vish@agentwolf27
```

Skills then run as `/vish:verify`, `/vish:frontend`, and so on. Pick one method, not both,
or you get each skill twice.

**Into one project.** Copy the folders you want into that repo's `.claude/skills/` and commit
them. Teammates get them on clone.

Check that every skill parses, from the repo root or against any skills directory:

```bash
sh scripts/check-skills.sh
```

## The skills

### house-files

The contracts for `PLAN.md`, `TASKS.md`, `PROGRESS.md` and `DECISIONS.md`: how an outcome, a
task, a progress entry and a decision are written so a command can check them. The other skills
refer to it. `templates/` next to it holds a blank copy of each file. Claude loads it on its own
when you add a task or mark something done; you can also ask for it.

```
/house-files
> Add a task for the retry cap with a VERIFY that fails when the cap is missing.
```

### plan-md

Writes or revises `PLAN.md`: five sections, and a "Done looks like" where every line is
`- [ ] <outcome> — `<command>``. If an outcome cannot be checked, it moves to "Why" or is
sharpened until it can be. It never ticks a line.

```
/plan-md a CLI that renames photos by the date in their EXIF data
> Writes PLAN.md with checkable outcomes, asks before rewriting a plan that still holds.
```

### plan-together

For a plan bigger than a day, or one whose shape is not obvious. First it dispatches one
subagent per frame (frontend, backend, tester, reviewer, manager), each blind to the others, so
the options cannot anchor on each other. Then the critics argue one at a time *through*
`PLAN.md`, each reading what came before, until a full round adds nothing. You sign it with a
`PLAN FROZEN` line, and nothing is dispatched before that line exists.

```
/plan-together how should sessions be stored
/plan-together frontend backend tester
> The argument stays in PLAN.md underneath the plan, as the record of how it was reached.
```

### verify

Runs a task's or outcome's VERIFY command and reports the exit code and the output, both. A
task moves to Done only on exit zero. A refused command is reported as not checked; a task with
no command is reported as uncheckable. Nothing here is a judgement call.

```
/verify 7
/verify retry
/verify            (everything open)
```

### state

For resuming, or before telling anybody the work is finished. Re-runs every VERIFY including the
ticked ones, unticks what no longer passes, finds work in `git diff` and `git log` that nobody
wrote down, and corrects the files rather than the story. Reports a count, not a narrative.

```
/state
> 11 checks ran, 9 passed, 2 unticked, 1 task added from the working tree.
```

### handoff

Writes the brief for whoever continues: where the work actually is, what is blocked and on
what, what was tried and did not work, and the one thing to do first. Appends it to
`PROGRESS.md` so it lives on disk, not in a chat window.

```
/handoff the storage decision is still open, waiting on the owner
> Appends a dated, signed entry to PROGRESS.md and fixes TASKS.md if work stopped mid-task.
```

### decision

Appends to `DECISIONS.md`: the decision, the alternative it beat and why, and what would reopen
it. Entries are never edited, only superseded or contested. With `gotcha`, it records something
that bit you, named for the symptom, with what to do instead.

```
/decision sessions are per project, not per agent; per-agent loses the shared context
/decision gotcha the test suite passes on undefined and fails on null; that is coercion
```

### pulse-review

Reviews the current diff against the plan with a subagent that did not write the code. The
reviewer runs each outcome's VERIFY and reports proven, not proven, uncheckable and out of
scope, with evidence. Ticks only what it proved. Needs `agents/plan-reviewer.md` installed.

```
/pulse-review
/pulse-review origin/dev
> Relays the reviewer's findings in full, then ticks only the outcomes whose command exited 0.
```

### frontend

Not a workflow skill. It is a reference for interfaces that display measured quantities: text
layout without reflow (and the four caveats before you ship Pretext), how many digits a number
earns, why an error bar is usually the wrong move, empty states that do not read as zero, and
the JavaScript coercions that turn `null` into a confident `0.00`. Every claim carries its
source.

```
/frontend
> Review this dashboard. Half the fields are nullable and I think one of them renders as zero.
```

## Pulse

These skills were written alongside [Pulse](https://github.com/agentwolf27/pulse), a progress
bar for Claude Code sessions that reads the same four files. The skills do not need it. Where
Pulse is installed, `verify`, `state`, `plan-md` and `handoff` use its `pulse-plan` command to
run every outcome deterministically; where it is not, the skill says so in its context and
Claude runs the commands itself. Pulse's own repo ships the same skills as slash commands.

## Not in this repo

Skills I use that are not mine to publish: Anthropic's bundled skills, plugins from marketplaces,
and a few private ones with my own job-search details in them.

## License

MIT. See [LICENSE](LICENSE).
