---
name: write-project-docs
description: Document an nbdev project -- add section-heading notes per notebook, tidy the index/README, optionally wire up an llms.txt file, and optionally give the GitHub Pages docs site a dark theme with a light/dark toggle. Use when asked to "document this project," "add doc notes to these notebooks," "add llms.txt," or "make the docs dark / add a theme toggle" for an nbdev-based repo.
---

# Write project docs

Three parts: (1) documenting the notebooks themselves, (2) optionally publishing an
`llms.txt` on the project's docs site, and (3) optionally theming that docs site dark with a
light/dark toggle. Part 1 is the common case; parts 2 and 3 are one-time setups you'll rarely
repeat per-project.

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

## Part 3: dark theme + light/dark toggle (one-time per project)

Turns the stock cosmo (light) docs site into a dark site that **defaults to dark** and has a
sun/moon toggle to flip to a plain-cosmo light mode. All edits are build config in `nbs/` --
no notebook cells. Iterate by running `nbdev-docs` and opening `_docs/` locally.

Two new files, then edits to `_quarto.yml` and `styles.css`.

**1. `nbs/darktheme.scss`** -- the palette (DaisyUI v5 "dark" tokens, oklch converted to hex
because Sass color math can't operate on `oklch()`). Layered on cosmo as the `dark` theme:

```scss
/*-- scss:defaults --*/
$body-bg:    #1d232a;   // page background
$body-color: #ecf9ff;   // foreground text
$primary:    #605dff;   // links / active accents
$dark:       #191e24;   // navbar + chrome that echoes it
$code-color: #bd93f9;   // inline `backtick` code (dracula purple)
$code-block-bg: #282a36; // fenced code blocks -- dracula's own bg. REQUIRED: with a
                         // light/dark theme pair, Quarto's per-mode highlight CSS carries
                         // only token colors, so the dark block *background* must come from
                         // the theme, or bright dracula tokens strand on cosmo's light block.
/*-- scss:rules --*/
```

**2. `nbs/theme-toggle.html`** -- an after-body script that swaps Quarto's built-in toggle
glyph for sun/moon SVGs. It reuses Quarto's own toggle `<a>`, so all the theme-switching +
localStorage persistence keeps working; only the icon changes. Quarto adds `.alternate` to
the toggle in dark mode, which `styles.css` keys off to show moon (dark) vs sun (light):

```html
<script>
(function () {
  var SUN = '<svg class="boop-sun" xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24"><path d="M5.64,17l-.71.71a1,1,0,0,0,0,1.41,1,1,0,0,0,1.41,0l.71-.71A1,1,0,0,0,5.64,17ZM5,12a1,1,0,0,0-1-1H3a1,1,0,0,0,0,2H4A1,1,0,0,0,5,12Zm7-7a1,1,0,0,0,1-1V3a1,1,0,0,0-2,0V4A1,1,0,0,0,12,5ZM5.64,7.05a1,1,0,0,0,.7.29,1,1,0,0,0,.71-.29,1,1,0,0,0,0-1.41l-.71-.71A1,1,0,0,0,4.93,6.34Zm12,.29a1,1,0,0,0,.7-.29l.71-.71a1,1,0,1,0-1.41-1.41L17,5.64a1,1,0,0,0,0,1.41A1,1,0,0,0,17.66,7.34ZM21,11H20a1,1,0,0,0,0,2h1a1,1,0,0,0,0-2Zm-9,8a1,1,0,0,0-1,1v1a1,1,0,0,0,2,0V20A1,1,0,0,0,12,19ZM18.36,17A1,1,0,0,0,17,18.36l.71.71a1,1,0,0,0,1.41,0,1,1,0,0,0,0-1.41ZM12,6.5A5.5,5.5,0,1,0,17.5,12,5.51,5.51,0,0,0,12,6.5Zm0,9A3.5,3.5,0,1,1,15.5,12,3.5,3.5,0,0,1,12,15.5Z"/></svg>';
  var MOON = '<svg class="boop-moon" xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24"><path d="M21.64,13a1,1,0,0,0-1.05-.14,8.05,8.05,0,0,1-3.37.73A8.15,8.15,0,0,1,9.08,5.49a8.59,8.59,0,0,1,.25-2A1,1,0,0,0,8,2.36,10.14,10.14,0,1,0,22,14.05,1,1,0,0,0,21.64,13Zm-9.5,6.69A8.14,8.14,0,0,1,7.08,5.22v.27A10.15,10.15,0,0,0,17.22,15.63a9.79,9.79,0,0,0,2.1-.22A8.11,8.11,0,0,1,12.14,19.73Z"/></svg>';
  function boopify() {
    document.querySelectorAll('.quarto-color-scheme-toggle').forEach(function (t) {
      if (t.dataset.boopified) return;
      t.dataset.boopified = '1';
      t.innerHTML = SUN + MOON;
    });
  }
  boopify();
  document.addEventListener('DOMContentLoaded', boopify);
})();
</script>
```

**3. `nbs/_quarto.yml`**, `format.html` -- replace `theme: cosmo` with a light/dark pair and
wire in the highlight split + toggle include; and set the navbar to `dark`:

```yaml
format:
  html:
    theme:
      dark: [cosmo, darktheme.scss]   # dark listed FIRST -> it's the default (see gotchas)
      light: cosmo
    highlight-style:
      light: arrow
      dark: dracula
    css: styles.css
    include-after-body: theme-toggle.html
# ... under website.navbar:
#     background: dark                 # was `primary`
```

**4. `nbs/styles.css`** -- add the dark-mode code-output color and the toggle-icon CSS:

```css
/* Plain code output (stdout/stderr/text reprs) has no highlight spans, so it inherits
   near-black text -- invisible on the dark page. DARK mode only; light keeps cosmo defaults.
   Quarto puts .quarto-dark on <body>. Excludes .sourceCode so highlighted output keeps tokens. */
.quarto-dark .cell-output-stdout > pre, .quarto-dark .cell-output-stderr > pre,
.quarto-dark .cell-output-display pre:not(.sourceCode) { color: #c7ccd1; }

/* Sun/moon toggle: theme-toggle.html injects both SVGs into Quarto's own toggle. */
.quarto-color-scheme-toggle .bi { display: none; }
.quarto-color-scheme-toggle svg {
  width: 1.5rem; height: 1.5rem;   /* ~1.3x the default, to match the other navbar icons */
  fill: currentColor;
  vertical-align: -0.24em;
  position: relative; top: 2px;    /* line up with the search magnifier */
}
.quarto-color-scheme-toggle .boop-moon { display: none; }
.quarto-color-scheme-toggle.alternate .boop-sun { display: none; }
.quarto-color-scheme-toggle.alternate .boop-moon { display: inline-block; }
```

### Gotchas (learned building this for boopiter + slmn, 2026-07-20)

- **Default dark comes from theme *order*** -- list `dark:` before `light:` and Quarto sets
  `authorPrefersDark=true`. Nothing else in the yaml selects the default.
- **Everything dark-specific lives in the dark theme, so light mode reverts for free.**
  `$code-color`, `$code-block-bg`, and the `.quarto-dark`-scoped output color only apply in
  dark mode; flipping to light drops them and you get plain cosmo. Don't hardcode a light-grey
  output color unscoped, or it'll be invisible on the light page.
- **`highlight-style` as a `{light, dark}` map** makes Quarto emit two highlight stylesheets
  (`quarto-syntax-highlighting[-dark].css`) and swap them with the theme. Those carry token
  *colors* only -- the code-block background is the `$code-block-bg` above, which is why it's
  required for dracula to look right in dark.
- The toggle button and its persistence are entirely Quarto's; `theme-toggle.html` only
  rewrites the icon. The `boop-*` class names are just internal identifiers -- harmless to
  keep verbatim.

### Optional add-on: color-code cells by type

If the project renders distinct cell *types* worth signaling (e.g. boopiter's note/prompt/
raw/code), add a left-border color bar per type with an nbdev **doc processor** -- the
supported way to touch cells before Quarto renders, no fork:

1. A module in the package (via a notebook, e.g. `nbs/NN_docsprocs.ipynb` -> `pkg/docsprocs.py`)
   with `color_cells(cell)` that wraps each markdown/raw cell's source in a Quarto fenced div
   `::: {.cellclass .type-class}` chosen by `cell.cell_type` (and any in-source marker); it
   skips the H1 title cell and leaves code cells to CSS (`.cell-code`).
2. Register it in `pyproject.toml [tool.nbdev]`: `doc_procs = ["pkg.docsprocs:color_cells"]`.
   **`import_obj` splits on a COLON (`module:obj`), not a dot** -- a dotted path fails the
   build with "not enough values to unpack."
3. CSS in `styles.css`: `.type-class { border-left: 4px solid <hex>; padding-left: .75rem; }`
   per type; code via `div.sourceCode.cell-code { border-left: ... }`.

This is opt-in and project-specific -- most nbdev projects want Part 3's theme without it.
