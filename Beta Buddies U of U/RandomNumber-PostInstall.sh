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
randomNumber=$(jot -r 1 1 1000) # Sets the random number

${defaults} write ${file} ${quarter} -string ${randomNumber}