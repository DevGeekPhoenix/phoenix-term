-- ─────────────────────────────────────────────────────────────
--  Tell LazyVim to use the hand-rolled Phoenix Black & Gold theme.
--  The colorscheme itself lives at  ~/.config/nvim/colors/phoenix.lua
--  The lualine sub-theme lives at   ~/.config/nvim/lua/lualine/themes/phoenix.lua
-- ─────────────────────────────────────────────────────────────
return {
  -- LazyVim picks `opts.colorscheme` after all plugins are loaded.
  {
    "LazyVim/LazyVim",
    opts = { colorscheme = "phoenix" },
  },

  -- Subtler indent guide character; keeps the editor from looking busy
  -- against the gold accents.
  {
    "lukas-reineke/indent-blankline.nvim",
    opts = function(_, opts)
      opts.indent = opts.indent or {}
      opts.indent.char = "▏"
      return opts
    end,
  },

  -- Make lualine use the matching `phoenix` theme module.
  {
    "nvim-lualine/lualine.nvim",
    opts = function(_, opts)
      opts.options = opts.options or {}
      opts.options.theme = "phoenix"
      opts.options.section_separators   = { left = "", right = "" }
      opts.options.component_separators = { left = "│", right = "│" }
      return opts
    end,
  },
}
