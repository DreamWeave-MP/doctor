--!strict
--!native
-- The doctor's cases. The first group is the tool's old harness (`tests/doctor.rs` in jess's
-- history), scenario for scenario, over the load order `build.luau` builds: one of every problem
-- the doctor looks for. The rest take a check, a severity, or an option each, on load orders made
-- for them; the dirt cases hold `@tes3cmd`'s lint to the messages the old `plugin:lint` wrote.
local doctor = require '@doctor'
local json = require '@jess/json'
local nif = require '@nif'
local order = require './order'
local tes3 = require '@tes3'
local test = require '@jess/test'
local yaml = require '@jess/yaml'

local expect = test.expect
local suite = test.new()

--- The first finding of `kind` whose message has `text` in it; the suite stops without one.
local function find(report: doctor.Report, kind: string, text: string): doctor.Finding
  for _, finding in order.findings(report, kind) do
    if string.find(finding.message, text, 1, true) then return finding end
  end

  return error(`no {kind} finding with '{text}'`, 0)
end

local function has(text: string, part: string): boolean return string.find(text, part, 1, true) ~= nil end

--- `text` with every `<root>` spelled as the load order's folder.
local function rooted(text: string, root: string): string
  return (string.gsub(text, '<root>', function(): string return root end))
end

--- What a report file holds: the report without where it was written.
local function written(report: doctor.Report): { [string]: unknown }
  return {
    config = report.config,
    contentFiles = report.contentFiles,
    plugins = report.plugins,
    checks = report.checks,
    summary = report.summary,
    findings = report.findings,
  }
end

--- The harness's load order's report, as YAML: every key in the order the doctor writes it.
local Yaml = [[
config: <root>/config/openmw.cfg
contentFiles: 11
plugins: 9
checks:
- masters
- content
- assets
- meshes
- dirt
- conflicts
summary:
  errors: 6
  warnings: 5
  info: 1
  byCheck:
    missingContent: 1
    unreadablePlugin: 1
    missingMaster: 2
    masterOrder: 1
    conflict: 1
    missingAsset: 2
    mesh: 1
    evilGmsts: 1
    junkCells: 1
    identicalToMaster: 1
findings:
- severity: error
  check: missingContent
  plugins:
  - Missing.esp
  message: Missing.esp is in the load order, but no data folder has it
  fix: "install the mod that provides Missing.esp, or remove content=Missing.esp from openmw.cfg"
- severity: error
  check: unreadablePlugin
  plugins:
  - Broken.esp
  message: "Broken.esp can't be read: failed to parse '<root>/data/Broken.esp': truncated record header at offset 0"
  fix: "reinstall the mod that provides Broken.esp, or remove content=Broken.esp from openmw.cfg"
  files:
  - <root>/data/Broken.esp
- severity: error
  check: missingMaster
  plugins:
  - Needs.esp
  - Unlisted.esm
  message: "Needs.esp needs Unlisted.esm, which isn't in the load order"
  fix: "add content=Unlisted.esm to openmw.cfg above content=Needs.esp"
- severity: error
  check: missingMaster
  plugins:
  - Orphan.esp
  - Gone.esm
  message: "Orphan.esp needs Gone.esm, which isn't in the load order"
  fix: "install Gone.esm, or remove content=Orphan.esp from openmw.cfg"
- severity: error
  check: masterOrder
  plugins:
  - Early.esp
  - Late.esm
  message: Early.esp loads before its master Late.esm
  fix: "move content=Late.esm above content=Early.esp in openmw.cfg"
- severity: error
  check: mesh
  plugins: []
  message: "meshes/doctor/rock.nif: truncated version line at offset 0"
  fix: "`jess nif check` on the file for the details; `jess nif fix` repairs some"
  records:
  - STAT doctor_rock
  files:
  - meshes/doctor/rock.nif
  details:
  - "invalidHeader: truncated version line at offset 0"
- severity: warning
  check: conflict
  plugins:
  - A.esp
  - B.esp
  message: B.esp replaces 2 records A.esp changed, dropping its changes (1 of them tes3merge can merge)
  fix: "merge them with tes3merge, and load Merged Objects.esp last; patch the 1 record it can't merge in a plugin loading after B.esp, or drop one of the two"
  records:
  - MISC doctor_gem
  - GLOB doctor_global
- severity: warning
  check: missingAsset
  plugins:
  - B.esp
  message: B.esp refers to 1 file nothing provides (missingMesh)
  fix: install the mod that provides them, or fix the paths in B.esp
  records:
  - MISC doctor_gem
  files:
  - "doctor\\gem.nif"
- severity: warning
  check: missingAsset
  plugins:
  - Patch.esp
  message: Patch.esp refers to 1 file nothing provides (missingMesh)
  fix: install the mod that provides them, or fix the paths in Patch.esp
  records:
  - STAT doctor_tree
  files:
  - d.nif
- severity: warning
  check: evilGmsts
  plugins:
  - Dirty.esp
  message: Dirty.esp has 1 evil GMST
  fix: "`jess plugin clean <root>/data/Dirty.esp --evil-gmsts`"
  details:
  - "GMST fWerewolfHealth at record 1 has Bloodmoon's default value"
- severity: warning
  check: junkCells
  plugins:
  - Dirty.esp
  message: Dirty.esp has 1 junk cell
  fix: "`jess plugin clean <root>/data/Dirty.esp --junk-cells`"
  details:
  - CELL Doctor Junk at record 2
- severity: info
  check: identicalToMaster
  plugins:
  - B.esp
  message: "B.esp has 1 record identical to its masters' copies"
  fix: "`jess plugin clean <root>/data/B.esp --duplicate-records`"
  records:
  - STAT doctor_rock
]]

