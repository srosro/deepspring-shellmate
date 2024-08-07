#!/bin/sh

#  uninstall_v2.sh
#  ShellMate
#
#  Created by Daniel Delattre on 06/08/24.
#

# Get the current user's home directory
USER_HOME=$(eval echo ~$USER)

# Define the application name and related paths
APP_NAME="ShellMate"
BUNDLE_IDENTIFIER="com.CamelsAndNeedles.ShellMate"
APP_PATH_UTILITY="/Applications/Utilities/$APP_NAME.app"
APP_PATH_MAIN="/Applications/$APP_NAME.app"
CACHE_PATH="$USER_HOME/Library/Caches/$BUNDLE_IDENTIFIER"
PREFERENCES_PATH="$USER_HOME/Library/Preferences/$BUNDLE_IDENTIFIER.plist"
SAVED_STATE_PATH="$USER_HOME/Library/Saved Application State/$BUNDLE_IDENTIFIER.savedState"

# Define the target executable and directories
MAIN_EXECUTABLE_NAME="sm"
TARGET_DIR="$USER_HOME/shellmate"
LINK_DIR="$USER_HOME/bin"

# Function to delete a file or directory if it exists
delete_if_exists() {
    if [ -e "$1" ]; then
        echo "Deleting $1..."
        rm -rf "$1"
    else
        echo "$1 not found. Skipping..."
    fi
}

# Function to remove the symbolic link and executable
remove_executable_and_link() {
    echo "Removing symbolic link for $MAIN_EXECUTABLE_NAME in $LINK_DIR..."
    rm -f "$LINK_DIR/$MAIN_EXECUTABLE_NAME"
    if [ $? -ne 0 ]; then
        echo "Error: Failed to remove symbolic link for $MAIN_EXECUTABLE_NAME in $LINK_DIR."
        exit 1
    fi

    echo "Removing $MAIN_EXECUTABLE_NAME from $TARGET_DIR..."
    rm -f "$TARGET_DIR/$MAIN_EXECUTABLE_NAME"
    if [ $? -ne 0 ]; then
        echo "Error: Failed to remove $MAIN_EXECUTABLE_NAME from $TARGET_DIR."
        exit 1
    fi

    if [ -d "$TARGET_DIR" ]; then
        if [ -z "$(ls -A $TARGET_DIR)" ]; then
            echo "Removing empty directory $TARGET_DIR..."
            rmdir "$TARGET_DIR"
            if [ $? -ne 0 ]; then
                echo "Error: Failed to remove empty directory $TARGET_DIR."
                exit 1
            fi
        else
            TARGET_DIR_LOWER=$(echo "$TARGET_DIR" | tr '[:upper:]' '[:lower:]')
            APP_NAME_LOWER=$(echo "$APP_NAME" | tr '[:upper:]' '[:lower:]')
            if echo "$TARGET_DIR_LOWER" | grep -q "$APP_NAME_LOWER"; then
                echo "Directory $TARGET_DIR contains $APP_NAME. Do you want to proceed with rm -rf? (yes/no)"
                read -r response
                if [ "$response" = "yes" ]; then
                    echo "Removing $TARGET_DIR..."
                    rm -rf "$TARGET_DIR"
                    if [ $? -ne 0 ]; then
                        echo "Error: Failed to remove $TARGET_DIR."
                        exit 1
                    fi
                else
                    echo "Skipping removal of $TARGET_DIR."
                fi
            else
                echo "Directory $TARGET_DIR is not empty and does not contain $APP_NAME. Not removing."
            fi
        fi
    else
        echo "Directory $TARGET_DIR not found. Skipping..."
    fi

    echo "Executable and symbolic link removal complete."
}

# Function to remove LINK_DIR if it is empty and update PATH
remove_link_dir_if_empty() {
    if [ -d "$LINK_DIR" ]; then
        if [ -z "$(ls -A $LINK_DIR)" ]; then
            echo "Removing empty directory $LINK_DIR..."
            rmdir "$LINK_DIR"
            if [ $? -ne 0 ]; then
                echo "Error: Failed to remove empty directory $LINK_DIR."
                exit 1
            fi
            echo "Updating PATH to remove $LINK_DIR..."
            PATH=$(echo "$PATH" | tr ':' '\n' | grep -v "^$USER_HOME/bin$" | tr '\n' ':' | sed 's/:$//')
            export PATH
            echo "Updated PATH: $PATH"
        else
            echo "Directory $LINK_DIR is not empty, not removing."
        fi
    else
        echo "Directory $LINK_DIR not found. Skipping..."
    fi
}

# Uninstall the application from both Utilities and main Applications directories
delete_if_exists "$APP_PATH_UTILITY"
delete_if_exists "$APP_PATH_MAIN"

# Remove related cache, preferences, and saved state files
delete_if_exists "$CACHE_PATH"
delete_if_exists "$PREFERENCES_PATH"
delete_if_exists "$SAVED_STATE_PATH"

# Remove user defaults
echo "Removing user defaults for $BUNDLE_IDENTIFIER..."
defaults delete $BUNDLE_IDENTIFIER

# Remove the executable and symbolic link
remove_executable_and_link

# Remove LINK_DIR if empty and update PATH
remove_link_dir_if_empty

# Function to check user's shell profile and inform the user to remove the PATH line
check_and_inform_user_to_edit_path() {
    SHELL_PROFILES="$HOME/.zshrc $HOME/.bashrc $HOME/.profile"
    PATH_LINE='export PATH="'"$USER_HOME/bin"':$PATH"'

    echo "Checking for PATH line: $PATH_LINE"

    for profile in $SHELL_PROFILES; do
        if [ -f "$profile" ]; then
            echo "Checking $profile..."
            if grep -qF "$PATH_LINE" "$profile"; then
                echo "Found PATH line in $profile."
                echo "Please edit the above file to remove the PATH line manually."
                return
            fi
        else
            echo "$profile does not exist. Skipping..."
        fi
    done

    echo "PATH line not found in any of the shell profiles."
}

# Check for PATH line and inform user to edit manually
check_and_inform_user_to_edit_path

echo "Uninstallation of $APP_NAME completed."
