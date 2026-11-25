# generate.jl — Markdown -> styled HTML -> one-page A3 portrait PDF
# Usage:  julia generate.jl [input.md]
# Developed with assistance from Mistral AI (Vibe)

using Markdown
using Dates
using TOML

const SCRIPT_DIR = @__DIR__
const INPUT = length(ARGS) >= 1 ? abspath(ARGS[1]) : joinpath(SCRIPT_DIR, "Julia_Code_Organization_Cheat_Sheet.md")
const OUT_DIR = dirname(abspath(INPUT))
const OPTIONS_FILE = joinpath(SCRIPT_DIR, "options.toml")
const VERSION_TAG = "v1.5"          # bump this on each release

const VARIANT_RE = r"<!--\s*variant:(\w+)\s*-->([\s\S]*?)<!--\s*variant:end\s*-->"

"""Keep only the `<!-- variant:NAME -->` blocks whose NAME == keep."""
function select_variants(md::String, keep::String)
    buf = IOBuffer()
    pos = 1
    n = lastindex(md)
    for m in eachmatch(VARIANT_RE, md)
        write(buf, md[pos:m.offset-1])
        if m.captures[1] == keep
            body = replace(m.captures[2], r"\A\r?\n" => "")
            body = replace(body, r"\r?\n\z" => "")
            write(buf, body, "\n")
        end
        pos = m.offset + sizeof(m.match)
    end
    pos <= n && write(buf, md[pos:end])
    return String(take!(buf))
end

function css(root_pt)
    """
    @page  { size: A3 portrait; margin: 6mm 16mm 5mm; }
    *      { box-sizing: border-box; }
    html   { font-size: $(root_pt)pt; }
    body   { display: grid; grid-template-columns: 1fr 1fr;
             align-items: start; gap: 1.4rem;
             padding-bottom: 6mm;
             font: 1rem/1.35 "Inter","Segoe UI",Arial,sans-serif; color: #1e293b; }
    h1     { grid-column: 1 / -1; font-size: 1.9rem; line-height: 1.1;
             text-align: center; margin: 0; color: #0f172a; }

    .panel:nth-of-type(1) { grid-column: 1 / -1; columns: 2; column-gap: 1.4rem; }
    .panel:nth-of-type(8) { grid-column: 1 / -1; columns: 2; column-gap: 1.4rem; }

    .panel { border: 1.5px solid #94a3b8; border-radius: 8px;
             padding: 1.1rem; break-inside: avoid; background: #f8fafc; }
    .panel:nth-of-type(1) { background: #eef2ff; border-color: #818cf8; }
    .panel:nth-of-type(2) { background: #fdf4ff; border-color: #f0abfc; }
    .panel:nth-of-type(3) { background: #faf5ff; border-color: #c084fc; }
    .panel:nth-of-type(4) { background: #fdf2f8; border-color: #f9a8d4; }
    .panel:nth-of-type(5) { background: #f0fdf4; border-color: #86efac; }
    .panel:nth-of-type(6) { background: #eff6ff; border-color: #93c5fd; }
    .panel:nth-of-type(7) { background: #fffbeb; border-color: #fbbf24; }
    .panel:nth-of-type(8) { background: #ffffff; border-color: #cbd5e1; }

    .panel h2 { margin-top: 0; font-size: 1.22rem; color: #3730a3; }
    .panel:nth-of-type(2) h2 { color: #86198f; }
    .panel:nth-of-type(3) h2 { color: #6b21a8; }
    .panel:nth-of-type(4) h2 { color: #9d174d; }
    .panel:nth-of-type(5) h2 { color: #166534; }
    .panel:nth-of-type(6) h2 { color: #1e40af; }
    .panel:nth-of-type(7) h2 { color: #92400e; }
    .panel:nth-of-type(8) h2 { color: #0f172a; }

    h3     { font-size: 1.11rem; margin: 0.28rem 0 0.1rem; color: #0369a1; break-after: avoid; }
    ul     { padding-left: 1.4rem; margin: 0.1rem 0; }
    li     { margin: 0.07rem 0; }
    p      { margin: 0.15rem 0; break-inside: avoid; }
    p.spacer { line-height: 0.85; font-size: 0.6rem; margin: 0.1rem 0; }

    pre    { background: #ffffff; border: 1px solid #cbd5e1; border-radius: 4px;
             font: 0.83rem/1.3 ui-monospace,Consolas,monospace; padding: 0.47rem;
             white-space: pre-wrap; break-inside: avoid; }
    code   { font-family: ui-monospace,Consolas,monospace; font-size: 0.89rem; }

    .panel:nth-of-type(4) pre { line-height: 1.15; }
    .panel:nth-of-type(7) pre:last-of-type { white-space: pre; overflow: hidden;
             font-size: 0.72rem; line-height: 1.25; }

    .panel:nth-of-type(7) h3     { display: inline; }
    .panel:nth-of-type(7) h3 + p { display: inline; margin: 0 0 0 0.3rem; }

    blockquote { border-left: 3px solid #7c3aed; margin: 0.22rem 0;
                 padding: 0.17rem 0.32rem; break-inside: avoid; }
    hr     { display: none; }

    .version { position: fixed; left: 0; right: 0; bottom: 0;
               text-align: center; font-size: 0.78rem;
               color: #64748b; margin: 0; }
    """
