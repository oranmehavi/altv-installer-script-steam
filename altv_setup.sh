#!/bin/bash

set -e
BRANCH="release"
PREFIX_PATH=""
PROTON_PATH=""
STEAM_TYPE=""
STEAM_PATH=""

function downloadProton
{
	if ! wget "https://nightly.link/Frogging-Family/wine-tkg-git/workflows/proton-arch-nopackage/master/proton-tkg-build.zip"; then
		return 1
	fi
}

function extractProton
{
	mkdir proton-tkg &> /dev/null

	if ! tar xvzf "proton-tkg-build.zip" -C "proton-tkg" --strip-components=1 &> /dev/null; then
		return 1
	fi
}

function downloadLauncher
{
	if [[ -f altv.exe ]]; then
		rm altv.exe
	fi

	if [[ -f logo_green.svg ]]; then
		rm logo_green.svg
	fi

	if ! wget "https://cdn.alt-mp.com/launcher/${BRANCH}/x64_win32/altv.exe" 2> /dev/null; then
		return 1
	fi

	if ! wget "https://altv.mp/img/branding/logo_green.svg" 2> /dev/null; then
		return 1
	fi

	return 0
}

function findCorrectSteamPath
{
	POSSIBLE_STEAM_PATHS=("$HOME/.local/share/Steam" "$HOME/.steam/root" "$HOME/.steam/steam" "$HOME/.steam/debian-installation")

	if [[ $STEAM_TYPE == "distro" ]]; then
		for val in "${POSSIBLE_STEAM_PATHS[@]}"; do
			if [[ -d $val ]]; then
				STEAM_PATH=$val
				break
			fi
		done

	elif [[ $STEAM_TYPE == "flatpak" ]]; then
		STEAM_PATH="$HOME/.var/app/com.valvesoftware.Steam/data/Steam"
	else
		STEAM_PATH="$HOME/snap/steam/common/.steam/root"
	fi
}

function getGamePath
{


	local gta_path=""
	game_search_file="$STEAM_PATH/config/libraryfolders.vdf"
	game_line_number=$(cat $game_search_file | grep -m 1 -n 271590 | cut -d':' -f1)
	game_base_path=$(head -n "$game_line_number" "$game_search_file" | tac | grep -m 1 "path" | cut -d'"' -f 4)
	gta_path="$game_base_path/steamapps/common/Grand Theft Auto V"
	echo $gta_path
	return 0
}

