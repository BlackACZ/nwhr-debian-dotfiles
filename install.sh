#!/bin/bash

# ============================================
# We all come from NWHR
# BSPWM Environment Installer for Debian
# With Kali Linux repositories
# Execute with: sudo ./install.sh
# ============================================

# -- Colors --
red='\e[0;31m'
green='\e[0;32m'
cyan='\e[0;36m'
yellow='\e[0;33m'
nc='\e[0m'

# -- Check root --
if [ "$(id -u)" -ne 0 ]; then
    echo -e "${red}you need root${nc}"
    exit 1
fi

# Get the real user (not root)
REAL_USER="${SUDO_USER:-$(logname)}"
REAL_HOME=$(eval echo ~"$REAL_USER")

# ============================================
# FUNCTIONS
# ============================================

install_packages() {
    local name=$1
    shift
    local packages=("$@")

    echo -e "${cyan}==> installing ${name}...${nc}"
    apt-get install -y "${packages[@]}"

    if [ $? -eq 0 ]; then
        echo -e "${green}==> ${name} done${nc}"
    else
        echo -e "${red}==> ${name} failed${nc}"
        return 1
    fi
}

run_as_user() {
    sudo -u "$REAL_USER" "$@"
}

# ============================================
# 1. FIX SYSTEM
# ============================================

fix_system() {
    echo -e "${cyan}========================================${nc}"
    echo -e "${cyan}  [1/10] Fixing system...               ${nc}"
    echo -e "${cyan}========================================${nc}"

    # Sync clock
    timedatectl set-ntp true 2>/dev/null
    hwclock --systohc 2>/dev/null

    # Update system
    apt-get update -y
    apt-get upgrade -y
    apt-get install -y curl wget gnupg2 apt-transport-https software-properties-common ca-certificates

    echo -e "${green}==> system ready${nc}"
}

# ============================================
# 2. ADD KALI REPOS
# ============================================

add_kali_repos() {
    echo -e "${cyan}========================================${nc}"
    echo -e "${cyan}  [2/10] Adding Kali repositories...    ${nc}"
    echo -e "${cyan}========================================${nc}"

    # Add Kali GPG key
    curl -fsSL https://archive.kali.org/archive-key.asc | gpg --dearmor -o /usr/share/keyrings/kali-archive-keyring.gpg

    # Add Kali repo
    echo "deb [signed-by=/usr/share/keyrings/kali-archive-keyring.gpg] https://http.kali.org/kali kali-rolling main contrib non-free non-free-firmware" > /etc/apt/sources.list.d/kali.list

    # Set priority: Debian packages first, Kali only for tools
    cat > /etc/apt/preferences.d/kali.pref << 'EOF'
Package: *
Pin: release o=Kali
Pin-Priority: 50

Package: kali-linux-headless kali-tools-*
Pin: release o=Kali
Pin-Priority: 500
EOF

    apt-get update -y

    echo -e "${green}==> kali repos added${nc}"
}

# ============================================
# 3. INSTALL XORG
# ============================================

install_xorg() {
    echo -e "${cyan}========================================${nc}"
    echo -e "${cyan}  [3/10] Installing Xorg...             ${nc}"
    echo -e "${cyan}========================================${nc}"

    local packages=(
        xorg
        xinit
        x11-xserver-utils
        x11-utils
        x11-xkb-utils
        xdotool
        xclip
        xsel
    )
    install_packages "xorg" "${packages[@]}"
}

# ============================================
# 4. INSTALL WINDOW MANAGER
# ============================================

install_wm() {
    echo -e "${cyan}========================================${nc}"
    echo -e "${cyan}  [4/10] Installing BSPWM + sxhkd...   ${nc}"
    echo -e "${cyan}========================================${nc}"

    local packages=(
        bspwm
        sxhkd
    )
    install_packages "window manager" "${packages[@]}"
}

# ============================================
# 5. INSTALL BAR
# ============================================

install_bar() {
    echo -e "${cyan}========================================${nc}"
    echo -e "${cyan}  [5/10] Installing Polybar...          ${nc}"
    echo -e "${cyan}========================================${nc}"

    local packages=(
        polybar
    )
    install_packages "status bar" "${packages[@]}"
}

# ============================================
# 6. INSTALL TERMINAL + SHELL
# ============================================