--- How the same report starts and ends as JSON.
local JsonStart = [[
{
  "config": "<root>/config/openmw.cfg",
  "contentFiles": 11,
  "plugins": 9,
  "checks": [
    "masters",
    "content",
    "assets",
    "meshes",
    "dirt",
    "conflicts"
  ],
  "summary": {
    "errors": 6,
    "warnings": 5,
    "info": 1,
    "byCheck": {
      "missingContent": 1,
      "unreadablePlugin": 1,
      "missingMaster": 2,
      "masterOrder": 1,
      "conflict": 1,
      "missingAsset": 2,
      "mesh": 1,
      "evilGmsts": 1,
      "junkCells": 1,
      "identicalToMaster": 1
    }
  },
  "findings": [
    {
      "severity": "error",
      "check": "missingContent",
      "plugins": [
        "Missing.esp"
      ],
      "message": "Missing.esp is in the load order, but no data folder has it",
      "fix": "install the mod that provides Missing.esp, or remove content=Missing.esp from openmw.cfg"
    },
]]

local JsonEnd = [[
    {
      "severity": "info",
      "check": "identicalToMaster",
      "plugins": [
        "B.esp"
      ],
      "message": "B.esp has 1 record identical to its masters' copies",
      "fix": "`jess plugin clean <root>/data/B.esp --duplicate-records`",
      "records": [
        "STAT doctor_rock"
      ]
    }
  ]
}
]]

