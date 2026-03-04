#!/bin/bash

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
MAGENTA='\033[0;35m'
BOLD='\033[1m'
DIM='\033[2m'
NC='\033[0m'

info()    { echo -e "${CYAN}${BOLD}  --> ${NC}${BOLD}$*${NC}"; }
success() { echo -e "${GREEN}${BOLD}  --> $*${NC}"; }
warn()    { echo -e "${YELLOW}${BOLD}  [!] $*${NC}"; }
error()   { echo -e "${RED}${BOLD}  [x] $*${NC}"; exit 1; }
section() { echo -e "\n${MAGENTA}${BOLD}== $* ==${NC}\n"; }
divider() { echo -e "${DIM}  ------------------------------------${NC}"; }

banner() {
    clear
    echo -e "${CYAN}${BOLD}"
    echo "  +------------------------------------------+"
    echo "  |       ROM Builder - Tree Adapter         |"
    echo "  |   Auto-adapts device trees for any ROM   |"
    echo "  |              By Kultrinhaa_              |"
    echo "  +------------------------------------------+"
    echo -e "${NC}"
}

arrow_menu() {
    local title="$1"; shift
    local items=("$@")
    local count=${#items[@]}
    local current=0

    tput civis 2>/dev/null
    echo -e "${BOLD}${CYAN}  $title${NC}"
    divider

    _draw_single() {
        for ((i = 0; i < count; i++)); do
            tput el 2>/dev/null
            if [ "$i" -eq "$current" ]; then
                echo -e "  ${GREEN}${BOLD}>  ${items[$i]}${NC}  ${DIM}<--${NC}"
            else
                echo -e "     ${DIM}${items[$i]}${NC}"
            fi
        done
    }

    _draw_single
    while true; do
        local key seq
        IFS= read -rsn1 key 2>/dev/null
        if [[ "$key" == $'\x1b' ]]; then
            IFS= read -rsn2 -t 0.05 seq 2>/dev/null
            case "$seq" in
                '[A') current=$(( current - 1 )); [[ $current -lt 0 ]] && current=$(( count - 1 )) ;;
                '[B') current=$(( current + 1 )); [[ $current -ge $count ]] && current=0 ;;
            esac
        elif [[ "$key" == '' || "$key" == $'\n' ]]; then
            break
        fi
        tput cuu "$count" 2>/dev/null
        _draw_single
    done

    tput cnorm 2>/dev/null
    echo ""
    MENU_RESULT="${items[$current]}"
}

