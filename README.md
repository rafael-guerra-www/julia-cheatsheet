# Julia Code Organization Cheat Sheet

One-page A3 cheat sheet covering how Julia finds and loads code:
load-path resolution, environments, Project vs Package, the module system,
registries, package anatomy, and the Pkg REPL.

## Files

* `Julia_Code_Organization_Cheat_Sheet.md` — the single source of truth
* `generate.jl` — renders it to a one-page PDF (needs Julia + a Chromium-based browser)
* `cheatsheet.pdf` — not in the repo: regenerate it with `julia generate.jl`

## How to run

Requirements:

* [Julia](https://julialang.org/downloads/) 1.9 or later (uses the `Markdown` standard library, no packages to install)
* A Chromium-based browser: Chrome, Edge, or Chromium. Auto-detected on Windows
  (Chrome/Edge) and Linux/macOS (Chrome/Chromium/Edge via `PATH`). Without one,
  the script still writes `cheatsheet.html` and opens it in your default browser.

Usage, from the repo root:

```bash
julia generate.jl                      # uses Julia_Code_Organization_Cheat_Sheet.md
julia generate.jl my_sheet.md         # render any other Markdown file
```

What it does:

1. Parses the Markdown with Julia's built-in `Markdown` module.
2. Wraps each `##` section in a styled, colored panel on a 2-column A3 grid.
3. Tries font sizes from 8.0pt down to 6.0pt and keeps the largest one that fits on a single page.
4. Prints the PDF via the headless browser, writing `cheatsheet.pdf`.

Outputs (written next to the input file, both git-ignored):

* `cheatsheet.pdf` — the one-page A3 portrait PDF
* `cheatsheet.html` — the intermediate HTML page, useful for quick preview in a browser

To adapt the sheet, edit the `.md` file and re-run the script; the layout
auto-fits the new content.

## Feedback

Corrections and suggestions welcome via [issues](https://github.com/rafael-guerra-www/julia-cheatsheet/issues).

## License

MIT

## Acknowledgments

This cheat sheet and its generation tooling (`generate.jl`, the Markdown
source, the release workflow) were developed with the assistance of
Mistral AI (Vibe, formerly Le Chat).

All technical content was reviewed and validated by the author, and
corrections from the community are incorporated through the
[issue tracker](https://github.com/rafael-guerra-www/julia-cheatsheet/issues).
