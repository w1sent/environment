#!/bin/fish

# This script is intended to be run on a fresh analysis enviroment based on arch linux installation.

echo -e "\033[1;32m========== Arch Linux Analysis Tools Installer ==========\033[0m"
echo "This script will install a comprehensive set of analysis and reverse engineering tools."
echo "It may take a while depending on your internet connection and system performance."
echo -e "\033[1;33mNote: You may be asked for your sudo password during installation.\033[0m"

# ===================================================
# Variables
# ===================================================
set TEMP_DIR (mktemp -d)
set STEP 0
set TOTAL_STEPS 16

cd $TEMP_DIR

# ==================================================
# utility functions
# ==================================================
function cleanup
echo -e "\033[1;31m========== Cleanup ==========\033[0m"
    echo "Removing temporary directory..."
    rm -rf $TEMP_DIR
    echo "Cleanup completed."
end

function run
  echo $argv
  set result "$(eval $argv)"
  if test $status -ne 0
    echo -e "\033[1;31mError: Command failed: $argv\033[0m"
echo "Output: $result"
    exit 1
  end
end

function download
  set url $argv[1]
  set filename $TEMP_DIR/$argv[2]
  echo -e "\n\033[1;34mDownloading: $url\033[0m"
  run wget -q --show-progress -O $filename $url
  echo -e "\033[1;32mDownloaded: $filename\033[0m\n"
end

function install_package
  run sudo pacman -S --noconfirm $argv
  echo -e "\033[1;32mInstalled: $package\033[0m"
end

function stage
  set STEP (math "$STEP + 1")
  echo ""
  echo -e "\033[1;34m========== Step $STEP/$TOTAL_STEPS: $argv ==========\033[0m"
  echo ""
end

function stage_msg
  echo -e "\033[1;32m$argv successfully.\033[0m"
end

trap cleanup EXIT

# ===================================================
# Initial Configuration
# ===================================================

# Make sudo session persistent
sudo echo "Defaults:$(whoami) timestamp_timeout=-1" | sudo EDITORS="tee -a" visudo


# ==================================================
# Update system
# ==================================================
function update_system
  stage "Update System"
  run sudo pacman -Syu --noconfirm
  stage_msg "System updated"
end

# ==================================================
# install base environment
# ==================================================

function install_base
  stage "Install Base Environment"
  set -l packages \
    "base" \
    "base-devel" \
    "linux-headers" \
    "curl" \
    "git" \
    "wget" \
    "python" \
    "python-pip" \
    "python-setuptools" \
    "python-virtualenv" \
    "fzf" \
    "ripgrep" \
    "fd" \
    "bat" \
    "tree" \
    "htop" \
    "xclip" \
    "firefox" \
    "unzip" \
    "wine" \
    "automake" \
    "autoconf" \
    "tmux" \
    "sqlite" \
    "rsync" \
    "cmake" \
    "bison" \
    "wezterm" \
    "multipath-tools"

  install_package $packages
  stage_msg "Base packages installed"

  # Install fonts
  set FONT_DIR "~/.local/share/fonts/"
  mkdir -p $FONT_DIR

  download "https://github.com/ryanoasis/nerd-fonts/releases/download/v3.2.1/JetBrainsMono.zip" "JetBrainsMono.zip"
  run unzip -q "JetBrainsMono.zip" -d $FONT_DIR
  run fc-cache -f
  stage_msg "Fonts installed"

  echo "local wezterm = require 'wezterm'
local config = {}
config.font = wezterm.font 'JetBrainsMono Nerd Font'
return config
" > ~/.wezterm.lua

  chown $(whoami):$(whoami) ~/.wezterm.lua
  stage_msg "Base environment installed"
end

# ==================================================
# Install EDITORS
# ==================================================

function install_editors
  stage "Install Editors"
  install_package neovim lua51 luarocks luajit npm rust tree-sitter
  stage_msg "Editors installed successfully."

  # Configure neovim
  mkdir -p ~/.config/
  cd ~/.config/
  rm -rf nvim
  git clone -q https://github.com/w1sent/nvim.git
  run nvim --headless '+Lazy! sync' +qa

  cd $TMP_DIR
  stage_msg "Editors installed"
end

# ==================================================
# Install Development tools
# ==================================================

function install_dev_tools
  stage "Install Development Tools"
  set -l packages \
    "cmake" \
    "ninja" \
    "lld" \
    "clang" \
    "clang-tools-extra" \
    "llvm" \
    "opam" \
    "ocaml" \
    "nasm" \
    "lldb" \
    "jdk-openjdk" \
    "flex" \
    "z3" \
    "protobuf" \
    "git-delta" \
    "zig" \
    "dotnet-sdk" \
    "dotnet-sdk-8.0" \
    "dotnet-sdk-6.0" \
    "aspnet-runtime" \
    "aspnet-runtime-8.0" \
    "aspnet-runtime-6.0" \
    "go"

  install_package $packages
  stage_msg "Development tools installed"

  # Configure git-delta
  echo "[core]
    pager = delta

