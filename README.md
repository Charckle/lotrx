# What
- lotrx is supposed to be a soft clone of the Lords of the realm 2 RTS battles. The soft part implies that the technological limitations will be removed, additional features will be added, the combat between units will be different
- the basic idea is to reacapture the spirit of the game

# Current status
- two playable maps, one castle, one open. More are almost done
- the open map is plaaable against the AI, the castle no
- working moats, rams, doors, siege towers, oil
- working multiplayer

# Roadmap 2025
- better AI
- fix pathfinding
- implement castle destruction
- implement better UI for map selection
- implement scenarios
- implement wooden castles


# To Do
- caldron should not destroy its own doors
- AI
    - make an order of what units get comands, so that some units get a headstart to their positions?
	- dont execute the orders immediatelly, but put them in a queue, and every X miliseconds, execute some of them
	- make the units not try to attack the ram begind a door, making them go to the neerest available point to them, which is on the other side of the map
- upgrade pathfinding a second time
- doubleclick on unit, to select all of them on screen
- dry moat
- make the option to load maps afer the game is built, so that additional maps can be added to the game, withought needing the user to download a new version
- siege lvl 1
	- ram siege weapon DONE (bigger units?) 
	- oil siege weapons DONE
	- larger single door DONE
	- drawbridge DONE
	- mote, that units can fill
- siege lvl 2
	- trebuchets
		- only fire where you tell them, they dont attack by themselfs
		- limited projectiles
		- area of effect
		- castle based too
	- destroyable walls
		- make the tiles have the value of the destruction, so its easier, less objects
- siege lvl 3:
	- siege tower OK
- wooden castles
- scenarios:
    - short scenarios, where you control X provicnes and have limited time to battle the enemy
- create basic maps:
	- enclosed norman keep OK
	- enclosed castle OK
	- linked castle
	- concentric castle
	- poli warded castle
- skirmish:
    - decide what siege weapons youll have
	- decide what the ration of your army will be
- ingame chat
    - also, make the chat in the lobby persistent
- horses and sieges cannot go on the walls
- tooltip when hovering over a unit
- weather
	- check if you can use multimashinstance2d for weather objects
	- set weather for all players the same
	- add fog
	- add wind
	- rain puddles
	- thunder
	- night/day
- shaders shaders shaders
- make filled moat be covered with dirt tiles, when the moat is removed
- make trees react to the wind, make them an object and movable
	- assign a value to the tiles, and the at the start of the game, just add tree objects
- make dynamic water with whaders or smtg, make it look like in monkey island 3
- make an outside resource where you set data for things like unit value, strenght, etc, so its more centralized
- waypoints
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
- LAN multiplayer OK
	- LAM multiplayer COOP OK

The main goal is basically LAN multiplayer, but since I think it will be the hardest part, the idea is to make a playable product beforehand.


![Castle](screenshots/lotrx_03.png)