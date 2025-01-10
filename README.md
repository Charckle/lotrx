# What
- lotrx is supposed to be a soft clone of the Lords of the realm 2 RTS battles. The soft part implies that the technological limitations will be removed, additional features will be added, the combat between units will be different
- the basic idea is to reacapture the spirit of the game

# Current status
- one open map, one castle map.
- the open map is playable: the AI will attack or defend. If the attacker is loosing, the AI will counterattack. If the AI is the attacker, it will retreat.
- the castle map is...eeh... work in progress
- archers have problems attacking enemies that are behind walls. Yeah, I know.

# To Do
- fix archer attacking if there is no path to unit
- cranulations
- agression stances
- upgrade pathfinding
- oil siege weapons
- ram siege weapon (bigger units?)
- update maps to new tilesistem for new godot version
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
- units:
	- make stances: hold and agressive: when you defend, you dont want them to be aggressive
- siedge weapons
- damage difference depending on the angle of attack (if you get hit in the back, auch)
	- arrows deal more damage the closer they are shot at a target
	- castle walls give extra range
- a campaign
- LAN multiplayer

# Goal
- multiple campaign, trough which you could explore parts of history and real castles.
- multiple castle maps, based on real life castles
- skirmishes, where you can choose to fight an AI in a specific scenario
- AI tiers
- LAN multiplayer
	- LAM multiplayer COOP

The main goal is basically LAN multiplayer, but since I think it will be the hardest part, the idea is to make a playable product beforehand.