install_terminal() {
    echo -e "${cyan}========================================${nc}"
    echo -e "${cyan}  [6/10] Installing terminal stuff...   ${nc}"
    echo -e "${cyan}========================================${nc}"

    local packages=(
        alacritty
        zsh
        zsh-autosuggestions
        zsh-syntax-highlighting
        lsd
        bat
        fastfetch
        cmatrix
    )
    install_packages "terminal" "${packages[@]}"

    # Install cava (audio visualizer) from source if not available
    if ! command -v cava &>/dev/null; then
        echo -e "${cyan}==> building cava from source...${nc}"
        apt-get install -y libfftw3-dev libasound2-dev libncursesw5-dev libpulse-dev libtool automake autoconf-archive
        local tmp_dir=$(run_as_user mktemp -d)
        run_as_user git clone https://github.com/karlstav/cava.git "$tmp_dir/cava"
        cd "$tmp_dir/cava"
        run_as_user ./autogen.sh
        run_as_user ./configure
        run_as_user make
        make install
        cd -
        rm -rf "$tmp_dir"
    fi

    # Set zsh as default shell
    chsh -s /bin/zsh "$REAL_USER"

    echo -e "${green}==> terminal stuff done${nc}"
}

# ============================================
# 7. INSTALL APPS
# ============================================

install_apps() {
    echo -e "${cyan}========================================${nc}"
    echo -e "${cyan}  [7/10] Installing apps...             ${nc}"
    echo -e "${cyan}========================================${nc}"

    local packages=(
        rofi
        picom
        feh
        dunst
        scrot
        brightnessctl
        playerctl
        git
        build-essential
        unzip
        htop
        neovim
        ranger
        fzf
        ripgrep
        tree
        net-tools
        ipcalc
    )
    install_packages "apps" "${packages[@]}"
}

# ============================================
# 8. INSTALL FONTS
# ============================================

install_fonts() {
    echo -e "${cyan}========================================${nc}"
    echo -e "${cyan}  [8/10] Installing fonts...            ${nc}"
    echo -e "${cyan}========================================${nc}"

    local packages=(
        fonts-font-awesome
        fonts-noto
        fonts-noto-color-emoji
    )
    install_packages "fonts" "${packages[@]}"

    # Install JetBrainsMono Nerd Font manually
    echo -e "${cyan}==> installing JetBrainsMono Nerd Font...${nc}"
    local font_dir="$REAL_HOME/.local/share/fonts"
    run_as_user mkdir -p "$font_dir"

    local tmp_dir=$(run_as_user mktemp -d)
    run_as_user curl -fLo "$tmp_dir/JetBrainsMono.zip" \
        "https://github.com/ryanoasis/nerd-fonts/releases/latest/download/JetBrainsMono.zip"
    run_as_user unzip -o "$tmp_dir/JetBrainsMono.zip" -d "$font_dir/JetBrainsMono"
    rm -rf "$tmp_dir"

    fc-cache -fv

    echo -e "${green}==> fonts done${nc}"
}

# ============================================
# 9. INSTALL KALI TOOLS
# ============================================

install_kali_tools() {
    echo -e "${cyan}========================================${nc}"
    echo -e "${cyan}  [9/10] Installing Kali tools...       ${nc}"
    echo -e "${cyan}========================================${nc}"

    local packages=(
        nmap
        netcat-openbsd
        whois
        dnsutils
        traceroute
        tcpdump
        aircrack-ng
        hydra
        john
        hashcat
        sqlmap
        dirb
        gobuster
        nikto
        wfuzz
        enum4linux
        smbclient
        seclists
        wordlists
        exploitdb
        metasploit-framework
        burpsuite
        wireshark
        responder
        crackmapexec
        evil-winrm
        bloodhound
        impacket-scripts
        feroxbuster
        whatweb
        wpscan
    )

    echo -e "${yellow}==> installing kali tools (this will take a while)...${nc}"

    for pkg in "${packages[@]}"; do
        echo -e "${cyan}  -> ${pkg}${nc}"
        apt-get install -y "$pkg" 2>/dev/null || echo -e "${yellow}  -> ${pkg} not available, skipping${nc}"
    done

    echo -e "${green}==> kali tools done${nc}"
}

# ============================================
# 10. INSTALL DISPLAY MANAGER
# ============================================

