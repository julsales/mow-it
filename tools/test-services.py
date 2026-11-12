#!/usr/bin/env python3
"""Run actual service modules with explicit engine boundaries mocked in Luau CLI."""
from pathlib import Path
import re
import subprocess
import argparse
import tempfile

ROOT = Path(__file__).resolve().parents[1]
parser = argparse.ArgumentParser()
parser.add_argument('--luau', default='luau')
args = parser.parse_args()
base = ROOT / 'src/ReplicatedStorage/Shared'
parts = ['''local M = {}
local Color3 = { fromRGB = function(...) return {...} end }
local Random = { new = function(seed)
    local state = seed % 2147483647
    return { NextNumber = function(self)
        state = state * 16807 % 2147483647
        return state / 2147483647
    end }
end }
''']
for name in ['Config/GameConfig', 'Config/Progression', 'Config/Franchise', 'Config/Crew', 'Config/Zones',
             'Config/Backpacks', 'Config/Weather', 'Config/Contracts', 'Config/Quests', 'GrassBag', 'ProgressionRules']:
    source = (base / (name + '.luau')).read_text()
    source = re.sub(r'local Config = script.Parent(?::WaitForChild\("Config"\)|\.Config)', 'local Config = {}', source)
    source = re.sub(r'require\(Config\.(\w+)\)', r'M.\1', source)
    parts.append(f'M.{Path(name).name} = (function()\n{source}\nend)()')
pure_parts = parts.copy()
parts.append((ROOT / 'tests/service-harness.luau').read_text())
services = ROOT / 'src/ServerScriptService/Services'
source = (services / 'QuestService.luau').read_text()
for key, value in {'Shared.Config.Quests': 'M.Quests', 'Shared.QuestWorld': 'QuestWorld',
                   'script.Parent.ProfileService': 'Profiles', 'script.Parent.LandService': 'Land'}.items():
    source = source.replace(f'require({key})', value)
parts.append('local Quests = (function()\n' + source + '\nend)()')
source = (services / 'ContractService.luau').read_text()
for key, value in {'Shared.Config.Contracts': 'M.Contracts', 'Shared.Config.Zones': 'M.Zones',
                   'Shared.ProgressionRules': 'M.ProgressionRules', 'script.Parent.ProfileService': 'Profiles',
                   'script.Parent.LevelService': 'Levels', 'script.Parent.LandService': 'Land', 'script.Parent.QuestService': 'Quests'}.items():
    source = source.replace(f'require({key})', value)
parts.append('local Contracts = (function()\n' + source + '\nend)()')
source = (services / 'ProgressionService.luau').read_text()
for key, value in {'Shared.Config.Progression': 'M.Progression', 'Shared.Config.Zones': 'M.Zones',
                   'Shared.Config.Crew': 'M.Crew', 'Shared.ProgressionRules': 'M.ProgressionRules',
                   'Shared.GrassBag': 'M.GrassBag', 'Shared.PlantingPlots': '{}', 'script.Parent.ProfileService': 'Profiles',
                   'script.Parent.LandService': 'Land', 'script.Parent.ContractService': 'Contracts',
                   'script.Parent.QuestService': 'Quests', 'script.Parent.PlotService': '{ Plant = function() return "stub" end }'}.items():
    source = source.replace(f'require({key})', value)
parts.append('local Progression = (function()\n' + source + '\nend)()')
parts.append((ROOT / 'tests/services.spec.luau').read_text())
persistence = (services / 'ProfileService.luau').read_text()
for key, value in {'Shared.Config.GameConfig': 'M.GameConfig', 'Shared.Config.Progression': 'M.Progression',
                   'Shared.ProgressionRules': 'M.ProgressionRules'}.items():
    persistence = persistence.replace(f'require({key})', value)
persistence_parts = pure_parts + [(ROOT / 'tests/persistence-harness.luau').read_text(),
    'local function createService()\n' + persistence + '\nend',
    (ROOT / 'tests/persistence.spec.luau').read_text()]
with tempfile.TemporaryDirectory(prefix='mowit-services-') as tmp:
    path = Path(tmp) / 'run.luau'
    path.write_text('\n'.join(parts))
    subprocess.run([args.luau, str(path)], check=True)
    path.write_text("\n".join(persistence_parts))
    subprocess.run([args.luau, str(path)], check=True)
