#!/bin/bash
#
# This scripts updates the full text index for reposearch,
# the full text search plugin for redmine.
#
# Author: Jostein Elvaker Haande <tolecnal@tolecnal.net>
#
# INSTALLATION
#  - copy the script to your desired location
#  - edit the settings below
#  - enable 'reposearcher' for your desired project(s)
#  - set up a crontab to run the script
#    i.e: */10 * * * * /path/to/update-reposearch.sh
#    This will run the update process every ten minutes
#
# reposearch-update.sh - BASH script to update your repos for reposearch
# Copyright (C) 2012 - Jostein Elvaker Haande <tolecnal@tolecnal.net>
# 
# This program is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program.  If not, see <http://www.gnu.org/licenses/>. 

NAME="RepoSearchUpdate"

# Here we specify the path to the curl binary, the URL to your redmine
# instllation as well as your API key.
CURLPATH="/usr/bin/curl"
REDMINEURL="http://redmine.yourdomain.tld/repoindexer/crawl/"
APIKEY="xxxxxxxxxxxxxx"

# List of the repositories we want to keep up to date with the
# reposearch full text indexer. Separated by spaces!
# You find the name by looking under your projects settings, and
# the setting 'identifier'.
# Make sure that you've enabled 'reposearcher' under the project
# settings, or else repoindexer will fail.
REPOS="repo1 repo2 repo3"

# Do we want to log to syslog
SYSLOG=1

# Do *NOT* touch these. For internal book keeping during script execution
ERROR=0
ERRORSTR=""

for repo in $REPOS
do
  COMMAND=$($CURLPATH -s $REDMINEURL$repo?key=$APIKEY)
  if (( $? )) || [ "$COMMAND" != "Successfully indexed!" ] ; then
    if [ "$SYSLOG" -eq "1" ] ; then
      logger -t $NAME "Error updating repository $repo"
    fi
    ERROR=1
    ERRORSTR="$ERRORSTRError updating repository $repo\n"
  fi
done

if [ "$ERROR" -eq "1" ] ; then
  echo -e "### Reposearch repository updater ###"
  echo -e ""
  echo -e "An error was encountered on $(date)"
  echo -e ""
  echo -e "ERROR:"
  echo -e "$ERRORSTR"
  exit 1
else
  exit 0
fi