install_dm() {
    echo -e "${cyan}========================================${nc}"
    echo -e "${cyan}  [10/10] Installing display manager... ${nc}"
    echo -e "${cyan}========================================${nc}"

    local packages=(
        ly
    )

    # ly might not be in Debian repos, build from source
    if ! apt-get install -y ly 2>/dev/null; then
        echo -e "${yellow}==> ly not in repos, building from source...${nc}"
        apt-get install -y libpam0g-dev libxcb-xkb-dev build-essential zig
        local tmp_dir=$(run_as_user mktemp -d)
        run_as_user git clone --recurse-submodules https://github.com/fairyglade/ly.git "$tmp_dir/ly"
        cd "$tmp_dir/ly"
        make
        make install
        cd -
        rm -rf "$tmp_dir"
    fi

    systemctl enable ly.service 2>/dev/null
    systemctl disable getty@tty2.service 2>/dev/null

    echo -e "${green}==> display manager done${nc}"
}

# ============================================
# DEPLOY DOTFILES
# ============================================

deploy_dotfiles() {
    echo -e "${cyan}========================================${nc}"
    echo -e "${cyan}  Deploying dotfiles...                 ${nc}"
    echo -e "${cyan}========================================${nc}"

    # Create directories
    run_as_user mkdir -p "$REAL_HOME/.config/bspwm"
    run_as_user mkdir -p "$REAL_HOME/.config/sxhkd"
    run_as_user mkdir -p "$REAL_HOME/.config/polybar/scripts"
    run_as_user mkdir -p "$REAL_HOME/.config/picom"
    run_as_user mkdir -p "$REAL_HOME/.config/alacritty"
    run_as_user mkdir -p "$REAL_HOME/.config/rofi"
    run_as_user mkdir -p "$REAL_HOME/.config/cava"
    run_as_user mkdir -p "$REAL_HOME/bin"
    run_as_user mkdir -p "$REAL_HOME/wallpapers"
    run_as_user mkdir -p "$REAL_HOME/Pictures"

    # ==========================================
    # BSPWMRC
    # ==========================================
    cat > "$REAL_HOME/.config/bspwm/bspwmrc" << 'BSPWMRC'
#!/bin/sh

# ============================================
# NWHR BSPWM Config - Debian Edition
# ============================================

# -- Autostart -- #
pgrep -x sxhkd > /dev/null || sxhkd &
$HOME/.config/polybar/launch.sh &
picom --config $HOME/.config/picom/picom.conf &
feh --bg-fill $HOME/wallpapers/wallpaper.jpg &

# -- Auto resolution -- #
xrandr_output=$(xrandr | grep ' connected' | head -n 1 | awk '{print $1}')
xrandr_res=$(xrandr | grep ' connected' -A1 | tail -n 1 | awk '{print $1}')
xrandr --output "$xrandr_output" --mode "$xrandr_res" --rate 60

# -- Workspaces -- #
bspc monitor -d I II III IV V VI VII VIII IX X

# -- Window Config -- #
bspc config border_width            2
bspc config window_gap              8
bspc config top_padding             32
bspc config bottom_padding          0
bspc config left_padding            0
bspc config right_padding           0

bspc config split_ratio             0.52
bspc config borderless_monocle      true
bspc config gapless_monocle         true
bspc config focus_follows_pointer   true

# -- Colors (dark, subtle) -- #
bspc config normal_border_color     "#1a1a2e"
bspc config active_border_color     "#1a1a2e"
bspc config focused_border_color    "#4a4a6a"
bspc config presel_feedback_color   "#2e2e4e"

# -- Rules -- #
bspc rule -a Firefox desktop='^2'
bspc rule -a Burp\ Suite desktop='^3'
bspc rule -a Wireshark desktop='^4'
bspc rule -a Alacritty state=tiled

# -- Cursor -- #
xsetroot -cursor_name left_ptr
BSPWMRC
    chmod +x "$REAL_HOME/.config/bspwm/bspwmrc"

    # ==========================================
    # SXHKDRC
    # ==========================================
    cat > "$REAL_HOME/.config/sxhkd/sxhkdrc" << 'SXHKDRC'
# ============================================
# NWHR sxhkd Config - Debian Edition
# ============================================

# -- Terminal -- #
super + Return
    alacritty

# -- Kill window -- #
super + x
    bspc node -c

# -- Rofi launcher -- #
super + d
    rofi -show drun -theme $HOME/.config/rofi/config.rasi

# -- Quick bar (mac style) -- #
super + space
    rofi -show drun -theme $HOME/.config/rofi/quickbar.rasi

# -- Reload sxhkd -- #
super + Escape
    pkill -USR1 -x sxhkd

# -- Restart bspwm -- #
super + alt + r
    bspc wm -r

# -- Logout -- #
super + alt + q
    bspc quit

# -- Focus window -- #
super + {h,j,k,l}
    bspc node -f {west,south,north,east}

# -- Move window -- #
super + shift + {h,j,k,l}
    bspc node -s {west,south,north,east}

# -- Switch workspace -- #
super + {1-9,0}
    bspc desktop -f '^{1-9,10}'

# -- Send window to workspace -- #
super + shift + {1-9,0}
    bspc node -d '^{1-9,10}'

# -- Toggle floating -- #
super + f
    bspc node -t '~floating'

# -- Toggle fullscreen -- #
super + shift + f
    bspc node -t '~fullscreen'

# -- Resize window -- #
super + alt + {h,j,k,l}
    bspc node -z {left -20 0,bottom 0 20,top 0 -20,right 20 0}

# -- Preselect direction -- #
super + ctrl + {h,j,k,l}
    bspc node -p {west,south,north,east}

# -- Cancel preselect -- #
super + ctrl + space
    bspc node -p cancel

# -- Volume -- #
XF86AudioRaiseVolume
    pactl set-sink-volume @DEFAULT_SINK@ +5%

XF86AudioLowerVolume
    pactl set-sink-volume @DEFAULT_SINK@ -5%

XF86AudioMute
    pactl set-sink-mute @DEFAULT_SINK@ toggle

# -- Brightness -- #
XF86MonoBrightnessUp
    brightnessctl set +10%

XF86MonoBrightnessDown
    brightnessctl set 10%-

# -- Screenshot -- #
Print
    scrot "$HOME/Pictures/screenshot_%Y%m%d_%H%M%S.png" && dunstify "Screenshot saved"

shift + Print
    scrot -s "$HOME/Pictures/screenshot_%Y%m%d_%H%M%S.png" && dunstify "Screenshot saved"
SXHKDRC

    # ==========================================
    # POLYBAR CONFIG
    # ==========================================
    cat > "$REAL_HOME/.config/polybar/config.ini" << 'POLYBAR'
; ============================================
; NWHR Polybar Config - Debian / Dark Hacker
; ============================================

[colors]
background = #0a0a14
background-alt = #1a1a2e
foreground = #a0a0b8
foreground-alt = #606078
primary = #a0a0b8
accent = #5e81ac
alert = #d45e5e
green = #7ec49d
cyan = #6ecfcf
yellow = #d4b95e
magenta = #a87ec4

; ============================================
; Bar
; ============================================

[bar/main]
width = 100%
height = 26pt
offset-x = 0%
offset-y = 0%

background = ${colors.background}
foreground = ${colors.foreground}

padding-left = 1
padding-right = 1
module-margin = 1

font-0 = "JetBrainsMono Nerd Font:size=9;3"
font-1 = "JetBrainsMono Nerd Font:size=13;4"
font-2 = "Font Awesome 6 Free Solid:size=9;3"

modules-left = debian separator workspaces
modules-center = target
modules-right = ip-info separator filesystem separator date separator powermenu

cursor-click = pointer
separator =
tray-position = right
tray-padding = 4

wm-restack = bspwm

[module/separator]
type = custom/text
content = "│"
content-foreground = ${colors.foreground-alt}

; ============================================
; Left Modules
; ============================================

[module/debian]
type = custom/text
content = "%{T2} %{T-}"
content-foreground = ${colors.alert}

[module/workspaces]
type = internal/bspwm

label-focused = %icon%
label-focused-foreground = ${colors.primary}
label-focused-background = ${colors.background-alt}
label-focused-padding = 1

label-occupied = %icon%
label-occupied-foreground = ${colors.foreground-alt}
label-occupied-padding = 1

label-urgent = %icon%
label-urgent-foreground = ${colors.alert}
label-urgent-padding = 1

label-empty = %icon%
label-empty-foreground = #2a2a3e
label-empty-padding = 1

ws-icon-0 = I;
ws-icon-1 = II;
ws-icon-2 = III;󰈹
ws-icon-3 = IV;
ws-icon-4 = V;
ws-icon-5 = VI;󰙯
ws-icon-6 = VII;
ws-icon-7 = VIII;
ws-icon-8 = IX;
ws-icon-9 = X;

; ============================================
; Center Module - Target
; ============================================

[module/target]
type = custom/script
exec = $HOME/.config/polybar/scripts/target.sh
interval = 2
format-foreground = ${colors.alert}
format-prefix = "󰓾 "
format-prefix-foreground = ${colors.alert}

; ============================================
; Right Modules
; ============================================

[module/ip-info]
type = custom/script
exec = $HOME/.config/polybar/scripts/ip-info.sh
interval = 5
click-left = $HOME/.config/polybar/scripts/ip-info.sh --toggle
click-right = $HOME/.config/polybar/scripts/ip-info.sh --copy
format-prefix = "󰈀 "
format-prefix-foreground = ${colors.cyan}

[module/filesystem]
type = internal/fs
mount-0 = /
interval = 30
label-mounted = "󰋊 %free%"
label-mounted-foreground = ${colors.green}
label-unmounted = "󰋊 N/A"

[module/date]
type = internal/date
interval = 1
date = "%d/%m/%Y"
time = "%H:%M"
label = "󰥔 %date%  %time%"
label-foreground = ${colors.foreground}

[module/powermenu]
type = custom/text
content = "⏻"
content-foreground = ${colors.alert}
click-left = rofi -show power-menu -modi power-menu:$HOME/.config/rofi/powermenu.sh
POLYBAR

    # ==========================================
    # POLYBAR LAUNCH
    # ==========================================
    cat > "$REAL_HOME/.config/polybar/launch.sh" << 'LAUNCH'
#!/bin/bash
killall -q polybar
while pgrep -u $UID -x polybar >/dev/null; do sleep 1; done
polybar main -c $HOME/.config/polybar/config.ini &
LAUNCH
    chmod +x "$REAL_HOME/.config/polybar/launch.sh"

    # ==========================================
    # POLYBAR SCRIPTS
    # ==========================================
    cat > "$REAL_HOME/.config/polybar/scripts/target.sh" << 'TARGET_SCRIPT'
#!/bin/bash
TARGET_FILE="/tmp/target"
if [ -f "$TARGET_FILE" ]; then
    ip=$(head -n 1 "$TARGET_FILE")
    name=$(sed -n '2p' "$TARGET_FILE")
    if [ -n "$name" ]; then
        echo "$ip - $name"
    else
        echo "$ip"
    fi
else
    echo "No target"
fi
TARGET_SCRIPT
    chmod +x "$REAL_HOME/.config/polybar/scripts/target.sh"

    cat > "$REAL_HOME/.config/polybar/scripts/ip-info.sh" << 'IP_SCRIPT'
#!/bin/bash
STATE_FILE="/tmp/ip-info-state"

get_lan() {
    ip -4 addr show scope global | grep -oP '(?<=inet\s)\d+(\.\d+){3}' | head -n 1
}

get_wan() {
    curl -s --max-time 3 ifconfig.me 2>/dev/null || echo "N/A"
}

[ ! -f "$STATE_FILE" ] && echo "lan" > "$STATE_FILE"
state=$(cat "$STATE_FILE")

case "$1" in
    --toggle)
        if [ "$state" = "lan" ]; then
            echo "wan" > "$STATE_FILE"
        else
            echo "lan" > "$STATE_FILE"
        fi
        ;;
    --copy)
        if [ "$state" = "lan" ]; then
            get_lan | xclip -selection clipboard
            dunstify "LAN IP copied"
        else
            get_wan | xclip -selection clipboard
            dunstify "WAN IP copied"
        fi
        ;;
    *)
        if [ "$state" = "lan" ]; then
            ip=$(get_lan)
            echo "LAN: ${ip:-N/A}"
        else
            ip=$(get_wan)
            echo "WAN: ${ip:-N/A}"
        fi
        ;;
