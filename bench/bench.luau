--!strict
--!native
--[[
The doctor, timed through its public modules: whole checks over load orders built here with
`@tes3`, each `@doctor` called with an `@openmw` Context the way its command line calls it; the
command line's argument lists read; and the command line itself, warm and run once.

  jess run --capability filesystem.read --capability filesystem.write \
    --capability process.spawn --package . --package-path .. \
    bench/bench.luau <scratch> [filter] [jess binary] [package path]

Three load orders, written to a folder under `<scratch>`, which is removed afterwards:

- A load order with one of everything the doctor looks for, at a size a check is worth timing
  at: a master of 2,300 records (settings, globals, statics, activators, items, weapons, lights,
  books, interiors with their references) and four plugins that define every fourth, sixth,
  tenth, and fifteenth of them again, changed, one of them a patch that names two of the others
  as masters, one with copies of the master's records left in it, one that records the master's
  size wrong; a plugin of dirt; a plugin before its master, one whose master isn't in the load
  order, one whose master isn't installed, one that isn't a plugin, one that isn't there, and a
  script list. Its data folder holds two in five of the 150 models and 80 icons the master's
  records name, and none of those 60 models loads.
- Thirty plugins over a master a quarter that size, none naming another as a master, each
  defining a seventh of the master's records again and 40 records of its own that name files
  nothing provides: 246 pairs of plugins where one drops the other's changes.
- A master of 4,000 statics that each name a model of their own, none of them installed: what a
  load order looks like without the asset pack a mod needs.

One line per workload, `name<TAB>seconds per call`: the median of seven batches of about a tenth
of a second each, with a full collection between batches. The doctor reports through `print`, so
each check also prints its own lines between those: the lines of the bench are the ones holding
a tab. Every check's report is weighed before the first batch and after the last, outside the
time: its counts, and a digest of the file it wrote with the scratch folder's path taken out,
compared with what is pinned here, so a path that stops doing its work fails instead of posting a
time. The digests hold for a scratch path of letters, digits, `/`, `.`, `_`, and `-`, which is
what the report writes without quotes; the bench refuses any other.

Given the jess binary to start (and `process.spawn`), the cold workloads too: what one process
pays for one command from its first `require` on. Each is the median of seven processes running
`cold.luau`, which find the packages this one depends on in the package path, the folder above
this package without one.
]]

local bytes = require '@dream/bytes'
local cli = require '@doctor/cli'
local doctor = require '@doctor'
local fs = require '@dream/fs'
local openmw = require '@openmw'
local process = require '@dream/process'
local tes3 = require '@tes3'

-- A build without the verified toolchain runs Luau slower than a release does, so a number from
-- one says nothing about what ships.
if not jess.bench.verified then
  error('doctor bench: this jess was built without the verified toolchain: measure on a release', 0)
end

local scratch: string?, filter: string?, binary: string?, packages: string? = ...
if not scratch then error('doctor bench: a scratch folder is required', 0) end

if not string.find(scratch, '^/[%w/%._%-]*$') then
  error(
    `doctor bench: the scratch folder '{scratch}' must be an absolute path of letters, digits, /, ., _, and -`,
    0
  )
end

local Wanted = if filter and filter ~= '' then string.split(filter, '|') else nil

--- Whether the workload called `name` runs: every one without a filter, else those whose name
--- holds one of the filter's parts, which `|` separates.
local function runs(name: string): boolean
  if not Wanted then return true end

  for _, part in Wanted do
    if string.find(name, part, 1, true) then return true end
  end

  return false
end

--- Where this file is, from its chunk name: `cold.luau` is beside it.
local function here(): string
  local source = debug.info(1, 's')
  local first = string.sub(source, 1, 1)
  local path = if first == '@' or first == '=' then string.sub(source, 2) else source

  return string.match(path, '^(.*)/[^/]*$') or '.'
end

