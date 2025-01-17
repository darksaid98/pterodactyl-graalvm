#!/bin/bash

#
# Copyright (c) 2021 Matthew Penner
#
# Permission is hereby granted, free of charge, to any person obtaining a copy
# of this software and associated documentation files (the "Software"), to deal
# in the Software without restriction, including without limitation the rights
# to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
# copies of the Software, and to permit persons to whom the Software is
# furnished to do so, subject to the following conditions:
#
# The above copyright notice and this permission notice shall be included in all
# copies or substantial portions of the Software.
#
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
# IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
# FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
# AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
# LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
# OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
# SOFTWARE.
#

# Default the TZ environment variable to UTC.
TZ=${TZ:-UTC}
export TZ

# Set environment variable that holds the Internal Docker IP
INTERNAL_IP=$(ip route get 1 | awk '{print $(NF-2);exit}')
export INTERNAL_IP

# Switch to the container's working directory
cd /home/container || exit 1

# Update repo from git
if [ "${GIT_ENABLED}" == "false" ] || [ "${GIT_ENABLED}" == "0" ]; then
    echo -e "Git enabled."
    
    ## add git ending if it's not on the address
    if [[ ${GIT_ADDRESS} != *.git ]]; then
        GIT_ADDRESS=${GIT_ADDRESS}.git
    fi

    if [ -z "${GIT_USERNAME}" ] && [ -z "${GIT_ACCESS_TOKEN}" ]; then
        echo -e "Git Username or Git Token was not specified. Proceeding anonymously."
    else
        GIT_ADDRESS="https://${GIT_USERNAME}:${GIT_ACCESS_TOKEN}@$(echo -e ${GIT_ADDRESS} | cut -d/ -f3-)"
    fi

    
    if [ "$(ls -A /home/container)" ]; then
        echo -e "/home/container directory is not empty."

        # Get git origin from /home/container/.git/config
        if [ -d .git ]; then
            echo -e ".git directory exists"
            if [ -f .git/config ]; then
                echo -e "loading info from git config"
                ORIGIN=$(git config --get remote.origin.url)
            else
                echo -e "files found with no git config"
                echo -e "closing out without touching things to not break anything"
                exit 10
            fi
        fi

        # If git origin matches the repo specified by user then pull
        if [ "${ORIGIN}" == "${GIT_ADDRESS}" ]; then
            echo "pulling latest from github"
            git pull && echo "Finished pulling /home/container from Git." || echo "Failed pulling /home/container from Git."
        fi
    else
        # No files exist in resources folder, clone
        echo -e "/home/container is empty.\ncloning files into repo"
        if [ -z ${GIT_BRANCH} ]; then
            echo -e "Cloning default branch into /home/container."
            git clone ${GIT_ADDRESS} .
        else
            echo -e "Cloning ${GIT_BRANCH} branch into /home/container."
            git clone --single-branch --branch ${GIT_BRANCH} ${GIT_ADDRESS} . && echo "Finished cloning into /home/container from Git." || echo "Failed cloning into /home/container from Git."
        fi
    fi
else
    echo -e "Git disabled."
fi

# Print Java version
printf "\033[1m\033[33mcontainer@pterodactyl~ \033[0mjava -version\n"
java -version

# Convert all of the "{{VARIABLE}}" parts of the command into the expected shell
# variable format of "${VARIABLE}" before evaluating the string and automatically
# replacing the values.
PARSED=$(echo "${STARTUP}" | sed -e 's/{{/${/g' -e 's/}}/}/g' | eval echo "$(cat -)")

# Display the command we're running in the output, and then execute it with the env
# from the container itself.
printf "\033[1m\033[33mcontainer@pterodactyl~ \033[0m%s\n" "$PARSED"
# shellcheck disable=SC2086
eval ${PARSED}