esac
IP_SCRIPT
    chmod +x "$REAL_HOME/.config/polybar/scripts/ip-info.sh"

    # ==========================================
    # PICOM
    # ==========================================
    cat > "$REAL_HOME/.config/picom/picom.conf" << 'PICOM'
# NWHR Picom - Dark, clean, no bullshit
backend = "glx";
vsync = true;

# Rounded corners
corner-radius = 10;
rounded-corners-exclude = [
    "class_g = 'Polybar'"
];

# Transparency
inactive-opacity = 0.85;
active-opacity = 0.92;
frame-opacity = 1.0;
inactive-opacity-override = false;

opacity-rule = [
    "100:class_g = 'Rofi'",
    "95:class_g = 'Alacritty' && focused",
    "85:class_g = 'Alacritty' && !focused"
];

# Fading
fading = true;
fade-in-step = 0.04;
fade-out-step = 0.04;
fade-delta = 4;

# NO shadows
shadow = false;

# NO blur
blur-method = "none";
PICOM

    # ==========================================
    # ALACRITTY
    # ==========================================
    cat > "$REAL_HOME/.config/alacritty/alacritty.toml" << 'ALACRITTY'
[window]
padding = { x = 15, y = 15 }
opacity = 0.88
decorations = "None"

[font]
size = 10.0

