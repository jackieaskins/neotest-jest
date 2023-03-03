local lib = require('neotest.lib')

-- Adapter Interface: https://github.com/nvim-neotest/neotest/blob/master/lua/neotest/adapters/interface.lua
local adapter = {
  name = 'neotest-jest',
  root = lib.files.match_root_pattern('package.json'),
}

function adapter.filter_dir(name)
  return name ~= 'node_modules'
end

function adapter.is_test_file(file_path)
  for _, start in ipairs({ '__tests__/.*', '%.spec', '%.test' }) do
    for _, ext in ipairs({ 'js', 'jsx', 'coffee', 'ts', 'tsx' }) do
      if file_path:match(start .. '%.' .. ext .. '$') then
        return true
      end
    end
  end

  return false
end

function adapter.discover_positions(file_path)
  return lib.treesitter.parse_positions(file_path, require('neotest-jest.query'), { nested_tests = true })
end

function adapter.build_spec(args)
  if not args.tree then
    return
  end

  local pos = args.tree:data()

  local bin_jest = 'node_modules/.bin/jest'
  local jest = vim.fn.filereadable(bin_jest) == 1 and bin_jest or { 'npx', 'jest' }
  local results_path = vim.fn.tempname() .. '.json'

  local config_dir = require('lspconfig').util.root_pattern('jest.config.js')(pos.path)

  local command = vim.tbl_flatten({
    jest,
    config_dir and '--config=' .. config_dir .. '/jest.config.js' or {},
    '--json',
    '--verbose',
    '--coverage=false',
    '--outputFile=' .. results_path,
    pos.type ~= 'dir' and '--runTestsByPath' or {},
    '--testLocationInResults',
    vim.tbl_contains({ 'test', 'namespace' }, pos.type) and '--testNamePattern=' .. pos.name or {},
    pos.path,
  })

  return {
    command = command,
    context = { results_path = results_path, file = pos.path },
  }
end

local status_map = {
  failed = 'failed',
  broken = 'failed',
  passed = 'passed',
  skipped = 'skipped',
  unknown = 'failed',
}

local function is_test_in_range(node_data, position)
  local position_parts = {}
  for part in vim.gsplit(position, '::', true) do
    table.insert(position_parts, part)
  end

  local file, line, col = position_parts[1], tonumber(position_parts[2]), tonumber(position_parts[3])

  local range = node_data.range
  local start_line, start_col, end_line, end_col = range[1] + 1, range[2] + 1, range[3] + 1, range[4] + 1

  return file == node_data.path and line >= start_line and line <= end_line and col >= start_col and col <= end_col
end

function adapter.results(spec, _, tree)
  local results_path = spec.context.results_path

  local success, data = pcall(lib.files.read, results_path)
  if not success then
    vim.api.nvim_err_writeln('Unable to read results path: ' .. results_path)
    return {}
  end

  local jest_result = vim.json.decode(data, { luanil = { object = true } }) or {}

  local test_results = {}
  for _, test_result in ipairs(jest_result.testResults) do
    for _, assertion_result in ipairs(test_result.assertionResults) do
      local position = table.concat({
        test_result.name,
        assertion_result.location.line,
        assertion_result.location.column,
      }, '::')
      local status = status_map[assertion_result.status]

      if status ~= 'pending' then
        local position_results = test_results[position] or { status = 'passed', errors = {} }

        local new_status = position_results.status

        if new_status == 'passed' and (status == 'skipped' or status == 'failed') then
          new_status = status
        elseif new_status == 'skipped' and status == 'failed' then
          new_status = status
        end

        test_results[position] = {
          status = new_status,
          errors = vim.tbl_flatten({ position_results.errors, assertion_result.failureMessages }),
        }
      end
    end
  end

  local results = {}
  for _, node in tree:iter_nodes() do
    local node_data = node:data()

    if node_data.type == 'test' then
      for position, result in pairs(test_results) do
        if is_test_in_range(node_data, position) then
          results[node_data.id] = {
            status = result.status,
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

return adapter
