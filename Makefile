# Mow It! - local Rojo workflow.
#
# Local dev uses the Rojo binary pinned at .tools/bin/rojo (7.6.1), installed by
# hand (see README > Quick start). Override it if you keep Rojo elsewhere:
#   make serve ROJO=rojo
ROJO ?= .tools/bin/rojo

# The Rojo Studio plugin connects to this address and port.
ADDRESS ?= 127.0.0.1
PORT ?= 34872

GAME_PROJECT := default.project.json
LOBBY_PROJECT := lobby.project.json

.PHONY: build serve serve-lobby clean

## build: build both place files into build/
build:
	mkdir -p build
	$(ROJO) build $(GAME_PROJECT) -o build/MowIt-Game.rbxlx
	$(ROJO) build $(LOBBY_PROJECT) -o build/MowIt-Lobby.rbxlx

## serve: serve the Game place (default.project.json) for the Studio plugin
serve:
	$(ROJO) serve $(GAME_PROJECT) --address $(ADDRESS) --port $(PORT)

## serve-lobby: serve the Lobby place (lobby.project.json) for the Studio plugin
serve-lobby:
	$(ROJO) serve $(LOBBY_PROJECT) --address $(ADDRESS) --port $(PORT)

## clean: delete the built place files
clean:
	rm -f build/MowIt-Game.rbxlx build/MowIt-Lobby.rbxlx
