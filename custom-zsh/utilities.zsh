######################################################################################
# General Utilities & Helpers
# General-purpose utilities and helper functions
######################################################################################

######################################################################################
# Aliases
######################################################################################

## Augment wrapper
alias aug="auggie $@"

######################################################################################
# Functions
######################################################################################

function listAlfredWorkflows() {
  for plist in ~/Library/Application\ Support/Alfred/Alfred.alfredpreferences/workflows/*/info.plist; do
    name=$(defaults read "$plist" name 2>/dev/null)
    bundleid=$(defaults read "$plist" bundleid 2>/dev/null)
    echo "$name — $bundleid"
  done
}

function listAlfredWorkflowIds() {
  cd ~/Library/Application\ Support/Alfred/Alfred.alfredpreferences/workflows
  find user.workflow.* -type f -name info.plist | while read -r plist; do
    name=$(/usr/libexec/PlistBuddy -c "Print name" "$plist" 2>/dev/null)
    if [[ -n "$name" ]]; then
      uuid_folder=$(echo "$plist" | cut -d'/' -f1)
      echo "$uuid_folder → $name"
    fi
    cd -
  done
}

function auggie() {
  # Check if augment is installed
  if ! command -v augment &> /dev/null; then
    echo "Augment not found. Installing..."
   npm install -g @augmentcode/auggie

    # Confirm installation and show version
    if command -v augment &> /dev/null; then
      echo "Augment installed successfully!"
      augment -v
    else
      echo "Failed to install augment"
      return 1
    fi
  fi

  # Run augment with provided arguments, or show help if no arguments
  if [ $# -eq 0 ]; then
    augment -h
  else
    augment "$@"
  fi
}

function dadjoke() {
  curl -s -H "Accept: text/plain" https://icanhazdadjoke.com/
}

function getabspath() {
  absolute_path=$(realpath $1)
  echo "Absolute path: ${absolute_path}"
}

function timestamp_now() {
  date -u +%Y-%m-%dT%H:%M:%SZ
}
