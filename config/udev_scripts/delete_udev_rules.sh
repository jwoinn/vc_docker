#!/bin/bash

echo "Deleting voisis udev rules"
sudo rm -f /etc/udev/rules.d/99-voisis.rules
sudo udevadm control --reload-rules && sudo udevadm trigger
echo "Done!"