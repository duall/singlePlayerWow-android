#!/bin/bash

# AzerothCore Single Player WoW Setup Script for Termux
# Compiles everything from GitHub sources
# Usage: curl -fsSL https://raw.githubusercontent.com/username/repo/main/wowsp.sh -o ~/wowsp.sh && bash ~/wowsp.sh

set -e  # Exit on any error

SERVER_DIR="$HOME/azeroth-server"
SOURCE_DIR="$HOME/azerothcore-android"
BUILD_DIR="$SOURCE_DIR/build"
AUTOFIX_FLAG="$SERVER_DIR/.autofix_applied"

echo "=== AzerothCore Single Player WoW Setup Script ==="
echo "This script will compile AzerothCore from source for Android/Termux"
echo ""

# Function to launch servers with autofix capability
launch_servers() {
    local attempt_autofix=true
    
    # Check if autofix was already applied
    if [ -f "$AUTOFIX_FLAG" ]; then
        echo "✓ Autofix was previously applied, launching servers directly..."
        attempt_autofix=false
    fi
    
    if [ "$attempt_autofix" = true ]; then
        echo "Starting WorldServer with auto-fix capability..."
        
        # Create log file path in server directory
        log_file="$SERVER_DIR/worldserver_output.log"
        
        # Run worldserver in background and capture output
        cd "$SERVER_DIR"
        ./bin/worldserver > "$log_file" 2>&1 & 
        worldserver_pid=$!
        
        # Show output in real-time but filter warnings
        tail -f "$log_file" | grep -v "Deprecated program name\|use.*mariadb.*instead" & 
        tail_pid=$!
        
        # Check every 5 seconds for up to 20 minutes (240 checks)
        echo "Monitoring WorldServer startup..."
        for check in {1..240}; do
            sleep 5
            
            # Check if the process is still running
            if ! kill -0 "$worldserver_pid" 2>/dev/null; then
                echo ""
                echo "WorldServer process stopped. Running SQL fix..."
                kill "$tail_pid" 2>/dev/null || true
                break
            fi
            
            # Check if it's ready (look for the AC> prompt)
            if grep -q "AC>" "$log_file"; then
                echo ""
                echo "✓ WorldServer fully initialized and ready!"
                
                # Kill monitoring processes
                kill "$worldserver_pid" 2>/dev/null || true
                kill "$tail_pid" 2>/dev/null || true
                wait "$worldserver_pid" 2>/dev/null || true
                
                # Mark autofix as applied (successful startup)
                touch "$AUTOFIX_FLAG"
                
                # Give it a moment to release resources
                sleep 3
                break
            fi
            
            # Show progress every 15 seconds
            if [ $((check % 3)) -eq 0 ]; then
                echo "Still waiting... (${check}0 seconds elapsed)"
            fi
        done
        
        # Kill any remaining processes
        kill "$worldserver_pid" 2>/dev/null || true
        kill "$tail_pid" 2>/dev/null || true
        wait "$worldserver_pid" 2>/dev/null || true
        
        # If we didn't find AC> prompt, run SQL fix
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
    
    # Kill existing session if it exists
    tmux kill-session -t azeroth 2>/dev/null || true
    
    # Start the tmux session
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
    
    # Function to import SQL file
    import_sql() {
        local file="$1"
        local database="$2"
        local relative_path="$3"
        
        echo "  Importing: $relative_path -> $database"
        if mariadb -u "$DB_USER" -p"$DB_PASS" "$database" < "$file" 2>/dev/null; then
            echo "    ✓ Success"
            return 0
        else
            echo "    ❌ Failed"
            return 1
        fi
    }
    
    # Check if modules directory exists
    if [ ! -d "$MODULES_DIR" ]; then
        echo "Warning: Modules directory not found at $MODULES_DIR"
        return 1
    fi
    
    # Find all modules with SQL data (check both data/sql and sql directories)
    modules_with_sql=$(find "$MODULES_DIR" -type d \( -path "*/data/sql" -o -path "*/sql" \) | sed -E 's|/(data/)?sql$||' | sort -u)
    
    if [ -z "$modules_with_sql" ]; then
        echo "No modules with SQL data found."
        return 0
    fi
    
    echo "Found modules with SQL data:"
    echo "$modules_with_sql" | sed 's|.*/||' | sed 's/^/  - /'
    echo ""
    
    # Process each module
    total_files=0
    success_count=0
    failed_count=0
    
    for module_dir in $modules_with_sql; do
        module_name=$(basename "$module_dir")
        
        # Check for both possible SQL directory locations
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
        
        # Find all SQL files in this module
        if [ -d "$sql_dir" ]; then
            # Find all db-* directories and process them
            db_dirs=$(find "$sql_dir" -type d -name "db-*" 2>/dev/null | sort || true)
            
            for db_dir in $db_dirs; do
                db_type=$(basename "$db_dir" | sed 's/^db-//')
                
                # Map db type to actual database name
                case "$db_type" in
                    "auth")
                        target_db="acore_auth"
                        ;;
                    "characters")
                        target_db="acore_characters"
                        ;;
                    "world")
                        target_db="acore_world"
                        ;;
                    *)
                        # For any other db-* directories, try to map to acore_*
                        target_db="acore_$db_type"
                        ;;
                esac
                
                # Find SQL files in this db directory
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
            
            # Also check for alternative directory structures (world/, characters/, auth/)
            alt_dirs=$(find "$sql_dir" -type d \( -name "world" -o -name "characters" -o -name "auth" \) 2>/dev/null | sort || true)
            
            for alt_dir in $alt_dirs; do
                dir_type=$(basename "$alt_dir")
                
                # Map directory type to actual database name
                case "$dir_type" in
                    "auth")
                        target_db="acore_auth"
                        ;;
                    "characters")
                        target_db="acore_characters"
                        ;;
                    "world")
                        target_db="acore_world"
                        ;;
                esac
                
                # Find SQL files in this directory (including subdirectories)
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

