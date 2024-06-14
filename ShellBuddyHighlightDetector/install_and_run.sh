#!/bin/sh

#  install.sh
#  ShellBuddy
#
#  Created by Daniel Delattre on 14/06/24.
#  

# Determine the directory where the script is located
SCRIPT_DIR=$(dirname "$0")
cd "$SCRIPT_DIR"

# Check if the virtual environment folder exists
if [ ! -d "./venv" ]; then
    echo "Virtual environment not found. Creating one..."
    python3 -m venv venv
else
    echo "Virtual environment already exists."
fi

# Activate the virtual environment
source ./venv/bin/activate

# Install the required packages
pip install -r requirements.txt

# Run the main.py script
python3 main.py
