#!/bin/bash

# ===================================================================================================
# Configuration
# ===================================================================================================
RESET_MODE=false
TEMP_DIR=$(mktemp -d)
TOTAL_STEPS=24
CURRENT_STEP=0
set -e  # Exit on error

# ===================================================================================================
# Helper functions
# ===================================================================================================
progress() {
  CURRENT_STEP=$((CURRENT_STEP + 1))
  PERCENTAGE=$((CURRENT_STEP * 100 / TOTAL_STEPS))
  BAR_WIDTH=50
  FILLED_WIDTH=$((BAR_WIDTH * PERCENTAGE / 100))

  printf "\n\033[1;36m[%3d%%]\033[0m " "$PERCENTAGE"
  printf "["
  printf "%${FILLED_WIDTH}s" | tr ' ' '='
  printf "%$((BAR_WIDTH - FILLED_WIDTH))s" | tr ' ' ' '
  printf "] "
  printf "\033[1;32mStep %d/%d:\033[0m %s\n\n" "$CURRENT_STEP" "$TOTAL_STEPS" "$1"
}

cleanup() {
  echo "Cleaning up temporary files..."
  rm -rf "$TEMP_DIR"
}

# Set trap to ensure cleanup on exit
trap cleanup EXIT

# ===================================================================================================
# Only ask for sudo password once
# ===================================================================================================
sudo echo "Defaults:$(whoami) timestamp_timeout=-1" | sudo EDITOR='tee -a' visudo

# ===================================================================================================
# Update system
# ===================================================================================================
progress "Updating system..."
sudo apt update -yqqq
sudo apt upgrade -yqqq

# ===================================================================================================
# Install packages from the default repository
# ===================================================================================================
progress "Installing packages from the default repository..."
sudo apt install -yqqq \
  apktool \
  autoconf \
  automake \
  autopoint \
  bat \
  binwalk \
  bison \
  bubblewrap \
  build-essential \
  clang \
  clang-tools \
  clangd \
  cloc \
  cmake \
  curl \
  fd-find \
  fish \
  flex \
  fzf \
  gettext \
  git \
  imagemagick \
  inetsim \
  libc6 \
  libcapstone4 \
  liblua5.1-0-dev \
  libmagickwand-dev \
  libprotobuf-dev \
  libpython3-dev \
  libstdc++6 \
  libtool \
  libz3-dev \
  lld \
  lldb \
  llvm \
  llvm-dev \
  llvm-runtime \
  lnav \
  lua5.1 \
  luajit \
  luarocks \
  m4 \
  kpartx \
  nasm \
  ninja-build \
  nmap \
  npm \
  opam \
  openjdk-17-jdk \
  pkg-config \
  protobuf-compiler \
  python3 \
  python3-dev \
  python3-pip \
  python3-venv \
  ripgrep \
  rsync \
  sqlite3 \
  tmux \
  tree-sitter-cli \
  unzip \
  visidata \
  wireshark \
  xclip \
  yara \
  zip \
  zsh \
  wine-stable \
  wine \
  wine64 \
  winetricks \
  sqlite3 \
  sqlite3-doc

# Change default shell to zsh
chsh -s "$(which fish)"

# ===================================================================================================
# Install Nerd Font
# ===================================================================================================
progress "Installing Nerd Font..."
cd "$TEMP_DIR"
wget -q https://github.com/ryanoasis/nerd-fonts/releases/download/v3.2.1/JetBrainsMono.zip
mkdir -p ~/.local/share/fonts
unzip -qq ./JetBrainsMono.zip -d ~/.local/share/fonts
fc-cache -f

echo "Nerd Font has been successfully installed!"

# ===================================================================================================
# Install current wezterm
# ===================================================================================================
progress "Installing WezTerm..."
curl -fsSL https://apt.fury.io/wez/gpg.key | sudo gpg --yes --dearmor -o /etc/apt/keyrings/wezterm-fury.gpg
echo 'deb [signed-by=/etc/apt/keyrings/wezterm-fury.gpg] https://apt.fury.io/wez/ * *' | sudo tee /etc/apt/sources.list.d/wezterm.list
sudo apt update -yqq
sudo apt install -yqq wezterm

