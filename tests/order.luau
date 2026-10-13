--!strict
--!native
-- What the doctor's suites share: load orders in a folder under the host's scratch root, laid out
-- as the tool's old harness laid its own out (`data`, the user's `config`, and `out` as
-- data-local), and a check over one that keeps what the tool printed.
local doctor = require '@doctor'
local fixture = require './build'
local openmw = require '@openmw'
local tes3 = require '@tes3'

export type Fields = { [string]: unknown }

--- A load order in scratch: its folder, the user's configuration folder and the openmw.cfg in it,
--- the data folder, and the `data-local` folder.
export type Order = { root: string, config: string, cfg: string, data: string, out: string }

--- What a check left behind: every line the doctor printed, each ending in a newline, the state
--- it was called with, and its report.
export type Run = { printed: string, state: { [string]: unknown }, report: doctor.Report }

local scratch = assert(rawget(_G, 'scratchRoot') :: string?, 'the suite needs a host-owned scratchRoot')

-- The doctor reports through `print`, and its old harness read that off standard output. A suite
-- can't, so the tool's function runs in an environment whose `print` keeps the lines instead.
local printed: { string } = {}

local function keep(...: unknown)
  local words: { string } = {}
  for index = 1, select('#', ...) do
    words[index] = tostring((select(index, ...)))
  end

  table.insert(printed, table.concat(words, '\t') .. '\n')
end

setfenv(doctor, setmetatable({ print = keep }, { __index = getfenv(doctor) }))

--- A fresh, empty load order named `name`, with `content` as its `content=` lines, in order.
local function empty(name: string, content: { string }): Order
  local root = jess.fs.join(scratch, 'doctor', name)
  if jess.fs.exists(root) then jess.fs.remove(root) end

  local built: Order = {
    root = root,
    config = jess.fs.join(root, 'config'),
    cfg = jess.fs.join(root, 'config', 'openmw.cfg'),
    data = jess.fs.join(root, 'data'),
    out = jess.fs.join(root, 'out'),
  }

  for _, folder in { built.data, built.config, built.out } do
    jess.fs.createDir(folder)
  end

  local lines = { `data="{built.data}"`, `data-local="{built.out}"` }
  for _, file in content do
    table.insert(lines, `content={file}`)
  end

  jess.fs.write(built.cfg, table.concat(lines, '\n') .. '\n')
  return built
end

--- The harness's load order: `build.luau`'s plugins, and its eleven content files.
local function harness(name: string): Order
  local built = empty(name, fixture.content)
  fixture.build(built.data)
  return built
end

--- A plugin's bytes: `records` after a header naming `masters`; a master file when `fileType`
--- says so.
local function plugin(
  records: { Fields },
  masters: { { name: string, size: number } }?,
  fileType: tes3.FileType?
): buffer
  local built = tes3.new(fileType)
  if masters then built:setMasters(masters) end

  for _, record in records do
    built:insertValue(built:count(), record)
  end

  built:updateRecordCount()
  return built:save()
end

--- A fresh load order named `name` whose data folder holds `files` by their paths below it, with
--- `content` as its `content=` lines.
local function order(name: string, files: { [string]: string | buffer }, content: { string }): Order
  local built = empty(name, content)
  for path, bytes in files do
    jess.fs.write(jess.fs.join(built.data, path), bytes)
  end

  return built
end

--- Runs the doctor over the load order with `options` as its `state.doctor`, in `state` when one
--- is given.
local function check(built: Order, options: doctor.Options?, state: { [string]: unknown }?): Run
  local shared: { [string]: unknown } = state or {}
  shared.doctor = options
  table.clear(printed)
  doctor(shared, openmw.new(built.cfg))

  local given = shared.doctor :: doctor.Options
  return { printed = table.concat(printed), state = shared, report = given.report :: doctor.Report }
end

--- What the doctor has printed since the suite last asked: for the runs a suite doesn't start
--- itself, through the command line.
local function takePrinted(): string
  local text = table.concat(printed)
  table.clear(printed)
  return text
end

--- Every file under `folder`, by path, with its bytes.
local function files(folder: string): { [string]: string }
  local found: { [string]: string } = {}
  local function walk(directory: string)
    for _, name in jess.fs.list(directory) do
      local path = jess.fs.join(directory, name)
      if jess.fs.isDir(path) then
        walk(path)
      else
        found[path] = jess.fs.read(path)
      end
    end
  end

  walk(folder)
  return found
end

--- The findings of a report that are of `kind`, in the report's order.
local function findings(report: doctor.Report, kind: string): { doctor.Finding }
  return [for finding in report.findings if finding.check == kind => finding]
end

return table.freeze {
  check = check,
  files = files,
  findings = findings,
  harness = harness,
  order = order,
  plugin = plugin,
  takePrinted = takePrinted,
}
