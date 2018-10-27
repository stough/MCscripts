#!/usr/bin/env bash

date=`date +%d`
month=`date +%b`
year=`date +%Y`

server_do()
{
	tmux -S "$tmux_socket" send-keys -t "$sessionname":0.0 "$*" Enter
	# Enter $* in the first pane of the first window of session $sessionname on socket $tmux_socket
}

countdown()
{
	warning="Autosave pausing for backups in $*"
	server_do say $warning
	echo $warning
}

if [ -z "$1" -o -z "$2" -o "$1" = -h -o "$1" = --help ]; then
	>&2 echo Backs up Minecraft server world running in tmux session.
	>&2 echo '`./MCbackup.sh $server_dir $sessionname [$backup_dir] [$tmux_socket]`'
	>&2 echo 'Backups are ${world}_Backups/$year/$month/$date.zip in ~ or $backup_dir if applicable. $backup_dir is best on another drive.'
	exit 1
fi

server_dir=${1%/}
# Remove trailing slash
properties=$server_dir/server.properties
if [ ! -r "$properties" ]; then
	if [ -f "$properties" ]; then
		>&2 echo $properties is not readable
		exit 2
	fi
	>&2 echo No file $properties
	exit 3
fi
world=`grep level-name "$properties" | cut -d = -f 2`
# $properties says level-name=$world

sessionname=$2

if [ -n "$3" ]; then
	backup_dir=${3%/}
else
	backup_dir=~
fi
backup_dir=$backup_dir/${world}_Backups/$year/$month
mkdir -p "$backup_dir"
# Make directory and parents quietly
backup_dir=`realpath "$backup_dir"`

if [ -n "$4" ]; then
	tmux_socket=${4%/}
else
	tmux_socket=/tmp/tmux-`id -u $USER`/default
fi
if ! tmux -S "$tmux_socket" ls | grep -q "$sessionname"; then
	>&2 echo No session $sessionname on socket $tmux_socket
	exit 4
fi

countdown 20 seconds
sleep 17
countdown 3 seconds
sleep 1
countdown 2 seconds
sleep 1
countdown 1 second
sleep 1
server_do say Darnit

server_do save-off
# Disable autosave
server_do save-all flush
# Pause and save the server
while [ -z "$success" ]; do
	buffer=`tmux -S "$tmux_socket" capture-pane -pt "$sessionname":0.0 -S -`
	# Get buffer from the first pane of the first window of session $sessionname on socket $tmux_socket
	buffer=`echo "$buffer" | awk 'file{file=file"\n"$0} /save-all/{file=$0} END {print file}'`
	# Trim off $buffer before last occurence of save-all
	# If file exists append $0, if $0 contains save-all set file to $0, and at end print file
	if echo "$buffer" | grep -q 'Saved the game'; then
	# Minecraft says [HH:MM:SS] [Server thread/INFO]: Saved the game
		success=true
	else
		sleep 1
	fi
done
cd "$server_dir"
# zip restores path of directory given to it ($world), not just the directory itself
zip -r "$backup_dir/$date.zip" "$world"
server_do save-on
server_do say "Well that's better now, isn't it?"