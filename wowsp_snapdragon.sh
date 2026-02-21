#!/bin/bash

# AzerothCore Single Player WoW Setup Script for Termux (Snapdragon Devices Only)
# Downloads pre-compiled binaries instead of compiling from source
# Usage: curl -fsSL https://raw.githubusercontent.com/duall/singlePlayerWow-android/main/wowsp_snapdragon.sh -o ~/wowsp_snapdragon.sh && bash ~/wowsp_snapdragon.sh

set -e  # Exit on any error

SERVER_DIR="$HOME/azeroth-server"
SOURCE_DIR="$HOME/azerothcore-android"
AUTOFIX_FLAG="$SERVER_DIR/.autofix_applied"

# Binary download URLs
AUTHSERVER_URL="https://github.com/duall/singlePlayerWow-android/releases/download/snapdragon/authserver_snapdragon"
WORLDSERVER_URL="https://github.com/duall/singlePlayerWow-android/releases/download/snapdragon/worldserver_snapdragon"

# Locked commit for modules/configs
AZEROTHCORE_COMMIT="abc884520173084d5cd37b72b57b3822230dcb32"

echo "=== AzerothCore Single Player WoW Setup (Snapdragon Binary) ==="
echo "This script downloads pre-compiled binaries for Snapdragon devices"
echo ""

# Function to check if MariaDB is running
check_mariadb_running() {
    if pgrep -f "mariadbd" > /dev/null; then
        return 0
    else
        return 1
    fi
}

# Function to start MariaDB if not running
ensure_mariadb_running() {
    if ! check_mariadb_running; then
        echo "Starting MariaDB..."
        mariadbd-safe --datadir="$PREFIX/var/lib/mysql" &
        
        echo "Waiting for MariaDB to start..."
        for i in {1..30}; do
            if mariadb -u root -e "SELECT 1;" >/dev/null 2>&1; then
                print_status "MariaDB started and ready"
                break
            fi
            if [ $i -eq 30 ]; then
                print_warning "MariaDB taking longer than expected"
                echo "Continuing anyway - it might work..."
            else
                printf "."
                sleep 1
            fi
        done
    else
        print_status "MariaDB already running"
    fi
}

# Function to launch servers with autofix capability
launch_servers() {
    local attempt_autofix=true
    
    if [ -f "$AUTOFIX_FLAG" ]; then
        echo "Autofix was previously applied, launching servers directly..."
        attempt_autofix=false
    fi
    
    if [ "$attempt_autofix" = true ]; then
        echo "Starting WorldServer with auto-fix capability..."
        
        log_file="$SERVER_DIR/worldserver_output.log"
        
        cd "$SERVER_DIR"
        ./bin/worldserver > "$log_file" 2>&1 & 
        worldserver_pid=$!
        
        tail -f "$log_file" | grep -v "Deprecated program name\|use.*mariadb.*instead" & 
        tail_pid=$!
        
        echo "Monitoring WorldServer startup..."
        for check in {1..240}; do
            sleep 5
            
            if ! kill -0 "$worldserver_pid" 2>/dev/null; then
                echo ""
                echo "WorldServer process stopped. Running SQL fix..."
                kill "$tail_pid" 2>/dev/null || true
                break
            fi
            
            if grep -q "AC>" "$log_file"; then
                echo ""
                echo "WorldServer fully initialized and ready!"
                
                kill "$worldserver_pid" 2>/dev/null || true
                kill "$tail_pid" 2>/dev/null || true
                wait "$worldserver_pid" 2>/dev/null || true
                
                touch "$AUTOFIX_FLAG"
                
                sleep 3
                break
            fi
            
            if [ $((check % 3)) -eq 0 ]; then
                echo "Still waiting... (${check}0 seconds elapsed)"
            fi
        done
        
        kill "$worldserver_pid" 2>/dev/null || true
        kill "$tail_pid" 2>/dev/null || true
        wait "$worldserver_pid" 2>/dev/null || true
        
        if ! grep -q "AC>" "$log_file" 2>/dev/null; then
            echo "Running integrated SQL fix..."
            run_sql_fix
            echo "SQL fix completed. Marking autofix as applied..."
            touch "$AUTOFIX_FLAG"
        fi
        
        echo "Starting servers in tmux in 5 seconds..."
        sleep 5
    fi
    
    echo "Launching AzerothCore servers in tmux..."
    
    tmux kill-session -t azeroth 2>/dev/null || true
    
    cd "$SERVER_DIR"
    tmux new-session -d -c "$SERVER_DIR" -s azeroth './bin/authserver' \; \
         split-window -h -c "$SERVER_DIR" './bin/worldserver' \; \
         attach
}

