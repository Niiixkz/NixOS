vim.cmd('colorscheme pywal')

vim.cmd('highlight LineNr guifg={foreground}')
vim.cmd('highlight LineNrAbove guifg={color8}')
vim.cmd('highlight LineNrBelow guifg={color8}')

vim.cmd('highlight SnacksIndentScope guifg={foreground}')
vim.cmd('highlight SnacksIndent guifg={color1}')

vim.cmd('highlight BlinkCmpMenu guibg={background}')
vim.cmd('highlight BlinkCmpMenuBorder guifg={foreground} guibg={background}')
vim.cmd('highlight BlinkCmpMenuSelection guibg={color1}')
vim.cmd('highlight BlinkCmpLabel guifg={foreground}')
vim.cmd('highlight BlinkCmpLabelMatch guifg={color5}')
vim.cmd('highlight BlinkCmpLabelDeprecated guifg={foreground} gui=strikethrough')
vim.cmd('highlight BlinkCmpDocBorder guifg={foreground} guibg={background}')
vim.cmd('highlight BlinkCmpDoc guibg={background}')
