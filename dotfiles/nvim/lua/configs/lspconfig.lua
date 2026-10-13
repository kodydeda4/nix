require("nvchad.configs.lspconfig").defaults()

-- sourcekit: Swift (Apple's sourcekit-lsp; with buildServer.json from
-- xcode-build-server it understands Xcode projects too)
local servers = { "html", "cssls", "sourcekit" }
vim.lsp.enable(servers)

-- read :h vim.lsp.config for changing options of lsp servers 
