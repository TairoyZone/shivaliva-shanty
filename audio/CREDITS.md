# Audio credits & licenses

Shivaliva Shanty's sound is a mix of:

1. **Procedural placeholders** synthesised in-engine (`tools/sfx_gen.gd`, `tools/music_gen.gd`) — original
   to this project, no third-party license: `coin, clack, pop, whoosh, thunk, chime, buzz, click, toss`
   and the `overworld` ambient music bed.
2. **Borrowed library sounds** from Troy's owned GDQuest courses + their bundled third-party assets. Every
   borrowed file is listed below with its license so a **public build stays compliant**. **Keep this file
   with any public release** (and surface the CC-BY credit on an in-game Credits screen or the itch.io page).

## Borrowed SFX (`audio/sfx/`)

| Files | Origin | License | Required credit |
|---|---|---|---|
| `voice_talk.ogg`, `voice_talk2.ogg` | "Talking Synthesizer" by **tcarisland** (OpenGameArt) — via GDQuest *Learn 2D Gamedev* | **CC-BY-SA 4.0** | "Talking Synthesizer" by tcarisland (CC-BY-SA 4.0) |
| `type_key.wav` | "Keyboard soundpack 1" by **unicaegames** (OpenGameArt) — via GDQuest *Learn 2D Gamedev* | **CC0** | none required (credit appreciated) |
| `pickup.wav`, `powerup.wav`, `hit.wav`, `bop.wav`, `hurt.wav`, `ko.wav`, `pain.wav`, `laser.wav` | **GDQuest** "Learn 2D Gamedev with Godot 4" | **CC-BY 4.0** | Additional assets CC-By 4.0 GDQuest (https://www.gdquest.com/) |
| `explosion.ogg` | **Kenney** (Sci-Fi Sounds / Digital Audio) — via GDQuest *Node Essentials* | **CC0** | none required (Kenney — https://kenney.nl — credit appreciated) |

## Borrowed music (`audio/music/`)

| File | Origin | License | Required credit |
|---|---|---|---|
| `title.ogg` | "Title Screen" by **Juhani Junkala** (5 Chiptunes / Action) — via GDQuest *Node Essentials* | **CC0** | none required (credit appreciated) |

## Notes
- The **Kenney + Junkala CC0** classifications are inferred from the well-known upstream packs (filenames
  match Kenney's audio packs and Junkala's chiptune set). **Verify against the upstream OpenGameArt/Kenney
  pages before a public release** if you want it airtight.
- **CC-BY-SA** (`voice_talk*`) only "shares alike" *adaptations of the sound itself* — using it unchanged
  as a game SFX needs attribution but does **not** change this game's license.
- **CC-BY** (GDQuest) just needs the credit line above somewhere visible.
- **ARR** in the GDQuest LICENSE files covers only their interactive tour/practice *code* — not these audio
  assets — so nothing borrowed here is restricted.
