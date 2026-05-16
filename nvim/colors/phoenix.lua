-- ─────────────────────────────────────────────────────────────
--  Phoenix Theme · Black & Gold — for Neovim
--  Palette and scope mappings ported from the canonical VS Code
--  source (BeardedBear/bearded-theme, dist/vscode/themes/
--  bearded-theme-black-&-gold.json) — built directly from the
--  TypeScript generator, not from the Zed port.
-- ─────────────────────────────────────────────────────────────

vim.cmd("hi clear")
if vim.fn.exists("syntax_on") == 1 then vim.cmd("syntax reset") end
vim.opt.termguicolors = true
vim.g.colors_name = "phoenix"

-- ── Palette (canonical) ───────────────────────────────────────
local p = {
  -- backgrounds
  bg          = "#111418",   -- editor.background
  bg_terminal = "#0f1215",   -- panel.background / terminal.background
  bg_panel    = "#0c0f11",   -- sidebar, activity bar, tab inactive
  bg_elev     = "#1c2027",   -- editorWidget, notifications, menu
  bg_subtle   = "#161a1f",   -- input
  bg_select   = "#262d36",   -- suggest widget selected
  bg_active   = "#31384573", -- list.activeSelection (approximated solid)
  bg_active_solid = "#1f2530",
  bg_titlebar = "#060708",
  border      = "#040506",
  border_mid  = "#262d36",
  focus_border = "#3b4654",

  -- foregrounds
  fg          = "#bec6d0",   -- editor.foreground
  fg_ui       = "#a0acbb",   -- foreground (UI)
  fg_dim      = "#85929e",   -- active line number
  fg_disabled = "#475262",   -- inactive tab fg, indent active
  fg_faint    = "#343a43",   -- line number inactive

  -- accents (the Phoenix "blackColors" palette, verbatim)
  gold        = "#c7910c",
  gold_b      = "#d39600",   -- terminal bright yellow
  orange      = "#d4770c",
  red         = "#E35535",
  red_b       = "#ff4319",
  salmon      = "#c62f52",   -- variable
  pink        = "#d46ec0",
  green       = "#00a884",
  teal        = "#38c7bd",   -- keyword.function / storage / variable.defaultLibrary
  cyan        = "#11B7D4",   -- function, tag, namespace
  cyan_b      = "#00c3e5",
  cyan_bb     = "#12edde",   -- terminal bright cyan
  purple      = "#a85ff1",   -- type, enum member
  blue_alt    = "#3585bb",   -- entity.name.type (deeper class blue)

  -- semi-transparent (precomputed against bg_terminal where useful)
  cursorline  = "#15181c",   -- editor.lineHighlightBackground (#c7910c0f over #111418)
  selection   = "#473812",   -- editor.selectionBackground (#c7910c4d over #0f1215)
  match       = "#3a2f12",   -- find match
  match_curr  = "#c7910c",
  bracket_bg  = "#473812",
  bracket_brd = "#7a5e1b",
  indent      = "#202730",   -- editorIndentGuide.background1 (#47526233 over bg)
  indent_act  = "#475262",   -- editorIndentGuide.activeBackground1
  punct       = "#7c8392",
  comment     = "#475262",
}

local function hi(g, s) vim.api.nvim_set_hl(0, g, s) end

-- ── Core editor ───────────────────────────────────────────────
hi("Normal",       { fg = p.fg, bg = p.bg })
hi("NormalNC",     { fg = p.fg, bg = p.bg })
hi("NormalFloat",  { fg = p.fg, bg = p.bg_elev })
hi("FloatBorder",  { fg = p.gold, bg = p.bg_elev })
hi("FloatTitle",   { fg = p.gold, bg = p.bg_elev, bold = true })
hi("WinSeparator", { fg = p.border, bg = p.bg })
hi("VertSplit",    { fg = p.border, bg = p.bg })

hi("CursorLine",   { bg = p.cursorline })
hi("CursorColumn", { bg = p.cursorline })
hi("CursorLineNr", { fg = p.gold, bold = true })
hi("LineNr",       { fg = p.fg_faint })
hi("LineNrAbove",  { fg = p.fg_faint })
hi("LineNrBelow",  { fg = p.fg_faint })
hi("SignColumn",   { bg = p.bg })
hi("FoldColumn",   { fg = p.fg_disabled, bg = p.bg })
hi("Folded",       { fg = p.fg_ui, bg = p.bg_elev })
hi("ColorColumn",  { bg = p.bg_subtle })

hi("Cursor",       { fg = p.bg, bg = p.gold })
hi("TermCursor",   { fg = p.bg, bg = p.gold })
hi("MatchParen",   { fg = p.gold, bg = p.bracket_bg, bold = true })
hi("Search",       { fg = p.fg, bg = p.match })
hi("IncSearch",    { fg = p.bg, bg = p.match_curr, bold = true })
hi("CurSearch",    { fg = p.bg, bg = p.match_curr, bold = true })
hi("Visual",       { bg = p.selection })
hi("VisualNOS",    { bg = p.selection })
hi("Substitute",   { fg = p.bg, bg = p.orange })

hi("Pmenu",        { fg = p.fg, bg = p.bg_elev })
hi("PmenuSel",     { fg = p.gold, bg = p.bg_select, bold = true })
hi("PmenuSbar",    { bg = p.bg_elev })
hi("PmenuThumb",   { bg = p.fg_disabled })
hi("PmenuMatch",   { fg = p.gold, bold = true })
hi("PmenuMatchSel",{ fg = p.gold, bg = p.bg_select, bold = true })
hi("WildMenu",     { fg = p.gold, bg = p.bg_elev, bold = true })

hi("StatusLine",   { fg = p.fg, bg = p.bg })
hi("StatusLineNC", { fg = p.fg_disabled, bg = p.bg })
hi("TabLine",      { fg = p.fg_disabled, bg = p.bg_panel })
hi("TabLineFill",  { bg = p.bg_panel })
hi("TabLineSel",   { fg = p.fg, bg = p.bg, bold = true })
hi("WinBar",       { fg = p.fg_ui, bg = p.bg })
hi("WinBarNC",     { fg = p.fg_disabled, bg = p.bg })

hi("ModeMsg",      { fg = p.gold, bold = true })
hi("MoreMsg",      { fg = p.green })
hi("ErrorMsg",     { fg = p.red, bold = true })
hi("WarningMsg",   { fg = p.orange, bold = true })
hi("Question",     { fg = p.cyan })
hi("Title",        { fg = p.gold, bold = true })
hi("Directory",    { fg = p.cyan })
hi("SpecialKey",   { fg = p.fg_disabled })
hi("NonText",      { fg = p.indent })
hi("Whitespace",   { fg = p.indent })
hi("EndOfBuffer",  { fg = p.bg })
hi("Conceal",      { fg = p.fg_disabled })
hi("MsgArea",      { fg = p.fg, bg = p.bg })
hi("MsgSeparator", { fg = p.border, bg = p.bg_elev })

-- ── Legacy syntax (fallback for non-treesitter) ──────────────
hi("Comment",      { fg = p.comment, italic = true })
hi("Constant",     { fg = p.red })
hi("String",       { fg = p.green })
hi("Character",    { fg = p.red })
hi("Number",       { fg = p.orange })           -- VS Code: constant.numeric → orange
hi("Boolean",      { fg = p.red, italic = true })
hi("Float",        { fg = p.orange })

hi("Identifier",   { fg = p.fg })
hi("Function",     { fg = p.cyan })

hi("Statement",    { fg = p.gold })
hi("Conditional",  { fg = p.gold })
hi("Repeat",       { fg = p.gold })
hi("Label",        { fg = p.gold })
hi("Operator",     { fg = p.gold })
hi("Keyword",      { fg = p.gold })
hi("Exception",    { fg = p.gold })

hi("PreProc",      { fg = p.gold })
hi("Include",      { fg = p.gold })
hi("Define",       { fg = p.gold })
hi("Macro",        { fg = p.cyan })
hi("PreCondit",    { fg = p.gold })

hi("Type",         { fg = p.purple })
hi("StorageClass", { fg = p.teal })
hi("Structure",    { fg = p.purple })
hi("Typedef",      { fg = p.purple })

hi("Special",      { fg = p.orange })
hi("SpecialChar",  { fg = p.orange })
hi("Tag",          { fg = p.cyan })
hi("Delimiter",    { fg = p.punct })
hi("SpecialComment", { fg = p.fg_ui, italic = true })
hi("Debug",        { fg = p.red })

hi("Underlined",   { fg = p.cyan, underline = true })
hi("Bold",         { bold = true })
hi("Italic",       { italic = true })
hi("Ignore",       { fg = p.fg_disabled })
hi("Error",        { fg = p.red, bold = true })
hi("Todo",         { fg = p.gold, bg = p.bg_elev, bold = true })

-- ── Diagnostics ───────────────────────────────────────────────
hi("DiagnosticError",            { fg = p.red })
hi("DiagnosticWarn",             { fg = p.orange })
hi("DiagnosticInfo",             { fg = p.cyan })
hi("DiagnosticHint",             { fg = p.teal })
hi("DiagnosticOk",               { fg = p.green })
hi("DiagnosticUnderlineError",   { sp = p.red,    undercurl = true })
hi("DiagnosticUnderlineWarn",    { sp = p.orange, undercurl = true })
hi("DiagnosticUnderlineInfo",    { sp = p.cyan,   undercurl = true })
hi("DiagnosticUnderlineHint",    { sp = p.teal,   undercurl = true })
hi("DiagnosticVirtualTextError", { fg = p.red,    italic = true })
hi("DiagnosticVirtualTextWarn",  { fg = p.orange, italic = true })
hi("DiagnosticVirtualTextInfo",  { fg = p.cyan,   italic = true })
hi("DiagnosticVirtualTextHint",  { fg = p.teal,   italic = true })
hi("DiagnosticSignError",        { fg = p.red })
hi("DiagnosticSignWarn",         { fg = p.orange })
hi("DiagnosticSignInfo",         { fg = p.cyan })
hi("DiagnosticSignHint",         { fg = p.teal })

-- ── Git / diff ────────────────────────────────────────────────
hi("DiffAdd",      { bg = "#16261f" })  -- ~#00a8841a over bg
hi("DiffChange",   { bg = "#16242a" })  -- ~#11b7d41a over bg
hi("DiffDelete",   { fg = p.red, bg = "#2a1a17" })
hi("DiffText",     { bg = "#1d3a44", bold = true })
hi("diffAdded",    { fg = p.green })
hi("diffRemoved",  { fg = p.red })
hi("diffChanged",  { fg = p.cyan })
hi("diffFile",     { fg = p.gold })
hi("diffNewFile",  { fg = p.green })
hi("diffOldFile",  { fg = p.red })

hi("GitSignsAdd",       { fg = p.green })
hi("GitSignsChange",    { fg = p.cyan })
hi("GitSignsDelete",    { fg = p.red })
hi("GitSignsAddNr",     { fg = p.green })
hi("GitSignsChangeNr",  { fg = p.cyan })
hi("GitSignsDeleteNr",  { fg = p.red })
hi("GitSignsAddInline",    { bg = "#16261f" })
hi("GitSignsChangeInline", { bg = "#16242a" })
hi("GitSignsDeleteInline", { bg = "#2a1a17" })

-- ── Treesitter (modern @captures) ─────────────────────────────
hi("@comment",                  { link = "Comment" })
hi("@comment.documentation",    { fg = p.comment, italic = true })
hi("@comment.todo",             { fg = p.gold, bold = true })
hi("@comment.note",             { fg = p.cyan, bold = true })
hi("@comment.warning",          { fg = p.orange, bold = true })
hi("@comment.error",            { fg = p.red, bold = true })

hi("@constant",                 { fg = p.red })
hi("@constant.builtin",         { fg = p.red, italic = true })
hi("@constant.macro",           { fg = p.red })
hi("@number",                   { fg = p.orange })
hi("@number.float",             { fg = p.orange })
hi("@boolean",                  { fg = p.red, italic = true })
hi("@character",                { fg = p.red })
hi("@character.special",        { fg = p.orange })

hi("@string",                   { fg = p.green })
hi("@string.documentation",     { fg = p.green, italic = true })
hi("@string.regexp",            { fg = p.orange })
hi("@string.escape",            { fg = p.orange, bold = true })
hi("@string.special",           { fg = p.orange })
hi("@string.special.symbol",    { fg = p.orange })
hi("@string.special.url",       { fg = p.cyan, underline = true })

hi("@function",                 { fg = p.cyan })
hi("@function.builtin",         { fg = p.cyan, italic = true })
hi("@function.call",            { fg = p.cyan })
hi("@function.macro",           { fg = p.cyan })
hi("@function.method",          { fg = p.cyan })
hi("@function.method.call",     { fg = p.cyan })

hi("@constructor",              { fg = p.blue_alt })
hi("@operator",                 { fg = p.gold })

hi("@keyword",                  { fg = p.gold })
hi("@keyword.function",         { fg = p.teal })
hi("@keyword.operator",         { fg = p.gold })
hi("@keyword.import",           { fg = p.gold })
hi("@keyword.storage",          { fg = p.teal })
hi("@keyword.repeat",           { fg = p.gold })
hi("@keyword.return",           { fg = p.gold, italic = true })
hi("@keyword.conditional",      { fg = p.gold })
hi("@keyword.coroutine",        { fg = p.gold })
hi("@keyword.exception",        { fg = p.gold })
hi("@keyword.directive",        { fg = p.gold })
hi("@keyword.modifier",         { fg = p.teal })
hi("@keyword.type",             { fg = p.gold })

hi("@type",                     { fg = p.purple })
hi("@type.builtin",             { fg = p.purple, italic = true })
hi("@type.definition",          { fg = p.purple })
hi("@type.qualifier",           { fg = p.purple, italic = true })

hi("@attribute",                { fg = p.pink })       -- decorators
hi("@attribute.builtin",        { fg = p.pink, italic = true })

-- VS Code's tokenColors put `variable.other.property` and the like at orange (#d4770c).
-- Treesitter has @property for object keys/fields → render those orange.
hi("@property",                 { fg = p.orange })
hi("@field",                    { fg = p.orange })

hi("@variable",                 { fg = p.salmon })
hi("@variable.builtin",         { fg = p.teal, italic = true })   -- this/self → teal per VS Code
hi("@variable.member",          { fg = p.fg })
hi("@variable.parameter",       { fg = p.pink, italic = true })
hi("@variable.parameter.builtin", { fg = p.pink, italic = true })

hi("@punctuation",              { fg = p.punct })
hi("@punctuation.delimiter",    { fg = p.punct })
hi("@punctuation.bracket",      { fg = p.punct })
hi("@punctuation.special",      { fg = p.gold })

hi("@tag",                      { fg = p.cyan })
hi("@tag.builtin",              { fg = p.cyan, italic = true })
hi("@tag.attribute",            { fg = p.gold })
hi("@tag.delimiter",            { fg = p.punct })

hi("@label",                    { fg = p.gold })
hi("@module",                   { fg = p.cyan })       -- namespace → cyan per VS Code semantic
hi("@module.builtin",           { fg = p.cyan, italic = true })
hi("@namespace",                { fg = p.cyan })
hi("@namespace.builtin",        { fg = p.cyan, italic = true })

hi("@markup.heading",           { fg = p.gold, bold = true })
hi("@markup.heading.1",         { fg = p.gold, bold = true })
hi("@markup.heading.2",         { fg = p.pink, bold = true })
hi("@markup.heading.3",         { fg = p.cyan, bold = true })
hi("@markup.heading.4",         { fg = p.green, bold = true })
hi("@markup.heading.5",         { fg = p.purple, bold = true })
hi("@markup.heading.6",         { fg = p.teal, bold = true })
hi("@markup.strong",            { fg = p.salmon, bold = true })
hi("@markup.italic",            { fg = p.orange, italic = true })
hi("@markup.underline",         { underline = true })
hi("@markup.strikethrough",     { fg = p.red, strikethrough = true })
hi("@markup.link",              { fg = p.cyan })
hi("@markup.link.label",        { fg = p.cyan })
hi("@markup.link.url",          { fg = p.cyan, underline = true })
hi("@markup.list",              { fg = p.cyan })
hi("@markup.list.checked",      { fg = p.green })
hi("@markup.list.unchecked",    { fg = p.fg_ui })
hi("@markup.quote",             { fg = p.pink, italic = true })
hi("@markup.raw",               { fg = p.purple })
hi("@markup.raw.block",         { fg = p.fg, bg = p.bg_panel })

hi("@diff.plus",                { fg = p.green })
hi("@diff.minus",               { fg = p.red })
hi("@diff.delta",               { fg = p.orange })

-- ── LSP semantic tokens (VS Code parity) ──────────────────────
-- VS Code's semanticTokenColors:
--   class.declaration  → purple
--   class.decorator    → pink
--   enumMember         → purple
--   meta.decorator     → pink
--   namespace          → cyan
--   parameter          → pink
--   property           → orange
--   property.declaration → fg
--   variable           → salmon
--   variable.defaultLibrary → teal
hi("@lsp.type.class",            { fg = p.blue_alt })   -- entity.name.type → deeper blue
hi("@lsp.type.enum",             { fg = p.purple })
hi("@lsp.type.interface",        { fg = p.purple })
hi("@lsp.type.struct",           { fg = p.purple })
hi("@lsp.type.type",             { fg = p.purple })
hi("@lsp.type.typeParameter",    { fg = p.purple })
hi("@lsp.type.parameter",        { fg = p.pink, italic = true })
hi("@lsp.type.property",         { fg = p.orange })
hi("@lsp.type.variable",         { fg = p.salmon })
hi("@lsp.type.function",         { fg = p.cyan })
hi("@lsp.type.method",           { fg = p.cyan })
hi("@lsp.type.macro",            { fg = p.cyan })
hi("@lsp.type.namespace",        { fg = p.cyan })
hi("@lsp.type.enumMember",       { fg = p.purple })
hi("@lsp.type.event",            { fg = p.pink })
hi("@lsp.type.decorator",        { fg = p.pink })
hi("@lsp.type.keyword",          { fg = p.gold })
hi("@lsp.type.string",           { fg = p.green })
hi("@lsp.type.number",           { fg = p.orange })
hi("@lsp.type.regexp",           { fg = p.orange })
hi("@lsp.type.operator",         { fg = p.gold })

hi("@lsp.typemod.variable.defaultLibrary",  { fg = p.teal, italic = true })
hi("@lsp.typemod.variable.readonly",        { fg = p.red })
hi("@lsp.typemod.variable.static",          { fg = p.salmon, italic = true })
hi("@lsp.typemod.property.declaration",     { fg = p.fg })
hi("@lsp.typemod.class.declaration",        { fg = p.purple })
hi("@lsp.typemod.function.declaration",     { fg = p.cyan, bold = true })
hi("@lsp.typemod.method.declaration",       { fg = p.cyan, bold = true })
hi("@lsp.typemod.parameter.declaration",    { fg = p.pink, italic = true })
hi("@lsp.mod.deprecated",                   { strikethrough = true })
hi("@lsp.mod.readonly",                     { fg = p.red })
hi("@lsp.mod.static",                       { italic = true })

-- ── cmp / blink completion ────────────────────────────────────
hi("CmpItemAbbr",            { fg = p.fg })
hi("CmpItemAbbrMatch",       { fg = p.gold, bold = true })
hi("CmpItemAbbrMatchFuzzy",  { fg = p.gold, bold = true })
hi("CmpItemAbbrDeprecated",  { fg = p.fg_disabled, strikethrough = true })
hi("CmpItemKindFunction",    { fg = p.cyan })
hi("CmpItemKindMethod",      { fg = p.cyan })
hi("CmpItemKindVariable",    { fg = p.salmon })
hi("CmpItemKindKeyword",     { fg = p.gold })
hi("CmpItemKindClass",       { fg = p.purple })
hi("CmpItemKindInterface",   { fg = p.purple })
hi("CmpItemKindModule",      { fg = p.cyan })
hi("CmpItemKindProperty",    { fg = p.orange })
hi("CmpItemKindText",        { fg = p.fg })
hi("CmpItemKindSnippet",     { fg = p.green })
hi("CmpItemKindFile",        { fg = p.cyan })
hi("CmpItemKindFolder",      { fg = p.cyan })
hi("CmpItemMenu",            { fg = p.fg_disabled, italic = true })

hi("BlinkCmpMenu",                 { link = "Pmenu" })
hi("BlinkCmpMenuBorder",           { link = "FloatBorder" })
hi("BlinkCmpMenuSelection",        { link = "PmenuSel" })
hi("BlinkCmpLabel",                { fg = p.fg })
hi("BlinkCmpLabelMatch",           { fg = p.gold, bold = true })
hi("BlinkCmpLabelDeprecated",      { fg = p.fg_disabled, strikethrough = true })
hi("BlinkCmpKindFunction",         { fg = p.cyan })
hi("BlinkCmpKindMethod",           { fg = p.cyan })
hi("BlinkCmpKindVariable",         { fg = p.salmon })
hi("BlinkCmpKindKeyword",          { fg = p.gold })
hi("BlinkCmpKindClass",            { fg = p.purple })
hi("BlinkCmpKindSnippet",          { fg = p.green })
hi("BlinkCmpKindProperty",         { fg = p.orange })

-- ── Telescope / Snacks picker ─────────────────────────────────
hi("TelescopeNormal",         { fg = p.fg, bg = p.bg_panel })
hi("TelescopeBorder",         { fg = p.bg_panel, bg = p.bg_panel })
hi("TelescopePromptNormal",   { fg = p.fg, bg = p.bg_elev })
hi("TelescopePromptBorder",   { fg = p.bg_elev, bg = p.bg_elev })
hi("TelescopePromptTitle",    { fg = p.bg, bg = p.gold, bold = true })
hi("TelescopePromptPrefix",   { fg = p.gold, bg = p.bg_elev })
hi("TelescopePreviewTitle",   { fg = p.bg, bg = p.green, bold = true })
hi("TelescopeResultsTitle",   { fg = p.bg_panel, bg = p.bg_panel })
hi("TelescopeSelection",      { fg = p.gold, bg = p.bg_active_solid, bold = true })
hi("TelescopeMatching",       { fg = p.gold, bold = true })

hi("SnacksPickerBorder",      { fg = p.gold })
hi("SnacksPickerTitle",       { fg = p.bg, bg = p.gold, bold = true })
hi("SnacksPickerMatch",       { fg = p.gold, bold = true })
hi("SnacksPickerListCursorLine", { bg = p.bg_active_solid })
hi("SnacksDashboardHeader",   { fg = p.gold, bold = true })
hi("SnacksDashboardIcon",     { fg = p.gold })
hi("SnacksDashboardDesc",     { fg = p.fg })
hi("SnacksDashboardKey",      { fg = p.cyan })
hi("SnacksDashboardFooter",   { fg = p.fg_ui, italic = true })

-- ── Neo-tree / Oil ────────────────────────────────────────────
hi("NeoTreeNormal",           { fg = p.fg, bg = p.bg_panel })
hi("NeoTreeNormalNC",         { fg = p.fg, bg = p.bg_panel })
hi("NeoTreeRootName",         { fg = p.gold, bold = true })
hi("NeoTreeDirectoryIcon",    { fg = p.gold })
hi("NeoTreeDirectoryName",    { fg = p.fg })
hi("NeoTreeFileName",         { fg = p.fg })
hi("NeoTreeFileNameOpened",   { fg = p.gold, italic = true })
hi("NeoTreeIndentMarker",     { fg = p.bg_elev })
hi("NeoTreeGitAdded",         { fg = p.green })
hi("NeoTreeGitModified",      { fg = p.cyan })
hi("NeoTreeGitDeleted",       { fg = p.red })
hi("NeoTreeGitUntracked",     { fg = p.green })       -- VS Code: gitDecoration.untrackedResourceForeground
hi("NeoTreeGitIgnored",       { fg = p.fg_disabled })
hi("NeoTreeGitConflict",      { fg = p.gold })
hi("NeoTreeTabActive",        { fg = p.gold, bg = p.bg, bold = true })
hi("NeoTreeTabInactive",      { fg = p.fg_disabled, bg = p.bg_panel })
hi("NeoTreeTabSeparatorActive",   { fg = p.bg, bg = p.bg })
hi("NeoTreeTabSeparatorInactive", { fg = p.bg_panel, bg = p.bg_panel })

hi("OilDir",                  { fg = p.gold })
hi("OilLink",                 { fg = p.cyan })
hi("OilFile",                 { fg = p.fg })

-- ── Indent guides ─────────────────────────────────────────────
hi("IblIndent",          { fg = p.indent })
hi("IblScope",           { fg = p.indent_act })
hi("IblWhitespace",      { fg = p.indent })
hi("IndentBlanklineChar", { fg = p.indent })
hi("IndentBlanklineContextChar", { fg = p.indent_act })

-- ── which-key, notify, noice ──────────────────────────────────
hi("WhichKey",            { fg = p.gold })
hi("WhichKeyGroup",       { fg = p.cyan })
hi("WhichKeyDesc",        { fg = p.fg })
hi("WhichKeySeparator",   { fg = p.fg_disabled })
hi("WhichKeyFloat",       { bg = p.bg_elev })
hi("WhichKeyBorder",      { fg = p.gold, bg = p.bg_elev })
hi("WhichKeyValue",       { fg = p.fg_ui })

hi("NotifyERRORBorder",   { fg = p.red });    hi("NotifyERRORIcon",   { fg = p.red });    hi("NotifyERRORTitle",   { fg = p.red,    bold = true })
hi("NotifyWARNBorder",    { fg = p.orange }); hi("NotifyWARNIcon",    { fg = p.orange }); hi("NotifyWARNTitle",    { fg = p.orange, bold = true })
hi("NotifyINFOBorder",    { fg = p.cyan });   hi("NotifyINFOIcon",    { fg = p.cyan });   hi("NotifyINFOTitle",    { fg = p.cyan,   bold = true })
hi("NotifyDEBUGBorder",   { fg = p.fg_ui });  hi("NotifyDEBUGIcon",   { fg = p.fg_ui });  hi("NotifyDEBUGTitle",   { fg = p.fg_ui })
hi("NotifyTRACEBorder",   { fg = p.purple }); hi("NotifyTRACEIcon",   { fg = p.purple }); hi("NotifyTRACETitle",   { fg = p.purple })

hi("NoiceCmdline",          { fg = p.fg, bg = p.bg_elev })
hi("NoiceCmdlinePopup",     { fg = p.fg, bg = p.bg_elev })
hi("NoiceCmdlinePopupBorder", { fg = p.gold, bg = p.bg_elev })

-- ── Lualine theme (require'd via lua/lualine/themes/phoenix.lua) ──
-- That file is written out by the colorscheme plugin spec.

-- Expose palette so user plugins can re-use it
vim.g.phoenix_palette = p
