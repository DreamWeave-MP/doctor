--!strict
--!native
-- The `doctor` command target's entry: the command line's arguments in, the exit status out.
local cli = require '@doctor/cli'

return cli.run { ... }
