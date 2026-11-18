#!/bin/bash
RULES=~/voisis_docker/vc_docker/config/udev_scripts/99-voisis.rules

echo "Installing udev rules from $RULES"
sudo cp "$RULES" /etc/udev/rules.d/
sudo udevadm control --reload-rules && sudo udevadm trigger

echo "Done!"