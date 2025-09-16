#!/bin/zsh --no-rcs

################################################################################################
# Here are our variables.
################################################################################################

defaults="/usr/bin/defaults"
file="/Library/Preferences/com.thumbtack.randomnumber.plist" # Where we're storing the plist file
year=$(date +%Y)
month=$(date +%m)
quarter=$(( ($month - 1) / 3 + 1 ))
quarter="${year}_Q${quarter}"

################################################################################################
# Now let's check to see if the key pair $quarter currently exists in $file. 
# If the exitCode is 0, it exists, if it's 1, it doesn't exist
################################################################################################

if "$defaults" read "$file" "$quarter" 2>&1 | grep -q "does not exist"; then
   echo "The key pair does not exist."
   exit 0
else
   echo "The key pair exists."
   exit 1
fi