return [[
  ((call_expression
    function: (identifier) @func_name (#match? @func_name "^describe")
    arguments: (arguments (_) @namespace.name (_))
  )) @namespace.definition

  ((call_expression
    function: (call_expression) @func_name (#match? @func_name "^describe.each")
    arguments: (arguments (_) @namespace.name (_))
  )) @namespace.definition

  ((call_expression
    function: (identifier) @func_name (#match? @func_name "^(it|test)")
    arguments: (arguments (_) @test.name (_))
  )) @test.definition

  ((call_expression
    function: (call_expression) @func_name (#match? @func_name "^(it|test).each")
    arguments: (arguments (_) @test.name (_))
  )) @test.definition
]]
