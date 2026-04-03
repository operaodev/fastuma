<img width="512" height="512" alt="chara_stand_1015_101501" src="https://github.com/user-attachments/assets/a28c7950-8f09-4bbd-914e-757c70d11ee5" />


# Fastuma

> Uma Musume character outfits for [fastfetch](https://github.com/fastfetch-cli/fastfetch) — every terminal session shows a random girl.



![bash](https://img.shields.io/badge/shell-bash-4EAA25?style=flat-square&logo=gnubash&logoColor=white)
![fastfetch](https://img.shields.io/badge/requires-fastfetch-blue?style=flat-square)
![jq](https://img.shields.io/badge/requires-jq-orange?style=flat-square)
![license](https://img.shields.io/badge/license-MIT-lightgrey?style=flat-square)

---

## What it does

Fastuma wraps fastfetch to display a random Uma Musume character with a random outfit as the session image. On each run it picks a character and outfit at random, patches a temporary copy of your fastfetch config with the image path and character name, and runs fastfetch — your original config is never modified.

Assets are downloaded once from [umapyoi.net](https://umapyoi.net) and [gametora.com](https://gametora.com) and stored locally.

```
◄ 0s ◎ fastuma
╭─────────────────────────────────────╮
│  🖼  SPECIAL WEEK · CLASSIC OUTFIT  │
│  OS      Arch Linux                 │
│  Kernel  6.9.3-arch1-1              │
│  Shell   fish 3.7.1                 │
│  WM      Hyprland                   │
│  ...                                │
╰─────────────────────────────────────╯
```

---

## Requirements

- `bash` 4+
- [`fastfetch`](https://github.com/fastfetch-cli/fastfetch)
- `jq`
- `curl`
- A terminal with image support: [Kitty](https://sw.kovidgoyal.net/kitty/), iTerm2, or any Sixel-compatible terminal

---

## Install

Clone anywhere and run the installer:

```bash
git clone https://github.com/youruser/fastuma.git
cd fastuma
bash install.sh
```

The installer will:
- Create `~/.local/share/fastuma/` with the resource directories
- Copy `fastuma.sh` and `fastuma.conf` there
- Create a symlink at `~/.local/bin/fastuma`
- Download all outfit images from the API

Then just run:

```bash
fastuma
```

If the command is not found, add `~/.local/bin` to your PATH:

```bash
# bash / zsh
export PATH="$HOME/.local/bin:$PATH"

# fish
fish_add_path ~/.local/bin
```

---

## Configuration

Edit `~/.local/share/fastuma/fastuma.conf`:

| Key | Default | Description |
|-----|---------|-------------|
| `RESOURCE` | `outfit` | Image module: `outfit` · `card` · `icon` · `mini` |
| `RANDOM_CHARA` | `true` | Pick a random character each run |
| `RANDOM_OUTFIT` | `true` | Pick a random outfit for the character |
| `FIXED_CHARA_ID` | _(empty)_ | Character ID to use when `RANDOM_CHARA=false` |
| `FASTFETCH_CONFIG` | `~/.config/fastfetch/config.jsonc` | Your fastfetch base config |
| `IMAGE_PROTOCOL` | `kitty` | `kitty` · `sixel` · `iterm2` · `chafa` |

---

## File layout

```
~/.local/share/fastuma/
├── fastuma.sh            ← main script
├── fastuma.conf          ← your config
├── uma_grouped.json      ← character + outfit index (generated)
└── resource/
    ├── outfit/           ← chara_stand images  ← default
    ├── card/
    ├── icon/
    └── mini/

~/.local/bin/
└── fastuma               ← symlink → fastuma.sh
```

---

## Run on terminal startup

Add to your shell config so fastuma runs every time you open a terminal:

```bash
# ~/.bashrc or ~/.zshrc
fastuma

# ~/.config/fish/config.fish
fastuma
```

---

## Uninstall

```bash
rm -rf ~/.local/share/fastuma
rm ~/.local/bin/fastuma
```

---

## Data sources

- Character and outfit metadata: [umapyoi.net](https://umapyoi.net)
- Character images: [gametora.com](https://gametora.com)

All assets belong to Cygames. This project is fan-made and not affiliated with or endorsed by Cygames.

---

## License

MIT