[font.normal]
family = "JetBrainsMono Nerd Font"
style = "Regular"

[font.bold]
family = "JetBrainsMono Nerd Font"
style = "Bold"

[font.italic]
family = "JetBrainsMono Nerd Font"
style = "Italic"

# -- NWHR Dark Hacker Colors -- #
[colors.primary]
background = "#0a0a14"
foreground = "#a0a0b8"

[colors.cursor]
text = "#0a0a14"
cursor = "#a0a0b8"

[colors.normal]
black   = "#1a1a2e"
red     = "#d45e5e"
green   = "#7ec49d"
yellow  = "#d4b95e"
blue    = "#5e81ac"
magenta = "#a87ec4"
cyan    = "#6ecfcf"
white   = "#a0a0b8"

[colors.bright]
black   = "#3a3a5e"
red     = "#e87575"
green   = "#98d4b2"
yellow  = "#e8d47a"
blue    = "#7a9cc4"
magenta = "#c49dd4"
cyan    = "#8ee8e8"
white   = "#d0d0e8"

[keyboard]
bindings = []
ALACRITTY

    # ==========================================
    # ROFI MAIN
    # ==========================================
    cat > "$REAL_HOME/.config/rofi/config.rasi" << 'ROFI'
configuration {
    modi: "drun,run,window";
    show-icons: true;
    icon-theme: "Papirus-Dark";
    font: "JetBrainsMono Nerd Font 11";
    display-drun: "  Apps";
    display-run: "  Run";
    display-window: "  Windows";
}