[interactive]
    diffFilter = delta --color-only

[delta]
    navigate = true  # use n and N to move between diff sections
    dark = true      # or light = true, or omit for auto-detection
    line-numbers = true

[merge]
    conflictstyle = zdiff3
" > ~/.gitconfig
  stage_msg "data configured"
end


# ==================================================
# Install Reporting Tools
# ==================================================

function install_reporting_tools
  stage "Install Reporting Tools"
  set -l packages \
    "pandoc" \
    "typst"

  install_package $packages

  stage_msg "reporting installed"
end

# ==================================================
# Install mobile Tools
# ==================================================

function install_mobile_tools
  stage "Install Mobile Tools"
  set -l packages \
    "android-tools" \
    "android-udev" \
    "jadx"

  install_package $packages
  stage_msg "Mobile tools installed"
end

# ==================================================
# Dotnet Analysis tools
# ==================================================

function install_dotnet_analysis_tools
  stage "Install Dotnet Analysis Tools"
  run dotnet tool install -g ilspycmd

  set -l libs_path "~/libs/dnlib"
  run mkdir -p $libs_path

  cd $TEMP_DIR
  download "https://github.com/0xd4d/dnlib/archive/refs/tags/v4.4.0.zip" "dnlib.zip"
  run unzip -q "dnlib.zip" -d $libs_path

  stage_msg "Dotnet analysis tools installed"
end

# ==================================================
# Install Python environment
# ==================================================

function install_python_env
  stage "Install Python Environment"
  cd ~
  run python -m venv .venv/analysis
  # Activate the virtual environment with every startup
  echo "source ~/.venv/analysis/bin/activate.fish" >> ~/.config/fish/config.fish
  echo "source ~/.venv/analysis/bin/activate" >> ~/.bashrc
  run .venv/analysis/bin/pip install --upgrade pip
  cd $TEMP_DIR

  set -l py_packages \
    "capstone" \
    "pefile" \
    "python-registry" \
    "triton" \
    "miasm" \
    "python-bindiff" \
    "frida-tools" \
    "lief" \
    "reflutter" \
    "ast-grep-cli" \
    "mitmproxy" \
    "dnfile" \
    "euporie" \
    "jupyter"


  set -l treesitter_packages \
    "tree-sitter" \
    "tree-sitter-c-sharp" \
    "tree-sitter-cpp" \
    "tree-sitter-c" \
    "tree-sitter-go" \
    "tree-sitter-php" \
    "tree-sitter-java" \
    "tree-sitter-python" \
    "tree-sitter-javascript"

  run ~/.venv/analysis/bin/pip install $py_packages
  run ~/.venv/analysis/bin/pip install $treesitter_packages
  run ~/.venv/analysis/bin/pip install "https://github.com/mandiant/flare-floss/archive/master.zip"

  stage_msg "Python environment installed"
end

# ==================================================
# Install other tools
# ==================================================

function install_other_tools
  stage "Install Other Tools"
  set -l packages \
    "binwalk" \
    "foremost" \
    "lnav" \
    "veracrypt" \
    "ssdeep" \
    "hashcat" \
    "john" \
    "yara" \
    "nmap" \
    "bc" \
    "graphviz" \
    "gnuplot" \
    "kicad" \
    "wireshark-qt" \

  install_package $packages
  stage_msg "Other tools installed"
end

# ==================================================
# Install ghidra
# ==================================================

function install_ghidra
  stage "Install Ghidra"

  cd $TEMP_DIR

  set -l ghidra_url "https://github.com/NationalSecurityAgency/ghidra/releases/download/Ghidra_11.3.1_build/ghidra_11.3.1_PUBLIC_20250219.zip"
  set -l ghidra_zip "ghidra.zip"
  set -l ghidra_dir "/opt/ghidra"

  run sudo mkdir -p $ghidra_dir

  download $ghidra_url $ghidra_zip
  run sudo unzip -q $ghidra_zip -d $ghidra_dir

  # Create a symbolic link to the ghidra directory
  run sudo ln -s -f $ghidra_dir/ghidra_11.3.1_PUBLIC/ghidraRun /usr/local/bin/ghidra

  # Create a desktop entry for Ghidra
  run mkdir -p ~/.local/share/applications
  echo "[Desktop Entry]