# Check if worldserver already exists
if [ -f "$SERVER_DIR/bin/worldserver" ]; then
    echo "✓ AzerothCore installation found at $SERVER_DIR"
    echo "✓ Servers are ready to launch!"
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

echo "Estimated time: 30-60 minutes depending on device performance"
echo ""

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

# Function to check if MariaDB is running
check_mariadb_running() {
    if pgrep -f "mariadbd" > /dev/null; then
        return 0
    else
        return 1
    fi
}

# Function to print colored output
print_status() {
    echo "✓ $1"
}

print_step() {
    echo ""
    echo "=== $1 ==="
}

print_warning() {
    echo "⚠ $1"
}

print_error() {
    echo "❌ $1"
}

# Step 1: Install build dependencies
print_step "Step 1: Installing build dependencies"
PACKAGES=("git" "cmake" "make" "clang" "mariadb" "boost-headers" "boost-static" "tmux" "curl" "unzip")
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

# Step 2: Clone AzerothCore source
print_step "Step 2: Downloading AzerothCore source code"
if [ ! -d "$SOURCE_DIR" ]; then
    echo "Cloning AzerothCore Android fork..."
    git clone https://github.com/duall/azerothcore-android.git "$SOURCE_DIR"
    print_status "Source code downloaded"
else
    print_status "Source code already exists, updating..."
    cd "$SOURCE_DIR"
    git pull origin master || echo "Failed to update, continuing with existing code"
fi

# Step 3: Clone required modules (excluding problematic individual progression)
print_step "Step 3: Downloading AzerothCore modules"
cd "$SOURCE_DIR/modules"

# Remove existing modules to ensure clean state
rm -rf mod-* 2>/dev/null || true

echo "Cloning required modules (this may take a few minutes)..."

