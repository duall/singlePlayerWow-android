#!/bin/bash

# Script to automatically import all SQL files from AzerothCore modules
# Searches for SQL files in modules/*/data/sql/ directories and imports them to appropriate databases

set -e

MODULES_DIR="$HOME/azerothcore-android/modules"
DB_USER="acore"
DB_PASS="acore"

echo "=== AzerothCore Module SQL Import Script ==="
echo "Searching for SQL files in: $MODULES_DIR"
echo ""

# Function to import SQL file
import_sql() {
    local file="$1"
    local database="$2"
    local relative_path="$3"
    
    echo "  Importing: $relative_path -> $database"
    if mariadb -u "$DB_USER" -p"$DB_PASS" "$database" < "$file" 2>/dev/null; then
        echo "    ✓ Success"
    else
        echo "    ❌ Failed"
        return 1
    fi
}

# Check if modules directory exists
if [ ! -d "$MODULES_DIR" ]; then
    echo "Error: Modules directory not found at $MODULES_DIR"
    exit 1
fi

# Find all modules with SQL data
modules_with_sql=$(find "$MODULES_DIR" -type d -path "*/data/sql" | sed 's|/data/sql||' | sort)

if [ -z "$modules_with_sql" ]; then
    echo "No modules with SQL data found."
    exit 0
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
    sql_dir="$module_dir/data/sql"
    
    echo "Processing module: $module_name"
    
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
    fi
    
    echo ""
done

echo "=== Import Summary ==="
echo "Total files processed: $total_files"
echo "Successful imports: $success_count"
echo "Failed imports: $failed_count"

if [ $failed_count -gt 0 ]; then
    echo ""
    echo "Some imports failed. This might be normal if:"
    echo "  - Files contain updates for non-existent tables"
    echo "  - Files are meant for different AzerothCore versions"
    echo "  - Dependencies between files exist"
    exit 1
else
    echo ""
    echo "All SQL files imported successfully!"
fi
