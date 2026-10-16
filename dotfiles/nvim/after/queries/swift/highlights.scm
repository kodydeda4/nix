;extends
; Extra Swift highlight groups so the xcode_dark theme can color these like Xcode.

; struct / class / enum / actor / protocol names where they're declared
(class_declaration
  name: (type_identifier) @type.definition)

(protocol_declaration
  name: (type_identifier) @type.definition)

; the type being extended: extension ActivityHistoryFeature.State.Tab
(class_declaration
  "extension"
  (user_type
    (type_identifier) @type.definition)
  (#set! priority 130))

; stored and computed properties declared in a type
(class_body
  (property_declaration
    (pattern
      (simple_identifier) @variable.member.definition)))

; enum cases where they're declared (case view, case login): declaration color,
; over sourcekit's enumMember token
(enum_entry
  (simple_identifier) @variable.member.definition
  (#set! priority 130))

; argument labels: plain text until sourcekit resolves the call; then
; lspconfig.lua colors them like the callee (CGSize(width:), LabelState(title:))
(value_argument
  name: (value_argument_label
    (simple_identifier) @label.argument))

; calling a capitalized name constructs a type (VStack(...), Text("Hi")):
; Xcode colors it as a type, not a function call
(call_expression
  (simple_identifier) @constructor
  (#match? @constructor "^[A-Z]"))

; Attributes, as a fallback for when sourcekit isn't running: with it, its
; semantic tokens decide (macro vs property wrapper, Apple vs not; lspconfig.lua
; colors the "@" to match). Later patterns win: project first, then Apple's,
; then built-ins.

; anything not Apple's: your code and packages (@Dependency, @Shared, @Reducer...)
(attribute
  "@" @attribute.project
  (user_type
    (type_identifier) @_name)
  (#match? @_name "^[A-Z]"))

(attribute
  (user_type
    (type_identifier) @attribute.project)
  (#match? @attribute.project "^[A-Z]"))

; Apple's property wrappers and attribute types: @State, @Bindable, @MainActor...
(attribute
  "@" @attribute.type
  (user_type
    (type_identifier) @_name)
  (#any-of? @_name
    "State" "Binding" "Bindable" "Environment" "EnvironmentObject" "ObservedObject"
    "StateObject" "Published" "AppStorage" "SceneStorage" "FocusState" "FocusedValue"
    "GestureState" "Namespace" "ScaledMetric" "Query" "FetchRequest" "SectionedFetchRequest"
    "MainActor" "ViewBuilder" "ToolbarContentBuilder" "SceneBuilder" "CommandsBuilder"
    "UIApplicationDelegateAdaptor" "NSApplicationDelegateAdaptor" "WKApplicationDelegateAdaptor"
    "ResultBuilder" "TaskLocal" "Attribute" "Relationship" "Transient" "Unique"))

(attribute
  (user_type
    (type_identifier) @attribute.type)
  (#any-of? @attribute.type
    "State" "Binding" "Bindable" "Environment" "EnvironmentObject" "ObservedObject"
    "StateObject" "Published" "AppStorage" "SceneStorage" "FocusState" "FocusedValue"
    "GestureState" "Namespace" "ScaledMetric" "Query" "FetchRequest" "SectionedFetchRequest"
    "MainActor" "ViewBuilder" "ToolbarContentBuilder" "SceneBuilder" "CommandsBuilder"
    "UIApplicationDelegateAdaptor" "NSApplicationDelegateAdaptor" "WKApplicationDelegateAdaptor"
    "ResultBuilder" "TaskLocal" "Attribute" "Relationship" "Transient" "Unique"))

; Apple's macros: @Observable, @Model, @Entry, @Test...
(attribute
  "@" @attribute.macro
  (user_type
    (type_identifier) @_name)
  (#any-of? @_name "Observable" "ObservationIgnored" "ObservationTracked" "Model" "Entry" "Previewable" "Test" "Suite"))

(attribute
  (user_type
    (type_identifier) @attribute.macro)
  (#any-of? @attribute.macro "Observable" "ObservationIgnored" "ObservationTracked" "Model" "Entry" "Previewable" "Test" "Suite"))

; @objc, @available, @main, @discardableResult: built-in attributes
(attribute
  "@" @attribute.builtin
  (user_type
    (type_identifier) @_name)
  (#match? @_name "^([a-z]|unchecked)"))

(attribute
  (user_type
    (type_identifier) @attribute.builtin)
  (#match? @attribute.builtin "^([a-z]|unchecked)")
  (#set! priority 130))

; @escaping / @autoclosure are keywords in Xcode
[
  "@escaping"
  "@autoclosure"
] @keyword.modifier

; .task in .send(.task): an enum case / static member
(prefix_expression
  operation: "."
  target: (simple_identifier) @variable.member.implicit)

; self and Self are keywords in Xcode; keep the language server from recoloring them
((simple_identifier) @variable.builtin
  (#eq? @variable.builtin "self")
  (#set! priority 130))

((type_identifier) @variable.builtin
  (#eq? @variable.builtin "Self")
  (#set! priority 130))

((simple_identifier) @variable.builtin
  (#eq? @variable.builtin "Self")
  (#set! priority 130))

; init is a keyword in Xcode: init(...) declarations and .init / super.init calls
(init_declaration
  "init" @keyword.function
  (#set! priority 130))

((simple_identifier) @keyword.function
  (#eq? @keyword.function "init")
  (#set! priority 130))

; key paths: sourcekit colors resolved ones (your \.stageBalance teal); the
; ones it can't resolve, like macro-generated case paths (\.list), stay purple
(navigation_expression
  (key_path_expression)
  (navigation_suffix
    (simple_identifier) @variable.member.keypath))

; trailing closure labels: } actions: { ... } message: {
(call_suffix
  (simple_identifier) @label.trailing
  (#set! priority 130))

; parameter names where a function / init declares them: init(store: ...)
; (closure parameters, { state, action in }, stay plain)
(parameter
  (simple_identifier) @variable.parameter.definition)

; with two names, only the outer one is a declaration color; the inner name is
; plain: (_ application: ...), (didFinishLaunchingWithOptions launchOptions: ...)
(parameter
  external_name: (simple_identifier)
  name: (simple_identifier) @variable.parameter)

; @Sendable: a keyword in Xcode
(attribute
  "@" @attribute.sendable
  (user_type
    (type_identifier) @_name)
  (#eq? @_name "Sendable")
  (#set! priority 130))

(attribute
  (user_type
    (type_identifier) @attribute.sendable)
  (#eq? @attribute.sendable "Sendable")
  (#set! priority 130))

; @main is a keyword in Xcode (after the built-in attribute rules, so it wins)
(attribute
  "@" @keyword.modifier
  (user_type
    (type_identifier) @_name)
  (#eq? @_name "main")
  (#set! priority 130))

(attribute
  (user_type
    (type_identifier) @keyword.modifier)
  (#eq? @keyword.modifier "main")
  (#set! priority 130))

; Any is a keyword in Xcode
((user_type
  (type_identifier) @keyword.type)
  (#eq? @keyword.type "Any")
  (#set! priority 130))

; #filePath, #file, #line, #function...: keywords in Xcode
((special_literal) @constant.builtin
  (#set! priority 130))

; #if DEBUG: the condition is preprocessor-colored like #if
(directive
  (simple_identifier) @keyword.directive)

; top-level declarations (let package = Package(...)); locals stay plain
(source_file
  (property_declaration
    (pattern
      (simple_identifier) @variable.member.definition)))