cat > ~/.wezterm.lua << 'EOL'
local wezterm = require 'wezterm'
local config = {}
config.font = wezterm.font 'JetBrainsMono Nerd Font'
return config
EOL

echo "WezTerm has been successfully installed!"

# ===================================================================================================
# Install current neovim
# ===================================================================================================
progress "Installing Neovim..."

# Create a temporary directory for building
NVIM_BUILD_DIR="$TEMP_DIR/neovim_build"
mkdir -p "$NVIM_BUILD_DIR"
cd "$NVIM_BUILD_DIR"

# Clone the Neovim repository
git clone -q https://github.com/neovim/neovim.git
cd neovim

# Checkout the latest stable release
git checkout -q stable

# Build Neovim
make -j"$(nproc)" -s CMAKE_BUILD_TYPE=Release > /dev/null

# Install Neovim
sudo make -s install

# Verify installation
nvim --version

echo "Neovim has been successfully installed!"

# ===================================================================================================
# Configure neovim
# ===================================================================================================
progress "Configuring Neovim..."

sudo luarocks --lua-version=5.1 install magick
mkdir -p ~/.config/
cd ~/.config/
rm -rf nvim
git clone -q https://github.com/w1sent/nvim.git
nvim --headless "+Lazy! sync" +qa

echo "Neovim has been successfully configured!"

# ===================================================================================================
# Install Bindiff
# ===================================================================================================
progress "Installing BinDiff..."

# Download BinDiff
cd "$TEMP_DIR"

# Download the package from GitHub
BINDIFF_VERSION="8"
BINDIFF_URL="https://github.com/google/bindiff/releases/download/v${BINDIFF_VERSION}/bindiff_${BINDIFF_VERSION}_amd64.deb"
wget -q "$BINDIFF_URL"

# Install the package
sudo apt install -yqq "./bindiff_${BINDIFF_VERSION}_amd64.deb" > /dev/null

# Create desktop entry
mkdir -p ~/.local/share/applications
cat > ~/.local/share/applications/bindiff.desktop << 'EOL'
[Desktop Entry]
Version=1.0
Type=Application
Name=BinDiff
GenericName=Binary Diffing Tool
Comment=Quickly find differences and similarities in disassembled code
Exec=/opt/bindiff/bin/bindiff
Icon=/opt/bindiff/share/icons/hicolor/256x256/apps/bindiff.png
Terminal=false
Categories=Development;Utility;
Keywords=binary;diff;reverse engineering;
StartupNotify=true
EOL

# Set permissions
chmod +x ~/.local/share/applications/bindiff.desktop

echo "BinDiff $BINDIFF_VERSION has been successfully installed!"

# ===================================================================================================
# Install ziglang
# ===================================================================================================
progress "Installing Zig..."

cd "$TEMP_DIR"

# Function to check if URL exists
url_exists() {
  curl --output /dev/null --silent --head --fail "$1"
  return $?
}

# Function to install Zig
install_zig() {
  VERSION=$1
  FILENAME="zig-linux-x86_64-$VERSION.tar.xz"
  URL="https://ziglang.org/download/$VERSION/$FILENAME"

  echo "Downloading Zig $VERSION..."
  wget -q "$URL" -O "$FILENAME"

  # Create installation directory
  INSTALL_DIR="/usr/local/lib/zig"
  sudo mkdir -p "$INSTALL_DIR"

  echo "Extracting Zig to $INSTALL_DIR..."
  sudo tar -xf "$FILENAME" -C "$INSTALL_DIR"

  # Create symbolic link
  echo "Creating symbolic link..."
  sudo ln -sf "$INSTALL_DIR/zig-linux-x86_64-$VERSION/zig" /usr/local/bin/zig

  echo "Zig $VERSION has been successfully installed!"
}

