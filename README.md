# Top-Down Shooter

A 2D top-down tactical shooter inspired by Valorant, built in Godot 3.5.3 Stable.

## Concept

The game takes the core ideas of Valorant and reimagines them in a 2D top-down perspective. Players face off against each other or against intelligent bots in tactical combat where vision, positioning, and resource management matter as much as aim.

## Key Features

### Field of View System
Each player and bot has a limited cone of vision with peripheral awareness. You only see enemies whose body crosses into your FOV cone — anything outside is hidden, including their own FOV cones. Line-of-sight checks mean walls block what you see, so positioning around cover is essential.

### Smart Enemy AI
Bots actively pursue the player instead of patrolling randomly. They:
- **Kite at distance** — keep an engagement band (~230–330 px), back off when too close, push in when too far
- **Strafe** left/right while shooting so they're never a stationary target
- **React to damage** — snap-turn to face their attacker the moment they take a hit, never lose the trail again
- Slide along walls and pick perpendicular avoidance routes when stuck

### Game Modes
- **Single Player** — fight three bots on a procedurally-built map with cover, lanes, and walls
- **Local PvP (LAN)** — host or join a 1v1 match over the local network via IP

### Map
A 2560 × 1600 arena built procedurally each match: two side bases connected by three lanes (top / mid / bottom), L-shaped cover, a center pillar, and tight choke points around the dividers. The camera follows your player with smoothing and is clamped to the map bounds.

### Resources & Consumables
- **Health pickups** (green ⛬) — restore HP, clamped to max
- **Ammo pickups** (orange ▮) — add reserve ammo
- **Armor pickups** (blue ⛨) — armor absorbs incoming damage **before** it hits HP
- Spawners distribute pickups across the lanes and refill empty spawn points on a timer (no two pickups ever stack on the same point)

### HUD
- **HP bar** with green → yellow → red color tiers as your health drops, plus a gloss highlight strip
- **Armor bar** in blue right below HP — damage soaks armor first
- **Ammo bullet icons** that empty out as you fire (and grey out during reload), plus a "current / reserve" readout
- All laid out in a styled rounded panel with drop shadow and orange accent

### Combat Feedback
- Floating red damage numbers with a pop animation, outline, and 1.2 s fade
- HP bar colors track damage severity
- Frozen world + blurred + darkened background when the match ends

### Game Over Screen
When you die or win, the world freezes (players, enemies, pickups all stop) and the screen blurs behind a stats card:
- Time alive (m:ss)
- Kills
- Shots fired (with hit count)
- Accuracy %
- Damage dealt / damage taken
- **Play Again** restarts the match, **Main Menu** returns to the menu

### Main Menu
A styled card with crosshair logo, animated tracer bullets streaking across the background, horizontal scrolling lines, and a chasing-dots loading spinner during connection. Hover any button to see it scale up; click outside the IP field to release focus.

## Controls

| Action               | Key                  |
|----------------------|----------------------|
| Move                 | W / A / S / D        |
| Aim                  | Mouse                |
| Shoot                | Left Mouse Button    |
| Reload               | R                    |
| Suicide / end match  | X                    |
| Restart (game over)  | R                    |

## Running

1. Open the project in **Godot 3.5.3 Stable**.
2. Press F5 (or click ▶) — boots into `MainMenu.tscn`.
3. **Single Player** — fight three bots.
4. **Local PvP**:
   - One machine clicks **Host PvP** (waits on port 7777).
   - The other clicks **Join PvP**, enters the host's IP, and connects.

To test PvP on a single machine, launch two instances of the project and join `127.0.0.1` from one to the other.

## Architecture

- **MainMenu.tscn / MainMenu.gd** — entry scene with styled buttons, tracer animation, spinner
- **World.tscn / World.gd** — gameplay scene: procedurally builds the tilemap walls, spawns the player (and enemies in single, the second player in PvP), runs the HUD, shows the game-over card
- **Player.tscn / Player.gd** — KinematicBody2D with movement, mouse aim, reload, FOV cone, server-authoritative damage in PvP, stat tracking
- **enemy.gd** — kiting + strafing + damage-aware AI, FOV cone visible only when the enemy is in your FOV
- **Bullet.tscn / Bullet.gd** — Area2D projectile with `damage`, `owner_node`, hit notification back to the shooter
- **AmmoPickup / HealthPickup / ArmorPickup** — Area2D pickups with bob animation and spawn-in tween
- **AmmoSpawner / HealthSpawner / ArmorSpawner** — fill spawn points at start, refill on a timer, never stack on occupied points
- **GameState.gd** *(autoload)* — match mode (`SINGLE` / `PVP_HOST` / `PVP_CLIENT`), port constant, host IP
- **NetworkManager.gd** *(autoload)* — `NetworkedMultiplayerENet` host/join/leave, scene transition, peer-left + join-failed signals
- **DamageNumber** — floating red number with pop, outline, fade

## Networking

LAN multiplayer uses Godot's High-Level Multiplayer API over ENet (port 7777). Movement and aim are **client-authoritative** (each peer is master of their own player, position synced via `rset_unreliable`); damage and HP/armor changes are **server-authoritative** (only the host mutates state, then RPCs the result to all peers). Bullets are RPC'd visually but only the host arbitrates collisions.

## Roadmap

- [x] Player movement and shooting
- [x] FOV cone system + peripheral vision + body-edge cone check
- [x] Enemy AI with kiting, strafing, damage awareness
- [x] Procedural tilemap map with cover and lanes
- [x] HP / armor / ammo pickups
- [x] Styled HUD (HP bar, armor bar, ammo icons)
- [x] LAN PvP (host / join)
- [x] Main menu + game-over stats screen
- [x] Suicide key (X)
- [ ] Sound effects + music
- [ ] Custom sprites (player, weapon, enemy, pickups)
- [ ] Abilities (Full Vision, etc.)
- [ ] Rounds / scoring for PvP
- [ ] Settings menu (volume, controls)
