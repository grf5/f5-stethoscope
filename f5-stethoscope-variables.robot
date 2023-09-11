*** Variables ***
# These are the credential variables with default values; you can modify them here or
# override the values by running this script using the format below:
#
# robot f5-stethoscope.robot --bigip_host 192.168.1.1 --bigip_username admin --bigip_password g00dgrAvy_1984$
#
${bigip_host}                  192.168.1.245
${bigip_username}              admin
${bigip_password}              f5c0nfig123!
# Each test will write out data in human readable, plain text output to the file specified here.
${text_output_file_name}       device_info.txt
# 
${configuration_file_name}     device_configuration.txt
# Creating an empty dictionary that we will populate with data as the tests run
&{api_info_block}  