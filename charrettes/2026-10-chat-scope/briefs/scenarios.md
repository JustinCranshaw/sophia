# Scenario script: how Sophia's conversations relate to the notebook

Every stage tests its proposals against all eleven scenarios below. The notebook content is disposable and non-sensitive. Use it verbatim in prototypes so the alternatives stay comparable.

## The notebook: "Fourier analysis"

The person is an independent learner relearning Fourier analysis for signal-processing work. They've had the notebook for about three weeks. Goals (learning.jsonl):

- **g-1** (confirmed by the person): "Be able to explain why a convolution in time is a product in frequency, and use that to reason about filters." Criteria: g-1#1 "Derive the convolution theorem for the DTFT", g-1#2 "Predict what a moving-average filter does to a high-frequency component before computing it", g-1#3 "Say when the theorem does not apply (finite signals, circular vs linear convolution)".
- **g-2** (provisional, by Sophia): "Understand the DFT well enough to read an FFT-based spectrogram critically." No criteria yet.

Sophia's working memory has four lines, e.g. "The person is fluent with complex exponentials but finds the sign convention of the inverse transform rusty [t-0188, n-12]" and "Open: whether zero-padding 'adds information' (they think it does; it doesn't) [t-0231, n-19]".

Chapters and pages (notebook.json; file names in parentheses):

**Chapter 0: Foundations**
- 0.1 Complex exponentials as a basis (`0-1-complex-exponentials.md`)
- 0.2 The Fourier series of a periodic signal (`0-2-fourier-series.md`)
- 0.3 Orthogonality and why the coefficients fall out (`0-3-orthogonality.md`)

**Chapter 1: Transforms**
- 1.1 From series to transform: the continuous-time FT (`1-1-continuous-ft.md`)
- 1.2 The DTFT and periodicity in frequency (`1-2-dtft.md`)
- 1.3 The convolution theorem (`1-3-convolution-theorem.md`)  ← **page P**
- 1.4 Sampling and aliasing (`1-4-sampling.md`)  ← **page Q**

**Chapter 2: Computation**
- 2.1 The DFT as a sampled DTFT (`2-1-dft.md`)
- 2.2 Zero-padding and interpolation (`2-2-zero-padding.md`)

**Not in a chapter**
- Reading list (`reading-list.md`)

Page P ("1.3 The convolution theorem") has four sections: "Statement", "Derivation for the DTFT", "What it buys you: filters", and "Where it fails". The "Derivation" section contains a block quote of the person's attempt from Oct 9 (`<!-- quote: t-0204 -->`): "Swap the sums, substitute m = n − k, and the inner sum is just X(ω) times a phase factor." The person edited one line in "Where it fails" on Oct 16 (an `edit_page` entry, protected): "Circular convolution of length-N sequences equals linear convolution only when N ≥ L₁ + L₂ − 1."

Page Q ("1.4 Sampling and aliasing") has three sections: "Sampling as multiplication by an impulse train", "Replication in frequency", and "The Nyquist condition". It has never been edited by the person.

Page R does not exist yet. In scenario 4 Sophia creates it: "1.5 Windowing and spectral leakage" (`1-5-windowing.md`).

Transcript so far: about 240 entries across 9 sessions (app launches) over three weeks. Six checkpoints. One briefing on Oct 12. Page `2-2-zero-padding.md` was discussed in four different sessions; page `0-3-orthogonality.md` has never been discussed in conversation (Sophia wrote it unprompted alongside 0.2 and the person never asked about it).

## The eleven scenarios

