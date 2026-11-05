# Industrial Equipment Failure and Maintenance System

A C++ console application that helps a small factory decide **which machine to repair first**
when there are only a few technicians and a limited stock of spare parts.

It also includes a simulator that runs a model plant for a month and compares four
maintenance strategies, so the decisions can be tested instead of just assumed.

PBL project, B.Tech CSE 2nd year, Graphic Era.

---

## The problem

Machines in a plant depend on each other. If the coolant pump stops, every CNC machine it
feeds stops too, even though they are fine. A list sorted only by machine condition misses
this: a worn-out exhaust fan ends up above a slightly worn pump that keeps half the shop running.

Most small manufacturers still track maintenance on paper or in Excel and mostly fix machines
after they break. This project models the plant as a dependency graph and uses it to rank
repairs by how much production is actually at risk.

## Features

| # | Feature | What it is for |
|---|---------|----------------|
| 1 | Equipment table | Health, status, own loss per hour and total loss per hour if it stops |
| 2 | Priority list | Repairs ranked by money at risk, next to the rank by health alone |
| 3 | Failure impact | Everything that stops if one machine stops |
| 4 | Root cause finder | Given several alarms, which machines to check first |
| 5 | Start-up / shutdown order | Safe order to switch the plant on or off |
| 6 | Search by id | Full details of one machine |
| 7 | Update health | With undo |
| 8 | Vibration readings | Flags a reading that jumps well above the recent average |
| 9 | Record maintenance | Failure / repair / preventive / note, uses spare parts, with undo |
| 10 | History and MTBF | Full log of a machine and mean time between failures |
| 11 | Spare parts | Stock, lead time, which machines use each part |
| 12 | Strategy simulation | Month-long comparison of four strategies over 30 random seeds |
| 13 | Undo | Reverts the last change |

## Data structures and algorithms used

| Concept | Where | File |
|---------|-------|------|
| Graph (adjacency list) | Machine dependencies | `PlantGraph.h/.cpp` |
| DFS (iterative) | Failure impact, upstream search | `PlantGraph.cpp` |
| BFS (multi-source) | Which machines are starved by stopped ones | `PlantGraph.cpp` |
| Topological sort (Kahn) | Start-up / shutdown order, cycle check when loading | `PlantGraph.cpp` |
| Binary max-heap (own implementation) | Job queue, part orders (min order via reversed compare) | `MaxHeap.h` |
| Hash map | Machine id lookup, spare parts inventory | `Plant.h` |
| Singly linked list (own implementation) | Maintenance history per machine, deep copy | `MaintenanceLog.h` |
| Stack (linked, own implementation) | Undo | `UndoStack.h` |
| Queue / deque (sliding window) | Vibration moving average | `SensorWindow.h` |
| Greedy | Assigning jobs to technicians | `Simulator.cpp` |
| Sorting | Display tables | `Menu.cpp` |

### How priority is calculated

```
critical loss  = own loss per hour + loss per hour of every machine downstream
urgency        = 1 if failed, else ((100 - health) / 100)^2
score          = critical loss x urgency
```

Urgency is squared so a machine at health 30 counts much more than one at 60.
If the vibration sensor raised an alert, health is treated as at most 45.

## Build and run

Needs a C++17 compiler (g++ 7 or newer).

**Linux / macOS / Windows with MinGW + make**

```bash
make            # builds ./iefms
make run        # interactive menu
make simulate   # strategy comparison only
make test       # data structure tests
```

**Windows without make**

```bash
g++ -std=c++17 -O2 -Iinclude -o iefms src/*.cpp
iefms
```

**Command line options**

```
--data DIR    folder with the CSV files (default: data)
--simulate    only run the strategy comparison
--runs N      runs per strategy (default 30)
--hours N     hours per run (default 720)
--seed N      first random seed (default 42)
--wear X      wear speed multiplier (default 1.0)
```

## Project structure

```
include/        headers (data structures are header-only)
src/            graph, plant loading, scheduler, simulator, menu, main
data/           sample plant as CSV files
tests/          assert based tests
Makefile
```

## Data files

All in `data/`. Lines starting with `#` are ignored.

