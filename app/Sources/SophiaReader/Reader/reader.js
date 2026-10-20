/* Only this bundled code runs. Markdown and TeX are data, never script source. */
"use strict";

const content = document.getElementById("content");
// KaTeX's MathML keeps the original TeX in <semantics><annotation>, for VoiceOver and
// copying. DOMPurify drops both by default; annotation-xml (which can carry HTML) stays out.
function sanitizeHTML(html) {
  return DOMPurify.sanitize(html, { ADD_TAGS: ["eq", "eqn", "semantics", "annotation"] });
}
function renderSafely(source) { return sanitizeHTML(renderMarkdown(source)); }
const post = message => window.webkit?.messageHandlers.reader?.postMessage(message);

let lastSource = null;
let lastHeight = 0;
let lastHeadings = "";
function reportHeight(shift = 0) {
  const height = Math.ceil(content.getBoundingClientRect().height);
  // Where each section heading sits, so the app can scroll to a linked section. While a
  // section is open its headings are source text, so the last positions are kept.
  const top = content.getBoundingClientRect().top;
  const headings = window.sophiaEditor?.isOpen ? null
    : Array.from(content.querySelectorAll("h2, h3"), h => Math.round(h.getBoundingClientRect().top - top));
  const key = headings ? headings.join(",") : lastHeadings;
  if (height !== lastHeight || key !== lastHeadings || shift) {
    lastHeight = height;
    lastHeadings = key;
    // shift: how far the editor, or the line the person was on, moved; the app scrolls to match.
    post(headings ? { height, headings, shift } : { height, shift });
  }
}

// MARK: Edit affordances

/// A button in the left margin of each editable part of a page: on a section's heading, and
/// on the opening text before the first section. It shows on hover or keyboard focus.
function placeAffordances(sections) {
  for (const section of sections ?? []) {
    const blocks = [...content.querySelectorAll(":scope > [data-line]")]
      .filter(b => +b.dataset.line >= section.start && +b.dataset.line < section.end);
    const anchor = section.key === "(opening)" ? blocks[0] : blocks.find(b => +b.dataset.line === section.start);
    if (!anchor) continue;
    if (section.key === "(opening)") blocks.forEach(b => b.classList.add("opening-block"));
    const button = document.createElement("button");
    button.type = "button";
    button.className = "edit-affordance" + (section.key === "(opening)" ? " opening-affordance" : "");
    button.setAttribute("aria-label", `Edit ${section.label}`);
    button.title = `Edit ${section.label}`;
    button.addEventListener("click", () => post({ edit: section.key }));
    anchor.prepend(button);
  }
}

/// Where the caret should open in a range: the block holding the reader's selection, else
/// the first block visible at the top of the window (caretY), else the range's first line.
/// Also returns where that block sits now, so the view can be held still around it.
function caretFor(editor) {
  const inRange = b => b && +b.dataset.line >= editor.start && +b.dataset.line < editor.end;
  const blocks = [...content.querySelectorAll(":scope > [data-line]")].filter(inRange);
  const selection = window.getSelection();
  const node = selection?.rangeCount ? selection.getRangeAt(0).startContainer : null;
  let block = (node?.nodeType === Node.ELEMENT_NODE ? node : node?.parentElement)?.closest("#content > [data-line]");
  if (!inRange(block)) block = editor.caretY == null ? null : blocks.find(b => b.getBoundingClientRect().bottom > editor.caretY);
  return block ? { line: +block.dataset.line - editor.start, top: block.getBoundingClientRect().top }
    : { line: 0, top: blocks[0]?.getBoundingClientRect().top ?? null };
}

// MARK: Updates from the app

