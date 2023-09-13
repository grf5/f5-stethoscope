#!/usr/bin/env bash

# Detect Python 3 
which python3 || {
  echo Python3 not found.
  exit 2
}

# Detect Robot executable
which robot || {
  echo Robot Framework not found. 
  exit 3
}

# Disable self-signed certificate warning for BIG-IP
export PYTHONWARNINGS='ignore:Unverified HTTPS request'

export ROBOT_TIMESTAMP=$(date +%Y-%m-%d-%H%M%S-%Z)
# Execute the robot executable
# You can specify the hostname, username, password or ssh key here, or optionally be prompted
# for them if they are omitted
robot \
  --variable "bigip_host:13e25db5-d113-447c-bf38-cd5114ed5417.access.udf.f5.com" \
  --variable "bigip_username:admin" \
  --variable "bigip_password:f5c0nfig123!" \
  --variable "bigip_ssh_identity_file:/Users/G.Robinson/.ssh/id_ed25519" \
  --variable "bigip_ssh_port:47000" \
  --variable "status_output_file_name:device_status-$ROBOT_TIMESTAMP.txt" \
  --variable "statistics_output_file_name:device_statistics-$ROBOT_TIMESTAMP.txt" \
  --logtitle "F5 Stethoscope" \
  --reporttitle "F5 Stethoscope" \
  --outputdir /Users/G.Robinson/Downloads/Robot_Reports \
  --output output-$ROBOT_TIMESTAMP.xml \
  --log log-$ROBOT_TIMESTAMP.html \
  --report report-$ROBOT_TIMESTAMP.html \
  --maxerrorlines NONE \
  --maxassignlength 1000 \
  --consolewidth 120 \
  --pythonpath $(which python3) \
  --exitonerror \
  f5-stethoscope.robot