#!/bin/bash

script_dir=$(pwd)
echo "Current directory: $script_dir"

CLASH_BIN="/usr/local/bin/mihomo"
CLASH_CONTROL="/usr/local/bin/clashctl"
CLASH_ETC="/etc/mihomo"
CLASH_CONFIG="${CLASH_ETC}/config.yaml"
CLASH_SERVICE="${CLASH_ETC}/mihomo.service"

# Check if you are running as root
if [[ $EUID -ne 0 ]]; then
	echo "ERROR: Please run this script as root!"
	exit 1
fi

# Function to handle log
handleLog() {
	echo -e "INFO: $1"
}

# Function to handle errors and exit
handleError() {
	echo -e "ERROR: $1"
	exit 1
}

# Function to detect system information
detectSystemInfo() {
	# Get the system name and architecture
	local UNAME_S=$(uname -s)
	local UNAME_M=$(uname -m)

	handleLog "Checking system infomation..."

	case "$UNAME_S" in
		Linux)
			SYSTEM=$( [ -f "/system/bin/getprop" ] && echo "android" || echo "linux" )
			;;
		*)
			handleError "Unsupported system: $UNAME_S"
			;;
	esac

	case "$SYSTEM" in
		android)
			AARCH=$( [ "$UNAME_M" = "armv7l" ] && echo "armv7" || echo "arm64-v8" )
			;;
		linux)
			AARCH=$( [ "$UNAME_M" = "x86_64" ] && echo "amd64-v1" || echo "386" )
			;;
		*)
			handleError "Unsupported architecture: $UNAME_M"
			;;
	esac
}

createAutostartService() {
	local SYSTEMD_SYMBOLIC=/etc/systemd/system/mihomo.service

	# Create a symbolic link in the systemd system directory
	if [ -f "$CLASH_SERVICE" ]; then
		ln -sf "$CLASH_ETC/mihomo.service" "$SYSTEMD_SYMBOLIC" && \
			handleLog "Create [mihomo.service] successfully." || \
			handleError "Failed to create [mihomo.service]."
	else
		handleError "[$CLASH_SERVICE] not found."
	fi

	# Enable the service to start on boot
	systemctl daemon-reload
	systemctl enable --now mihomo.service && \
		handleLog "Enable [mihomo.service] successfully." || \
		handleError "Failed to enable [mihomo.service]."
}

installClash() {
	handleLog "Installing..."

	# Get system information
	detectSystemInfo

	# Construct the binary file path based on system info
	local BINARY_FILE="./bin/mihomo-$SYSTEM-$AARCH"
	# Check if the binary file exists
	if [ -f "$BINARY_FILE" ]; then
		handleLog "Copying kernrl binary file to [$CLASH_BIN]..."
		cp -f "$BINARY_FILE" "$CLASH_BIN" || handleError "Failed to copy binary."
		chmod 0755 "$CLASH_BIN" || handleError "Failed to set execute permission."
	else
		handleError "Kernel binary file not found."
	fi

	local CONTROL_FILE="./clashctl"
	# Check if the binary file exists
	if [ -f "$CONTROL_FILE" ]; then
		handleLog "Copying kernel control script to [$CLASH_CONTROL]..."
		cp -f "$CONTROL_FILE" "$CLASH_CONTROL" || handleError "Failed to copy script."
		chmod 0755 "$CLASH_CONTROL" || handleError "Failed to set execute permission."
	else
		handleError "Kernel control script not found."
	fi

	# Create configuration directory if needed
	if [ -d "./etc" ]; then
		handleLog "Copying kernel etc files to [$CLASH_ETC]..."
		mkdir -p "$CLASH_ETC" || handleError "Failed to create directory."
		cp -rf "./etc/." "${CLASH_ETC}/"  || handleError "Failed to copy files"
	else
		handleError "Kernel etc files not found."
	fi
}

# Main script
installClash
createAutostartService
echo "ALL DONE."
echo "#############################################################"
echo "  Please edit configuration file: [$CLASH_CONFIG]  "
echo "#############################################################"
echo "`mihomo -v`"
echo "`sudo clashctl --help`"
exit 0
