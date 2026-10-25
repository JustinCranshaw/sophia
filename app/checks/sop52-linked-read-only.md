# Existing-only linked notebook reads (SOP-52)

The linked-page tool previously constructed a writable `NotebookStore` for a missing destination, recreating `pages/` and default `notebook.json`. A second controlled reproduction showed that eager MCP startup repaired corrupt **source** metadata before deciding permission and then returned the linked target body. Both used disposable developer fixtures and actual MCP JSON-RPC, without a provider.

`ExistingNotebook` reads strict existing metadata and listed pages through directory-relative, `NOFOLLOW` opens. It rejects malformed privacy metadata, invalid path components, symlinks and nonregular files. It creates no directory, lock, default metadata or recovery record. Shared page-list formatting and existing frontmatter/section parsers preserve normal titles and section bodies. Title discovery, link proposal validation and UI link labels use this reader. Confirmed linked reads require a current person-authored link and available nonseparate source/destination metadata.

MCP `read_page`, initialization and tool listing do not bootstrap writable stores. Other tool calls retain the existing writable context and checks; `recall` is source-local and still uses that context. This is not a claim that every read-shaped tool is nonmutating. Ordinary writes still initialize the store, and the same process can read, write and read the new page.

An open directory descriptor can continue reading its original directory after a rename. The guarantee is no recreation or redirection into a replacement/symlink target, not an atomic filesystem snapshot or universal failure on every rename. The Library root is person-selected; notebook/page components are untrusted and rejected if they are symlinks.

Verification:

- `swift run sophia-checks`: three focused checks cover parser/format parity, missing/corrupt/separate/provisional destinations, invalid identifiers, symlink/FIFO canaries, and the held-directory rename case. The one-way pending-status Quit check remains last.
- Build `swift build --product sophia-mcp`, then run `python3 checks/check-linked-reads.py .build/debug/sophia-mcp`. This actual MCP matrix compares exact fixture trees before/after reads, checks corrupt source metadata is not repaired and target body is withheld, checks initialize/list inertness, and exercises normal read→write→read in one process. It creates and reports its own disposable fixture and leaves it intact.
- App build verifies the narrow MemoryViews title-lookup substitution; no new layout or interaction was introduced. Existing SOP-28 native link-title/navigation evidence is separate from these new filesystem/protocol checks.

No provider call, authentication change, notebook writer redesign or repair of existing corrupt data is part of this change.

Review follow-up preserves legal macOS backslash names, projects historical duplicate page references once in stored order without rewriting metadata, and prevents new duplicate chapter assignments. The direct metadata-symlink canary has a distinct listed page with a confirmed link, so following it would disclose the canary; denial is not explained by missing permission.
