# Art Bible

Version 0.1, 2026-11-14. The measurable standard every visual asset is reviewed against. A reviewer should be able to pass or fail an asset from this document alone.

The numbers here are starting values. They are calibrated on the door (stage 2) and the first street corner (stage 3), measured on the reference PC (GTX 1660 SUPER, 1080p). When a number changes, it changes here first.

## 1. The look in one paragraph

Realistic, solid and specific. Things have the right size, the right weight and a history: paint worn where hands touch, stone darkened where rain runs. Materials respond to light the way the real ones do. We are not chasing photographs of human faces; people are believable and slightly simplified. Every asset is built to be looked at from arm's length.

## 2. Scale and orientation

| Rule | Value |
|---|---|
| Unit | 1 unit = 1 metre |
| Up / forward | +Y up, asset faces -Z (Godot convention) |
| Origin | Centre of the base, on the ground, unless the asset hinges or rotates; then at the pivot |
| Dimensions | Real-world, within 2% of a documented reference. State the reference in the pull request |
| Applied transforms | Scale 1, rotation 0 on export |

Reference sizes: adult 1.75 m; eye level 1.6 m; door leaf about 0.9 by 2.1 m; stair riser 0.17 m; kerb 0.12 to 0.15 m; Berlin tenement storey 3.2 to 3.8 m; traffic lane 3 m.

## 3. Geometry

- No razor edges. Any edge visible at eye level has a real bevel or a baked one.
- Silhouette first: spend triangles where the outline is seen, not on flat faces.
- Clean shading: no visible faceting on curved parts at 1 m; no shading seams.
- Moving parts (door leaf, handle, wheel, lid) are separate objects with correct pivots.
- No hidden faces inside sealed volumes; no overlapping duplicate faces.

### Triangle budgets (highest level of detail)

| Class | Example | Budget |
|---|---|---|
| Hero piece | The door, a landmark detail, a key gadget | up to 80,000 |
| Small prop | Telephone, lamp, bottle | up to 5,000 |
| Medium prop | Bench, phone booth, kiosk | up to 15,000 |
| Large prop | Tram shelter, market stall | up to 30,000 |
| Vehicle | Exterior up to 60,000; interior up to 30,000 |
| Character | Body, head and one outfit | up to 50,000 |
| Facade piece | One window bay, one shopfront | up to 8,000 |

### Levels of detail

- Named `_LOD0` (full) to `_LOD3`. Targets: LOD1 50%, LOD2 25%, LOD3 10% of LOD0.
- Hero pieces, vehicles and characters ship hand-checked LODs. Other classes may rely on the engine's automatic LODs if they hold their silhouette.
- Collision: a simple convex shape per part, named with the `-col` suffix so the engine imports it as collision.

## 4. Materials and textures

Physically based, metallic-roughness workflow.

| Map | Rule |
|---|---|
| Base colour | sRGB. No baked lighting or shadows. Non-metal values between 30 and 240 (of 255) |
| Metallic | 0 or 1. In-between values only at worn transitions |
| Roughness | Varied and motivated. Never one flat value across a surface |
| Normal | OpenGL convention (green up) |
| Occlusion, roughness, metallic | Packed into one texture: red = occlusion, green = roughness, blue = metallic |
| Emission | Only for things that emit light |

### Texel density (texture pixels per metre of surface)

| Use | Density |
|---|---|
| Hero pieces and anything touched or read up close | 2048 px/m |
| Standard props, characters, vehicles | 1024 px/m |
| Building facades, ground | 512 px/m, with detail or trim textures for close range |
| Distant-only pieces | 256 px/m |

Density must be even across an asset (within a factor of 1.5), except where a part is deliberately given more.

### Texture sizes and quality tiers

Author at the highest tier. The engine produces the lower ones on import.

| Tier | Runs on | Largest texture |
|---|---|---|
| High | Reference PC and better | 4096 |
| Medium | Weaker PCs | 2048 |
| Low | Tablets and phones | 1024 |

- Source textures are PNG (16-bit for height where used). The engine handles compression.
- Material count: up to 2 on small and medium props, up to 4 on hero pieces, vehicles and characters. Glass is always its own material.
- Reuse shared trim and tiling materials before making unique ones.

### Wear and history

- Wear follows use: edges, handles, kick height, where water runs, where sun reaches.
- No uniform noise or "dirt everywhere". If you cannot say why a mark is there, remove it.
- Period-correct materials for the world and year. For Berlin 1961-63: oil paint, enamel signs, brass, cast iron, bakelite, sandstone, render, cobbles.

