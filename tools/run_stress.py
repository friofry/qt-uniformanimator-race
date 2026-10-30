#!/usr/bin/env python3
"""Runs the rig several times and reports how each run ended.

usage: run_stress.py <path-to-binary> [--mode uniform] [--runs 5] [--seconds 30] [--software]
"""
import argparse
import os
import subprocess
import time

parser = argparse.ArgumentParser()
parser.add_argument("binary")
parser.add_argument("--mode", default="uniform")
parser.add_argument("--runs", type=int, default=5)
parser.add_argument("--seconds", type=int, default=30)
parser.add_argument("--software", action="store_true",
                    help="render on the CPU, which makes the race easy to hit")
args = parser.parse_args()

env = dict(os.environ)
if args.software:
    env["QSG_RHI_BACKEND"] = "opengl"
    env["QT_OPENGL"] = "software"       # Windows: opengl32sw.dll
    env["LIBGL_ALWAYS_SOFTWARE"] = "1"  # Linux: llvmpipe

binary = os.path.abspath(args.binary)
crashes = 0
for run in range(1, args.runs + 1):
    start = time.time()
    code = subprocess.run([binary, "--mode", args.mode, "--seconds", str(args.seconds)],
                          env=env, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL).returncode
    crashed = code != 0
    crashes += crashed
    print(f"run {run}: exit {code & 0xffffffff:#x} after {time.time() - start:.1f}s"
          f"{' CRASH' if crashed else ''}", flush=True)
print(f"mode={args.mode}: {crashes}/{args.runs} crashed")
