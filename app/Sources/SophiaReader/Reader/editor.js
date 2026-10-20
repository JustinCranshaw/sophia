/* The page editor: one range of the page's raw Markdown (a section, the opening, or the
   whole page) in CodeMirror, with the rest of the page still rendered around it. Styled
   source: syntax stays visible but quiet, math source is always shown, and the formula
   or tune (an ```abc fence) holding the caret is previewed beneath it. Loaded only when editing begins.
   The app owns the text: this script reports drafts and commits, and the app decides. */
"use strict";

window.sophiaEditor = (() => {
  const content = document.getElementById("content");
  const before = document.createElement("div");
  const after = document.createElement("div");
  const host = document.createElement("div");
  const strip = document.createElement("div");
  const mount = document.createElement("div");
  const theirs = document.createElement("div");
  host.className = "editing";
  strip.className = "strip";
  strip.setAttribute("role", "toolbar");
  theirs.className = "theirs";
  host.append(strip, mount, theirs);

  let view = null, current = null, original = "", parts = null;
  const post = message => window.webkit?.messageHandlers.reader?.postMessage(message);

  // MARK: Math in the source

  /// Formulas in the text, with the reader's delimiters ($…$, $$…$$, \(…\), \[…\]), outside code.
  function findMath(state) {
    const text = state.doc.toString();
    const codes = [];
    CM.syntaxTree(state).iterate({
      enter(node) {
        if (/^(FencedCode|CodeBlock|InlineCode)$/.test(node.name)) { codes.push([node.from, node.to]); return false; }
      }
    });
    let c = 0;
    const inCode = i => {
      while (c < codes.length && codes[c][1] <= i) c++;
      return c < codes.length && codes[c][0] <= i;
    };
    const out = [];
    for (let i = 0; i < text.length; i++) {
      const ch = text[i];
      if ((ch !== "$" && ch !== "\\") || inCode(i)) continue;
      if (ch === "\\") {
        const next = text[i + 1];
        if (next === "[" || next === "(") {
          const j = text.indexOf(next === "[" ? "\\]" : "\\)", i + 2);
          if (j > 0) { out.push({ from: i, to: j + 2, tex: text.slice(i + 2, j), display: next === "[" }); i = j + 1; continue; }
        }
        i++; // an escaped character, such as \$
        continue;
      }
      if (text[i + 1] === "$") {
        const j = text.indexOf("$$", i + 2);
        if (j > 0) { out.push({ from: i, to: j + 2, tex: text.slice(i + 2, j), display: true }); i = j + 1; }
        else i++;
        continue;
      }
      if (/\s/.test(text[i + 1] ?? " ")) continue;
      let j = i + 1;
      while (j < text.length && text[j] !== "$") {
        if (text[j] === "\n" && text[j + 1] === "\n") { j = text.length; break; }
        j += text[j] === "\\" ? 2 : 1;
      }
      if (j < text.length && !/\s/.test(text[j - 1]) && !/\d/.test(text[j + 1] ?? "")) {
        out.push({ from: i, to: j + 1, tex: text.slice(i + 1, j), display: false });
        i = j;
      }
    }
    return out;
  }

  const katexOptions = display => ({ ...mathOptions, macros: {}, displayMode: display });
  const checked = new Map();
  /// Whether KaTeX can typeset a formula; cached, since every keystroke rechecks the page's math.
  function isValid(tex, display) {
    const key = (display ? "D" : "I") + tex;
    if (!checked.has(key)) {
      if (checked.size > 500) checked.clear();
      try { katex.renderToString(tex, { ...katexOptions(display), throwOnError: true }); checked.set(key, true); }
      catch { checked.set(key, false); }
    }
    return checked.get(key);
  }

  class Preview extends CM.WidgetType {
    constructor(tex, display) { super(); this.tex = tex; this.display = display; }
    eq(other) { return other.tex === this.tex && other.display === this.display; }
    toDOM() {
      const element = document.createElement("div");
      element.className = "cm-math-preview";
      // The source is what's read aloud; the preview repeats it visually.
      element.setAttribute("aria-hidden", "true");
      element.innerHTML = sanitizeHTML(katex.renderToString(this.tex, { ...katexOptions(this.display), throwOnError: false }));
      return element;
    }
  }

  // MARK: Music in the source

  /// The ```abc fences in the text, with their content as the reader's parser gives it.
  function findTunes(state) {
    const out = [];
    CM.syntaxTree(state).iterate({
      enter(node) {
        if (node.name !== "FencedCode") return;
        const info = node.node.getChild("CodeInfo"), code = node.node.getChild("CodeText");
        if (info && state.sliceDoc(info.from, info.to).trim().split(/\s+/)[0] === "abc") {
          out.push({ from: node.from, to: node.to, text: code ? state.sliceDoc(code.from, code.to) + "\n" : "" });
        }
        return false;
      }
    });
    return out;
  }

  /// The tune at the caret, typeset beneath its fence: right away when it's already typeset,
  /// else once typing pauses. The last drawing stays until the new one is ready.
  class MusicPreview extends CM.WidgetType {
    constructor(text) { super(); this.text = text; }
    eq(other) { return other.text === this.text; }
    toDOM(view) {
      const element = document.createElement("div");
      element.className = "cm-music-preview";
      // The source is what's read aloud; the preview repeats it visually.
      element.setAttribute("aria-hidden", "true");
      this.schedule(element, view, 0);
      return element;
    }
    updateDOM(element, view) { this.schedule(element, view, 300); return true; }
    schedule(element, view, delay) {
      clearTimeout(element.timer);
      const draw = () => {
        if (!window.sophiaMusic) { loadMusic().then(draw); return; }
        const figure = document.createElement("figure");
        figure.className = "abc";
        sophiaMusic.draw(figure, this.text, sophiaMusic.typeset(this.text));
        element.replaceChildren(figure);
        view.requestMeasure();
      };
      if (window.sophiaMusic?.isTypeset(this.text) || !delay) draw();
      else element.timer = setTimeout(draw, delay);
    }
    destroy(element) { clearTimeout(element.timer); }
  }

  function decorations(state, math, tunes) {
    const head = state.selection.main.head;
    const ranges = math.map(m => CM.Decoration.mark({ class: isValid(m.tex, m.display) ? "cm-math" : "cm-math cm-math-error" }).range(m.from, m.to));
    const atCaret = math.find(m => m.from <= head && head <= m.to && m.tex.trim());
    if (atCaret) {
      const end = state.doc.lineAt(atCaret.to).to;
      ranges.push(CM.Decoration.widget({ widget: new Preview(atCaret.tex, atCaret.display), block: true, side: 1 }).range(end));
    }
    const tune = tunes.find(t => t.from <= head && head <= t.to && t.text.trim());
    if (tune) {
      ranges.push(CM.Decoration.widget({ widget: new MusicPreview(tune.text), block: true, side: 1 }).range(state.doc.lineAt(tune.to).to));
    }
    return CM.Decoration.set(ranges, true);
  }

  // Block widgets must come from state, not a view plugin.
  const mathField = CM.StateField.define({
    create(state) {
      const math = findMath(state), tunes = findTunes(state);
      return { math, tunes, deco: decorations(state, math, tunes) };
    },
    update(value, tr) {
      if (!tr.docChanged && !tr.selection) return value;
      const math = tr.docChanged ? findMath(tr.state) : value.math;
      const tunes = tr.docChanged ? findTunes(tr.state) : value.tunes;
      return { math, tunes, deco: decorations(tr.state, math, tunes) };
    },
    provide: field => CM.EditorView.decorations.from(field, value => value.deco)
  });

  // MARK: Styled source

  const quiet = "color-mix(in srgb, CanvasText 38%, transparent)";
  const highlight = CM.HighlightStyle.define([
    { tag: CM.tags.heading1, fontSize: "30px", fontWeight: "600" },
    { tag: CM.tags.heading2, fontSize: "21px", fontWeight: "600" },
    { tag: CM.tags.heading3, fontSize: "18px", fontWeight: "600" },
    { tag: [CM.tags.heading4, CM.tags.heading5, CM.tags.heading6], fontWeight: "600" },
    { tag: [CM.tags.processingInstruction, CM.tags.labelName, CM.tags.url, CM.tags.escape, CM.tags.contentSeparator], color: quiet },
    { tag: CM.tags.emphasis, fontStyle: "italic" },
    { tag: CM.tags.strong, fontWeight: "600" },
    { tag: CM.tags.monospace, fontFamily: "ui-monospace, SFMono-Regular, Menlo, monospace", fontSize: "0.85em" },
    { tag: CM.tags.link, color: "LinkText" },
    { tag: CM.tags.quote, fontStyle: "italic" }
  ]);
  const theme = CM.EditorView.theme({
    "&": { fontSize: "var(--size)" },
    "&.cm-focused": { outline: "none" },
    ".cm-scroller": { fontFamily: "inherit", lineHeight: "var(--leading)", overflow: "visible" },
    ".cm-content": { padding: "6px 0", caretColor: "CanvasText" },
    ".cm-line": { padding: "0 10px" },
    ".cm-cursor": { borderLeftColor: "CanvasText", borderLeftWidth: "1.5px" },
    "&.cm-focused .cm-selectionBackground, .cm-selectionBackground": { backgroundColor: "color-mix(in srgb, Highlight 35%, transparent)" }
  });

  // MARK: The strip

  function renderStrip() {
    const conflict = current.conflict != null;
    strip.replaceChildren();
    strip.classList.toggle("dimmed", !!current.dimmed && !conflict);
    strip.setAttribute("aria-label", `Editing ${current.label}`);
    const label = document.createElement("span");
    label.textContent = `Editing ${current.label}`;
    strip.append(label);
    const button = (text, action, disabled = false) => {
      const b = document.createElement("button");
      b.type = "button";
      b.textContent = text;
      b.disabled = disabled;
      // Keep the caret in the editor while clicking the strip.
      b.addEventListener("mousedown", event => event.preventDefault());
      b.addEventListener("click", action);
      return b;
    };
    const dot = () => { const s = document.createElement("span"); s.textContent = " · "; return s; };
    if (current.dimmed && !conflict) {
      strip.append(dot(), Object.assign(document.createElement("span"), { textContent: "open" }));
    } else {
      strip.append(dot(), button("Done ⌘↩", done, conflict), dot(), button("Revert Esc", revert));
    }
    theirs.hidden = true;
    if (conflict) {
      const line = document.createElement("div");
      line.className = "conflict";
      line.append("Sophia revised this section while you were editing · ",
        button("Show her version", () => {
          theirs.hidden = !theirs.hidden;
          if (!theirs.hidden) show(theirs, current.conflict);
        }), dot(), button("Keep mine", () => post({ keepMine: current.id })));
      strip.append(line);
    }
  }

  // MARK: Commands

  function text() {
    // Untouched, the text goes back exactly as it came, whatever its line endings.
    return view.state.doc.eq(view.initialDoc) ? original : view.state.sliceDoc();
  }
  function done() {
    if (current.conflict != null) return true;
    post({ commit: { id: current.id, hash: current.hash, text: text() } });
    return true;
  }
  function revert() {
    post({ revert: current.id });
    return true;
  }

  // Clicking elsewhere on the page commits, as clicking outside a field does.
  document.addEventListener("mousedown", event => {
    if (view && !host.contains(event.target)) done();
  }, true);

  // Music around the editor is typeset before this returns (reader.js loads abcjs first).
  function render(element, source) { show(element, source); }
  function split(source, start, end) {
    const lines = source.split("\n");
    return { before: lines.slice(0, start).join("\n"), after: lines.slice(end).join("\n") };
  }

  return {
    get isOpen() { return view !== null; },
    get id() { return current?.id; },
    view: () => view,
    undo: () => view && CM.undo(view),
    redo: () => view && CM.redo(view),

    /// Opens the editor on lines start..<end of the rendered source, with the app's text for them.
    /// caretLine is the line (within the range) to start on; returns how far the line the person
    /// was looking at moved, so the app can scroll to keep it still.
    open(source, editor, caretLine, anchorTop) {
      current = editor;
      original = editor.text;
      parts = split(source, editor.start, editor.end);
      render(before, parts.before);
      render(after, parts.after);
      content.replaceChildren(before, host, after);
      const extensions = [
        CM.Prec.highest(CM.keymap.of([{ key: "Mod-Enter", run: done }, { key: "Escape", run: revert }])),
        CM.history(), CM.drawSelection(), CM.EditorView.lineWrapping,
        CM.keymap.of([...CM.historyKeymap, ...CM.defaultKeymap]),
        CM.markdownLanguage.extension, CM.syntaxHighlighting(highlight), theme, mathField,
        CM.EditorView.contentAttributes.of({ "aria-label": `Editing ${editor.label}, Markdown source` }),
        CM.EditorView.updateListener.of(update => {
          if (update.docChanged) {
            post({ draft: { id: current.id, text: text() } });
            post({ history: [CM.undoDepth(update.state), CM.redoDepth(update.state)] });
          }
          if (update.selectionSet || update.docChanged || update.geometryChanged) reportCaret();
        })
      ];
      if (original.includes("\r\n")) extensions.push(CM.EditorState.lineSeparator.of("\r\n"));
      view = new CM.EditorView({ parent: mount, state: CM.EditorState.create({ doc: original, extensions }) });
      view.initialDoc = view.state.doc;
      renderStrip();
      const line = view.state.doc.line(Math.min(Math.max(caretLine, 0), view.state.doc.lines) + 1);
      // A heading opens with the caret at its end; a paragraph at its start.
      view.dispatch({ selection: { anchor: caretLine === 0 && /^#/.test(line.text) ? line.to : line.from } });
      view.focus();
      post({ history: [0, 0] });
      if (anchorTop == null) return 0;
      const rect = view.coordsAtPos(view.state.selection.main.head);
      return rect ? rect.top - anchorTop : 0;
    },

    /// The page or the app's state changed while editing: re-render around the editor without
    /// touching its text or caret, and return how far that moved the editor on the page.
    update(source, editor) {
      const top = host.getBoundingClientRect().top;
      const next = split(source, editor.start, editor.end);
      if (next.before !== parts.before) render(before, next.before);
      if (next.after !== parts.after) render(after, next.after);
      parts = next;
      const changed = editor.dimmed !== current.dimmed || editor.conflict !== current.conflict || editor.label !== current.label;
      current = { ...editor, id: current.id };
      if (changed) renderStrip();
      return host.getBoundingClientRect().top - top;
    },

    close() {
      view?.destroy();
      view = null;
      current = null;
      parts = null;
      post({ history: [0, 0] });
    }
  };

  // The page scrolls in the app, not in this web view, so CodeMirror can't keep the caret
  // visible itself. Report where it is; the app scrolls it into view.
  function reportCaret() {
    const rect = view.coordsAtPos(view.state.selection.main.head);
    if (rect) post({ caret: [rect.top + scrollY, rect.bottom + scrollY] });
  }
})();
