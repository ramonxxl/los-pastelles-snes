# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project

"Los Pastelles: O Império do Pastel" is a pastry-shop management game for the Super Nintendo. It is written in 65816 assembly (ca65), and all of its assets (art, font, text, music) are generated from code by Node.js and Python scripts. The code, comments, game text and docs are in Brazilian Portuguese, so keep new identifiers and comments in Portuguese to match. `LEIAME.md` is the player-facing doc. It covers controls, content, secrets and how to burn a cartridge.

## Build

```
node build.js
```

This writes intermediate files to `gen/` (gitignored), assembles and links with cc65, fixes the header checksum and overwrites `LosPastelles.sfc` at the repo root. The ROM is committed (as a development build; official ROMs come from the GitHub releases). The build is deterministic: the same source and version produce the same bytes.

Requirements that are not in the repo (`tools/` is gitignored):
- cc65 (2.19). The build uses `tools/cc65/bin/ca65` and `ld65` if they exist; otherwise it runs `ca65`/`ld65` from `PATH` (for example after `apt install cc65`).
- Python with Pillow, used for `gerador/logo.py`, `gerador/icones.py` and `gerador/checa_largura.py`.
- The Python interpreter comes from the `PYTHON` env var. If it isn't set, the build uses `python` on Windows and `python3` everywhere else. If Python fails, logo and icons fall back to existing `gen/` files.
- `gerador/checa_largura.py` (the 65816 width checker) runs on every build. If it finds a problem, the build fails. If Python is missing, it only warns, except in CI (`CI` env var set), where it fails too.
- `gerador/icones.py` downloads Twemoji PNGs from jsDelivr the first time. They are cached in `arte_fonte/emoji/`, which is committed.

Other generators, run on demand:
- `node gerador/preview.js` writes art previews to `gen/preview/`.
- `node gerador/exporta_arte.js` exports transparent character PNGs to `cartucho/arte/`.
- `python gerador/cartucho.py` regenerates the cartridge label and the manual PDF in `cartucho/`.
- `gerador/trailer*.py` builds the trailer.
- `cartucho.py`, `capa.py` and `trailer.py` load TrueType fonts (Impact, Arial…) from the folder in the `FONTES` env var, defaulting to `C:/Windows/Fonts/`. On Linux, point it at a folder that has those fonts.

## Tests

There is no unit test suite. Tests are Lua scripts that run inside **Mesen 2** in test-runner mode, from a separate install in `teste/mesen/` so they don't touch the player's saves:

```
teste/mesen/Mesen.exe --testrunner LosPastelles.sfc teste/bot.lua
```

`teste/ci.lua` is the main pass/fail test that CI runs (`teste/tutorial.lua`, described under "Guided tutorial", runs right after it):
- The robot plays a new game, and the script checks these milestones in order: day 1 starts, the tutorial is completed, the day ends (results), the shop opens, and day 2 starts.
- It also checks for a valid save in SRAM and allows at most 4 lag frames during gameplay. Scene loads and open boxes don't count, since they pause the loop on purpose.
- It exits with code 0 if everything passed and 1 if anything failed. A summary goes to `teste/ci.txt`, and the robot's own log goes to `teste/bot.txt`.
- Every test assumes a cartridge with no saves: delete `teste/mesen/Saves` before each run (CI does that). A leftover save makes the game load a game where the tutorial is already done.
- It takes about 55 s (about 9,700 frames). Run it locally (Linux) with:

```
LD_PRELOAD=/usr/lib/x86_64-linux-gnu/libstdc++.so.6 teste/mesen/Mesen --testrunner LosPastelles.sfc teste/ci.lua
```

