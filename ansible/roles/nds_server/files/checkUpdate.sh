echo "$(date) checking for update" >> /srv/steam/log.txt

remoteVer=$(/usr/games/steamcmd +login anonymous app_info_update 1 +app_info_print 2353090 +quit | grep buildid | awk  'NR==1{print $2}' | tr -d '"')
localVer=$(/usr/games/steamcmd +login anonymous +app_status 2353090 +quit | grep BuildID | awk '{print $NF}')

echo "$(date) remoteVer=$remoteVer localVer=$localVer" >> /srv/steam/log.txt

rm /srv/steam/ServerCommand.xml.tmp || true
rm /srv/steam/ServerCommand.xml || true

if [ -z "$remoteVer" ]; then
    echo "$(date) remoteVer is none" >> /srv/steam/log.txt
    exit 0
fi

if [ -z "$localVer" ]; then
    echo "$(date) localVer is none" >> /srv/steam/log.txt
    exit 0
fi

if [ "$remoteVer" != "$localVer" ]; then
    echo "$(date) new update available" >> /srv/steam/log.txt

    playersNow=$(cat /srv/steam/nds.log | grep "players now: " | tail -1 | awk '{print $NF}')
    if [ -z "$playersNow" ] || [ "$playersNow" -eq "0" ]; then
        echo "$(date) no players on server, restarting now" >> /srv/steam/log.txt
        sudo /usr/bin/systemctl restart nds.service
    else
        echo "$(date) server not empty, has $playersNow players, scheduling restart" >> /srv/steam/log.txt
        cat << EOF > /srv/steam/ServerCommand.xml.tmp
<ServerCommandFile>
    <Command>ScheduleRestart</Command>
    <Message>New update available! The server will restart after this match</Message>
</ServerCommandFile>
EOF
        mv /srv/steam/ServerCommand.xml.tmp /srv/steam/ServerCommand.xml
    fi
fi
