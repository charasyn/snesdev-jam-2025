# Engine notes for CHE (cooprocks123e HAL-like engine)
## Goals
- DMA in VBlank: OAM, Palette, VRAM queue
- OAM construction
   - double-buffered
   - game logic populates "spritemaps" in one of 3 priority lists
- Entity and script system
   - similar to earthbound
-

## Design
### VRAM DMA queue
- size (16)
- dest addr (16)
- source addr (24)
- type (8)

32 entries (256 bytes)

### Sprites

Order:
- game entities
   - create
- "priority spritemap table" entries
   - get ordered and put into
- OAM

Game entities: these are covered in another section, very similar to HAL object system

"Priority spritemap table" entries:
- X, Y
- spritemap pointer

Spritemap entries:
- X (16)
- Y (16)
- Tile + settings (16)