* {
    bg:       #0a0a14ee;
    bg-alt:   #1a1a2eff;
    fg:       #a0a0b8ff;
    fg-alt:   #606078ff;
    accent:   #5e81acff;
    urgent:   #d45e5eff;
    background-color: transparent;
    text-color: @fg;
}

window {
    width: 500px;
    background-color: @bg;
    border: 2px;
    border-color: @bg-alt;
    border-radius: 12px;
    padding: 20px;
}

inputbar {
    children: [prompt, entry];
    background-color: @bg-alt;
    border-radius: 8px;
    padding: 10px;
    spacing: 10px;
}

prompt { text-color: @accent; }

entry {
    placeholder: "search...";
    placeholder-color: @fg-alt;
}

listview {
    lines: 7;
    columns: 1;
    spacing: 5px;
    padding: 10px 0 0 0;
}

element {
    padding: 8px;
    border-radius: 6px;
}

element selected {
    background-color: @bg-alt;
    text-color: @fg;
}

element-icon {
    size: 24px;
    margin: 0 10px 0 0;
}
ROFI

    # ==========================================
    # ROFI QUICKBAR
    # ==========================================
    cat > "$REAL_HOME/.config/rofi/quickbar.rasi" << 'QUICKBAR'
configuration {
    modi: "drun";
    show-icons: true;
    icon-theme: "Papirus-Dark";
    font: "JetBrainsMono Nerd Font 11";
    display-drun: "";
}