# Enhanced integrated SQL fix function
run_sql_fix() {
    echo "=== Running Enhanced Integrated SQL Fix ==="
    
    MODULES_DIR="$SOURCE_DIR/modules"
    DB_USER="acore"
    DB_PASS="acore"
    
    echo "Searching for SQL files in: $MODULES_DIR"
    
    import_sql() {
        local file="$1"
        local database="$2"
        local relative_path="$3"
        
        echo "  Importing: $relative_path -> $database"
        if mariadb -u "$DB_USER" -p"$DB_PASS" "$database" < "$file" 2>/dev/null; then
            echo "    Success"
            return 0
        else
            echo "    Failed"
            return 1
        fi
    }
    
    if [ ! -d "$MODULES_DIR" ]; then
        echo "Warning: Modules directory not found at $MODULES_DIR"
        return 1
    fi
    
    modules_with_sql=$(find "$MODULES_DIR" -type d \( -path "*/data/sql" -o -path "*/sql" \) | sed -E 's|/(data/)?sql$||' | sort -u)
    
    if [ -z "$modules_with_sql" ]; then
        echo "No modules with SQL data found."
        return 0
    fi
    
    echo "Found modules with SQL data:"
    echo "$modules_with_sql" | sed 's|.*/||' | sed 's/^/  - /'
    echo ""
    
    total_files=0
    success_count=0
    failed_count=0
    
    for module_dir in $modules_with_sql; do
        module_name=$(basename "$module_dir")
        
        sql_dir=""
        if [ -d "$module_dir/data/sql" ]; then
            sql_dir="$module_dir/data/sql"
            echo "Processing module: $module_name (using data/sql)"
        elif [ -d "$module_dir/sql" ]; then
            sql_dir="$module_dir/sql"
            echo "Processing module: $module_name (using sql)"
        else
            echo "Warning: No SQL directory found for module $module_name"
            continue
        fi
        
        if [ -d "$sql_dir" ]; then
            db_dirs=$(find "$sql_dir" -type d -name "db-*" 2>/dev/null | sort || true)
            
            for db_dir in $db_dirs; do
                db_type=$(basename "$db_dir" | sed 's/^db-//')
                
                case "$db_type" in
                    "auth") target_db="acore_auth" ;;
                    "characters") target_db="acore_characters" ;;
                    "world") target_db="acore_world" ;;
                    *) target_db="acore_$db_type" ;;
                esac
                
                sql_files=$(find "$db_dir" -name "*.sql" 2>/dev/null || true)
                
                if [ -n "$sql_files" ]; then
                    echo "  Database '$target_db' files:"
                    while IFS= read -r file; do
                        if [ -f "$file" ]; then
                            relative_path="${file#$MODULES_DIR/}"
                            total_files=$((total_files + 1))
                            if import_sql "$file" "$target_db" "$relative_path"; then
                                success_count=$((success_count + 1))
                            else
                                failed_count=$((failed_count + 1))
                            fi
                        fi
                    done <<< "$sql_files"
                fi
            done
            
            alt_dirs=$(find "$sql_dir" -type d \( -name "world" -o -name "characters" -o -name "auth" \) 2>/dev/null | sort || true)
            
            for alt_dir in $alt_dirs; do
                dir_type=$(basename "$alt_dir")
                
                case "$dir_type" in
                    "auth") target_db="acore_auth" ;;
                    "characters") target_db="acore_characters" ;;
                    "world") target_db="acore_world" ;;
                esac
                
                sql_files=$(find "$alt_dir" -name "*.sql" 2>/dev/null || true)
                
                if [ -n "$sql_files" ]; then
                    echo "  Database '$target_db' files (alt structure):"
                    while IFS= read -r file; do
                        if [ -f "$file" ]; then
                            relative_path="${file#$MODULES_DIR/}"
                            total_files=$((total_files + 1))
                            if import_sql "$file" "$target_db" "$relative_path"; then
                                success_count=$((success_count + 1))
                            else
                                failed_count=$((failed_count + 1))
                            fi
                        fi
                    done <<< "$sql_files"
                fi
            done
        fi
        
        echo ""
    done
    
    echo "=== SQL Fix Summary ==="
    echo "Total files processed: $total_files"
    echo "Successful imports: $success_count"
    echo "Failed imports: $failed_count"
    
    if [ $failed_count -gt 0 ]; then
        echo ""
        echo "Some imports failed. This might be normal if:"
        echo "  - Files contain updates for non-existent tables"
        echo "  - Files are meant for different AzerothCore versions"
        echo "  - Dependencies between files exist"
    else
        echo ""
        echo "All SQL files imported successfully!"
    fi
}

