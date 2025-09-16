#!/bin/zsh

# Check the current seed, based on what's recorded at com.thumbtack.betaprogram

currentState=$(/usr/bin/defaults read /Library/Preferences/com.thumbtack.betaprogram Program)

if [[ $currentState = "CustomerSeed" ]]; then

	echo "<result>CustomerSeed</result>"
	exit 0
	
else
	
	echo "<result>Production</result>"
	exit 0
	
fi