local Here = here()
local PackagePath = packages or `{Here}/../..`
local Root = `{scratch}/doctor-bench`

local function io<Value>(value: Value?, message: string?, kind: dream_fs_ErrorKind?): Value
  if not value then error(message or tostring(kind), 0) end

  return value
end

type Fields = { [string]: unknown }
type Master = { name: string, size: number }

--- A record of one kind: the master's `index`th at revision 0, and the same record as the
--- plugin of revision 1 to 4 changes it. A plugin of the thirty changes it as revision 5 and up.
type Maker = (index: number, revision: number) -> Fields

local function setting(index: number, revision: number): Fields
  return {
    type = 'GameSetting',
    id = `fBenchSetting{index}`,
    value = { type = 'Float', data = index / 8 + revision },
  }
end

local function global(index: number, revision: number): Fields
  return {
    type = 'GlobalVariable',
    id = `bench_global_{index}`,
    value = { type = 'Float', data = index + revision },
  }
end

-- A plugin's change names a model nothing provides.
local function static(index: number, revision: number): Fields
  return {
    type = 'Static',
    id = `bench_static_{index}`,
    mesh = if revision == 0
      then `bench\\rock_{index % 60}.nif`
      else `bench\\rock_{index % 60}_{revision}.nif`,
  }
end

local function activator(index: number, revision: number): Fields
  return {
    type = 'Activator',
    id = `bench_activator_{index}`,
    name = if revision == 0 then `Lever {index}` else `Lever {index}, mark {revision}`,
    mesh = `bench\\lever_{index % 10}.nif`,
    script = '',
  }
end

local function miscItem(index: number, revision: number): Fields
  return {
    type = 'MiscItem',
    id = `bench_misc_{index}`,
    name = if revision == 1 then `Polished Trinket {index}` else `Trinket {index}`,
    mesh = `bench\\trinket_{index % 20}.nif`,
    icon = `bench\\trinket_{index % 20}.tga`,
    script = '',
    data = { weight = 1 + index % 7, value = 10 + index % 90 + 500 * revision, flags = '' },
  }
end

local function weapon(index: number, revision: number): Fields
  return {
    type = 'Weapon',
    id = `bench_weapon_{index}`,
    name = if revision == 1 then `Honed Blade {index}` else `Blade {index}`,
    mesh = `bench\\blade_{index % 20}.nif`,
    icon = `bench\\blade_{index % 20}.tga`,
    script = '',
    enchanting = '',
    data = {
      weight = 8 + index % 20,
      value = 40 + index % 400,
      weaponType = 'AxeOneHand',
      health = 300 + index % 900,
      speed = 1,
      reach = 1,
      enchantment = 5 + index % 60,
      chopMin = 1 + index % 5,
      chopMax = 10 + index % 30 + revision,
      slashMin = 1,
      slashMax = 12 + index % 20,
      thrustMin = 1,
      thrustMax = 8,
      flags = '',
    },
  }
end

local function light(index: number, revision: number): Fields
  return {
    type = 'Light',
    id = `bench_light_{index}`,
    name = `Lantern {index}`,
    mesh = `bench\\lantern_{index % 20}.nif`,
    icon = `bench\\lantern_{index % 20}.tga`,
    script = '',
    sound = '',
    data = {
      weight = 2,
      value = 10 + index % 30,
      time = 600 + 100 * revision,
      radius = 128 + index % 128,
      color = { 240, 200 - index % 60, 120, 0 },
      flags = 'DYNAMIC | CAN_CARRY | FIRE',
    },
  }
end

local Page = string.rep('The page goes on, as pages in these books do, for a while longer. ', 9)

local function book(index: number, revision: number): Fields
  return {
    type = 'Book',
    id = `bench_book_{index}`,
    name = `Volume {index}`,
    mesh = `bench\\octavo_{index % 20}.nif`,
    icon = `bench\\octavo_{index % 20}.tga`,
    script = '',
    enchanting = '',
    text = if revision == 0 then `<DIV>{Page}` else `<DIV ALIGN="LEFT">Errata {revision}.<BR>{Page}`,
    data = { weight = 3, value = 25 + index % 50, bookType = 'Book', skill = 'None', enchantment = 0 },
  }
