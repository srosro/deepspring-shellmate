#!/bin/sh

# Get the directory of the script
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Define the source files and the target executables
MAIN_SOURCE_FILE="$SCRIPT_DIR/main.swift"
PASTE_SOURCE_FILE="$SCRIPT_DIR/paste.swift"
MAIN_EXECUTABLE_NAME="sb"
PASTE_EXECUTABLE_NAME="sb_paste"
TARGET_DIR="$HOME/shellbuddy"
LINK_DIR="$HOME/bin"

echo -e "Starting installation script from:\n $SCRIPT_DIR"

echo -e "\nFiles in the directory:\n"
ls "$SCRIPT_DIR"

# Check if swiftc is installed
if ! command -v swiftc &> /dev/null
then
    echo "Error: swiftc could not be found. Please install Swift."
    exit 1
fi

# Create the target directory if it does not exist
echo "Creating target directory $TARGET_DIR if it does not exist..."
mkdir -p $TARGET_DIR
if [ $? -ne 0 ]; then
    echo "Error: Failed to create target directory $TARGET_DIR."
    exit 1
fi


# Move the executables to the target directory
echo "Moving $MAIN_EXECUTABLE_NAME and $PASTE_EXECUTABLE_NAME to $TARGET_DIR..."
cp "$SCRIPT_DIR/$MAIN_EXECUTABLE_NAME" "$TARGET_DIR"
if [ $? -ne 0 ]; then
    echo "Error: Failed to move $MAIN_EXECUTABLE_NAME to $TARGET_DIR."
    exit 1
fi

cp "$SCRIPT_DIR/$PASTE_EXECUTABLE_NAME" "$TARGET_DIR"
if [ $? -ne 0 ]; then
    echo "Error: Failed to move $PASTE_EXECUTABLE_NAME to $TARGET_DIR."
    exit 1
fi


# Create the link directory if it does not exist
echo "Creating link directory $LINK_DIR if it does not exist..."
mkdir -p $LINK_DIR
if [ $? -ne 0 ]; then
    echo "Error: Failed to create link directory $LINK_DIR."
    exit 1
fi

# Determine the user's shell and update the appropriate profile
if [ "$SHELL" = "/bin/zsh" ]; then
    SHELL_PROFILE="$HOME/.zshrc"
elif [ "$SHELL" = "/bin/bash" ]; then
    SHELL_PROFILE="$HOME/.bashrc"
else
    # Default to zsh if shell cannot be determined
    SHELL_PROFILE="$HOME/.zshrc"
fi

# Add $LINK_DIR to PATH if not already present
if ! grep -q "$LINK_DIR" "$SHELL_PROFILE"; then
    echo "Adding $LINK_DIR to PATH in $SHELL_PROFILE..."
    echo "export PATH=\"$LINK_DIR:\$PATH\"" >> "$SHELL_PROFILE"
    if [ $? -ne 0 ]; then
        echo "Error: Failed to add $LINK_DIR to PATH."
        exit 1
    fi
else
    echo "$LINK_DIR is already in PATH."
fi

# Create a symbolic link for the main executable in the link directory
echo "Creating a symbolic link for $MAIN_EXECUTABLE_NAME in $LINK_DIR..."
ln -sf "$TARGET_DIR/$MAIN_EXECUTABLE_NAME" "$LINK_DIR/$MAIN_EXECUTABLE_NAME"
if [ $? -ne 0 ]; then
    echo "Error: Failed to create symbolic link for $MAIN_EXECUTABLE_NAME in $LINK_DIR."
    exit 1
fi

# Source the shell profile to update the current session
echo "Sourcing $SHELL_PROFILE to update the current session..."
. "$SHELL_PROFILE"
if [ $? -ne 0 ]; then
    echo "Error: Failed to source $SHELL_PROFILE."
    exit 1
fi

echo "Installation complete. You can now use the command '$MAIN_EXECUTABLE_NAME' system-wide."
echo "Please restart your terminal or run 'source $SHELL_PROFILE' to update your PATH."
