#!/bin/zsh

# Check the current seed, and only display the line containing "Currently"

currentState=$(/usr/bin/defaults read /Library/Preferences/com.thumbtack.betaprogram Program)

if [[ $currentState = "CustomerSeed" ]]; then

	echo "<result>CustomerSeed</result>"
	exit 0
	
else
	
	echo "<result>Production</result>"
	exit 0
	
fi