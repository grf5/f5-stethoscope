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

# Delete existing reports from destination; used for development purposes
rm -fR /Users/G.Robinson/Downloads/Robot_Reports/*
# Disable self-signed certificate warning for BIG-IP
export PYTHONWARNINGS='ignore:Unverified HTTPS request'

#Execute the robot executable
# Set your hostname, username, password or ssh key here
robot \
  --variable "bigip_host:13e25db5-d113-447c-bf38-cd5114ed5417.access.udf.f5.com"      \
  --variable "bigip_ssh_identity_file:/Users/G.Robinson/.ssh/id_ed25519"              \
  --variable "bigip_ssh_port:47000"                                                   \
  --variable "status_output_file_name:device_status.txt"                              \
  --variable "statistics_output_file_name:device_statistics.txt"                      \
  --logtitle "F5 Stethoscope"                                                         \
  --reporttitle "F5 Stethoscope"                                                      \
  --output-dir /Users/G.Robinson/Downloads/Robot_Reports                              \
  --output output.xml                                                                 \
  --log log.html                                                                      \
  --report report.html                                                                \
  --maxerrorlines NONE                                                                \
  --maxassignlength 1000                                                              \
  --timestampoutputs                                                                  \
  --consolewidth 120                                                                  \
  --pythonpath $(which python3)                                                       \
  f5-stethoscope.robot

open /Users/G.Robinson/Downloads/Robot_Reports