# List of modules to clone (excluding mod-individual-progression)
MODULES=(
    "https://github.com/liyunfan1223/mod-playerbots.git"
	"https://github.com/DustinHendrickson/mod-player-bot-level-brackets"
	"https://github.com/ZhengPeiRu21/mod-individual-progression.git"
    "https://github.com/azerothcore/mod-1v1-arena"
    "https://github.com/azerothcore/mod-account-achievements"
    "https://github.com/duall/mod-ah-bot"
    "https://github.com/azerothcore/mod-auto-revive"
    "https://github.com/azerothcore/mod-autobalance"
    "https://github.com/azerothcore/mod-better-item-reloading"
    "https://github.com/azerothcore/mod-boss-announcer"
    "https://github.com/azerothcore/mod-desertion-warnings"
    "https://github.com/azerothcore/mod-duel-reset"
    "https://github.com/hallgaeuer/mod-dynamic-loot-rates"
    "https://github.com/azerothcore/mod-dynamic-xp"
    "https://github.com/azerothcore/mod-emblem-transfer"
    "https://github.com/azerothcore/mod-fireworks-on-level"
    "https://github.com/azerothcore/mod-guildhouse"
    "https://github.com/azerothcore/mod-individual-xp"
    "https://github.com/azerothcore/mod-instance-reset"
    "https://github.com/noisiver/mod-junk-to-gold"
    "https://github.com/noisiver/mod-learnspells"
    "https://github.com/azerothcore/mod-low-level-rbg"
    "https://github.com/azerothcore/mod-morphsummon"
    "https://github.com/azerothcore/mod-npc-beastmaster"
    "https://github.com/azerothcore/mod-npc-buffer"
    "https://github.com/azerothcore/mod-npc-enchanter"
    "https://github.com/Gozzim/mod-npc-spectator"
    "https://github.com/azerothcore/mod-npc-talent-template"
    "https://github.com/azerothcore/mod-phased-duels"
    "https://github.com/azerothcore/mod-pvp-titles"
    "https://github.com/azerothcore/mod-queue-list-cache"
    "https://github.com/azerothcore/mod-quick-teleport"
    "https://github.com/azerothcore/mod-racial-trait-swap"
    "https://github.com/azerothcore/mod-rdf-expansion"
    "https://github.com/ZhengPeiRu21/mod-reagent-bank"
    "https://github.com/azerothcore/mod-reward-played-time"
    "https://github.com/azerothcore/mod-solo-lfg"
    "https://github.com/azerothcore/mod-top-arena"
    "https://github.com/azerothcore/mod-transmog"
    "https://github.com/azerothcore/mod-who-logged"
)

# Clone modules with error handling
FAILED_MODULES=()
for module in "${MODULES[@]}"; do
    module_name=$(basename "$module" .git)
    echo "Cloning $module_name..."
    if ! git clone --depth 1 "$module" 2>/dev/null; then
        FAILED_MODULES+=("$module_name")
        echo "  Failed to clone $module_name, continuing..."
    fi
done

