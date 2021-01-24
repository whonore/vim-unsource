# vim-unsource

[![Build Status](https://github.com/whonore/vim-unsource/workflows/Tests/badge.svg?branch=main)](https://github.com/whonore/vim-unsource/actions?query=workflow%3ATests)

Undo a Vim script.

```vim
" Unsource a file
call unsource#unsource('/etc/vimrc.local')
" Unsource multiple files
call unsource#unsource(['/etc/vimrc.local', '/etc/vimrc'])
" Only undo 'set's and 'map's
call unsource#unsource('/etc/vimrc.local', 'sm')
```

The second argument to `unsource#unsource` can be used to configure which
commands are undone.
By default the commands are `let`, `function`, `set`, `autocmd`, and `map`.
To undo only a subset pass a string containing the first letter of the commands
(e.g., `'lsa'`).