end

function write_html(header, panels, root_pt, variant_label)
    stamp = "<p class=\"version\">$VERSION_TAG$variant_label &#183; $(Dates.today()) (prepared with Mistral AI assistance)</p>"
    page = "<html><head><meta charset=\"utf-8\"><style>$(css(root_pt))</style></head>\n<body>\n$header\n$panels\n$stamp\n</body></html>"
    write(joinpath(OUT_DIR, "cheatsheet.html"), page)
    return joinpath(OUT_DIR, "cheatsheet.html")
end

function print_pdf(browser, html_path)
    pdf_path = joinpath(OUT_DIR, "cheatsheet.pdf")
    isfile(pdf_path) && rm(pdf_path)
    html_url = "file:///" * replace(html_path, "\\" => "/")
    profile_dir = joinpath(mktempdir(), "headless-profile")
    cmd = `$(browser) --headless --no-first-run --user-data-dir=$(profile_dir) --print-to-pdf=$(pdf_path) --no-pdf-header-footer $(html_url)`
    proc = run(cmd, wait = false)
    t = 0
    while process_running(proc) && t < 60
        sleep(1)
        t += 1
    end
    if process_running(proc)
        kill(proc)
        error("headless browser did not finish within 60 s")
    end
    isfile(pdf_path) || error("browser exited but wrote no PDF")
    raw = read(pdf_path, String)
    return count("/Type /Page", raw) - count("/Type /Pages", raw), pdf_path
end

"""Locate a headless-capable browser: Chrome/Edge on Windows, Chrome/Chromium/Edge on Unix."""
function find_browser()
    if Sys.iswindows()
        candidates = [
            raw"C:\Program Files\Google\Chrome\Application\chrome.exe",
            raw"C:\Program Files (x86)\Google\Chrome\Application\chrome.exe",
            raw"C:\Program Files (x86)\Microsoft\Edge\Application\msedge.exe",
            raw"C:\Program Files\Microsoft\Edge\Application\msedge.exe",
        ]
        i = findfirst(isfile, candidates)
        return i === nothing ? nothing : candidates[i]
    else
        for exe in ("google-chrome", "google-chrome-stable", "chromium",
                    "chromium-browser", "microsoft-edge")
            path = Sys.which(exe)
            path !== nothing && return path
        end
        return nothing
    end
end

"""Open an HTML file in the platform default browser."""
function open_html(html_path)
    if Sys.iswindows()
        run(`cmd /c start "" $html_path`)
    elseif Sys.isapple()
        run(`open $html_path`)
    else
        run(`xdg-open $html_path`)
    end
end

function main()
    use_jetls = false
    if isfile(OPTIONS_FILE)
        opts = TOML.parsefile(OPTIONS_FILE)
        use_jetls = Bool(get(opts, "use_jetls", false))
    end
    variant_label = use_jetls ? " &#183; JETLS variant" : ""

    mdtxt = read(INPUT, String)
    mdtxt = replace(mdtxt, "\r\n" => "\n")
    mdtxt = select_variants(mdtxt, use_jetls ? "jetls" : "ls")
    html_body = Markdown.html(Markdown.parse(mdtxt))
    html_body = replace(html_body, "&amp;nbsp;" => "&#160;")    # nbsp
    html_body = replace(html_body, "&amp;ensp;" => "&#8194;")   # half "em"
    html_body = replace(html_body, "&amp;emsp;"  => "&#8195;")  # full "em"
    html_body = replace(html_body, r"<p>\s*(?:&#160;|&nbsp;)\s*</p>" => "<p class=\"spacer\">&#160;</p>")

    parts = split(html_body, r"<h2>")
    panels = join(("<section class=\"panel\"><h2>" * strip(p, ['\n', '\r', ' ']) *
                   "</section>" for p in parts[2:end]), "\n")
    header = parts[1]

    b = find_browser()
    if b === nothing
        html_path = write_html(header, panels, 9.0, variant_label)
        try
            open_html(html_path)
        catch
            println("No browser command available; open $(html_path) manually.")
        end
        println("No Chrome/Chromium/Edge found; opened cheatsheet.html in your default browser.")
        return
    end

    println("Auto-fitting A3 portrait (trying 8.0pt down to 6.0pt)...")
    for root_pt in 8.0:-0.25:6.0
        n_pages, pdf_path = print_pdf(b, write_html(header, panels, root_pt, variant_label))
        println("  root $(rpad(round(root_pt, digits=2), 5))pt -> $n_pages page(s)")
        if n_pages == 1
            println("OK: one-page A3 portrait at $(round(root_pt, digits=2))pt root size.")
            println("wrote $pdf_path and cheatsheet.html")
            return
        end
    end
    println("WARNING: did not fit on one page even at 6.0pt - shorten the Markdown.")
end

main()
