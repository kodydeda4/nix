; inherits: rust

; rsx! (Dioxus): the whole macro is its own `rsx` tree (configs/rsx.lua), so
; every token tree here is rsx. Like Zed's (zed/rsx/highlights.scm), after the
; dioxus-rsx VS Code grammar: `div {` is an element, `class:` an attribute.
; rust-analyzer's tokens cover these as methods and consts, so each pattern
; here is set above them (priority 130; theirs are 125-128); the rest of the
; macro keeps rust-analyzer's colors (components, calls, types).

; Keywords: a token tree has no Rust grammar, and rust-analyzer calls
; `for` / `in` methods
((token_tree
  [
    "for"
    "if"
    "match"
    "while"
    "loop"
    "return"
    "break"
    "continue"
    "let"
    "async"
    "await"
    "const"
    "static"
    "unsafe"
    "as"
  ] @keyword)
  (#set! priority 130))

; Elements
((token_tree
  (identifier) @tag
  .
  (token_tree
    .
    "{"))
  (#lua-match? @tag "^[a-z_]")
  (#set! priority 130))

; ...but not an expression before a block: `if show {`, `= value {`,
; `.field {`, `..spread, {children}`
((token_tree
  [
    ".."
    "if"
    "match"
    "while"
    "return"
    "break"
    "="
    "=="
    "!="
    "<"
    "<="
    ">"
    ">="
    "&&"
    "||"
    "!"
    "&"
    "*"
    "-"
    "."
  ]
  .
  (identifier) @variable
  .
  (token_tree
    .
    "{"))
  (#lua-match? @variable "^[a-z_]")
  (#set! priority 130))

((token_tree
  (identifier) @_in
  .
  (identifier) @variable
  .
  (token_tree
    .
    "{"))
  (#eq? @_in "in")
  (#lua-match? @variable "^[a-z_]")
  (#set! priority 130))

; Anchors skip punctuation, so an element match can also be `name! {`,
; `name => {`, `value, {children}` or `name: {`: put those back
((token_tree
  (identifier) @function.macro
  .
  "!")
  (#set! priority 130))

((token_tree
  (identifier) @variable
  .
  [
    "=>"
    ","
    ";"
    "?"
  ])
  (#lua-match? @variable "^[a-z_]")
  (#set! priority 130))

; Attributes, also ones named like a keyword: `as:`
((token_tree
  (identifier) @tag.attribute
  .
  ":")
  (#set! priority 130))

((token_tree
  [
    "as"
    "async"
    "default"
    "for"
    "loop"
    "static"
    "type"
  ] @tag.attribute
  .
  ":")
  (#set! priority 130))

; Closure parameters: `move |e|`, `move |e: Event<MouseData>|`
((token_tree
  (identifier) @variable.parameter
  .
  "|")
  (#lua-match? @variable.parameter "^[a-z_]")
  (#set! priority 130))

((token_tree
  "|"
  .
  (identifier) @variable.parameter
  .
  ":")
  (#lua-match? @variable.parameter "^[a-z_]")
  (#set! priority 130))

; Keywords a token tree leaves as identifiers, over the element pattern:
; `async move {`, `} else {`
(((identifier) @keyword
  (#any-of? @keyword "move" "ref" "dyn" "extern" "raw" "else" "in" "yield"))
  (#set! priority 130))
