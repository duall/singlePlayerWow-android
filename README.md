<img width="2066" height="753" alt="image" src="https://github.com/user-attachments/assets/ba815e88-dd5b-4584-88e9-dfdf9eed767b" />


## One click install script (Cutoff date applied, so azerothcore updates do not break this):
*copy into termux*

`curl -fsSL https://raw.githubusercontent.com/duall/singlePlayerWow-android/main/wowsp_cutoff.sh -o ~/wowsp_cutoff.sh && bash ~/wowsp_cutoff.sh`

Should take care of everything below automatically

Connect with chromiecraft 3.3.5 trough winlator ( set realm to 127.0.0.1 or 192.168.x.x  )

## Manual installation if script does not work

You need to install the build and runtime dependencies:

`pkg install git cmake make clang mariadb boost-headers boost-static tmux libc++ curl unzip`

---

### Install AzerothCore

Clone the project and lock to a known working commit:

```
git clone https://github.com/duall/azerothcore-android.git
cd azerothcore-android
git checkout abc884520173084d5cd37b72b57b3822230dcb32
```

### Patch Boost compatibility (required for Boost 1.89+)

Termux now ships Boost 1.90+ which removed the `boost_system` stub library. You must patch this before building:

```
sed -i '1i cmake_policy(SET CMP0167 OLD)' deps/boost/CMakeLists.txt
sed -i -E 's/ system / /g; s/ system$//g; s/^system //g' deps/boost/CMakeLists.txt
```

### Enter the project's modules directory

`cd modules`

### Clone modules (locked to known working commits)

Feel free to remove modules, but **mod-playerbots** is required for this branch.

Some players might want to remove **mod-individual-progression**.

```
clone_mod() {
    local repo="$1" commit="$2" name
    name=$(basename "$repo" .git)
    git clone "$repo" && cd "$name" && git checkout "$commit" && cd ..
}

clone_mod https://github.com/liyunfan1223/mod-playerbots.git df3c44419de4ec447b1d73de180d3753f3bd8f4c
clone_mod https://github.com/DustinHendrickson/mod-player-bot-level-brackets.git 12aac35118c928e423708902f596e961456191c3
clone_mod https://github.com/ZhengPeiRu21/mod-individual-progression.git ad2e8e4536275126d55732255e02ac5fd8533b64
clone_mod https://github.com/azerothcore/mod-1v1-arena.git 29748fe1cd20001d97034f533a42c034d822fc7b
clone_mod https://github.com/azerothcore/mod-random-enchants.git 02a2e0d83b3cfad039bf1967177326aef8dd71f5
clone_mod https://github.com/azerothcore/mod-account-achievements.git bfbe3677635feeef823057964e028e023633115a
clone_mod https://github.com/azerothcore/mod-auto-revive.git ce5ca7a600dbef0dec48dc6da42d374d08d6b728
clone_mod https://github.com/azerothcore/mod-autobalance.git 37455446fe99f073e4a6113987e3228705054639
clone_mod https://github.com/azerothcore/mod-better-item-reloading.git ab4fa9dc28e146e2f0730e989af2c025fac85dd5
clone_mod https://github.com/azerothcore/mod-boss-announcer.git d206190617552ca04540d14b1098cd3717a94c36
clone_mod https://github.com/azerothcore/mod-desertion-warnings.git ed1b7e26869d520b7627c289d461fbc5d040be6a
clone_mod https://github.com/azerothcore/mod-duel-reset.git 8fc67b6baa16cf20d6322b3710f82110dc9ee20b
clone_mod https://github.com/hallgaeuer/mod-dynamic-loot-rates.git 41ffb6a7c5bc78d1c062b8237a9a185892514a32
clone_mod https://github.com/azerothcore/mod-dynamic-xp.git 56033ee97fe400898aea057596e933062821d13e
clone_mod https://github.com/azerothcore/mod-emblem-transfer.git 5d9d0d9ff8c8b80fb33f6615f046b979d5efccb4
clone_mod https://github.com/azerothcore/mod-fireworks-on-level.git e5c58542996e0f1ad3410ebdb7cff9ed9d52e3d6
clone_mod https://github.com/azerothcore/mod-guildhouse.git 23b86dcc78471c50c60b3fc27e07e4cda8a3e200
clone_mod https://github.com/azerothcore/mod-individual-xp.git a0c60a5da285984dbe8fb028ac4676bf75e573e2
clone_mod https://github.com/azerothcore/mod-instance-reset.git 42ddc011dd6836ad662774472b0b214d32c3ea31
clone_mod https://github.com/noisiver/mod-junk-to-gold.git 2134690bb03899e5c9e44d0682e8e6abf0bbbaf2
clone_mod https://github.com/noisiver/mod-learnspells.git fe63752be467f325ebf283b010325e47a9fce4ff
clone_mod https://github.com/azerothcore/mod-low-level-rbg.git fd6077de0fd49bf2caaae3c5c4dcb857178cf7b9
clone_mod https://github.com/azerothcore/mod-morphsummon.git 28e347515cf97d80f296e5ca072ff2686199c6ca
clone_mod https://github.com/azerothcore/mod-npc-beastmaster.git eb9bdbaaabbf096a22febfbe8a0735a778d96a9e
clone_mod https://github.com/azerothcore/mod-npc-buffer.git 9a755a3ef6ed1f183d8c290729e0db43e174ed64
clone_mod https://github.com/azerothcore/mod-npc-enchanter.git 0c34e45a534d6335732f778eb15eb68bba7f8055
clone_mod https://github.com/Gozzim/mod-npc-spectator.git 8dc107289cf6af9b49945c2c9e6826a29e1dc5a6
clone_mod https://github.com/azerothcore/mod-npc-talent-template.git 43238807f12692dcba96e6cb2b7cc0ac3edcfe51
clone_mod https://github.com/azerothcore/mod-phased-duels.git 349db1972d44dd4b25e24d0e2f0c207bea136ce1
clone_mod https://github.com/azerothcore/mod-pvp-titles.git 2c7c16a4ff504cb43d60919552581833d7efcb05
clone_mod https://github.com/azerothcore/mod-queue-list-cache.git f10c480f8c43f7716da26150d02903933f50af40
clone_mod https://github.com/azerothcore/mod-quick-teleport.git 3a88ac0f294f7ce21441fb3cb3de13f87c9683eb
clone_mod https://github.com/azerothcore/mod-racial-trait-swap.git 99d1895617bcc1a857c166bccfd4454699f7fdc6
clone_mod https://github.com/azerothcore/mod-rdf-expansion.git c7a91c5973cda4529495b52b89375913f98726d6
clone_mod https://github.com/ZhengPeiRu21/mod-reagent-bank.git eceb91d636f56289f8720eea6d3c7e24db07bd43
clone_mod https://github.com/azerothcore/mod-reward-played-time.git fc8a07958213393dbffad035e853bdc18ab66a6e
clone_mod https://github.com/azerothcore/mod-solo-lfg.git 3821fe1d108ade8d2b7ad6611e41154e05864c65
clone_mod https://github.com/azerothcore/mod-top-arena.git 6f3a8eded4e5cd6abab730b633d5e3f0719c9a19
clone_mod https://github.com/azerothcore/mod-transmog.git 949cdfb0b989628064d36d95b0948f8b19ec702f
clone_mod https://github.com/azerothcore/mod-who-logged.git 3f439d0aa56d3a4782dee1467f1bdcb16b35aa2f
```

