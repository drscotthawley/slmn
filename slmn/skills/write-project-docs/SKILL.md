---
name: write-project-docs
description: Document an nbdev project -- add section-heading notes per notebook, tidy the index/README, and (optionally) wire up an llms.txt file for its GitHub Pages docs site. Use when asked to "document this project," "add doc notes to these notebooks," or "add llms.txt" for an nbdev-based repo.
---

# Write project docs

Two parts: (1) documenting the notebooks themselves, and (2) optionally publishing an
`llms.txt` on the project's docs site. Part 1 is the common case; part 2 is a one-time setup
you'll rarely repeat per-project.

## Part 1: documenting notebooks

If `slmn` is importable in this environment, prefer its tools over hand-editing notebook
JSON:

- `slmn.nbtools.write_nb_docs(path, notes=[[after_id, source], ...], patches=[[cell_id, new_source], ...])`
  for one notebook.
- `slmn.nbtools.write_project_docs(specs, llms_txt=None)` for several notebooks at once --
  `specs` is `{notebook_path: {'notes': ..., 'patches': ...}}`. It validates every cell id in
  every notebook *before* writing any of them, so a bad id can't leave some notebooks
  half-edited.

Both take two kinds of edit -- **notes** (new markdown cells, purely additive) and
**patches** (replace an existing cell's source outright). Deciding which one to use for a
given cell is the part that needs judgment, not a fixed rule:

### Preserve vs. overwrite

**Default to `notes`.** Adding a heading/summary next to existing content is always safe --
worst case it's slightly redundant, and that's trivial to fix later. Reach for `patches`
only when you're confident the existing cell is disposable.

A cell is disposable if it's near-verbatim **nbdev/quarto scaffolding** -- the same
boilerplate every fresh `nbdev_new`-generated project ships with, not anything a human wrote
for *this* project. Known examples to check the exact wording of before treating something
new as boilerplate (the wording can drift between nbdev versions):

- "This file will become your README and also the index of your documentation."
- The whole `## Developer Guide` section ("If you are new to using `nbdev` here are some
  useful pointers to get you started.", "### Install \<pkg\> in Development mode", the
  `pip install -e .` / `nbdev_prepare` code block).
- `## Usage` / `### Installation` boilerplate with unfilled conda/PyPI placeholders (`pip
  install git+https://github.com/...`, `conda install -c ...`, `pip install ...`) when the
  package in fact isn't published to conda/PyPI yet -- these aren't just generic, they're
  actively wrong.
- `### Documentation` boilerplate pointing at `[docs]`/`[repo]`/`[pypi]`/`[conda]` link
  placeholders with no project-specific content.

Anything else -- a paragraph explaining *why* a module exists, a design note, a warning
about a gotcha, prose that reads like it took someone real time to write -- **leave alone**,
even if it's short, informal, or you think you could phrase it better. If you have something
useful to add about a cell like that, add it as an adjacent note, never as a replacement.
When genuinely unsure whether something is boilerplate or hard-won prose, treat it as the
latter: preserve and append.

### The safety net

This work happens on a feature branch, goes through `publish`'s status-review gate, and
lands as a reviewable PR diff before merging (see slmn's own dev workflow) -- so a
questionable `patches` call isn't unrecoverable, it's a diff hunk the human can reject. That
said, don't rely on the diff to catch everything: when you do overwrite something that isn't
on the boilerplate list above, say so explicitly in your summary or the commit/PR body (e.g.
"rewrote cell X -- looked like stale scaffolding, please check"), so review effort goes where
the judgment call actually happened instead of a blind full-diff read.

## Part 2: llms.txt (one-time per project)

[llms.txt](https://llmstxt.org) is a project-summary file for LLMs, published alongside the
docs site. Wiring it into an nbdev project's GitHub Pages build needs three build-config
edits (none of them notebook cells) plus the file itself:

1. **pyproject.toml**: add `pysym2md` and `llms-txt` (pip package; ships the `llms_txt2ctx`
   command) to the `dev` extra -- not a new extra of their own. Both of nbdev's reusable
   GitHub Actions (`nbdev3-ci` for tests, `quarto-ghp3` for the Pages deploy) hardcode
   `pip install -e ".[dev]"`, so anything the docs *build* needs must live in `dev`.

2. **nbs/_quarto.yml**, under `project:`:
   ```yaml
   pre-render:
     - pysym2md --output_file apilist.txt <pkg>      # <pkg> = the import name
   post-render:
     - llms_txt2ctx llms.txt --optional true --save_nbdev_fname llms-ctx-full.txt
     - llms_txt2ctx llms.txt --save_nbdev_fname llms-ctx.txt
   resources:
     - "*.txt"
   ```

3. **.gitignore**: add `nbs/apilist.txt` and `nbs/llms-ctx*.txt` (regenerated every build;
   the `llms-ctx*.txt` files actually land in nbdev's `_proc/` dir, usually already ignored
   -- add the `nbs/` patterns anyway since `apilist.txt` lands next to `llms.txt`).

4. **nbs/llms.txt** itself: H1 title, `>` blockquote summary, a detail paragraph or two, then
   `##`-headed link sections (`[name](url): description`) pointing at the site's published
   `*.html.md` doc pages, and an `## Optional` section linking `apilist.txt` (included only
   when a context-builder asks for the fuller `llms-ctx-full.txt`).

### Gotchas (learned building this for slmn, 2026-07-20)

- `llms_txt2ctx` **downloads every linked URL** and inlines it -- links must point at the
  already-published site, not local files.
- On the very first deploy after wiring this up, `apilist.txt` isn't live yet, so that one
  build's `llms-ctx-full.txt` embeds GitHub's 404 page for the Optional-section link. It
  self-heals on the next deploy once `apilist.txt` exists. `llms-ctx.txt` (no `--optional`)
  is unaffected since it doesn't reference `apilist.txt`.
- `pysym2md <pkg>` pulls every symbol's signature and docstring straight from the installed
  package -- another reason real docstrings matter (see Part 1's judgment above: a good
  docstring is exactly the kind of content to never overwrite carelessly).

If `slmn` is available, `write_project_docs(..., llms_txt={'nbs/llms.txt': source})` will
write the `llms.txt` content for you; the three config edits above still need to be done by
hand (or with a plain file edit), once per project.
