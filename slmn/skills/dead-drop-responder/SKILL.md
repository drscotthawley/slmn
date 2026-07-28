---
name: dead-drop-responder
description: Act as the responding LLM for slmn's file-based dead drop -- the channel boopiter's 'deaddrop/claude' model speaks. Use when asked to "watch the dead drop," "start the claude watch," "answer dead-drop prompts," or to be the model behind a deaddrop/* entry in boopiter's model menu.
---

# Dead-drop responder

You are the model on the far side of a file-based prompt/response exchange
(see `slmn.dead_drop`). A producer -- typically a boopiter notebook with the
`deaddrop/claude` model selected -- drops each prompt as a file in
`~/dead_drop/prompts/`; you answer by writing `~/dead_drop/responses/<same-name>`.

## The loop

1. **Arm the watch** (run as a background command; its exit is your wake-up call):

       slmn watch_prompts

   It blocks until a prompt lands, prints it as one JSON line
   (`{"name": ..., "content": ...}`), consumes the prompt file, and exits.

2. **When it fires**: read the JSON from the task output. Compose your reply to
   `content` (it is the notebook's full visible context; the `[system: ...]`
   trailer about `---MODEL:` is instructions for you, not part of the question).

3. **Reply** (body via stdin spares shell-quoting; `name` is from step 1's JSON):

       slmn respond_prompt <name> --model "<your model name and version>" <<'EOF'
       ...your reply in markdown...
       EOF

   `respond_prompt` appends the `---MODEL: ...---` line and `---DONE---`
   terminator itself -- do not include them in the body.

4. **Re-arm** (`slmn watch_prompts` again, in the background) so the next prompt
   is caught. Repeat until told to stop.

## Rules that keep it friction-free

- **Run every `slmn` command ALONE in its shell call.** Permission allowlists
  match the whole command line: `slmn ... && git status`, a `(cd ...)` subshell,
  or any appended command breaks the match and triggers a permission prompt.
- Don't poll for the watch result -- the background task's exit notifies you.
- If a prompt references images as `![...](/boopimg/<hex>.png)`, only the tag
  reaches you as text. If you are on the producer's machine, the file lives at
  `<boopiter-launch-dir>/.boopiter/images/<hex>.png` -- read it and answer about
  the actual image; otherwise say you received only the reference.
- One response file per prompt name, exactly. If the same context arrives twice
  under two names (e.g. the user double-ran the cell), answer each name -- the
  notebook only follows the newest.

## Session routes (inbox/outbox)

Producers can also address a named session (`deaddrop/<session-id>` in boopiter)
via `drop_prompt`/`follow_reply`. The CLI tools above only cover the legacy
`prompts/`+`responses/` route; for sessions, use `slmn.dead_drop.await_prompt` /
`reply_stream` from Python.
