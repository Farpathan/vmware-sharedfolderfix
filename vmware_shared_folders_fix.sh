#!/bin/bash
set -euo pipefail

# --- Config ---
MOUNT_POINT="/mnt/hgfs"
FSTAB_PATH="/etc/fstab"
FSTAB_ENTRY="vmhgfs-fuse ${MOUNT_POINT} fuse defaults,allow_other,_netdev 0 0"
GTK_BOOKMARKS_PATH=".config/gtk-3.0/bookmarks"

INTERACTIVE=true
REAL_USER="${SUDO_USER:-$(logname 2>/dev/null || echo "")}"
USER_HOME=""
[ -n "$REAL_USER" ] && USER_HOME=$(getent passwd "$REAL_USER" | cut -d: -f6)

log_info() {
    echo "[INFO] $1"
}

log_warn() {
    echo "[WARN] $1" >&2
}

log_error() {
    echo "[ERROR] $1" >&2
}

usage() {
    echo "Usage: $(basename "$0") [OPTIONS]"
    echo "  -y, --yes    Non-interactive mode (auto-confirm actions)"
    echo "  -h, --help   Display this help message"
    exit 0
}

check_root() {
    if [[ "$EUID" -ne 0 ]]; then
        log_error "This script must be run as root. Please use sudo."
        exit 1
    fi
}

check_dependencies() {
    if ! command -v vmhgfs-fuse &> /dev/null; then
        log_error "vmhgfs-fuse not found. Please install vmware-tools."
        exit 1
    fi
}

backup_file() {
    local file_path="$1"
    if [[ -f "$file_path" ]]; then
        local backup_path="${file_path}.bak.$(date +%s)"
        cp "$file_path" "$backup_path"
        log_info "Backed up $file_path to $backup_path"
    fi
}

configure_mount() {
    if [[ ! -d "$MOUNT_POINT" ]]; then
        mkdir -p "$MOUNT_POINT"
        log_info "Created mount point: $MOUNT_POINT"
    else
        log_info "Mount point exists: $MOUNT_POINT"
    fi

    if grep -qF "vmhgfs-fuse ${MOUNT_POINT}" "$FSTAB_PATH"; then
        log_info "Entry already exists in $FSTAB_PATH. Skipping."
    else
        backup_file "$FSTAB_PATH"
        echo "$FSTAB_ENTRY" >> "$FSTAB_PATH"
        log_info "Added configuration to $FSTAB_PATH"
        
        if mount "$MOUNT_POINT"; then
             log_info "Successfully mounted shared folders."
        else
             log_warn "Mount attempt failed. A reboot may be required."
        fi
    fi
}

configure_bookmark() {
    if [[ -z "$REAL_USER" || -z "$USER_HOME" ]]; then
        log_warn "Could not detect non-root user. Skipping bookmark."
        return
    fi

    local bookmark_file="$USER_HOME/$GTK_BOOKMARKS_PATH"
    local bookmark_entry="file://$MOUNT_POINT VMware Shared Folders"

    if [[ "$INTERACTIVE" == true ]]; then
        read -r -p "Add file manager bookmark for $REAL_USER? [y/N]: " response
        [[ ! "$response" =~ ^[Yy]$ ]] && return
    fi

    if [[ ! -d "$(dirname "$bookmark_file")" ]]; then
        mkdir -p "$(dirname "$bookmark_file")"
        chown "$REAL_USER:$(id -gn "$REAL_USER")" "$(dirname "$bookmark_file")"
    fi

    if grep -qF "file://$MOUNT_POINT" "$bookmark_file" 2>/dev/null; then
        log_info "Bookmark already exists for user $REAL_USER."
    else
        echo "$bookmark_entry" >> "$bookmark_file"
        chown "$REAL_USER:$(id -gn "$REAL_USER")" "$bookmark_file"
        chmod 600 "$bookmark_file"
        log_info "Bookmark added for user $REAL_USER."
    fi
}

prompt_reboot() {
    if [[ "$INTERACTIVE" == true ]]; then
        echo "Configuration complete. A reboot is recommended."
        read -r -p "Reboot now? [y/N]: " response
        if [[ "$response" =~ ^[Yy]$ ]]; then
            reboot
        fi
    else
        log_info "Configuration complete. Please reboot manually to ensure all changes take effect."
    fi
}

# --- Main ---

while [[ $# -gt 0 ]]; do
    case "$1" in
        -y|--yes) INTERACTIVE=false; shift ;;
        -h|--help) usage ;;
        *) log_error "Unknown option: $1"; usage ;;
    esac
done

check_root
check_dependencies
configure_mount
configure_bookmark
prompt_reboot