function createConfigFile
{
	if [[ -f altv.toml ]]; then
		rm altv.toml
	fi

	# Replace every / with \
	GTA_PATH=${GTA_PATH////\\}
	# Prepend Z: to path because of Wine Environment
	GTA_PATH="Z:$GTA_PATH"

	cat > altv.toml << EOF
branch = '$BRANCH'
gtaPlatform = 'rgl'
gtapath = '$GTA_PATH'
EOF
	return 0
}

function createStartScript
{
	if [[ -f altv.sh ]]; then
		rm altv.sh
	fi

	cat > altv.sh << EOF
#!/bin/bash

STEAM_COMPAT_CLIENT_INSTALL_PATH=$STEAM_PATH STEAM_COMPAT_DATA_PATH=$PREFIX_PATH "proton-tkg/proton" run \$(realpath altv.exe)
EOF

	return 0
}


# Discord IPC bridge was obtained by using this GitHub repo: https://github.com/openglfreak/winestreamproxy/
# Credits go to the creator of the repo - openglfreak
function addDiscordIPCBridge
{
	if ! wget "https://github.com/openglfreak/winestreamproxy/releases/download/v2.0.3/winestreamproxy-2.0.3-amd64.tar.gz" 2> /dev/null; then
		return 1
	fi
	
	winebin=$(cat "$PREFIX_PATH/config_info" | sed -n -e '4{p;q}')
	winebin="${winebin%/lib*}/bin/wine64"
	echo "$winebin"
	
	mkdir winestreamproxy-2.0.3-amd64

	tar xvzf winestreamproxy-2.0.3-amd64.tar.gz -C winestreamproxy-2.0.3-amd64 &> /dev/null

	(
		cd winestreamproxy-2.0.3-amd64
		env WINE="$winebin" WINEPREFIX="$PREFIX_PATH/pfx" ./install.sh
	)

	# Checks if installation was successful
	if [ $? -ne 0 ]; then
		rm -rf winestreamproxy-2.0.3-amd64.tar.gz winestreamproxy-2.0.3-amd64
  		return 1
	fi
	
	return 0
}

function createDesktopFile
{
	cat > altv.desktop << EOF
[Desktop Entry]
Type=Application
Name=alt:V
Icon=$(dirname "$(realpath \$0)")/logo_green.svg
GenericName=alt:V
Comment=Alternative GTA V Multiplayer experience
Exec=$(dirname "$(realpath \$0)")/altv.sh %u
Path=$(dirname "$(realpath \$0)")
StartupNotify=false
MimeType=x-scheme-handler/altv;
Categories=Game;ActionGame;AdventureGame;RolePlaying;
EOF
}

function fixActivationError
{
	if [[ ! -d backup ]]; then
		mkdir backup
	fi

	if [[ ! -L backup/steam_api64.dll ]]; then
		ln -s "$GTA_PATH/steam_api64.dll" backup/steam_api64.dll
	fi
}

function cleanUP
{
	rm -rf winestreamproxy-2.0.3-amd64.tar.gz winestreamproxy-2.0.3-amd64
}

if [[ "$EUID" -eq 0 ]]; then
	echo "Don't run as root"
	exit
fi

if [[ -n "$1" ]]; then
	if [[ "$1" == "dev" ]] || [[ "$1" == "rc" ]] || [[ "$1" == "release" ]]; then
		BRANCH="$1"
	else
		echo "Usage ./altv_setup.sh [BRANCH] [SEARCH_PATH]"
		echo -e "  BRANCH\t- dev, rc, release (default)"
		echo -e "  SEARCH_PATH\t- path used to search GTAV on steam (default: /home/$USER)"
		echo ""
		exit 1
	fi
fi

echo "Choose the type of Steam installation you have"
echo -e " 1 - Distro package (recommended)\n 2 - Flatpak\n 3 - Snap"
read -r ans

case $ans in
	1)
	STEAM_TYPE="distro"
	;;
	2)
	STEAM_TYPE="flatpak"
	;;
	3)
	STEAM_TYPE="snap"
	;;
esac

echo "Finding Steam path"
findCorrectSteamPath

echo "Searching for GTAV Path"
if [[ -n $GTA_PATH ]]; then
    echo "Skipping GTA V search, using $GTA_PATH instead."
else
    if ! GTA_PATH=$(getGamePath); then
        echo "[ERROR] Couldn't find GTAV path."
        exit 4
    fi
fi



echo $GTA_PATH
echo "Fixing activation error prompt"
fixActivationError

# Getting prefix path
PREFIX_PATH="${GTA_PATH%/common*}/compatdata/271590"

PROTON_PATH=$(head -3 "$PREFIX_PATH/config_info" | tail -1)
if [[ $PROTON_PATH == *"files"* ]]; then
	PROTON_PATH="${PROTON_PATH%/files/*}"
else
	PROTON_PATH="${PROTON_PATH%/dist/*}"
fi

echo "Downloading alt:V Launcher"
if ! downloadLauncher; then
	echo "[ERROR] Couldn't download alt:V Launcher."
	exit 3
fi

echo "Downloading proton"
if ! downloadProton; then
	echo "[ERROR] Failed to download proton."
	exit 1
fi

echo "Extracting proton, this can take few minutes"
if ! extractProton; then
	echo "[ERROR] Failed to extract proton."
	exit 2
fi

echo "Creating config file for alt:V"
if ! createConfigFile; then
	echo $?
	echo "[ERROR] Failed to create config file."
	exit 6
fi

echo "Creating start script"
if ! createStartScript; then
	echo "[ERROR] Failed to create start script."
	exit 7
fi

echo "Creating desktop file"
createDesktopFile

echo "Adding discord sdk support"
if ! addDiscordIPCBridge; then
	echo "[ERROR] Failed to download/install ipc bridge."
	exit 9
fi


chmod u+x altv.sh
chmod u+x altv.desktop
mv altv.desktop ~/.local/share/applications
xdg-mime default altv.desktop x-scheme-handler/altv
cleanUP
echo "Done. You may now start alt:V by running ./altv.sh"



exit 0
