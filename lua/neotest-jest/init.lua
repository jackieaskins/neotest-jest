local async = require('neotest.async')
local lib = require('neotest.lib')

local utils = require('neotest-jest.utils')

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

---@async
---@param file_path string
---@return neotest.Tree | nil
function adapter.discover_positions(file_path)
  return lib.treesitter.parse_positions(file_path, require('neotest-jest.query'), { nested_tests = true })
end

---@param args neotest.RunArgs
---@return nil | neotest.RunSpec | neotest.RunSpec[]
function adapter.build_spec(args)
  if not args.tree then
    return
  end

  local pos = args.tree:data()

  local bin_jest = adapter.root(pos.path) .. '/node_modules/.bin/jest'
  local jest = async.fn.filereadable(bin_jest) == 1 and bin_jest or { 'npx', 'jest' }
  local results_path = async.fn.tempname() .. '.json'

  local config_dir = lib.files.match_root_pattern('jest.config.js')(pos.path)

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

---@async
---@param spec neotest.RunSpec
---@param _ neotest.StrategyResult
---@param tree neotest.Tree
---@return table<string, neotest.Result>
function adapter.results(spec, _, tree)
  local results_path = spec.context.results_path

  local success, data = pcall(lib.files.read, results_path)
  if not success then
    async.api.nvim_err_writeln('Unable to read results path: ' .. results_path)
    return {}
  end

  local jest_result = vim.json.decode(data, { luanil = { object = true } }) or {}
  return utils.get_neotest_results(utils.parse_jest_results(jest_result), tree)
end

return adapter