# Check for Zig versions
PREFERRED_VERSION="0.14.0"
FALLBACK_VERSION="0.13.0"

echo "Checking for Zig $PREFERRED_VERSION..."0.18.2
if url_exists "https://ziglang.org/download/$PREFERRED_VERSION/zig-linux-x86_64-$PREFERRED_VERSION.tar.xz"; then
  install_zig "$PREFERRED_VERSION"
else
  echo "Zig $PREFERRED_VERSION is not available. Falling back to $FALLBACK_VERSION..."

  # Check if fallback version exists
  if url_exists "https://ziglang.org/download/$FALLBACK_VERSION/zig-linux-x86_64-$FALLBACK_VERSION.tar.xz"; then
    install_zig "$FALLBACK_VERSION"
  else
    echo "Error: Neither Zig $PREFERRED_VERSION nor $FALLBACK_VERSION are available."
    exit 1
  fi
fi

# Verify installation
echo "Verifying installation..."
zig version
echo "Zig has been successfully installed!"

# ===================================================================================================
# Install Ghidra
# ===================================================================================================
progress "Installing Ghidra..."

# Create installation directory
INSTALL_DIR="/opt/ghidra"
sudo mkdir -p "$INSTALL_DIR"

# Download Ghidra
cd "$TEMP_DIR"
wget -q https://github.com/NationalSecurityAgency/ghidra/releases/download/Ghidra_11.3.1_build/ghidra_11.3.1_PUBLIC_20250219.zip

# Extract files
sudo unzip -q ghidra_11.3.1_PUBLIC_20250219.zip -d "$INSTALL_DIR"

# Create symbolic link to the executable
GHIDRA_DIR="$INSTALL_DIR/ghidra_11.3.1_PUBLIC"
sudo ln -sf "$GHIDRA_DIR/ghidraRun" /usr/local/bin/ghidra

# Download icon (using the icon from the Ghidra package)
ICON_PATH="$GHIDRA_DIR/support/ghidra.ico"

# Create desktop entry
mkdir -p ~/.local/share/applications
cat > ~/.local/share/applications/ghidra.desktop << EOL
[Desktop Entry]
Version=1.0
Type=Application
Name=Ghidra
GenericName=Reverse Engineering Framework
Comment=Ghidra is a software reverse engineering (SRE) framework
Exec=$GHIDRA_DIR/ghidraRun
Icon=$ICON_PATH
Terminal=false
Categories=Development;Utility;
Keywords=reverse engineering;decompiler;disassembler;
StartupNotify=true
EOL

# Set permissions
chmod +x ~/.local/share/applications/ghidra.desktop

echo "Ghidra has been successfully installed!"

# ===================================================================================================
# Install ImHex
# ===================================================================================================
progress "Installing ImHex..."
cd "$TEMP_DIR"
wget -q https://github.com/WerWolv/ImHex/releases/download/v1.37.4/imhex-1.37.4-Ubuntu-24.04-x86_64.deb
sudo apt install -yqq ./imhex-1.37.4-Ubuntu-24.04-x86_64.deb

# ===================================================================================================
# Install python packages
# ===================================================================================================
progress "Installing Python packages..."

# Create a Python virtual environment
VENV_DIR="$HOME/venv/analysis"
python3 -m venv "$VENV_DIR"

# Install packages using pip
"$VENV_DIR/bin/pip" -q install capstone \
                                pefile \
                                angr \
                                python-registry \
                                triton \
                                miasm \
                                python-bindiff \
                                frida-tools \
                                lief \
                                reflutter \
                                jupyter \
                                ast-grep-cli \
                                mitmproxy \
                                dnfile \
                                tree-sitter \
                                tree-sitter-python \
                                tree-sitter-javascript \
                                tree-sitter-c \
                                tree-sitter-cpp \
                                tree-sitter-go \
                                tree-sitter-php \
                                tree-sitter-java \
                                tree-sitter-csharp

"$VENV_DIR/bin/pip" -q install https://github.com/mandiant/flare-floss/archive/master.zip