# Function to check if a package is installed
check_package() {
    if dpkg -l | grep -q "^ii  $1 "; then
        return 0
    else
        return 1
    fi
}

# Function to check if MariaDB user exists
check_mysql_user() {
    if mariadb -u root -e "SELECT User FROM mysql.user WHERE User='acore' AND Host='localhost';" 2>/dev/null | grep -q "acore"; then
        return 0
    else
        return 1
    fi
}

# Function to print colored output
print_status() {
    echo "OK $1"
}

print_step() {
    echo ""
    echo "=== $1 ==="
}

print_warning() {
    echo "WARNING $1"
}

print_error() {
    echo "ERROR $1"
}

# Check if worldserver already exists
if [ -f "$SERVER_DIR/bin/worldserver" ]; then
    echo "AzerothCore installation found at $SERVER_DIR"
    
    echo "Checking MariaDB status..."
    ensure_mariadb_running
    
    echo "Servers are ready to launch!"
    echo ""
    echo "Starting servers in:"
    for i in 5 4 3 2 1; do
        echo "  $i..."
        sleep 1
    done
    echo ""
    
    launch_servers
    exit 0
fi

echo "Estimated time: 10-20 minutes (no compilation needed)"
echo ""

# Step 1: Snapdragon compatibility check - download and test binary before anything else
print_step "Step 1: Checking Snapdragon binary compatibility"

echo "Downloading test binary to verify device compatibility..."
mkdir -p "$SERVER_DIR/bin"

if curl -L --fail "$AUTHSERVER_URL" -o "$SERVER_DIR/bin/authserver" 2>/dev/null; then
    chmod +x "$SERVER_DIR/bin/authserver"
    print_status "Test binary downloaded"
else
    print_error "Failed to download test binary"
    echo ""
    echo "This device may not have internet access or the download URL is unavailable."
    echo "Please try again later."
    rm -rf "$SERVER_DIR"
    exit 1
fi

echo "Testing if Snapdragon binary can execute on this device..."
test_output=$("$SERVER_DIR/bin/authserver" 2>&1 || true)

if echo "$test_output" | grep -qiE "cannot execute binary file|Exec format error|SIGILL|Illegal instruction"; then
    print_error "This binary is NOT compatible with your device!"
    echo ""
    echo "The pre-compiled Snapdragon binaries cannot run on this device."
    echo "This could mean your device uses a different chipset (MediaTek, Exynos, etc.)"
    echo "or has an incompatible CPU architecture."
    echo ""
    echo "Please use the source compilation script instead:"
    echo ""
    echo "  curl -fsSL https://raw.githubusercontent.com/duall/singlePlayerWow-android/main/wowsp_cutoff.sh -o ~/wowsp_cutoff.sh && bash ~/wowsp_cutoff.sh"
    echo ""
    rm -rf "$SERVER_DIR"
    exit 1
