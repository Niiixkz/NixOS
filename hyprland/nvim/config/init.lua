-- bootstrap lazy.nvim, LazyVim and your plugins
require("config.lazy")

vim.cmd("set expandtab")
vim.cmd("set tabstop=4")
vim.cmd("set softtabstop=4")
vim.cmd("set shiftwidth=4")
vim.g.mapleader = " "

require("lualine").setup {
    options = {
        theme = 'pywal-nvim'
    }
}

local pid = vim.fn.getpid()
vim.fn.serverstart("/tmp/nvim-pywal-" .. pid .. ".sock")

local colors = require("pywal.core").get_colors()


vim.cmd('highlight LineNr guifg=' .. colors.foreground)
vim.cmd('highlight LineNrAbove guifg=' .. colors.color8)
vim.cmd('highlight LineNrBelow guifg=' .. colors.color8)

vim.cmd('highlight SnacksIndentScope guifg=' .. colors.foreground)
vim.cmd('highlight SnacksIndent guifg=' .. colors.color1)

vim.cmd('highlight BlinkCmpMenu guibg=' .. colors.background)
vim.cmd('highlight BlinkCmpMenuBorder guifg=' .. colors.foreground .. ' guibg=' .. colors.background)
vim.cmd('highlight BlinkCmpMenuSelection guibg=' .. colors.color1)
vim.cmd('highlight BlinkCmpLabel guifg=' .. colors.foreground)
vim.cmd('highlight BlinkCmpLabelMatch guifg=' .. colors.color5)
vim.cmd('highlight BlinkCmpLabelDeprecated guifg=' .. colors.foreground .. ' gui=strikethrough')
vim.cmd('highlight BlinkCmpDocBorder guifg=' .. colors.foreground .. ' guibg=' .. colors.background)
vim.cmd('highlight BlinkCmpDoc guibg=' .. colors.background)
