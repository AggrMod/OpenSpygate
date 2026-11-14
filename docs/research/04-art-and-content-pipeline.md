# 04: Art and Content Pipeline Research

> **Policy change, 2026-11-14.** The project now makes all of its own assets and accepts no third-party asset files (fonts excepted), and its licences are MIT for code and CC BY 4.0 for everything else. Where this document talks about using third-party sources or about CC BY-SA or GPL, it is out of date and is kept as background. `CONTRIBUTING.md` is the rule.

**Project:** OpenSpygate: original open-world, multiplayer, third-person espionage game set in several stylized city "worlds" (Berlin-like, Vienna-like and Istanbul-like cities).
**Builder:** one AI developer who drives Blender 4.2 LTS by Python script (no hand modeling) and builds in Godot 4.x.
**Hardware targets:** GTX 1660 desktop (6 GB) and Android tablets (mid/low tier).
**Hard rules:** no placeholder art on screen (boxes and capsules do not ship, even in the first playable build). Everything is original or properly licensed, CC0 preferred. Nothing comes from commercial games.
**Researched:** 2026-11-14, using about 25 web searches plus direct fetches of license pages.

> **How to read the tags.** **[V]** means verified against the source quoted. **[V-2nd]** means confirmed only through secondary sources or forum reposts. **[U]** means not verified in this research (from general knowledge); check it before you rely on it. None of this is legal advice.

---

## 0. TL;DR recommendations

1. **Style: "Graphic-novel low-poly."** Low-poly geometry, flat colors from a palette texture, a two- or three-step toon light ramp, inverted-hull outlines on characters and hero props, heavy distance fog and per-city color grading. Mood comes from light and color. Detail does not carry it. A script pipeline can produce this style reliably. The big CC0 libraries (Kenney, Quaternius, KayKit) already use flat palette-textured models, so they blend in after a recolor. It runs on the GTX 1660 and on tablets with Godot's Mobile renderer. Avoid photoreal PBR, which a script cannot make look good and which exposes every weak mesh. Also avoid raw PS1 jitter as the main look, because it reads as "retro horror" and is tiring on a tablet.
2. **Cities come from a facade-module kit plus a generator.** Write roughly 50 to 70 parametric facade, roof and corner modules per city in Blender Python. Generate building masses from footprints, using a fictional layout loosely inspired by OSM street patterns. Hand-compose 3 to 5 landmarks per city. Build 6 to 10 enterable interiors as a few handcrafted rooms. All other buildings stay closed shells with lit windows.
3. **Characters: one shared humanoid skeleton.** Use Quaternius Universal Animation Library 1 and 2 (CC0, more than 120 clips in the first) as the animation base. Build modular bodies, heads, clothes and palette swaps for crowds. Retarget in Godot with `SkeletonProfileHumanoid` and a BoneMap. Use Mixamo only as a supplement, under its "no redistribution of raw files / no ML training" terms.
4. **Voice: Kokoro-82M (Apache-2.0).** Bake briefings offline to WAV. Use Rhubarb Lip Sync (MIT) only where a face is on screen. Better still, deliver briefings as radio or dossier slideshows so no face is needed.
5. **Keep a license ledger from day one** (`assets/LICENSES.csv`: source URL, license, author, date fetched, sha256). Ship a credits screen that includes "© OpenStreetMap contributors" if any OSM data is used.

---

## 1. Art style that a scripted pipeline can deliver

### 1.1 What a script-driven Blender pipeline is good and bad at

