#!/bin/zsh

## =============================================================
## Created 2023 03 21
## By Adam Anklewicz for Thumbtack Inc. endpoint team
## aanklewicz@thumbtack.com
## Updated 2023 05 09 - Auto enter the quarter
## =============================================================

################################################################################################
# Here are our variables.
################################################################################################

defaults="/usr/bin/defaults"
file="/Library/Preferences/com.thumbtack.randomnumber.plist" # Where we're storing the plist file
year=$(date +%Y)
month=$(date +%m)
quarter=$(( ($month - 1) / 3 + 1 ))
quarter="${year}_Q${quarter}"
randomNumber=$(jot -r 1 1 1000) # Sets the random number

################################################################################################
# Now let's check to see if the key pair $quarter currently exists in $file. 
# If the exitCode is 0, it exists, if it's 1, it doesn't exist
################################################################################################

if "$defaults" read "$file" "$quarter" 2>&1 | grep -q "does not exist"; then
   exitCode=1
fi

################################################################################################
# If the key pair doesn't exist, create it, and add a random number.
################################################################################################

if [[ $exitCode = 1 ]]; then
   ${defaults} write ${file} ${quarter} -string ${randomNumber}
fi

################################################################################################
# Store the results in $result and echo it in a method that Jamf can read as an EA
################################################################################################

result=$(${defaults} read ${file} ${quarter})

echo "<result>$result</result>"

exit 0