if [ ${#FAILED_MODULES[@]} -gt 0 ]; then
    print_warning "Some modules failed to clone: ${FAILED_MODULES[*]}"
    echo "The server will still work, but some features may be missing."
else
    print_status "All modules downloaded successfully"
fi

# Step 4: Configure MariaDB
print_step "Step 4: Configuring MariaDB"

# Initialize MariaDB if needed
if [ ! -d "$PREFIX/var/lib/mysql/mysql" ]; then
    echo "Initializing MariaDB database..."
    mysql_install_db --datadir="$PREFIX/var/lib/mysql"
    print_status "MariaDB initialized"
else
    print_status "MariaDB already initialized"
fi

# Configure MySQL version spoofing
if ! grep -q "version=8.0.36" "$PREFIX/etc/my.cnf" 2>/dev/null; then
    echo "Adding MySQL version configuration..."
    echo -e "\n[mysqld]\nversion=8.0.36" >> "$PREFIX/etc/my.cnf"
    print_status "MySQL version configured"
else
    print_status "MySQL version already configured"
fi

# Fix MariaDB library link
if [ ! -L "$PREFIX/lib/libmariadb.so" ]; then
    echo "Creating MariaDB library link..."
    ln -sf "$PREFIX/lib/aarch64-linux-android/libmariadb.so" "$PREFIX/lib/libmariadb.so"
    print_status "Library link created"
else
    print_status "Library link already exists"
fi

# Step 5: Start MariaDB
print_step "Step 5: Starting MariaDB"
if ! check_mariadb_running; then
    echo "Starting MariaDB daemon..."
    mariadbd-safe --datadir="$PREFIX/var/lib/mysql" &
    
    # Wait for MariaDB to be ready
    echo "Waiting for MariaDB to start..."
    for i in {1..30}; do
        if mariadb -u root -e "SELECT 1;" >/dev/null 2>&1; then
            print_status "MariaDB started and ready"
            break
        fi
        if [ $i -eq 30 ]; then
            print_warning "MariaDB is taking longer than expected to start"
            echo "Continuing anyway - it might work..."
        else
            printf "."
            sleep 1
        fi
    done
else
    print_status "MariaDB already running"
fi

# Step 6: Setup database user
print_step "Step 6: Setting up database user"
if ! check_mysql_user; then
    echo "Creating acore user..."
    
    # Retry database connection up to 10 times
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

# Step 7: Create required databases
print_step "Step 7: Creating AzerothCore databases"
echo "Creating required databases..."
if mariadb -u acore -pacore -e "CREATE DATABASE IF NOT EXISTS acore_world; CREATE DATABASE IF NOT EXISTS acore_characters; CREATE DATABASE IF NOT EXISTS acore_auth; CREATE DATABASE IF NOT EXISTS acore_playerbots;" 2>/dev/null; then
    print_status "Databases created successfully"
else
    print_warning "Failed to create some databases - they may already exist"
fi

# Step 8: Configure and compile AzerothCore
print_step "Step 8: Configuring AzerothCore build"

# Create build directory inside source directory
cd "$SOURCE_DIR"
rm -rf build 2>/dev/null || true
mkdir build
cd build

echo "Running cmake configuration..."
echo "This may take a few minutes..."

# Configure the build
cmake ../ \
    -DCMAKE_INSTALL_PREFIX="$SERVER_DIR" \
    -DCMAKE_C_COMPILER="$PREFIX/bin/clang" \
    -DCMAKE_CXX_COMPILER="$PREFIX/bin/clang++" \
    -DWITH_WARNINGS=1 \
    -DTOOLS=0 \
    -DSCRIPTS=static \
    -DCMAKE_CXX_FLAGS="-D__ANDROID__ -DANDROID" \
    -DCMAKE_EXE_LINKER_FLAGS="-Wl,--allow-multiple-definition"

print_status "Build configured successfully"

# Step 9: Compile AzerothCore
print_step "Step 9: Compiling AzerothCore (this will take 20-45 minutes)"
echo "Starting compilation with $(nproc) CPU cores..."
echo "Please be patient, this is the longest step..."

# Show progress during compilation
START_TIME=$(date +%s)
if make -j$(nproc); then
    END_TIME=$(date +%s)
    DURATION=$((END_TIME - START_TIME))
    MINUTES=$((DURATION / 60))
    SECONDS=$((DURATION % 60))
    print_status "Compilation completed in ${MINUTES}m ${SECONDS}s"
else
    print_error "Compilation failed!"
    echo "This could be due to:"
    echo "  - Insufficient memory (try closing other apps)"
    echo "  - Missing dependencies"
    echo "  - Source code issues"
    echo ""
    echo "You can try running the compilation manually:"
    echo "  cd $BUILD_DIR && make -j$(nproc)"
    exit 1
fi

# Step 10: Install AzerothCore
print_step "Step 10: Installing AzerothCore"
if make install; then
    print_status "AzerothCore installed to $SERVER_DIR"
else
    print_error "Installation failed!"
    exit 1
fi

# Step 11: Download configuration files
print_step "Step 11: Setting up configuration files"
echo "Downloading configuration files..."

TEMP_CONFIG_DIR="$HOME/temp_configs"
rm -rf "$TEMP_CONFIG_DIR" 2>/dev/null || true

if git clone --filter=blob:none --sparse https://github.com/duall/singlePlayerWow-android.git "$TEMP_CONFIG_DIR"; then
    cd "$TEMP_CONFIG_DIR"
    git sparse-checkout set configs
    
    # Ensure etc directory exists
    mkdir -p "$SERVER_DIR/etc"
    
    # Copy configurations
    if [ -d "configs" ]; then
        cp -r configs/* "$SERVER_DIR/etc/"
        print_status "Configuration files installed"
    else
        print_warning "Configuration directory not found in repository"
    fi
    
    # Cleanup
    cd "$HOME"
    rm -rf "$TEMP_CONFIG_DIR"
else
    print_warning "Failed to download configuration files"
    echo "You may need to configure the server manually"
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
    echo ""
    echo "Check the compilation step for errors."
    exit 1
fi

# Make executables runnable
chmod +x "$SERVER_DIR/bin/authserver"
chmod +x "$SERVER_DIR/bin/worldserver"

echo ""
echo "SUCCESS! AzerothCore has been compiled and installed successfully."
echo "✓ Servers are ready to launch!"
echo ""
echo "Starting servers in:"
for i in 5 4 3 2 1; do
    echo "  $i..."
    sleep 1
done
echo ""

launch_servers
