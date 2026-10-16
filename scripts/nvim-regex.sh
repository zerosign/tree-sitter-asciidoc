#!/bin/sh
# Regression test for Neovim's treesitter predicate regex dialect.
#
# Neovim compiles the regex argument of #match?/#not-match?/#any-match? (and
# the *-vim-match? aliases) as a Vim regex: see check_magic() in
# $VIMRUNTIME/lua/vim/treesitter/query.lua, which prepends "\v" unless the
# pattern already starts with a magic prefix. Regex syntax that is valid for
# the Rust regex crate but not for Vim very-magic regex therefore raises:
#
#     E866: (NFA regexp) Misplaced ?
#
# and aborts the whole injections query, breaking highlighting. The most
# common offender is a non-capturing group "(?:...)".
#
# This test extracts every Vim-regex predicate pattern from the query files of
# both grammars and compiles it exactly the way Neovim does. It is skipped
# when nvim is not installed, so the primary (tree-sitter CLI / Rust regex)
# test suite is unaffected.
set -eu

cd "$(dirname "$0")/.."

if ! command -v nvim >/dev/null 2>&1; then
  echo "nvim not found; skipping nvim regex predicate test"
  exit 0
fi

nvim --headless -u NONE -l /dev/stdin <<'LUA'
-- Mirror of Neovim's vim/treesitter/query.lua check_magic().
local MAGIC_PREFIXES = { ['\\v'] = true, ['\\m'] = true, ['\\M'] = true, ['\\V'] = true }
local function check_magic(str)
  if #str < 2 or MAGIC_PREFIXES[str:sub(1, 2)] then
    return str
  end
  return '\\v' .. str
end

-- Undo the tree-sitter query string escaping ("\\" is what reaches the
-- predicate handler for the patterns we test).
local function unescape(s)
  return (s:gsub('\\\\', '\\'))
end

local files = {}
for _, dir in ipairs({ 'tree-sitter-asciidoc/queries', 'tree-sitter-asciidoc_inline/queries' }) do
  vim.list_extend(files, vim.fn.glob(dir .. '/*.scm', false, true))
end
if #files == 0 then
  io.stderr:write('nvim regex predicate test: no query files found\n')
  vim.cmd('cq')
end

local failures, checked = {}, 0
for _, file in ipairs(files) do
  local lnum = 0
  for _, line in ipairs(vim.fn.readfile(file)) do
    lnum = lnum + 1
    local pred = line:match('^%s*%(%s*(#[%w%-]*match%?)')
    if pred and not pred:match('lua') then
      local pattern = line:match('"(.*)"')
      if pattern then
        checked = checked + 1
        local ok, err = pcall(function()
          local re = vim.regex(check_magic(unescape(pattern)))
          re:match_str('') -- force compilation
        end)
        if not ok then
          failures[#failures + 1] = string.format('%s:%d  %s\n    pattern: %s', file, lnum, tostring(err), pattern)
        end
      end
    end
  end
end

print(string.format('nvim regex predicate test: checked %d pattern(s) in %d file(s)', checked, #files))
if #failures > 0 then
  io.stderr:write('nvim regex predicate test FAILED:\n')
  for _, f in ipairs(failures) do
    io.stderr:write('  ' .. f .. '\n')
  end
  vim.cmd('cq')
end
print('nvim regex predicate test: OK')
LUA
