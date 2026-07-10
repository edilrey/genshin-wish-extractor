
#  Genshin Impact Wish History Link Extractor for Linux (Zsh)
#  Based on the official paimon.moe PowerShell script


setopt extendedglob
emulate -L zsh


function _error() { echo "Error: $*" >&2; }


for cmd in curl grep sort cut; do
    command -v $cmd &>/dev/null || { _error "$cmd is required."; exit 1; }
done
if ! command -v jq &>/dev/null; then
    _error "jq is required. Install it with: sudo pacman -S jq"
    exit 1
fi


if [[ -n $WAYLAND_DISPLAY ]]; then
    if ! command -v wl-copy &>/dev/null; then
        _error "wl-copy is required. Install wl-clipboard."; exit 1
    fi
    _clip_cmd="wl-copy"
elif [[ -n $DISPLAY ]]; then
    if ! command -v xclip &>/dev/null; then
        _error "xclip is required. Install it with: sudo pacman -S xclip"; exit 1
    fi
    _clip_cmd="xclip -selection clipboard"
else
    _error "No display server detected."; exit 1
fi


WINE_PREFIX="${GENSHIN_PREFIX:-/mnt/Games/lutris/Games/genshin-impact}"


REGION="global"
API_HOST="public-operation-hk4e-sg.hoyoverse.com"


while [[ $# -gt 0 ]]; do
    case "$1" in
        --china) REGION="china"; API_HOST="public-operation-hk4e.mihoyo.com"; shift ;;
        --prefix) WINE_PREFIX="$2"; shift 2 ;;
        *) echo "Usage: $0 [--china] [--prefix /path/to/prefix]"; exit 1 ;;
    esac
done


USER_NAME="${USER:-$(whoami)}"
if [[ $REGION == "china" ]]; then
    LOG_PATH="$WINE_PREFIX/drive_c/users/$USER_NAME/AppData/LocalLow/miHoYo/原神/output_log.txt"
else
    LOG_PATH="$WINE_PREFIX/drive_c/users/$USER_NAME/AppData/LocalLow/miHoYo/Genshin Impact/output_log.txt"
fi

if [[ ! -f "$LOG_PATH" ]]; then
    _error "Cannot find the log file! Make sure to open the wish history first!"
    _error "Checked: $LOG_PATH"
    exit 1
fi


log_line=$(grep -m1 -E "(GenshinImpact_Data|YuanShen_Data)" "$LOG_PATH")
if [[ -z $log_line ]]; then
    _error "Cannot find game data path in the log file. Open the wish history first."
    exit 1
fi


if [[ $log_line =~ "([A-Za-z]:/[^\"]*(GenshinImpact_Data|YuanShen_Data))" ]]; then
    win_path="${match[1]}"

    drive_letter="${win_path:0:1}"
    linux_path="${win_path#${drive_letter}:}"  
    game_data_dir="$WINE_PREFIX/drive_c${linux_path%/}"  
else
    _error "Could not parse game data path from log."; exit 1
fi

if [[ ! -d "$game_data_dir" ]]; then
    _error "Game data directory not found: $game_data_dir"; exit 1
fi


webcache_root="$game_data_dir/webCaches"
if [[ ! -d "$webcache_root" ]]; then
    _error "webCaches folder not found: $webcache_root"; exit 1
fi


latest_cache_ver=$(ls -dt "$webcache_root"/*(/N) | head -1)
if [[ -z $latest_cache_ver ]]; then
    _error "No version folder found in $webcache_root"; exit 1
fi

cache_file="$latest_cache_ver/Cache/Cache_Data/data_2"
if [[ ! -f "$cache_file" ]]; then
    _error "Cache file not found: $cache_file"; exit 1
fi

tmpfile=$(mktemp /tmp/ch_data_2.XXXXXX)
cp "$cache_file" "$tmpfile"


url_list=$(grep -a -b -oP 'https?://[^\x00-\x1f\s]+game_biz=[a-zA-Z0-9_]+' "$tmpfile" 2>/dev/null \
    | sort -t: -k1 -nr | cut -d: -f2-)

if [[ -z $url_list ]]; then
    _error "No wish history URLs found in cache. Open the wish history first."
    rm -f "$tmpfile"
    exit 1
fi


function _test_url() {
    local url="$1"
    local api_url


    local query="${url#*\?}"
    local new_query="lang=en&gacha_type=301&size=5&${query}&lang=en-us"
    api_url="https://${API_HOST}/gacha_info/api/getGachaLog?${new_query}"


    local response
    response=$(curl -s --max-time 10 "$api_url" 2>/dev/null)
    local retcode=$(echo "$response" | jq -r '.retcode' 2>/dev/null)
    [[ "$retcode" == "0" ]]
}

echo "Testing URLs (newest first)..."

found_link=""
while IFS= read -r candidate; do
    echo -n "Checking URL: ${candidate:0:80}... "
    if _test_url "$candidate"; then
        echo "VALID"
        found_link="$candidate"
        break
    else
        echo "invalid"
    fi
    sleep 1
done <<< "$url_list"

rm -f "$tmpfile"

if [[ -z $found_link ]]; then
    _error "Could not find a working wish history link. Open the history in-game and try again."
    exit 1
fi

echo "$found_link"
echo -n "$found_link" | eval $_clip_cmd
echo "Link copied to clipboard – paste it into paimon.moe"