- `equipment.csv` - id, name, type, zone, health, wear_rate, downtime_cost, skill, part_id, repair_hours, status
- `dependencies.csv` - `from,to` means *to* cannot run while *from* is stopped
- `technicians.csv` - id, name, skill (MECH / ELEC), shift (1: 06-14, 2: 14-22, 3: 22-06, 0: any)
- `parts.csv` - part_id, name, stock, lead_time_hours
- `history.csv` - equipment_id, hour, kind, note

The sample plant is a made-up small auto-component unit with 18 machines.
**All costs, wear rates and lead times are assumptions for testing, not measured data.**

## How the simulation works

Each run is 720 hours (a month of 24x7 work). Every hour:

1. Spare parts that have arrived are added to stock.
2. Finished repairs bring machines back to health 100.
3. Running machines lose health. A small chance of a hidden fault makes one wear 4x faster
   and raises its vibration. Breakdown chance rises sharply below health 50.
4. Machines below health 55 (or with a sensor alert) get a maintenance request,
   except under the reactive strategy, which only repairs breakdowns.
5. Open jobs go into a heap ordered by the strategy. Free technicians on shift take jobs
   matching their skill. A job needs one spare part; if none is left, it waits and a reorder is placed.
   Breakdown repairs take twice as long as planned ones.
6. Every machine that is stopped, under repair or starved by an upstream stop adds its loss for the hour.

All four strategies run on the same 30 seeds.

## Results

Averages per simulated month, 30 runs each. Loss is in Rs lakh, with standard deviation.

**Default plant (`./iefms --simulate`)**

| Strategy | Loss (Rs L) | sd | Machine-hours down | Breakdowns |
|----------|------------:|---:|-------------------:|-----------:|
| Reactive | 16.26 | 5.44 | 488 | 16.3 |
| First come first served | 10.13 | 2.75 | 301 | 2.1 |
| Worst health first | 9.94 | 2.49 | 296 | 2.1 |
| Criticality aware | 10.07 | 2.57 | 299 | 2.3 |

**Faster wear (`--wear 2`, `--wear 3`, `--wear 4`), loss in Rs lakh**

| Strategy | x2 | x3 | x4 |
|----------|---:|---:|---:|
| Reactive | 24.82 | 37.16 | 49.97 |
| First come first served | 15.70 | 21.11 | 26.62 |
| Worst health first | 16.19 | 20.70 | 26.64 |
| Criticality aware | 15.78 | 21.18 | 26.61 |

### What the results show

- Doing preventive maintenance at all cuts loss by about 38% compared with fixing machines
  only after they fail, and the gap grows as wear increases.
- **The order of preventive jobs made no measurable difference.** The three preventive
  strategies are within one standard deviation of each other at every wear level.
- The reason is visible in the full output: technicians are busy only about 5-13% of the time,
  while jobs spend many hours waiting for spare parts. In this model the bottleneck is spare
  parts, not people. Requests open at health 55, which leaves enough time for any order to
  finish before machines fail.

So the original idea (rank by criticality) is not what helps here. The graph features
(failure impact, root cause, start-up order) are still useful on their own, but the
scheduling result means the next thing to work on is the spare parts policy.

## Limitations

- All dependencies are treated as "needs all of these". Parallel machines (if one of two
  conveyors stops, the other still runs) are not modelled.
- Health is known exactly in the simulation. Real plants only see sensor readings.
- Wear rates, costs and failure curves are assumptions, not fitted to real data.
- Greedy assignment is not guaranteed to be optimal.
- A planned repair stops the machine immediately; real plants schedule it for a break or weekend.

## Possible next steps

- Reorder policy for spare parts (reorder point, safety stock), since that is the bottleneck found above.
- Test different request thresholds instead of the fixed 55.
- Group repairs on the same line into one shutdown.
- Support "any one of" dependencies for parallel machines.
- Fit wear and failure behaviour to a public dataset.
- Talk to maintenance staff at a local unit and check the assumptions.

## References

- Siemens / Senseye, *The True Cost of Downtime 2024*.
- MaintainX survey of 211 maintenance leaders on skilled labour shortages (2026).
- Forvis Mazars, report on digital transformation of MSMEs in India.



