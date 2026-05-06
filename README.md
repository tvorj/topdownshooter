# Top-Down Shooter

A 2D top-down shooter inspired by Valorant, built in Godot 3.5.3 Stable.

## Concept

The game takes the core ideas of Valorant and reimagines them in a 2D top-down perspective. Players face off against each other or against intelligent bots in tactical combat where vision, positioning, and abilities matter as much as aim.

## Key Features

### Field of View System
Each player and bot has a limited cone of vision. You can only see and react to what's inside your FOV — everything outside is hidden. This makes positioning and map awareness critical.

### Smart Bots
Bots are aware of their surroundings through their own FOV. They will only shoot at the player if the player is within their cone of vision, making them feel like real opponents rather than simple enemies.

### Abilities
Abilities are designed around the 2D FOV system:
- **Full Vision** — Expand your FOV to 360° temporarily, revealing all threats around you
- More abilities coming soon...

### Combat
- Real-time shooting with projectile physics
- Tactical movement and cover usage
- HP system with damage feedback

## Controls

| Action | Key |
|--------|-----|
| Move | W / A / S / D |
| Aim | Mouse |
| Shoot | Left Mouse Button |

## Roadmap

- [x] Player movement
- [x] Shooting system
- [x] Basic enemy AI (chase)
- [ ] Tilemap level
- [ ] FOV cone system
- [ ] Bots shoot within FOV
- [ ] Abilities
- [ ] Rounds / win conditions
- [ ] UI (HP bar, score)