multi_select_menu() {
    local title="$1"; shift
    local items=("$@")
    local count=${#items[@]}
    local current=0
    local selected=()
    for ((i = 0; i < count; i++)); do selected+=("0"); done

    tput civis 2>/dev/null
    echo -e "${BOLD}${CYAN}  $title${NC}"
    echo -e "  ${DIM}(arrows to navigate, SPACE to select, ENTER to confirm)${NC}"
    divider

    _draw_multi() {
        for ((i = 0; i < count; i++)); do
            tput el 2>/dev/null
            local check=" "
            [[ "${selected[$i]}" == "1" ]] && check="${GREEN}x${NC}"
            if [ "$i" -eq "$current" ]; then
                echo -e "  ${GREEN}${BOLD}>${NC} [${check}] ${BOLD}${items[$i]}${NC}  ${DIM}<--${NC}"
            else
                echo -e "     [${check}] ${DIM}${items[$i]}${NC}"
            fi
        done
    }

    _draw_multi
    while true; do
        local key seq
        IFS= read -rsn1 key 2>/dev/null
        if [[ "$key" == $'\x1b' ]]; then
            IFS= read -rsn2 -t 0.05 seq 2>/dev/null
            case "$seq" in
                '[A') current=$(( current - 1 )); [[ $current -lt 0 ]] && current=$(( count - 1 )) ;;
                '[B') current=$(( current + 1 )); [[ $current -ge $count ]] && current=0 ;;
            esac
        elif [[ "$key" == ' ' ]]; then
            [[ "${selected[$current]}" == "1" ]] && selected[$current]="0" || selected[$current]="1"
        elif [[ "$key" == '' || "$key" == $'\n' ]]; then
            break
        fi
        tput cuu "$count" 2>/dev/null
        _draw_multi
    done

    tput cnorm 2>/dev/null
    echo ""

    MENU_RESULTS=()
    for ((i = 0; i < count; i++)); do
        [[ "${selected[$i]}" == "1" ]] && MENU_RESULTS+=("${items[$i]}")
    done
    if [ ${#MENU_RESULTS[@]} -eq 0 ]; then
        warn "Nothing selected. Using current: ${items[$current]}"
        MENU_RESULTS+=("${items[$current]}")
    fi
}

yes_no_menu() {
    arrow_menu "$1" "Yes" "No"
}

detect_rom() {
    section "Detecting ROM"
    [ ! -d "vendor" ] && error "vendor/ not found. Run this script from the Android source root."

    declare -gA ROM_MAP=(
        ["lineage"]="lineage" ["voltage"]="voltage" ["pixel"]="pixel"
        ["evolution"]="ev"    ["spark"]="spark"     ["aosp"]="aosp"
        ["havoc"]="havoc"     ["rising"]="rising"   ["arrow"]="arrow"
        ["bliss"]="bliss"     ["proton"]="proton"   ["axion"]="axion"
        ["crdroid"]="lineage" ["pixelexperience"]="aosp"
    )

    local found_vendors=()
    while IFS= read -r -d '' dir; do
        found_vendors+=("$(basename "$dir")")
    done < <(find vendor/ -maxdepth 1 -mindepth 1 -type d -print0 2>/dev/null)

    [ ${#found_vendors[@]} -eq 0 ] && error "No vendors found in vendor/."

    ROM_PREFIX=""
    ROM_VENDOR_DIR=""
    for v in "${found_vendors[@]}"; do
        if [[ -v "ROM_MAP[$v]" ]]; then
            ROM_PREFIX="${ROM_MAP[$v]}"
            ROM_VENDOR_DIR="$v"
            break
        fi
    done

    if [ -z "$ROM_PREFIX" ]; then
        warn "Could not auto-detect ROM."
        arrow_menu "Which vendor is the ROM?" "${found_vendors[@]}"
        ROM_VENDOR_DIR="$MENU_RESULT"
        echo -e "  ${CYAN}Enter the ROM prefix (e.g. lineage, voltage, ev):${NC}"
        printf "  ${BOLD}> ${NC}"; read -r ROM_PREFIX
    fi

    success "ROM: ${BOLD}$ROM_VENDOR_DIR${NC} -> prefix: ${BOLD}$ROM_PREFIX${NC}"
}

detect_brands() {
    section "Detecting Brands"
    [ ! -d "device" ] && error "device/ not found."

    local brands=()
    while IFS= read -r -d '' dir; do
        brands+=("$(basename "$dir")")
    done < <(find device/ -maxdepth 1 -mindepth 1 -type d -print0 2>/dev/null)

    [ ${#brands[@]} -eq 0 ] && error "No brands found in device/."

    arrow_menu "Which brand do you want to build?" "${brands[@]}"
    SELECTED_BRAND="$MENU_RESULT"
}

detect_devices() {
    section "Detecting Devices for $SELECTED_BRAND"

    local devices=()
    while IFS= read -r -d '' dir; do
        local dev
        dev=$(basename "$dir")
        devices+=("$dev")
        success "${SELECTED_BRAND}: ${BOLD}$dev${NC} found"
    done < <(find "device/$SELECTED_BRAND/" -maxdepth 1 -mindepth 1 -type d -print0 2>/dev/null)

    [ ${#devices[@]} -eq 0 ] && error "No devices found in device/$SELECTED_BRAND/."

    echo ""
    multi_select_menu "Which device trees do you want to adapt?" "${devices[@]}"
    SELECTED_DEVICES=("${MENU_RESULTS[@]}")

    echo -e "  ${GREEN}${BOLD}Selected devices:${NC}"
    for dev in "${SELECTED_DEVICES[@]}"; do
        echo -e "    ${GREEN}x${NC}  $dev"
    done
    echo ""
}

adapt_tree() {
    section "Adapting Device Tree: $(basename "$1")"
    local tree_path="$1" old_prefix="$2" new_prefix="$3"
    local changed=0 sed_count=0

    info "Looking for files with prefix '${old_prefix}' in ${tree_path}..."
    echo ""

    while IFS= read -r -d '' file; do
        local dir filename new_filename
        dir=$(dirname "$file")
        filename=$(basename "$file")
        new_filename="${new_prefix}_${filename#${old_prefix}_}"
        mv "$file" "$dir/$new_filename"
        success "Renamed: ${BOLD}$filename${NC} -> ${GREEN}$new_filename${NC}"
        changed=$(( changed + 1 ))
    done < <(find "$tree_path" -maxdepth 2 -type f -name "${old_prefix}_*.mk" -print0 2>/dev/null)

    while IFS= read -r -d '' file; do
        if grep -q "$old_prefix" "$file" 2>/dev/null; then
            local before after
            before=$(grep -n "$old_prefix" "$file" | head -5)
            sed -i "s/${old_prefix}/${new_prefix}/g" "$file"
            after=$(grep -n "$new_prefix" "$file" | head -5)
            info "Changes in ${BOLD}$(basename "$file")${NC}:"
            while IFS= read -r line; do echo -e "    ${RED}-${NC} $line"; done <<< "$before"
            while IFS= read -r line; do echo -e "    ${GREEN}+${NC} $line"; done <<< "$after"
            sed_count=$(( sed_count + 1 ))
        fi
    done < <(find "$tree_path" -maxdepth 3 -type f \( -name "*.mk" -o -name "*.bp" \) \
        ! -name "device.mk" ! -name "BoardConfig.mk" -print0 2>/dev/null)

    local ap_mk="$tree_path/AndroidProducts.mk"
    if [ -f "$ap_mk" ] && grep -q "${old_prefix}_" "$ap_mk" 2>/dev/null; then
        info "Updating ${BOLD}AndroidProducts.mk${NC}..."
        local before_ap after_ap
        before_ap=$(grep -n "${old_prefix}_" "$ap_mk")
        sed -i "s/${old_prefix}_/${new_prefix}_/g" "$ap_mk"
        after_ap=$(grep -n "${new_prefix}_" "$ap_mk")
        while IFS= read -r line; do echo -e "    ${RED}-${NC} $line"; done <<< "$before_ap"
        while IFS= read -r line; do echo -e "    ${GREEN}+${NC} $line"; done <<< "$after_ap"
        success "AndroidProducts.mk updated!"
    fi

    divider
    success "Name changed: ${RED}${old_prefix}${NC} -> ${GREEN}${new_prefix}${NC}"
    info "Renamed: ${BOLD}$changed${NC} | Substitutions: ${BOLD}$sed_count${NC}"
}

add_moto_camera() {
    section "Moto Camera 4"
    yes_no_menu "Do you want to add Moto Camera 4?"
    [ "$MENU_RESULT" == "No" ] && { info "Moto Camera 4 skipped."; return; }

    info "Cloning Moto Camera 4 repositories..."
    echo ""

    local repos=(
        "https://gitlab.com/Deivid21/proprietary_vendor_motorola_MotCamera4-bengal.git vendor/motorola/MotCamera4-bengal"
        "https://gitlab.com/Deivid21/proprietary_vendor_motorola_MotCamera-common.git vendor/motorola/MotCamera-common"
        "https://gitlab.com/Deivid21/proprietary_vendor_motorola_MotoPhotoEditor.git vendor/motorola/MotoPhotoEditor"
        "https://gitlab.com/Deivid21/proprietary_vendor_motorola_MotCamera2AI.git vendor/motorola/MotCamera2AI"
        "https://gitlab.com/Deivid21/proprietary_vendor_motorola_MotCamera3AI-bengal.git vendor/motorola/MotCamera3AI-bengal"
        "https://gitlab.com/Deivid21/proprietary_vendor_motorola_MotCameraAI-common.git vendor/motorola/MotCameraAI-common"
        "https://gitlab.com/Deivid21/proprietary_vendor_motorola_MotoSignatureApp.git vendor/motorola/MotoSignatureApp"
        "https://gitlab.com/Deivid21/proprietary_vendor_motorola_MotorolaSettingsProvider.git vendor/motorola/MotorolaSettingsProvider"
    )

    local clone_ok=0 clone_fail=0
    for entry in "${repos[@]}"; do
        local url dest repo_name
        url="${entry%% *}"
        dest="${entry##* }"
        repo_name=$(basename "$dest")

        if [ -d "$dest/.git" ]; then
            warn "Already exists: ${BOLD}$dest${NC}. Skipping."
            continue
        fi

        printf "  ${CYAN}${BOLD}Cloning${NC} ${BOLD}%s${NC}...\n" "$repo_name"
        if git clone "$url" -b android-15 "$dest" 2>&1 | sed 's/^/    /'; then
            success "Cloned: ${BOLD}$repo_name${NC}"
            clone_ok=$(( clone_ok + 1 ))
        else
            warn "Failed: ${BOLD}$repo_name${NC}"
            clone_fail=$(( clone_fail + 1 ))
        fi
        echo ""
    done

    divider
    success "Done: OK=${BOLD}$clone_ok${NC} | Failed=${BOLD}$clone_fail${NC}"
    echo ""

    if [ "$clone_fail" -gt 0 ]; then
        yes_no_menu "There were failures. Continue anyway?"
        [ "$MENU_RESULT" == "No" ] && error "Aborted."
    fi

    for dev in "${SELECTED_DEVICES[@]}"; do
        local tree_path="device/$SELECTED_BRAND/$dev"
        local device_mk="$tree_path/device.mk"

        [ ! -f "$device_mk" ] && device_mk=$(find "$tree_path" -maxdepth 2 -name "device.mk" 2>/dev/null | head -1)

        if [ -z "$device_mk" ] || [ ! -f "$device_mk" ]; then
            warn "device.mk not found for $dev. Skipping."; continue
        fi

        if grep -q "TARGET_USES_MOTCAMERA4" "$device_mk" 2>/dev/null; then
            warn "Moto Camera flags already present in $dev. Skipping."; continue
        fi

        info "Adding Moto Camera flags to ${BOLD}$dev${NC}/device.mk..."

        if [ "$KEYS_TYPE" = "crDroid keys (may not work on most ROMs)" ]; then
            cat >> "$device_mk" << EOF

# Keys
-include vendor/lineage-priv/keys/keys.mk

# Moto Camera 4
TARGET_MOTCAMERA4 := ${dev}
TARGET_USES_MOTCAMERA4 := true

\$(call inherit-product, vendor/motorola/MotCamera4-bengal/motcamera4.mk)
EOF
        else
            cat >> "$device_mk" << EOF

# Moto Camera 4
TARGET_MOTCAMERA4 := ${dev}
TARGET_USES_MOTCAMERA4 := true

\$(call inherit-product, vendor/motorola/MotCamera4-bengal/motcamera4.mk)
EOF
        fi
        success "Flags added for ${BOLD}$dev${NC}"
    done

    section "Fixing Sepolicy"
    local sep_te="hardware/motorola/sepolicy/qti/vendor/hal_camera_default.te"
    local sep_prop="hardware/motorola/sepolicy/qti/vendor/property.te"

    if [ -f "$sep_te" ]; then
        sed -i '/moto_camera_config_prop/d' "$sep_te"
        success "Fixed: ${BOLD}$sep_te${NC}"
    else
        warn "Not found: $sep_te"
    fi

    if [ -f "$sep_prop" ]; then
        sed -i '/vendor_public_prop(moto_camera_config_prop)/d' "$sep_prop"
        success "Fixed: ${BOLD}$sep_prop${NC}"
    else
        warn "Not found: $sep_prop"
    fi
}

setup_keys() {
    section "Signed Keys Setup"

    if [ ! -f "development/tools/make_key" ]; then
        warn "development/tools/make_key not found."
        warn "Keys setup requires a full repo sync. Skipping."
        KEYS_TYPE="none"
        return
    fi

    arrow_menu "Which ROM do you want to sign keys for?"         "LineageOS keys"         "crDroid keys (may not work on most ROMs)"         "GenesisOS keys"

    KEYS_TYPE="$MENU_RESULT"

    case "$KEYS_TYPE" in

    "LineageOS keys")
        local keys_dest="$HOME/.android-certs"
        if [ -d "$keys_dest" ] && [ -n "$(ls -A "$keys_dest" 2>/dev/null)" ]; then
            warn "Keys already exist at ${BOLD}$keys_dest${NC}. Skipping."
            return
        fi
        info "Generating LineageOS signing keys..."
        mkdir -p "$keys_dest"
        local subject='/C=US/ST=California/L=Mountain View/O=Android/OU=Android/CN=Android/emailAddress=android@android.com'
        for cert in bluetooth cyngn-app media networkstack nfc platform releasekey sdk_sandbox shared testcert testkey verity; do
            ./development/tools/make_key "$keys_dest/$cert" "$subject" <<< $'

' 2>&1 | sed 's/^/    /'
        done
        success "LineageOS keys generated at ${BOLD}$keys_dest${NC}"
        ;;

    "crDroid keys (may not work on most ROMs)")
        local keys_repo="https://github.com/crdroidandroid/crDroid-build-signed-script.git"
        local keys_dest="vendor/lineage-priv/keys"
        local clone_dir="/tmp/crdroid-keys-script"
        if [ -d "$keys_dest" ] && [ -n "$(ls -A "$keys_dest" 2>/dev/null)" ]; then
            warn "Keys already exist at ${BOLD}$keys_dest${NC}. Skipping."
            return
        fi
        info "Cloning crDroid signed keys script..."
        rm -rf "$clone_dir"
        if ! git clone "$keys_repo" "$clone_dir" 2>&1 | sed 's/^/    /'; then
            warn "Failed to clone keys script. Skipping."
            return
        fi
        local script_file mk_file
        script_file="$clone_dir/create-signed-env.sh"
        mk_file=$(find "$clone_dir" -maxdepth 1 -name "*.mk" | head -1)
        if [ ! -f "$script_file" ]; then
            warn "create-signed-env.sh not found in repo. Skipping."
            return
        fi
        mkdir -p "$keys_dest"
        if [ -n "$mk_file" ]; then
            mv "$mk_file" "$keys_dest/keys.mk"
            success "Moved: ${BOLD}keys.mk${NC} -> ${BOLD}$keys_dest/${NC}"
        fi
        local dest_script="$keys_dest/$(basename "$script_file")"
        mv "$script_file" "$dest_script"
        chmod +x "$dest_script"
        success "Script ready: ${BOLD}$dest_script${NC}"
        info "Running keys script (auto-confirming all prompts)..."
        echo ""
        cd "$keys_dest" || return
        yes "" | bash "$(basename "$dest_script")" 2>&1 | sed 's/^/    /'
        cd - > /dev/null
        success "crDroid keys setup done!"
        rm -rf "$clone_dir"
        ;;

    "GenesisOS keys")
        local keys_dest="vendor/$ROM_VENDOR_DIR/signing/keys"
        if [ -d "$keys_dest" ] && [ -n "$(ls -A "$keys_dest" 2>/dev/null)" ]; then
            warn "Keys already exist at ${BOLD}$keys_dest${NC}. Skipping."
            return
        fi
        info "Generating GenesisOS signing keys..."
        mkdir -p "$keys_dest"
        local subject='/C=US/ST=State/L=City/O=Android/OU=Android/CN=Android/emailAddress=android@android.com'
        for x in releasekey platform shared media networkstack verity otakey testkey sdk_sandbox bluetooth nfc; do
            ./development/tools/make_key "$keys_dest/$x" "$subject" <<< $'

' 2>&1 | sed 's/^/    /'
        done
        success "GenesisOS keys generated at ${BOLD}$keys_dest${NC}"
        ;;

    esac
}

download_vendor() {
    section "Vendor Tree"

    for dev in "${SELECTED_DEVICES[@]}"; do
        yes_no_menu "Do you have a vendor tree for ${BOLD}$dev${NC}?"
        [ "$MENU_RESULT" == "No" ] && { warn "Skipping vendor for $dev."; continue; }

        echo ""
        echo -e "  ${CYAN}How many vendor repos do you want to clone for ${BOLD}$dev${NC}?${NC}"
        printf "  ${BOLD}> ${NC}"; read -r vqty
        if ! [[ "$vqty" =~ ^[0-9]+$ ]] || [ "$vqty" -lt 1 ]; then vqty=1; fi

        for ((vn = 1; vn <= vqty; vn++)); do
            echo ""
            echo -e "  ${MAGENTA}${BOLD}-- Vendor $vn of $vqty for $dev --${NC}"

            arrow_menu "How do you want to provide the repository?" \
                "Paste the full URL" \
                "Build URL manually"

            local vendor_url vendor_branch vendor_path

            if [ "$MENU_RESULT" == "Paste the full URL" ]; then
                echo -e "  ${CYAN}Repository URL:${NC}"
                printf "  ${BOLD}> ${NC}"; read -r vendor_url

                echo -e "  ${CYAN}Branch:${NC}"
                printf "  ${BOLD}> ${NC}"; read -r vendor_branch

                echo -e "  ${CYAN}Destination path (e.g. vendor/motorola/${dev}):${NC}"
                printf "  ${BOLD}> ${NC}"; read -r vendor_path

            else
                arrow_menu "Which platform is the repository on?" "github" "gitlab"
                local platform="$MENU_RESULT"

                echo -e "  ${CYAN}Username (e.g. TheMuppets):${NC}"
                printf "  ${BOLD}> ${NC}"; read -r vendor_user

                echo -e "  ${CYAN}Repository name (e.g. proprietary_vendor_motorola_${dev}):${NC}"
                printf "  ${BOLD}> ${NC}"; read -r vendor_repo

                echo -e "  ${CYAN}Branch:${NC}"
                printf "  ${BOLD}> ${NC}"; read -r vendor_branch

                echo -e "  ${CYAN}Destination path (e.g. vendor/motorola/${dev}):${NC}"
                printf "  ${BOLD}> ${NC}"; read -r vendor_path

                vendor_url="https://${platform}.com/${vendor_user}/${vendor_repo}"
            fi

            if [ -d "$vendor_path/.git" ]; then
                warn "Already exists: ${BOLD}$vendor_path${NC}. Skipping."
                continue
            fi

            info "Cloning ${BOLD}$vendor_url${NC} -> ${BOLD}$vendor_path${NC} (branch: ${BOLD}$vendor_branch${NC})..."
            if git clone "$vendor_url" -b "$vendor_branch" "$vendor_path" 2>&1 | sed 's/^/    /'; then
                success "Vendor cloned: ${BOLD}$vendor_path${NC}"
            else
                warn "Failed to clone vendor for $dev."
            fi
            echo ""
        done
    done
}

KNOWN_BRANDS="asus bq essential fairphone google huawei leeco lenovo lge linaro motorola nextbit nothing nubia nvidia oneplus oppo razer realme samsung shift sony tcl ulefone vivo wileyfox wingtech xiaomi zte zuk"

brand_is_valid() {
    local b
    for b in $KNOWN_BRANDS; do
        [ "$b" = "$1" ] && return 0
    done
    return 1
}

read_brand() {
    local input brand_lower tries=0
    while true; do
        printf "  ${BOLD}> ${NC}"; read -r input
        brand_lower=$(echo "$input" | tr '[:upper:]' '[:lower:]')

        if brand_is_valid "$brand_lower"; then
            BRAND_RESULT="$brand_lower"
            return 0
        fi

        tries=$(( tries + 1 ))
        if [ "$tries" -lt 3 ]; then
            warn "Brand '${input}' not recognized! (attempt $tries/3)"
            echo -e "  ${DIM}Valid brands:${NC}"
            echo "  $KNOWN_BRANDS" | fold -sw 60 | sed 's/^/    /'
            echo -e "  ${CYAN}Try again:${NC}"
        else
            warn "3 attempts exhausted. Using '${brand_lower}' anyway..."
            BRAND_RESULT="$brand_lower"
            return 0
        fi
    done
}

_write_depparse() {
    cat > /tmp/_depparse.py << 'PYEOF'
import json, sys

dep_file = sys.argv[1]
fallback = sys.argv[2]

try:
    with open(dep_file) as f:
        data = json.load(f)
except Exception as e:
    sys.stderr.write("ERROR: " + str(e) + "\n")
    sys.exit(1)

for d in data:
    remote = d.get("remote", "").strip().rstrip("/")
    if not remote:
        remote = "https://github.com/LineageOS"
    elif not remote.startswith("http"):
        remote = "https://github.com/" + remote
    repo   = d.get("repository", "")
    path   = d.get("target_path", "")
    branch = d.get("branch", fallback)
    if repo and path:
        print(remote + "|" + repo + "|" + path + "|" + branch)
PYEOF
}

clone_deps() {
    local tree_path="$1"
    local fallback_branch="$2"
    local depth="${3:-0}"
    local dep_file="$tree_path/lineage.dependencies"
    local indent=""
    for ((i = 0; i < depth; i++)); do indent+="  "; done

    if [ ! -f "$dep_file" ]; then
        echo -e "${indent}${DIM}  (no lineage.dependencies in $tree_path -- end of chain)${NC}"
        return
    fi

    info "${indent}Reading deps from ${BOLD}$(basename "$tree_path")${NC}..."
    echo ""

    local deps
    deps=$(python3 /tmp/_depparse.py "$dep_file" "$fallback_branch" 2>/tmp/_dep_err.txt)

    if [ -z "$deps" ]; then
        warn "${indent}No dependencies found or failed to parse JSON."
        [ -s /tmp/_dep_err.txt ] && sed "s/^/${indent}  /" /tmp/_dep_err.txt
        return
    fi

    while IFS='|' read -r dep_remote dep_repo dep_path dep_branch; do
        [ -z "$dep_path" ] && continue
        local dep_url="${dep_remote}/${dep_repo}"

        if [ -d "${dep_path}/.git" ]; then
            echo -e "${indent}${YELLOW}${BOLD}  [!] Already exists: ${dep_path}. Checking deps...${NC}"
            clone_deps "$dep_path" "$dep_branch" $(( depth + 1 ))
            continue
        fi

        info "${indent}Cloning: ${BOLD}$dep_repo${NC} -> ${BOLD}$dep_path${NC}"
        if git clone "$dep_url" -b "$dep_branch" "$dep_path" 2>&1 | sed "s/^/${indent}    /"; then
            success "${indent}Cloned: ${BOLD}$dep_path${NC}"
            echo ""
            clone_deps "$dep_path" "$dep_branch" $(( depth + 1 ))
        else
            warn "${indent}Failed: ${BOLD}$dep_url${NC}"
        fi
        echo ""
    done <<< "$deps"
}

download_tree() {
    section "Download Device Trees"

    _write_depparse

    local devices_to_clone=()

    echo -e "  ${CYAN}${BOLD}How many device trees do you want to download?${NC}"
    printf "  ${BOLD}> ${NC}"; read -r qty
    if ! [[ "$qty" =~ ^[0-9]+$ ]] || [ "$qty" -lt 1 ]; then qty=1; fi

    for ((n = 1; n <= qty; n++)); do
        echo ""
        echo -e "  ${MAGENTA}${BOLD}-- Device $n of $qty --${NC}"

        echo -e "  ${CYAN}Brand (e.g. motorola, google, xiaomi):${NC}"
        read_brand
        local dt_brand="$BRAND_RESULT"

        echo -e "  ${CYAN}Codename (e.g. rhode, devon, hawao):${NC}"
        printf "  ${BOLD}> ${NC}"; read -r dt_device

        echo -e "  ${CYAN}LineageOS version (e.g. lineage-22.2):${NC}"
        printf "  ${BOLD}> ${NC}"; read -r dt_branch

        devices_to_clone+=("${dt_brand}|||${dt_device}|||${dt_branch}")
    done

    echo ""
    divider

    for entry in "${devices_to_clone[@]}"; do
        local brand device branch dest repo_url
        brand="${entry%%|||*}";   entry="${entry#*|||}"
        device="${entry%%|||*}"
        branch="${entry##*|||}"
        dest="device/$brand/$device"
        repo_url="https://github.com/LineageOS/android_device_${brand}_${device}"

        echo ""
        section "Cloning $brand/$device"

        if [ -d "$dest/.git" ]; then
            warn "Already exists: ${BOLD}$dest${NC}. Skipping clone."
        else
            info "Cloning ${BOLD}$repo_url${NC} (branch: ${BOLD}$branch${NC})..."
            if git clone "$repo_url" -b "$branch" "$dest" 2>&1 | sed 's/^/    /'; then
                success "Cloned: ${BOLD}$dest${NC}"
            else
                warn "Failed to clone. Check codename/version."
                continue
            fi
        fi

        echo ""
        clone_deps "$dest" "$branch" 0

        success "==== $device + dependencies cloned! ===="
        divider
    done
}

select_android_prefix() {
    section "Android Version Prefix"

    local prefixes=(
        "bp4a  (Android 16 QPR2)"
        "bp2a  (Android 16 QPR1)"
        "bp1a  (Android 16)"
        "ap4a  (Android 15 QPR3)"
        "ap3a  (Android 15 QPR2)"
        "ap2a  (Android 15 QPR1)"
        "ap1a  (Android 15)"
        "ur1a  (Android 14 QPR2)"
        "uq1a  (Android 14 QPR1)"
        "up1a  (Android 14)"
        "tq3a  (Android 13 QPR2)"
        "tq1a  (Android 13 QPR1)"
        "tp1a  (Android 13)"
        "sq3a  (Android 12 QPR3)"
        "sq1a  (Android 12 QPR1)"
        "sp1a  (Android 12)"
        "Type manually"
    )

    arrow_menu "What is the Android version prefix?" "${prefixes[@]}"

    if [ "$MENU_RESULT" == "Type manually" ]; then
        echo -e "  ${CYAN}Enter prefix (e.g. bp4a):${NC}"
        printf "  ${BOLD}> ${NC}"; read -r ANDROID_PREFIX
    else
        ANDROID_PREFIX="${MENU_RESULT%%  *}"
    fi

    success "Prefix: ${BOLD}$ANDROID_PREFIX${NC}"
}

select_variant() {
    section "Build Variant"
    arrow_menu "Which variant do you want to build?" \
        "userdebug  (recommended for testing)" \
        "user       (release, no debug)" \
        "eng        (engineering, more logs)"
    VARIANT="${MENU_RESULT%%  *}"
    success "Variant: ${BOLD}$VARIANT${NC}"
}

start_build() {
    section "Starting Build"

    local build_device
    if [ ${#SELECTED_DEVICES[@]} -gt 1 ]; then
        arrow_menu "Which device do you want to build now?" "${SELECTED_DEVICES[@]}"
        build_device="$MENU_RESULT"
    else
        build_device="${SELECTED_DEVICES[0]}"
    fi

    local lunch_target="${ROM_PREFIX}_${build_device}-${ANDROID_PREFIX}-${VARIANT}"

    echo -e "  ${BOLD}Final configuration:${NC}"
    divider
    echo -e "  ${DIM}ROM:${NC}           ${BOLD}$ROM_VENDOR_DIR${NC} (${ROM_PREFIX})"
    echo -e "  ${DIM}Brand:${NC}         ${BOLD}$SELECTED_BRAND${NC}"
    echo -e "  ${DIM}Device:${NC}        ${BOLD}$build_device${NC}"
    echo -e "  ${DIM}Android:${NC}       ${BOLD}$ANDROID_PREFIX${NC}"
    echo -e "  ${DIM}Variant:${NC}       ${BOLD}$VARIANT${NC}"
    echo -e "  ${DIM}Lunch target:${NC}  ${GREEN}${BOLD}$lunch_target${NC}"
    divider
    echo ""

    yes_no_menu "Confirm and start build?"
    [ "$MENU_RESULT" == "No" ] && { warn "Build cancelled."; exit 0; }

    info "Running: ${BOLD}. build/envsetup.sh${NC}"
    # shellcheck disable=SC1091
    . build/envsetup.sh || error "Failed to source build/envsetup.sh"

    info "Running: ${BOLD}lunch $lunch_target${NC}"
    lunch "$lunch_target" || error "Lunch failed. Check if the target exists."

    echo ""
    echo -e "  ${CYAN}${BOLD}How many threads to use? [$(nproc)]:${NC}"
    printf "  ${BOLD}> ${NC}"; read -r THREADS
    THREADS="${THREADS:-$(nproc)}"

    info "Running: ${BOLD}make bacon -j${THREADS}${NC}"
    echo ""

    if ! make bacon -j"$THREADS"; then
        warn "make bacon failed, trying make otapackage..."
        make otapackage -j"$THREADS" || error "Build failed."
    fi

    echo ""
    success "========================================"
    success "  Build completed successfully!  :)"
    success "========================================"
}

main() {
    banner

    [ ! -f "build/envsetup.sh" ] && \
        error "Run this script from the Android source root (where build/envsetup.sh is)."

    detect_rom

    yes_no_menu "Do you want to download device trees?"
    [ "$MENU_RESULT" == "Yes" ] && download_tree

    detect_brands
    detect_devices

    download_vendor

    setup_keys

    for dev in "${SELECTED_DEVICES[@]}"; do
        local tree_path="device/$SELECTED_BRAND/$dev"
        local old_prefix="lineage"
        local existing_mk
        existing_mk=$(find "$tree_path" -maxdepth 2 -name "*.mk" 2>/dev/null | head -10)
        for known in lineage voltage aosp ev rising spark havoc arrow bliss; do
            if echo "$existing_mk" | grep -q "${known}_"; then
                old_prefix="$known"; break
            fi
        done
        info "Detected prefix in ${BOLD}$dev${NC}: ${BOLD}$old_prefix${NC}"
        if [ "$old_prefix" = "$ROM_PREFIX" ]; then
            warn "Tree '$dev' already uses '$ROM_PREFIX'. Nothing to rename."
        else
            adapt_tree "$tree_path" "$old_prefix" "$ROM_PREFIX"
        fi
    done

    add_moto_camera

    select_android_prefix
    select_variant
    start_build
}

main "$@"
