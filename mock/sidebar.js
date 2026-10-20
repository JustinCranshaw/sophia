// Sophia UI mock: every screen's sidebar comes from one template, so its order never drifts.
//
// Structure, in this order:
//   Search
//   Library: one row per notebook. The open notebook expands in place; its row opens Contents.
//     Goals · Sophia's notes            (per-notebook, above the book)
//     ───
//     Chapters (disclosure rows) with their pages, then pages with no chapter at chapter level
//     ───
//     Not in the book yet               (drafts, revisions, chapter proposals, set-aside drafts)
//
// Items may carry `when` (same syntax as data-when), `set`, `scroll` and `cur`.
(function () {
  var FV = 'Why the Fiedler vector splits a graph';
  var S = 'width="14" height="14" viewBox="0 0 16 16" fill="none" stroke="currentColor" stroke-width="1.3" aria-hidden="true"';
  var ICON = {
    search: '<svg width="13" height="13" viewBox="0 0 16 16" fill="none" stroke="currentColor" stroke-width="1.5" aria-hidden="true"><circle cx="7" cy="7" r="4.5"/><path d="M10.5 10.5L14 14"/></svg>',
    book: '<svg class="ic" ' + S + '><rect x="3" y="1.5" width="10" height="13" rx="1.5"/><path d="M6 1.5v13"/></svg>',
    goal: '<svg class="ic" ' + S + '><circle cx="8" cy="8" r="6"/><circle cx="8" cy="8" r="3"/></svg>',
    notes: '<svg class="ic" ' + S + '><rect x="3" y="2" width="10" height="12" rx="1.5"/><path d="M5.5 5.5h5M5.5 8h5M5.5 10.5h3"/></svg>',
    page: '<svg class="ic" ' + S + '><path d="M4 1.5h5.5l2.5 2.5v10.5H4z"/></svg>',
    draft: '<svg class="ic" ' + S + ' stroke-dasharray="2 1.5"><path d="M4 1.5h5.5l2.5 2.5v10.5H4z"/></svg>',
    chev: '<svg width="10" height="10" viewBox="0 0 10 10" aria-hidden="true"><path d="M2.5 3.5L5 6l2.5-2.5" fill="none" stroke="currentColor" stroke-width="1.4"/></svg>'
  };
  var NOTEBOOKS = [
    { id: 'gc', name: 'Graph Clustering', href: '#return' },
    { id: 'llm', name: 'How LLMs Work', href: '#research' }
  ];
  var KIND = {
    draft: function (p) { return 'Draft' + (p.to ? ' · for ' + p.to : ''); },
    revision: function () { return 'Revision to a page'; },
    chapter: function () { return 'Proposed chapter'; },
    aside: function (p) { return 'Set aside ' + p.date; },
    undone: function (p) { return 'Undone ' + p.date + (p.to ? ' · for ' + p.to : ''); }
  };

  function attrs(o) {
    return (o.when ? ' data-when="' + o.when + '"' : '') +
      (o.set ? ' data-set="' + o.set + '"' : '') +
      (o.scroll ? ' data-scroll="' + o.scroll + '"' : '');
  }
  function link(cls, o, inner) {
    return '<a class="' + cls + (o.cur ? ' cur' : '') + '" href="' + (o.href || '#') + '"' + attrs(o) +
      (o.cur ? ' aria-current="page"' : '') + '>' + inner + '</a>';
  }
  function counts(c) {
    if (!c) return '';
    if (typeof c === 'string') return '<span class="count">' + c + '</span>';
    return c.map(function (x) { return '<span class="count" data-when="' + x[0] + '">' + x[1] + '</span>'; }).join('');
  }

  // Amber count of items not in the book yet, on the open notebook's row; it scrolls to them.
  function pendingBadge(cfg) {
    if (!cfg.pending) return '';
    var c = cfg.pendCount || (cfg.pendWhen ? [[cfg.pendWhen, String(cfg.pending.length)]] : String(cfg.pending.length));
    if (typeof c === 'string') c = [[null, c]];
    return c.map(function (x) {
      return '<span class="pc" data-scroll=".side .pend" title="Not in the book yet"' +
        (x[0] ? ' data-when="' + x[0] + '"' : '') + '>' + x[1] + '</span>';
    }).join('');
  }

  function tree(cfg) {
    var t = '<div class="tree">';
    t += link('it util', { href: '#goals', cur: cfg.cur === 'goals' }, ICON.goal + '<span class="t">Goals</span>' + counts(cfg.goals));
    t += link('it util', { href: '#notes', cur: cfg.cur === 'notes' }, ICON.notes + '<span class="t">Sophia\'s notes</span>' + counts(cfg.notes));
    t += '<div class="sep"></div>';
    // When the current page is in a chapter, the other chapters start collapsed.
    var holds = function (ch) { return ch.pages.some(function (p) { return p.cur; }); };
    var focused = (cfg.chapters || []).length > 1 && (cfg.chapters || []).some(holds);
    (cfg.chapters || []).forEach(function (ch) {
      var open = !focused || holds(ch);
      t += '<div class="chg' + (open ? '' : ' closed') + '"' + attrs({ when: ch.when }) + '>' +
        '<div class="it ch"><button class="tri" aria-expanded="' + open + '" aria-label="Show or hide ' + ch.t + '">' + ICON.chev + '</button>' +
        '<a href="' + (cfg.home || '#return') + '"><span class="num">' + ch.n + '</span>' + ch.t + '</a></div><div class="pages">';
      ch.pages.forEach(function (p) { t += link('it pg', p, ICON.page + '<span class="t">' + p.t + '</span>'); });
      t += '</div></div>';
    });
    if (cfg.unfiled) {
      t += '<div class="unfiled"' + attrs({ when: cfg.unfiledWhen }) + '>';
      cfg.unfiled.forEach(function (p) { t += link('it pg top', p, ICON.page + '<span class="t">' + p.t + '</span>'); });
      t += '</div>';
    }
    if (cfg.empty) t += '<div class="it muted indent"' + attrs({ when: cfg.empty.when }) + '>' + cfg.empty.text + '</div>';
    if (cfg.pending) {
      t += '<div class="pend"' + attrs({ when: cfg.pendWhen }) + '><div class="sep"></div><div class="it subhead pendhead">Not in the book yet</div>';
      cfg.pending.forEach(function (p) {
        var cls = 'it pg ' + (p.kind === 'aside' ? 'aside' : 'draft');
        t += link(cls, p, ICON.draft + '<span class="t">' + p.t + '<span class="to">' + KIND[p.kind](p) + '</span></span>');
      });
      t += '</div>';
    }
    return t + '</div>';
  }

  function build(cfg) {
    var h = '<div class="search">' + ICON.search + 'Search notebooks</div>';
    h += '<div class="grp"><div class="h">Library <button class="plus" aria-label="New notebook">+</button></div>';
    if (cfg.emptyLib) h += '<div class="it muted"' + attrs({ when: cfg.emptyLib }) + '>No notebooks yet.</div>';
    NOTEBOOKS.forEach(function (nb) {
      var open = cfg.nb === nb.id;
      h += '<a class="nbk' + (open ? ' open' : '') + (open && cfg.cur === 'contents' ? ' cur' : '') + '" href="' +
        (open ? (cfg.home || nb.href) : nb.href) + '"' + attrs({ when: cfg.nbWhen }) + '>' +
        '<span class="tri' + (open ? '' : ' shut') + '">' + ICON.chev + '</span>' + ICON.book + '<span class="t">' + nb.name + '</span>' + (open ? pendingBadge(cfg) : '') + '</a>';
      if (open) h += tree(cfg);
    });
    return h + '</div>' + (cfg.foot || '');
  }

  var aside = { t: 'Choosing a threshold', kind: 'aside', date: 'Oct 16', href: '#return' };
  var ch1 = function (pages) { return { n: 1, t: 'Spectral methods', pages: pages }; };
  var fv = function (o) { var p = { t: FV, href: '#page' }; for (var k in o) p[k] = o[k]; return p; };

  var CONFIG = {
    library: {
      nbWhen: 'view:populated', emptyLib: 'view:first',
      foot: '<div class="side-foot" data-when="view:first"><div><span class="dot"></span>Claude Code · Claude subscription</div><div>Sophia won\'t switch to API billing without asking you.</div></div>'
    },
    research: { nb: 'llm', home: '#research', empty: { text: 'No pages yet. That\'s fine.' } },
    first: {
      nb: 'gc', goals: '1', notes: '3',
      chapters: [{ n: 1, t: 'Spectral methods', when: 'state:accepted;chap:spectral', pages: [fv({ href: '#first', scroll: '#f-art', cur: true })] }],
      unfiledWhen: 'state:accepted;chap:none', unfiled: [fv({ href: '#first', scroll: '#f-art', cur: true })],
      empty: { text: 'No pages yet.', when: 'state:pending,undone,deferred,rejected' },
      pendWhen: 'state:pending,undone,deferred', pendCount: [['state:pending,undone,deferred', '1']],
      pending: [
        { t: FV, kind: 'draft', to: 'Spectral methods', when: 'state:pending;chap:spectral', href: '#first', scroll: '#f-art', cur: true },
        { t: FV, kind: 'draft', to: 'no chapter', when: 'state:pending;chap:none', href: '#first', scroll: '#f-art', cur: true },
        { t: FV, kind: 'undone', date: 'Oct 14', to: 'Spectral methods', when: 'state:undone;chap:spectral', href: '#first', scroll: '#f-art', cur: true },
        { t: FV, kind: 'undone', date: 'Oct 14', when: 'state:undone;chap:none', href: '#first', scroll: '#f-art', cur: true },
        { t: FV, kind: 'aside', date: 'Oct 14', when: 'state:deferred', href: '#first', set: 'state:pending' }
      ]
    },
    page: { nb: 'gc', goals: '1', notes: '4', chapters: [ch1([fv({ set: 'mode:reading', cur: true })])], pending: [aside] },
    guided: { nb: 'gc', goals: '1', notes: '3', chapters: [ch1([fv({ cur: true })])], pendWhen: 'stop:done', pending: [aside] },
    revise: {
      nb: 'gc', goals: '1', notes: '4',
      chapters: [ch1([fv({ when: 'rev:1,2,stale' }), fv({ when: 'rev:accepted', cur: true })])],
      pendCount: [['rev:1,2,stale', '2'], ['rev:accepted', '1']],
      pending: [{ t: FV, kind: 'revision', when: 'rev:1,2,stale', href: '#revise', cur: true }, aside]
    },
    return: { nb: 'gc', cur: 'contents', goals: '1', notes: '4', chapters: [ch1([fv({})])], pending: [aside] },
    experiment: {
      nb: 'gc', goals: '1', notes: '4', chapters: [ch1([fv({})])],
      pending: [{ t: 'Bridge weight and the Fiedler vector', kind: 'draft', to: 'Spectral methods', href: '#experiment', cur: true }, aside]
    },
    contents: {
      nb: 'gc', cur: 'contents', home: '#contents', goals: '1', notes: '9',
      chapters: [
        ch1([fv({}), { t: 'Normalized cut and the random-walk Laplacian', href: '#problems' }]),
        { n: 2, t: 'Rounding the relaxation', when: 'struct:accepted', pages: [{ t: 'Choosing a threshold', href: '#contents' }, { t: 'When zero is the wrong threshold', href: '#contents' }] }
      ],
      unfiledWhen: 'struct:before,proposed',
      unfiled: [{ t: 'Choosing a threshold', href: '#contents' }, { t: 'When zero is the wrong threshold', href: '#contents' }],
      pendWhen: 'struct:proposed',
      pending: [{ t: 'Rounding the relaxation', kind: 'chapter', href: '#contents' }]
    },
    goals: {
      nb: 'gc', cur: 'goals', notes: '4',
      goals: [['g:tracking,proposed', '1'], ['g:met', '1 met']],
      chapters: [ch1([fv({})])], pending: [aside]
    },
    notes: { nb: 'gc', cur: 'notes', goals: '1', notes: '4', chapters: [ch1([fv({})])], pending: [aside] },
    problems: {
      nb: 'gc', goals: '1', notes: '4', chapters: [ch1([fv({})])],
      pending: [{ t: 'Normalized cut and the random-walk Laplacian', kind: 'draft', to: 'Spectral methods', href: '#problems', cur: true }],
      foot: '<div class="side-foot">' +
        '<div data-when="kind:engine"><span class="dot bad"></span>Claude Code · not responding</div>' +
        '<div data-when="kind:billing"><span class="dot warn"></span>Claude Code · signed out</div>' +
        '<div data-when="kind:save,source"><span class="dot"></span>Claude Code · Claude subscription</div></div>'
    }
  };

  window.SophiaSidebar = { build: build };

  document.querySelectorAll('.screen').forEach(function (screen) {
    var nav = screen.querySelector('nav.side');
    if (nav && CONFIG[screen.id]) nav.innerHTML = build(CONFIG[screen.id]);
  });

  // Chapter disclosure triangles.
  document.addEventListener('click', function (e) {
    var tri = e.target.closest('.ch .tri');
    if (!tri) return;
    var group = tri.closest('.chg');
    var closed = group.classList.toggle('closed');
    tri.setAttribute('aria-expanded', closed ? 'false' : 'true');
  });
})();
