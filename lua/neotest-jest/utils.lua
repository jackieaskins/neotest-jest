local utils = {}

local position_sep = '::'

local status_values = { 'passed', 'skipped', 'failed', 'unknown' }
local status_map = {
  -- passed statuses
  passed = 1,

  -- skipped statuses
  pending = 2,
  skipped = 2,

  -- failed statuses
  broken = 3,
  failed = 3,

  -- unknown statuses
  unknown = 4,
}

---Generates string of form file_name::line::column
---@param test_name string
---@param line number | string
---@param column number | string
---@return string
function utils.generate_position(test_name, line, column)
  return table.concat({ test_name, line, column }, position_sep)
end

---Parses string of form file_name::line::column into parts
---@param position string
---@return string[]
function utils.parse_position(position)
  return vim.split(position, position_sep, { plain = true })
end

---Returns whether provided position is inside of node's range
---@param node_data any
---@param position string
---@return boolean
function utils.is_test_in_range(node_data, position)
  local position_parts = utils.parse_position(position)

  local file, line, col = position_parts[1], tonumber(position_parts[2]) - 1, tonumber(position_parts[3]) - 1

  if file ~= node_data.path then
    return false
  end

  local start_line, start_col, end_line, end_col = unpack(node_data.range)

  if line == start_line then
    return col >= start_col
  elseif line == end_line then
    return col <= end_col
  end

  return line > start_line and line < end_line
end

---@class JestResults
---@field statuses number[]
---@field errors string[]

---Parse jest results
---@param jest_result any
---@return table<string, JestResults>
function utils.parse_jest_results(jest_result)
  local results = {}

  for _, test_result in ipairs(jest_result.testResults) do
    for _, assertion_result in ipairs(test_result.assertionResults) do
      local position =
        utils.generate_position(test_result.name, assertion_result.location.line, assertion_result.location.column)

      local position_results = results[position] or { statuses = {}, errors = {} }
      local statuses = position_results.statuses

      table.insert(statuses, status_map[assertion_result.status])

      results[position] = {
        statuses = statuses,
        errors = vim.tbl_flatten({
          position_results.errors,
          assertion_result.failureMessages,
        }),
      }
    end
  end

  return results
end

---Parses jest results to neotest
---@param test_results any
---@param tree neotest.Tree
---@return table<string, neotest.Result>
function utils.get_neotest_results(test_results, tree)
  local results = {}
  for _, node in tree:iter_nodes() do
    local node_data = node:data()

    if node_data.type == 'test' then
      for position, result in pairs(test_results) do
        if utils.is_test_in_range(node_data, position) then
          results[node_data.id] = {
            status = status_values[math.max(unpack(result.statuses))],
            errors = vim.tbl_map(function(err)
              return { message = err }
            end, result.errors),
          }
        end
      end
    end
  end

  return results
end

return utils
