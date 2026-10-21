# doctor benchmarks

`bench/bench.jsl` times the doctor the way it is reached: `@doctor` called with an `@openmw-install`
Context over load orders the bench builds with `@esm`, the argument lists `@doctor/cli` reads,
and the command line, warm and from a cold start. There are four load orders:

- **A load order** with one of everything the doctor looks for: a master of 2,300 records and
  four plugins that define every fourth, sixth, tenth, and fifteenth of them again, changed (one
  a patch naming two of the others as masters, one with copies of the master's records left in
  it, one with the master's size recorded wrong), a plugin of dirt, a plugin before its master,
  one whose master isn't in the load order, one whose master isn't installed, one that isn't a
  plugin, one that isn't there, and a script list. Its data folder holds two in five of the 150
  models and 80 icons the master names, and none of those 60 models loads. 87 findings.
- **Thirty plugins** over a master a quarter that size, none naming another as a master, each
  defining a seventh of the master's records again and 40 of its own that name files nothing
  provides: 246 pairs where one plugin drops another's changes. 300 findings.
- **A master missing its 4,000 models**: 4,000 statics that each name a model of their own, none
  installed. One finding, of 4,000 records and 4,000 files: a load order without the asset pack
  a mod needs.
- **Three hundred plugins** of three records each over a master of 285 records, each naming the
  master and the plugin before it, every tenth with the master's size recorded wrong: a long load
  order. 632 findings checked whole, 30 by its headers.

A warm workload is warmed up, sized to a batch of about a tenth of a second, and reported as the
median of seven batches with a full collection between them. A `cold:` workload is a fresh
process a sample: seven running `bench/cold.jsl`, the command line run once and timed inside the
script from its first `require`; or fifteen running `bench/load.jsl`, which times the doctor's
own two modules loading once the packages they depend on are there. Every check's report is
weighed before the first batch and after the last, its counts and a digest of the file it wrote
with the scratch folder's path taken out, against what the bench has pinned, so a path that
stops doing the work stops the run instead of posting a time.

```sh
jess run --capability filesystem.read --capability filesystem.write \
  --capability process.spawn --package jpk/doctor --package-path jpk \
  jpk/doctor/bench/bench.jsl <scratch> [filter] [jess binary] [package path]
```

Without the binary (and `process.spawn`) the cold workloads are skipped. The doctor reports
through `print`, so each check prints its own lines among the bench's: the bench's are the ones
that hold a tab. The scratch folder's path must be absolute and hold only letters, digits, `/`,
`.`, `_`, and `-`: the digests are of reports that write it without quotes.

## The move onto l3i 2.0, base against head

- Machine: Intel Core i7-10870H @ 2.20 GHz, 16 threads, shared with other work while this ran
  (load average 1.0 to 1.6 over the runs).
- Date: 2026-10-12.
- Binary: the verified release build of Jess 0.1.0 on l3i 2.0.2 (Luau 0.742), the same one for
  both sides, as are the packages this one depends on.
- Base: `8f663e9`, the package before the move, with the bench (the bench files as they are
  now, copied over the export: the three-hundred-plugin order and the load workload were added
  later, and run against the old code as they are). Head: `bd26383`; what follows it is this
  page, a line of the bench's own comment, and three cases of the suite.
- Protocol: the whole bench against an export of base and against head, six times each in two
  sets of three, alternating and swapping which goes first (base head, head base, base head;
  then head base, base head, head base), each set back to back under one lock; each cell is the
  median of its six runs. A difference under 5 percent is called no change.

| Workload | Base | Head | Base / head |
|---|---:|---:|---:|
| check a load order, every check | 35.30 ms | 31.91 ms | 1.11x |
| check a load order, every check, as json | 38.71 ms | 32.95 ms | 1.17x |
| check a load order, masters and content | 2.73 ms | 2.66 ms | no change |
| check a load order, assets | 22.93 ms | 21.03 ms | 1.09x |
| check a load order, meshes | 22.24 ms | 21.23 ms | no change ¹ |
| check a load order, dirt | 10.55 ms | 10.34 ms | no change |
| check a load order, conflicts | 7.17 ms | 6.97 ms | no change |
| check a load order, errors only | 30.64 ms | 28.98 ms | 1.06x |
| check thirty plugins, every check | 39.33 ms | 34.27 ms | 1.15x |
| check thirty plugins, conflicts | 14.04 ms | 11.56 ms | 1.21x |
| check thirty plugins, conflicts, as json | 17.09 ms | 12.72 ms | 1.34x |
| check a master missing its 4,000 models, assets | 59.64 ms | 31.79 ms | 1.88x |
| check a master missing its 4,000 models, assets, as json | 64.25 ms | 31.66 ms | 2.03x |
| check three hundred plugins, masters and content | 18.91 ms | 7.42 ms | 2.55x |
| check three hundred plugins, every check | 40.03 ms | 25.28 ms | 1.58x |
| parse 8 argument lists | 8.00 µs | 8.06 µs | no change |
| the command, a load order | 34.64 ms | 31.50 ms | 1.10x |
| cold: load the doctor's own modules | 9.08 ms | 9.70 ms | 0.94x ² |
| cold: --help | 374.66 ms | 260.62 ms | 1.44x |
| cold: the command, masters and content | 388.11 ms | 274.32 ms | 1.41x |
| cold: the command, a load order | 424.56 ms | 422.26 ms | no change ³ |
| cold: the command, a master missing its 4,000 models | 453.49 ms | 421.79 ms | 1.08x |

¹ 1.05x in the first set and 1.047x over both: at the threshold, and not over it.

² Slower, by 0.6 ms a process: see "What loading costs" below.

³ The check itself is 3.4 ms faster warm, which is under one percent of a cold run and inside
what seven processes can tell apart.

## What moved, and why

Nothing in this package is a loop over a buffer, and no list it sorts is long, so nothing here
went to the data plane. The doctor asks other packages for a load order's plugins, their dirt,
their overrides, and the files they name, and what it does itself is place masters, group what
comes back, and write the report. Three of those were doing more than their share. Each commit's
share below is from one run of the warm checks against an export of every commit of the move,
first to last under one lock, so each figure is good to about 3 percent; the phases named were
timed with a clock in a scratch copy of the module.

- **The files a plugin names** (`b487fde`; a master missing its models 1.82x, as JSON 1.69x).
  Each file a group of asset findings names is listed once, and whether it was already listed
  was asked of the list, a search of it for every finding, which is the square of the files: 30
  ms of the 64 on 4,000 of them. It is asked of a set.
- **Placing masters** (`533d7be`; three hundred plugins by their headers 2.36x, checked whole
  1.47x). `@openmw-content`'s `masters` is given the load order's names and lowers every one of them
  for each plugin it is asked about: 14 ms of the 19 on three hundred plugins. The doctor already
  holds where each name is, built the same way (by name without case, a name listed twice where
  it is listed last), and reads the plugin's masters against that.
- **A master's size** (`3cad83f`; three hundred plugins by their headers 1.12x). It was read
  from disk for every plugin that names the master. It is read once.
- **How a string is written** (`892607b`, `90aac34`; thirty plugins' conflicts 1.18x and as
  JSON 1.32x over the two, a load order as JSON 1.11x, a master missing its models as JSON
  1.09x). Whether a string can go into YAML bare was worked out for every string of a JSON
  report too, and thrown away; the seven words YAML reads as something else were a table made
  again for each string; and the two questions (is it bare, does it need escaping) were three
  Lua patterns, one of them unanchored. A JSON report no longer asks the first; the words are a
  set; and the patterns are three of `@dream/bytes`, compiled once. Timed apart under the lock
  over 8,000 strings of the kind a report lists (`STAT bench_static_123`, 16 to 22 bytes), one
  of those is about 105 ns a string against about 500 for the two finds it replaces together,
  and about 105 against about 440 for the `gsub` that finds nothing to escape. A string that
  holds a quote or a backslash and no control character is escaped by `gsub` with a replacement
  string, where every escape was a call. The old and new spellings were compared over every
  string of one and two bytes and 3.2 million of three and four before the change, and
  `tests/run.jsl` pins 33 names as YAML and JSON write them.
- **A cold start** (`bd26383`; `--help` 1.44x, the command with `--checks masters,content`
  1.41x, both from the table above). `@plugin-assets`, with the model reader behind it, takes a
  process that has what every run of the doctor loads (`@esm`, `@openmw-content`, `@openmw-install`) 80 ms
  to load, and `@tes3cmd` 34, each the median of seven processes under the lock; a process that
  has `@esm` alone pays 205 ms for `@plugin-assets`, most of it packages `@openmw-install` loads too.
  Only the asset and model checks use the first and only the dirt and conflict checks the
  second. Each is required where its checks start. A run of every check loads what it always
  did.

Two commits changed how the code reads and not what it costs: an asset finding's group is found
by plugin and then by code (`e7823e6`), and a failure, a group, a conflict, and a finding are
taken apart by record pattern (`a78615c`).

## What loading costs

The doctor is a command: every run is a fresh process, and what its module costs to compile is
paid every time. The dialect is not free there. `7cbd23e` wrote nine loops of the module as
comprehensions (the plugins compared, the findings kept, the checks run, a document's nodes, a
JSON list's and map's members, the counts printed). Against the commit that put the loops back
(`e42fba8`), four rounds each, alternating, under one lock:

| Workload | Comprehensions (`3cad83f`) | Loops (`e42fba8`) | |
|---|---:|---:|---:|
| the fifteen warm checks | | | 0.98x to 1.03x, no change |
| cold: load the doctor's own modules | 10.82 ms | 9.79 ms | 1.11x |

A millisecond a run for nothing a run could measure, so the loops are back. The nine lists are
each a few to a few hundred elements long, built once a check.

Five record patterns stayed. The module with them and without them, four rounds: 9.79 ms against
9.64, which is 0.15 ms and under what this page calls a difference. The rest of row ² is the
three patterns of `@dream/bytes` compiling (0.16 ms in a fresh process, and 0.04 more the first
time each is asked) and the module being 56 lines longer. By the per-string times above, and not
by any measurement of it, a report of about 500 strings pays the patterns back. No run in the
table is slower for the 0.6 ms: a run of some checks loads less than it did, and a run of all of
them saves more in the check.

## What is left

A whole check of the first load order is about 32 ms, timed by phase in one run: `@plugin-assets`'
check 15.8, `@tes3cmd`'s lint 3.9 and its overrides 3.2, writing the file 2.2, opening the
plugins 1.0 and opening them again for the asset check 1.2, and of the doctor's own, spelling
the report 3.1 (4.2 as JSON) and grouping asset findings 0.7. Over three hundred plugins the two
opens are 6.3 ms of 25 and the report 4.7.

The second open is the one thing here that looks like the doctor's to shorten and wasn't. The
asset check opens every plugin with the record types that name files, and the checks after it
open them again whole (or by the types compared, or by their headers). One open can't stand for
the other: `@esm` doesn't frame a record a filtered open skips, so a plugin with a malformed
record of a type the asset check never reads (a global whose subrecord runs past it, tried
here) is reported today both as unreadable and for the model it names that nothing provides,
and under one open would be reported only as unreadable. Reading each file once needs
`@openmw-content` to open one read of it under two filters.

A findings list is sorted with a comparator: 0.2 ms for 300 findings and 0.5 for 632, under two
percent of either check, and its last key is the message, which `argsort` has no order for.

A cold run of every check is 420 ms, of which the check is about 30: `@esm` takes a fresh
process 105 ms to load and `@openmw-install` with the packages under it 145 more (seven processes each,
under the lock), neither this package's to shorten, and `--help` still pays both, 260 ms, to
print a page of text. `@doctor/cli` needs `@doctor` for the types of its options, and Luau has no
way to ask for a module's types without loading it.

## Which modules are native, and why

Jess compiles to machine code only what is marked (`--!native` on a module, `@native` on one
function), and every load pays for what is marked. A module carries `--!native` when a row below
spends its time there and the module is small (12 KB or less); a larger module carries `@native`
on the functions the row spends its time in, and nothing else.

Measured 2026-10-15 with `jess 0.1.0`, the verified release build of jess `07c38cb` on l3i
2.0.3, on the i7-10870H, the one-minute load 1.41 and 1.42 at the start of the two
sessions. In each session the bench ran alternately on this package and on a copy of it with
every module marked, three fresh runs of `bench/bench.jsl` each, every run's row the median of
its batches; a column is the median of the three, and a ratio is against the all-marked runs of
the same session. Which functions a row spends its time in comes from `jess run --profile` of
that row alone, unmarked. The load cost is a fresh `jess run --package <this package>
--package-path jpk` of a script that only requires `@doctor`, the two sides alternating, the
median of five each after one warm-up.

| Requiring `@doctor` | All marked | This state |
| --- | ---: | ---: |
| Unmarked | 0.139 s | 0.132 s |
| Final | 0.142 s | 0.135 s |

| Row | All marked (ms) | Unmarked / all marked | Final (ms) | Final / all marked |
| --- | ---: | ---: | ---: | ---: |
| check a load order, every check | 42.09 | 1.025× | 41.47 | 0.985× |
| check a load order, every check, as json | 43.31 | 1.016× | 42.46 | 0.980× |
| check a load order, masters and content | 2.941 | 1.027× | 2.638 | 0.897× |
| check a load order, assets | 28.32 | **1.068×** | 27.29 | 0.964× |
| check a load order, meshes | 28.71 | 0.999× | 28.84 | 1.005× |
| check a load order, dirt | 12.23 | 1.021× | 12.58 | 1.028× |
| check a load order, conflicts | 7.815 | 1.047× | 8.170 | 1.045× |
| check a load order, errors only | 37.32 | 1.010× | 40.66 | **1.090×** |
| check thirty plugins, every check | 44.11 | 1.044× | 45.54 | 1.033× |
| check thirty plugins, conflicts | 13.47 | **1.097×** | 13.99 | 1.039× |
| check thirty plugins, conflicts, as json | 14.87 | **1.087×** | 15.59 | 1.048× |
| check a master missing its 4,000 models, assets | 40.48 | **1.080×** | 39.69 | 0.981× |
| check a master missing its 4,000 models, assets, as json | 40.75 | 1.017× | 39.43 | 0.968× |
| check three hundred plugins, masters and content | 8.572 | 1.006× | 8.818 | 1.029× |
| check three hundred plugins, every check | 31.09 | **1.073×** | 31.95 | 1.028× |
| parse 8 argument lists | 0.00981 | **1.250×** | 0.01286 | **1.310×** |
| the command, a load order | 39.44 | 1.030× | 41.91 | **1.063×** |

What carries the directive (every function here is one a row spends its time in, unmarked):

- `init`, by function: `isScripts`, a closure at line 744, `strings`, `jsonString`, `scalarText`,
  `yamlLines`.
- Unmarked: `cli`, `main`.

`cli` and `main` parse a command line once a run and are never marked, so `parse 8 argument
lists` (1.31x, of a 10 µs call) is slower than all marked by rule. The two other rows above 5%
are checking a load order for errors (1.09x) and the command over a load order (1.06x), 40 ms
calls whose remaining time is spread over the rest of `init`. Marking `init` whole would give back
the load this saves (requiring `@doctor` costs what the package unmarked costs, within a
millisecond) for a few milliseconds of a check; a doctor run over a real load order is twelve
seconds, nearly all of it in `@nif`.
