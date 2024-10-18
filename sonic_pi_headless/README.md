All based on this: https://github.com/sonic-pi-net/sonic-pi/issues/3407#issuecomment-2251902029
See blog post

# Dependencies

    sudo apt install supercollider pipewire-jack ruby ruby-dev build-essential cmake ninja-build pkg-config libssl-dev erlang-dev erlang-xmerl elixir

# Download 
most recent from https://github.com/sonic-pi-net/sonic-pi/
code -> download zip

    unzip sonic-pi-dev.zip 

    cd sonic-pi-dev/app

# Edit this file

    nano linux-build-all.sh

    #"${SCRIPT_DIR}"/linux-config.sh "$@"
    #"${SCRIPT_DIR}"/linux-build-gui.sh "$@"

# build it

    ./linux-build-all.sh --system-libs

# add my new version
I thought webhooks would be good for this, but for that you need a publically available server, so I pass cleaned up data via MQTT. See square_webhook.py (which is a mess and only works in python 2).
TBH I think I should just use the API proper but here we are

    cp cube_sonicpi_headless.rb server/ruby/bin/

# edit bin/sonic-pi-repl.sh

    #"${RUBY_PATH}" "../app/server/ruby/bin/repl.rb" "$@"
    "${RUBY_PATH}" "../app/server/ruby/bin/cube_sonicpi_headless.rb" "$@"

# add the new user systemd file

    cp cube-music.service /usr/lib/systemd/user/
    systemctl --user --now enable cube-music.service 
    systemctl --user start cube-music.service

# use raspi-config to make it autologin on boot

system options -> boot / autologin -> console autologin