end

local function references(index: number): { Fields }
  local list: { Fields } = {}

  for slot = 1, 6 do
    list[slot] = {
      id = `bench_misc_{(index + slot) % 500 + 1}`,
      mastIndex = 0,
      refrIndex = index * 8 + slot,
      temporary = true,
      translation = { 64 * slot, 32 * (index % 20), 0 },
      rotation = { 0, 0, 0 },
    }
  end

  return list
end

local function interior(index: number, revision: number): Fields
  return {
    type = 'Cell',
    name = `Bench Hall {index}`,
    data = {
      flags = if revision == 1 then 'IS_INTERIOR | HAS_WATER' else 'IS_INTERIOR',
      grid = { 0, 0 },
    },
    waterHeight = revision,
    atmosphereData = {
      ambientColor = { 70, 70, 70, 0 },
      sunlightColor = { 240, 220, 220, 0 },
      fogColor = { 10, 10 + revision, 10, 0 },
      fogDensity = 1,
    },
    references = references(index),
  }
end

--- Each kind the master has, and how many of it: 2,300 records in all.
local Kinds: { { make: Maker, count: number } } = {
  { make = setting, count = 200 },
  { make = global, count = 100 },
  { make = static, count = 600 },
  { make = activator, count = 100 },
  { make = miscItem, count = 500 },
  { make = weapon, count = 300 },
  { make = light, count = 200 },
  { make = book, count = 100 },
  { make = interior, count = 200 },
}

--- The models and icons the master's records name, by folder and name, and how many of each.
local Files: { { folder: string, name: string, extension: string, count: number } } = {
  { folder = 'meshes', name = 'rock', extension = 'nif', count = 60 },
  { folder = 'meshes', name = 'lever', extension = 'nif', count = 10 },
  { folder = 'meshes', name = 'trinket', extension = 'nif', count = 20 },
  { folder = 'meshes', name = 'blade', extension = 'nif', count = 20 },
  { folder = 'meshes', name = 'lantern', extension = 'nif', count = 20 },
  { folder = 'meshes', name = 'octavo', extension = 'nif', count = 20 },
  { folder = 'icons', name = 'trinket', extension = 'tga', count = 20 },
  { folder = 'icons', name = 'blade', extension = 'tga', count = 20 },
  { folder = 'icons', name = 'lantern', extension = 'tga', count = 20 },
  { folder = 'icons', name = 'octavo', extension = 'tga', count = 20 },
}

--- A load order in scratch: its data folder, and the openmw.cfg that names it.
type Order = { data: string, config: string, report: string }

local function order(name: string): Order
  local folder = `{Root}/{name}`
  local built: Order = {
    data = `{folder}/data`,
    config = `{folder}/config/openmw.cfg`,
    report = `{folder}/config/jess-doctor`,
  }

  io(fs.mkdir(built.data, { recursive = true }))
  io(fs.mkdir(`{folder}/config`, { recursive = true }))

  return built
end

local function configure(built: Order, content: { string })
  local lines = { `data="{built.data}"\n` }
  for _, file in content do
    table.insert(lines, `content={file}\n`)
  end

  io(fs.writeFile(built.config, table.concat(lines)))
end

--- Writes a plugin of `records` that names `masters`, a master file when its name says so.
--- Gives what a plugin naming it as a master records.
local function write(built: Order, name: string, masters: { Master }, records: { Fields }): Master
  local plugin = tes3.new(if string.find(name, '%.esm$') then 'master' else 'plugin')
  plugin:setMasters(masters)

  for _, record in records do
    plugin:insertValue(plugin:count(), record :: tes3.Value)
  end

  plugin:updateRecordCount()

  local saved = plugin:save()
  io(fs.writeFile(`{built.data}/{name}`, saved))
  return { name = name, size = buffer.len(saved) }