- `teste/bot.lua` is a robot that plays the game by reading RAM. It resolves variable addresses by name from `gen/labels.txt` (ld65 `-Ln` output), so renaming a variable in `vars.inc` can break the bot. Its behavior is configured with `botcfg*.lua` (choose one by setting the `BOTCFG` global).
- The other scripts are focused probes: `lag.lua` (frame lag), `tut.lua` (tutorial), `mg.lua` (minigame), `fotos.lua`/`ui_fotos.lua` (screenshots), `trace.lua`, `ram.lua`, and `run.lua` (input script plus `cenario.lua`).
- Each Lua script finds `teste/` from its own path via `debug.getinfo`. If Mesen doesn't expose `debug`, it falls back to the relative path `teste/`, so launch Mesen from the repo root. Other paths are built from that directory (`dir .. "../gen/labels.txt"`).
- Outputs (`teste/*.png`, `teste/*.txt`) are gitignored.
- Running Mesen 2 (Linux x64 build 2.1.1) here:
  - It crashes with `std::bad_cast` (a libstdc++ conflict inside MesenCore). Work around it with `LD_PRELOAD=/usr/lib/x86_64-linux-gnu/libstdc++.so.6 teste/mesen/Mesen --testrunner ...`.
  - A `settings.json` next to the binary puts it in portable mode, so configs and saves stay in `teste/mesen/`.
  - That file must have `Debug.ScriptWindow.AllowIoOsAccess: true`, or the scripts can't use `io` and can't save screenshots.
  - It must also have `Snes.Port1.Type: "SnesController"`, or `emu.setInput` is ignored.
  - Press a button for a few polls in a row so the game sees it.
  - It works without a display. The minimal `settings.json` that CI writes is enough: `{"Snes":{"Port1":{"Type":"SnesController"}},"Debug":{"ScriptWindow":{"AllowIoOsAccess":true}}}`.

## Versioning and releases

The project uses semantic versioning (`MAJOR.MINOR.PATCH`), starting at `0.0.1`. **A new version only happens when someone bumps `VERSION`.** A commit without that bump (docs, CI, refactoring…) is tested and built, but doesn't create a version or a release.

`gerador/versao.js` reads two sources:
- `VERSION`: the current version of the game.
- git tags `vX.Y.Z`: the versions already released, created by CI.

