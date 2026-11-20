# Julia Code Organization — Technical Cheat Sheet
*From process startup to code loading: editor, environments, projects, packages, modules, registries and the depot.*

## 0. How Julia finds code — load path resolution

The resolution pipeline:

```text
Julia process  →  LOAD_PATH stack  →  Project.toml + Manifest.toml  →  Depot  →  Registry
```

### Julia process

Example:

```bash
julia --project=@. app.jl
```

`--project` sets the active environment.

### LOAD_PATH environment stack

The default stack:

1. Active environment (`@`)
2. `@v#.#`
3. `@stdlib`

The first match wins. The stack can be overridden using `JULIA_LOAD_PATH`.

`@v#.#` names the default env, one per Julia minor version (e.g. `v1.11`).
Installing everything there is the classic novice mistake: expect version conflicts.

### Project and Manifest

- `Project.toml` declares dependencies.
- `Manifest.toml` pins the resolved dependency graph.

An **environment** is a folder with a Project.toml (Manifest optional).


Activation examples:

```julia
Pkg.activate(path)
Pkg.activate("Name")       # named environment
Pkg.activate(temp=true)    # temporary environment
```

A global (`@v#.#`) tool environment stays visible everywhere without being a dependency.

### Depot

- Controlled by `JULIA_DEPOT_PATH`
- Default location:  ~/.julia/
- Contains: Packages, Development packages (`dev`), Environments, Artifacts

### Registry

Maps: name + UUID → repository, versions

Registries can be public (General) or private.

---

## 1. Editor and VS Code workspace

- A `.code-workspace` file (multi-root) groups folders and editor settings, including:

  - Formatting, linting, tasks, debugging

- The Julia extension runs `LanguageServer.jl` per folder. It automatically detects the nearest `Project.toml` by searching upward.

- `julia.environmentPath` pins the environment per folder when automatic detection chooses the wrong one.

- Completions, hover documentation and go-to-definition reflect the active environment's `Manifest.toml`, not the workspace itself.
&nbsp;
### Key points

The IDE never resolves dependencies. A wrong or inactive environment can cause:
- Missing completions
- False "missing reference" diagnostics

Fix the environment, not the editor.

**Tips:**

- Use one workspace and one environment per project folder.
- `launch.json` and tasks can pass `--project`.

Other editors, all speak the same LanguageServer protocol:

- Emacs: `julia-snail` / `lsp-julia`
- Vim: `nvim-lsp`

---

## 2. Project vs Package — the key distinction

Both have a `Project.toml`, and can have a `Manifest.toml`. What differs is their purpose and structure.

### Project (application / environment)

- Defines the dependency context for running scripts and applications.
- No package identity (name and uuid) is needed for an ordinary application environment.
- No src/ layout or package module is required.
- Run with:

  ```bash
  julia --project=. run.jl
  ```

- Cannot be registered or depended on by others.

### Package

- A project with a UUID and a `src/MyPkg.jl` file defining the module named after the package.
- Loadable with `using MyPkg`.
- Versioned, registrable and testable.
- Can be a dependency of other projects and packages.
- Develop in place with; and test with:

  ```julia
  ] dev ./MyPkg
  ] test
  ```

**Every package is a project; not every project is a package.**

---

## 3. Module system — language level

Example module:

```julia
module MyPkg
using JSON                      # brings exported names in
import JSON                     # module name only: JSON.write
import JSON: write              # specific binding
export myfunc
include("helpers.jl")           # textual load into this module
myfunc(x) = ...
function __init__() ... end     # runs once, at first load
end
```

### Important points

- Modules are namespaces: they control name resolution, not dependencies or disk layout.
- A package must expose a top-level module named like the package.
- Scripts and applications do not need a module.
- Modules outside packages are loaded with relative paths: `using .Helpers` (note leading dot)
- Submodules organize large packages: `module Internals ... end` inside the main module.
---

## 4. Public vs private registries

Julia packages and registries — both public and private — make code reusable, reproducible, and manageable across projects and teams

### General registry (public)

- Default registry, served from `pkg.julialang.org`.
- Maps name + UUID to Git repository and registered versions.
- Public registration via Registrator / RegistryCI.

&nbsp;

### Private registries

- Used for internal packages.
- A registry is maintained as a Git repository.
- It can optionally be served through a private package server.

&nbsp;

Pkg can combine information from multiple registries.
Versions registered in different registries are considered together during dependency resolution.

---

## 5. Package anatomy

Typical package structure:

```text
MyPkg/
├── Project.toml       # name, uuid, deps, compat
├── Manifest.toml      # resolved lockfile (generated)
├── src/MyPkg.jl       # main module, name = package
├── src/__init__.jl    # runs on first using
├── test/runtests.jl   # Pkg.test() entry point
├── docs/make.jl       # Documenter.jl
└── ext/               # extensions via [weakdeps] (≥ 1.9)
```

- `Project.toml`: hand-edited intent.
- `Manifest.toml`: generated state.
- The main module must be named MyPkg in src/MyPkg.jl.
- The uuid in Project.toml is the package's unique identity: assigned once.
- [compat] records version bounds; missing it, the General registry rejects registration.
- [extras] + [targets] declare test-only dependencies (e.g. Test) without adding them to [deps].
- A package's Manifest.toml is usually not committed: the registry decides resolution.
- Extensions in ext/ must be declared in [weakdeps], e.g. MyPkgX.jl.
- Extensions are loaded only when the triggering package is present.

---

## 6. Command cheat sheet

### Shell

```bash
julia --project=. run.jl       # run in this environment
julia --project=@. -t auto     # nearest environment upward
JULIA_DEPOT_PATH=... julia     # CI / relocatable depot
```

### Pkg REPL

Enter Pkg mode by pressing `]`.

```julia
activate .              # set folder as the active environment
activate --shared dev   # named shared environment
activate --temp         # throwaway environment for an experiment
add Plots@1.40          # install from the registry, pin the version
dev ./MyPkg             # install a working copy of another package
free MyPkg              # undo pin / dev, back to normal
instantiate             # install everything recorded in Manifest.toml
up                      # upgrade packages to latest allowed versions
resolve                 # update Manifest for a modified Project.toml
test                    # run the tests of the active env's packages
precompile              # precompile the active environment
status                  # show the environment's contents
build MyPkg             # re-run a package's build step
```

---

## 7. Distinctions people get wrong

- **Workspace (editor)** groups folders and settings; it never resolves dependencies.
- **Pkg Workspace** (v1.12+): multiple related projects under a root Project.toml, sharing one Manifest. Not the same as an editor workspace.
- **Environment** = which package versions are available.
- **Project** = the directory holding that context.
- **Package** = project + UUID + main module.
- **Module** = namespace, inside or outside packages.
- One depot serves many environments.
- One environment can `dev` many packages.
- Registries only index; the depot stores.

### Overall picture

This is **not a folder hierarchy**.

A workspace may hold several environments, packages, applications and scripts. The resolution flow is:

```text
LOAD_PATH → Project.toml → Manifest.toml → Depot
```
