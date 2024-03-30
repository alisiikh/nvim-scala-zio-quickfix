local async = require('plenary.async')
local parsers = require('nvim-treesitter.parsers')
local query = require('scala-zio-quickfix.query')
local utils = require('scala-zio-quickfix.utils')

local M = {}

local function make_code_action(bufnr)
  return function(result)
    return {
      title = result.title,
      action = function()
        local action = result.action

        vim.api.nvim_buf_set_text(
          bufnr,
          action.start_row,
          action.start_col,
          action.end_row,
          action.end_col,
          { result.replacement }
        )
      end,
    }
  end
end

function M.resolve_actions(bufnr, start_line, end_line, done)
  local root = parsers.get_tree_root(bufnr)

  local query_names = {
    'succeed_unit',
    'map_unit',
    'as_unit',
    'zip_right_unit',
    'zip_right_value',
    'map_value',
    'catch_all_unit',
    'fold_cause_ignore',
    'or_else_fail',
    'or_else_fail2',
    'or_else_fail3',
    'zio_type',
    'zlayer_type',
    'zio_none',
    'zio_some',
  }

  local queries = {}
  for _, query_name in ipairs(query_names) do
    table.insert(
      queries,
      async.wrap(
        query.run_query({
          bufnr = bufnr,
          root = root,
          query_name = query_name,
          start_line = start_line,
          end_line = end_line,
          callback = make_code_action(bufnr),
        }),
        1
      )
    )
  end

  local ok, actions = pcall(async.util.join, queries)

  if ok then
    done(utils.flatten_array(actions))
  else
    -- if failed, return nothing
    vim.notify('Failed to collect actions: ' .. actions)
    done(nil)
  end
end

return M