It has two commands:
- `node gerador/versao.js --lancar` prints the version to release now: the one in `VERSION`, if it doesn't have a tag yet. Otherwise it prints nothing. If `VERSION` is below the latest tag, it's an error.
- `node gerador/versao.js` prints the version of this build:
  - `GAME_VERSION`, if set (CI sets it, and it's validated as semver);
  - otherwise `git describe`, giving the latest tag plus the commits since it (e.g. `0.0.2-dev.3+abc1234`; exactly `0.0.2` on the tagged commit);
  - with no git or no tags, `VERSION` plus `-dev`.

`build.js` only writes the version as text, as "VERSÃO …": in the credits card (`CARDS.CREDITOS`) and on the opening screen (`TXT_SP_VER`, centered on row 24 via `SP_VER_COL`). Nothing in the game logic, the save format or the ROM layout depends on it.
- `versaoNaTela` keeps only characters that have a glyph and caps the text at 19 characters. If it's too long, the `+metadata` part is dropped first.
- `gen/versao.txt` records the version of the last build.

**CI** (`.github/workflows/ci.yml`, on `ubuntu-24.04`):
- **Build job:**
  - installs cc65, Pillow and SDL2 via apt, with Mesen 2.1.1 cached, and clones the full history (for tags and `git describe`);
  - computes the version and compiles with `node build.js` (which includes the width checker);
  - runs `teste/ci.lua` headless;
  - uploads the ROM as an unzipped artifact (`archive: false`, `LosPastelles-<version>.sfc`, kept for 14 days).
- **Push to `main` with a new `VERSION`** (no tag yet): the build uses that version, and the `release` job (the only one with `contents: write`) creates the `v<version>` tag on the commit and publishes the release with the ROM.
- **Push to `main` without a `VERSION` change:** tests and an artifact with a `-dev` version, but no release.
- **Pull requests:** the version is `<VERSION>-pr.<number>+<sha>`. The PR's ROM is the artifact of the run, linked in the run summary. A new push cancels the PR's previous run.
- **Concurrency:** runs on `main` are queued, never in parallel.
- **Skipped changes:** changes only to `*.md`, `cartucho/`, `trailer/` or `.gitignore` don't run CI.

**How to release a new version:** bump `VERSION` in the commit/PR that should become the version, then push or merge to `main`. If the tests pass, the release comes out on its own.
- **PATCH** (fixes): `0.0.2` → `0.0.3`.
- **MINOR** (new features): `0.0.3` → `0.1.0`.
- **MAJOR** (big changes or incompatible saves): `0.9.0` → `1.0.0`.
- `VERSION` can never go below the latest tag; the build fails. To see what the next push would release: `git fetch --tags && node gerador/versao.js --lancar`.

## Architecture

### Asset pipeline (build.js → gen/ → src/)
`build.js` is the hub. It calls the `gerador/` modules and writes:
- Binary blobs (`*_tiles.bin`, `*_map.bin`, `*_pal.bin`, `spc.bin`, `font.bin`, `ui_*.bin`) that `src/main.s` pulls in with `.incbin`.
- `gen/assets.inc` holds generated constants: `SPR_*` sprite IDs, `FONT_*` glyph codes, `SONG_*`/`SFX_*` indices, `CARD_*` and `SPC_SIZE`.
- `gen/data.inc` holds compiled strings (`TXT_<key>`), the lookup tables `MissionTxt`/`ShopName`/`ShopDesc`/`TrophyTxt` (their **counts are hard-coded in build.js**: 15 missions, 19 shop items, 16 trophies), music tracks, the SFX/pitch/instrument tables and the UI tables.
- `gen/cards.inc` holds the story-card text, which lives in its own bank (BANK11).

The generator modules:
- `gerador/textos.js` defines every game string as `T` (key → text, uppercase, `\n` = new line) plus `CARDS`.
- `gerador/fonte.js` turns text into tile codes with `compile()`. A character without a glyph throws at build time, so any new accented or special character needs a glyph in `G` first.
- To show a controller button inside text, use the tokens `{A}` `{B}` `{X}` `{Y}` `{CIMA}` `{BAIXO}` `{ESQ}` `{DIR}` (never a bare letter):
  - `compile()` turns each token into a transparent glyph (codes `FONT_BTN0`…`FONT_BTN0+N_BTN-1`).
  - `PrintStr`/`TypeStep` record its position via `BtnReg` in `ui.s`.
  - Every frame, `BtnSprites` draws a colored 8×8 button sprite (`SPR_BTN8_*`, sprite palette 0) over each recorded position that still holds the glyph.
  - At most 12 buttons can be on screen at once.
- **Text layout in boxes (avoid broken glyphs and text past the box):**
  - Text is in 8×8 cells. A button sprite fills its whole cell, and its Y has to be exactly `row × 8`. Text (BG3) is drawn on top of sprites, so if the sprite is even 1 pixel higher or lower, the shadow of the letters on the next line covers the edge of the button. Never offset button sprites vertically.
  - In texts with buttons, put a blank line (`\n\n`) between paragraphs/items, as in `INTRO_B` and the tutorial (`TB_B*`, which is double-spaced). That gives vertical breathing room around the icons. Dense lines are fine only inside the same item.
  - Maximum widths, counting `{X}` as 1 character:
    - **Card body:** column 3, up to 26 characters per line and 17 lines (rows 8–24; the footer is on row 26).
    - **Tutorial box:** column 4, up to 25 characters and 6 rows.
  - `build.js` (`cabe`) fails the build if a card or `TB_B*` goes past those limits. Break the line by hand, aligning continuation lines with spaces as in the numbered lists.
  - The sprite limit per scanline (32 sprites / 34 8 px tiles) also matters. Buttons and the pill are in the last OAM slots and are the first to be dropped. That's why `TutSprites` hides game sprites that touch the tutorial balloon. Any new box drawn over gameplay needs the same care.
- Dialog-box footers (action hints such as `{A}: CONTINUAR`) are printed with `Footer` in `ui.s` (X = text, A = row; the boxes use row 26, which straddles the panel's bottom edge):
  - It centers the text and records it, and `PillSprites` draws a cream gradient "pill" behind it every frame, made of 16×16 sprites `SPR_PILULA_*` (sprite palette 1).
  - The pill disappears when the text in that position changes.
- Reserved OAM slots (`vars.inc`): 100–111 for buttons (`OAM_BTN`), 112–127 for the pill (`OAM_PILL`). `AddSprite` stops at `OAM_BTN`. Lower slot numbers draw in front, which keeps the buttons over the pill.
- `gerador/arte.js` and `gerador/gfx.js` contain all pixel art as code: scenes, sprites, palettes and 4bpp encoding. `shopScene(bairro, reforma)` gives 5 neighborhoods × 3 renovation stages.
- `gerador/audio.js` contains the SPC700 driver blob and the chiptune songs and SFX.
- `gerador/ui_tabs.js` builds the HDMA gradient and animation tables.
- `gerador/logo.py` converts whichever root-level PNG has "pastelles" in its filename into the 15-color title logo.

### ROM layout
`src/snes.cfg` maps LoROM SlowROM with 32 banks of 32 KB (1 MB). The header in `main.s` says 1 MB and 2 KB of battery SRAM. Banks 13 and up hold the recorded audio (`gen/sons.inc`, generated; currently up to bank 27).
- `src/main.s` is the single translation unit. It `.include`s `macros.inc`, `gen/assets.inc`, `vars.inc`, then `audio.s`, `voz.s`, `game.s`, `telas.s`, `extra.s`, `segredo.s` and `ui.s` (all in the `CODE` segment, bank 0), then the data. Graphics go in the `BANK1`–`BANK12` segments, roughly one scene group per bank. The banks are 32 KB, so watch for overflow when art grows.
- Register convention: **A is 8-bit, X/Y are 16-bit, DBR = $80, D = $0000**. Switch widths with the `A8`/`A16`/`I8`/`I16` macros so that the assembler's `.a8`/`.a16` tracking stays correct.
- `gerador/checa_largura.py` runs on every build and flags branches or jumps whose target label was assembled under a different accumulator width. Treat its "problemas: N>0" output as a real bug.

### Audio (SPC700) and recorded voices
- **The driver** (`DRIVER` in `gerador/audio.js`) is hand-assembled SPC700 code, using the small assembler `monta`. ca65 doesn't assemble SPC700. It's uploaded via IPL to `$0200`.
  - When it starts, it reads port 0 and only then signals "ready" (`$D5` on port 1). `ApuUpload` waits for that signal.
  - Port 0 changes on every command:
    - **Bit 7 = 1 (data):** 3 bytes (ports 1–3) go to write pointer A (`$02`, bit 6 = 0: music and the fixed-voice load) or B (`$06`, bit 6 = 1: speech), which advances 3. Data commands don't return status, which keeps them fast.
    - **Bit 7 = 0:** port 1 = DSP register and port 2 = value; port 1 = `$80`/`$81` sets pointer A/B to port 2/3. These commands return `ENDX` on port 1.
  - It always echoes port 0. Sending is pipelined: `APU_ESPERA` waits for the previous command's echo before writing to the ports. `ApuTrio`/`LOTE` don't wait for their own echo. `DspWrite` does.
- **SPC700 memory** (`ARAM` in `audio.js`):

  | Range | Contents |
  |---|---|
  | `$0200` | driver |
  | `$0300` | sample directory (SRCN 0–2 chiptune waves, 3 music ring, 4 sizzle, 5 speech ring, 6+ fixed voices; `build.js` checks the order) |
  | `$0400–$CFFF` | fixed voices and the sizzle |
  | `$D000–$DFFF` | echo (EDL = 2, 32 ms) |
  | `$E000–$E7FA` | speech ring (227 blocks) |
  | `$E800–$FFBA` | music ring (675 blocks) |

- **Recorded voices and music** (`gerador/sons.js`, `src/voz.s`): the MP3s in `sounds/` are converted to BRR by `gerador/brr.js`. The decoder used to model the DSP is checked against the samples that Mesen's DSP decodes. The table `VOZES` sets file, type, priority and the cooldown before the same voice can repeat.
  - **Fixed voices:** the frequent ones (`tipo: 'fixa'`), 8 voices plus the sizzle. Their rate is the highest that fits, currently 9 kHz. They're loaded into the SPC700 in idle time while the splash screen runs. `VozCargaFim` finishes the load immediately if needed.
  - **Speech streams:** the rare voices, at 10 kHz, played on voice 7 through ring B.
  - **The recorded song** (`VOZ_TEMA`, 10 kHz, looping): plays on voice 1 through ring A, on the title (with the narration on top) and during the day (in place of the old day chiptunes). It starts with `MusToca`. `MusPara` stops it, and `PlaySong`/`StopMusic` call `MusPara` too.
  - **Sending data:** `Bomba` runs inside `WaitFrame`, in each frame's idle time, and stops as soon as the NMI arrives. It sends in batches (`LOTE`, at most `LOTE_MAX` = 72 bytes) straight from ROM, prefetching the next 3 bytes while the SPC700 writes the previous ones.
  - **Priority and cushion:** speech goes first. If it sent a batch, the music waits for the next loop. The music has a 0.5 s cushion so it can get through a rare speech playing on top of it; speech keeps 0.15 s.
  - **Resync:** once per frame, `VozQuadro`/`MusQuadro` use the `ENDX` value read at the start of `AudioUpdate` (`apu_endx`). When a voice wraps around its ring, the level becomes the write position minus one frame, because the `ENDX` notice arrives up to 1 frame late. If the write position is beyond ¾ of the ring, the write pointer hasn't wrapped yet, so the level is 0.
  - **Budget:** the day leaves about 170–180 bytes per frame of idle time. Music and speech at 10 kHz use ~94 + 94. Above that rate (or with long speech streams playing alongside the music), the rings run empty in the busy frames. Measure before raising the rates.
- **Cache:** the converted BRR is committed in `arte_fonte/brr/`. `indice.json` records the MP3 hash, the rate and the encoder version (`BRR.VERSAO`). Building doesn't need ffmpeg; it's only needed when an MP3, a rate or the encoder changes.
- **To add a voice:**
  - Put the MP3 in `sounds/` and add it to `VOZES`, then call `VozToca` with `VOZ_<ID>` on the event.
  - `fixa` is only for short, frequent voices: the fixed voices share ~50 KB, and adding one lowers everyone's rate.
  - A long `stream` that plays often during the day competes with the music.

### Title and options screens
- **Title** (`TitleInit`/`TitleMenu`/`TitleSprites` in `telas.s`):
  - `gerador/logo.py` builds the BG1 image: the logo shrunk at the top, plus the menu card at the bottom (`CARTAO`, same look as the boxes). The background outside the emblem and the card is transparent, found by flood fill from the edge.
  - Behind it, `UI_TITULO` shows the animated checker (BG2) with no gradient.
  - The items (`TIT_LIN`/`TIT_COL`) each have an emoji icon (`IconeSprite`, `ICO_*` in `ui.s`). The selected one is red, with a pill behind it (`PilulaLiga`) and a bobbing icon.
  - The recorded song and the narration start when the fixed-voice load finishes (`tema_pend`), so skipping the splash screen doesn't freeze the title.
- **Options** (`extra.s`):
  - One row per item (`OPT_*`): icon, name, value between the d-pad buttons, a pulsing highlight band, an explanation of the selected item (`OptAjuda`) and a pill footer.
  - Items: difficulty, music (turns the recorded song on or off), speech (`opt_falas`: when off, `VozToca` plays nothing) and back.
  - Saved in SRAM at `OPT_SRAM`: `'O','P'`, difficulty, music, and speech as `$A0|value`. An old save without that byte defaults to speech on.
- **Icons:** the emoji sheet (`gerador/icones.py`) is the shop's (items 0–19) plus the menus' (20–23); it holds 24 icons. Title, options and shop load `IconGfx` into OBJ tiles 0–95. The screens that use those tiles reload the sprites: `DayInit`, and `IntroInit` (the street).

### Demo mode (attract mode, `src/demo.s`)
- **Start:** 30 s with no buttons on the title (`DemoTitulo`, `DEMO_OCIOSO`) starts a demo. `DemoSorteia` rolls a stage in the RAM copy of the save: level 1–24 (which sets the flavors), day, baskets, counter, renovation, neighborhood and extras.
- **Off during the demo:** tutorial, broken baskets and app deliveries.
- **The day:** starts at `DEMO_HORA` (14h, about 1 minute).
- **The CPU playing:** `DemoControle` runs right after `ReadPad` in the main loop. On the day screen, every 4 frames it replaces `pad_new` with the button chosen by `DemoIA` (the same logic as `teste/bot.lua`), and every so often shows `TXT_DEMO` on the HUD.
- **End:** any real button, or the end of the day (when the next state would be the results), returns to the title.
- **Saving:** nothing is saved, because the day never writes SRAM and results/shop/tutorial are skipped.
- **Banks:** `DemoSorteia` (with its own `DemoRand`) and `DemoIA` live in bank 28, called with `JSL` and returning with `RTL`, because bank 0 is full. They can only call routines in the same bank. RAM and the bank-0 tables are reachable through the DBR (`$80`).

### Emoji sprites
`gerador/emoji_sprites.py` (Twemoji, cached in `arte_fonte/emoji/`) turns sprites that have a perfect emoji into 16×16 with the shop icons' outline: flavors 🥩 🧀 🍗 🥓, lock, anger, heart, coin, X, star, phone, computer, scooter, sparkle and fire.
- **Colors:** they're quantized to the sprite's fixed palette (0 or 1), because during the day palettes 3–7 belong to the customers.
- **Fallback:** sprites without a good emoji (calabresa, catupiry, soda can, order bubble, smoke, mascot, pastéis, store) keep the hand-drawn art from `arte.js`.
- **Build:** `build.js` writes `gen/spal.json` and passes the result (`gen/emoji_spr.json`) to `buildSprites(emojis)`.

### Menu background (BG2)
Menu screens (`LoadMenuScene`) show a 2-layer background:
- BG1 holds the panel. Outside the panel it is transparent.
- BG2 holds the checker pattern (`menuChecker` in `arte.js`): 3 tiles at tile index 1021 (`MENU_CHK_VRAM`), a map at `VRAM_BG2MAP` = $5800, and BG palette 3 (`ChkPal`, loaded by `LoadXadrez` callers). It doesn't use palette 2 because that one belongs to the scene/logo.

`UiNmi` scrolls BG2 1 px to the right every 2 frames and turns BG2 on in `TM` while `ui_mode` is `UI_PANEL` (boxes) or `UI_TITULO` (title). Every other scene uses BG1 only.

### Guided tutorial (first order of day 1)
While `tut_step != $FF` (tutorial active; see `TUT_BIT` in `s_tflags` for "already completed"), the player can't get the first order wrong:
- **Customer:** `DaySpawn` sends a single customer, who orders meat (no double order, combo, tourist or mystery customer). `CustUpdate` doesn't drop their patience.
- **Clock:** `DayClock` doesn't run. The hour doesn't advance, no basket breaks and the shop doesn't close.
- **Input:** `DayInput` hands off to `TutInput`, which places the cursor itself (on the meat bin, then the basket with the pastel, then the customer via `AutoTarget`). Directions, B, X and Y are ignored, and A only works at the right moment: with a customer in the shop, or with the pastel at least at perfect doneness (≥160).
- **Minigame:** `MiniGame` doesn't count time, and a wrong button only makes the error sound (the pastel doesn't open).
- **Fryer:** `FryUpdate` caps the progress at `fry_lim`. During the tutorial that's `TUT_PONTO` (185, perfect doneness), so the pastel never burns.

Everything goes back to normal after the first delivery (`tut_step = $FF`). `teste/tutorial.lua` checks all of this with a player who tries to get everything wrong, and runs in CI after `teste/ci.lua`.

### Tutorial balloon (day 1)
`TutBox` (in `game.s`) sets `dim_on = 2`, and the NMI then calls `TutNmi` (in `ui.s`):
- It turns on BG2, which holds the cream balloon (`tutBalloon` in `arte.js`). `LoadShopScene` loads its tiles (from tile 960), map and palette 3. Box size and position (`TUT_X0`…) come from `TUT_BOX` in `arte.js`.
- Window 1 hides BG1 inside the balloon. HDMA channel 6 limits the window to the balloon's rows.
- HDMA channel 7 changes `CGADSUB` per line, so BG3 (the HUD) is darkened outside the balloon.
- `TutSprites` lowers game sprites to priority 2 so they go behind the balloon (BG2 with high priority).

### Game loop and state machine
`MainLoop` in `main.s` dispatches through the `StateInit`/`StateUpdate` jump tables (`src/telas.s`), indexed by `state`. The `ST_*` constants are defined at the top of `src/game.s` (title, intro, card, preday, day, results, shop, map, options, choose, slots, splash, trophies, secret). To change screens, write to `next_state`. The main loop runs the new state's Init once, then calls Update every frame, followed by `UiUpdate`, `AudioUpdate`, `WaitFrame` and `ReadPad`. NMI uploads OAM, palettes and VRAM from RAM buffers.
- `game.s` is the in-day gameplay: frying, customers, minigame, deliveries. `telas.s` holds the screens and menus, `extra.s` additional features, `segredo.s` the secret cheat menu, `ui.s` the HDMA panels and icons, and `audio.s` the APU upload and the music and SFX sequencer.
- `src/vars.inc` declares the RAM variables. The block between `save_start` and `save_end` is copied to SRAM as one unit (3 save slots) and **must stay contiguous**. Adding, removing or reordering fields there changes the save format.

### Other folders
`cartucho/` holds the label, manual, photos and exported art for the physical cartridge. `trailer/` holds the final trailer MP4. `roteiro_*.md` is the game's design and story script.