# Add to zsh config
echo "# Reverse engineering environment" >> "$HOME/.zshrc"
echo "source $VENV_DIR/bin/activate" >> "$HOME/.zshrc"

# Add to fish config
mkdir -p "$HOME/.config/fish"
echo "# Reverse engineering environment" >> "$HOME/.config/fish/config.fish"
echo "source $VENV_DIR/bin/activate.fish" >> "$HOME/.config/fish/config.fish"

echo "Installation complete!"
echo "To activate your environment, run: source $VENV_DIR/bin/activate"

# source python environment
source "$VENV_DIR/bin/activate"

echo "Python packages have been successfully installed!"

# ===================================================================================================
# Install quarto
# ===================================================================================================
progress "Installing Quarto..."

cd "$TEMP_DIR"
wget -q https://github.com/quarto-dev/quarto-cli/releases/download/v1.6.42/quarto-1.6.42-linux-amd64.deb
sudo apt install -yqqq ./quarto-1.6.42-linux-amd64.deb > /dev/null

echo "Quarto has been successfully installed!"

# ===================================================================================================
# Install Cyber Chef
# ===================================================================================================
progress "Installing CyberChef..."

# Create directory for CyberChef
CYBERCHEF_DIR="$HOME/.local/share/cyberchef"
mkdir -p "$CYBERCHEF_DIR"

# Download latest CyberChef release
wget -q https://github.com/gchq/CyberChef/releases/download/v10.19.4/CyberChef_v10.19.4.zip -O "$CYBERCHEF_DIR/CyberChef_latest.zip"

# Extract files
unzip -q "$CYBERCHEF_DIR/CyberChef_latest.zip" -d "$CYBERCHEF_DIR"
rm "$CYBERCHEF_DIR/CyberChef_latest.zip"

# Find the actual HTML file name
CYBERCHEF_HTML=$(find "$CYBERCHEF_DIR" -name "CyberChef_*.html" -type f -printf "%f\n")

# Create applications directory if it doesn't exist
mkdir -p "$HOME/.local/share/applications"

# Download CyberChef icon
wget -q https://raw.githubusercontent.com/gchq/CyberChef/master/src/web/static/images/favicon.ico -O "$CYBERCHEF_DIR/cyberchef.ico"

# Create desktop entry file
cat > "$HOME/.local/share/applications/cyberchef.desktop" << EOL
[Desktop Entry]
Version=1.0
Type=Application
Name=CyberChef
Comment=The Cyber Swiss Army Knife
Exec=xdg-open $CYBERCHEF_DIR/$CYBERCHEF_HTML
Icon=$CYBERCHEF_DIR/cyberchef.ico
Terminal=false
Categories=Utility;Development;
Keywords=cyber;encryption;decryption;encoding;decoding;
StartupNotify=true
EOL

# Set permissions
chmod +x "$HOME/.local/share/applications/cyberchef.desktop"

echo "CyberChef has been successfully installed!"

# ===================================================================================================
# Install JADX
# ===================================================================================================
progress "Installing JADX..."

# Create directory for JADX
JADX_DIR="/opt/jadx"
sudo mkdir -p "$JADX_DIR"

# Download latest JADX release
cd "$TEMP_DIR"
wget -q https://github.com/skylot/jadx/releases/latest/download/jadx-1.5.1.zip

# Extract files
sudo unzip -q jadx-1.5.1.zip -d "$JADX_DIR"

# Create symbolic links
sudo ln -sf "$JADX_DIR/bin/jadx" /usr/local/bin/jadx
sudo ln -sf "$JADX_DIR/bin/jadx-gui" /usr/local/bin/jadx-gui

# Create desktop entry for jadx-gui
cat > "$HOME/.local/share/applications/jadx-gui.desktop" << EOL
[Desktop Entry]
Version=1.0
Type=Application
Name=JADX GUI
Comment=Dex to Java decompiler
Exec=jadx-gui
Icon=$JADX_DIR/lib/jadx-logo.png
Terminal=false
Categories=Development;
EOL