## 5. Period, originality and names

- Every asset fits its world's year. Give your reference in the pull request (see the reference packs in `docs/reference/`).
- No real brands, logos, maker's marks or product names. Invent them, or leave plates blank.
- No real people's names on signs, plates or documents.
- Text on assets is in the world's language and period lettering, and says something ordinary.
- Built from your own work or openly licensed sources only, with ledger rows (see `CONTRIBUTING.md`).

## 6. Characters

- Realistic proportions, about 7.5 heads tall. One shared skeleton, defined in the technical design.
- Faces: believable structure, slightly simplified skin and features. No attempt at photographic likeness, and never a real person.
- Clothing is separate skinned pieces with real fabric behaviour in the material: wool is rough and matte, leather has worn highlights.
- Hair is modelled shapes or cards, whichever holds up at 1 m on the reference PC.

## 7. Files and names

```
assets/<world>/<class>/<name>/
  source/     the .blend file (Blender 4.2 LTS) or the script that makes it
  export/     <name>.glb  (glTF 2.0 binary)
  textures/   <name>_<part>_basecolor.png, _normal.png, _orm.png, _emission.png
  review/     the pictures listed in section 8
```

- Lowercase, underscores, no spaces: `berlin_prop_phone_booth_a`.
- `<world>` is a city name or `shared`. `<class>` is `hero`, `prop`, `vehicle`, `character`, `facade`, `interior`, `ground`.
- Object names inside the file match the file name, with `_LOD0`, `-col` and part names added.

## 8. What a contribution must include

1. The source file and the export.
2. Review pictures, in `review/`:
   - turntable, 8 angles, neutral light
   - wireframe over shaded
   - texel-density checker view
   - in game at eye level (1.6 m) from 1 m, 3 m and 10 m, in the lighting it will be seen in, next to existing assets
3. In the pull request: real-world reference and dimensions, triangle count per LOD, texture sizes, material count, tools used.
4. Ledger rows for anything third-party.

## 9. How it is reviewed

Automatic checks (built in stage 2) measure: dimensions against the declared reference, transforms, triangle counts, LOD and collision presence, texel density, texture sizes, base-colour and metallic ranges, naming and folder layout.

A person or agent then checks what cannot be measured: does it read as the real thing at arm's length, does the wear make sense, does it sit with its neighbours, is it of its year. Review follows `AGENTS.md`, section 7.

## 10. Lighting

- Light is physically motivated: every light has a source you could point to.
- One sun or moon, practical lamps, light from windows and doorways. Fog and a colour grade per city.
- Night scenes are lit by their practicals. Black is allowed to be black.
- Reflections matter for wet streets and polished metal; assets are checked under them.

## 11. Specification: the door

The first asset, and the standard for all others. Stage 2.

**What it is:** the entrance door of a Berlin tenement flat, built around 1900, as it looks in 1961. It stands alone in an empty black void, closed, with light coming from behind it.

| | |
|---|---|
| Leaf | About 0.92 m wide, 2.12 m high, 45 mm thick. Solid softwood, frame-and-panel construction with raised panels and mouldings |
| Frame | Full door frame with architrave and a worn threshold. Stands free; finished on both sides |
| Finish | Several layers of oil paint, the older colour showing where it has chipped. Brush marks. Wear at hand height and kick height |
| Hardware | Brass lever handle and escutcheon, polished by use where it is gripped; keyhole; mortise lock; three hinges; a letter slot; a blank name-plate holder; a bell push on the frame |
| Moving parts | Leaf swings on its hinges; handle turns; letter-slot flap lifts. Each a separate object with a correct pivot |
| Gap | 8 mm under the leaf, with light spilling through onto the ground |

**Standard it must meet:**

- Holds up with the camera 0.3 m from the surface: wood grain, paint edges, screw slots and the keyhole interior all resolve.
- Up to 80,000 triangles at LOD0 including hardware. Texel density 2048 px/m on the leaf and frame, higher on the hardware.
- Up to 4 materials: painted wood, brass, iron, and one spare.
- Every mark has a reason. The handle is brighter where a thumb goes. The paint is thin on the edge of the stile where the door has been pushed for sixty years.
- No real maker's marks, no name on the plate.

**The scene around it:** pure black, no horizon. The ground exists only where the door's light touches it. One soft key light and the warm light from under the door. The voice speaks when the player comes close. The player can walk around the door, touch the handle, and open it.

**Delivered with:** everything in section 8, plus a close-up set (handle, keyhole, a hinge, the bottom rail, the chipped paint) and frame-rate and memory figures on the reference PC.