else
    print_status "Binary is compatible with this device!"
fi

echo "Device compatibility confirmed. Proceeding with full setup..."

# Step 2: Install runtime dependencies (no build tools needed)
print_step "Step 2: Installing runtime dependencies"
PACKAGES=("git" "mariadb" "tmux" "curl" "unzip" "libc++" "boost")
MISSING_PACKAGES=()

echo "Checking for required packages..."
for package in "${PACKAGES[@]}"; do
    if ! check_package "$package"; then
        MISSING_PACKAGES+=("$package")
    fi
done

if [ ${#MISSING_PACKAGES[@]} -gt 0 ]; then
    echo "Installing missing packages: ${MISSING_PACKAGES[*]}"
    pkg update
    pkg install -y "${MISSING_PACKAGES[@]}"
    print_status "Dependencies installed"
else
    print_status "All dependencies already installed"
fi

# Step 3: Download pre-compiled binaries
print_step "Step 3: Downloading pre-compiled binaries"

# authserver was already downloaded during compatibility check
echo "authserver already downloaded from compatibility check."

echo "Downloading worldserver..."
if curl -L --fail "$WORLDSERVER_URL" -o "$SERVER_DIR/bin/worldserver"; then
    chmod +x "$SERVER_DIR/bin/worldserver"
    print_status "worldserver downloaded"
else
    print_error "Failed to download worldserver binary"
    rm -rf "$SERVER_DIR"
    exit 1
fi

print_status "Both server binaries downloaded and ready"

# Step 4: Clone source for modules (needed for SQL data and configs)
print_step "Step 4: Downloading AzerothCore source (for modules/SQL data)"
if [ ! -d "$SOURCE_DIR" ]; then
    echo "Cloning AzerothCore Android fork..."
    git clone https://github.com/duall/azerothcore-android.git "$SOURCE_DIR"
    cd "$SOURCE_DIR"
    echo "Checking out locked commit $AZEROTHCORE_COMMIT..."
    git checkout "$AZEROTHCORE_COMMIT"
    print_status "Source code downloaded and locked to commit $AZEROTHCORE_COMMIT"
else
    print_status "Source code already exists"
    cd "$SOURCE_DIR"
    CURRENT_COMMIT=$(git rev-parse HEAD)
    if [ "$CURRENT_COMMIT" != "$AZEROTHCORE_COMMIT" ]; then
        echo "Resetting to locked commit $AZEROTHCORE_COMMIT..."
        git fetch origin
        git checkout "$AZEROTHCORE_COMMIT"
        print_status "Source code locked to commit $AZEROTHCORE_COMMIT"
    else
        print_status "Source code already at correct commit"
    fi
fi

# Step 5: Clone all modules (locked to specific commits)
print_step "Step 5: Downloading AzerothCore modules"
mkdir -p "$SOURCE_DIR/modules"
cd "$SOURCE_DIR/modules"

# Remove any existing modules to ensure clean state
rm -rf mod-* 2>/dev/null || true

echo "Cloning modules with locked commits (this may take a few minutes)..."

MODULES=(
    "https://github.com/azerothcore/mod-1v1-arena.git 29748fe1cd20001d97034f533a42c034d822fc7b"
    "https://github.com/azerothcore/mod-account-achievements.git bfbe3677635feeef823057964e028e023633115a"
    "https://github.com/azerothcore/mod-auto-revive.git ce5ca7a600dbef0dec48dc6da42d374d08d6b728"
    "https://github.com/azerothcore/mod-autobalance.git 37455446fe99f073e4a6113987e3228705054639"
    "https://github.com/azerothcore/mod-better-item-reloading.git ab4fa9dc28e146e2f0730e989af2c025fac85dd5"
    "https://github.com/azerothcore/mod-boss-announcer.git d206190617552ca04540d14b1098cd3717a94c36"
    "https://github.com/azerothcore/mod-desertion-warnings.git ed1b7e26869d520b7627c289d461fbc5d040be6a"
    "https://github.com/azerothcore/mod-duel-reset.git 8fc67b6baa16cf20d6322b3710f82110dc9ee20b"
    "https://github.com/hallgaeuer/mod-dynamic-loot-rates.git 41ffb6a7c5bc78d1c062b8237a9a185892514a32"
    "https://github.com/azerothcore/mod-dynamic-xp.git 56033ee97fe400898aea057596e933062821d13e"
    "https://github.com/azerothcore/mod-emblem-transfer.git 5d9d0d9ff8c8b80fb33f6615f046b979d5efccb4"
    "https://github.com/azerothcore/mod-fireworks-on-level.git e5c58542996e0f1ad3410ebdb7cff9ed9d52e3d6"
    "https://github.com/azerothcore/mod-guildhouse.git 23b86dcc78471c50c60b3fc27e07e4cda8a3e200"
    "https://github.com/ZhengPeiRu21/mod-individual-progression.git ad2e8e4536275126d55732255e02ac5fd8533b64"
    "https://github.com/azerothcore/mod-individual-xp.git a0c60a5da285984dbe8fb028ac4676bf75e573e2"
    "https://github.com/azerothcore/mod-instance-reset.git 42ddc011dd6836ad662774472b0b214d32c3ea31"
    "https://github.com/noisiver/mod-junk-to-gold.git 2134690bb03899e5c9e44d0682e8e6abf0bbbaf2"
    "https://github.com/noisiver/mod-learnspells.git fe63752be467f325ebf283b010325e47a9fce4ff"
    "https://github.com/azerothcore/mod-low-level-rbg.git fd6077de0fd49bf2caaae3c5c4dcb857178cf7b9"
    "https://github.com/azerothcore/mod-morphsummon.git 28e347515cf97d80f296e5ca072ff2686199c6ca"
    "https://github.com/azerothcore/mod-npc-beastmaster.git eb9bdbaaabbf096a22febfbe8a0735a778d96a9e"
    "https://github.com/azerothcore/mod-npc-buffer.git 9a755a3ef6ed1f183d8c290729e0db43e174ed64"
    "https://github.com/azerothcore/mod-npc-enchanter.git 0c34e45a534d6335732f778eb15eb68bba7f8055"
    "https://github.com/Gozzim/mod-npc-spectator.git 8dc107289cf6af9b49945c2c9e6826a29e1dc5a6"
    "https://github.com/azerothcore/mod-npc-talent-template.git 43238807f12692dcba96e6cb2b7cc0ac3edcfe51"
    "https://github.com/azerothcore/mod-phased-duels.git 349db1972d44dd4b25e24d0e2f0c207bea136ce1"
    "https://github.com/DustinHendrickson/mod-player-bot-level-brackets.git 12aac35118c928e423708902f596e961456191c3"
    "https://github.com/liyunfan1223/mod-playerbots.git df3c44419de4ec447b1d73de180d3753f3bd8f4c"
    "https://github.com/azerothcore/mod-pvp-titles.git 2c7c16a4ff504cb43d60919552581833d7efcb05"
    "https://github.com/azerothcore/mod-queue-list-cache.git f10c480f8c43f7716da26150d02903933f50af40"
    "https://github.com/azerothcore/mod-quick-teleport.git 3a88ac0f294f7ce21441fb3cb3de13f87c9683eb"
    "https://github.com/azerothcore/mod-racial-trait-swap.git 99d1895617bcc1a857c166bccfd4454699f7fdc6"
    "https://github.com/azerothcore/mod-random-enchants.git 02a2e0d83b3cfad039bf1967177326aef8dd71f5"
    "https://github.com/azerothcore/mod-rdf-expansion.git c7a91c5973cda4529495b52b89375913f98726d6"
    "https://github.com/ZhengPeiRu21/mod-reagent-bank.git eceb91d636f56289f8720eea6d3c7e24db07bd43"
    "https://github.com/azerothcore/mod-reward-played-time.git fc8a07958213393dbffad035e853bdc18ab66a6e"
    "https://github.com/azerothcore/mod-solo-lfg.git 3821fe1d108ade8d2b7ad6611e41154e05864c65"
    "https://github.com/azerothcore/mod-top-arena.git 6f3a8eded4e5cd6abab730b633d5e3f0719c9a19"
    "https://github.com/azerothcore/mod-transmog.git 949cdfb0b989628064d36d95b0948f8b19ec702f"
    "https://github.com/azerothcore/mod-who-logged.git 3f439d0aa56d3a4782dee1467f1bdcb16b35aa2f"
)

FAILED_MODULES=()
for entry in "${MODULES[@]}"; do
    repo_url="${entry% *}"
    commit_hash="${entry##* }"
    module_name=$(basename "$repo_url" .git)
    
    echo "Cloning $module_name..."
    if git clone "$repo_url" 2>/dev/null; then
        cd "$module_name"
        if git checkout "$commit_hash" 2>/dev/null; then
            echo "  Locked to $commit_hash"
        else
            echo "  WARNING: Failed to checkout commit $commit_hash, using default branch"
            FAILED_MODULES+=("$module_name")
        fi
        cd "$SOURCE_DIR/modules"
    else
        FAILED_MODULES+=("$module_name")
        echo "  Failed to clone $module_name, continuing..."
    fi
done

if [ ${#FAILED_MODULES[@]} -gt 0 ]; then
    print_warning "Some modules had issues: ${FAILED_MODULES[*]}"
    echo "The server will still work, but some features may be missing."
else
    print_status "All ${#MODULES[@]} modules downloaded and locked successfully"
fi

# Step 6: Configure MariaDB
print_step "Step 6: Configuring MariaDB"

if [ ! -d "$PREFIX/var/lib/mysql/mysql" ]; then
    echo "Initializing MariaDB database..."
    mysql_install_db --datadir="$PREFIX/var/lib/mysql"
    print_status "MariaDB initialized"
else
    print_status "MariaDB already initialized"
fi

if ! grep -q "version=8.0.36" "$PREFIX/etc/my.cnf" 2>/dev/null; then
    echo "Adding MySQL version configuration..."
    echo -e "\n[mysqld]\nversion=8.0.36" >> "$PREFIX/etc/my.cnf"
    print_status "MySQL version configured"
else
    print_status "MySQL version already configured"
fi

if [ ! -L "$PREFIX/lib/libmariadb.so" ]; then
    echo "Creating MariaDB library link..."
    ln -sf "$PREFIX/lib/aarch64-linux-android/libmariadb.so" "$PREFIX/lib/libmariadb.so"
    print_status "Library link created"
else
    print_status "Library link already exists"
fi

# Step 7: Start MariaDB
print_step "Step 7: Starting MariaDB"
ensure_mariadb_running

# Step 8: Setup database user
print_step "Step 8: Setting up database user"
if ! check_mysql_user; then
    echo "Creating acore user..."
    
    for attempt in {1..10}; do
        if mariadb -u root -e "DROP USER IF EXISTS 'acore'@'localhost'; CREATE USER 'acore'@'localhost' IDENTIFIED BY 'acore';" 2>/dev/null; then
            mariadb -u root -e "GRANT ALL PRIVILEGES ON *.* TO 'acore'@'localhost';"
            print_status "Database user created and privileges granted"
            break
        else
            if [ $attempt -eq 10 ]; then
                print_error "Failed to create database user after 10 attempts"
                echo "MariaDB might still be starting. Try running the script again."
                exit 1
            else
                echo "  Attempt $attempt failed, retrying in 2 seconds..."
                sleep 2
            fi
        fi
    done
else
    print_status "Database user already exists"
fi

# Step 9: Create required databases
print_step "Step 9: Creating AzerothCore databases"
echo "Creating required databases..."
if mariadb -u acore -pacore -e "CREATE DATABASE IF NOT EXISTS acore_world; CREATE DATABASE IF NOT EXISTS acore_characters; CREATE DATABASE IF NOT EXISTS acore_auth; CREATE DATABASE IF NOT EXISTS acore_playerbots;" 2>/dev/null; then
    print_status "Databases created successfully"
else
    print_warning "Failed to create some databases - they may already exist"
fi

# Step 10: Download configuration files
print_step "Step 10: Setting up configuration files"
echo "Downloading configuration files..."

TEMP_CONFIG_DIR="$HOME/temp_configs"
rm -rf "$TEMP_CONFIG_DIR" 2>/dev/null || true

if git clone --filter=blob:none --sparse https://github.com/duall/singlePlayerWow-android.git "$TEMP_CONFIG_DIR"; then
    cd "$TEMP_CONFIG_DIR"
    git sparse-checkout set configs
    
    mkdir -p "$SERVER_DIR/etc"
    
    if [ -d "configs" ]; then
        cp -r configs/* "$SERVER_DIR/etc/"
        print_status "Configuration files installed"
    else
        print_warning "Configuration directory not found in repository"
    fi
    
    cd "$HOME"
    rm -rf "$TEMP_CONFIG_DIR"
else
    print_warning "Failed to download configuration files"
    echo "You may need to configure the server manually"
fi

# Step 11: Copy module configuration files
print_step "Step 11: Copying module configuration files"
mkdir -p "$SERVER_DIR/etc/modules"
MODULE_CONFS=$(find "$SOURCE_DIR/modules" -name "*.conf.dist" 2>/dev/null)
if [ -n "$MODULE_CONFS" ]; then
    CONF_COUNT=0
    while IFS= read -r conf_file; do
        cp "$conf_file" "$SERVER_DIR/etc/modules/"
        CONF_COUNT=$((CONF_COUNT + 1))
    done <<< "$MODULE_CONFS"
    print_status "$CONF_COUNT module config files copied"
else
    print_warning "No module .conf.dist files found"
fi

# Step 12: Download server data
print_step "Step 12: Downloading server data files"
echo "Downloading WoW client data (this may take several minutes)..."

DATA_URL="https://github.com/wowgaming/client-data/releases/download/v16/data.zip"
if curl -L "$DATA_URL" -o "$HOME/data.zip"; then
    echo "Extracting data files..."
    if unzip -q "$HOME/data.zip" -d "$SERVER_DIR/"; then
        rm "$HOME/data.zip"
        print_status "Server data files installed"
    else
        print_warning "Failed to extract data files"
        rm "$HOME/data.zip" 2>/dev/null || true
    fi
else
    print_warning "Failed to download server data files"
    echo "The server may not work properly without these files"
fi

# Step 13: Final setup and launch
print_step "Step 13: Setup Complete"

# Verify executables exist
if [ ! -f "$SERVER_DIR/bin/authserver" ] || [ ! -f "$SERVER_DIR/bin/worldserver" ]; then
    print_error "Server executables not found!"
    echo "Expected files:"
    echo "  $SERVER_DIR/bin/authserver"
    echo "  $SERVER_DIR/bin/worldserver"
    exit 1
fi

chmod +x "$SERVER_DIR/bin/authserver"
chmod +x "$SERVER_DIR/bin/worldserver"

echo ""
echo "SUCCESS! AzerothCore has been set up with pre-compiled Snapdragon binaries."
echo "Servers are ready to launch!"
echo ""
echo "Starting servers in:"
for i in 5 4 3 2 1; do
    echo "  $i..."
    sleep 1
done
echo ""

launch_servers
