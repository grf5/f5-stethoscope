*** Variables ***
# These are the credential variables with default values; you can modify them here or
# override the values by running this script using the format below:
#
# robot f5-stethoscope.robot --bigip_host 192.168.1.1 --bigip_username admin --bigip_password g00dgrAvy_1984$
#
${bigip_host}                      192.168.1.245
${bigip_username}                  admin
${bigip_password}                  f5c0nfig123!
${bigip_ssh_identity_file}         ${EMPTY}
${bigip_ssh_port}                  22
${bigip_https_port}                443
# Device and object status will be written to this file. Information in this file should be static
# and can be diff'd prior to and after a maintenance event to view configuration or operation state
# changes:
${status_output_file_name}         device_status.txt
# Device statistics will be written to this file:
${statistics_output_file_name}     device_statistics.txt
# Creating an empty dictionary that we will populate with data as the tests run
&{api_info_block}  