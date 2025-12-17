(document
  (body
    (directive
      name: (expr) @directive_type
      value: (value) @directive_value
      (#match? @directive_type "(ORG_NOTEBOOK|org_notebook)_*")) @directive))