# Set permissions
chmod +x "$HOME/.local/share/applications/jadx-gui.desktop"

echo "JADX has been successfully installed!"

# ===================================================================================================
# Install DynamoRIO
# ===================================================================================================
progress "Installing DynamoRIO..."

# Create installation directory
DYNAMORIO_DIR="/opt/dynamorio"
sudo mkdir -p "$DYNAMORIO_DIR"

# Download DynamoRIO
cd "$TEMP_DIR"
wget -q "https://github.com/DynamoRIO/dynamorio/releases/download/release_11.3.0-1/DynamoRIO-Linux-11.3.0.tar.gz"

# Extract files
sudo tar -xzf "DynamoRIO-Linux-11.3.0.tar.gz" -C "$DYNAMORIO_DIR" --strip-components=1

# Create symbolic links to common tools
sudo mkdir -p /usr/local/bin

# Link common DynamoRIO tools
sudo ln -sf "$DYNAMORIO_DIR/bin64/drrun" /usr/local/bin/drrun
sudo ln -sf "$DYNAMORIO_DIR/bin64/drcov" /usr/local/bin/drcov
sudo ln -sf "$DYNAMORIO_DIR/bin64/drcachesim" /usr/local/bin/drcachesim
sudo ln -sf "$DYNAMORIO_DIR/bin64/drltrace" /usr/local/bin/drltrace
sudo ln -sf "$DYNAMORIO_DIR/bin64/drdisas" /usr/local/bin/drdisas

# Create desktop entry for documentation
cat > "$HOME/.local/share/applications/dynamorio-docs.desktop" << EOL
[Desktop Entry]
Version=1.0
Type=Application
Name=DynamoRIO Documentation
GenericName=Dynamic Instrumentation Tool Platform
Comment=Documentation for DynamoRIO dynamic binary instrumentation framework
Exec=xdg-open $DYNAMORIO_DIR/docs/html/index.html
Icon=$DYNAMORIO_DIR/docs/images/DynamoRIO-logo.png
Terminal=false
Categories=Development;Utility;
Keywords=binary instrumentation;dynamic analysis;
StartupNotify=true
EOL

# Set permissions
chmod +x "$HOME/.local/share/applications/dynamorio-docs.desktop"

echo "DynamoRIO has been successfully installed!"

# ===================================================================================================
# Install .NET SDK
# ===================================================================================================
progress "Installing .NET SDK..."
cd "$TEMP_DIR"

# Install .NET SDK
sudo add-apt-repository -y ppa:dotnet/backports
sudo apt update -yqqq
sudo apt install -yqqq dotnet-sdk-9.0 dotnet-sdk-8.0 dotnet-sdk-6.0

# Install .NET interactive kernel
dotnet tool install -v q -g Microsoft.dotnet-interactive

# Add .NET Core SDK tools to PATH in bash
export PATH="$PATH:/home/user/.dotnet/tools"
cat << \EOF >> ~/.bash_profile
# Add .NET Core SDK tools
export PATH="$PATH:/home/user/.dotnet/tools"
EOF
# Add .NET Core SDK tools to PATH in zshrc
cat << \EOF >> ~/.zshrc
# Add .NET Core SDK tools
export PATH="$PATH:/home/user/.dotnet/tools"
EOF

dotnet interactive jupyter install

echo ".NET SDK has been successfully installed!"

# ===================================================================================================
# Install libewf
# ===================================================================================================
progress "Installing libewf..."
cd "$TEMP_DIR"
git clone https://github.com/libyal/libewf.git
cd libewf/
./synclibs.sh > /dev/null
./autogen.sh > /dev/null
./configure -q --enable-verbose-output --enable-shared=no --enable-static-executables=yes --enable-python --enable-wide-character-type
make -s -j"$(nproc)" > /dev/null
sudo make -s install
sudo ldconfig

echo "libewf has been successfully installed!"