// The editor and CodeMirror load only when editing begins, and abcjs only for a page with
// music, so other readers don't pay for them.
const load = src => new Promise((resolve, reject) => {
  const script = document.createElement("script");
  script.src = src;
  script.onload = resolve;
  script.onerror = () => reject(new Error(`Couldn't load ${src}`));
  document.head.append(script);
});
let editorScripts = null, musicScripts = null;
function loadEditor() {
  editorScripts ??= load("vendor/codemirror.min.js").then(() => load("editor.js"));
  return editorScripts;
}
function loadMusic() {
  musicScripts ??= load("vendor/abcjs.min.js").then(() => load("music.js"));
  return musicScripts;
}
const hasMusic = source => /^[ \t]*(`{3,}|~{3,})[ \t]*abc\b/m.test(source);

/// Renders Markdown into an element, then typesets its music (music.js). Once abcjs has
/// loaded this finishes before returning, so the editor can measure around it.
/// Resolves to each tune's line, title, and warnings.
async function show(element, source) {
  element.innerHTML = renderSafely(source);
  if (!element.querySelector("figure.abc")) return [];
  if (!window.sophiaMusic) await loadMusic();
  return sophiaMusic.render(element);
}

// A page's notation warnings go to the app, which tells Sophia (MUSIC.md). Only whole
// renders report; while a section is open, its tunes are source text.
let lastMusic = "[]";
function reportMusic(music) {
  const key = JSON.stringify(music);
  if (key === "[]" && lastMusic === "[]") return;
  lastMusic = key;
  post({ music });
}

async function apply({ source, serif, size, lineSpacing, paragraphSpacing, sections, editor }) {
  document.body.classList.toggle("book", serif);
  // A page keeps a left margin for its Edit buttons, whether or not a section is open.
  document.body.classList.toggle("editable", !!sections);
  const style = document.documentElement.style;
  style.setProperty("--size", `${size}px`);
  style.setProperty("--leading", `${size + lineSpacing}px`);
  style.setProperty("--paragraph", `${paragraphSpacing}px`);
  let shift = 0;
  if (editor) {
    await loadEditor();
    if (hasMusic(source)) await loadMusic();
    if (sophiaEditor.id !== editor.id) {
      if (sophiaEditor.isOpen) sophiaEditor.close();
      if (source !== lastSource || !content.querySelector("[data-line]")) await show(content, source);
      const caret = caretFor(editor);
      shift = sophiaEditor.open(source, editor, caret.line, caret.top);
    } else {
      shift = sophiaEditor.update(source, editor);
    }
    lastSource = source;
  } else {
    if (window.sophiaEditor?.isOpen) { sophiaEditor.close(); lastSource = null; }
    if (source !== lastSource || sections) {
      const music = await show(content, source);
      lastSource = source;
      placeAffordances(sections);
      reportMusic(music);
    }
  }
  reportHeight(shift);
  document.fonts.ready.then(() => reportHeight());
}

// Updates apply in order, though opening the editor waits for its scripts.
let pending = Promise.resolve();
window.sophiaReader = {
  update(payload) {
    pending = pending.then(() => apply(payload)).catch(error => post({ problem: String(error) }));
    return pending;
  }
};

new ResizeObserver(() => reportHeight()).observe(content);
document.addEventListener("copy", event => {
  const selection = window.getSelection();
  if (event.defaultPrevented || !selection || selection.isCollapsed || !event.clipboardData) return;
  const range = selection.getRangeAt(0).cloneRange();
  const closestSource = node => (node.nodeType === Node.ELEMENT_NODE ? node : node.parentElement)?.closest(".katex, figure.abc");
  const start = closestSource(range.startContainer);
  const end = closestSource(range.endContainer);
  if (start) range.setStartBefore(start);
  if (end) range.setEndAfter(end);
  const fragment = range.cloneContents();
  if (!fragment.querySelector(".katex, figure.abc")) return; // Keep native prose copying.
  // Copy music as its ABC fence, which pastes back into a page as the same tune.
  for (const figure of fragment.querySelectorAll("figure.abc")) {
    const source = figure.querySelector(".abc-source")?.textContent ?? "";
    figure.replaceWith(document.createTextNode("```abc\n" + source + (source.endsWith("\n") ? "" : "\n") + "```"));
  }
  // Copy math as editable LaTeX, rather than the duplicated visual/MathML text.
  for (const formula of fragment.querySelectorAll(".katex")) {
    const source = formula.querySelector('annotation[encoding="application/x-tex"]')?.textContent;
    if (source !== undefined) {
      formula.replaceWith(document.createTextNode(formula.closest(".katex-display") ? `$$${source}$$` : `$${source}$`));
    }
  }
  // innerText preserves paragraph and code line breaks. Measure the converted
  // fragment offscreen so copying a mixed passage doesn't join its paragraphs.
  const copyText = document.createElement("div");
  copyText.style.cssText = "position:absolute;left:-100000px;top:0;white-space:pre-wrap";
  copyText.append(fragment);
  document.body.append(copyText);
  event.clipboardData.setData("text/plain", copyText.innerText);
  copyText.remove();
  event.preventDefault();
});
window.webkit?.messageHandlers.reader?.postMessage({ ready: true });
