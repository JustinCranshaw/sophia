// Sophia UI mock: screen routing, per-screen state, and a few live interactions.
(function () {
  var screens = Array.prototype.slice.call(document.querySelectorAll('.screen'));

  // An element with data-when="state:a,b;rev:2" is shown only when every clause
  // matches its screen's data attributes. data-pressed uses the same syntax for aria-pressed.
  function matches(screen, spec) {
    return spec.split(';').every(function (clause) {
      var parts = clause.split(':');
      var key = parts[0].trim(), vals = parts[1].split(',').map(function (v) { return v.trim(); });
      return vals.indexOf(screen.dataset[key]) >= 0;
    });
  }

  function render(screen) {
    screen.querySelectorAll('[data-when]').forEach(function (el) {
      el.hidden = !matches(screen, el.dataset.when);
    });
    screen.querySelectorAll('[data-pressed]').forEach(function (el) {
      el.setAttribute('aria-pressed', matches(screen, el.dataset.pressed) ? 'true' : 'false');
    });
    screen.querySelectorAll('.states').forEach(function (bar) {
      var key = bar.dataset.key;
      bar.querySelectorAll('button').forEach(function (b) {
        b.setAttribute('aria-pressed', screen.dataset[key] === b.dataset.val ? 'true' : 'false');
      });
    });
    screen.querySelectorAll('[data-bind]').forEach(function (el) { el.value = screen.dataset[el.dataset.bind]; });
    // Conversations open at their latest message.
    screen.querySelectorAll('.chat').forEach(function (c) { c.scrollTop = c.scrollHeight; });
  }

  function apply(screen, setSpec) {
    setSpec.split(';').forEach(function (pair) {
      var p = pair.split(':');
      screen.dataset[p[0].trim()] = p[1].trim();
    });
    render(screen);
  }

  function show() {
    var id = (location.hash || '#overview').slice(1);
    var target = screens.filter(function (s) { return s.id === id; })[0];
    if (!target) return;
    screens.forEach(function (s) { s.hidden = s !== target; });
    document.querySelectorAll('.nav a').forEach(function (a) {
      if (a.getAttribute('href') === '#' + id) a.setAttribute('aria-current', 'page');
      else a.removeAttribute('aria-current');
    });
    render(target);
    window.scrollTo(0, 0);
  }

  document.addEventListener('click', function (e) {
    var screen = e.target.closest('.screen');
    if (!screen) return;
    var stateBtn = e.target.closest('.states button');
    if (stateBtn) { apply(screen, stateBtn.closest('.states').dataset.key + ':' + stateBtn.dataset.val); return; }
    var setter = e.target.closest('[data-set]');
    if (setter) { e.preventDefault(); apply(screen, setter.dataset.set); return; }
    var scroller = e.target.closest('[data-scroll]');
    if (scroller) {
      e.preventDefault();
      var t = screen.querySelector(scroller.dataset.scroll);
      if (t) t.scrollIntoView({ behavior: 'smooth', block: 'center' });
      return;
    }
    var del = e.target.closest('[data-del]');
    if (del) {
      var note = del.closest('.note, .note2');
      note.hidden = true;
      var toast = screen.querySelector('.toast');
      toast.hidden = false;
      toast.querySelector('button').onclick = function () { note.hidden = false; toast.hidden = true; };
      clearTimeout(toast._t);
      toast._t = setTimeout(function () { toast.hidden = true; }, 6000);
    }
  });

  document.addEventListener('change', function (e) {
    var el = e.target.closest('[data-bind]');
    if (el) apply(el.closest('.screen'), el.dataset.bind + ':' + el.value);
  });

  addEventListener('hashchange', show);
  screens.forEach(render);
  show();

  // ---- Experiment: Fiedler vector of two triangles joined by a bridge of weight w ----
  function fiedler(w) {
    var n = 6, A = [], i, j;
    for (i = 0; i < n; i++) { A.push([0, 0, 0, 0, 0, 0]); }
    [[0, 1, 1], [0, 2, 1], [1, 2, 1], [3, 4, 1], [3, 5, 1], [4, 5, 1], [2, 3, w]].forEach(function (e) {
      A[e[0]][e[1]] = A[e[1]][e[0]] = e[2];
    });
    var L = A.map(function (row, r) {
      var d = row.reduce(function (s, x) { return s + x; }, 0);
      return row.map(function (x, c) { return (r === c ? d : 0) - x; });
    });
    // Cyclic Jacobi eigenvalue iteration for a small symmetric matrix.
    var V = L.map(function (_, r) { return L.map(function (_, c) { return r === c ? 1 : 0; }); });
    for (var sweep = 0; sweep < 60; sweep++) {
      for (var p = 0; p < n; p++) for (var q = p + 1; q < n; q++) {
        if (Math.abs(L[p][q]) < 1e-12) continue;
        var th = (L[q][q] - L[p][p]) / (2 * L[p][q]);
        var t = (th >= 0 ? 1 : -1) / (Math.abs(th) + Math.sqrt(th * th + 1));
        var c = 1 / Math.sqrt(t * t + 1), s = t * c, k;
        for (k = 0; k < n; k++) {
          var lkp = L[k][p], lkq = L[k][q];
          L[k][p] = c * lkp - s * lkq; L[k][q] = s * lkp + c * lkq;
        }
        for (k = 0; k < n; k++) {
          var lpk = L[p][k], lqk = L[q][k];
          L[p][k] = c * lpk - s * lqk; L[q][k] = s * lpk + c * lqk;
        }
        for (k = 0; k < n; k++) {
          var vkp = V[k][p], vkq = V[k][q];
          V[k][p] = c * vkp - s * vkq; V[k][q] = s * vkp + c * vkq;
        }
      }
    }
    var order = [0, 1, 2, 3, 4, 5].sort(function (a, b) { return L[a][a] - L[b][b]; });
    var idx = order[1];
    var vec = V.map(function (row) { return row[idx]; });
    if (vec[0] < 0) vec = vec.map(function (x) { return -x; });
    return { lambda: L[idx][idx], vec: vec };
  }

  var slider = document.getElementById('bridge');
  if (slider) {
    var out = document.getElementById('bridge-out');
    var bars = document.getElementById('bars');
    var lam = document.getElementById('lambda');
    var update = function () {
      var w = parseFloat(slider.value), r = fiedler(w);
      out.textContent = w.toFixed(2);
      lam.textContent = r.lambda.toFixed(2);
      bars.innerHTML = r.vec.map(function (x, k) {
        var h = Math.round(Math.abs(x) * 200), up = x >= 0;
        return '<g transform="translate(' + (30 + k * 52) + ',0)">' +
          '<rect x="0" y="' + (up ? 130 - h : 130) + '" width="34" height="' + h + '" rx="3" fill="' + (up ? '#2F4FB3' : '#E08A3C') + '"/>' +
          '<text x="17" y="' + (up ? 124 - h : 146 + h) + '" text-anchor="middle" font-size="11" fill="#3C4048">' + (x >= 0 ? '+' : '−') + Math.abs(x).toFixed(2) + '</text>' +
          '<text x="17" y="262" text-anchor="middle" font-size="11" fill="#5B5F68">v' + (k + 1) + '</text></g>';
      }).join('') + '<line x1="20" x2="340" y1="130" y2="130" stroke="#C9CDD4"/>';
    };
    slider.addEventListener('input', update);
    update();
  }
})();
