-- Dioxus hook snippets for Rust files: type a hook's full name and pick it in
-- the completion menu (Enter) to get a small working example instead of just
-- the name. Tab / Shift+Tab move between the parts to fill in.
-- Not autosnippets like the Swift ones (configs/espanso_snippets.lua): those
-- would fire inside longer names (use_context in use_context_provider) and in
-- `use dioxus::prelude::{...}` imports.
local ls = require "luasnip"

local hooks = {
  -- state: let mut count = use_signal(|| 0); then count() / count += 1
  { "use_signal", "use_signal(|| ${1:0})" },
  -- derived value, recomputed when the signals it reads change
  { "use_memo", "use_memo(move || ${1:count() * 2})" },
  -- side effect, rerun when the signals it reads change
  -- (\\} is a literal } inside a placeholder)
  { "use_effect", 'use_effect(move || {\n\t${1:println!("count is {count\\}");}\n});' },
  -- async value: resource() is None until it finishes, then Some(value)
  { "use_resource", "use_resource(move || async move {\n\t${1:fetch_data().await}\n})" },
  -- async task with no value, started once
  { "use_future", "use_future(move || async move {\n\t${1}\n});" },
  -- share a value with every component below this one...
  { "use_context_provider", "use_context_provider(|| ${1:Signal::new(${2:0})});" },
  -- ...and read it there (same type as the provider's)
  { "use_context", "use_context::<${1:Signal<${2:i32}>}>()" },
  -- a value created once and kept across renders
  { "use_hook", "use_hook(|| ${1:value})" },
  -- an event handler you can pass to child components
  { "use_callback", "use_callback(move |${1:value}: ${2:i32}| {\n\t${3}\n})" },
}

local snippets = {}
for _, hook in ipairs(hooks) do
  local name, body = hook[1], hook[2]
  table.insert(snippets, ls.parser.parse_snippet({ trig = name, name = name, dscr = "Dioxus " .. name .. " example" }, body))
end
ls.add_snippets("rust", snippets)
