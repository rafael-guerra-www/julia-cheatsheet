# Julia Code Organization — Technical Cheat Sheet

## 0. How Julia finds code — load path resolution

When `using` a package, the active environment's `LOAD_PATH` stack is searched for it, and the exact version is read from `Manifest.toml` (`Project.toml` lists the direct dependencies), and the code is loaded from the depot.
The registry takes no part in loading: it is only consulted by Pkg operations (add, up) to decide which versions to install. Loading and installing are two different flows:

**Load:**&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;LOAD_PATH stack → Project.toml + Manifest.toml → Depot

**Install:**&nbsp;&nbsp;&nbsp;Registry (name + UUID → versions) → Depot

&nbsp;
### Julia process example

```bash
julia --project=@. app.jl      # '--project' sets the active environment
```

### LOAD_PATH default stack

&emsp;**1.** Active environment (`@`)&emsp;&emsp;**2.** `@v#.#`&emsp;&emsp;**3.** `@stdlib`

&nbsp;

The first match wins. Packages in `@v#.#` are visible to scripts and the REPL, but a package's own dependencies always resolve through its own Manifest.

&nbsp;

**Beware of `JULIA_LOAD_PATH`**: setting this env var replaces the managed loading path (`@`, `@v#.#`, `@stdlib`) — scripts may miss the active environment or `@stdlib`. Reserve it for specialist setups (CI, isolated tests).

**`@v#.#`** names the default env, one per Julia minor version (e.g. `v1.11`).
Installing everything there is the classic novice mistake: expect version conflicts, long precompile times and a slow-loading REPL.

### Project and Manifest

- `Project.toml` declares dependencies. `Manifest.toml` pins the resolved dependency graph.
- Versioned names (`Manifest-v1.11.toml`) are preferred automatically since 1.10.8; `JuliaProject.toml` is also recognized.

An **environment** is a folder with a Project.toml (Manifest optional). A global (`@v#.#`) tool environment stays visible everywhere without being a dependency. Activation examples:

```julia
Pkg.activate(path)                    # explicit path
Pkg.activate("Name"; shared=true)     # named shared env (~/.julia/environments/)
Pkg.activate(temp=true)               # temporary environment
```

### Depot

- Controlled by `JULIA_DEPOT_PATH` (a stack; set before launch). Default location: `~/.julia/`
- Contains: packages, registries, environments, artifacts, compiled caches, logs, scratch spaces
- Also holds `config/startup.jl`, run at every Julia start: keep it minimal — a `cd()` or package loading there affects every script & tool (bypass with `julia --startup-file=no`).

### Registry

Registries can be public (General) or private. Maps: name + UUID → repository, versions

---

## 1. Editor and VS Code workspace

- A `.code-workspace` file (multi-root) groups folders and editor settings, including:

  - Formatting, linting, tasks, debugging

<!-- variant:ls -->
- **IDE support**: LanguageServer.jl — classic LSP, robust, works on all editors (VS Code, Neovim, Emacs, Sublime); the VS Code extension detects the nearest `Project.toml` by searching upward.
<!-- variant:end -->
<!-- variant:jetls -->
- **IDE support**: JETLS.jl (JET team) — static analysis based on the compiler: typed diagnostics, macro-aware navigation; requires Julia 1.12.2–1.14 and an instantiated environment; installed as standalone executable (`Pkg.Apps.add`, then `jetls` in `~/.julia/bin`; re-run after a Julia upgrade); native in Zed, `jetls-client` extension for VS Code.
<!-- variant:end -->

- `julia.environmentPath` pins the environment per folder when auto detection chooses the wrong one.

- Completions, hover documentation and go-to-definition reflect the active environment's `Manifest.toml`, not the workspace itself.

### Key points

The IDE never resolves dependencies. Fix the environment, not the editor. A wrong or inactive environment can cause: Missing completions; False "missing reference" diagnostics.

&nbsp;

**Tips:**

- Use one workspace and one environment per project folder.
- `launch.json` and tasks can pass `--project`.

Other editors all speak the same Language Server Protocol (LSP):

- Emacs: `lsp-julia` / eglot (REPL support: `julia-snail`)
- Neovim: built-in `vim.lsp.config` (≥ 0.11)

---

## 2. Project vs Package — the key distinction

Both have a `Project.toml`, and can have a `Manifest.toml`. What differs is their purpose and structure.

### Project (application / environment)

- Defines the dependency context for running scripts and applications.
- No package identity (name and uuid) is needed for an ordinary application environment.
- No src/ layout or package module is required. Cannot be registered or depended on by others. Run it with:

  ```bash
  julia --project=. run.jl
  ```
  In-script: `Pkg.activate(@__DIR__)`; `@main` (≥ 1.11) opts in to a Main.main(args) entry point.

### Package

- A project with a name + UUID and a `src/MyPkg.jl` file defining the module named after the package.
- Loadable with `using MyPkg`. Versioned, registrable and testable.
- Can be a dependency of other projects and packages.
- Develop against a consumer environment, not inside the package:

  ```julia
  ] dev ./MyPkg     # in the app env: track local files
  ] test            # inside the package: run its own tests, isolated
  ```

