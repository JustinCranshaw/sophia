// Chat-scope prototype harness (C2). Shared by the three prototypes; owned by the facilitator.
// Scenario states are addressed by hash: #s1, #s2, #s3, #s5, #s6, #s7, #s11a, #s11b, #s11c.
// Append "/sees" to open the diagnostic "What Sophia sees" inspector: #s2/sees.
// Elements use the mock's syntax: data-when="s:2,3;step:b" shows an element only when every
// clause matches the root (.proto) data attributes. data-set="step:b" changes a sub-state.
// data-init on .proto lists sub-state defaults that are restored whenever the scenario changes.
(function () {
  var root = document.querySelector('.proto');
  if (!root) return;

  function matches(spec) {
    return spec.split(';').every(function (clause) {
      var parts = clause.split(':');
      var key = parts[0].trim(), vals = parts[1].split(',').map(function (v) { return v.trim(); });
      return vals.indexOf(root.dataset[key]) >= 0;
    });
  }

  function render() {
    root.querySelectorAll('[data-when]').forEach(function (el) { el.hidden = !matches(el.dataset.when); });
    fit();
    root.querySelectorAll('[data-when]').forEach(function (el) { el.hidden = !matches(el.dataset.when); });
    document.querySelectorAll('[data-go]').forEach(function (b) {
      b.setAttribute('aria-pressed', b.dataset.go === root.dataset.s ? 'true' : 'false');
    });
    root.querySelectorAll('[data-pressed]').forEach(function (el) {
      el.setAttribute('aria-pressed', matches(el.dataset.pressed) ? 'true' : 'false');
    });
    var panel = document.querySelector('.sees-panel');
    if (panel) panel.hidden = root.dataset.sees !== 'on';
    document.querySelectorAll('[data-sees-toggle]').forEach(function (b) {
      b.setAttribute('aria-pressed', root.dataset.sees === 'on' ? 'true' : 'false');
    });
    // Panes open at their latest content unless a visible [data-anchor] asks to be shown.
    root.querySelectorAll('.pane').forEach(function (pane) {
      var anchor = Array.prototype.filter.call(pane.querySelectorAll('[data-anchor]'), function (a) {
        return a.offsetParent !== null;
      })[0];
      if (anchor) pane.scrollTop += anchor.getBoundingClientRect().top - pane.getBoundingClientRect().top - stickyHead(pane) - 8;
      else if (pane.classList.contains('chat')) pane.scrollTop = pane.scrollHeight;
      else pane.scrollTop = 0;
    });
  }

  // Height of a sticky header (bookhead/chathead) at the top of a pane, so anchors land below it.
  function stickyHead(pane) {
    var h = pane.querySelector(':scope > .bookhead, :scope > .chathead');
    return h && h.offsetParent !== null ? h.offsetHeight : 0;
  }

  // Size the window to the viewport below the strip and the "Look at" line, whatever their height.
  function fit() {
    var bar = document.querySelector('.proto-bar'), what = document.querySelector('.proto-what');
    var top = (bar ? bar.offsetHeight : 0) + (what ? what.offsetHeight : 0);
    document.documentElement.style.setProperty('--proto-top', top + 'px');
    document.documentElement.style.setProperty('--proto-bar', (bar ? bar.offsetHeight : 0) + 'px');
  }

  function applyInit() {
    (root.dataset.init || '').split(';').forEach(function (pair) {
      if (!pair.trim()) return;
      var p = pair.split(':');
      root.dataset[p[0].trim()] = p[1].trim();
    });
  }

  function fromHash() {
    var h = (location.hash || '').replace(/^#/, '');
    var parts = h.split('/');
    var s = (parts[0] || '').replace(/^s/, '') || root.dataset.first || '1';
    if (s !== root.dataset.s) applyInit();
    root.dataset.s = s;
    root.dataset.sees = parts.indexOf('sees') > 0 ? 'on' : 'off';
    render();
  }

  function go(s, sees) {
    location.hash = 's' + s + (sees ? '/sees' : '');
  }

  document.addEventListener('click', function (e) {
    var g = e.target.closest('[data-go]');
    if (g) { e.preventDefault(); go(g.dataset.go, root.dataset.sees === 'on'); return; }
    var t = e.target.closest('[data-sees-toggle]');
    if (t) { e.preventDefault(); go(root.dataset.s, root.dataset.sees !== 'on'); return; }
    var setter = e.target.closest('[data-set]');
    if (setter) {
      e.preventDefault();
      setter.dataset.set.split(';').forEach(function (pair) {
        var p = pair.split(':');
        root.dataset[p[0].trim()] = p[1].trim();
      });
      render();
    }
  });

  addEventListener('hashchange', fromHash);
  addEventListener('resize', function () { fit(); });
  fromHash();
})();