| Good at (deterministic, parametric) | Bad at (needs an artist's eye or sculpting) |
|---|---|
| Architecture: boxes with bevels, arrays, window bays, cornices, roofs | Organic faces, realistic cloth folds, hair cards |
| Repeating props such as lampposts, benches, kiosks, phone booths and signs | Hand-painted textures and believable wear |
| Hard-surface vehicles made from profile curves and lofts | Photoreal PBR materials that hold up close |
| Assigning colors from a palette atlas (UVs snap to swatches) | Unique stylized character silhouettes, unless built from a template |
| LODs, decimation, collision proxies, batch export | Animation keyframing beyond simple loops |

The style should put the weight on **shape, color, light and composition** and take it off surface detail. This is the same reasoning behind the small-team successes below.

### 1.2 Candidate styles compared

| Style | Script-friendly? | 1660 / tablet cost | Fits espionage? | Verdict |
|---|---|---|---|---|
| **Flat-shaded low-poly + palette texture + toon ramp + outlines ("graphic-novel")** | Excellent | Very low (one material, batches well) | Strong. It reads as 1960s spy-poster and comic art. | **Recommended** |
| Smooth low-poly "Kenney/Quaternius" look with no post | Excellent | Lowest | Reads "cute/casual" without grading | Use as the base, then add lighting and outlines |
| PS1 retro (affine warping, vertex snap, 320p, dithering) | Good | Low | Reads as horror (Haunted PS1 scene) | Optional "VHS/CCTV" filter only |
| PS2-era (more polys, baked lighting, blob shadows) | Medium (needs texture painting) | Low | Good: the Cold War nostalgia era | A good accent, such as baked vertex-color AO |
| Moebius line art (Sable) | Medium (custom shaders, precise outlines) | Medium (outline passes) | Strong, but the reference is very recognizable | Borrow the principles: flat light plus lines plus fog |
| Stylized PBR (Fortnite-like) | Poor (needs painted textures) | Medium/high | Neutral | No |
| Photoreal PBR | Poor | High | Neutral | No |

### 1.3 Small-team open-world (or open-ish) references and why their style worked

- **Sable (Shedworks).** The core team began as two people and grew to roughly 6 to 10 during development. Sources disagree: Engadget says "two-man team", and MCV says "fluctuated between six and 10" **[V-2nd]**. The creative director cites Moebius and Ghibli and says "We kept all the lighting really flat." Because flat shading leaves fewer tools, they built depth in layers with lighting, fog and lines. They also leaned on modular construction (Unity case study, "How a modular design approach crafted Sable"). **Lesson:** flat shading plus outlines plus fog layers gives readability and mood without detailed textures. Sources: https://www.gamedeveloper.com/marketing/how-shedworks-refined-the-art-of-sable-in-pursuit-of-readability , https://videogameartgallery.com/vga-zine/vga-fireside-highlights-gk , https://mcvuk.com/business-news/when-we-made-how-shedworks-went-from-a-north-london-shed-to-the-stunning-dunes-of-sable/ , https://unity.com/en/resources/shedworks-sable-modular-design-approach
- **Dread Delusion (Lovely Hellplace).** It started as one developer (James Wragg) working "in Blender and Unity" and became an open-world RPG in PS1 style. A small writing team joined later. **Lesson:** a deliberately limited low-poly look let one person ship an open world, and the limits make interactable things easy to spot. Sources: https://rpgsite.net/interview/16267-dread-delusion-creative-director-speaks-on-how-flying-islands-helped-development-why-ps1-games-are-timeless , https://en.wikipedia.org/wiki/Dread_Delusion
- **Agent 64: Spies Never Die (Replicant D6).** A solo developer made this N64-style spy shooter and released it on PC on 2026-08-11 after about 5.5 years of work **[V-2nd]**. **Lessons:** (a) low-poly, chunky characters are accepted in the spy genre and even welcomed, and (b) the scope warning is that a solo developer took more than 5 years, and the game is mission-based, not open-world multiplayer. Sources: https://www.timeextension.com/news/2026/07/agent-64-is-the-perfect-dark-and-goldeneye-007-successor-weve-been-waiting-for-and-it-arrives-next-month , https://www.gamedeveloper.com/press-release/retro-spy-fps-agent-64-spies-never-die-infiltrates-pc-today
- **Bomb Rush Cyberfunk (Team Reptile, small Dutch indie founded in 2011 by two people).** It is set in a fictional city ("New Amsterdam") split into five boroughs, and each borough is a distinct district. Team size and rendering technique were **[U]** in this research. **Lesson:** a few strongly themed districts beat a large generic city. Source: https://en.wikipedia.org/wiki/Bomb_Rush_Cyberfunk
- **Townscaper and Tiny Glade.** Both are procedural, very small teams, and generate buildings from rules and modules **[U]**. **Lesson:** a good generator plus a strict palette can look handcrafted.

### 1.4 Concrete art bible for Spycraft (proposed)

- **Geometry:** low-poly with chamfered edges. A 2 to 3 cm bevel at building scale catches the toon ramp highlight, and that one detail removes the "box" look. Avoid smooth subdivision.
- **Color:** one 256x256 **palette atlas** shared by every environment mesh, with 8x8 swatch blocks of about 32 px. UVs snap to swatch centers, so a single material and a single texture cover the whole city and draw calls batch. Recolor CC0 kits into the same atlas so they match.
- **Per-city identity through palette and lighting:**

| City | Palette mood | Light | Signature shapes |
|---|---|---|---|
| Berlin-like ("Grenzstadt") | Concrete greys, tram yellow, sodium orange, red-flag accents | Overcast day, sodium-lit night, wet streets | Wall/checkpoint barriers, prefab housing slabs, rail viaducts, watchtowers |
| Vienna-like ("Kaiserstadt") | Cream, ochre and pastel facades, green copper roofs, gold trim | Warm late afternoon, lamplit night, fog | Baroque cornices, ring boulevard, Ferris wheel silhouette (original design), cafés, sewer tunnels |
| Istanbul-like ("Bosphor") | Terracotta, whitewash, turquoise tile, brass | Hot haze, sunset gold, harbor night | Domes and minarets (generic, not real mosques), ferries, bazaar arcades, hills down to water |

- **Shading:** a Godot `ShaderMaterial` with a 2- or 3-band ramp. Cool shadow tint for each city, plus rim light on characters. Use vertex-color AO baked in Blender for the "PS2-era" grounding.
- **Outlines:** inverted-hull outlines (backface-extruded shell) on characters, vehicles and interactables only. These are cheap and work on the Mobile and Compatibility renderers. Do not use screen-space outlines on tablets.
- **Atmosphere:** depth fog and height fog, plus a per-city color-grading LUT (`Environment.adjustment_color_correction`). Precomputed lightmaps only for interiors. Exteriors use one directional light, with shadows on PC and blob or projected shadows on tablets.
- **Optional filters:** a "CCTV/surveillance" post filter (scanlines, low-res) used diegetically when hacking cameras. That is where the PS1 and VHS look belongs.

### 1.5 Performance envelope (rules of thumb, **[U]**; measure on device)

- **Renderer:** Forward+ on PC. Use **Mobile** (Vulkan) for tablets, with **Compatibility** (OpenGL) as the fallback for older GPUs. The Godot docs say Compatibility "supports the widest range of hardware", and Mobile lacks SDFGI and volumetric fog. Benchmark both on the actual test tablets. Source: https://docs.godotengine.org/en/stable/tutorials/rendering/renderers.html **[V]**
- **Tablet targets:** under about 300 draw calls, under about 300k visible triangles, 1 to 2 shared materials for the environment, no dynamic shadows beyond the player, MultiMesh for props and crowds, aggressive visibility ranges or HLOD.
- **PC target (1660):** 60 fps at 1080p with shadows, SSAO off or low, and higher LOD distances.

---

## 2. City building at scale

### 2.1 Approach: kit + generator + hand-placed hero content

1. **Facade-module kit per city**, written as Blender Python (bmesh) functions with parameters: `wall_bay(width, floors, window_style, sill, lintel)`, `corner(...)`, `cornice(...)`, `roof_mansard(...)`, `shopfront(...)`, `door(...)`, `balcony(...)`. Modules share a grid, for example 3.0 m bays and 3.2 m floor height (Vienna-like gets 3.8 m floors). Each module exports at 2 to 3 LODs.
2. **Building generator:** input is a footprint polygon plus tags (height, style, ground-floor use). Output is a single merged mesh per building with UVs on the palette atlas. Two options:
   - **Pure Python assembly:** place module instances along footprint edges and merge them. This is deterministic, easy to diff and easy to test. **Recommended**, because the developer is a script.
   - **Geometry Nodes:** build a GN node group once (by script) and drive it with attributes. It is fast to iterate on but harder to version and debug from text. Existing GN generators include **Buildify** by Pavel Oliva: free base and $17.80 premium, generates buildings from part libraries, and works with Blender OSM. Its license text was **[U]**: CG Channel describes it as free but no license file was found. One commercial alternative licenses its *outputs* as CC BY 4.0 and forbids redistributing the node group. Read any such add-on's license before shipping meshes made with it. Writing our own avoids the question. Sources: https://www.cgchannel.com/2022/07/download-free-blender-3d-building-generator-buildify/ , https://blendermarket.com/products/procedural-building-generator
3. **Blocks and parcels:** generate street blocks from a road graph, subdivide them into parcels, and assign a building archetype to each parcel. Give each district roughly 6 to 10 archetypes, such as tenement, embassy villa, prefab slab, café row, warehouse or bazaar arcade.
4. **Hand-composed landmarks:** 3 to 5 per city, made from bigger bespoke scripts plus kit parts. They are orientation anchors and are visible on the minimap.
5. **Set dressing by rule:** sidewalks get lampposts every N m, plus benches, bins and kiosks near intersections. Cafés get awnings and tables. Place these with deterministic seeds so the network layer can rebuild identical worlds.

### 2.2 Roads

- Use a road-graph data file (nodes and edges with type: boulevard, street, alley, tram line, bridge, stairs). One Blender script generates road meshes, curbs, sidewalks and tram rails. A Godot script builds navigation (`NavigationRegion3D`), traffic lanes and minimap vectors from the **same graph**, so there is one source of truth.
- Kit pieces cover what generated meshes do poorly: intersections, roundabouts, plazas and bridge ends. Kenney City Kit (Roads) is CC0 for reference shapes, but we would restyle it.
- For Godot's built-in road tooling, the community "Road Generator" add-on exists **[U]**. Generating from our own graph is simpler to keep consistent.

### 2.3 Using OpenStreetMap as layout inspiration

- **License:** OSM data is under the **ODbL 1.0**. A game rendered from OSM data is a **Produced Work**: "only the data is covered by the license." The game can carry any license, **but** if the work is used to extract or recreate substantial parts of the data, it is "considered to be a Derivative Database" and share-alike applies to that database. **[V]** https://osmfoundation.org/wiki/Licence_and_Legal_FAQ
- **Attribution:** it is required when a Produced Work is used publicly. For "video or computer games, attribution can be provided by a splash screen on application startup", with wording such as "Map data from OpenStreetMap" or "© OpenStreetMap". It must not require user interaction to see. **[V-2nd]** (OSMF attribution guideline) https://osmfoundation.org/wiki/Attribution , https://wiki.openstreetmap.org/wiki/Open_Data_License/Community_Guidelines/Attribution_For_Different_Media_Types
- **Our obligations, by risk level:**
  - **Safest (recommended):** use OSM only as **visual reference** for street patterns, block sizes and the ratio of boulevards to alleys. Then author a **fictional** road graph by script, with original street names and districts. If no OSM data is transformed into game data, ODbL obligations are minimal. Credit OSM anyway as a courtesy.
  - **If OSM geometry is imported** (for example with the Blosm Blender add-on, whose free version imports untextured OSM buildings and whose source is GPL **[V-2nd]**): the shipped level is a Produced Work. Add the attribution splash and credits line. Do **not** ship the extracted road and footprint database as a separate data file that others could pull out. If you do, publish that database under ODbL. https://github.com/vvoovv/blosm , https://wiki.openstreetmap.org/wiki/Blender-osm
  - **Fetching data:** the Overpass API and OSM tile servers have usage policies (rate limits, no bulk scraping) **[U]**. Use a one-time regional extract (for example a Geofabrik `.osm.pbf`) instead of repeated API calls.
- **Real buildings and landmarks:** do not reproduce identifiable real landmarks one-to-one. Use "inspired-by" compositions (for example "a baroque palace with a green copper dome", not a specific named palace). Architecture rights and freedom-of-panorama rules vary by country **[U]**, so fictional landmarks avoid the issue entirely.

### 2.4 District identity

For each city, define 4 to 6 districts. Each one gets a building archetype mix, a palette subset, a prop set, an ambience bed, a street-sign style and NPC wardrobe weights. Example districts for the Berlin-like city:
- Checkpoint and wall zone: barriers, searchlights, guard NPCs, sparse props.
- Old tenement quarter: courtyards, laundry lines, corner pubs.
- Socialist boulevard: wide avenue, prefab slabs, parade stands.
- Rail and industrial yards: warehouses and cranes, good for chases.
- Western shopping street: neon, cafés, cinema.

### 2.5 Interiors strategy

- **Few, handcrafted, high-value interiors (6 to 10 per city):** safehouse (the player hub), embassy lobby and office floor, grand hotel lobby, café or bar, apartment template, warehouse, sewer or tunnel segment, police or secret-police station, and a hideout per mission. Build these from a shared **interior kit** of 40 to 60 pieces: wall, door and window frames, stairs, furniture, filing cabinets, desks, typewriters, radios and lamps.
- **Everything else stays closed but alive.** Use emissive window cards with a lit and curtained palette, plus an occasional silhouette card or **interior-mapping shader** that fakes rooms behind windows (cheap on PC; disable on tablets **[U]**).
- **Procedural "apartment" interiors** come from one room-template generator for missions that need "any apartment on the block." Reuse 3 to 4 layouts with different dressing seeds.
- Load interiors as separate scenes (doors are loading triggers or seamless portals). This keeps the exterior streaming budget clean, and in multiplayer it allows instancing per mission.

---

## 3. CC0 and permissive 3D asset sources

| Source | License (quoted) | Useful for Spycraft | Automated download terms |
|---|---|---|---|
| **Kenney** (kenney.nl) | "all game assets on the asset pages are public domain licensed (CC0)… You're free to use them, even in commercial projects… Attribution is not required." Credit is welcome, but do not use the Kenney logo by itself. **[V]** https://kenney.nl/support | City Kit (Commercial/Suburban/Roads/Industrial), Car Kit, Furniture Kit, Animated Characters, UI packs, audio packs (UI, impacts, etc.) **[V-2nd]** for the Car Kit and City Kits via OpenGameArt/itch; others **[U]** | No stated policy found. Kenney sells or offers an "All-in-1" bundle, so download that instead of scraping. |
| **Quaternius** (quaternius.com) | CC0 ("Free to use in personal, educational and commercial projects. (CC0 License)") **[V]** https://quaternius.com/packs/universalanimationlibrary.html | **Universal Animation Library 1 (120+ clips: 8-direction locomotion, jog, sprint, crawl, swim, sit, deaths) and 2 (Jan 2026: melee/armed combos, parkour, etc.)** on a "universal humanoid rig… ready for retargeting". Ships FBX, glTF and (UAL2) .blend. Also LowPoly Cars (CC0 on OpenGameArt **[V-2nd]**), plus modular characters and city or props packs **[U]**. https://quaternius.com/packs/universalanimationlibrary2.html , https://opengameart.org/content/lowpoly-cars | No stated policy found. Manual download from itch.io or the site. |
| **KayKit** (Kay Lousberg) | CC0 1.0 on itch.io, GitHub and the Godot Asset Library **[V-2nd]**. The paid **Unity Asset Store** versions carry that store's license, so use the itch/GitHub copies. https://kaylousberg.itch.io/city-builder-bits | City Builder Bits (roads, buildings, cars, props in a stylized look), Furniture Bits, character packs with rigs **[U]** for the character details | Pay-what-you-want on itch, plus a GitHub repo. Clone the repo for reproducible fetching. |
| **Poly Haven** (polyhaven.com) | "all its HDRIs, textures, and 3D models are licensed as CC0" **[V]** https://polyhaven.com/license | HDRI skies for lighting reference and baking, plus tileable textures (brick, plaster, cobblestone) to **sample palette colors from or to downsample into stylized tiles**, and props/furniture models (realistic, so they need restyling) | **API:** "The Poly Haven API is now free for everyone - including commercial use." It encourages integration and bulk download. Conditions: "All requests to the API require a unique User-Agent header," and in tools you make, "make it clear to your users that the assets came from Poly Haven", which is "a condition of using the live API service, not of the assets themselves." Endpoints may change. **[V]** https://polyhaven.com/our-api . An older dev log said commercial API use needed permission; that is superseded by the page above. |
| **ambientCG** (ambientcg.com) | "All ambientCG assets are provided under the Creative Commons CC0 1.0 Universal License… even for commercial purposes… You can include the raw files in your project, for example a video game." Credit is optional. **[V]** https://docs.ambientcg.com/license | PBR materials, the same use as Poly Haven textures (sample colors, make stylized trims), plus decals | A public API exists (v3 endpoint, used by community importers). **No rate-limit or scraping policy was found**, so be polite: cache, fetch only what you need, and set a clear User-Agent. |
| **OpenGameArt.org** | **Mixed, set per asset** (CC0, CC-BY, CC-BY-SA, GPL…) | Filter to CC0. Quaternius' and Kenney's uploads are mirrored there. | Check every file's license and record it in the ledger |
| **Poly Pizza** (poly.pizza) | Mixed CC0 / CC-BY per model **[V-2nd]** | Quick browsing of low-poly models | Record the license per model |

**Restyling rule:** every imported kit asset goes through a script that (1) remaps its materials to the Spycraft palette atlas, (2) adds the bevel or vertex-AO pass where useful, (3) generates collision and LODs, and (4) writes a ledger row. This keeps third-party assets from looking pasted in and keeps the look consistent.

**Avoid:** Sketchfab models unless each one is checked for CC0 or CC-BY; TurboSquid/CGTrader "free" items with editorial-only or no-game clauses; anything ripped from games, including fan "model resource" sites; and the Bandai Namco motion dataset (see section 4).

---

## 4. Characters and animation

### 4.1 Rigged character sources

- **Primary: build our own modular humanoid in Blender by script** on the **Quaternius UAL skeleton**, or on a skeleton whose bones match `SkeletonProfileHumanoid` naming. One male and one female base body, stylized proportions about 7 heads tall with slightly larger hands and heads for readability, and around 2.5k to 5k triangles. Clothing is separate skinned meshes that share the skeleton.
- **CC0 starting points:** Quaternius modular characters and KayKit character packs **[U]**. Kenney Animated Characters (CC0) **[U]**.
- **MakeHuman / MPFB:** its outputs are CC0 per the project **[U]**. This is useful for a realistic base mesh that is then simplified by script. Verify the current MPFB asset licenses before use.

### 4.2 Animation libraries and licenses (precise)

| Library | License | Notes |
|---|---|---|
| **Quaternius Universal Animation Library 1 & 2** | **CC0**: "Free to use in personal, educational and commercial projects. (CC0 License)" **[V]** | **Primary library.** UAL1 has 120+ clips (8-direction locomotion, jog, sprint, push, crawl, swim, sit, deaths). UAL2 (Jan 2026) has melee and armed combos, parkour, etc. It is a universal humanoid rig compatible with Godot. Ships glTF, FBX and .blend. https://quaternius.com/packs/universalanimationlibrary.html |
| **Mixamo** (Adobe) | Free, needs an Adobe ID. Adobe's FAQ (2022 community repost): characters and animations are "available for free, with no licensing or royalty fees, for unlimited commercial or non commercial use", with "Video Games" listed as allowed. However, "really the only thing you can't do is distribute the raw character and animation files". Files may be shared within your project team but not with customers or outsiders. **"Blueprints, templates, or asset packages for video game engines"** may not be created. **"The only research application Mixamo content can't be used in is training machine-learning models."** Governing text is the Adobe Terms of Use. **[V-2nd]** (the official helpx FAQ returned 403 to our fetch) https://community.adobe.com/t5/mixamo-discussions/mixamo-faq-licensing-royalties-ownership-eula-and-tos/td-p/13234775 | Allowed **embedded in the shipped game**. **Not allowed:** putting Mixamo FBX/glTF files in a public repo, a mod kit or an open-source release, or in any dataset used for ML. If the Spycraft repo will ever be public, keep Mixamo-derived clips out of it, or avoid Mixamo entirely. No public download API was found, so there is no sanctioned automated download; download manually. |
| **CMU Graphics Lab Motion Capture Database** | Described as free for research and usable in commercially sold products, but not resellable directly "even in converted form", with credit requested **[V-2nd]**. Check http://mocap.cs.cmu.edu (the "free for all uses" wording comes mostly from third-party pages). **BVH conversions carry their own licenses**: one is CC BY 4.0, and a 4TU FBX conversion is **CC BY-NC 4.0 (not usable)**. | Raw mocap: noisy, a 2000s skeleton, and it needs cleanup. Good for crowd idles, gestures and "talking" loops after filtering and retargeting. |
| **Bandai Namco Research Motion Dataset** | The GitHub README says **CC BY-NC 4.0**, and press reported **CC BY-NC-ND 4.0** **[V-2nd]**. It is non-commercial either way. | **Do not use.** |
| **Kenney / KayKit animations** | CC0 | Small sets bundled with their characters |

**About "CC0 mocap":** truly CC0 raw mocap libraries are rare. Quaternius' keyframed libraries are the dependable CC0 option. Any mocap pack described as "free" should be checked for NC clauses before import.

### 4.3 Retargeting

- **In Godot 4 (preferred at import):** select the `Skeleton3D` in the import dialog, create a **BoneMap** with **SkeletonProfileHumanoid** (it auto-maps common English bone names), and enable **Overwrite Axis** so all rests match the reference T-pose ("the most important option for sharing animations"). **Normalize Position Tracks** scales root motion by hips height (`motion_scale`) to reduce foot sliding across body sizes. Use **Remove Tracks** options for shareable `AnimationLibrary` resources. The reference pose is a T-pose facing +Z, Y-up. **[V]** https://docs.godotengine.org/en/stable/tutorials/assets_pipeline/retargeting_3d_skeletons.html
- **Workflow:** keep a single `anim_library_humanoid.res` made from UAL clips and any extras. Every character scene uses the same profile, so all clips play on all characters, including future cities' NPCs.
- **In Blender (for cleanup or baking):** retarget with a script using Copy Rotation constraints from the source to the target armature, then bake the action. Rokoko's free Blender retargeting add-on also exists **[U]**. Root motion: extract it in Blender or let the Godot import handle it, and pick one approach.

### 4.4 Crowd variety (needed for "blend into the crowd" spy gameplay)

- **Modular parts:** 2 bodies × 3 builds × 8 to 12 heads × tops (coats, suits, uniforms, overcoats) × bottoms × hats (fedora, ushanka, flat cap, fez-style for Istanbul-like) × accessories (briefcase, newspaper, umbrella).
- **Palette swaps:** clothing UVs sit on a small character palette strip. A per-instance shader parameter (`instance uniform`) offsets the palette row, so one mesh gives N colorways. The network sync for appearance is then a compact tuple of part IDs and palette indices.
- **District wardrobe weights**, for example more uniforms near the checkpoint and suits near the embassy.
- **Crowd LOD:** within about 25 m, full skeletons plus AnimationTree. At mid range, a simplified AnimationPlayer at a reduced update rate. In the far field, **vertex-animation textures (VAT)** baked in Blender, drawn with MultiMesh at almost no CPU cost **[U]** (Godot VAT is a community technique; prototype it). On tablets, cap active skinned NPCs at about 20 to 30.

### 4.5 Faces and lip-sync shortcuts

- **Stylized faces:** eyes, brows and mouth are **texture decals** (swappable atlas tiles) or a few shape keys. With no facial bones, expressions are texture swaps.
- **Lip-sync:** **Rhubarb Lip Sync** (MIT **[V-2nd]**) produces 6 basic mouth shapes (A to F) plus optional G, H and X from audio. Run it at build time on the baked TTS WAVs, then convert its cue file into Godot animation tracks that swap mouth tiles. A Godot 4.3 "Baked Lipsync" plugin (MIT) also exists. https://github.com/DanielSWolf/rhubarb-lip-sync , https://godotengine.org/asset-library/asset/3629
- **Biggest shortcut:** briefings are **voice over a dossier or slideshow, or a radio handler**, and NPC chatter is bark audio with no visible lips at distance. Faces animate only in a handful of close-up scenes.

---

## 5. Vehicles

### 5.1 Sources

- **Kenney Car Kit** (CC0, v3.0 on OpenGameArt **[V-2nd]**), **Quaternius LowPoly Cars** (CC0 **[V-2nd]**) and **KayKit City Builder Bits** cars (CC0). These are useful as proportion references and fallback filler, but they look modern or cartoony.
- **Recommended: a script-built "period car generator"** in Blender. It lofts a body from 3 to 4 profile curves (side, top, front), adds wheel arches, a greenhouse (cabin glass), bumpers, grille panels and lights from parametric parts. Archetypes: 1950s/60s small sedan, boxy 1970s saloon, two-stroke compact, limousine, delivery van, taxi, police car, military truck, motorcycle with sidecar, tram and city bus (Berlin/Vienna), ferry and dolmuş-style minibus (Istanbul-like). Use 8 to 10 archetypes with palette variants. Each car is about 2k to 4k triangles with a separate wheel mesh and opening doors on hero cars only.

### 5.2 Avoiding trademark and trade-dress trouble

- No badges, logos or brand names. Use invented makes in signage and UI (for example a fictional East-bloc maker and a fictional Western luxury brand).
- **Blend features** so no car copies a single real model's distinctive silhouette, grille or lamp arrangement. Famous shapes such as the Beetle, Trabant, Mini or Mercedes "Ponton" are recognizable trade dress, and several manufacturers actively license their cars to games **[U]**. Generic period cues (round headlamps, chrome bumpers, fins, two-tone paint, boxy saloons) are fine.
- Keep a short "vehicle design note" per model stating which generic period cues it uses.

### 5.3 Arcade vehicle physics in Godot

- **Built-in `VehicleBody3D`** is a raycast vehicle ("based on the raycast vehicle system commonly found in physics engines"). It is fine for a prototype and tunable, but it is known to be fiddly for arcade feel. https://docs.godotengine.org/en/stable/classes/class_vehiclebody3d.html
- **Recommended: a custom raycast car** on `RigidBody3D`. Use 4 `RayCast3D` or shape casts for suspension (spring and damper force at each contact), lateral grip force from the wheel's sideways velocity, drive force at the rear contacts, and arcade assists (downforce, yaw damping, auto-righting, a speed-sensitive steering curve, handbrake drift). Server-authoritative simulation with client prediction for multiplayer. Reference implementations: Dechode's **Godot-AdvancedVehicle** (MIT, more simulation-oriented, last updated 2022), "Godot Easy Vehicle Physics" (arcade assists, based on AdvancedVehicle; license **[U]**), and the KidsCanCode **sphere-car** recipe (the simplest arcade approach: a rolling sphere plus a visual body). https://github.com/Dechode/Godot-AdvancedVehicle , https://kidscancode.org/godot_recipes/4.x/3d/3d_sphere_car
- **Traffic AI** follows lanes generated from the road graph (section 2.2) with simple path following and kinematic movement. Physics are used only near players.

---

## 6. Audio

### 6.1 Sources and licenses

| Source | License | Use |
|---|---|---|
| **Kenney audio packs** (UI, impacts, interface, RPG…) | CC0 **[U]** for the specific packs; the site-wide CC0 statement is **[V]** | UI clicks and confirms, impacts, footsteps (basic) |
| **Freesound.org** | **Per sound:** CC0, CC-BY or CC-BY-NC. "If a sound has a non-commercial license, you may not use it if you make any money with your game." CC-BY needs a credit (title, author, URL, license). **[V-2nd]** | Ambience (city traffic, trams, harbor, bazaar crowds, rain), Foley, vehicle engines. **Filter to CC0** and log each ID in the ledger. |
| **Sonniss GDC Game Audio Bundles** (yearly, free) | Royalty-free, commercial use, no attribution required. **No AI/ML training**, and the sounds may not be resold or redistributed on their own. **Each year has its own license PDF.** **[V-2nd]** Store the PDF with the files. https://gamefromscratch.com/sonniss-27-5gb-sound-effect-giveaway-at-gdc-2024/ | High-quality vehicle, foley, weapons (gadgets), doors, ambiences. The best SFX quality available for free. |
| **Kevin MacLeod / incompetech** | CC BY 4.0, attribution required **[U]** | Temporary or period-flavored music if credited |
| **OpenGameArt music** | Mixed per track | CC0 only, ledger every track |
| **Original music (recommended long-term)** | Ours | Script-composed MIDI rendered through permissively licensed SoundFonts (check each SoundFont's license **[U]**), or commission a composer. Avoid AI-music services unless their terms grant clear commercial rights **[U]**. |

### 6.2 Footsteps and surfaces

Tag surface materials in the palette atlas or with collision layers (cobble, asphalt, wood, carpet, metal grate, puddle). Use 4 to 6 variations per surface, with random pitch and volume, triggered from animation markers on walk and run clips. Also give "sneak" variants a quieter, softer set. Noise level is a gameplay value, because guards hear footsteps.

### 6.3 Voiced briefings with local TTS

- **Kokoro-82M** is **Apache-2.0** on its official Hugging Face card, "trained exclusively on permissive or non-copyrighted audio data", with 50+ voicepacks under the same license. Its phonemizer dependency **espeak-ng is GPLv3**. **Run it offline at build time and ship only the baked WAV/OGG files** so no GPL code ships. **[V-2nd]** https://huggingface.co/hexgrad/Kokoro-82M .
- **Piper:** the engine is GPL-3 and **voices are licensed individually, many non-commercial** **[V-2nd]**. Use only voices whose model card allows commercial use.
- **Accent and character:** add radio EQ, tape hiss or a "numbers-station" treatment in post (a Godot `AudioEffect` chain or ffmpeg at bake time). This hides TTS artifacts and fits the genre.
- **Script:** briefings live as text in data files, and a bake script regenerates audio whenever the text changes.

### 6.4 Adaptive music basics

Godot 4.3 added **AudioStreamInteractive** (clips plus a transition table: immediate, end-of-clip or beat-synced, with fades), **AudioStreamSynchronized** (layers in sync with per-layer volume) and **AudioStreamPlaylist**. The design is described as similar to Wwise/FMOD/Elias, and nesting Synchronized inside Interactive gives vertical layering plus horizontal state changes. **[V]** https://godotengine.org/releases/4.3/
- **States per city:** `explore`, `suspicion` (adds a percussion layer), `pursuit` (an immediate cut), `combat`, `stealth_success`, and `safehouse` (lounge).
- **Layers:** bass and pad, percussion, a melodic "spy" motif (surf guitar, cimbalom or zither for the Vienna-like city, saz/oud-like timbre for the Istanbul-like city), and a stinger layer.
- Use 0.5 to 1 s crossfades and beat-quantized transitions. The guides recommend authoring the `.tres` resources in the inspector because the GDScript construction API is limited.

---

## 7. UI/UX craft for an espionage game

### 7.1 Visual language (described, not copied)

Spy fiction's graphic shorthand, translated into original UI:
- **1960s title-sequence modernism:** big flat color fields, bold sans-serif or condensed type, silhouettes, circles and iris shapes, hard cuts. Use it for the menus and mission-start cards.
- **Bureaucratic documents:** typewriter text, rubber stamps (CLASSIFIED / VERIFIED / BURNED), paperclips, carbon-copy blue, redaction bars, file tabs, index cards. Use it for dossiers and the mission log.
- **Analog tech:** CRT green and amber, oscilloscope lines, reel-to-reel counters, rotary-dial and teletype motifs. Use it for hacking, comms and gadget readouts.
- **Map-room maps:** muted printed map colors, grease-pencil annotations, pins and string. Use it for the full map and minimap styling.

Make a per-city accent (Berlin-like: stencil and red; Vienna-like: gilt serif; Istanbul-like: tile-pattern borders) on top of a shared base system.

### 7.2 Fonts (OFL/Apache, freely embeddable **[U]**: confirm on Google Fonts before use)

- **Headers:** Oswald, Bebas Neue or Barlow Condensed (condensed sans for title cards)
- **Body/UI:** IBM Plex Sans or Inter (very readable on tablets)
- **Typewriter/dossier:** Courier Prime or Special Elite
- **Terminal:** IBM Plex Mono or Space Mono
Avoid any font tied to a real franchise's logo look.

### 7.3 Key screens and widgets

- **Minimap:** an orthographic render of the road graph and building footprints, generated as **vector or pre-rendered tiles from the same data**, not a live camera. That makes it cheap on tablets. Use a north-up option, district tint, objective pins and guard vision cones (when spotted or tagged), plus a "noise ring" showing how loud the player is.
- **Mission briefing:** a slideshow dossier. Photo cards are in-engine renders of NPCs and locations captured by script, with typewriter text revealing in sync with the baked voice, then an animated map with route lines. The player can skip, replay or review.
- **Gadget wheel:** radial selection with 6 to 8 slots, slow-motion while open (single-player) or no slow-motion in multiplayer. Each slot has an icon, charges and cooldown arc. Touch: press-hold-drag. Gamepad: stick. PC: hold key plus mouse.
- **Dossier menus:** a file-folder metaphor (tabs: Agent, Gadgets, Contacts, Intel, Cities). Intel items "stamp" in when found. A contacts web uses pin-and-string links.
- **Detection HUD:** an eye or suspicion meter per guard over their head, a screen-edge pulse for unseen watchers, and cover and disguise status.
- **Touch-first design:** 48 dp minimum hit targets, thumb-zone controls, and a large-text option. The same UI scales to PC via Godot `Control` anchors and themes.
- **Icon production:** icons are drawn as SVG by script (shapes and paths) in one stroke weight. Godot imports SVG natively, so icons are crisp at any size.

---

## 8. Recommended pipeline and content budget

### 8.1 Pipeline (all scripted, versioned, reproducible)

```
openspygate/
  art/
    palette/            palette_atlas.png (+ per-city LUTs), palette.json (swatch names -> UV)
    blender/
      lib/              shared bmesh helpers, bevel/AO, LOD, export, ledger writer
      kits/<city>/      facade modules, roofs, props   (python → .blend → .glb)
      gen/              building_gen.py, road_gen.py, car_gen.py, char_gen.py, interior_gen.py
      review/           turntable + "street-level" renders to PNG for every asset
    third_party/        raw CC0 downloads (never edited), each with LICENSE + source.txt
  assets/LICENSES.csv   one row per third-party file: path, source URL, author, license, fetched, sha256
  godot/
    import/             EditorScenePostImport scripts: material → palette shader, -col collisions, LOD, occluders
    world/<city>/       generated .tscn chunks (streamed), landmarks, interiors
```

1. **Blender headless:** `blender -b -P art/blender/gen/building_gen.py -- --city berlin --seed 42`. Every generator is deterministic from (city, seed, data file), so server and clients can rebuild identical content.
2. **Export as glTF 2.0** (`.glb`) with naming conventions: `-col` for collision, `_LOD1` and so on, plus empties as markers for doors, sit spots, NPC spawns and footstep surfaces.
3. **Godot import scripts** assign the shared palette shader, build collision, set `visibility_range`, and pack props into MultiMeshes.
4. **Review gate (anti-placeholder):** every asset produces a turntable PNG and an in-engine street-level screenshot. A contact sheet goes to the owner. Nothing enters a playable build unless it has been viewed next to its neighbors in context. The playable build starts with real (if simple) art.
5. **Perf gate:** an automated fly-through on PC and on a tablet (adb) logs fps, draw calls and memory per district.

### 8.2 Content budget for the first playable city (one Berlin-like district, about 600 × 600 m)

| Category | Count | Notes |
|---|---|---|
| Facade/roof/corner modules | 50 to 70 | Wall bays ×12, windows ×10, doors ×6, shopfronts ×6, corners ×4, cornices ×6, roofs ×6, balconies ×4, misc |
| Building archetypes | 8 to 10 | Tenement, prefab slab, embassy villa, warehouse, rail viaduct, café row, office block, guardhouse |
| Generated building instances | 120 to 250 | From footprints, with deterministic variation |
| Landmarks (bespoke) | 3 | Checkpoint complex, TV-tower-style mast (original design), grand railway station |
| Road kit pieces | 12 to 16 | Plus generated straights and curbs; tram tracks; bridge; plaza; stairs |
| Street props | 60 to 80 | Lampposts ×3, benches ×2, bins ×2, kiosks ×2, phone booth, mailbox, ad column, barriers ×4, sign blanks ×8, trees ×4, crates/barrels, scaffold, café furniture, bicycles |
| Enterable interiors | 4 to 6 | Safehouse, café/bar, embassy lobby + office, warehouse, apartment template, tunnel |
| Interior kit pieces | 40 to 60 | Walls/doors/stairs + furniture + spy props (typewriter, radio set, safe, filing cabinet, camera, phone) |
| Character base bodies | 2 (+1 heavy build) | Shared skeleton |
| Heads / hair / hats | 10 / 6 / 6 | Texture-decal faces |
| Clothing parts | 20 to 30 | Including 3 uniforms |
| Visible NPC variants | 40+ | Through combinations and palette swaps |
| Player agent looks | 4 | Plus disguise outfits from NPC uniforms |
| Vehicles | 8 to 10 archetypes | Small sedan, saloon, compact, limo, van, taxi, police, military truck, tram, motorcycle |
| Animations | 60 to 80 | Locomotion (idle, walk, jog, sprint, crouch, 8-direction strafe), cover in/out/peek, climb/vault (UAL2 parkour), door open/locked/lockpick, use terminal/phone, photograph, pickup/drop/hand-off, sit/lean/read newspaper, takedown/knockout/fall/getup, carry body, vehicle enter/exit/drive/ride, crowd idles and talk loops ×6, emotes ×5 |
| SFX | 150 to 200 | Footsteps (6 surfaces × 2 modes × 5), doors, gadgets, vehicles (4 engine loops), UI (20), impacts |
| Ambience beds | 6 to 8 | Per district plus interiors, day and night |
| Music | 1 adaptive set | 5 to 6 states, 4 layers |
| Voice lines | About 3 briefings + 100 barks | Baked TTS |
| UI screens | 10 to 12 | Title, main menu, lobby, briefing, HUD, minimap/map, gadget wheel, dossier, pause/settings, debrief, credits/licenses |

Later cities reuse **about 60%**: skeleton, animations, interior furniture, generic props, vehicles (re-skinned), UI and audio systems. Each new city then needs a new facade kit, landmarks, a palette and LUT, a wardrobe, ambience and a music motif.

### 8.3 Order of work

1. **Art bible and "golden block."** Lock the palette atlas, toon shader, outline, fog and LUT. Build **one street corner** at final quality (2 buildings from the generator, 10 props, 1 car, 1 NPC) and test it on the 1660 **and** a tablet. Show it to the owner and get sign-off on the style before scaling. This protects against the costly late-restyle failure.
2. **Character base and animation core.** Base body plus the UAL retarget into one `AnimationLibrary`. Third-person controller with real art from the first day.
3. **Facade kit and building generator** for the Berlin-like city. Footprint data comes from a fictional road graph.
4. **Road network:** road meshes, nav, traffic lanes and minimap from one graph.
5. **District dressing:** props, trees, rule-based placement, lighting pass, day/night.
6. **Vehicles:** car generator, raycast physics, traffic.
7. **Landmarks** (3).
8. **Interiors:** kit plus safehouse and 3 mission interiors.
9. **Crowd system:** modular parts, palette swaps, LOD/VAT, district wardrobes.
10. **Audio:** footsteps, ambience, SFX import from Sonniss/Freesound CC0 with ledger, adaptive music, TTS briefings.
11. **UI:** HUD, minimap, gadget wheel, briefing, dossier, credits and licenses screen.
12. **Perf and polish pass** on tablet, then repeat steps 3 to 9 for city 2 using the shared systems.

### 8.4 Risks and mitigations

| Risk | Mitigation |
|---|---|
| Generated city looks repetitive | Archetype mix per district, landmark anchors, hand-placed "story spots", variation seeds, palette noise per facade |
| Kit assets clash with the original style | Mandatory restyle script (palette remap, bevel/AO) plus the review gate |
| Mixamo terms conflict with an open repo or mods | Use CC0 UAL first. Keep any Mixamo clips out of public repos and mod kits. |
| License drift (CC-BY or NC files slip in) | `LICENSES.csv` plus a CI check that every file in `third_party/` has a ledger row and an allow-listed license |
| Tablet performance | Mobile renderer, one shared material, MultiMesh, VAT crowds, blob shadows, profile every milestone with adb |
| Scope (a solo spy game took 5.5 years) | One district first; reuse systems across cities; procedural over handmade wherever the player moves fast |

---

## 9. Unverified items to check before relying on them

- Current official Mixamo FAQ (helpx.adobe.com returned 403). The terms quoted come from a 2022 Adobe community repost.
- Exact contents of the Kenney, KayKit and Quaternius character, city and audio packs beyond those cited.
- Buildify license text. Godot road-generator add-on licenses.
- CMU mocap terms on mocap.cs.cmu.edu itself.
- Per-year Sonniss license PDF, and each Freesound file's license at download time.
- Kevin MacLeod license, font licenses, SoundFont licenses.
- Overpass API and OSM tile usage policies; architecture and freedom-of-panorama rules per country.
- VAT crowds and the interior-mapping shader on the Godot Mobile and Compatibility renderers (prototype required).
- Team size and rendering details for Bomb Rush Cyberfunk, Townscaper and Tiny Glade.

## Sources

- Kenney license/support: https://kenney.nl/support
- Quaternius UAL 1/2: https://quaternius.com/packs/universalanimationlibrary.html , https://quaternius.com/packs/universalanimationlibrary2.html , https://quaternius.itch.io/universal-animation-library
- Quaternius LowPoly Cars: https://opengameart.org/content/lowpoly-cars ; Kenney Car Kit: https://opengameart.org/content/car-kit
- KayKit City Builder Bits: https://kaylousberg.itch.io/city-builder-bits , https://www.godotengine.org/asset-library/asset/2123
- Poly Haven license and API: https://polyhaven.com/license , https://polyhaven.com/our-api , https://blog.polyhaven.com/dev-log-20/
- ambientCG license: https://docs.ambientcg.com/license
- Mixamo FAQ repost: https://community.adobe.com/t5/mixamo-discussions/mixamo-faq-licensing-royalties-ownership-eula-and-tos/td-p/13234775
- CMU mocap: http://mocap.cs.cmu.edu , https://paperswithcode.com/dataset/cmu-motion-capture
- Bandai Namco dataset: https://github.com/BandaiNamcoResearchInc/Bandai-Namco-Research-Motiondataset/blob/master/README.md , https://automaton-media.com/en/news/20220430-12213/
- Godot retargeting: https://docs.godotengine.org/en/stable/tutorials/assets_pipeline/retargeting_3d_skeletons.html
- Godot renderers: https://docs.godotengine.org/en/stable/tutorials/rendering/renderers.html
- Godot 4.3 interactive audio: https://godotengine.org/releases/4.3/
- Godot VehicleBody3D: https://docs.godotengine.org/en/stable/classes/class_vehiclebody3d.html ; AdvancedVehicle: https://github.com/Dechode/Godot-AdvancedVehicle ; sphere car: https://kidscancode.org/godot_recipes/4.x/3d/3d_sphere_car
- OSM/ODbL: https://osmfoundation.org/wiki/Licence_and_Legal_FAQ , https://osmfoundation.org/wiki/Attribution , https://wiki.openstreetmap.org/wiki/Open_Data_License/Community_Guidelines/Attribution_For_Different_Media_Types
- Blosm: https://github.com/vvoovv/blosm , https://wiki.openstreetmap.org/wiki/Blender-osm
- Buildify: https://www.cgchannel.com/2022/07/download-free-blender-3d-building-generator-buildify/
- Freesound licensing (community): https://freesound.org/forum/legal-help-and-attribution-questions/38292
- Sonniss GDC bundle coverage: https://gamefromscratch.com/sonniss-27-5gb-sound-effect-giveaway-at-gdc-2024/
- Kokoro-82M: https://huggingface.co/hexgrad/Kokoro-82M ; Piper voices (secondary): https://tts.ai/voices/piper/
- Rhubarb Lip Sync: https://github.com/DanielSWolf/rhubarb-lip-sync ; Baked Lipsync (Godot): https://godotengine.org/asset-library/asset/3629
- Sable: https://www.gamedeveloper.com/marketing/how-shedworks-refined-the-art-of-sable-in-pursuit-of-readability , https://mcvuk.com/business-news/when-we-made-how-shedworks-went-from-a-north-london-shed-to-the-stunning-dunes-of-sable/ , https://unity.com/en/resources/shedworks-sable-modular-design-approach
- Dread Delusion: https://rpgsite.net/interview/16267-dread-delusion-creative-director-speaks-on-how-flying-islands-helped-development-why-ps1-games-are-timeless
- Agent 64: https://www.timeextension.com/news/2026/07/agent-64-is-the-perfect-dark-and-goldeneye-007-successor-weve-been-waiting-for-and-it-arrives-next-month
- Bomb Rush Cyberfunk: https://en.wikipedia.org/wiki/Bomb_Rush_Cyberfunk