Version=1.0
Type=Application
Name=Ghidra
GenericName=Reverse Engineering Framework
Comment=Ghidra is a software reverse engineering (SRE) framework
Exec=$ghidra_dir/ghidra_11.3.1_PUBLIC/ghidraRun
Icon=$icon_path
Terminal=false
Categories=Development;Utility;
Keywords=reverse engineering;decompiler;disassembler;
StartupNotify=true
" > ~/.local/share/applications/ghidra.desktop

  run chmod +x ~/.local/share/applications/ghidra.desktop

  stage_msg "Ghidra installed"
end

# ==================================================
# Install Imhex
# ==================================================

function install_imhex
  stage "Install Imhex"
  cd $TEMP_DIR

  download "https://github.com/WerWolv/ImHex/releases/download/v1.37.4/imhex-1.37.4-ArchLinux-x86_64.pkg.tar.zst" "imhex.tar.zst"

  run sudo pacman -U --noconfirm imhex.tar.zst
  stage_msg "ImHex installed"
end


# ==================================================
# Install DynamoRIO
# ==================================================

function install_dynamorio
  stage "Install DynamoRIO"

  set install_path "/opt/dynamorio"
  run sudo mkdir -p $install_path

  set dynamorio_url "https://github.com/DynamoRIO/dynamorio/releases/download/release_11.3.0-1/DynamoRIO-Linux-11.3.0.tar.gz"
  set dynamorio_tar "dynamorio.tar.gz"

  download $dynamorio_url $dynamorio_tar

  run sudo tar -xzf $dynamorio_tar -C $install_path --strip-components=1

  run mkdir -p /usr/local/bin/

  set -l dynamo_tools "drrun" "drcov" "drcachesim" "drltrace" "drdisas"
  for tool in $dynamo_tools
    run sudo ln -s -f $install_path/bin64/$tool /usr/local/bin/$tool
  end

  stage_msg "DynamoRIO installed"
end


# ==================================================
# Install CyberChef
# ==================================================

function install_cyber_chef
  stage "Install CyberChef"
  cd $TEMP_DIR

  set cyber_chef_dir "~/.local/share/cyberchef"
  run mkdir -p $cyber_chef_dir

  set cyberchef_url "https://github.com/gchq/CyberChef/releases/download/v10.19.4/CyberChef_v10.19.4.zip"
  set cyberchef_zip "cyberchef.zip"

  download $cyberchef_url $cyberchef_zip
  run unzip -q $cyberchef_zip -d $cyber_chef_dir

  set cyberchef_html (find $cyber_chef_dir -name "index.html" -type f -printf "%f\n")
  set icon_url "https://raw.githubusercontent.com/gchq/CyberChef/master/src/web/static/images/favicon.ico"
  set icon_path "$cyber_chef_dir/cyberchef.ico"
  download $icon_url "cyberchef.ico"
  run mv "cyberchef.ico" $cyber_chef_dir

  # Create a desktop entry for CyberChef
  echo "[Desktop Entry]
Version=1.0
Type=Application
Name=CyberChef
Comment=The Cyber Swiss Army Knife
Exec=xdg-open $cyber_chef_dir/$cyberchef_html
Icon=$icon_path
Terminal=false
Categories=Utility;Development;
Keywords=cyber;encryption;decryption;encoding;decoding;
StartupNotify=true
" > ~/.local/share/applications/cyberchef.desktop

  run chmod +x ~/.local/share/applications/cyberchef.desktop

  stage_msg "CyberChef installed"
end

# ==================================================
# Install pwndbg
# ==================================================

function install_pwndbg
  stage "Install pwndbg"

  cd $TEMP_DIR

  run git clone "https://github.com/pwndbg/pwndbg"
  cd pwndbg
  run ./setup.sh

  cd $TEMP_DIR
  stage_msg "pwndbg installed"
end

# ==================================================
# Instal libewf
# ==================================================

function install_libewf
  stage "Install libewf"
  install_package libewf
  stage_msg "libewf installed"
end


function install_zoekt
  stage "Install zoekt"
  go install github.com/sourcegraph/zoekt/cmd/zoekt-webserver@main
  go install github.com/sourcegraph/zoekt/cmd/zoekt-indexserver@main
  go install github.com/sourcegraph/zoekt/cmd/zoekt@main
  go install github.com/sourcegraph/zoekt/cmd/zoekt-index@main
  go install github.com/sourcegraph/zoekt/cmd/zoekt-git-index@main
  run ln -s $(go env GOPATH)/bin/zoekt* /usr/bin/
  stage_msg "zoekt installed"
end

# ==================================================
# Main function
# ==================================================

update_system
install_base
install_python_env
install_editors
install_dev_tools
install_mobile_tools
install_other_tools
install_ghidra
install_imhex
install_dynamorio
install_cyber_chef
install_libewf
install_pwndbg
install_reporting_tools
install_dotnet_analysis_tools
install_zoekt
cleanup
