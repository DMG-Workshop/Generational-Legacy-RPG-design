# Fonts

## Silkscreen (the interface's pixel font)

- Files: `Silkscreen-Regular.ttf`, `Silkscreen-Bold.ttf`. Licence: SIL Open Font License 1.1, in `LICENSE-Silkscreen.txt`.
- Copyright 2001 The Silkscreen Project Authors (designer: Jason Kottke). Source: the Google Fonts repository,
  `ofl/silkscreen/` (https://fonts.google.com/specimen/Silkscreen), fetched unmodified.
- The OFL lets the game ship, embed and redistribute the font with the licence text kept beside it, and forbids selling the font on its
  own or reusing the reserved name for a changed font. We do not change the font files.
- It is drawn only where a pixel of the font is a whole number of screen pixels (8 pixels to the em: sizes 8, 16, 24 at 100% text size,
  16 and 32 at 150%, 32 at 125%); elsewhere the engine's font stays. `UiSkin.font_file` turns smoothing, hinting and
  sub-pixel placement off when it loads them (the `.import` files are not kept in the repository), so the pixels stay square.
- What uses it, and the rules for sizes, are data: `font` in `data/ui/skin.json` (see `UiSkin.font_size_for`). The Menu's Accessibility
  row has a Plain font option that puts everything back in the engine's font.