1. **Ask about a sentence, then revise.** On page P, in "What it buys you: filters", the person selects the sentence "A moving-average filter is a low-pass filter because its frequency response is a sinc." and chooses "Ask Sophia about this". They ask: "Why sinc? I'd have guessed something smoother." Sophia explains (the rectangular window's DTFT is a Dirichlet kernel, often loosely called a sinc), then revises P: she replaces "is a sinc" with "is a Dirichlet kernel (a periodic sinc)" and adds two sentences. The person sees the revision and the undo offer.

2. **Mid-exchange, open another page and connect them.** Before replying to Sophia's revision, the person opens page Q ("1.4 Sampling and aliasing") and asks: "Does the convolution theorem explain why sampling replicates the spectrum? Sampling is multiplication in time, so…" The question depends on the P discussion (the theorem) and on Q (replication). Where is the person now, what does Sophia know, and where does the answer go?

3. **Notebook level.** The person is not on any page (or is on the notebook's top-level page). Three exchanges in a row:
   - "What should I study next?" (Sophia answers from goals, memory, and the page list.)
   - "Move 2.2 Zero-padding into Chapter 1, after Sampling. Chapter 2 should be about the FFT." (Sophia calls `set_chapter`; the contents update.)
   - "Actually, my real goal is to be able to read a spectrogram and know what's an artifact. Make that the goal." (Sophia revises g-2 with `set_goal`; it's provisional until confirmed.)

4. **A page-scoped conversation creates a new page.** On page P's chat, the person asks about leakage: "If I window a signal before the DFT, is that the convolution theorem again?" Sophia explains and, because the material doesn't belong on P, writes a new page R ("1.5 Windowing and spectral leakage") with `write_page`, filed in Chapter 1. Afterward: does the conversation stay on P or move to R? When the person later opens R, what does R's chat show: nothing, a pointer to the P exchange, or the exchange itself?

5. **Fresh start on P.** P's conversation has grown long over several sessions (the sinc discussion, the leakage discussion, an earlier derivation walk-through). The person wants to start a clean exchange about "Where it fails" without the earlier context steering Sophia, but does not want to lose the earlier discussion, and wants Sophia to keep what she learned from it (notes, memory). What do they do, what happens to the transcript, the checkpoint, and Sophia's memory, and how do they get back to the old discussion?

6. **Two unrelated lines on the same page at once.** On P, the person is partway through a derivation check with Sophia in "Derivation for the DTFT" (Sophia has asked them to write the swapped-sums step). Before answering, they notice a typo-level question in "Where it fails" ("Is it L₁ + L₂ − 1 or L₁ + L₂?") and want to ask it without derailing the derivation. Is this a second thread, a parenthetical in one stream, or a page edit (scenario 8)? The stage must say whether this situation is common enough for a solo learner to justify machinery.

7. **Back after a week.** The person last used the notebook eight days ago, mid-derivation on P, and the last two messages have no notes. On launch: catch-up notes run, then a briefing of at most two sentences. Where does the briefing appear (notebook scope, P's chat, both, a banner), and in which scope does the person land? If they open Q first, do they see it?

8. **Editing P while P's chat is open.** The person opens "Where it fails" in the editor and starts changing their own line (the N ≥ L₁ + L₂ − 1 line) to add a parenthetical. Meanwhile Sophia, in P's chat, finishes a reply and tries to revise "Where it fails". The write is refused ("open"). The refusal shows in the conversation. The person commits; their next message carries the edit as a hunk. Then Sophia proposes rewording their line and is refused ("protected"); the release marker appears. The EDITING.md rules must hold unchanged whichever scope the chat lives in.

9. **Undo across scopes.** In P's chat Sophia revises P. The person, without replying on P, opens Q and sends a message in Q's chat. Is P's revision still undoable? Today undo lasts "until the person's next message". The stage must say what "next message" means with several scopes, and what the page banner on P shows afterward.

10. **Crash and relaunch with several scopes live.** Chats on P, Q, and the notebook level all have history from this sitting; a checkpoint has not run; P's chat has an undoable write. The app crashes. On relaunch: each scope's history must be exactly what was persisted, nothing duplicated or lost; the undo state is whatever the rule in scenario 9 says survives; provider resume for one or more scopes fails (the stored provider session id is stale or Claude Code can't find it) and Sophia must say her context was reconstructed. What does the person see in each scope?

11. **Empty and overflow states.**
    - A page that has never been discussed (`0-3-orthogonality.md`): what does its chat show, and what is the first-message experience?
    - A page with many past sessions (`2-2-zero-padding.md`, four sessions, two checkpoints, one undo): how is history found, and what does Sophia get as context?
    - A notebook-level chat that keeps growing for months (hundreds of entries): what bounds it, what does the person see, and what does Sophia get?
