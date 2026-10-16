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

- `teste/bot.lua` is a robot that plays the game by reading RAM. It resolves variable addresses by name from `gen/labels.txt` (ld65 `-Ln` output), so renaming a variable in `vars.inc` can break the bot. Its behavior is configured with `botcfg*.lua` (choose one by setting the `BOTCFG` global). A probe that drives the input itself sets the global `BOT_PARADO` so the bot stops playing the day, or `BOT_DESLIGADO` so the bot stops sending input on every screen.
- The other scripts are focused probes: `lag.lua` (frame lag), `tut.lua` (tutorial), `mao.lua` (screenshots of the held-item hand next to the cursor), `mapa.lua` (expansion map with 0, some and all units, plus the store choice screen), `loja.lua` (one screenshot per shop tab), `pausa.lua` (pause menu screenshots; exits 1 if B doesn't resume), `senha.lua`/`sem_sram.lua`/`senha_secreto.lua` (password round trip with and without SRAM, and the secret code on the password screen; see "Password"), `montagem.lua` (big pastel animation: every keyframe, the wrong-button case and the vblank check), `lixeira.lua` (trash animation: wrong button, timeout and none in the tutorial), `hud.lua` (day HUD screenshots in several situations), `ajuda.lua` (every help page; exits 1 if the navigation fails), `loja_cenario.lua` (the day scene in all 5 neighborhoods × 3 renovations), `resultado.lua`/`resultado_cheio.lua` (screenshots of both end-of-day pages; the second forces RAM values so every line shows), `mg.lua` (minigame), `fotos.lua`/`ui_fotos.lua` (screenshots), `trace.lua`, `ram.lua`, and `run.lua` (input script plus `cenario.lua`).
- Each Lua script finds `teste/` from its own path via `debug.getinfo`. If Mesen doesn't expose `debug`, it falls back to the relative path `teste/`, so launch Mesen from the repo root. Other paths are built from that directory (`dir .. "../gen/labels.txt"`).
- Outputs (`teste/*.png`, `teste/*.txt`) are gitignored.
- `--testrunner` stops after 100 s by default (exit code 255, no message). Scripts that run longer (`senha.lua`, `senha_secreto.lua`, `audio_orc.lua`, `perfil.lua`) need `--timeout=900`.
- `audio_orc.lua` (audio budget per frame on a late-game day: idle scanlines, bytes sent, ring levels and the context of any empty frame) and `perfil.lua` (instructions per routine in day frames; `PERFIL_CHAMADAS = true` counts `AddSprite` calls per caller) are the probes to rerun after changing the day loop or the audio.
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
- `gen/data.inc` holds compiled strings (`TXT_<key>`), the lookup tables `MissionTxt`/`ShopName`/`ShopDesc`/`TrophyTxt` (their **counts are hard-coded in build.js**: 15 missions, 21 shop items, 16 trophies), music tracks, the SFX/pitch/instrument tables and the UI tables.
- `gen/cards.inc` holds the story-card text, which lives in its own bank (BANK11).

The generator modules:
- `gerador/textos.js` defines every game string as `T` (key → text, uppercase, `\n` = new line) plus `CARDS`.
- `gerador/fonte.js` turns text into tile codes with `compile()`. A character without a glyph throws at build time, so any new accented or special character needs a glyph in `G` first.
- To show a controller button inside text, use the tokens `{A}` `{B}` `{X}` `{Y}` `{CIMA}` `{BAIXO}` `{ESQ}` `{DIR}` `{L}` `{R}` `{CRUZ}` (never a bare letter):
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
- Shop scene decorations made from emojis (window, plant, picture, city, bags, books, the showcase pastéis, sunflowers) come from `gerador/emoji_cenario.py`: `build.js` writes the 5 neighborhood palettes to `gen/shoppal.json`, the script resizes each Twemoji, adds the dark outline and quantizes it per neighborhood into `gen/emoji_cen.json`, and `shopScene` pastes it with `colaEmoji` (it reads the JSON itself, so run `node build.js` before `preview.js`).
  - Shop palette (`PAL_SHOP`): colors 6 (wall) and 15 (detail) change per neighborhood (`SHOP_VAR`), 11 is green and 14 is blue for the emojis, and 12 blinks in game (`OilColor`), so the quantizer never uses 12. Only the elements in `COM_BAIRRO` may use 6/15.
  - Sprites cover the kitchen wall (flavors, locks, cursor) and the wall behind the counter (customers), so decorations there get hidden; `teste/loja_cenario.lua` restarts the day with each neighborhood/renovation and saves `teste/foto_cen_<b>_<r>.png`.
- `gerador/audio.js` contains the SPC700 driver blob and the chiptune songs and SFX.
- `gerador/ui_tabs.js` builds the HDMA gradient and animation tables.
- `gerador/logo.py` converts whichever root-level PNG has "pastelles" in its filename into the 15-color title logo.

### ROM layout
`src/snes.cfg` maps LoROM SlowROM with 64 banks of 32 KB (2 MB; the cartridge boards in use take up to 4 MB). The header in `main.s` says 2 MB and 2 KB of battery SRAM. Banks 32–63 hold the recorded audio (`gen/sons.inc`, generated; currently up to bank 52); bank 13 holds the RAMON opening (below); banks 14–27 are free.
- `src/main.s` is the single translation unit. It `.include`s `macros.inc`, `gen/assets.inc`, `vars.inc`, then `audio.s`, `voz.s`, `game.s`, `telas.s`, `extra.s`, `segredo.s`, `ui.s`, `demo.s` and `banco28.s` (in the `CODE` segment, bank 0, except the `BANK28` parts of `demo.s` and all of `banco28.s`), then the data. Graphics go in the `BANK1`–`BANK12` segments, roughly one scene group per bank. The banks are 32 KB, so watch for overflow when art grows.
- Register convention: **A is 8-bit, X/Y are 16-bit, DBR = $80, D = $0000**. Switch widths with the `A8`/`A16`/`I8`/`I16` macros so that the assembler's `.a8`/`.a16` tracking stays correct.
- `gerador/checa_largura.py` runs on every build and flags branches or jumps whose target label was assembled under a different accumulator width. Treat its "problemas: N>0" output as a real bug.

### Audio (SPC700) and recorded voices
- **The driver** (`DRIVER` in `gerador/audio.js`) is hand-assembled SPC700 code, using the small assembler `monta`. ca65 doesn't assemble SPC700. It's uploaded via IPL to `$0200`.
  - When it starts, it reads port 0, zeroes the echo buffer (`$C400–$D3FF`) and only then signals "ready" (`$D5` on port 1). `ApuUpload` waits for that signal.
  - It reads port 0 twice and accepts a command only when both reads match (see "Real hardware vs. emulator" below).
  - Port 0 changes on every command:
    - **Bit 7 = 1 (data):** 3 bytes (ports 1–3) go to write pointer A (`$02`, bit 6 = 0: music and the fixed-voice load) or B (`$06`, bit 6 = 1: speech), which advances 3. Data commands don't return status, which keeps them fast. The echo goes out right after the 3 bytes are stored and before the pointer advances, so the CPU writes the next trio while the SPC700 adds 3. Dispatch is `mov x,a` + `bpl` (on the SPC700 `mov dp,a` doesn't set flags) and `and a,#$40`. This loop is the real limit of the stream: ~2.3 bytes per idle scanline.
    - **Bit 7 = 0:** port 1 = DSP register and port 2 = value; port 1 = `$80`/`$81` sets pointer A/B to port 2/3. These commands return `ENDX` on port 1.
  - It always echoes port 0. Sending is pipelined: `APU_ESPERA` waits for the previous command's echo before writing to the ports. `ApuTrio`/`LOTE` don't wait for their own echo. `DspWrite` does.
