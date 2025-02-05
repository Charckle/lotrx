# What
- lotrx is supposed to be a soft clone of the Lords of the realm 2 RTS battles. The soft part implies that the technological limitations will be removed, additional features will be added, the combat between units will be different
- the basic idea is to reacapture the spirit of the game

# Current status
- one open map, one castle map.
- the open map is playable: the AI will attack or defend. If the attacker is loosing, the AI will counterattack. If the AI is the attacker, it will retreat.
- the castle map is...eeh... work in progress
- archers have problems attacking enemies that are behind walls. Yeah, I know.

# To Do
- upgrade pathfinding a second time

- siege lvl 1
	- ram siege weapon (bigger units?)
	- oil siege weapons
	- larger single door
	- drawbridge
	- mote, that units can fill
- siege lvl 2
	- trebuchets
		- only fire where you tell them, they dont attack by themselfs
	- destroyable walls
		- make the tiles have the value of the destruction, so its easier, less objects
- siege lvl 3:
	- siege tower?
- create basic maps:
	- enclosed norman keep
	- enclosed castle
	- linked castle
	- concentric castle
	- poli warded castle
- update maps to new tilesistem for new godot version
- weather
	- check if you can use multimashinstance2d for weather objects
	- set weather for all players the same
	- add fog
	- add wind
- make trees react to the wind, make them an object and movable
	- assign a value to the tiles, and the at the start of the game, just add tree objects
- make an outside resource where you set data for things like unit value, strenght, etc, so its more centralized
- waypoints
- adding additional units to command groups
- scroll zoom
- AI:
	- defending open map
	- attacking open map
            - dont make it go directly twords the enemy, but make him do hops trough the map, so that the units dont get too dispersed: horses reach the target first, pikeman last
	- defending castle
	- attacking castle
- siedge weapons
- damage difference depending on the angle of attack (if you get hit in the back, auch)
	- arrows deal more damage the closer they are shot at a target
	- castle walls give extra range
- a campaign
- LAN multiplayer - working
    - but its a non sync, poor mans multiplayer. prolly good only on lan

# Goal
- multiple campaign, trough which you could explore parts of history and real castles.
- multiple castle maps, based on real life castles
- skirmishes, where you can choose to fight an AI in a specific scenario
- AI tiers
- LAN multiplayer
	- LAM multiplayer COOP

The main goal is basically LAN multiplayer, but since I think it will be the hardest part, the idea is to make a playable product beforehand.