suite.describe('the harness\'s load order', function()
  suite.it('has every kind of problem found in it, and nothing changed', function()
    local built = order.harness 'report'
    local before = order.files(built.root)
    local run = order.check(built, { format = 'json' })
    local report = run.report
    local path = jess.fs.join(built.config, 'jess-doctor.json')
    expect(has(run.printed, 'doctor: 6 errors')).toBe(true)
    expect(has(run.printed, `report: {path}\n`)).toBe(true)
    expect(report.output).toBe(path)
    expect(report.backup).toBeNil()

    -- `state.doctor.report` is the report written.
    local text = jess.fs.read(path)
    expect(json.decode(text)).toEqual(written(report))
    expect(string.sub(text, 1, #rooted(JsonStart, built.root))).toBe(rooted(JsonStart, built.root))
    expect(string.sub(text, -#rooted(JsonEnd, built.root))).toBe(rooted(JsonEnd, built.root))

    local missing = find(report, 'missingContent', 'Missing.esp')
    expect(missing.severity).toBe 'error'
    expect(has(missing.fix, 'remove content=Missing.esp from openmw.cfg')).toBe(true)
    find(report, 'unreadablePlugin', 'Broken.esp')
    expect(string.sub(find(report, 'missingMaster', 'Orphan.esp needs Gone.esm').fix, 1, 16)).toBe 'install Gone.esm'

    -- An installed master gets enabled.
    expect(
      has(
        find(report, 'missingMaster', 'Needs.esp needs Unlisted.esm').fix,
        'add content=Unlisted.esm to openmw.cfg above content=Needs.esp'
      )
    ).toBe(true)
    find(report, 'masterOrder', 'Early.esp loads before its master Late.esm')

    local conflict = find(report, 'conflict', 'B.esp replaces 2 records A.esp changed')
    expect(conflict.severity).toBe 'warning'
    expect(has(conflict.message, '1 of them tes3merge can merge')).toBe(true)
    expect(has(conflict.fix, 'merge them with tes3merge')).toBe(true)
    expect(has(conflict.fix, 'patch the 1 record')).toBe(true)
    expect(conflict.plugins).toEqual { 'A.esp', 'B.esp' }
    expect(conflict.records).toEqual { 'MISC doctor_gem', 'GLOB doctor_global' }

    -- A patch with both plugins as masters settles their conflict.
    for _, finding in report.findings do
      expect(has(finding.message, 'Patch.esp replaces')).toBe(false)
    end

    local dirty = jess.fs.join(built.data, 'Dirty.esp')
    expect(find(report, 'evilGmsts', 'Dirty.esp has 1 evil GMST').fix).toBe(
      `\`jess plugin clean {dirty} --evil-gmsts\``
    )
    find(report, 'junkCells', 'Dirty.esp has 1 junk cell')
    find(report, 'identicalToMaster', 'B.esp has 1 record identical')
    expect(find(report, 'missingAsset', 'B.esp refers to 1 file nothing provides').severity).toBe 'warning'

    local mesh = find(report, 'mesh', 'meshes/doctor/rock.nif')
    expect(mesh.severity).toBe 'error'
    expect(has(mesh.fix, 'jess nif check')).toBe(true)

    -- Most severe first.
    local ranks = { error = 1, warning = 2, info = 3 }
    for position = 2, #report.findings do
      local earlier, later = report.findings[position - 1], report.findings[position]
      expect(ranks[earlier.severity] <= ranks[later.severity]).toBe(true)
    end

    -- The report is the only file the doctor writes.
    local after = order.files(built.root)
    expect(after[path]).toBe(text)
    after[path] = nil
    expect(after).toEqual(before)

    -- A second run backs the first report up.
    local again = order.check(built, { format = 'json' })
    expect(again.report.backup).toBe(path .. '.bak')
    expect(jess.fs.read(path .. '.bak')).toBe(text)
    expect(has(again.printed, `report: {path} (the last one is in {path}.bak)\n`)).toBe(true)
  end)

  suite.it('is reported as YAML beside the user config by default', function()
    local built = order.harness 'yaml'
    local run = order.check(built, {})
    local path = jess.fs.join(built.config, 'jess-doctor.yaml')
    expect(has(run.printed, `report: {path}\n`)).toBe(true)

    local text = jess.fs.read(path)
    expect(string.sub(text, 1, #`config: {built.cfg}`)).toBe(`config: {built.cfg}`)
    for _, expected in {
      'summary:\n  errors: 6\n',
      'findings:\n- severity: error\n  check: missingContent\n  plugins:\n  - Missing.esp\n',
      '  fix: "install the mod that provides Missing.esp, or remove content=Missing.esp from openmw.cfg"\n',
      '  records:\n  - MISC doctor_gem\n  - GLOB doctor_global\n',
    } do
      expect(has(text, expected)).toBe(true)
    end

    -- The whole file, key for key and line for line; it reads back as the report it is.
    expect(text).toBe(rooted(Yaml, built.root))
    expect(yaml.decode(text)).toEqual(written(run.report))
  end)

  suite.it('is checked with the checks, severity, and output asked for', function()
    local built = order.harness 'options'
    local output = jess.fs.join(built.out, 'checked.json')
    local run = order.check(built, {
      checks = { 'masters', 'content' },
      minSeverity = 'error',
      format = 'json',
      output = output,
    })
    expect(jess.fs.exists(jess.fs.join(built.config, 'jess-doctor.json'))).toBe(false)

    local report = json.decode(jess.fs.read(output)) :: doctor.Report
    expect(report.checks).toEqual { 'masters', 'content' }
    expect(report.summary.errors).toBe(#report.findings)
    expect(report.summary.warnings).toBe(0)
    expect(#report.findings).toBe(5)

    local allowed = { 'missingContent', 'unreadablePlugin', 'missingMaster', 'masterOrder' }
    for _, finding in report.findings do
      expect(finding.severity).toBe 'error'
      expect(table.find(allowed, finding.check) ~= nil).toBe(true)
    end

    expect(run.report.output).toBe(output)

    local bad = order.harness 'bad-check'
    expect(function() order.check(bad, { checks = { 'vibes' } }) end).toThrow(
      'doctor: unknown check "vibes"; expected masters, content, assets, meshes, dirt, conflicts'
    )
  end)

  -- The harness ran `@jess/tes3merge` first, in the same state, without activating its plugin.
  -- What the doctor reads of that run is `state.tes3merge.report`, which is here as the merge
  -- leaves it: a table.
  suite.it('is checked knowing TES3Merge handles a conflict', function()
    local built = order.harness 'tes3merge'
    local state: { [string]: unknown } = { tes3merge = { report = { merged = {}, failed = {} } } }
    local report = order.check(built, { format = 'json', checks = { 'conflicts' } }, state).report

    local unlisted = find(report, 'tes3merge', 'Merged Objects.esp isn\'t in the load order')
    expect(unlisted.severity).toBe 'warning'
    expect(has(unlisted.fix, 'add content=Merged Objects.esp to openmw.cfg')).toBe(true)

    -- The global still needs a patch.
    local conflict = find(report, 'conflict', 'B.esp replaces 2 records A.esp changed')
    expect(conflict.severity).toBe 'warning'
    expect(string.sub(conflict.fix, 1, 31)).toBe 'Merged Objects.esp merges these'
  end)
end)

local function static(id: string, mesh: string): order.Fields
  return { type = 'Static', id = id, mesh = mesh }
end

local function gem(name: string): order.Fields
  return { type = 'MiscItem', id = 'gem', name = name, data = { weight = 1, value = 1 } }
end

--- A CELL record's bytes with its DATA subrecord there twice: what `tes3.encode` writes for
--- `cell`, and a copy of DATA after the first.
local function cellWithRepeatedData(cell: order.Fields): buffer
  local built = tes3.new()
  built:insertValue(1, cell)

  local record = built:bytes(1)
  for _, subrecord in built:subrecords(1) do
    if subrecord.tag ~= 'DATA' then continue end

    local length = subrecord.finish - subrecord.start
    local repeated = buffer.create(buffer.len(record) + length)
    buffer.copy(repeated, 0, record, 0, subrecord.finish)
    buffer.copy(repeated, subrecord.finish, record, subrecord.start, length)
    buffer.copy(repeated, subrecord.finish + length, record, subrecord.finish)
    buffer.writeu32(repeated, 4, buffer.readu32(record, 4) + length)
    return repeated
  end

  return error('the cell has no DATA', 0)
end

suite.describe('dirt', function()
  -- Each message is the one jess-omwaddon's lint wrote for the check (`lint.rs` in jess's
  -- history), which the doctor lists as the finding's details.
  suite.it('is each kind `jess plugin clean` removes, with the lint\'s own words', function()
    local dirty = tes3.new()
    dirty:setMasters { { name = 'Base.esm', size = 1 } }
    for _, record in {
      static('twice', 'a.nif'),
      static('twice', 'a.nif'),
      static('TWICE', 'b.nif'),
      { type = 'GameSetting', id = 'fWerewolfHealth', value = { type = 'Float', data = 2 } },
      { type = 'GameSetting', id = 'fKept', value = { type = 'Float', data = 2 } },
      { type = 'Cell', name = 'Junk', data = { flags = 'IS_INTERIOR', grid = { 0, 0 } } },
      { type = 'Cell', name = 'Kept', data = { flags = 'IS_INTERIOR', grid = { 0, 0 } }, waterHeight = 1 },
    } :: { order.Fields } do
      dirty:insertValue(dirty:count(), record)
    end

    dirty:insert(
      dirty:count(),
      cellWithRepeatedData {
        type = 'Cell',
        name = 'Repeated',
        data = { flags = 'IS_INTERIOR', grid = { 0, 0 } },
        waterHeight = 2,
      }
    )
    dirty:updateRecordCount()

    local built = order.order('dirt', {
      ['Base.esm'] = order.plugin({}, nil, 'master'),
      ['Dirty.esp'] = dirty:save(),
    }, { 'Base.esm', 'Dirty.esp' })
    local report = order.check(built, { checks = { 'dirt' } }).report
    local path = jess.fs.join(built.data, 'Dirty.esp')
    expect(report.summary).toEqual {
      errors = 0,
      warnings = 3,
      info = 1,
      byCheck = { evilGmsts = 1, junkCells = 1, duplicateRecords = 1, cellParams = 1 },
    }

    expect(report.findings).toEqual {
      {
        severity = 'warning',
        check = 'evilGmsts',
        plugins = { 'Dirty.esp' },
        details = { 'GMST fWerewolfHealth at record 4 has Bloodmoon\'s default value' },
        message = 'Dirty.esp has 1 evil GMST',
        fix = `\`jess plugin clean {path} --evil-gmsts\``,
      },
      {
        severity = 'warning',
        check = 'junkCells',
        plugins = { 'Dirty.esp' },
        details = { 'CELL Junk at record 6' },
        message = 'Dirty.esp has 1 junk cell',
        fix = `\`jess plugin clean {path} --junk-cells\``,
      },
      {
        severity = 'warning',
        check = 'duplicateRecords',
        plugins = { 'Dirty.esp' },
        details = {
          'STAT twice at record 2 duplicates record 1',
          -- Ids are the same record whatever their case, and each repeat names the one before.
          'STAT TWICE at record 3 duplicates record 2',
        },
        message = 'Dirty.esp has 2 records it defines twice',
        fix = `\`jess plugin clean {path} --duplicate-records\``,
      },
      {
        severity = 'info',
        check = 'cellParams',
        plugins = { 'Dirty.esp' },
        details = { 'duplicate DATA in CELL record 8' },
        message = 'Dirty.esp has 1 repeated cell setting',
        fix = `\`jess plugin clean {path} --cell-params\``,
      },
    }
  end)

  suite.it('is left alone in Bethesda\'s masters, and quoted in a fix when its path needs it', function()
    local records: { order.Fields } = {
      { type = 'GameSetting', id = 'fWerewolfHealth', value = { type = 'Float', data = 2 } },
    }

    local built = order.order('dirt-official', {
      ['Morrowind.esm'] = order.plugin(records, nil, 'master'),
      ['tribunal.esm'] = order.plugin(records, nil, 'master'),
      ['BLOODMOON.ESM'] = order.plugin(records, nil, 'master'),
      ['My Mod.esp'] = order.plugin(records),
    }, { 'Morrowind.esm', 'Tribunal.esm', 'Bloodmoon.esm', 'My Mod.esp' })
    local report = order.check(built, { checks = { 'dirt' } }).report
    expect(#report.findings).toBe(1)
    expect(report.findings[1].plugins).toEqual { 'My Mod.esp' }
    expect(report.findings[1].fix).toBe(
      `\`jess plugin clean "{jess.fs.join(built.data, 'My Mod.esp')}" --evil-gmsts\``
    )
    expect(report.plugins).toBe(4)
  end)

  suite.it('counts a record identical to its master\'s only where that master is named', function()
    local rock = static('rock', 'rock.nif')
    local base = order.plugin({ rock, gem 'Gem' }, nil, 'master')
    local built = order.order('identical', {
      ['Base.esm'] = base,
      ['Named.esp'] = order.plugin({ rock, gem 'Gem' }, { { name = 'Base.esm', size = #buffer.tostring(base) } }),
      ['Unnamed.esp'] = order.plugin { rock },
    }, { 'Base.esm', 'Named.esp', 'Unnamed.esp' })

    local report = order.check(built, { checks = { 'dirt' } }).report
    expect(report.findings).toEqual {
      {
        severity = 'info',
        check = 'identicalToMaster',
        plugins = { 'Named.esp' },
        -- In the order the load order first defines them.
        records = { 'STAT rock', 'MISC gem' },
        message = 'Named.esp has 2 records identical to its masters\' copies',
        fix = `\`jess plugin clean {jess.fs.join(built.data, 'Named.esp')} --duplicate-records\``,
      },
    }

    -- The comparison is the conflict check's, but identical records are dirt: without the dirt
    -- check they aren't reported.
    expect(order.check(built, { checks = { 'conflicts' } }).report.findings).toEqual {}
  end)
end)

suite.describe('masters', function()
  suite.it('are compared by the size each plugin records', function()
    local base = order.plugin({ static('rock', 'rock.nif') }, nil, 'master')
    local size = #buffer.tostring(base)
    local built = order.order('master-size', {
      ['Base.esm'] = base,
      ['Right.esp'] = order.plugin({}, { { name = 'base.ESM', size = size } }),
      ['Wrong.esp'] = order.plugin({}, { { name = 'Base.esm', size = 7 } }),
    }, { 'Base.esm', 'Right.esp', 'Wrong.esp' })
    local report = order.check(built, { checks = { 'masters' } }).report
    expect(report.findings).toEqual {
      {
        severity = 'info',
        check = 'masterSize',
        plugins = { 'Wrong.esp', 'Base.esm' },
        message = `Wrong.esp records Base.esm as 7 bytes; it's {size}`,
        fix = `\`jess plugin header {jess.fs.join(built.data, 'Wrong.esp')} --update-masters\` (OpenMW doesn't mind; Morrowind.exe and the CS do)`,
      },
    }

    -- Only the headers are read for it, and every plugin still counts as read.
    expect(report.plugins).toBe(3)
    expect(report.contentFiles).toBe(3)
  end)
end)

local Triangle = { { 0, 0, 0 }, { 1, 0, 0 }, { 0, 1, 0 } }

--- A model: a triangle under a root node, drawn with `texture` when one is named; with
--- `lowercase`, a lowercase `NCc`, which turns its collision off; with `marker`, the shape named
--- as an editor marker, which draws.
local function model(texture: string?, lowercase: boolean?, marker: boolean?): buffer
  local file = nif.new()
  local root = file:insert { type = 'NiNode', name = 'Root' }
  if lowercase then
    local rootNode = file:record(root) :: { [string]: unknown }
    rootNode.extraData = file:insert { type = 'NiStringExtraData', value = 'NCc', bytesRemaining = 7 }
  end

  file:shape {
    name = if marker then 'Tri EditorMarker 0' else 'Tri Shape',
    vertices = Triangle,
    triangles = { { 0, 1, 2 } },
    texture = texture,
    parent = root,
  }
  file.roots = { root }

  return file:save()
end

suite.describe('assets and models', function()
  suite.it('groups what a plugin refers to by what is wrong, and reads script lists', function()
    local records: { order.Fields } = {
      static('one', 'gone\\one.nif'),
      static('two', 'gone\\two.nif'),
      static('again', 'gone\\one.nif'),
      { type = 'MiscItem', id = 'coin', icon = 'coin.tga' },
      { type = 'Book', id = 'open', text = '<IMG SRC="x.tga' },
      -- A texture that isn't a .dds and the placeholder model are milder than the doctor asks for.
      { type = 'LandscapeTexture', id = 'sand', index = 1, fileName = 'tx_sand.tga' },
      { type = 'MiscItem', id = 'ghost', mesh = 'Add World Art' },
    }

    local built = order.order('assets', {
      ['Mod.esp'] = order.plugin(records),
      ['Scripts.omwscripts'] = 'PLAYER: scripts/gone.lua\nGLOBAL scripts/b.lua\n',
      ['textures/tx_sand.tga'] = '',
    }, { 'Mod.esp', 'Scripts.omwscripts' })
    local report = order.check(built, { checks = { 'assets' } }).report
    expect(report.plugins).toBe(1)
    expect(report.contentFiles).toBe(2)
    expect(report.findings).toEqual {
      {
        severity = 'warning',
        check = 'badRecord',
        plugins = { 'Mod.esp' },
        records = { 'BOOK open' },
        files = {},
        message = 'Mod.esp has 1 record OpenMW reads wrong (bookMarkupError)',
        fix = 'fix these records in Mod.esp, or ask its author to',
      },
      {
        severity = 'warning',
        check = 'badRecord',
        plugins = { 'Scripts.omwscripts' },
        records = { 'omwscripts line 2' },
        files = {},
        message = 'Scripts.omwscripts has 1 record OpenMW reads wrong (omwscriptsError)',
        fix = 'fix these records in Scripts.omwscripts, or ask its author to',
      },
      {
        severity = 'warning',
        check = 'missingAsset',
        plugins = { 'Mod.esp' },
        records = { 'MISC coin' },
        files = { 'coin.tga' },
        message = 'Mod.esp refers to 1 file nothing provides (missingIcon)',
        fix = 'install the mod that provides them, or fix the paths in Mod.esp',
      },
      {
        severity = 'warning',
        check = 'missingAsset',
        plugins = { 'Mod.esp' },
        -- Every record that names a missing file, and each file once.
        records = { 'STAT one', 'STAT two', 'STAT again' },
        files = { 'gone\\one.nif', 'gone\\two.nif' },
        message = 'Mod.esp refers to 2 files nothing provides (missingMesh)',
        fix = 'install the mod that provides them, or fix the paths in Mod.esp',
      },
      {
        severity = 'warning',
        check = 'missingAsset',
        plugins = { 'Scripts.omwscripts' },
        records = { 'omwscripts line 1' },
        files = { 'scripts/gone.lua' },
        message = 'Scripts.omwscripts refers to 1 file nothing provides (missingScript)',
        fix = 'install the mod that provides them, or fix the paths in Scripts.omwscripts',
      },
    }
  end)

  suite.it('grades a model by the worst thing wrong with it that matters in OpenMW', function()
    local records: { order.Fields } = {
      static('clean', 'clean.nif'),
      static('junk', 'junk.nif'),
      static('bare', 'bare.nif'),
      static('uncollided', 'uncollided.nif'),
      static('marker', 'marker.nif'),
      static('plain', 'plain.nif'),
      { type = 'Creature', id = 'guar', mesh = 'actor.nif' },
    }

    local built = order.order('meshes', {
      ['Mod.esp'] = order.plugin(records),
      ['meshes/clean.nif'] = model 'tx_a.tga',
      ['meshes/junk.nif'] = 'junk\nmore',
      ['meshes/bare.nif'] = model 'tx_gone.tga',
      ['meshes/uncollided.nif'] = model('tx_gone.tga', true, true),
      ['meshes/marker.nif'] = model(nil, false, true),
      ['meshes/plain.nif'] = model 'tx_plain.bmp',
      ['meshes/actor.nif'] = model(nil, true),
      ['textures/tx_a.dds'] = '',
      ['textures/tx_plain.bmp'] = '',
    }, { 'Mod.esp' })
    local report = order.check(built, { checks = { 'meshes' } }).report
    local fix = '`jess nif check` on the file for the details; `jess nif fix` repairs some'
    expect(report.findings).toEqual {
      {
        severity = 'error',
        check = 'mesh',
        plugins = {},
        records = { 'STAT junk' },
        files = { 'meshes/junk.nif' },
        details = { 'invalidHeader: Invalid NIF header: junk' },
        message = 'meshes/junk.nif: Invalid NIF header: junk',
        fix = fix,
      },
      {
        severity = 'warning',
        check = 'mesh',
        plugins = {},
        records = { 'STAT bare' },
        files = { 'meshes/bare.nif' },
        details = {
          'missingTexture: texture "tx_gone.tga" not found (tried textures/tx_gone.dds, textures/tx_gone.tga)',
        },
        message = 'meshes/bare.nif: texture "tx_gone.tga" not found (tried textures/tx_gone.dds, textures/tx_gone.tga)',
        fix = fix,
      },
      {
        severity = 'warning',
        check = 'mesh',
        plugins = {},
        records = { 'STAT uncollided' },
        files = { 'meshes/uncollided.nif' },
        -- Every finding at the collision level or worse is a detail; the headline is the first
        -- of the worst the doctor grades them: the missing texture, a warning like the collision
        -- OpenMW drops, comes before it.
        details = {
          'visibleEditorMarker: "Tri EditorMarker 0" draws in game because the root has no "MRK" string data',
          'missingTexture: texture "tx_gone.tga" not found (tried textures/tx_gone.dds, textures/tx_gone.tga)',
          'lowercaseNcc: "NCc" turns collision off entirely; only an uppercase "NCC" keeps camera collision',
        },
        message = 'meshes/uncollided.nif: texture "tx_gone.tga" not found (tried textures/tx_gone.dds, textures/tx_gone.tga)',
        fix = fix,
      },
      {
        severity = 'info',
        check = 'mesh',
        plugins = {},
        records = { 'STAT marker' },
        files = { 'meshes/marker.nif' },
        details = {
          'visibleEditorMarker: "Tri EditorMarker 0" draws in game because the root has no "MRK" string data',
        },
        message = 'meshes/marker.nif: "Tri EditorMarker 0" draws in game because the root has no "MRK" string data',
        fix = fix,
      },
    }

    -- A clean model, one whose only finding is a texture that isn't a .dds, and an actor's model
    -- whose only finding is about collision it never has, aren't findings at all.
    expect(report.summary).toEqual { errors = 1, warnings = 2, info = 1, byCheck = { mesh = 4 } }
  end)
end)

suite.describe('conflicts', function()
  local function conflicted(name: string, content: { string }): order.Order
    local base = order.plugin({ gem 'Gem', static('rock', 'a.nif') }, nil, 'master')
    local masters = { { name = 'Base.esm', size = #buffer.tostring(base) } }
    return order.order(name, {
      ['Base.esm'] = base,
      ['A.esp'] = order.plugin({ gem 'Shiny Gem', static('rock', 'b.nif') }, masters),
      ['B.esp'] = order.plugin({ gem 'Dull Gem', static('rock', 'c.nif') }, masters),
      ['Merged Objects.esp'] = order.plugin({}, masters),
      ['My Merge.esp'] = order.plugin({}, masters),
    }, content)
  end

  suite.it('are a warning TES3Merge can settle, and information once it has', function()
    local built = conflicted('conflicts', { 'Base.esm', 'A.esp', 'B.esp' })
    expect(order.check(built, { checks = { 'conflicts' } }).report.findings).toEqual {
      {
        severity = 'warning',
        check = 'conflict',
        plugins = { 'A.esp', 'B.esp' },
        records = { 'MISC gem', 'STAT rock' },
        message = 'B.esp replaces 2 records A.esp changed, dropping its changes (2 of them tes3merge can merge)',
        fix = 'merge them with tes3merge, and load Merged Objects.esp last',
      },
    }

    local merged = conflicted('conflicts-merged', { 'Base.esm', 'A.esp', 'B.esp', 'merged objects.ESP' })
    expect(order.check(merged, { checks = { 'conflicts' } }).report.findings).toEqual {
      {
        severity = 'info',
        check = 'conflict',
        plugins = { 'A.esp', 'B.esp' },
        records = { 'MISC gem', 'STAT rock' },
        message = 'B.esp replaces 2 records A.esp changed, dropping its changes (2 of them tes3merge can merge)',
        fix = 'Merged Objects.esp merges these; run tes3merge again after load order changes',
      },
    }
  end)

  suite.it('know the merged plugin by the name TES3Merge was given in the same state', function()
    local built = conflicted('conflicts-named', { 'Base.esm', 'A.esp', 'B.esp', 'My Merge.esp' })
    local plain = order.check(built, { checks = { 'conflicts' } }).report
    expect(plain.findings[1].severity).toBe 'warning'

    local state: { [string]: unknown } = { tes3merge = { fileName = 'My Merge.esp' } }
    local named = order.check(built, { checks = { 'conflicts' } }, state).report
    expect(#named.findings).toBe(1)
    expect(named.findings[1].severity).toBe 'info'
    expect(named.findings[1].fix).toBe 'My Merge.esp merges these; run tes3merge again after load order changes'
  end)
end)

suite.describe('options', function()
  suite.it('leave out findings milder than the severity asked for, from the report and its counts', function()
    local built = order.harness 'severity'
    local warnings = order.check(built, { minSeverity = 'warning' }).report
    expect(warnings.summary.errors).toBe(6)
    expect(warnings.summary.warnings).toBe(5)
    expect(warnings.summary.info).toBe(0)
    expect(warnings.summary.byCheck.identicalToMaster).toBeNil()
    expect(#warnings.findings).toBe(11)

    local errors = order.check(built, { minSeverity = 'error' }).report
    expect(#errors.findings).toBe(6)
    expect(errors.summary.byCheck).toEqual {
      missingContent = 1,
      unreadablePlugin = 1,
      missingMaster = 2,
      masterOrder = 1,
      mesh = 1,
    }
  end)

  suite.it('print the first errors and warnings, or everything when verbose', function()
    local built = order.harness 'printed'
    local brief = order.check(built, {})
    local path = jess.fs.join(built.config, 'jess-doctor.yaml')
    local head = 'doctor: 6 errors, 5 warnings, 1 info in 11 content files\n'
      .. '  by check: missingContent 1, unreadablePlugin 1, missingMaster 2, masterOrder 1, conflict 1,'
      .. ' missingAsset 2, mesh 1, evilGmsts 1, junkCells 1, identicalToMaster 1\n'
    expect(string.sub(brief.printed, 1, #head)).toBe(head)
    expect(has(brief.printed, '  error missingContent: Missing.esp is in the load order, but no data folder has it\n')).toBe(true)
    expect(
      has(
        brief.printed,
        '    fix: install the mod that provides Missing.esp, or remove content=Missing.esp from openmw.cfg\n'
      )
    ).toBe(true)

    -- Ten at most, and never information: the eleventh finding and the one after are counted.
    expect(has(brief.printed, 'warning evilGmsts')).toBe(true)
    expect(has(brief.printed, 'warning junkCells')).toBe(false)
    expect(has(brief.printed, 'identicalToMaster:')).toBe(false)
    expect(has(brief.printed, `  ... and 2 more in the report\nreport: {path}\n`)).toBe(true)

    local verbose = order.check(built, { verbose = true })
    expect(has(verbose.printed, '  warning junkCells: Dirty.esp has 1 junk cell\n')).toBe(true)
    expect(has(verbose.printed, '  info identicalToMaster: B.esp has 1 record identical to its masters\' copies\n')).toBe(true)
    expect(has(verbose.printed, 'more in the report')).toBe(false)
  end)

  suite.it('refuse a format, a severity, and a call without a configuration', function()
    local built = order.harness 'refusals'
    expect(function() order.check(built, { format = 'toml' :: any }) end).toThrow(
      'doctor: unknown format "toml"; expected yaml or json'
    )
    expect(function() order.check(built, { minSeverity = 'fatal' :: any }) end).toThrow(
      'doctor: unknown minSeverity "fatal"; expected error, warning, or info'
    )
    expect(function() doctor({}) end).toThrow 'doctor: there is no OpenMW config to check'
    expect(jess.fs.exists(jess.fs.join(built.config, 'jess-doctor.yaml'))).toBe(false)
  end)

  suite.it('run every check without options, leaving them and the report in the state', function()
    local built = order.harness 'defaults'
    local run = order.check(built)
    expect(run.report.checks).toEqual { 'masters', 'content', 'assets', 'meshes', 'dirt', 'conflicts' }
    expect(run.report.output).toBe(jess.fs.join(built.config, 'jess-doctor.yaml'))
    expect((run.state.doctor :: doctor.Options).report).toBe(run.report)
  end)
end)

return suite
