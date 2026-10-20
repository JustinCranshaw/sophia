// Parser-only checks for environments that cannot launch WebKit. Uses the same
// vendored code and configuration as the app; no npm dependencies are needed.
// This does not test DOMPurify, WebKit layout, or the native bridge.
import assert from "node:assert/strict";
import { readFileSync } from "node:fs";
import vm from "node:vm";

const reader = new URL("../Sources/SophiaReader/Reader/", import.meta.url);
const context = vm.createContext({ console, atob, btoa });
try {
  for (const file of ["vendor/markdown-it.min.js", "vendor/katex.min.js", "vendor/texmath.js", "markdown.js"]) {
    vm.runInContext(readFileSync(new URL(file, reader), "utf8"), context, { filename: file });
  }
  const render = source => {
    context.source = source;
    return vm.runInContext("renderMarkdown(source)", context);
  };
  const count = (html, className) => (html.match(new RegExp(`class="${className}"`, "g")) ?? []).length;
  const sample = readFileSync(new URL("../Sources/sophia-reader-checks/Fixtures/math.md", import.meta.url), "utf8");
  const html = render(sample);
  assert.equal(count(html, "katex"), 10, "Inline, display, list, quote, and table math");
  assert.equal(count(html, "katex-display"), 3, "Dollar and bracket display delimiters");
  assert.equal(count(html, "katex-error"), 0, "Valid equations");
  assert.ok((html.match(/<mfrac>/g) ?? []).length >= 3, "Fractions");
  assert.ok((html.match(/<mtable/g) ?? []).length >= 2, "Matrices and aligned derivations");
  assert.match(html, /<pre><code class="language-latex">\$\$\\frac\{a\}\{b\}\$\$/);
  assert.match(html, /<code>\$x\^2\$<\/code>/, "Inline code stays literal");
  assert.match(html, /<annotation encoding="application\/x-tex">/, "Accessible MathML and TeX source");
  assert.match(html, /xᵀLx, λ₂, ∑/, "Older Unicode pages");

  assert.equal(count(render(String.raw`Prices are $5 and $10; escaped \$20. Unfinished: $\frac{a}{`), "katex"), 0);
  assert.equal(count(render(String.raw`An invalid $\frac{a}{$ then a valid $x^2$.`), "katex-error"), 1);
  assert.equal(count(render(String.raw`Prefix $x_1`), "katex"), 0);
  assert.equal(count(render(String.raw`Prefix $x_1+x_2$.`), "katex"), 1);
  assert.equal(count(render(String.raw`$\gdef\custom{z}\custom$`), "katex-error"), 0);
  assert.match(render(String.raw`$\custom$`), /\\custom/, "Macros cannot leak across documents");
  const untrusted = render(String.raw`<script>alert(1)</script>
![description](https://example.com/image.png)
[bad](javascript:alert(1))
$\includegraphics{https://example.com/tex.png}$
$\href{javascript:alert(1)}{bad}$
$\htmlStyle{background:url(https://example.com/track)}{x}$`);
  assert.doesNotMatch(untrusted, /<script|<img|href="javascript:|style="[^"]*example\.com/);
  assert.match(untrusted, /description/);
  assert.equal(count(render("A long reply with $x^2$.\n\n".repeat(100)), "katex"), 100);

  // Music (MUSIC.md): an abc fence becomes a placeholder holding its exact text; other fences don't.
  const tune = '{"tablature": {"instrument": "guitar"}}\n---\nX:1\nT:A <b>"title"</b> & $x$\nK:G\n|:GABc d2 e2:|\n\tw: lyr-ics\n';
  const music = render("Intro\n\n```abc\n" + tune + "```\n\n```js\nlet x = 1 < 2;\n```\n\n~~~ abc extra\nK:C\nC\n~~~\n\n```abcd\nK:C\n```\n");
  const held = [...music.matchAll(/<figure class="abc"( data-line="\d+")?><pre class="abc-source"><code>([^]*?)<\/code><\/pre><\/figure>/g)]
    .map(m => [m[1], m[2].replace(/&lt;/g, "<").replace(/&gt;/g, ">").replace(/&quot;/g, '"').replace(/&amp;/g, "&")]);
  assert.deepEqual(held, [[' data-line="2"', tune], [' data-line="16"', "K:C\nC\n"]], "abc fences become placeholders with their exact text");
  assert.doesNotMatch(music, /katex|<b>/, "No math or markup inside a tune");
  assert.match(music, /<pre><code class="language-js">let x = 1 &lt; 2;\n<\/code><\/pre>/, "Other fences are unchanged");
  assert.match(music, /<pre><code class="language-abcd">K:C\n<\/code><\/pre>/, "Only the abc info string");
  console.log("Parser checks passed: Markdown, LaTeX, code, streamed/invalid math, Unicode, restricted commands, and abc placeholders.");
} catch (error) {
  // Avoid dumping minified library source on failure.
  console.error(error.message);
  process.exitCode = 1;
}
