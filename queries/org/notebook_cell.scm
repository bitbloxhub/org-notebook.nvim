(block
  (directive
    name: (expr) @_directive_type
    value: (value) @name
    (#match? @_directive_type "(name|NAME)"))
  name: (expr) @type
  .
  parameter: (expr) @language
  parameter: (expr)* @extra_params
  contents: (contents) @code
  (#match? @type "(src|SRC)")) @block
