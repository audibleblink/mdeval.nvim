# mdeval.nvim


A simple Neovim plugin to evaluate code blocks inside markdown, [vimwiki](https://github.com/vimwiki/vimwiki), [orgmode.nvim](https://github.com/kristijanhusak/orgmode.nvim) and [norg](https://github.com/vhyrro/neorg) documents.

Inspired by org-mode's [evaluating code blocks](https://orgmode.org/manual/Evaluating-Code-Blocks.html#Evaluating-Code-Blocks) feature.

## Installation

Install with your plugin manager:

```lua
-- Lazy.nvim
{ 'audibleblink/mdeval.nvim' }

-- Packer
vim.pack.add("audibleblink/mdeval.nvim")
require('mdeval').setup()
```

## Usage

Move your cursor inside a fenced code block and run `:MdEval`.

The plugin will execute the code and insert the results right after the code block.

### Example

Before:
````markdown
```python
print("Hello, World!")
print(2 + 2)
```
````

After running `:MdEval`:
````markdown
```python
print("Hello, World!")
print(2 + 2)
```

**Results:**
```
Hello, World!
4
```
````

### Cleaning Results

Use `:MdEvalClean` to remove the results from the current code block.

## Configuration

### Basic Setup

```lua
require('mdeval').setup({
  -- Timeout in seconds (-1 for no timeout)
  timeout = -1,
  
  -- Label for results
  results_label = "**Results:**",
  
  -- Temp directory for compiled languages
  tmp_dir = "/tmp/mdeval",
  
  -- Language configurations
  languages = {
    python = "python3",
    bash = "bash",
    lua = "lua",
  },
})
```

### Language Configuration

Languages are configured with simple command strings:

```lua
languages = {
  -- Interpreters (code via stdin)
  python = "python3",
  ruby = "ruby",
  
  -- Compilers (use {file} and {tmp} placeholders)
  c = "gcc {file} -o {tmp}/a.out && {tmp}/a.out",
  cpp = "g++ {file} -o {tmp}/a.out && {tmp}/a.out",
  rust = "rustc {file} -o {tmp}/a.out && {tmp}/a.out",
}
```

**Placeholders:**
- `{file}` - Path to temporary source file
- `{tmp}` - Temp directory path

If a command contains `{file}`, the code is written to a file. Otherwise, it's passed via stdin.


### Keybindings

The plugin doesn't set default keybindings. Add your own:

```lua
vim.keymap.set('n', '<leader>e', function() 
    require("mdeval").eval() 
end, { silent = true })
vim.keymap.set('n', '<leader>e', function() 
    require("mdeval").clean() 
end, { silent = true })
```

## Supported Languages (Default)

Out of the box, these languages are configured:

- **Interpreters:** bash, sh, python, py, lua, ruby, js, haskell
- **Compilers:** c, cpp, rust

Add or override any language in your setup.

## Supported Filetypes

- `markdown` - ` ``` ` delimiters
- `markdown.pandoc` - ` ``` ` delimiters  
- `vimwiki` - `{{{` / `}}}` delimiters
- `org` - `#+BEGIN_SRC` / `#+END_SRC` delimiters
- `norg` - `@code` / `@end` delimiters


## Comparison with v1

This is a **complete rewrite** focused on simplicity:

- **59% less code** (659 → 267 lines)
- **65% fewer functions** (23 → 8)
- **Simpler configuration** - just command strings
- **More flexible** - full control over execution


## License

MIT