end

--- The master's records, each kind cut to one part in `divisor`.
local function masterRecords(divisor: number): { Fields }
  local records: { Fields } = {}

  for _, kind in Kinds do
    for index = 1, kind.count // divisor do
      table.insert(records, kind.make(index, 0))
    end
  end

  return records
end

--- One of everything the doctor looks for.
local function loadOrder(): Order
  local built = order 'load'
  local master = write(built, 'Bench.esm', {}, masterRecords(1))

  --- Every `every`th of the master's records as revision `revision` changes it, and a tenth as
  --- many of its own, which no other file defines.
  local function changed(every: number, revision: number): { Fields }
    local records: { Fields } = {}

    for _, kind in Kinds do
      for index = every, kind.count, every do
        table.insert(records, kind.make(index, revision))
      end

      for index = 1, kind.count // 10 do
        table.insert(records, kind.make(revision * 10000 + index, 0))
      end
    end

    return records
  end

  local rebalance = write(built, 'Rebalance.esp', { master }, changed(4, 1))

  -- Every ninth of the master's statics and items, as the master has them: dirt.
  local overhauled = changed(6, 2)
  for index = 9, 500, 9 do
    table.insert(overhauled, static(index, 0))
    table.insert(overhauled, miscItem(index, 0))
  end

  local overhaul = write(built, 'Overhaul.esp', { master }, overhauled)
  write(built, 'Tweaks.esp', { { name = master.name, size = 7 } }, changed(10, 3))
  write(built, 'Patch.esp', { master, rebalance, overhaul }, changed(15, 4))

  local dirt: { Fields } = {
    { type = 'GameSetting', id = 'fWerewolfHealth', value = { type = 'Float', data = 2 } },
  }

  for index = 1, 20 do
    table.insert(dirt, {
      type = 'Cell',
      name = `Bench Junk {index}`,
      data = { flags = 'IS_INTERIOR', grid = { 0, 0 } },
    })

    table.insert(dirt, static(90000 + index, 0))
    table.insert(dirt, static(90000 + index, 0))
  end

  write(built, 'Dirty.esp', { master }, dirt)

  local late = write(built, 'Late.esm', {}, {})
  write(built, 'Early.esp', { late }, {})
  write(built, 'Orphan.esp', { { name = 'Gone.esm', size = 1 } }, {})
  write(built, 'Needs.esp', { write(built, 'Unlisted.esm', {}, {}) }, {})
  io(fs.writeFile(`{built.data}/Broken.esp`, 'not a plugin'))
  io(
    fs.writeFile(
      `{built.data}/Scripts.omwscripts`,
      'PLAYER: scripts/bench/gone.lua\nGLOBAL scripts/bench/b.lua\n'
    )
  )

  -- Two files in five are there, and no model among them is one that loads.
  for _, file in Files do
    io(fs.mkdir(`{built.data}/{file.folder}/bench`, { recursive = true }))

    for index = 0, file.count - 1 do
      if index % 5 > 1 then continue end

      io(
        fs.writeFile(
          `{built.data}/{file.folder}/bench/{file.name}_{index}.{file.extension}`,
          'not a model'
        )
      )
    end
  end

  configure(built, {
    'Bench.esm',
    'Rebalance.esp',
    'Overhaul.esp',
    'Tweaks.esp',
    'Patch.esp',
    'Dirty.esp',
    'Early.esp',
    'Late.esm',
    'Orphan.esp',
    'Needs.esp',
    'Broken.esp',
    'Missing.esp',
    'Scripts.omwscripts',
  })

  return built
end

--- Whether the `plugin`th of the thirty defines the master's `index`th record of a kind again:
--- one record in seven, a different seventh for each plugin.
local function picks(index: number, plugin: number): boolean
  return bit32.rshift(bit32.bxor(index * 2654435761, plugin * 2246822519), 13) % 7 == 0
