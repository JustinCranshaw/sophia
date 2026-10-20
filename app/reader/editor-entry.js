// Bundler input for vendor/codemirror.min.js (see vendor.py). Only the CodeMirror
// pieces the page editor uses are exposed, as one global; the editor itself is
// Sophia's plain script, Reader/editor.js.
import { EditorState, EditorSelection, StateEffect, StateField, RangeSetBuilder, Prec } from "@codemirror/state";
import { EditorView, Decoration, ViewPlugin, WidgetType, keymap, drawSelection } from "@codemirror/view";
import { defaultKeymap, history, historyKeymap, undo, redo, undoDepth, redoDepth, cursorLineDown, cursorLineUp } from "@codemirror/commands";
import { syntaxHighlighting, HighlightStyle, syntaxTree } from "@codemirror/language";
import { markdownLanguage } from "@codemirror/lang-markdown";
import { tags } from "@lezer/highlight";

window.CM = {
  EditorState, EditorSelection, StateEffect, StateField, RangeSetBuilder, Prec,
  EditorView, Decoration, ViewPlugin, WidgetType, keymap, drawSelection,
  defaultKeymap, history, historyKeymap, undo, redo, undoDepth, redoDepth, cursorLineDown, cursorLineUp,
  syntaxHighlighting, HighlightStyle, syntaxTree, markdownLanguage, tags
};
