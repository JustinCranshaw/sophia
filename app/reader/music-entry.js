// Bundler input for vendor/abcjs.min.js (see vendor.py). Only abcjs's renderer, from the
// package's own sources: the published "basic" build also carries the synth, which can
// fetch soundfonts, and reading notation needs neither audio nor a network.
// Rendering is Sophia's plain script, Reader/music.js.
window.ABCJS = {
  renderAbc: require("abcjs/src/api/abc_tunebook_svg"),
  numberOfTunes: require("abcjs/src/api/abc_tunebook").numberOfTunes
};
