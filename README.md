## Install Dependencies (In termux android)
You need to install the build and runtime dependancies:

`pkg install git cmake make clang mariadb boost-headers boost-static tmux`

### Install Azerothcore
Clone the project

`git clone https://github.com/duall/azerothcore-android.git`

### Enter the project's modules directory

`cd azerothcore-android/modules`

### Clone modules

Feel free to remove or add, but *mod-playerbots.git* is required for this branch`

`echo "https://github.com/liyunfan1223/mod-playerbots.git https://github.com/azerothcore/mod-1v1-arena https://github.com/azerothcore/mod-account-achievements https://github.com/azerothcore/mod-ah-bot https://github.com/azerothcore/mod-auto-revive https://github.com/azerothcore/mod-autobalance https://github.com/azerothcore/mod-better-item-reloading https://github.com/azerothcore/mod-boss-announcer https://github.com/azerothcore/mod-desertion-warnings https://github.com/azerothcore/mod-duel-reset https://github.com/hallgaeuer/mod-dynamic-loot-rates https://github.com/azerothcore/mod-dynamic-xp https://github.com/azerothcore/mod-emblem-transfer https://github.com/azerothcore/mod-fireworks-on-level https://github.com/azerothcore/mod-guildhouse https://github.com/azerothcore/mod-individual-xp https://github.com/azerothcore/mod-instance-reset https://github.com/noisiver/mod-junk-to-gold https://github.com/noisiver/mod-learnspells https://github.com/azerothcore/mod-low-level-rbg https://github.com/azerothcore/mod-morphsummon https://github.com/azerothcore/mod-npc-beastmaster https://github.com/azerothcore/mod-npc-buffer https://github.com/azerothcore/mod-npc-enchanter https://github.com/Gozzim/mod-npc-spectator https://github.com/azerothcore/mod-npc-talent-template https://github.com/azerothcore/mod-phased-duels https://github.com/azerothcore/mod-pvp-titles https://github.com/azerothcore/mod-queue-list-cache https://github.com/azerothcore/mod-quick-teleport https://github.com/azerothcore/mod-racial-trait-swap https://github.com/azerothcore/mod-rdf-expansion https://github.com/ZhengPeiRu21/mod-reagent-bank https://github.com/azerothcore/mod-reward-played-time https://github.com/azerothcore/mod-solo-lfg https://github.com/azerothcore/mod-top-arena https://github.com/azerothcore/mod-transmog https://github.com/azerothcore/mod-who-logged" | tr ' ' '\n' | xargs -I {} -P 5 git clone --depth 1 {}`

### Create the build directory

`cd ../` - go back to main directory

`mkdir build`

### Enter the directory

`cd build`

### Configure azerothcore for building

`cmake ../ -DCMAKE_INSTALL_PREFIX=$HOME/azeroth-server/ \
-DCMAKE_C_COMPILER=$PREFIX/bin/clang \
-DCMAKE_CXX_COMPILER=$PREFIX/bin/clang++ \
-DWITH_WARNINGS=1 -DTOOLS=0 -DSCRIPTS=static \
-DCMAKE_CXX_FLAGS="-D__ANDROID__ -DANDROID" \
-DCMAKE_EXE_LINKER_FLAGS="-Wl,--allow-multiple-definition"`

## Compile Azerothcore

`make -j$(nproc)`

### Install Azerothcore

`make install`

You will find executables in ~/azeroth-server/bin/

### Apply configs

`git clone --filter=blob:none --sparse https://github.com/duall/singlePlayerWow-android.git temp_configs && cd temp_configs && git sparse-checkout set configs && cp -r configs/* ~/azeroth-server/etc/ && cd .. && rm -rf temp_configs`

### Download serverdata
`curl -L https://github.com/wowgaming/client-data/releases/download/v16/data.zip -o ~/data.zip && unzip ~/data.zip -d ~/azeroth-server/ && rm ~/data.zip`

### Fix mariadb link
##### CANNOT LINK EXECUTABLE "./authserver": library "libmariadb.so" not found: needed by main executable

`ln -sf $PREFIX/lib/aarch64-linux-android/libmariadb.so $PREFIX/lib/libmariadb.so`

### Spoof mysql version

`echo -e "\n[mysqld]\nversion=8.0.36" >> $PREFIX/etc/my.cnf`

### Start MariaDB

`mariadbd-safe --datadir=$PREFIX/var/lib/mysql &`

### Create user
`mariadb -u root -e "DROP USER IF EXISTS 'acore'@'localhost'; CREATE USER
'acore'@'localhost' IDENTIFIED BY 'acore';"`

### Grant privileges
`mariadb -u root -e "GRANT ALL PRIVILEGES ON *.* TO 'acore'@'localhost';"`

## Servers should be runnable now

`cd ~/azeroth-server/`

`./bin/authserver`

`./bin/worldserver`

## If worldserver fails with SQL error, do this:
`curl -sL https://raw.githubusercontent.com/duall/singlePlayerWow-android/refs/heads/main/fix-modules-sql.sh | bash`

## Launch both authserver and worldserver in a single tmux window
`tmux new-session -d -c ~/azeroth-server -s azeroth './bin/authserver' \; split-window -h -c
~/azeroth-server './bin/worldserver' \; attach`


## Troubleshooting:

### Poor performance:
Try reducing playerbots number in: etc/modules/playerbots.conf

### My wifi friends cannot connect
Replace 192.168.1.XXX with your actual LAN IP (type ifconfig to find out)
mariadb -u root -e "UPDATE acore_auth.realmlist SET address = '192.168.1.XXX' WHERE id =
1;"

### Winlator performance boost
Disable last 3 cores in winlator

And change this in worldserver.conf *UseProcessors = 224* (This uses last 3 efficiency cores in 8 core processor)

If your phone has more or less than 8 cores, modify this bitmask number.

This makes sure processors between server and client do not clash