end

--- Thirty plugins over one master, each dropping what the ones before it changed.
local function thirtyPlugins(): Order
  local built = order 'thirty'
  local master = write(built, 'Bench.esm', {}, masterRecords(4))
  local content = { master.name }

  for plugin = 1, 30 do
    local records: { Fields } = {}

    for _, kind in Kinds do
      for index = 1, kind.count // 4 do
        if picks(index, plugin) then table.insert(records, kind.make(index, 4 + plugin)) end
      end
    end

    for index = 1, 40 do
      table.insert(records, static(plugin * 1000 + index, plugin))
    end

    table.insert(content, write(built, `Mod {plugin}.esp`, { master }, records).name)
  end

  configure(built, content)
  return built
end

--- A master whose every model is one nothing provides.
local function missingPack(): Order
  local built = order 'pack'
  local records: { Fields } = {}

  for index = 1, 4000 do
    records[index] =
      { type = 'Static', id = `bench_pack_{index}`, mesh = `pack\\{index % 64}\\piece_{index}.nif` }
  end

  configure(built, { write(built, 'Pack.esm', {}, records).name })
  return built
end

--- `text` without the scratch folder's path, which a report holds wherever it names a file.
local function unrooted(text: string): string
  return table.concat(string.split(text, Root), '<root>')
end

--- What a check did, as one line: its report's counts, and the file it wrote.
local function weigh(options: doctor.Options): string
  local report = assert(options.report, 'the doctor left no report')
  local summary = report.summary
  local digest = bytes.sha256(unrooted(io(fs.readFileString(report.output))))

  return `{report.plugins} of {report.contentFiles} files, {summary.errors} errors, {summary.warnings} warnings, {summary.info} info, {digest}`
end

