local async = require('plenary.async')
local utils = require('scala-zio-quickfix.utils')
local ts = vim.treesitter

local zio_predicate = function(value)
  return string.find(value, 'ZIO') ~= nil -- TODO: match part of markdown?
end

local function parse_query(query)
  return ts.query.parse('scala', query)
end

local queries = {

  -- ZIO.succeed(()) ~> ZIO.unit
  succeed_unit = {
    query = parse_query([[
(call_expression
  function: (field_expression
    value: (_) @_1 (#eq? @_1 "ZIO")
    field: (identifier) @_2 (#eq? @_2 "succeed")
  )
  arguments: (arguments (unit)) @_3
)
]]),
    handler = function(bufnr, matches)
      local target = matches[2]
      local finish = matches[3]

      local start_row, start_col, _, _ = target:range()
      local _, _, end_row, end_col = finish:range()

      -- local tx, rx = async.control.channel.oneshot()
      -- utils.hover_node_and_match(bufnr, target, zio_predicate, tx)
      -- local is_zio = rx()

      -- if is_zio then
      return {
        {
          diagnostic = {
            row = start_row,
            start_col = start_col,
            end_col = end_col,
          },
          action = {
            start_row = start_row,
            start_col = start_col,
            end_row = end_row,
            end_col = end_col,
          },
          replacement = 'unit',
          title = 'ZIO: replace ZIO.succeed(()) with ZIO.unit',
        },
      }
      -- end
    end,
  },

  -- x.map(_ => ()) ~> x.unit
  map_unit = {
    query = parse_query([[
(call_expression
  function: (field_expression
    value: (_) @_1
    field: (identifier) @_2 (#eq? @_2 "map")
  )
  (arguments
    (lambda_expression parameters: (wildcard) (unit))
  ) @_3
)
]]),
    handler = function(bufnr, matches)
      local target = matches[2]
      local finish = matches[3]

      local start_row, start_col, _, _ = target:range()
      local _, _, end_row, end_col = finish:range()

      local tx, rx = async.control.channel.oneshot()
      utils.hover_node_and_match(bufnr, target, zio_predicate, tx)
      local is_zio = rx()

      if is_zio then
        return {
          {
            diagnostic = {
              row = start_row,
              start_col = start_col,
              end_col = end_col,
            },
            action = {
              start_row = start_row,
              start_col = start_col,
              end_row = end_row,
              end_col = end_col,
            },
            replacement = 'unit',
            title = 'ZIO: replace .map(_ => ()) with .unit',
          },
        }
      else
        return {}
      end
    end,
  },

  -- *> ZIO.succeed(()) ~> .unit
  -- *> ZIO.unit        ~> .unit
  -- TODO: if ZIO.succeed(()) is on the next line, treesitter renders it as a sibling to the function definition
  -- example: def func = effect *>
  --   ZIO.succeed(())
  -- TODO: also need to support .zipRight(_ => ()), can be replaced with .unit
  zip_right_unit = {
    query = parse_query([[
(infix_expression
  left: (_) @_1
  operator: (operator_identifier) @_2 (#eq? @_2 "*>")
  right: (_) @_3 (#any-of? @_3 "ZIO.unit" "ZIO.succeed(())")
)
]]),
    handler = function(bufnr, matches)
      local start = matches[1]
      local finish = matches[3]

      local _, _, start_row, start_col = start:range()
      local dstart_row, dstart_col, end_row, end_col = finish:range()

      -- local tx, rx = async.control.channel.oneshot()
      -- utils.hover_node_and_match(bufnr, finish, zio_predicate, tx)
      -- local is_zio = rx()

      local replaced = utils.get_node_text(bufnr, finish)
      local title = 'ZIO: replace *> ' .. replaced .. ' with .unit'

      -- if is_zio then
      return {
        {
          diagnostic = {
            row = dstart_row,
            start_col = dstart_col,
            end_col = end_col,
          },
          action = {
            start_row = start_row,
            start_col = start_col,
            end_row = end_row,
            end_col = end_col,
          },
          replacement = '.unit',
          title = title,
        },
      }
      -- end
    end,
  },

  -- x.as(()) ~> x.unit
  as_unit = {
    query = parse_query([[
(call_expression
  function: (field_expression
    value: (_) @_1
    field: (identifier) @_2 (#eq? @_2 "as")
  )
  arguments: (arguments (unit)) @_3
)
]]),
    handler = function(bufnr, matches)
      local target = matches[2]
      local finish = matches[3]

      local start_row, start_col, _, _ = target:range()
      local _, _, end_row, end_col = finish:range()

      -- local tx, rx = async.control.channel.oneshot()
      -- utils.hover_node_and_match(bufnr, target, zio_predicate, tx)
      -- local is_zio = rx()

      -- if is_zio then
      return {
        {
          diagnostic = {
            row = start_row,
            start_col = start_col,
            end_col = end_col,
          },
          action = {
            start_row = start_row,
            start_col = start_col,
            end_row = end_row,
            end_col = end_col,
          },
          replacement = 'unit',
          title = 'ZIO: replace .as(()) with .unit',
        },
      }
      -- end
    end,
  },

  -- *> ZIO.succeed(value) ~> .as(value)
  zip_right_value = {
    query = parse_query([[
(infix_expression
  left: (_) @_1
  operator: (operator_identifier) @_2 (#eq? @_2 "*>")
  right: (call_expression
    function: ((field_expression) @_3 (#eq? @_3 "ZIO.succeed"))
    arguments: (arguments (_) @_4 (#not-eq? @_4 "()"))
  ) @_5
)
]]),
    handler = function(bufnr, matches)
      local start = matches[1]
      local target = matches[3]
      local value = matches[4]
      local finish = matches[5]

      local _, _, start_row, start_col = start:range()
      local dstart_row, dstart_col, _, _ = target:range()
      local _, _, end_row, end_col = finish:range()

      -- local tx, rx = async.control.channel.oneshot()
      -- utils.hover_node_and_match(bufnr, target, zio_predicate, tx)
      -- local is_zio = rx()

      -- if is_zio then
      local value_text = utils.get_node_text(bufnr, value)
      local title = 'ZIO: replace *> ZIO.succeed(' .. value_text .. ') with .as(' .. value_text .. ')'
      local replacement = '.as(' .. value_text .. ')'

      return {
        {
          diagnostic = {
            row = dstart_row,
            start_col = dstart_col,
            end_col = end_col,
          },
          action = {
            start_row = start_row,
            start_col = start_col,
            end_row = end_row,
            end_col = end_col,
          },
          replacement = replacement,
          title = title,
        },
      }
      -- end
    end,
  },

  -- x.map(_ => value) ~> x.as(value)
  map_value = {
    query = parse_query([[
(call_expression
  function: (field_expression
    value: (_) @_1
    field: (identifier) @_2 (#eq? @_2 "map")
  )
  arguments: (arguments
    (lambda_expression
      parameters: (wildcard) (_) @_3 (#not-eq? @_3 "()")
    )
  ) @_4
)
]]),
    handler = function(bufnr, matches)
      local target = matches[2]
      local value = matches[3]
      local finish = matches[4]

      local dstart_row, dstart_col, _, _ = target:range()
      local _, _, end_row, end_col = finish:range()

      local tx, rx = async.control.channel.oneshot()
      utils.hover_node_and_match(bufnr, target, zio_predicate, tx)
      local is_zio = rx()

      if is_zio then
        local value_text = utils.get_node_text(bufnr, value)
        local title = 'ZIO: replace .map(_ => ' .. value_text .. ') with .as(' .. value_text .. ')'
        local replacement = 'as(' .. value_text .. ')'

        return {
          {
            diagnostic = {
              row = dstart_row,
              start_col = dstart_col,
              end_col = end_col,
            },
            action = {
              start_row = dstart_row,
              start_col = dstart_col,
              end_row = end_row,
              end_col = end_col,
            },
            replacement = replacement,
            title = title,
          },
        }
        -- handler(results, start_row, start_col, end_row, end_col, utils.get_node_text(bufnr, value))
      else
        return {}
      end
    end,
  },

  -- x.catchAll(_ => ()) ~> .ignore
  catch_all_unit = {
    query = parse_query([[
(call_expression 
  function: (field_expression
    value: (_)
    field: (_) @_1 (#eq? @_1 "catchAll")
  )
  arguments: (arguments 
    (lambda_expression 
      parameters: (wildcard) 
      (_) @_2 (#any-of? @_2 "ZIO.unit" "ZIO.succeed(())")
     )
  ) @_3
)
]]),
    handler = function(bufnr, matches)
      local target = matches[1]
      local value = matches[2]
      local finish = matches[3]

      local dstart_row, dstart_col, _, _ = target:range()
      local _, _, end_row, end_col = finish:range()

      local tx, rx = async.control.channel.oneshot()
      utils.hover_node_and_match(bufnr, target, zio_predicate, tx)
      local is_zio = rx()

      if is_zio then
        local value_text = utils.get_node_text(bufnr, value)
        local title = 'ZIO: replace .catchAll(_ => ' .. value_text .. ') with .ignore'
        local replacement = 'ignore'

        return {
          {
            diagnostic = {
              row = dstart_row,
              start_col = dstart_col,
              end_col = end_col,
            },
            action = {
              start_row = dstart_row,
              start_col = dstart_col,
              end_row = end_row,
              end_col = end_col,
            },
            replacement = replacement,
            title = title,
          },
        }
      else
        return {}
      end
    end,
  },

  -- x.foldCause(_ => (), _ => ()) ~> .ignore
  fold_cause_ignore = {
    query = parse_query([[
(call_expression
  function: (field_expression
    value: (_) @_1
    field: (identifier) @_2 (#eq? @_2 "foldCause")
  )
  arguments: (arguments
    (lambda_expression
      parameters: (wildcard) (unit)
    )
    (lambda_expression parameters: (wildcard) (unit))
  ) @_3
)
]]),
    handler = function(bufnr, matches)
      local target = matches[2]
      local finish = matches[3]

      local dstart_row, dstart_col, _, _ = target:range()
      local _, _, end_row, end_col = finish:range()

      -- local tx, rx = async.control.channel.oneshot()
      -- utils.hover_node_and_match(bufnr, target, zio_predicate, tx)
      -- local is_zio = rx()

      local title = 'ZIO: replace .foldCause(_ => (), _ => ()) with .ignore'

      -- if is_zio then
      return {
        {
          diagnostic = {
            row = dstart_row,
            start_col = dstart_col,
            end_col = end_col,
          },
          action = {
            start_row = dstart_row,
            start_col = dstart_col,
            end_row = end_row,
            end_col = end_col,
          },
          replacement = 'ignore',
          title = title,
        },
      }
      -- end
    end,
  },

  -- x.mapError(_ => "hello") ~> x.orElseFail("hello")
  or_else_fail = {
    query = parse_query([[
(call_expression 
    function: (field_expression 
      value: (_) @_1
      field: (identifier) @_2 (#eq? @_2 "mapError")
    )
    arguments: (arguments (
      (lambda_expression parameters: (wildcard) (_) @_3)
    )
  )
) @_4
]]),
    handler = function(bufnr, matches)
      local target = matches[2]
      local value = matches[3]
      local finish = matches[4]

      local dstart_row, dstart_col, _, _ = target:range()
      local _, _, end_row, end_col = finish:range()

      local value_text = utils.get_node_text(bufnr, value)

      local tx, rx = async.control.channel.oneshot()
      utils.hover_node_and_match(bufnr, target, zio_predicate, tx)
      local is_zio = rx()

      local title = 'ZIO: replace .mapError(_ => ' .. value_text .. ') with .orElseFail(' .. value_text .. ')'
      local replacement = 'orElseFail(' .. value_text .. ')'

      if is_zio then
        return {
          {
            diagnostic = {
              row = dstart_row,
              start_col = dstart_col,
              end_col = end_col,
            },
            action = {
              start_row = dstart_row,
              start_col = dstart_col,
              end_row = end_row,
              end_col = end_col,
            },
            replacement = replacement,
            title = title,
          },
        }
      else
        return {}
      end
    end,
  },

  -- x.orElse(ZIO.fail("hello")) ~> x.orElseFail("hello")
  or_else_fail2 = {
    query = parse_query([[
(call_expression 
    function: (field_expression 
      value: (_) @_1
      field: (identifier) @_2 (#eq? @_2 "orElse")
    )
    arguments: (arguments 
      (call_expression
        function: (_) @_3 (#eq? @_3 "ZIO.fail")
        arguments: (arguments (_) @_4) 
      )
    ) @_5
) 
]]),
    handler = function(bufnr, matches)
      local target = matches[2]
      local value = matches[4]
      local finish = matches[5]

      local dstart_row, dstart_col, _, _ = target:range()
      local _, _, end_row, end_col = finish:range()

      local value_text = utils.get_node_text(bufnr, value)

      local tx, rx = async.control.channel.oneshot()
      utils.hover_node_and_match(bufnr, target, zio_predicate, tx)
      local is_zio = rx()

      local title = 'ZIO: replace .orElse(ZIO.fail(' .. value_text .. ')) with .orElseFail(' .. value_text .. ')'
      local replacement = 'orElseFail(' .. value_text .. ')'

      if is_zio then
        return {
          {
            diagnostic = {
              row = dstart_row,
              start_col = dstart_col,
              end_col = end_col,
            },
            action = {
              start_row = dstart_row,
              start_col = dstart_col,
              end_row = end_row,
              end_col = end_col,
            },
            replacement = replacement,
            title = title,
          },
        }
      else
        return {}
      end
    end,
  },

  -- x.flatMapError(_ => ZIO.succeed("hello")) ~> x.orElseFail("hello")
  or_else_fail3 = {
    query = parse_query([[
(call_expression
    function: (field_expression
      value: (_) @_1
      field: (identifier) @_2 (#eq? @_2 "flatMapError")
    )
    arguments: (arguments
      (lambda_expression
        parameters: (wildcard)
        (call_expression
          function: (field_expression) @_3
          arguments: (arguments (_) @_4)
        )
      )
    ) @_5
)
]]),
    handler = function(bufnr, matches)
      local target = matches[2]
      local value = matches[4]
      local finish = matches[5]

      local dstart_row, dstart_col, _, _ = target:range()
      local _, _, end_row, end_col = finish:range()

      local value_text = utils.get_node_text(bufnr, value)

      -- local tx, rx = async.control.channel.oneshot()
      -- utils.hover_node_and_match(bufnr, target, zio_predicate, tx)
      -- local is_zio = rx()

      local title = 'ZIO: replace .flatMapError(_ => ZIO.succeed('
        .. value_text
        .. ')) with .orElseFail('
        .. value_text
        .. ')'
      local replacement = 'orElseFail(' .. value_text .. ')'

      -- if is_zio then
      return {
        {
          diagnostic = {
            row = dstart_row,
            start_col = dstart_col,
            end_col = end_col,
          },
          action = {
            start_row = dstart_row,
            start_col = dstart_col,
            end_row = end_row,
            end_col = end_col,
          },
          replacement = replacement,
          title = title,
        },
      }
      -- end
    end,
  },

  zio_type = {
    query = parse_query([[
(
  generic_type (
    (
     (type_identifier) @_1 (#eq? @_1 "ZIO")
    )
    type_arguments: (
      type_arguments 
      (type_identifier) @_2
      (type_identifier) @_3
      (type_identifier) @_4
    ) @finish
  )
)
]]),
    handler = function(bufnr, matches)
      local start = matches[1]
      local finish = matches[5]

      local r_value = utils.get_node_text(bufnr, matches[2])
      local e_value = utils.get_node_text(bufnr, matches[3])
      local a_value = utils.get_node_text(bufnr, matches[4])

      local start_row, start_col, _, _ = start:range()
      local _, _, end_row, end_col = finish:range()

      -- stylua: ignore start
      local lookup = {
        { "Any",   "Nothing",   'UIO['.. a_value .. ']' },
        { "Any",   "Throwable", 'Task[' .. a_value .. ']'  },
        { "Any",   e_value,     'IO[' .. e_value .. ', ' .. a_value .. ']'  },
        { r_value, "Nothing",   'URIO['.. r_value ..', ' .. a_value .. ']' },
        { r_value, "Throwable", 'RIO[' .. r_value ..', ' .. a_value .. ']' }
      }
      -- stylua: ignore end

      local results = {}
      for _, m in ipairs(lookup) do
        if r_value == m[1] and e_value == m[2] then
          local replacement = m[3]

          table.insert(results, {
            diagnostic = {
              row = start_row,
              start_col = start_col,
              end_col = end_col,
            },
            action = {
              start_row = start_row,
              start_col = start_col,
              end_row = end_row,
              end_col = end_col,
            },
            replacement = replacement,
            title = 'ZIO: replace ZIO[' .. r_value .. ', ' .. e_value .. ', ' .. a_value .. '] with ' .. replacement,
          })
        end
      end

      return results
    end,
  },

  zlayer_type = {
    query = parse_query([[
(
  generic_type (
    (
     (type_identifier) @start (#eq? @start "ZLayer")
    )
    type_arguments: (
      type_arguments 
      (type_identifier) @R_id 
      (type_identifier) @E_id 
      (type_identifier) @A_id 
    ) @finish
  )
)
]]),

    handler = function(bufnr, matches)
      local start = matches[1]
      local finish = matches[5]

      local r_value = utils.get_node_text(bufnr, matches[2])
      local e_value = utils.get_node_text(bufnr, matches[3])
      local a_value = utils.get_node_text(bufnr, matches[4])

      local start_row, start_col, _, _ = start:range()
      local _, _, end_row, end_col = finish:range()

      -- stylua: ignore start
      local lookup = {
        { "Any",   "Nothing",   'ULayer['.. a_value .. ']' },
        { "Any",   "Throwable", 'TaskLayer[' .. a_value .. ']'  },
        { "Any",   e_value,     'Layer[' .. e_value .. ', ' .. a_value .. ']'  },
        { r_value, "Nothing",   'URLayer['.. r_value ..', ' .. a_value .. ']' },
        { r_value, "Throwable", 'RLayer[' .. r_value ..', ' .. a_value .. ']' }
      }
      -- stylua: ignore end

      local results = {}
      for _, m in ipairs(lookup) do
        if r_value == m[1] and e_value == m[2] then
          local replacement = m[3]

          table.insert(results, {
            diagnostic = {
              row = start_row,
              start_col = start_col,
              end_col = end_col,
            },
            action = {
              start_row = start_row,
              start_col = start_col,
              end_row = end_row,
              end_col = end_col,
            },
            replacement = replacement,
            title = 'ZIO: replace ZLayer[' .. r_value .. ', ' .. e_value .. ', ' .. a_value .. '] with ' .. replacement,
          })
        end
      end

      return results
    end,
  },

  -- ZIO.succeed(None) ~> ZIO.none
  -- ZIO.succeed(Option.empty[A]) ~> ZIO.none
  -- TODO: support cats syntax none
  zio_none = {
    query = parse_query([[
(call_expression
  function: (field_expression) @_1 (#eq? @_1 "ZIO.succeed")
  arguments: (arguments
    [
      ((identifier) @_2 (#eq? @_2 "None"))
      ((generic_function
        function: ((field_expression) @_3 (#eq? @_3 "Option.empty"))
        type_arguments: (type_arguments (type_identifier) @_4)
      ))
    ] @_5
  ) @_6
)
]]),
    handler = function(bufnr, matches)
      local start = matches[1]
      local value = matches[5]
      local finish = matches[6]

      local dstart_row, dstart_col, _, _ = start:range()
      local _, _, end_row, end_col = finish:range()

      local value_text = utils.get_node_text(bufnr, value)

      return {
        {
          diagnostic = {
            row = dstart_row,
            start_col = dstart_col,
            end_col = end_col,
          },
          action = {
            start_row = dstart_row,
            start_col = dstart_col,
            end_row = end_row,
            end_col = end_col,
          },
          replacement = 'ZIO.none',
          title = 'ZIO: replace ZIO.succeed(' .. value_text .. ') with ZIO.none',
        },
      }
    end,
  },

  -- ZIO.succeed(Some(x)) ~> ZIO.some(x)
  -- ZIO.succeed(Option(x)) ~> ZIO.some(x)
  -- TODO: support cats syntax x.some
  zio_some = {
    query = parse_query([[
(call_expression
  function: (field_expression) @_1 (#eq? @_1 "ZIO.succeed")
  arguments: (arguments
    (call_expression
      function: (identifier) @_2 (#any-of? @_2 "Some" "Option")
      arguments: (arguments (_) @_3)
    ) @_4
  ) @_5
)
]]),
    handler = function(bufnr, matches)
      local start = matches[1]
      local value = matches[3]
      local expr = matches[4]
      local finish = matches[5]

      local dstart_row, dstart_col, _, _ = start:range()
      local _, _, end_row, end_col = finish:range()

      local expr_text = utils.get_node_text(bufnr, expr)
      local value_text = utils.get_node_text(bufnr, value)

      return {
        {
          diagnostic = {
            row = dstart_row,
            start_col = dstart_col,
            end_col = end_col,
          },
          action = {
            start_row = dstart_row,
            start_col = dstart_col,
            end_row = end_row,
            end_col = end_col,
          },
          replacement = 'ZIO.some(' .. value_text .. ')',
          title = 'ZIO: replace ZIO.succeed(' .. expr_text .. ') with ZIO.some(' .. value_text .. ')',
        },
      }
    end,
  },

  zio_either = {
    query = parse_query([[
(call_expression
  function: (field_expression) @_1 (#eq? @_1 "ZIO.succeed")
  arguments: (arguments 
    [
      (call_expression
          function: (identifier) @_2 (#any-of? @_2 "Left" "Right")
          arguments: (arguments (_) @_3)
      )
      (field_expression
        value: (_) @_4
        field: (identifier) @_5 (#any-of? @_5 "asLeft" "asRight")
      )
    ] @_6
  ) @_7
)
]]),
    handler = function(bufnr, matches)
      local start = matches[1]

      local either = matches[2]
      local cats_either = matches[5]

      local value = matches[3]
      local cats_value = matches[4]

      local expr = matches[6]
      local finish = matches[7]

      local dstart_row, dstart_col, _, _ = start:range()
      local _, _, end_row, end_col = finish:range()

      local smartc_text = nil
      local value_text = nil
      if either ~= nil then
        smartc_text = string.lower(utils.get_node_text(bufnr, either))
        value_text = utils.get_node_text(bufnr, value)
      else
        if utils.get_node_text(bufnr, cats_either) == 'asLeft' then
          smartc_text = 'left'
        else
          smartc_text = 'right'
        end
        value_text = utils.get_node_text(bufnr, cats_value)
      end

      local expr_text = utils.get_node_text(bufnr, expr)

      return {
        {
          diagnostic = {
            row = dstart_row,
            start_col = dstart_col,
            end_col = end_col,
          },
          action = {
            start_row = dstart_row,
            start_col = dstart_col,
            end_row = end_row,
            end_col = end_col,
          },
          replacement = 'ZIO.' .. smartc_text .. '(' .. value_text .. ')',
          title = 'ZIO: replace ZIO.succeed(' .. expr_text .. ') with ZIO.' .. smartc_text .. '(' .. value_text .. ')',
        },
      }
    end,
  },

  -- x.map(_ => ExitCode.success) ~> x.exitCode
  exit_code = {},
  -- x.as(ExitCode.success) ~> x.exitCode
  exit_code2 = {},
  -- x.fold(_ => ExitCode.failure, _ => ExitCode.success)
  exit_code3 = {},

  -- ZIO.fail(new Exception("hello")).orDie ~> ZIO.die(new Exception("hello"))
  -- TODO: how to verify the type of expression within fail call, can this be done with "textDocument/hover"
  -- yes, probably with this https://microsoft.github.io/language-server-protocol/specifications/lsp/3.17/specification/#typeHierarchy_supertypes
  zio_die = {},
}

local M = {}

---
--- Executes a query on a given buffer and returns the results.
--- @param opts (table) The options for running the query.
---   - bufnr (number, optional): The buffer number to run the query on. Defaults to the current buffer.
---   - start_line (number, optional): The starting line for the query. Defaults to 0.
---   - end_line (number, optional): The ending line for the query. Defaults to the total number of lines in the buffer.
---   - root (table): The root object for the query.
---   - handler (function): The handler function to process query results.
---   - query_name (string): The name of the query to run.
--- @return function callback
function M.run_query(opts)
  local bufnr = opts.bufnr or vim.api.nvim_get_current_buf()

  local start_line = opts.start_line or 0
  local end_line = opts.end_line or vim.api.nvim_buf_line_count(bufnr)

  local root = opts.root
  local callback = opts.callback

  return function(cb)
    --- @type table
    ---   - query (vim.treesitter.Query) - compiled treesitter query
    ---   - handler (function) - function that knows how to collect results of the match
    local query = queries[opts.query_name]
    if query == nil then
      return callback({})
    end

    local ok, query_results = pcall(function()
      return query.query:iter_matches(root, bufnr, start_line, end_line + 1)
    end)

    local results = {}

    if ok then
      for _, matches, _ in query_results do
        local items = query.handler(bufnr, matches)
        for _, item in ipairs(items) do
          table.insert(results, callback(item))
        end
      end
    else
      vim.notify('Query ' .. opts.query_name .. ' failed ' .. query_results, vim.log.levels.WARN)
    end

    return cb(results)
  end
end

return M
