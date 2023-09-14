# f5-stethoscope

## Overview

F5 Stethoscope is a Robot Framework test suite that pulls data from a F5 BIG-IP&trade;, including configuration, object status and statistics, and looks for potential issues.

Stethoscope also writes object status to a flat file, which can be used to diff before/after maintenance windows. This will quickly highlight objects that have changed status.

## Requirements

The requirements to run Stethoscope are:

- HTTPS connectivity to the BIG-IP
- SSH connectivity to the BIG-IP (supports password and identity authentication)
- the user account used to access the BIG-IP must have administrator access

## Usage

Credentials can be provided in two ways:
- via command-line arguments, as shown in the example bash script below (still writing credentials to a plain-text file and they'll be stored plain text in your bash history, so best to avoid)
- typed manually when prompted after executing the test suite (most secure)

Basic usage:

```bash
robot f5-stethoscope.robot
```

An example bash script for executing the test:

```bash
#!/usr/bin/env bash
export ROBOT_TIMESTAMP=$(date +%Y-%m-%d-%H%M%S-%Z)

robot \
  --variable "bigip_host:mybigip.mydomain.com" \
  --variable "bigip_username:admin" \
  --variable "bigip_password:These_pretzels_are_making_me_thirsty!" \
  --variable "bigip_ssh_identity_file:/Users/grf5/.ssh/id_rsa" \
  --variable "bigip_ssh_port:22" \
  --variable "bigip_https_port:443" \
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
  ```

## Output

You should have five files created after the test suite is complete:

- output.xml - contains outputs of the test suite in a single XML file
- device-status.txt - contains object status output
- device-statistics.txt - contains object statistics output
- report.html - the main test suite report
- log.html - detailed logs in HTML format linked from the report
