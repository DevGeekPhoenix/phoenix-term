return {
  {
    "LazyVim/LazyVim",
    opts = { colorscheme = "phoenix" },
  },

  {
    "lukas-reineke/indent-blankline.nvim",
    opts = function(_, opts)
      opts.indent = opts.indent or {}
      opts.indent.char = "▏"
      return opts
    end,
  },

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
