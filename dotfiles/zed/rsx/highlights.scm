; rsx! (Dioxus) highlights, after Zed's Rust ones (packages.nix: zed-editor
; puts rust/highlights.scm first). This layer is a whole rsx! macro
; (zed.patch), so every token tree in it is rsx: the Rust patterns only see its
; tokens. These add what the dioxus-rsx VS Code grammar does: `div {` is an
; element, `Link {` a component (already a type), `class:` an attribute.
; Zed has to be rebuilt for a change here: try it with try.lua first.

; Rust keywords that a token tree leaves as identifiers
((identifier) @keyword
  (#any-of? @keyword "dyn" "extern" "move" "raw" "ref"))

((identifier) @keyword.control
  (#any-of? @keyword.control "else" "in" "yield"))

; Calls, methods and fields
(token_tree
  (identifier) @function
  .
  (token_tree
    .
    "("))

(token_tree
  "."
  .
  (identifier) @property)

(token_tree
  "."
  .
  (identifier) @function.method
  .
  (token_tree
    .
    "("))

(token_tree
  "."
  .
  (identifier) @keyword.control
  (#eq? @keyword.control "await"))

((token_tree
  (identifier) @type
  .
  (token_tree
    .
    "("))
  (#match? @type "^[A-Z]"))

; Elements
((token_tree
  (identifier) @tag
  .
  (token_tree
    .
    "{"))
  (#match? @tag "^[a-z_]"))

; ...but not an expression before a block: `if show {`, `= value {`,
; `.field {`, `..spread, {children}`
(token_tree
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
    "{")
  (#match? @variable "^[a-z_]"))

((token_tree
  (identifier) @_in
  .
  (identifier) @variable
  .
  (token_tree
    .
    "{"))
  (#eq? @_in "in")
  (#match? @variable "^[a-z_]"))

; Anchors skip punctuation, so an element match can also be `name! {`,
; `name => {`, `value, {children}` or `name: {`: put those back.
(token_tree
  (identifier) @function.special
  .
  "!" @function.special)

(token_tree
  (identifier) @variable
  .
  [
    "=>"
    ","
    ";"
    "?"
  ]
  (#match? @variable "^[a-z_]"))

; Attributes, also ones named like a keyword: `as:`
(token_tree
  (identifier) @property
  .
  ":")

(token_tree
  [
    "as"
    "async"
    "default"
    "for"
    "loop"
    "static"
    "type"
  ] @property
  .
  ":")

; Closure parameters: `move |e|`, `move |e: Event<MouseData>|`
((token_tree
  (identifier) @variable.parameter
  .
  "|")
  (#match? @variable.parameter "^[a-z_]"))

((token_tree
  "|"
  .
  (identifier) @variable.parameter
  .
  ":")
  (#match? @variable.parameter "^[a-z_]"))

; Keywords again, over the element pattern: `async move {`, `} else {`
((identifier) @keyword
  (#any-of? @keyword "dyn" "extern" "move" "raw" "ref"))

((identifier) @keyword.control
  (#any-of? @keyword.control "else" "in" "yield"))
