#!/bin/bash

# AzerothCore Single Player WoW Setup Script for Termux (Snapdragon Devices Only)
# Downloads pre-compiled binaries instead of compiling from source
# Usage: curl -fsSL https://raw.githubusercontent.com/duall/singlePlayerWow-android/main/wowsp_snapdragon.sh -o ~/wowsp_snapdragon.sh && bash ~/wowsp_snapdragon.sh

set -e  # Exit on any error

SERVER_DIR="$HOME/azeroth-server"
DATA_REPO="$HOME/singlePlayerWow-android"
AUTOFIX_FLAG="$SERVER_DIR/.autofix_applied"

# Download URLs
AUTHSERVER_URL="https://github.com/duall/singlePlayerWow-android/releases/download/snapdragon/authserver_snapdragon"
WORLDSERVER_URL="https://github.com/duall/singlePlayerWow-android/releases/download/snapdragon/worldserver_snapdragon"
DATA_REPO_URL="https://github.com/duall/singlePlayerWow-android.git"
DATA_ZIP_URL="https://github.com/wowgaming/client-data/releases/download/v16/data.zip"

echo "=== AzerothCore Single Player WoW Setup (Snapdragon Binary) ==="
echo "This script downloads pre-compiled binaries for Snapdragon devices"
echo ""

# Function to check if MariaDB is running
check_mariadb_running() {
    pgrep -f "mariadbd" > /dev/null
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
                return 0
            fi
            if [ $i -eq 30 ]; then
                print_warning "MariaDB taking longer than expected"
            else
                printf "."
                sleep 1
            fi
        done
    else
        print_status "MariaDB already running"
    fi
}

# Function to launch servers
launch_servers() {
    echo "Launching AzerothCore servers in tmux..."
    tmux kill-session -t azeroth 2>/dev/null || true
    cd "$SERVER_DIR"
    tmux new-session -d -c "$SERVER_DIR" -s azeroth './bin/authserver' \; \
         split-window -h -c "$SERVER_DIR" './bin/worldserver' \; \
         attach
}

# Function to check if a package is installed
check_package() {
    dpkg -l | grep -q "^ii  $1 "
}

# Function to check if MariaDB user exists
check_mysql_user() {
    mariadb -u root -e "SELECT User FROM mysql.user WHERE User='acore' AND Host='localhost';" 2>/dev/null | grep -q "acore"
}

# Print helpers
print_status() { echo "OK $1"; }
print_step() { echo ""; echo "=== $1 ==="; }
print_warning() { echo "WARNING $1"; }
print_error() { echo "ERROR $1"; }

# Check if worldserver already exists - just launch
if [ -f "$SERVER_DIR/bin/worldserver" ]; then
    echo "AzerothCore installation found at $SERVER_DIR"
    echo "Checking MariaDB status..."
    ensure_mariadb_running
    
    echo "Servers are ready to launch!"
    echo ""
    for i in 5 4 3 2 1; do echo "  $i..."; sleep 1; done
    echo ""
    launch_servers
    exit 0
fi

echo "Estimated time: 10-15 minutes (no compilation needed)"
echo ""

# Step 1: Install runtime dependencies
print_step "Step 1: Installing runtime dependencies"
PACKAGES=("git" "mariadb" "tmux" "curl" "unzip" "libc++" "boost" "clang")
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

# Create Boost shared library stubs
echo "Creating Boost shared library stubs..."
BOOST_LIBS=(
    boost_system boost_filesystem boost_thread boost_program_options
    boost_iostreams boost_regex boost_atomic boost_chrono boost_locale
    boost_log boost_log_setup boost_date_time boost_container boost_random
)
for lib in "${BOOST_LIBS[@]}"; do
    if [ ! -f "$PREFIX/lib/lib${lib}.so" ]; then
        echo "void ${lib}_stub(void) {}" | clang -shared -o "$PREFIX/lib/lib${lib}.so" -x c -
    fi
done
print_status "Boost library stubs ready"

# Step 2: Download and test binary compatibility
print_step "Step 2: Checking Snapdragon binary compatibility"

echo "Downloading test binary to verify device compatibility..."
mkdir -p "$SERVER_DIR/bin"

if curl -L --fail "$AUTHSERVER_URL" -o "$SERVER_DIR/bin/authserver" 2>/dev/null; then
    chmod +x "$SERVER_DIR/bin/authserver"
    print_status "Test binary downloaded"
else
    print_error "Failed to download test binary"
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

# Step 3: Download worldserver binary
print_step "Step 3: Downloading worldserver binary"

echo "Downloading worldserver..."
if curl -L --fail "$WORLDSERVER_URL" -o "$SERVER_DIR/bin/worldserver"; then
    chmod +x "$SERVER_DIR/bin/worldserver"
    print_status "worldserver downloaded"
else
    print_error "Failed to download worldserver binary"
    rm -rf "$SERVER_DIR"
    exit 1
fi

# Step 4: Download SQL and configs
print_step "Step 4: Downloading SQL and configuration files"

