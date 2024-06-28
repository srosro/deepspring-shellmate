#!/bin/sh

# Define the target executables and directories
MAIN_EXECUTABLE_NAME="sb"
PASTE_EXECUTABLE_NAME="sb_paste"
TARGET_DIR="$HOME/shellbuddy"
LINK_DIR="$HOME/bin"

# Remove the symbolic link for the main executable
echo "Removing symbolic link for $MAIN_EXECUTABLE_NAME in $LINK_DIR..."
rm -f $LINK_DIR/$MAIN_EXECUTABLE_NAME
if [ $? -ne 0 ]; then
    echo "Error: Failed to remove symbolic link for $MAIN_EXECUTABLE_NAME in $LINK_DIR."
    exit 1
fi

# Remove the executables from the target directory
echo "Removing $MAIN_EXECUTABLE_NAME and $PASTE_EXECUTABLE_NAME from $TARGET_DIR..."
rm -f $TARGET_DIR/$MAIN_EXECUTABLE_NAME
if [ $? -ne 0 ]; then
    echo "Error: Failed to remove $MAIN_EXECUTABLE_NAME from $TARGET_DIR."
    exit 1
fi

rm -f $TARGET_DIR/$PASTE_EXECUTABLE_NAME
if [ $? -ne 0 ]; then
    echo "Error: Failed to remove $PASTE_EXECUTABLE_NAME from $TARGET_DIR."
    exit 1
fi

# Optionally, remove the target directory if it is empty
if [ -z "$(ls -A $TARGET_DIR)" ]; then
    echo "Removing empty directory $TARGET_DIR..."
    rmdir $TARGET_DIR
    if [ $? -ne 0 ]; then
        echo "Error: Failed to remove empty directory $TARGET_DIR."
        exit 1
    fi
else
    echo "Directory $TARGET_DIR is not empty, not removing."
fi

echo "Uninstallation complete."
