"use strict";

const mathOptions = {
    trust: false,
    throwOnError: false,
    strict: "ignore",
    maxSize: 20,
    maxExpand: 1000,
    output: "htmlAndMathml"
};
const md = markdownit({ html: false, linkify: false, typographer: false }).use(texmath, {
  engine: katex,
  delimiters: ["dollars", "brackets"],
  katexOptions: mathOptions
});

// Top-level blocks carry the source line they start on, so the page editor can find a
// section's heading and open the caret where the person was reading.
md.core.ruler.push("source_lines", state => {
  for (const token of state.tokens) {
    if (token.map && token.nesting === 1 && token.level === 0) token.attrSet("data-line", String(token.map[0]));
  }
});

// An ```abc fence (MUSIC.md) becomes a placeholder holding the fence's exact text. The
// reader typesets it after sanitizing (music.js); until then, or if that fails, it reads
// as the source. Other fences keep markdown-it's rendering.
const renderFence = md.renderer.rules.fence;
md.renderer.rules.fence = (tokens, i, options, env, self) => {
  const token = tokens[i];
  if (token.info.trim().split(/\s+/)[0] !== "abc") return renderFence(tokens, i, options, env, self);
  const line = token.map && token.level === 0 ? ` data-line="${token.map[0]}"` : "";
  return `<figure class="abc"${line}><pre class="abc-source"><code>${md.utils.escapeHtml(token.content)}</code></pre></figure>\n`;
};

// Reading a page never fetches an image or a tracking URL. Keep its description.
md.renderer.rules.image = (tokens, i) => md.utils.escapeHtml(tokens[i].content);

// Macros are shared within a document, never across documents or stream updates.
function renderMarkdown(source) {
  mathOptions.macros = {};
  return md.render(source);
}