local function median(samples: { number }): number
  table.sort(samples)
  return samples[(#samples + 1) // 2]
end

--- Seconds per call of `body`: warmed up, then the median of seven batches of a size that takes
--- about a tenth of a second. `verify` is given the result of the first call and of one more
--- after the last batch, outside the time.
local function measure<Result>(body: () -> Result, verify: (result: Result) -> ()): number
  jess.bench.collect()
  verify(body())

  local start = os.clock()
  body()

  local once = math.max(os.clock() - start, 1e-7)
  local iterations = math.max(1, math.floor(0.1 / once))
  local samples: { number } = {}

  for batch = 1, 7 do
    jess.bench.collect()
    start = os.clock()

    for _ = 1, iterations do
      body()
    end

    samples[batch] = (os.clock() - start) / iterations
  end

  verify(body())
  return median(samples)
end

--- Times `body`, whose every call must weigh `expected`.
local function workload<Result>(
  name: string,
  expected: string,
  body: () -> Result,
  weight: (result: Result) -> string
)
  if not runs(name) then return end

  local function verify(result: Result)
    local actual = weight(result)
    if actual ~= expected then error(`{name}: did "{actual}", not "{expected}"`, 0) end
  end

  print(`{name}\t{string.format('%.9f', measure(body, verify))}`)
end

--- Removes the backup of `built`'s report in `format`, so every check backs up the report before
--- it under the one name. The doctor keeps each report it replaces under a name not yet taken,
--- and looking for one takes longer the more there are.
local function settle(built: Order, format: string) fs.remove(`{built.report}.{format}.bak`) end

--- Times a check of `built` under the options `make` gives, which are made anew for each call:
--- the doctor leaves its report in them.
local function check(name: string, expected: string, built: Order, make: () -> doctor.Options)
  workload(name, expected, function(): doctor.Options
    local options = make()
    settle(built, options.format or 'yaml')
    doctor({ doctor = options }, openmw.new(built.config))
    return options
  end, weigh)
end

if fs.exists(Root) then io(fs.remove(Root, { recursive = true })) end

local Load, Thirty, Pack = loadOrder(), thirtyPlugins(), missingPack()

--- The digest of the load order's whole report, as YAML.
local Whole = '8d1abb1be1ac134925e34752285cc81b43107062aaee9b0c044f44467883b35e'

check(
  'check a load order, every check',
  `10 of 13 files, 65 errors, 20 warnings, 2 info, {Whole}`,
  Load,
  function(): doctor.Options return {} end
)

check(
  'check a load order, every check, as json',
  '10 of 13 files, 65 errors, 20 warnings, 2 info, 75a7273ce830e294fb369e66bd2cb0bf1dd2e918f8bd9c29e662205f765008ea',
  Load,
  function(): doctor.Options return { format = 'json' } end
)

check(
  'check a load order, masters and content',
  '10 of 13 files, 5 errors, 0 warnings, 1 info, a57c16f14c5f9f8f5db4cf21e8e067237a53b9afd502f97174a0be55f7fe38ed',
  Load,
  function(): doctor.Options return { checks = { 'masters', 'content' } } end
)

check(
  'check a load order, assets',
  '10 of 13 files, 1 errors, 13 warnings, 0 info, d5aedcd84226aa7e0111b0a38b42267baabe24cb97bb9d2fc0b29ba7e1fa0177',
  Load,
  function(): doctor.Options return { checks = { 'assets' } } end
)

check(
  'check a load order, meshes',
  '10 of 13 files, 61 errors, 0 warnings, 0 info, c918710fe3a7dd6dac670aa28b08d280ab13d2d69646b3147ea3a03512bb22c0',
  Load,
  function(): doctor.Options return { checks = { 'meshes' } } end
)

check(
  'check a load order, dirt',
  '10 of 13 files, 1 errors, 4 warnings, 1 info, 8b34a4e92367700a75f2ba2301e03a4fd0b5f34027c47c7abb6c34527763d33b',
  Load,
  function(): doctor.Options return { checks = { 'dirt' } } end
)

check(
  'check a load order, conflicts',
  '10 of 13 files, 1 errors, 3 warnings, 0 info, 5bb330a8963e5d639fc4ceaf998d351c6ce94eb180f37b4b615c7bdd14170ccd',
  Load,
  function(): doctor.Options return { checks = { 'conflicts' } } end
)

check(
  'check a load order, errors only',
  '10 of 13 files, 65 errors, 0 warnings, 0 info, 9d4b5e5ca0b6d9e66e1d67259a65f563f4dae11bbc0150b7f1e95207eb366b46',
  Load,
  function(): doctor.Options return { minSeverity = 'error' } end
)

check(
  'check thirty plugins, every check',
  '31 of 31 files, 0 errors, 300 warnings, 0 info, 1c9b4cb342fe246324bc97325d58a5e0f34f9c2cc958277bc6a513dfd9fa32ef',
  Thirty,
  function(): doctor.Options return {} end
)

check(
  'check thirty plugins, conflicts',
  '31 of 31 files, 0 errors, 246 warnings, 0 info, 8b2ecb0759f55530ecf252769b2c8d38e12d6dbbf24cde6903e26d03e7de9fba',
  Thirty,
  function(): doctor.Options return { checks = { 'conflicts' } } end
)

check(
  'check thirty plugins, conflicts, as json',
  '31 of 31 files, 0 errors, 246 warnings, 0 info, ab2d7fc04349d5a74f32bc823f89c2f1403f294f67d728cfc7c17a17ea75aafd',
  Thirty,
  function(): doctor.Options return { checks = { 'conflicts' }, format = 'json' } end
)

check(
  'check a master missing its 4,000 models, assets',
  '1 of 1 files, 0 errors, 1 warnings, 0 info, 0d0fe8eae5f0ed0072497a61a7110fd780af2a5afa679df3ad22e267446e0382',
  Pack,
  function(): doctor.Options return { checks = { 'assets' } } end
)

check(
  'check a master missing its 4,000 models, assets, as json',
  '1 of 1 files, 0 errors, 1 warnings, 0 info, 5c00869feafd02f2065dde262a2955c538d06c324fc82e397eaa2c9dbb494734',
  Pack,
  function(): doctor.Options return { checks = { 'assets' }, format = 'json' } end
)

--- Argument lists the command line takes, in every spelling it reads.
local ArgumentLists: { { string } } = {
  { '--config', Load.config },
  { '--config', Load.config, '--checks', 'masters,content', '--min-severity', 'error' },
  { `--config={Load.config}`, '--checks=assets', '--checks=meshes', '--format=json' },
  { '--checks', 'dirt', '--checks', 'conflicts,masters', '--output', `{Root}/out.yaml` },
  { '--verbose', '--format', 'yaml', '--min-severity=warning', `--output={Root}/out.yaml` },
  { '--checks=masters,content,assets,meshes,dirt,conflicts', '--verbose' },
  { '--help' },
  { '-h', '--verbose' },
}

workload('parse 8 argument lists', '6 checks, 13 names, 9 values', function(): string
  local checks, names, values = 0, 0, 0

  for _, argv in ArgumentLists do
    local command = assert(cli.parse(argv))
    local options = command.options
    if not options then continue end

    checks += 1
    names += #(options.checks or {})
    values += (if command.config then 1 else 0)
      + (if options.output then 1 else 0)
      + (if options.format then 1 else 0)
      + (if options.minSeverity then 1 else 0)
  end

  return `{checks} checks, {names} names, {values} values`
end, function(result: string): string return result end)

workload('the command, a load order', `0, {Whole}`, function(): number
  settle(Load, 'yaml')
  return cli.run { '--config', Load.config }
end, function(status: number): string
  return `{status}, {bytes.sha256(unrooted(io(fs.readFileString(`{Load.report}.yaml`))))}`
end)

--- Times the command line run once on `argv`, a process a sample. It must exit 0 and its last
--- line must be `expected`. A run that checks `built` finds no report there to back up.
local function cold(name: string, expected: string, argv: { string }, built: Order?)
  if not binary or not runs(name) then return end

  local arguments = {
    'run',
    '--capability',
    'filesystem.read',
    '--capability',
    'filesystem.write',
    '--package',
    `{Here}/..`,
    '--package-path',
    PackagePath,
    -- Past this, an argument that starts with a dash is the script's and not `jess run`'s.
    '--',
    `{Here}/cold.luau`,
  }

  for _, argument in argv do
    table.insert(arguments, argument)
  end

  local samples: { number } = {}

  for run = 1, 7 do
    if built then
      fs.remove(`{built.report}.yaml`)
      settle(built, 'yaml')
    end

    local result, message = process.run(binary, arguments, { stdout = 'capture', stderr = 'null' })
    if not result then error(`{name}: {message}`, 0) end

    local printed = result.stdout or ''
    local last, status, seconds = string.match(printed, '([^\n]*)\n\n(%d+)\t([%d.]+)\n$')
    if status ~= '0' or last ~= expected then
      error(`{name}: exited {status} having printed "{last}", not 0 and "{expected}"`, 0)
    end

    samples[run] = tonumber(seconds) :: number
  end

  print(`{name}\t{string.format('%.9f', median(samples))}`)
end

cold('cold: --help', 'failed.', { '--help' })
cold(
  'cold: the command, masters and content',
  `report: {Load.report}.yaml`,
  { '--config', Load.config, '--checks', 'masters,content' },
  Load
)

cold(
  'cold: the command, a load order',
  `report: {Load.report}.yaml`,
  { '--config', Load.config },
  Load
)

cold(
  'cold: the command, a master missing its 4,000 models',
  `report: {Pack.report}.yaml`,
  { '--config', Pack.config },
  Pack
)

io(fs.remove(Root, { recursive = true }))
