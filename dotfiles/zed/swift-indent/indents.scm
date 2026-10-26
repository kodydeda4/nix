; Swift indentation in Zed's own format. The Swift extension ships nvim's
; (@indent.begin, @indent.branch...), which Zed ignores apart from the
; bracket rules; ./apply copies this over it (rerun after the extension
; updates).

(_ "{" "}" @end) @indent
(_ "(" ")" @end) @indent
(_ "[" "]" @end) @indent
(_ "<" ">" @end) @indent

; case / default line up with their switch (config.toml)
(switch_statement) @start.switch
