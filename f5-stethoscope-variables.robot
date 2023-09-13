*** Variables ***
# These are the credential variables with default values; you can modify them here or
# override the values by running this script using the format below:
#
${bigip_username}
${bigip_password}
${bigip_ssh_identity_file}
${bigip_ssh_port}                  22
${bigip_https_port}                443
# Device and object status will be written to this file. Information in this file should be static
# and can be diff'd prior to and after a maintenance event to view configuration or operation state
# changes:
${status_output_file_name}         device_status.txt
${status_output_full_path}         ${OUTPUT_DIR}/${status_output_file_name}
# Device statistics will be written to this file:
${statistics_output_file_name}     device_statistics.txt
${statistics_output_full_path}     ${OUTPUT_DIR}/${statistics_output_file_name}     
# Creating an empty dictionary that we will populate with data as the tests run
&{api_responses}  