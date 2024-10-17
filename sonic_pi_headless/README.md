All based on this: https://github.com/sonic-pi-net/sonic-pi/issues/3407#issuecomment-2251902029

# deps

sudo apt install supercollider pipewire-jack ruby ruby-dev build-essential cmake ninja-build pkg-config libssl-dev erlang-dev erlang-xmerl elixir

# download most recent

unzip sonic-pi-dev.zip 

cd sonic-pi-dev/app

# edit this file

pico linux-build-all.sh

#"${SCRIPT_DIR}"/linux-config.sh "$@"
#"${SCRIPT_DIR}"/linux-build-gui.sh "$@"

./linux-build-all.sh --system-libs

# add my new version

cp cube_sonicpi_headless.rb server/ruby/bin/

# edit bin/sonic-pi-repl.sh

#"${RUBY_PATH}" "../app/server/ruby/bin/repl.rb" "$@"
"${RUBY_PATH}" "../app/server/ruby/bin/cube_sonicpi_headless.rb" "$@"

# add the new user systemd file

cp cube-music.service /usr/lib/systemd/user/
systemctl --user --now enable cube-music.service 
systemctl --user start cube-music.service

# use raspi-config to make it boot into 

system options -> boot / autologin -> console autologin

