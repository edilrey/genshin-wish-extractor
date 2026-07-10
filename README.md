# genshin-wish-extractor

this is a linux bash script for extracting wish history link on genshin for paimon.moe auto import

## How to use

Install required tools (if missing):

```bash
sudo pacman -S jq curl grep xclip

```

or for Wayland: `sudo pacman -S jq curl wl-clipboard`

Run the script from a terminal:

```bash
./getlink.sh
For the Chinese server, add --china:
```

```bash
./getlink.sh --china
```

If your Wine prefix is not /mnt/Games/lutris/Games/genshin-impact, use:

```bash
./getlink.sh --prefix /path/to/prefix
```
