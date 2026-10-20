/* Music on pages (MUSIC.md): typesets the ```abc placeholders markdown.js leaves, after the
   page's HTML was sanitized. abcjs draws into an offscreen element; only its SVG, sanitized
   again on its own with DOMPurify's SVG profile, reaches the page. The ABC source stays in
   the figure, visually hidden, for VoiceOver and copying. Loaded with vendor/abcjs.min.js
   only when a page has a tune. */
"use strict";

window.sophiaMusic = (() => {
  // MARK: Options

  const instruments = new Set(["guitar", "violin", "fiddle", "mandolin", "fiveString"]);
  const clamp = (n, low, high) => Math.min(high, Math.max(low, n));

  /// An optional first line of JSON followed by a line "---" (the Obsidian plugin's form).
  /// Only tablature (instrument, tuning, capo), scale, and staffwidth are taken.
  function split(text) {
    const lines = text.split("\n");
    if (!/^\s*\{/.test(lines[0]) || lines[1]?.trim() !== "---") return { abc: text, options: {}, problems: [] };
    const abc = lines.slice(2).join("\n");
    let raw;
    try { raw = JSON.parse(lines[0]); } catch { return { abc, options: {}, problems: ["The options line isn't valid JSON, so it was ignored."] }; }
    const options = {}, problems = [];
    if (typeof raw?.scale === "number") options.scale = clamp(raw.scale, 0.5, 2);
    if (typeof raw?.staffwidth === "number") options.staffwidth = clamp(raw.staffwidth, 200, 1200);
    if (raw?.tablature) {
      const tabs = [];
      for (const t of [raw.tablature].flat().slice(0, 4)) {
        if (!instruments.has(t?.instrument)) { problems.push(`Unknown tablature instrument ${JSON.stringify(t?.instrument ?? null)}; use one of ${[...instruments].join(", ")}.`); continue; }
        const tab = { instrument: t.instrument };
        if (Array.isArray(t.tuning) && t.tuning.length <= 8 && t.tuning.every(n => typeof n === "string" && /^[A-Ga-g][#b]?[,']*$/.test(n))) tab.tuning = t.tuning;
        if (Number.isInteger(t.capo)) tab.capo = clamp(t.capo, 0, 12);
        tabs.push(tab);
      }
      if (tabs.length) options.tablature = tabs;
    }
    return { abc, options, problems };
  }

  // MARK: Typesetting

  /// abcjs reports warnings as HTML ("Music Line:4:3: …"); read them as text in an inert document.
  const plain = html => new DOMParser().parseFromString(String(html), "text/html").body.textContent.replace(/\s+/g, " ").trim()
    .replace(/^Music Line:(\d+):(\d+): /, "Line $1 of the tune, column $2: ");

  const cache = new Map();
  /// The fence's text as sanitized SVG markup per tune, its warnings, and its first title.
  /// Cached by text, so re-rendering a page around the editor redraws nothing.
  function typeset(text) {
    if (cache.has(text)) return cache.get(text);
    const { abc, options, problems } = split(text);
    const result = { svgs: [], warnings: [...problems], title: "", failed: null };
    // abcjs measures text as it draws, so it needs a laid-out element; this one is offscreen.
    const scratch = document.createElement("div");
    scratch.className = "abc-scratch";
    document.body.append(scratch);
    try {
      const count = clamp(ABCJS.numberOfTunes(abc), 1, 20);
      const outputs = Array.from({ length: count }, () => scratch.appendChild(document.createElement("div")));
      const params = { responsive: "resize", selectTypes: false, add_classes: true };
      if (options.staffwidth) params.staffwidth = options.staffwidth;
      if (options.tablature) params.tablature = options.tablature;
      const tunes = ABCJS.renderAbc(outputs, abc, params);
      for (const tune of tunes) {
        result.title ||= tune.metaText?.title ?? "";
        for (const w of tune.warnings ?? []) result.warnings.push(plain(w));
      }
      for (const svg of scratch.querySelectorAll("svg")) {
        const clean = DOMPurify.sanitize(svg.outerHTML, {
          USE_PROFILES: { svg: true }, FORBID_TAGS: ["style", "foreignObject"], RETURN_DOM_FRAGMENT: true
        }).firstElementChild;
        if (!clean) continue;
        // abcjs positions the SVG inside its own wrapper; here it scales to the text column
        // instead, never wider than drawn (times the scale option).
        const width = clean.viewBox?.baseVal?.width;
        clean.removeAttribute("style");
        if (width) clean.style.maxWidth = `${Math.round(width * (options.scale ?? 1))}px`;
        clean.removeAttribute("role");
        clean.removeAttribute("aria-label");
        clean.setAttribute("aria-hidden", "true");
        result.svgs.push(clean.outerHTML);
      }
      if (!result.svgs.length) result.failed = "abcjs drew nothing for this text.";
    } catch (error) {
      result.failed = `abcjs couldn't read this notation (${error?.message ?? error}).`;
    } finally {
      scratch.remove();
    }
    if (cache.size > 100) cache.clear();
    cache.set(text, result);
    return result;
  }

  /// The collapsible list of warnings shown under a tune.
  function warningList(warnings) {
    const details = document.createElement("details");
    details.className = "abc-warnings";
    const summary = document.createElement("summary");
    summary.textContent = warnings.length === 1 ? "1 notation warning" : `${warnings.length} notation warnings`;
    const list = document.createElement("ul");
    for (const w of warnings) list.appendChild(document.createElement("li")).textContent = w;
    details.append(summary, list);
    return details;
  }

  /// Draws one tune's figure in place: the music, then any warnings. On a hard failure the
  /// figure shows its source, bordered, so the page still reads.
  function draw(figure, text, result) {
    const source = document.createElement("pre");
    source.className = "abc-source";
    source.appendChild(document.createElement("code")).textContent = text;
    figure.replaceChildren();
    if (result.failed) {
      figure.classList.add("abc-failed");
      figure.append(source, warningList([result.failed, ...result.warnings]));
      return;
    }
    figure.setAttribute("role", "figure");
    figure.setAttribute("aria-label", result.title ? `Music: ${result.title}` : "Music");
    const music = document.createElement("div");
    music.className = "abc-music";
    music.innerHTML = result.svgs.join("");
    figure.append(music, source);
    if (result.warnings.length) figure.append(warningList(result.warnings));
  }

  return {
    typeset,
    isTypeset: text => cache.has(text),
    draw,
    /// Typesets every placeholder under root that hasn't been drawn yet. Returns, for each, the
    /// line it starts on (when it's a top-level block), its title, and its warnings.
    render(root) {
      const out = [];
      for (const figure of root.querySelectorAll("figure.abc:not([data-drawn])")) {
        const text = figure.querySelector(".abc-source")?.textContent ?? "";
        const result = typeset(text);
        draw(figure, text, result);
        figure.dataset.drawn = "";
        const line = figure.dataset.line == null ? null : +figure.dataset.line;
        const warnings = result.failed ? [result.failed, ...result.warnings] : result.warnings;
        out.push({ line, title: result.title, warnings });
      }
      return out;
    }
  };
})();
