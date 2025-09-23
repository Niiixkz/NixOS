return {
  "xiyaowong/transparent.nvim",

  config = function()
    require('transparent').setup({
      enable = true,
      groups = {
        "Normal",
        "NormalNC",
        "Comment",
        "Constant",
        "Special",
        "Identifier",
        "Statement",
        "PreProc",
        "Type",
        "Underlined",
        "Todo",
        "String",
        "Function",
        "Conditional",
        "Repeat",
        "Operator",
        "Structure",
        "LineNr",
        "NonText",
        "SignColumn",
        "CursorLine",
        "CursorLineNr",
        "StatusLine",
        "StatusLineNC",
        "EndOfBuffer",
      },
      extra_groups = {
        "NormalFloat",
      },
    })

    require('transparent').clear_prefix('TabLine')
    require('transparent').clear_prefix('Float')
    require('transparent').clear_prefix('Snack')
    require('transparent').clear_prefix('Which')
    require('transparent').clear_prefix('NeoTree')
    require('transparent').clear_prefix('lualine_b')
    require('transparent').clear_prefix('lualine_c')
    require('transparent').clear_prefix('lualine_x')
    require('transparent').clear_prefix('Buffer')
    require('transparent').clear_prefix('Fold')
    require('transparent').clear_prefix('Msg')
    require('transparent').clear_prefix('Err')
    require('transparent').clear_prefix('Warn')
  end
}

