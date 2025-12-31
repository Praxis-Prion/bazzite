#!/usr/bin/env bash
# Master script to mount, unmount, verify NAS automount setup on Bazzite with menu loop

set -euo pipefail

# --- Configuration ---
MOUNT_PATH="/var/mnt/nas"
CREDENTIAL_FILE="/etc/samba/nas-homes.creds"
MOUNT_UNIT="var-mnt-nas.mount"
AUTOMOUNT_UNIT="var-mnt-nas.automount"
NAS_HOST="nas40ccf8.local"
NAS_SHARE="homes/admin"
NAS_USERNAME="admin"

# --- Functions ---
mount_nas() {
    echo "=== NAS Mount Setup ==="

    # User inputs NAS password
    read -p "Enter password for $NAS_USERNAME@$NAS_HOST: " NAS_PASSWORD
    echo ""

    # Create credential file so password is not stored in script
    echo "Creating credentials file..."
    sudo mkdir -p /etc/samba
    sudo tee "$CREDENTIAL_FILE" >/dev/null <<EOF
username=$NAS_USERNAME
password=$NAS_PASSWORD
EOF

    # Set security permissions
    sudo chmod 600 "$CREDENTIAL_FILE"

    # Creates the mount unit which defines how and where the NAS is mounted
    echo "Creating mount directory..."
    sudo mkdir -p "$MOUNT_PATH"

    echo "Creating systemd mount unit..."
    sudo tee "/etc/systemd/system/$MOUNT_UNIT" >/dev/null <<EOF
[Unit]
Description=NAS Homes/admin SMB Mount
After=network-online.target
Wants=network-online.target

[Mount]
What=//$NAS_HOST/$NAS_SHARE
Where=$MOUNT_PATH
Type=cifs
Options=credentials=$CREDENTIAL_FILE,uid=1000,gid=1000,noacl,noperm,soft,_netdev,serverino,iocharset=utf8,actimeo=1
TimeoutSec=30

[Install]
WantedBy=multi-user.target
EOF

    # Creates the auto-mount unit to defines when the mount should occur
    echo "Creating systemd automount unit..."
    sudo tee "/etc/systemd/system/$AUTOMOUNT_UNIT" >/dev/null <<EOF
[Unit]
Description=Automount NAS Homes

[Automount]
Where=$MOUNT_PATH

[Install]
WantedBy=multi-user.target
EOF

    # Adds auto mount to systemctl so that we will automatically mount after every boot
    echo "Reloading systemd and enabling automount..."
    sudo systemctl daemon-reload
    sudo systemctl enable "$AUTOMOUNT_UNIT"
    sudo systemctl start "$AUTOMOUNT_UNIT"

    echo "✅ NAS setup complete! Access with: cd $MOUNT_PATH"
}

unmount_nas() {
    echo "=== NAS Unmount / Cleanup ==="
    echo ""
    echo "* Disabling automount in systemctl"
    sudo systemctl stop "$AUTOMOUNT_UNIT" || true
    sudo systemctl disable "$AUTOMOUNT_UNIT" || true
    echo "* Unmounting"
    sudo umount "$MOUNT_PATH" || true
    echo "* Deleting mount unit and automount unit"
    sudo rm -f "/etc/systemd/system/$MOUNT_UNIT" "/etc/systemd/system/$AUTOMOUNT_UNIT"
    sudo systemctl daemon-reload
    echo "* Removing credential file"
    sudo rm -f "$CREDENTIAL_FILE"
    echo "* Deleting old mount path"
    sudo rmdir "$MOUNT_PATH" 2>/dev/null || true
    echo "✅ NAS cleanup complete"
}

verify_nas() {
    echo "=== Verifying NAS Setup ==="

    if mount | grep -q "$MOUNT_PATH"; then
        echo "✅ NAS is currently mounted at $MOUNT_PATH"
    else
        echo "⚠️ NAS is not mounted at $MOUNT_PATH (expected if unmounted)"
    fi

    echo "=== Checking systemd automount unit ==="
    if systemctl is-enabled "$AUTOMOUNT_UNIT" &>/dev/null; then
        echo "✅ Automount unit is enabled and exists"
    else
        echo "⚠️ Automount unit not found or not enabled"
    fi

    echo "=== Checking credentials file ==="
    if [ -f "$CREDENTIAL_FILE" ]; then
        ls -l "$CREDENTIAL_FILE"
        echo "✅ Credential file exists"
    else
        echo "⚠️ Credentials file not found (expected if unmounted)"
    fi

    echo "=== Checking mount directory existence ==="
    if [ -d "$MOUNT_PATH" ]; then
        echo "Directory exists: $MOUNT_PATH"
        echo "✅ Mount directory exists"
    else
        echo "⚠️ Mount directory does not exist"
    fi

    echo "=== Quick test access (triggers automount if mounted) ==="
    if [ -d "$MOUNT_PATH" ]; then
        echo "Listing contents of $MOUNT_PATH..."
        if ls "$MOUNT_PATH" &>/dev/null; then
            ls "$MOUNT_PATH"
            echo "✅ NAS access successful"
        else
            echo "⚠️ Could not access NAS — possible wrong credentials or offline"
        fi
    fi

    echo "=== Verification complete ==="
}


# --- Menu Loop ---
while true; do
    echo ""
    echo "==================================="
    echo "QNAP TS-230 NAS Mounter for Bazzite"
    echo "==================================="
    echo ""
    echo "Select an option:"
    echo "1) Mount NAS"
    echo "2) Unmount NAS"
    echo "3) Verify NAS"
    echo "4) Exit"
    read -p "Enter choice [1-4]: " choice

    case "$choice" in
        1) mount_nas ;;
        2) unmount_nas ;;
        3) verify_nas ;;
        4) echo "Exiting."; exit 0 ;;
        *) echo "Invalid choice, please select 1-4." ;;
    esac
done