* {
    bg:       #0a0a14ee;
    bg-alt:   #1a1a2eff;
    fg:       #a0a0b8ff;
    fg-alt:   #606078ff;
    accent:   #5e81acff;
    background-color: transparent;
    text-color: @fg;
}

window {
    anchor: south;
    location: south;
    width: 600px;
    y-offset: -20px;
    background-color: @bg;
    border: 2px;
    border-color: @bg-alt;
    border-radius: 16px;
    padding: 15px;
}

inputbar {
    children: [entry];
    background-color: @bg-alt;
    border-radius: 10px;
    padding: 10px 15px;
}

entry {
    placeholder: "quick launch...";
    placeholder-color: @fg-alt;
}

listview {
    lines: 1;
    columns: 6;
    spacing: 10px;
    padding: 15px 0 0 0;
    layout: horizontal;
}

element {
    padding: 15px;
    border-radius: 12px;
    orientation: vertical;
}

element selected { background-color: @bg-alt; }

element-icon {
    size: 40px;
    horizontal-align: 0.5;
}

element-text {
    horizontal-align: 0.5;
    font: "JetBrainsMono Nerd Font 8";
}
QUICKBAR

    # ==========================================
    # ROFI POWERMENU
    # ==========================================
    cat > "$REAL_HOME/.config/rofi/powermenu.sh" << 'POWERMENU'
#!/bin/bash
case "$1" in
    "⏻ Shutdown") systemctl poweroff ;;
    " Reboot") systemctl reboot ;;
    "󰍃 Logout") bspc quit ;;
    "󰒲 Suspend") systemctl suspend ;;
esac
echo "⏻ Shutdown"
echo " Reboot"
echo "󰍃 Logout"
echo "󰒲 Suspend"
POWERMENU
    chmod +x "$REAL_HOME/.config/rofi/powermenu.sh"

    # ==========================================
    # CAVA CONFIG
    # ==========================================
    cat > "$REAL_HOME/.config/cava/config" << 'CAVA'
[general]
bars = 50
bar_width = 2
bar_spacing = 1

[color]
gradient = 1
gradient_count = 4
gradient_color_1 = '#1a1a2e'
gradient_color_2 = '#3a3a5e'
gradient_color_3 = '#5e81ac'
gradient_color_4 = '#a0a0b8'

[smoothing]
noise_reduction = 77
CAVA

    # ==========================================
    # BIN SCRIPTS
    # ==========================================
    cat > "$REAL_HOME/bin/set-target" << 'SET_TARGET'
#!/bin/bash
TARGET_FILE="/tmp/target"
TARGET_DATA="$HOME/.targets"

if [ -z "$1" ]; then
    echo "Usage: set-target <ip> [name] [flag/password]"
    exit 1
fi

ip="$1"
name="${2:-}"
flag="${3:-}"

echo "$ip" > "$TARGET_FILE"
[ -n "$name" ] && echo "$name" >> "$TARGET_FILE"

mkdir -p "$(dirname "$TARGET_DATA")"
echo "$(date '+%Y-%m-%d %H:%M') | $ip | $name | $flag" >> "$TARGET_DATA"

echo "Target set: $ip ${name:+($name)} ${flag:+[flag: $flag]}"
SET_TARGET
    chmod +x "$REAL_HOME/bin/set-target"

    cat > "$REAL_HOME/bin/clear-target" << 'CLEAR_TARGET'
#!/bin/bash
TARGET_FILE="/tmp/target"
if [ -f "$TARGET_FILE" ]; then
    rm "$TARGET_FILE"
    echo "Target cleared"
else
    echo "No target set"
fi
CLEAR_TARGET
    chmod +x "$REAL_HOME/bin/clear-target"

    # ==========================================
    # ZSHRC
    # ==========================================
    cat > "$REAL_HOME/.zshrc" << 'ZSHRC'
# ============================================
# NWHR Zsh Config - Debian Edition
# ============================================

# -- History -- #
HISTFILE=~/.zsh_history
HISTSIZE=5000
SAVEHIST=5000
setopt appendhistory share_history

# -- Prompt -- #
if [ "$(id -u)" -eq 0 ]; then
    DISTRO_ICON="%F{red} %f"
else
    DISTRO_ICON="%F{blue} %f"
fi

