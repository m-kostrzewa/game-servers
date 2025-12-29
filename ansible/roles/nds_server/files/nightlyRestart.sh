echo "$(date) nightly restart" >> /srv/steam/log.txt

rm /srv/steam/ServerCommand.xml.tmp || true
rm /srv/steam/ServerCommand.xml || true

playersNow=$(cat /srv/steam/nds.log | grep "players now: " | tail -1 | awk '{print $NF}')
if [ -z "$playersNow" ] || [ "$playersNow" -eq "0" ]; then
    echo "$(date) no players on server, restarting now" >> /srv/steam/log.txt
    sudo /usr/bin/systemctl restart nds.service
else
    echo "$(date) server not empty, has $playersNow players, scheduling restart" >> /srv/steam/log.txt
    cat << EOF > /srv/steam/ServerCommand.xml.tmp
<ServerCommandFile>
    <Command>ScheduleRestart</Command>
    <Message>Nightly restart - the server will restart after this match</Message>
</ServerCommandFile>
EOF
    mv /srv/steam/ServerCommand.xml.tmp /srv/steam/ServerCommand.xml
fi