**Every package is a project; not every project is a package.**

---

## 3. Module system — language level

```julia
module MyPkg                   # Example module
using JSON                     # brings exported names in
import JSON                    # module name only: JSON.write
import JSON: write             # specific binding
export myfunc                  # makes myfunc available to callers without prefix
include("helpers.jl")          # loads the file into this module
using .Helpers                 # dot = module in scope, not a path
myfunc(x) = ...
function __init__() ... end    # runs at each load, not during precompilation
end
```

### Important points

- Modules are namespaces controlling name resolution, not dependencies or disk layout.
- A package must expose a top-level module named like the package.
- Scripts and applications do not need a module.
- Submodules organize large packages: `module Internals ... end` inside the main module.
- Load `using Revise` before `using MyPkg` to edit in place; it tracks code edits including structs (Julia ≥ 1.12), but not Project.toml changes — restart and `] resolve` after adding deps.

---

## 4. Public vs private registries

Julia packages and registries — both public and private — make code reusable, reproducible, and manageable across projects and teams.

&nbsp;

### General registry (public)

- Default registry, served from `pkg.julialang.org`.
- Maps name + UUID to Git repository and registered versions.
- Registration via Registrator (bot); RegistryCI enforces General's checks on the PR.

&nbsp;

### Private registries

- Used for internal packages.
- A registry is maintained as a Git repository.
- Create and maintain one with LocalRegistry.jl; serve it via LocalPackageServer or a private Pkg server.
- On the client side: `] registry add MyRegistry https://...` makes its packages resolvable everywhere — they install like General packages.

&nbsp;

Pkg can combine information from multiple registries.
Versions registered in different registries are considered together during dependency resolution.

---

## 5. Package anatomy

```text
MyPkg/                 # Typical package structure:
├── Project.toml       # name, uuid, deps, compat
├── Manifest.toml      # resolved lockfile (generated)
├── src/MyPkg.jl       # main module, name = package
├── test/runtests.jl   # Pkg.test() entry point
├── examples/          # optional usage examples and data
├── docs/make.jl       # Documenter.jl
└── ext/               # extensions via [weakdeps] (≥ 1.9)
```

- `Project.toml`: hand-edited intent. `Manifest.toml`: generated state.
- The main module must be named MyPkg in src/MyPkg.jl.
- The name + uuid in Project.toml are the package's identity: assigned once.
- [compat] bounds are required for every dependency and for julia itself — the General registry rejects registration otherwise.
- Test dependencies: `test/Project.toml` (current) or [extras] + [targets] (legacy), without polluting [deps].
- Apps commit their Manifest (exact reproducibility); packages usually don't — the registry decides resolution.
- An extension pairs a [weakdeps] entry with an [extensions] entry: `ext/MyPkgFooExt.jl`.
- Extensions load only when the triggering package is present.

---

## 6. Command cheat sheet

### Shell

```bash
julia script.jl               # runs in whatever environment is active
julia --project=. run.jl      # use the project in the current directory
julia --project=@script s.jl  # env next to the script (Julia ≥ 1.11)
JULIA_DEPOT_PATH=... julia    # CI / relocatable depot
```

### Pkg REPL

Enter Pkg mode by pressing **`]`**

```julia
activate .              # set folder as the active environment
activate --shared dev   # named shared environment
activate --temp         # throwaway environment for an experiment
add Plots@1.40          # install; spec [1.40, 2.0) — not a pin
pin Plots               # pin the installed version: never auto-update
dev ./MyPkg             # link env to local folder (edits take effect immediately); never `add` MyPkg
free MyPkg              # undo pin / dev, back to normal
instantiate             # install everything recorded in Manifest.toml
up                      # upgrade packages to latest allowed versions
resolve                 # update Manifest for a modified Project.toml
test                    # run the tests in an isolated process, no REPL restart
precompile              # precompile the active environment
status                  # show the environment's contents
```

---

## 7. Distinctions people get wrong

- **Workspace (editor)** groups folders and settings; it never resolves dependencies.
- **Pkg Workspace** (v1.12+): multiple related projects under a root Project.toml, sharing one Manifest. Not the same as an editor workspace.
- **Environment** = which package versions are available.
- **Project** = the directory holding that context.
- **Package** = project + name + UUID + main module named after the package.
- **Module** = namespace, inside or outside packages.
- Run scripts from a separate dev/scratch environment, never from the package's own environment: `add` there writes hard dependencies into its Project.toml, which breaks weak dependencies (extensions).
- One depot serves many environments. One environment can `dev` many packages.
- Registries only index; the depot stores.

&nbsp;
### Overall picture

The workspace is **not a folder hierarchy**: it may hold several environments, packages, applications and scripts. The resolution flow is: &nbsp;&nbsp;&nbsp;LOAD_PATH → Project.toml → Manifest.toml → Depot
