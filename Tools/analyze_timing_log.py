#!/usr/bin/env python3
"""Summarizes Temper's debug timing logs against the accuracy targets.

Share a log from Settings > Logs on a DEBUG build, then:

    python3 Tools/analyze_timing_log.py run-*.jsonl

Logs hold the iOS version and audio port types, never port names. Keep them out of the repo.
"""
import json
import statistics
import sys

PHASE_TARGET_MS = 100
CUE_TARGET_MS = 250


def stats(values):
    if not values:
        return "none"
    worst = max(values, key=abs)
    return f"n={len(values)} mean={statistics.mean(values):.1f} worst={worst:.1f} ms"


def clock_checks(clock_events):
    """Returns the audio clock's change across each lead-to-boundary pair, and any device sleep.

    mach_absolute_time stops while the device sleeps and ContinuousClock does not, so a fall in
    host minus wall is time the device spent asleep.
    """
    pair_ms = []
    for lead, boundary in zip(clock_events, clock_events[1:]):
        if lead["context"] == "lead" and boundary["context"] == "boundary":
            offset = [
                e["render_sample"] / e["render_rate"] + e["host_s"] - e["render_host_s"] - e["wall"]
                for e in (lead, boundary)
            ]
            pair_ms.append((offset[1] - offset[0]) * 1000)
    offsets = [e["host_s"] - e["wall"] for e in clock_events]
    asleep = offsets[0] - min(offsets) if offsets else 0
    return pair_ms, asleep


def report(path):
    with open(path) as log:
        events = [json.loads(line) for line in log if line.strip()]
    print(f"\n=== {path}")
    if not events:
        print("Empty log: the Workout never reached audio.")
        return
    start = next((e for e in events if e["e"] == "run_start"), {})
    dip = next((e["dip"] for e in events if e["e"] == "dip"), None)
    print(f"dip: {dip} | {start.get('os')} | Cue render {start.get('cue_render_s', 0):.1f} s")

    late = [e["late_ms"] for e in events if e["e"] == "phase_end"]
    for e in events:
        if e["e"] == "phase_end" and e["late_ms"] > PHASE_TARGET_MS:
            print(f"MISSED: Phase end at {e['wall']:.1f} s was {e['late_ms'] / 1000:.1f} s late")
    print(f"Phase end late:   {stats(late)} | over {PHASE_TARGET_MS} ms: {sum(abs(v) > PHASE_TARGET_MS for v in late)}")

    onsets = [e["error_ms"] for e in events if e["e"] == "onset" and "error_ms" in e]
    print(f"Cue onset error:  {stats(onsets)} | over {CUE_TARGET_MS} ms: {sum(abs(v) > CUE_TARGET_MS for v in onsets)} "
          "(leaves the player, not heard)")
    print(f"Cues: scheduled {sum(e['e'] == 'schedule' for e in events)}, onsets {len(onsets)}, "
          f"phase ends {len(late)}, skipped {sum(e['e'] == 'cue_skipped' for e in events)}")

    cycles = [e["ms"] for e in events if e["e"] == "dip_cycle"]
    if cycles:
        print(f"Dip cycle:        {stats(cycles)}")

    pair_ms, asleep = clock_checks([e for e in events if e["e"] == "clock"])
    print(f"Audio clock across a Cue's lead: {stats(pair_ms)}")
    if asleep > 1:
        print(f"DEVICE SLEPT for {asleep:.0f} s during this run")

    for kind in ("session_inactive", "session_active", "resume_recommendation", "route_change",
                 "engine_config_change", "media_services_reset", "cue_cancelled"):
        count = sum(e["e"] == kind for e in events)
        if count:
            print(f"{kind}: {count}")
    routes = {tuple(e["outputs"]) for e in events if e["e"] == "route"}
    print(f"Routes: {sorted(routes)}")

    end = next((e for e in events if e["e"] == "run_end"), None)
    if end is None:
        print(f"NO run_end: the process died or was still running. "
              f"Last event at {events[-1]['wall']:.1f} s: {events[-1]['e']}")
    else:
        print(f"run_end: completed={end['completed']} at {end['wall']:.1f} s")


for name in sys.argv[1:]:
    report(name)
