local p = {
  bg          = "#111418",
  bg_panel    = "#0c0f11",
  bg_elev     = "#1c2027",
  fg          = "#bec6d0",
  fg_disabled = "#475262",
  gold        = "#c7910c",
  green       = "#00a884",
  cyan        = "#11B7D4",
  pink        = "#d46ec0",
  red         = "#E35535",
  teal        = "#38c7bd",
}

return {
  normal = {
    a = { fg = p.bg,   bg = p.gold,     gui = "bold" },
    b = { fg = p.gold, bg = p.bg_elev },
    c = { fg = p.fg,   bg = p.bg_panel },
  },
  insert   = { a = { fg = p.bg, bg = p.green,  gui = "bold" }, b = { fg = p.green,  bg = p.bg_elev } },
  visual   = { a = { fg = p.bg, bg = p.pink,   gui = "bold" }, b = { fg = p.pink,   bg = p.bg_elev } },
  replace  = { a = { fg = p.bg, bg = p.red,    gui = "bold" }, b = { fg = p.red,    bg = p.bg_elev } },
  command  = { a = { fg = p.bg, bg = p.cyan,   gui = "bold" }, b = { fg = p.cyan,   bg = p.bg_elev } },
  terminal = { a = { fg = p.bg, bg = p.teal,   gui = "bold" }, b = { fg = p.teal,   bg = p.bg_elev } },
  inactive = {
    a = { fg = p.fg_disabled, bg = p.bg_panel },
    b = { fg = p.fg_disabled, bg = p.bg_panel },
    c = { fg = p.fg_disabled, bg = p.bg_panel },
  },
}
