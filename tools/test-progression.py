#!/usr/bin/env python3
"""Bundle real pure modules for Luau CLI; no Roblox credentials/network needed."""
from pathlib import Path
import argparse
import re
import subprocess
import tempfile

ROOT = Path(__file__).resolve().parents[1]
parser = argparse.ArgumentParser()
parser.add_argument('--luau', default='luau')
parser.add_argument('--compiler', default='luau-compile')
args = parser.parse_args()

sources = sorted((ROOT / 'src').rglob('*.luau'))
for source in sources:
    result = subprocess.run([args.compiler, '--binary', str(source)], capture_output=True)
    if result.returncode:
        raise SystemExit(result.stderr.decode())
print(f'Compiled {len(sources)} source files', flush=True)

# Only engine value constructors/RNG are stubbed. Economy/progression logic and
# all catalog data are the production source, not reimplemented by the test.
header = '''local M = {}
local Color3 = { fromRGB = function(...) return {...} end }
local Random = { new = function(seed)
    local state = seed % 2147483647
    return { NextNumber = function(self)
        state = state * 16807 % 2147483647
        return state / 2147483647
    end }
end }
'''
base = ROOT / 'src/ReplicatedStorage/Shared'
names = ['Config/GameConfig', 'Config/Progression', 'Config/Franchise', 'Config/Crew',
         'Config/Zones', 'Config/Backpacks', 'Config/Weather', 'GrassBag', 'ProgressionRules']
parts = [header]
for name in names:
    code = (base / (name + '.luau')).read_text()
    code = re.sub(r'local Config = script.Parent(?::WaitForChild\("Config"\)|\.Config)', 'local Config = {}', code)
    code = re.sub(r'require\(Config\.(\w+)\)', r'M.\1', code)
    parts.append(f'M.{Path(name).name} = (function()\n{code}\nend)()\n')
parts.append('local test = (function()\n' + (ROOT / 'tests/progression.spec.luau').read_text() + '\nend)()\ntest(M)\n')
with tempfile.TemporaryDirectory(prefix='mowit-test-') as tmp:
    runner = Path(tmp) / 'run.luau'
    runner.write_text('\n'.join(parts))
    subprocess.run([args.luau, str(runner)], check=True)