PROMPT='${DISTRO_ICON}%F{#606078}│%f %F{cyan}%m%f %F{#606078}│%f %F{green}%n%f %F{#606078}│%f %(~.%F{yellow} ~%f.%F{yellow} %1~%f) %F{#606078}❯%f '

# -- Aliases -- #
alias ls='lsd -l'
alias la='lsd -la'
alias ll='lsd -l'
alias lt='lsd --tree'
alias cat='batcat --color=always --style=plain'

alias grep='grep --color=auto'
alias mkdir='mkdir -pv'
alias cp='cp -iv'
alias mv='mv -iv'
alias rm='rm -iv'

alias cls='clear'
alias q='exit'
alias update='sudo apt update && sudo apt upgrade -y'

# -- Target aliases -- #
alias set-target='$HOME/bin/set-target'
alias clear-target='$HOME/bin/clear-target'
alias targets='cat $HOME/.targets 2>/dev/null || echo "No targets saved"'

# -- Pentesting quick aliases -- #
alias serve='python3 -m http.server 80'
alias listen='rlwrap nc -nlvp'
alias myip='curl -s ifconfig.me && echo'
alias scan='nmap -sC -sV'

# -- Path -- #
export PATH="$HOME/bin:$PATH"

# -- Plugins -- #
source /usr/share/zsh-autosuggestions/zsh-autosuggestions.zsh 2>/dev/null
source /usr/share/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh 2>/dev/null

ZSH_AUTOSUGGEST_HIGHLIGHT_STYLE='fg=#3a3a5e'

# -- Key bindings -- #
bindkey '^[[A' up-line-or-search
bindkey '^[[B' down-line-or-search
bindkey '^[[3~' delete-char
bindkey '^[[H' beginning-of-line
bindkey '^[[F' end-of-line

# -- Completion -- #
autoload -Uz compinit
compinit
zstyle ':completion:*' menu select
zstyle ':completion:*' matcher-list 'm:{a-z}={A-Z}'
ZSHRC

    # ==========================================
    # XINITRC
    # ==========================================
    cat > "$REAL_HOME/.xinitrc" << 'XINITRC'
#!/bin/sh
[ -f ~/.Xresources ] && xrdb -merge ~/.Xresources
exec bspwm
XINITRC

    # Fix ownership
    chown -R "$REAL_USER:$REAL_USER" "$REAL_HOME/.config"
    chown -R "$REAL_USER:$REAL_USER" "$REAL_HOME/.zshrc"
    chown -R "$REAL_USER:$REAL_USER" "$REAL_HOME/.xinitrc"
    chown -R "$REAL_USER:$REAL_USER" "$REAL_HOME/bin"
    chown -R "$REAL_USER:$REAL_USER" "$REAL_HOME/wallpapers"

    echo -e "${green}==> dotfiles deployed${nc}"
}

# ============================================
# MAIN
# ============================================

main() {
    echo ""
    echo -e "${cyan}========================================${nc}"
    echo -e "${cyan}   NWHR BSPWM Installer - Debian        ${nc}"
    echo -e "${cyan}   with Kali Linux tools                 ${nc}"
    echo -e "${cyan}========================================${nc}"
    echo ""

    fix_system
    add_kali_repos
    install_xorg
    install_wm
    install_bar
    install_terminal
    install_apps
    install_fonts
    install_kali_tools
    install_dm
    deploy_dotfiles

    echo ""
    echo -e "${green}========================================${nc}"
    echo -e "${green}  we're done with this shit...          ${nc}"
    echo -e "${green}========================================${nc}"
    echo ""
    echo -e "${yellow}now:${nc}"
    echo -e "${yellow}  1. add a wallpaper to ~/wallpapers/wallpaper.jpg${nc}"
    echo -e "${yellow}  2. reboot${nc}"
    echo -e "${yellow}  3. ly will start, login${nc}"
    echo -e "${yellow}  4. enjoy your rice${nc}"
    echo ""
    echo -e "${cyan}pentesting:${nc}"
    echo -e "${cyan}  set-target 10.10.10.5 machine flag{here}${nc}"
    echo -e "${cyan}  clear-target${nc}"
    echo -e "${cyan}  targets${nc}"
    echo -e "${cyan}  scan 10.10.10.5${nc}"
    echo -e "${cyan}  listen 4444${nc}"
    echo -e "${cyan}  serve${nc}"
    echo ""
}

main