# ===================================================================================================
# Install delta
# ===================================================================================================
progress "Installing Delta..."
cd "$TEMP_DIR"
wget -q https://github.com/dandavison/delta/releases/download/0.18.2/git-delta_0.18.2_amd64.deb
sudo apt install -yqqq ./git-delta_0.18.2_amd64.deb

cat << \EOF >> ~/.gitconfig
[core]
    pager = delta

[interactive]
    diffFilter = delta --color-only

[delta]
    navigate = true  # use n and N to move between diff sections
    dark = true      # or light = true, or omit for auto-detection
    line-numbers = true

[merge]
    conflictstyle = zdiff3
EOF

echo "Delta has been successfully installed!"

# ===================================================================================================
# Install euproie
# ===================================================================================================
progress "Installing EUPROIE..."
pip3 install euporie > /dev/null
echo "EUPROIE has been successfully installed!"


# ===================================================================================================
# Install pwndbg
# ===================================================================================================
progress "Installing Pwndbg..."
cd "$TEMP_DIR"
wget -q wget -q https://github.com/pwndbg/pwndbg/releases/download/2025.02.19/pwndbg_2025.02.19_am
sudo apt install -yqq ./pwndbg_2025.02.19_amd64.deb

echo "Pwndbg has been successfully installed!"

# ===================================================================================================
# Install powershell
# ===================================================================================================
progress "Installing PowerShell..."
cd "$TEMP_DIR"
wget -q https://github.com/PowerShell/PowerShell/releases/download/v7.4.7/powershell_7.4.7-1.deb_amd64.deb
sudo apt install -yqq ./powershell_7.4.7-1.deb_amd64.deb > /dev/null

echo "PowerShell has been successfully installed!"

# ===================================================================================================
# Install ILSpy
# ===================================================================================================
progress "Installing ILSpy..."
cd "$TEMP_DIR"
dotnet tool install --global ilspycmd

echo "ILSpy has been successfully installed!"

# ===================================================================================================
# Configure tree-sitter
# ===================================================================================================
progress "Configuring tree-sitter..."
mkdir -p ~/treesitter/languages
cd ~/treesitter/languages
wget -q https://github.com/tree-sitter/tree-sitter-c-sharp/archive/refs/tags/v0.23.1.tar.gz
wget -q https://github.com/tree-sitter/tree-sitter-cpp/releases/download/v0.23.4/tree-sitter-cpp.tar.xz
wget -q https://github.com/tree-sitter/tree-sitter-php/releases/download/v0.23.12/tree-sitter-php.tar.gz
wget -q https://github.com/tree-sitter/tree-sitter-c/releases/download/v0.23.5/tree-sitter-c.tar.gz
wget -q https://github.com/tree-sitter/tree-sitter-javascript/releases/download/v0.23.1/tree-sitter-javascript.tar.xz
wget -q https://github.com/tree-sitter/tree-sitter-json/releases/download/v0.24.8/tree-sitter-json.tar.xz
wget -q https://github.com/tree-sitter/tree-sitter-html/releases/download/v0.23.2/tree-sitter-html.tar.xz
wget -q https://github.com/tree-sitter/tree-sitter-regex/releases/download/v0.24.3/tree-sitter-regex.tar.xz
wget -q https://github.com/tree-sitter/tree-sitter-bash/releases/download/v0.23.3/tree-sitter-bash.tar.xz
wget -q https://github.com/tree-sitter/tree-sitter-css/releases/download/v0.23.2/tree-sitter-css.tar.xz
wget -q https://github.com/tree-sitter/tree-sitter-python/releases/download/v0.23.6/tree-sitter-python.tar.xz
mkdir -p ~/treesitter/libs
wget -q https://github.com/tree-sitter/zig-tree-sitter/archive/refs/tags/v0.25.0.zip

echo "Configuring tree-sitter finished."

# ===================================================================================================
# Install fakenet-ng
# ===================================================================================================
progress "Install FakeNet-NG..."
cd "$TEMP_DIR"
pip install https://github.com/mandiant/flare-fakenet-ng/zipball/master

echo "All installations completed successfully!"