rm -rf "$DATA_REPO" 2>/dev/null || true
echo "Downloading data repository (SQL + configs only)..."
if git clone --filter=blob:none --sparse "$DATA_REPO_URL" "$DATA_REPO"; then
    cd "$DATA_REPO"
    git sparse-checkout set sql configs
    
    # Create data/sql structure expected by DB updater
    mkdir -p "$DATA_REPO/data/sql/updates/pending_db_auth"
    mkdir -p "$DATA_REPO/data/sql/updates/pending_db_characters"
    mkdir -p "$DATA_REPO/data/sql/updates/pending_db_world"
    print_status "SQL and config files downloaded"
else
    print_error "Failed to download data repository"
    exit 1
fi

# Step 5: Install configuration files
print_step "Step 5: Setting up configuration files"

mkdir -p "$SERVER_DIR/etc/modules"

# Main configs
if [ -d "$DATA_REPO/configs" ]; then
    # Copy main configs (non-directory files)
    find "$DATA_REPO/configs" -maxdepth 1 -type f -exec cp {} "$SERVER_DIR/etc/" \;
    
    # Copy module configs
    if [ -d "$DATA_REPO/configs/modules" ]; then
        cp "$DATA_REPO/configs/modules/"* "$SERVER_DIR/etc/modules/" 2>/dev/null || true
    fi
    print_status "Configuration files installed"
    
    # Point SourceDirectory to our data repo for DB updater
    sed -i "s|SourceDirectory.*=.*|SourceDirectory = \"$DATA_REPO\"|" "$SERVER_DIR/etc/worldserver.conf" 2>/dev/null || true
    sed -i "s|SourceDirectory.*=.*|SourceDirectory = \"$DATA_REPO\"|" "$SERVER_DIR/etc/authserver.conf" 2>/dev/null || true
    print_status "SourceDirectory configured"
else
    print_warning "Configuration directory not found"
fi

# Server requires .conf.dist for every module - create from .conf if missing
for conf in "$SERVER_DIR/etc/modules/"*.conf; do
    [ -f "$conf" ] || continue
    dist="${conf}.dist"
    if [ ! -f "$dist" ]; then
        cp "$conf" "$dist"
    fi
done
print_status "Module .conf.dist files ensured"

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
                exit 1
            fi
            echo "  Attempt $attempt failed, retrying in 2 seconds..."
            sleep 2
        fi
    done
else
    print_status "Database user already exists"
fi

# Step 9: Create databases and import SQL
print_step "Step 9: Creating databases and importing SQL schemas"

DB_USER="acore"
DB_PASS="acore"
SQL_DIR="$DATA_REPO/sql"

echo "Creating databases..."
mariadb -u "$DB_USER" -p"$DB_PASS" -e "CREATE DATABASE IF NOT EXISTS acore_world; CREATE DATABASE IF NOT EXISTS acore_characters; CREATE DATABASE IF NOT EXISTS acore_auth; CREATE DATABASE IF NOT EXISTS acore_playerbots;" 2>/dev/null
print_status "Databases created"

# Import base schemas
echo "Importing base auth schemas..."
for f in "$SQL_DIR/base/db_auth/"*.sql; do
    [ -f "$f" ] && mariadb -u "$DB_USER" -p"$DB_PASS" acore_auth < "$f" 2>/dev/null || true
done
print_status "Auth schemas imported"

echo "Importing base characters schemas..."
for f in "$SQL_DIR/base/db_characters/"*.sql; do
    [ -f "$f" ] && mariadb -u "$DB_USER" -p"$DB_PASS" acore_characters < "$f" 2>/dev/null || true
done
print_status "Characters schemas imported"

echo "Importing base world schemas (this may take a minute)..."
for f in "$SQL_DIR/base/db_world/"*.sql; do
    [ -f "$f" ] && mariadb -u "$DB_USER" -p"$DB_PASS" acore_world < "$f" 2>/dev/null || true
done
print_status "World schemas imported"

# Import module SQL
echo "Importing module SQL files..."
mod_count=0
for db in db_auth db_characters db_world; do
    case "$db" in
        db_auth) target_db="acore_auth" ;;
        db_characters) target_db="acore_characters" ;;
        db_world) target_db="acore_world" ;;
    esac
    
    if [ -d "$SQL_DIR/modules/$db" ]; then
        for f in "$SQL_DIR/modules/$db/"*.sql; do
            if [ -f "$f" ]; then
                mariadb -u "$DB_USER" -p"$DB_PASS" "$target_db" < "$f" 2>/dev/null && mod_count=$((mod_count + 1)) || true
            fi
        done
    fi
done
print_status "$mod_count module SQL files imported"

# Step 10: Download server data
print_step "Step 10: Downloading server data files"
echo "Downloading WoW client data (this may take several minutes)..."

if curl -L "$DATA_ZIP_URL" -o "$HOME/data.zip"; then
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
fi

# Step 11: Final setup and launch
print_step "Step 11: Setup Complete"

if [ ! -f "$SERVER_DIR/bin/authserver" ] || [ ! -f "$SERVER_DIR/bin/worldserver" ]; then
    print_error "Server executables not found!"
    exit 1
fi

chmod +x "$SERVER_DIR/bin/authserver"
chmod +x "$SERVER_DIR/bin/worldserver"

# Keep DATA_REPO - worldserver needs it for SourceDirectory

echo ""
echo "SUCCESS! AzerothCore has been set up with pre-compiled Snapdragon binaries."
echo "Servers are ready to launch!"
echo ""
for i in 5 4 3 2 1; do echo "  $i..."; sleep 1; done
echo ""

launch_servers