- **Keying voices on/off:** always go through `VozesLiga`/`VozesDesliga` (`audio.s`), never write KON/KOF (`$4C`/`$5C`) directly. A KOF stays written until the next `AudioUpdate` (`kof_atual`), and each KON waits ~100 µs, because the DSP only polls KON/KOF every 2 samples (~64 µs).
- **SPC700 memory** (`ARAM` in `audio.js`):

  | Range | Contents |
  |---|---|
  | `$0200` | driver |
  | `$0300` | sample directory (SRCN 0–2 chiptune waves, 3 music ring, 4 sizzle, 5 speech ring, 6+ fixed voices; `build.js` checks the order) |
  | `$0400–$C3FF` | fixed voices and the sizzle (49,023 bytes at 9 kHz, up to `$C37E`) |
  | `$C400–$D3FF` | echo (EDL = 2, 32 ms; `ECO_ARAM`) |
  | `$D400–$DFB4` | speech ring (333 blocks) |
  | `$E000–$FFBE` | music ring (903 blocks) |

- **Recorded voices and music** (`gerador/sons.js`, `src/voz.s`): the MP3s in `sounds/` are converted to BRR by `gerador/brr.js`. The decoder used to model the DSP is checked against the samples that Mesen's DSP decodes. The table `VOZES` sets file, type, priority and the cooldown before the same voice can repeat.
  - **Fixed voices:** the frequent ones (`tipo: 'fixa'`), 8 voices plus the sizzle. Their rate is the highest that fits, currently 9 kHz. They're loaded into the SPC700 in idle time while the splash screen runs. `VozCargaFim` finishes the load immediately if needed.
  - **Speech streams:** the rare voices, at 16 kHz (`TAXA_STREAM`), played on voice 7 through ring B.
  - **The recorded song** (`VOZ_TEMA`, 14 kHz, looping): plays on voice 1 through ring A, on the title (with the narration on top) and during the day (in place of the old day chiptunes). It starts with `MusToca`. `MusPara` stops it, and `PlaySong`/`StopMusic` call `MusPara` too.
  - **Sending data:** `Bomba` runs inside `WaitFrame`, in each frame's idle time, and stops as soon as the NMI arrives. It sends in batches (`LOTE`, at most `LOTE_MAX` = 72 bytes) straight from ROM, prefetching the next 3 bytes while the SPC700 writes the previous ones.
  - **Priority and cushion:** speech goes first. If it sent a batch, the music waits for the next loop. The cushions (`FOLGA_S` in `build.js`) are 0.7 s for the music, so it can get through a speech playing on top of it in the busiest frames, and 0.2 s for speech. Exception: when the music ring is below 0.2 s (`MUS_CRITICO`, generated from the music rate) and speech has more than half its cushion, the music goes first that loop. `build.js` fails if a cushion plus a batch plus a frame passes ¾ of its ring (the resync rule below).
  - **Resync:** once per frame, `VozQuadro`/`MusQuadro` use the `ENDX` value read at the start of `AudioUpdate` (`apu_endx`). When a voice wraps around its ring, the level becomes the write position minus one frame, because the `ENDX` notice arrives up to 1 frame late. If the write position is beyond ¾ of the ring, the write pointer hasn't wrapped yet, so the level is 0.
  - **Budget** (measured by `teste/audio_orc.lua` on a late-game day: level 16, 3 baskets, full counter, app and deliveries): the logic ends ~137 scanlines before vblank (median; p10 106; minigame frames p50 122, p10 95), and the transfer runs at ~2.37 bytes per idle scanline. Music (14 kHz) needs 131 B/frame and speech (16 kHz) 150. In that test no ring ever ran empty; the lowest music level was ~1,600 bytes (0.2 s). Music at 16 kHz also passed, but with only ~0.05 s left, too thin for real hardware. Rerun it before adding CPU work to the day or raising a rate.
  - **The transfer limit is the SPC700 loop**, not the CPU: from seeing the new trio to echoing, it spends ~60 cycles (double read, dispatch, 3 indirect stores), and the CPU's ~10 µs reaction completes the ~80 µs period. A version with a running index and self-modified store addresses was no faster (the work before the echo is the same), so it was dropped. `LOTE` computes the next port-0 value (`lt_p0`) before waiting for the echo.
  - **What made room** (melhoria 13): the HUD only reprints the numbers whose value changed (`HudSig`/`HudGrp`, one bit per number); the minigame no longer clears and reprints its prompt every frame (`MiniAviso`); `OamClear` only hides the slots used since the last clear (`OamZera` clears everything, at boot); `AddSprite` doesn't switch register widths and follows the high-table position with `oam_hib`/`oam_his`; `NumConv` skips the 3 leading digits of 16-bit numbers. Before that, late-game days left ~40 idle scanlines and the music ring ran empty in 17% of the frames even at 10 kHz.
  - **ROM placement** (`build.js`): fixed voices, the music and the speech streams go in sequence from bank 32 (a stream may cross into the next bank).
  - **Conversion** (`gerador/sons.js`): MP3 → soxr resampling → treble boost (`agudos`, the BRRtools FIR that compensates the DSP's Gaussian interpolation, which costs -2 dB at 0.2 and -9 dB at 0.4 of the sample rate) → peak normalization → BRR. Measured on the DSP output simulated with Mesen's Gaussian table (`gen/brrexp`, not committed): +1.5 dB SNR on speech at 14–16 kHz and +4 to +5 dB on the fixed voices at 9 kHz. A beam-search BRR encoder gained only 0.4 dB, so the greedy one stays.
- **Cache:** the converted BRR is committed in `arte_fonte/brr/` (`BRR.VERSAO` 3 = treble boost and soxr). `indice.json` records the MP3 hash, the rate and the encoder version (`BRR.VERSAO`). Building doesn't need ffmpeg; it's only needed when an MP3, a rate or the encoder changes.
- **To add a voice:**
  - Put the MP3 in `sounds/` and add it to `VOZES`, then call `VozToca` with `VOZ_<ID>` on the event.
  - `fixa` is only for short, frequent voices: the fixed voices share ~50 KB, and adding one lowers everyone's rate.
  - A long `stream` that plays often during the day competes with the music.

### RAMON opening (ST_ABERTURA, first screen at boot)
A homage to Konami's logo intros: Sunset Riders' opening reproduced frame for frame, with the emblem replaced by an R, RAMON in place of KONAMI (no ®) and the original jingle. Boot goes to `ST_ABERTURA`, then `ST_SPLASH`; START or A skips.
- **Source art:** `arte_fonte/abertura/abertura.json` (committed; `ramon.png` is a preview). It was extracted once from a Sunset Riders (USA) ROM, which is not in the repo: `gerador/abertura_extrai.lua` (Mesen test runner) dumps VRAM and per-frame CGRAM to `gen/abertura_rom/`, and `python gerador/abertura_ramon.py` composes the logo and writes the JSON. A, M, O and N are the original letters; the R is K's stem and leg plus a hand-drawn bowl (`R_TOPO`, same per-row shading bands). The emblem's R (`emblema_r`) comes from the drawing `arte_fonte/abertura/emblema_r.png`: only its masks are used (red = leg, yellow = stem and bowl, orange edges go to the nearest), shaded like the original ribbons per row (dark bevel, the row's band color from the ribbon of the same color stretched over the height, light edge, highlight on top edges and shadow on bottom ones), so the blue outline and the palette shine stay right. The build doesn't need the ROM or Python.
- **Jingle:** the Lua also saves the SPC700 state at frame 313 as `jingle.spc`; `abertura_ramon.py` renders it with ffmpeg (libgme) into `sounds/abertura-ramon.mp3`, which plays as the stream `VOZ_ABERTURA`. `AbUpdateL` requests it at `AB_SOM_T` (4 frames before the voice keys on, while the ring fills), so it starts 6 frames after the fill begins, as in the original. It follows the MÚSICA option (not FALAS) and stops if the opening is skipped.
- **Build:** `gerador/abertura.js` → `gen/abertura_*.bin` and `gen/abertura.inc` in BANK13. BG1 (16×16 tiles, BGMODE `$19`) is the black curtain with the laser (row 1 of the map) and the 4-frame spark at its tip (`AB_FAISCA`); BG2 is the logo (palettes 0–1); the R's leg (palette 2 pixels) is `AB_NOBJ` 16×16 sprites (`AbObj`, OBJ tiles loaded over `VRAM_OBJ`, priority 1 so they sit behind BG2 and the curtain, OBJ palette 0 kept equal to palette 2 by `AbPalObj`), because it meets the yellow along a curve and a BG tile has a single palette. Everything else is palette: `AbPalQ` gives the frame of each of the `AB_NPAL` 128-byte states (colors 0–63: blue outline, fill with shine, white background, fade to black).
- **Code** (`banco28.s`): `AbInitL`/`AbUpdateL` (stubs `AbInit`/`AbUpdate` in `telas.s`); `AbRolagem` computes the curtain scroll (HOFS 256→0 at 8 px/frame, then VOFS −1→−259 at 2 px/frame) and the spark tile; `AbNmi` (called from the NMI after `UiNmi` while `ab_on`) writes TM = BG1+BG2, the scrolls and the spark's map entry. `SplashInit` calls `AbFim` (BGMODE back to `$09`, `SprTiles` reloaded) after its `ScreenOff`.
- Verified against the original by logging BG1 scroll, the spark's map entry and CGRAM 0–127 every frame in both ROMs: identical with a fixed 2-frame offset.

### Title and options screens
- **Title** (`TitleInit`/`TitleMenu`/`TitleSprites` in `telas.s`):
  - `gerador/logo.py` builds the BG1 image: the logo shrunk at the top, plus the menu card at the bottom (`CARTAO`, same look as the boxes). The background outside the emblem and the card is transparent, found by flood fill from the edge.
  - Behind it, `UI_TITULO` shows the animated checker (BG2) with no gradient.
  - Items: NOVO JOGO, CONTINUAR (only with a save), PASSWORD and OPÇÕES (`TitId` maps the position to the item). With all 4, the subtitle is hidden and the list starts 2 rows higher (`tit_lin`), because the card has no more room.
  - The items (`tit_lin`/`TIT_COL`) each have an emoji icon (`IconeSprite`, `ICO_*` in `ui.s`). The selected one is red, with a pill behind it (`PilulaLiga`) and a bobbing icon.
  - The recorded song and the narration start when the fixed-voice load finishes (`tema_pend`), so skipping the splash screen doesn't freeze the title.
- **Options** (`extra.s`):
  - One row per item (`OPT_*`): icon, name, value between the d-pad buttons, a pulsing highlight band, an explanation of the selected item (`OptAjuda`) and a pill footer.
  - Items: difficulty, music (turns the recorded song on or off), speech (`opt_falas`: when off, `VozToca` plays nothing) and back.
  - Saved in SRAM at `OPT_SRAM`: `'O','P'`, difficulty, music, and speech as `$A0|value`. An old save without that byte defaults to speech on.
- **Shop** (`ShopInit`/`DrawShop`/`ShopUpdate` in `telas.s`): the 20 items are split into 4 tabs (DIA, LOJA, EQUIPE, REDE) by `ShopOrd`/`ShopAbaIni`. L/R (or left/right) switch tabs, up/down move inside the tab (no scrolling: a tab holds at most 6 items). `menu_sel` is still the item index (`ShopName`, `ItemPrice`, `BuyFn`); `shop_aba`/`shop_pos` are derived from it by `ShopAcha` when the screen opens. The tab bar is row `SH_LINABA`, with `{L}`/`{R}` and a pill behind the selected tab. `teste/botcfg.lua` repeats the table in `SHOP_ABAS` (`SHOP_IR` drives the cursor to an item), and `teste/loja.lua` takes one screenshot per tab.
- **Icons:** the emoji sheet (`gerador/icones.py`) is the shop's (items 0–19) plus the menus' (20–23: new game, continue, options, password 🔐 `ICO_SENHA`; difficulty reuses the frying pan, 1); it holds 24 icons, so it's full. The shop's VER PASSWORD (item 20) uses `ICO_SENHA`. Title, options and shop load `IconGfx` into OBJ tiles 0–95. The screens that use those tiles reload the sprites: `DayInit`, and `IntroInit` (the street).
- **End-of-day screen** (`DrawResults`/`DrawChart` in `banco28.s`): a second sheet from `icones.py` (`ICONES_RES`, up to 24, `gen/icon_res_*`, `IconResPalTab`) replaces the labels with icons (`ICR_*`, drawn by `IcoRes`), loaded over the same OBJ tiles 0–95 and palettes 3–6. Left column = income (green), right = expenses (red); lines whose value is 0 (other stores, salaries) are hidden. `TxtEsq`/`NumEsq` print left-aligned and advance `txt_pos`. Mission texts must fit 24 characters next to the icon (`build.js` checks).

### Demo mode (attract mode, `src/demo.s`)
- **Start:** 30 s with no buttons on the title (`DemoTitulo`, `DEMO_OCIOSO`) starts a demo. `DemoSorteia` rolls a stage in the RAM copy of the save: level 1–24 (which sets the flavors), day, baskets, counter, renovation, neighborhood and extras.
- **Off during the demo:** tutorial, broken baskets and app deliveries.
- **The day:** starts at `DEMO_HORA` (14h, about 1 minute).
- **The CPU playing:** `DemoControle` runs right after `ReadPad` in the main loop. On the day screen, every 4 frames it replaces `pad_new` with the button chosen by `DemoIA` (the same logic as `teste/bot.lua`), and every so often shows `TXT_DEMO` on the HUD.
- **End:** any real button, or the end of the day (when the next state would be the results), returns to the title.
- **Saving:** nothing is saved, because the day never writes SRAM and results/shop/tutorial are skipped.
- **Banks:** `DemoSorteia` (with its own `DemoRand`) and `DemoIA` live in bank 28, called with `JSL` and returning with `RTL`, because bank 0 is full. They can only call routines in the same bank. RAM and the bank-0 tables are reachable through the DBR (`$80`).

### Emoji sprites
`gerador/emoji_sprites.py` (Twemoji, cached in `arte_fonte/emoji/`) turns sprites that have a perfect emoji into 16×16 with the shop icons' outline: flavors 🥩 🧀 🍗 🥓, lock, anger, heart, coin, X, star, phone, computer, scooter, sparkle, fire, the pause icons ▶️ 🏠 and the palm-up hand 🫴 (`SPR_MAO`, drawn next to the cursor by `MaoSprites` in `banco28.s` with the held flavor/soda on its fingers).
- **Own pixel art:** an entry whose source ends in `.png` (path from the repo root) is a hand-made PNG instead of an emoji. Requeijão cremoso uses `arte_fonte/requeijao_cremoso.png` (a squeeze bag, 14×28). `pixel_art()` halves it by majority color per block (no blur) and redraws the outline, and its quantization keeps the hue (a saturated color only maps to a saturated palette color of a close hue), so the navy label stays blue.
- **Colors:** they're quantized to the sprite's fixed palette (0 or 1), because during the day palettes 3–7 belong to the customers.
- **Fallback:** sprites without a good emoji (calabresa, soda can, order bubble, smoke, mascot, pastéis, store) keep the hand-drawn art from `arte.js`.
- **Build:** `build.js` writes `gen/spal.json` and passes the result (`gen/emoji_spr.json`) to `buildSprites(emojis)`.

### Expansion map (ST_MAP and ST_CHOOSE)
`gerador/mapa.js` draws the map in RGB (terrain by hand; buildings, construction sites and trees from Twemoji via `gerador/emoji_mapa.py` → `gen/emoji_mapa.json`) following the Gemini concept art in the repo root, then reduces it to 6 BG palettes (2..7): palette 2 is fixed (terrain; colors 9 and 11 are the water highlights that `MapAgua` swaps every 16 frames) and 5 come from k-means over the remaining tiles, always including the grass and outline colors so tiles don't show seams. `node gerador/mapa.js` writes previews to `gen/preview/mapa_base.png` / `mapa_cheio.png`.
- The base map has construction sites for stores 1–4 and "for sale" signs for the 5 franchises. Each unit is a tile rectangle (`LOJAS`/`FRANQ` in `mapa.js`); the build fails if buying a unit would change pixels outside its rectangle. `gen/map_obras.inc` holds those patches and `StoreXY` (cursor point above each store, read with `f:`); `MapObras` (bank 28) writes the bought ones over the BG1 map while the screen is off.
- `MapCarrega` (`telas.s`) loads everything for both screens; the choice screen only draws the bobbing cursor (`ChooseSprites`).

### Menu background (BG2)
Menu screens (`LoadMenuScene`) show a 2-layer background:
- BG1 holds the panel. Outside the panel it is transparent.
- BG2 holds the checker pattern (`menuChecker` in `arte.js`): 3 tiles at tile index 1021 (`MENU_CHK_VRAM`), a map at `VRAM_BG2MAP` = $5800, and BG palette 3 (`ChkPal`, loaded by `LoadXadrez` callers). It doesn't use palette 2 because that one belongs to the scene/logo.

`UiNmi` scrolls BG2 1 px to the right every 2 frames and turns BG2 on in `TM` while `ui_mode` is `UI_PANEL` (boxes) or `UI_TITULO` (title). Every other scene uses BG1 only.

### Day blockers
`PreDayInit` first calls `DiaBloqueado` (`banco28.s`). If something prevents a normal day it queues a card and returns C=1 instead of starting the day. Today the only blocker is no pastel stock (unless `VENTO_BIT`): with money for stock (R$ 30) it shows `CARD_SEMESTOQUE` ({A} goes to the shop, {B} back to the title, via `CardBotaoB`/`CardRodape`); without, the master gives 10 portions (`CARD_FALIU`) and the day starts. New blockers go in `DiaBloqueado`.

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

### Day HUD
The layout lives in `gerador/hud.js`: `arte.js` (`hudBaloes`) draws the cream pills (top band) and the cream panel (bottom band) into every shop scene, and `build.js` turns it into `HUD_*` constants (text column/width, emoji x, rows) and fails if the pills overlap.
- **Top (row `HUD_LIN_TOPO`):** day, money, level and clock, each in a pill with a 16×16 emoji at its left end (`SPR_CALENDARIO`, `SPR_MOEDA`, `SPR_ESTRELA`, `SPR_RELOGIO`). Numbers are left-aligned and padded with spaces (`HudNum`), on BG3 palettes 4–7 (the ones for cream backgrounds). The flying coin (`DrawCoin`) heads for the money emoji.
- **Bottom panel:** row `HUD_LIN_MSG` is the message line. It shows the mission (with the 8×8 star, `hud_mis = 1`) and, in its place, the messages (`ShowMsg`/`ShowMsgBad`, green/red), the tutorial hints, the minigame prompt and the demo notice. When `msg_timer` runs out, `MsgUpdate` calls `ShowMission`, which waits while a message is up. Row `HUD_LIN_NUM` has stock, reputation and the day's goal (progress/goal) with 8×8 sprites (`SPR_MINI_CAIXA`, `_CORACAO`, `_ALVO`). Messages (`M_*`, `TUT_*`, `DEMO`) must fit 30 columns; `build.js` checks.
- `DrawHudStatic`/`DrawHud` (bank 0) only call `HudFixo`/`HudValores` in bank 28; `DayDraw` calls `HudSprites` first, so the HUD emojis are in front. Rows 0 and 2 of BG3 are no longer used during the day. `teste/hud.lua` photographs the HUD (tutorial over it, a message, the mission, maxed numbers with a goal and held items, and the pause).

### Password (saving without SRAM, `gerador/senha.js`)
- **SRAM detection:** `SramDetecta` (bank 28, at boot) writes $55 and $AA to the last two SRAM bytes and only then reads both back (open bus returns the last value on the bus, so a single write+read can pass without SRAM), then restores them. `tem_sram = 0` means a cartridge without SRAM: `SaveGame`, `SaveTFlags`, `SaveOptions` do nothing, `HasSaveSlot` says empty, NOVO JOGO starts without the slot screen and VOLTAR AO MENU shows the password first (`senha_modo = 2`). The shop descriptions of VOLTAR/ABRIR switch to `SD_18N`/`SD_19N`.
- **Format:** the save becomes one number in **mixed radix** (`P`): each field of `CAMPOS` is a digit whose base is exactly the number of values it can take, so nothing is wasted rounding up to powers of 2. The password is `P` (`SENHA_BITS_P` bits, XORed with an LFSR seeded by the check) followed by the check (CRC-16 CCITT, the remaining bits, XOR a key): **20 symbols** of 5 bits from `23456789ABCDEFGHJKLMNPQRSTUVWXYZ` (no O/0/I/1), shown as 5 blocks of 4. `build.js` prints the bit budget and fails if a base passes 16 bits, `P` doesn't fit 96 bits or fewer than 9 bits are left for the check. Field types:
  - **range** (min, max, shift): `s_rep` goes in steps of 2 (the 70 needed for franchises stays exact).
  - **steps** (`TAB`, a precomputed table): the stored value is the largest step ≤ the real one. Stock (exact up to 199, then steps of 10), happy/perfect customers, deliveries and duels (0, 2, 5); the steps match the thresholds that missions and trophies check, so only progress between steps is lost.
  - **money:** a "float": exact below R$ 1024, then a 9-bit mantissa (loses at most 0.2%), capped at R$ 16,711,680.
  - **level + xp:** a single index into a precomputed table (`SenhaLvDes`/`SenhaLvNiv`/`SenhaLvIni`) over the (challenges beaten, level) pairs that can happen (the level is between the previous challenge's cap and the next one's) with xp in steps of 8. It also stores `s_boss`. A level outside its range is clamped.
- **Derived, not stored** (`SenhaDeriva`): `s_chapter` = challenges beaten, `s_ending` = 10 units, `s_upgrades` = fryer + counter above 1, the tutorial bit = day ≥ 2, `s_tot_fried`/`s_tot_sales` (only missions 0 and 1 check them).
- **What's left out:** options, profit history (reset), and the trophies that `TrophyCheck` recomputes from the state (only `s_trof` bits 5–7 go in, via `pw_trof`). **Any new field in the save block must be added to `CAMPOS` (and `VERSAO` bumped); raising a mission/trophy threshold means updating its steps table.**
- **Code** (bank 28): `SenhaGera` (RAM → `pw_sym`: one `BigMulAdd` per field) and `SenhaLe` (`pw_sym` → RAM: checks the CRC, pops the digits with `BigDivMod` from the last field to the first, rejects if anything is left over or the version differs, and only then writes), and the screen (`ST_SENHA`, `SenhaInitL`/`SenhaUpdateL`): `senha_modo` 0 types (8×4 keyboard; the selected key gets a 16×16 key-cap sprite behind the letter, `SenhaSprite`, loaded into OBJ tiles 0/1/16/17 where the menu icons live, so screens that use icons reload them; {A} types, {B} deletes or goes back when empty, START checks), 1 shows and returns to the shop (VER PASSWORD), 2 shows and goes to the title. A valid password goes to the slot screen with `sl_mode = 3` (choose where to save) when there's SRAM, or straight to `ST_PREDAY` without it. The secret code (`CodeCheck`, the same as on the title) also works while typing (`pw_festa`): the arrows cancel out on the keyboard, the code's B doesn't delete (`pw_bdel`: the final A restores the symbol; with nothing typed it doesn't go back to the title) and its A doesn't type. With `pw_festa`, START on a valid password opens `ST_SECRET` first; there SALVAR E JOGAR (SEGUIR JOGANDO without SRAM, `TXT_SEC_5N`) goes to the slots with `sl_mode = 3` or straight to `ST_PREDAY`, and every exit clears `pw_festa`. Without SRAM, the code on the title opens the typing screen with `pw_festa` already set (with SRAM it still goes to the slots, `sl_mode = 2`); the PASSWORD item clears it.
- **Tests:** `teste/senha.lua` (with SRAM: 30 random saves, including extremes, generated and read back by the ROM and compared with the rounding rules redone in Lua; then the full flow: shows the password, types it on the keyboard, a wrong one first, saves to a slot and compares RAM and SRAM). `teste/senha_secreto.lua` (runs on both ROMs) checks the secret code on the typing screen, empty and full, and the way through the secret menu back to the game. `teste/sem_sram.lua` runs on the ROM from `node teste/rom_sem_sram.js` (`gen/LosPastelles_sem_sram.sfc`, header without SRAM) and checks the whole no-SRAM flow.

### Pause menu (day)
START during the day opens the pause in the same cream balloon as the tutorial (`dim_on = 2`, so `TutNmi` and `TutSprites` apply): `PauseDraw`/`PauseMenu` in `game.s`. Title on row 9, three items (CONTINUAR, AJUDA, SAIR) on rows `PA_LIN0`, `+2`, `+4` (text at column 7), the "day isn't saved" warning under SAIR only when it is selected, and a `Footer` on row 18 (straddling the balloon's bottom edge). Each item has a 16×16 emoji sprite (`SPR_PAUSA_CONT` ▶️, `SPR_PAUSA_AJUDA` ❓, `SPR_PAUSA_SAIR` 🏠, from `emoji_sprites.py`), drawn by `PauseSprites`, which `TutSprites` calls at its end so the icons aren't hidden with the game sprites under the balloon. Up/down/SELECT switch items (with wrap), A/START confirm, B resumes. `build.js` checks the widths of `PAUSA`/`PA_*`. `teste/pausa.lua` takes screenshots and checks that B resumes.

### Help (AJUDA in the pause)
Code in `banco28.s` (`AjudaAbre`/`AjudaUpdate`/`AjudaDraw`/`AjudaSprites`/`AjudaNmi`), called from the pause (`aj_on`). It uses `dim_on = 3`: `TutNmi` calls `AjudaNmi`, which points the window/color-math HDMA at the big balloon's tables (`AjWinTab`/`AjMathTab`, rows 3..23; HDMA line counts are split at 127 because bit 7 means repeat mode) and sets `BG2SC` from `aj_sc`. `TutSprites` hides every game sprite while it's open.
- **Content:** `gerador/ajuda.js` defines the 4 tabs (CONTROLES, COMO JOGAR, NÍVEIS, EVOLUÇÃO) and their pages (13 lines × 26 characters from row 9, column 3; `build.js` checks with `cabe`). Compiled to `gen/ajuda.inc` in BANK11 (`AjNome`, `AjPagIni`, `AjPagTxt`, `AjPagNum` "1/3", `AjPagDes`) and printed with `PrintStrB`.
- **Levels have a single source:** `gerador/niveis.js` (`NV`). `build.js` exports `NV_*` to `assets.inc`; the code uses them (flavors, minigame buttons, customer types, `COMBO_LV`/`TEL_LV`, `ItemPrice`, `LevelCap`, unlock cards in `ResultsUpdate`), the chapter cards use them in `textos.js`, and the NÍVEIS tab is generated from `lista()`. Change a level there, never in the `.s` files. `build.js` fails if the unlock cards grouped at one level (`UN_ATEND`/`UN_TEL` with requeijão, `UN_PC` with the new shop) would split.
- **Art (BG2, loaded with the day scene by `AjudaCarrega`):** the big balloon (`ajudaBalloon` in `arte.js`, flat cream on top, gradient below the drawing) and the Super Famicom controller (`controleSFC`, BG palette 4 = `PAL_CTRL`, color 15 = the balloon's flat cream so the tiles blend). Two fixed maps: A with the controller (`$3400`) and B without (`$3800`); a page with `desenho: true` shows map A. Tiles go right before the maps (`AJ_VRAM`, about tile 709); `build.js` fails if a shop scene (BG1, up to 261 tiles today) would reach them.
- **Tabs:** `{L}`/`{R}` at the ends of row 5 and an emoji per tab (`SPR_AJ_CONTROLE` 🎮, `SPR_AJ_LIVRO` 📘, `SPR_ESTRELA` ⭐, `SPR_AJ_GRAFICO` 📈) with a pill (`SPR_PILULA_E`/`_D`, drawn by hand, since `Footer` owns the pill slots) behind the selected one. L/R or left/right switch tabs, up/down or A switch pages (with wrap), B/START go back to the pause. Footer on row 23.
- `{CRUZ}` is a text token for the whole d-pad (no arm lit). `teste/ajuda.lua` opens the help, photographs every page of every tab (`teste/foto_ajuda_*.png`) and checks the navigation and the way back.

### Big animations (BG2, day)
Large animations drawn over the day scene (today: assembling the pastel in the minigame) use a cream card on BG2 instead of sprites (the OBJ sheet is full).
- **Art:** each animation is `gerador/anim_<nome>.py` (listed in `ANIMS` in `build.js`). It draws the keyframes as RGBA 64×48 images with the shared palette of `gerador/anim_comum.py` (BG palette 5; colors 2–3 only for the card frame), builds the in-betweens with `gerador/morph.py` (`sequencia(chaves, n, contorno=C(1))`: shapes interpolate through signed distance fields, colors switch halfway, the outline is redrawn) and calls `salva(nome, quadros, chaves, extra, ponto)`. `extra` is one byte per frame for the game (`Anim<Nome>Extra`) and `ponto` an interior point (`ANIM_<NOME>_PX/PY`, in screen pixels).
- **Build (`gerador/anim.js`):** all frames of all animations form one list. `ANIM_<NOME>` is the first index and `ANIM_<NOME>_N` the count, and `Anim<Nome>Chaves` holds the keyframes relative to the first. Each frame is the 8×6 interior tiles (1536 bytes), 21 per bank in banks 29–31 (`AnimQuadro` = long address of each frame). The card border tiles and interior slot sit right below the pause help tiles (`ANIM_TILE`; the build fails if a shop scene reaches them). The BG2 map is at `ANIM_MAPA_VRAM` = $5C00, with the card at columns 2–11 and rows 16–23 (`ANIM_X0`…`ANIM_Y1`), below the counter (rows 13–15 have BG1 priority) and above the HUD panel.
- **Player (`banco28.s`, JSL):** `lda #frame : jsl AnimMostra` shows the card on that frame, `jsl AnimVai` walks to a target frame (forward or backward, one frame every `ANIM_VEL` = 3 video frames), `jsl AnimSome` sets how many frames to stay on the target before hiding (0 = stay), and `jsl AnimEsconde` hides it now. `AnimSprites` (end of `DayDraw`) steps the animation, moves sprites touching the card to priority 2 (behind BG2) and draws the extras (`MgaSprites`). In the NMI, `AnimDma` sends the current frame's tiles when it changes, taking the BG3 slot that frame (text goes one frame later; the DMAs end by line ~243, measured by `teste/montagem.lua`). `AnimNmi`, after `UiNmi` when there's no pause or tutorial, turns BG2 on with the card's map, and restores `BG2SC` to the menu checker's map when the card hides or the state is no longer the day.
- **Minigame (`MgaInicio`/`MgaAcerto`/`MgaErro`):** start at keyframe 0; each correct button walks to keyframe round(`mg_pos`×4/`mg_len`). The last one stays 24 frames and hides. The basket repair minigame (`mg_mode`) has no animation. While the mound is visible (`AnimMontagemExtra`), the flavor emoji (`IconTiles`) is drawn on it. **Trash animation:** `MgaErro` (called from `MiniGame` on a wrong button or timeout, outside the tutorial) plays `ANIM_LIXEIRA` from its first to its last frame and hides the card `LIX_FIM` = 30 frames after the lid closes. `gerador/anim_lixeira.py` draws its layers (open pastel, can, lid, the 💨 emoji) and builds the in-betweens by interpolating each layer's position and angle instead of `morph.py` (better for an object that crosses the card); layers marked "atrás" are cut at the can's mouth. A new minigame started during it replaces it with the assembly.

### Game loop and state machine
`MainLoop` in `main.s` dispatches through the `StateInit`/`StateUpdate` jump tables (`src/telas.s`), indexed by `state`. The `ST_*` constants are defined at the top of `src/game.s` (title, intro, card, preday, day, results, shop, map, options, choose, slots, splash, trophies, secret, password, opening). To change screens, write to `next_state`. The main loop runs the new state's Init once, then calls Update every frame, followed by `UiUpdate`, `AudioUpdate`, `WaitFrame` and `ReadPad`. NMI uploads OAM, palettes and VRAM from RAM buffers.
- `game.s` is the in-day gameplay: frying, customers, minigame, deliveries. `telas.s` holds the screens and menus, `extra.s` additional features, `segredo.s` the secret cheat menu, `ui.s` the HDMA panels and icons, and `audio.s` the APU upload and the music and SFX sequencer.
- `src/vars.inc` declares the RAM variables. The block between `save_start` and `save_end` is copied to SRAM as one unit (3 save slots) and **must stay contiguous**. Adding, removing or reordering fields there changes the save format.

### Real hardware vs. emulator (lessons from past bugs)
Mesen passing is not proof that the game works on a console. These bugs reached a real SNES (FXPAK) after passing every emulator test. Keep these rules in mind:
- **Never assume memory or registers start at zero.** Console RAM, SPC700 ARAM, DSP registers and DMA registers start with random or leftover values (a flashcart boots the game from its own menu, which leaves state behind). Clear everything you later read, including buffers a peripheral reads by itself, such as the echo buffer.
- **Cross-chip handshakes must tolerate glitches.** A port read at the same moment the other CPU writes it can return wrong bits. Read a changing value until two consecutive reads match, and write the data ports before the port that signals "new command".
- **Respect the hardware's sampling period.** If a chip polls a register periodically (the DSP polls KON/KOF every ~64 µs), a value written and undone faster than that may never be seen, and that depends on timing phase, so the emulator can happen to pass. Hold values for at least one poll period, and don't overwrite a pending command before it's consumed.
- **Fail-safe state machines.** If a "stop" command can be lost, the effect shouldn't loop forever. Prefer designs where a missed command self-corrects (rewritten every frame, or data that ends naturally).
- **Saved settings change behavior.** A cartridge keeps its SRAM between ROM versions, and the tests always start without a save. When something "doesn't play" or "doesn't show" only on the user's device, first rule out a saved option (e.g. MÚSICA off) before debugging code.
- **Debug by isolation.** Ask questions that split the problem: which voice or screen, does it stop, does turning an option off make it go away. Then measure in Mesen with Lua (`emu.getState()` exposes DSP voice state, `emu.memType.spcRam` the ARAM) rather than guessing.

### General rules from past fixes
- **Scanline sprite limit:** sprites hidden behind something still count toward the 32 sprites / 34 tiles per line. Hide them (move off-screen) instead of only lowering their priority, or the last OAM slots (buttons, pill) drop out.
- **Pixel alignment of overlays:** sprites that overlay text must align exactly to the 8×8 grid. Off-by-one positions get cut by the shadow of neighboring glyphs.
- **Let the build enforce limits.** Text that overflows a box, width mismatches (`checa_largura.py`), the sample directory order and the bank sizes all fail the build. When a new limit appears, add a check in `build.js` instead of relying on review.
- **Tests must start clean and be independent.** Each Mesen test runs without a save (delete `teste/mesen/Saves`); a leftover save from a previous test made a test fail for no real reason.
- **No machine-specific paths.** Scripts find their files relative to themselves (`debug.getinfo`, `__dirname`), and tools/fonts/interpreters come from env vars with per-OS defaults.
- **Use relative links in docs.** Absolute links to a fork's releases break in the original repo and in other forks.
- **Long or blocking work shouldn't freeze the screen.** Start dependent features when the prerequisite finishes (e.g. the title song waits for the fixed-voice load) instead of blocking the main loop.
- **Progress that must survive leaving mid-way is saved at the moment it happens** (e.g. the tutorial bit goes straight to SRAM on the first delivery).
- **Bank 0 is full.** New sizeable routines go to `src/banco28.s` (segment `BANK28`), called with `JSL` and returning with `RTL`. From there, call bank-0 routines (which end in `RTS`) with the `FAR0` macro (`macros.inc`): it pushes a return through `Rtl0` in bank 0. `PRINT0`/`PRINTNUM16_0` are the `FAR0` versions of `PRINT`/`PRINTNUM16`. Text strings (`TXT_*`) still live in bank 0. To free bank-0 bytes, move a big routine with few callers there (as done with `DrawChart`).
- **Keep CI dependencies current.** Update GitHub Actions before their runtime is deprecated.

### Other folders
`cartucho/` holds the label, manual, photos and exported art for the physical cartridge. `trailer/` holds the final trailer MP4. `roteiro_*.md` is the game's design and story script.
