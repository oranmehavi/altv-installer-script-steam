# altv-installer-script-steam
alt:V installer script for the Steam version only

> [!IMPORTANT]  
> Proton-tkg is so far the only known proton version to work.
> The install script will download the latest one.

# Instructions
1. create a new empty directory
2. Clone this repository by running `git clone https://github.com/oranmehavi/altv-installer-script-steam.git` in the new empty directory you created.
3. Make the script executable.
4. run this script.
5. run altv.sh to play.

# Getting logs
In order to get logs, you will need to do the following steps:
1. Add `altv.sh` to Steam as a non-Steam game.
2. Set launch arguments to `PROTON_LOG=1 %command%`.
3. Run `altv.sh` through Steam.
4. The log will be found in the home directory by the name `steam-<big_random_number>.log`.

# Credits
Daschaos
