# generate.jl — Markdown -> styled HTML -> one-page A3 portrait PDF
# Usage:  julia generate.jl [input.md]
# Auto-fits: tries the largest text size that still yields exactly one page.

@usingany Markdown


const INPUT = length(ARGS) >= 1 ? ARGS[1] : "Julia_Code_Organization_Cheat_Sheet.md"

function css(root_pt)
    """
    @page  { size: A3 portrait; margin: 6mm 16mm; }
    *      { box-sizing: border-box; }
    html   { font-size: $(root_pt)pt; }
    body   { display: grid; grid-template-columns: 1fr 1fr;
             gap: 1.4rem; font: 1rem/1.35 "Inter","Segoe UI",Arial,sans-serif;
             color: #1e293b; }
    h1     { grid-column: 1 / -1; font-size: 1.9rem; line-height: 1.1;
             text-align: center; margin: 0; color: #0f172a; }
    h1 + p { grid-column: 1 / -1; text-align: center; margin: 0 0 0.4rem; color: #475569; }

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
    p      { margin: 0.17rem 0; break-inside: avoid; }

    pre    { background: #ffffff; border: 1px solid #cbd5e1; border-radius: 4px;
             font: 0.83rem/1.3 ui-monospace,Consolas,monospace; padding: 0.47rem;
             white-space: pre-wrap; break-inside: avoid; }
    code   { font-family: ui-monospace,Consolas,monospace; font-size: 0.89rem; }

    /* box 0 pipeline banner: centered */
    .panel:nth-of-type(1) pre:first-of-type { border: none; background: none;
             text-align: center; font-weight: 600; font-size: 1rem;
             margin: 0.2rem 0 0.4rem; }
    /* box 7 resolution flow banner: left-justified */
    .panel:nth-of-type(8) pre:last-of-type { border: none; background: none;
             text-align: left; font-weight: 600; font-size: 1rem;
             margin: 0.2rem 0 0.4rem; }

    .panel:nth-of-type(4) pre { line-height: 1.15; }
    .panel:nth-of-type(7) pre:last-of-type { white-space: pre; overflow: hidden;
             font-size: 0.72rem; line-height: 1.25; }

    .panel:nth-of-type(7) h3     { display: inline; }
    .panel:nth-of-type(7) h3 + p { display: inline; margin: 0 0 0 0.3rem; }

    blockquote { border-left: 3px solid #7c3aed; margin: 0.22rem 0;
                 padding: 0.17rem 0.32rem; break-inside: avoid; }
    hr     { display: none; }
    """
end

function write_html(header, panels, root_pt)
    page = "<html><head><meta charset=\"utf-8\"><style>$(css(root_pt))</style></head>\n<body>\n$header\n$panels\n</body></html>"
    write("cheatsheet.html", page)
    return abspath("cheatsheet.html")
end

function print_pdf(browser, html_path)
    pdf_path = abspath("cheatsheet.pdf")
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

function main()
    mdtxt = read(INPUT, String)
    mdtxt = replace(mdtxt, "\r\n" => "\n")
    html_body = Markdown.html(Markdown.parse(mdtxt))
    html_body = replace(html_body, "&amp;nbsp;" => "&#160;")

    parts = split(html_body, r"<h2>")
    panels = join(("<section class=\"panel\"><h2>" * strip(p, ['\n', '\r', ' ']) *
                   "</section>" for p in parts[2:end]), "\n")
    header = parts[1]

    candidates = [
        raw"C:\Program Files\Google\Chrome\Application\chrome.exe",
        raw"C:\Program Files (x86)\Google\Chrome\Application\chrome.exe",
        raw"C:\Program Files (x86)\Microsoft\Edge\Application\msedge.exe",
        raw"C:\Program Files\Microsoft\Edge\Application\msedge.exe",
    ]
    browser = findfirst(isfile, candidates)
    if browser === nothing
        write_html(header, panels, 9.0)
        run(`cmd /c start cheatsheet.html`)
        println("No Chrome/Edge found; opened cheatsheet.html in your default browser.")
        return
    end
    b = candidates[browser]

    println("Auto-fitting A3 portrait (trying 8.0pt down to 6.0pt)...")
    for root_pt in 8.0:-0.25:6.0
        n_pages, pdf_path = print_pdf(b, write_html(header, panels, root_pt))
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