### Create the build directory

```
cd ../
mkdir build
cd build
```

### Configure AzerothCore for building

```
cmake ../ -DCMAKE_INSTALL_PREFIX=$HOME/azeroth-server/ \
-DCMAKE_C_COMPILER=$PREFIX/bin/clang \
-DCMAKE_CXX_COMPILER=$PREFIX/bin/clang++ \
-DWITH_WARNINGS=1 -DTOOLS=0 -DSCRIPTS=static \
-DCMAKE_CXX_FLAGS="-D__ANDROID__ -DANDROID -Wno-deprecated-literal-operator" \
-DCMAKE_EXE_LINKER_FLAGS="-Wl,--allow-multiple-definition -lunwind"
```

### Compile AzerothCore

`make -j$(nproc)` (Might want to reduce it if low on RAM)

### Install AzerothCore

`make install`

You will find executables in ~/azeroth-server/bin/

### Apply configs

`git clone --filter=blob:none --sparse https://github.com/duall/singlePlayerWow-android.git temp_configs && cd temp_configs && git sparse-checkout set configs && cp -r configs/* ~/azeroth-server/etc/ && cd .. && rm -rf temp_configs`

### Download server data

`curl -L https://github.com/wowgaming/client-data/releases/download/v16/data.zip -o ~/data.zip && unzip ~/data.zip -d ~/azeroth-server/ && rm ~/data.zip`

### Fix MariaDB link

##### CANNOT LINK EXECUTABLE "./authserver": library "libmariadb.so" not found: needed by main executable

`ln -sf $PREFIX/lib/aarch64-linux-android/libmariadb.so $PREFIX/lib/libmariadb.so`

### Spoof MySQL version

`echo -e "\n[mysqld]\nversion=8.0.36" >> $PREFIX/etc/my.cnf`

### Start MariaDB

`mariadbd-safe --datadir=$PREFIX/var/lib/mysql &`

### Create user

`mariadb -u root -e "DROP USER IF EXISTS 'acore'@'localhost'; CREATE USER 'acore'@'localhost' IDENTIFIED BY 'acore';"`

### Grant privileges

`mariadb -u root -e "GRANT ALL PRIVILEGES ON *.* TO 'acore'@'localhost';"`

---

## Servers should be runnable now

```
cd ~/azeroth-server/
./bin/authserver
./bin/worldserver
```

## If worldserver fails with SQL error, do this:

`curl -sL https://raw.githubusercontent.com/duall/singlePlayerWow-android/refs/heads/main/fix-modules-sql.sh | bash`

## Launch both authserver and worldserver in a single tmux window

`tmux new-session -d -c ~/azeroth-server -s azeroth './bin/authserver' \; split-window -h -c ~/azeroth-server './bin/worldserver' \; attach`

Connect with ChromieCraft 3.3.5 through Winlator (set realm to 127.0.0.1 or 192.168.x.x)

---

## Troubleshooting:

### How to create account:

Type this in worldserver window *AC>*

```
account create testacc testpwd
account set gmlevel testacc 3 -1
```

### Poor performance:

Try reducing playerbots number in: `nano ~/azeroth-server/etc/modules/playerbots.conf`

### Winlator performance boost

Disable efficiency cores in Winlator

And change this in worldserver.conf *UseProcessors = 3* (To use your CPU efficiency cores)
Ask AI for help how to modify this bitmask value to match your phone CPU

### My wifi friends cannot connect

Replace 192.168.X.XXX with your actual LAN/WAN IP (type ifconfig to find out)

`mariadb -u root -e "UPDATE acore_auth.realmlist SET address = '192.168.X.XXX' WHERE id = 1;"`
