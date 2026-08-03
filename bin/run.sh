#!/usr/bin/env sh

HOME=/home/weewx
WEEWX_ROOT=$HOME/weewx-data
CONF_FILE=$WEEWX_ROOT/weewx.conf

echo "HOME=$HOME"
echo "using $CONF_FILE"
echo "weewx is in $WEEWX_ROOT"
echo "TZ=$TZ"
cd $WEEWX_ROOT || exit

while true; do
  . /home/weewx/weewx-venv/bin/activate
  /home/weewx/weewx-venv/bin/weewxd $CONF_FILE > /dev/stdout
  echo "weewx exited with code $?. Restarting in 60 seconds..."
  sleep 60
done
