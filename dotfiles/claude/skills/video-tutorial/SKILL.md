---
name: video-tutorial
description: Use when the user gives a video tutorial — a YouTube link or a local video file — and wants to understand it, learn from it, reproduce what it builds, or improve on it. Watches the video's visual track through Gemini to recover the code, commands, versions, and UI actions shown on screen, then explains the technique, rebuilds it for real, and critiques where the tutorial is outdated or wrong. Also use for conference talks, screencasts, and demos when the user asks "what does this video do" or "build what they built". Not for videos where only the spoken words matter — a plain transcript skill is cheaper for those.
allowed-tools: Bash(python3:*) Read Write Edit Glob Grep
---

# Learning from a video tutorial

Claude cannot watch video. Gemini can, and it reads the **visual** track — which
is where a tutorial keeps the parts that matter. The narration says "and then we
configure the router"; the screen shows the twelve lines that actually do it. A
transcript-only approach throws away the tutorial and keeps the commentary.

`scripts/analyze_video.py` is the eyes. Everything after it is your job.

## Step 1 — Extract

```bash
python3 "$CLAUDE_SKILL_DIR/scripts/analyze_video.py" "<url-or-path>" \
    --output /tmp/tutorial.md
```

Useful flags:

- `--focus "the auth middleware"` — steer extraction when the user cares about
  one part of a long video
- `--model <id>` — override the default. Verify a model is actually callable
  before trusting it: the models endpoint lists ids that return 404.

Requires `GEMINI_API_KEY`, which lives in `~/.config/linux-cfg/secrets.env`.

Output sections are fixed: What this builds, Environment, Steps, Gotchas, Final
state, Weaknesses.

## Step 2 — Read it critically before believing it

The extraction is a strong reading of the screen, not ground truth. Resolve
these before building anything:

- `# ILLEGIBLE:` markers — the screen was unreadable. Do not paste these through
  as if they were code. Reconstruct from surrounding context and say that you
  did.
- `(inferred)` versions — check against what is actually installed here before
  pinning anything to them.
- APIs that look plausible but that you cannot find in the real library. A
  tutorial from three years ago references methods that no longer exist, and the
  extraction will faithfully reproduce them.

Verify against real documentation for anything load-bearing.

## Step 3 — Explain

Teach the technique, not the keystrokes. The user asked to *learn*, so the
explanation must survive the specific versions in the video:

- Why this approach, and what it is chosen over
- The one or two ideas that carry the design; the rest is detail
- Which steps are essential and which are the presenter's personal habit

Where the video does something without saying why, say so plainly rather than
inventing a rationale.

## Step 4 — Replicate

Actually build it. Not a summary of how it would be built.

- Use the versions installed here, not the ones in the video
- Follow the repo's existing conventions over the video's when they conflict
- Run it, and report what happened — including the failures
- Where you departed from the video, say where and why

If the video's approach cannot work as shown, stop and explain what breaks
rather than quietly substituting a different design.

## Step 5 — Improve

The **Weaknesses** section is the starting point, not the finish. Tutorials
optimise for a short recording: hardcoded secrets, no error handling, deprecated
calls, missing cleanup, "we'll fix this later" that never arrives.

Deliver the improved version, and be explicit about where it differs from the
video — someone comparing your result against the screen must not be confused by
silent changes. Separate real defects from taste.

## Cost

A long video is a large number of frames, so this is a real API call rather than
a free one. Scale the model and the `--focus` to the question being asked.
