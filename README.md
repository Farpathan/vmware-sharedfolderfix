# VMware Shared Folders Fix

A simple script to fix VMware shared folder not displaying after installing vmware-tools

## Prerequisites

- **vmware-tools** should be installed

## Usage

1. **Grant Permission**

   ```bash
   chmod +x vmware_shared_folders_fix.sh

2. **Run The Script**

   ```bash
   sudo ./vmware_shared_folders_fix.sh
   
   # Optionally, you can use --yes to apply all configs
   sudo ./vmware_shared_folders_fix.sh --yes
