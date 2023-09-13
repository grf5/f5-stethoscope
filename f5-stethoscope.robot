*** Settings ***
Documentation      F5 stethoscope is a Robot Framework script that checks the generic health
...                of BIG-IP devices.
...
...                By default, stethoscope uses the iControl REST API to retrieve information.
...                If the API is not available, it will fallback to SSH.

# Load third-party libraries that extend the functionality of Robot Framework, enabling us to use
# keywords that manipulate strings, connect to SSH hosts, make API Requests, manipulate collections
# (aka dictionaries), interact with the local filesystem to output custom formatted data, and
# access the system clock to enabling custom timestamps
Library            String
Library            SSHLibrary    timeout=20 seconds    loglevel=trace
Library            RequestsLibrary
Library            Collections
Library            OperatingSystem
Library            DateTime
Library            Dialogs

# This commands ensures that the proper log level is used for each test without having to specify
# it repeatedly in each test. This Suite Setup keyword can be extended to issue multiple keywords
# prior to starting a test suite.
Suite Setup        Set Log Level    trace

# This set of commands runs at the end of each test suite, ensuring that SSH connections are
# closed and any API sessions are closed.
Suite Teardown     Run Keywords    SSHLibrary.Close All Connections    RequestsLibrary.Delete All Sessions

*** Keywords ***
BIG-IP iControl BasicAuth GET
    [Documentation]    Performs an iControl REST API GET call using basic auth (See pages 25-38 of https://cdn.f5.com/websites/devcentral.f5.com/downloads/icontrol-rest-api-user-guide-13-1-0-a.pdf.zip)
    [Arguments]    ${bigip_host}    ${bigip_username}    ${bigip_password}    ${api_uri}
    [Teardown]    RequestsLibrary.Delete All Sessions
    ${api_auth}    Create List    ${bigip_username}   ${bigip_password}
    RequestsLibrary.Create Session    bigip-icontrol-get-basicauth    https://${bigip_host}:${bigip_https_port}    auth=${api_auth}
    &{api_headers}    Create Dictionary    Content-type=application/json
    ${api_response}    GET On Session    bigip-icontrol-get-basicauth   ${api_uri}    headers=${api_headers}
    Should be equal as integers    ${api_response.status_code}    200
    [Return]    ${api_response}

*** Variables ***
# These variables will be populated as credentials are supplied via command-line options
# or via text input during case execution
${bigip_host}
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
&{disk_volume_utilization}

*** Test Cases ***
Check Inputs and Prompt if Necessary
    # Check to ensure that each of the following variables are not empty, and prompt for them if so.
    IF    "${bigip_host}" == "${EMPTY}"
        ${bigip_host}    Get Value from User    message=BIG-IP Hostname or IP:    default_value=192.168.1.245
    END
    IF    "${bigip_username}" == "${EMPTY}"
        ${bigip_username}    Get Value from User    message=BIG-IP Username:    default_value=admin
    END
    IF    "${bigip_password}" == "${EMPTY}"
        ${bigip_password}    Get Value from User    message=BIG-IP Password:    hidden=True
    END
    IF    "${bigip_ssh_port}" == "${EMPTY}"
        ${bigip_ssh_port}    Get Value from User    message=BIG-IP SSH Port:    default_value=22
    END
    IF    "${bigip_https_port}" == "${EMPTY}"
        ${bigip_https_port}    Get Value from User    message=BIG-IP HTTPS Port:    default_value=443
    END
    IF    "${status_output_file_name}" == "${EMPTY}"
        ${status_output_file_name}    Get Value from User    message=Status File Name:    default_value=device_status.txt
    END
    IF    "${statistics_output_file_name}" == "${EMPTY}"
        ${statistics_output_file_name}    Get Value from User    message=Statistics File Name:    default_value=device_statistics.txt
    END

Create Output File Headers for Status and Statistics
    [Documentation]    This script simply outputs a timestamp to the console, log file,
    ...    plain text output file and API output dictionary
    ...    DO NOT DISABLE OR DELETE THIS TEST; IT WILL BREAK ALL OTHER TESTS!
    ${timestamp}   Get Current Date
    # Log the host and timestamp to the default robot log
    Log    BIG-IP: ${bigip_host} (${timestamp})
    # Log the host and timestamp to the console
    Log to console    \nBIG-IP: ${bigip_host} (${timestamp})
    # Log the timestamp and host to the dictionary containing all results
    Set to Dictionary    ${api_responses}    test-start-time=${timestamp}
    Set to Dictionary    ${api_responses}    bigip_host=${bigip_host}
    # Create the output files
    Create File    ${status_output_full_path}   BIG-IP: ${bigip_host} (${timestamp})\n
    Create File    ${statistics_output_full_path}   BIG-IP: ${bigip_host} (${timestamp})\n

Verify SSH Connectivity
    [Documentation]    Logs into the BIG-IP via TMSH, executes a BASH command and validates the expected response
    [Tags]    critical
    # Check for identity file and use it instead of password auth if present
    IF    "${bigip_ssh_identity_file}" != "${EMPTY}"
        TRY
            # Use the SSH Library to connect to the host
            SSHLibrary.Open Connection    ${bigip_host}    port=${bigip_ssh_port}
            # Log in and note the returned prompt
            ${login_output}    SSHLibrary.Login with public key    username=${bigip_username}    keyfile=${bigip_ssh_identity_file}    delay=7 seconds
            # Verify that the prompt includes (tmos)# for tmsh or the default bash prompt
            Should Contain Any    ${login_output}   (tmos)#    ] ~ #
        EXCEPT
            TRY
                # Use the SSH Library to connect to the host
                SSHLibrary.Open Connection    ${bigip_host}    port=${bigip_ssh_port}
                # Log in and note the returned prompt
                ${login_output}   SSHLibrary.Log In    ${bigip_username}   ${bigip_password}    delay=7 seconds
                # Verify that the prompt includes (tmos)# for tmsh or the default bash prompt
                Should Contain Any    ${login_output}   (tmos)#    ] ~ #
            EXCEPT
                Log    Could not connect to SSH
                Set to Dictionary    ${api_responses}    ssh-connectivity=${False}
                Append to file    ${status_output_full_path}    SSH Connecitivity: FAILED\n
                # Since all other tests will fail, stop further testing
                Fatal Error
            ELSE
                Log    Successfully connected to SSH
                Set to Dictionary    ${api_responses}    ssh-connectivity=${False}
                Append to file    ${status_output_full_path}    SSH Connecitivity: Succeeded\nLogin Output:\n${login_output}\n
            END
        ELSE
            Log    Successfully connected to SSH
            Set to Dictionary    ${api_responses}    ssh-connectivity=${True}
            Append to file    ${status_output_full_path}    SSH Connecitivity: Succeeded\nLogin Output:\n${login_output}\n
        END
    # If the SSH identity is not specified, skip to password authentication
    ELSE
        TRY
            # Use the SSH Library to connect to the host
            SSHLibrary.Open Connection    ${bigip_host}    port=${bigip_ssh_port}
            # Log in and note the returned prompt
            ${login_output}   SSHLibrary.Log In    ${bigip_username}   ${bigip_password}    delay=7 seconds
            # Verify that the prompt includes (tmos)# for tmsh or the default bash prompt
            Should Contain Any    ${login_output}   (tmos)#    ] ~ #
        EXCEPT
            Log    Could not connect to SSH
            Set to Dictionary    ${api_responses}    ssh-connectivity=${False}
            Append to file    ${status_output_full_path}    SSH Connectivity: FAILED\n
            # Since all other tests will fail, stop further testing
            Fatal Error
        ELSE
            Log    Successfully connected to SSH
            Set to Dictionary    ${api_responses}    ssh-connectivity=${True}
            Append to file    ${status_output_full_path}    SSH Connectivity: Succeeded\nLogin Output:\n${login_output}\n
        END
    END

Verify Remote Host is a BIG-IP via TMSH
    [Documentation]    This test will run a command via TMSH to verify that the remote host is
    ...                a BIG-IP device.
    [Teardown]    Run Keyword If Test Failed    Fatal Error    FATAL_ERROR: Aborting as endpoint is not a BIG-IP device!
    [Tags]    critical
    SSHLibrary.Open Connection    ${bigip_host}    port=${bigip_ssh_port}
    IF    "${bigip_ssh_identity_file}" != "${EMPTY}"
        SSHLibrary.Login with public key    username=${bigip_username}    keyfile=${bigip_ssh_identity_file}
    ELSE
        SSHLibrary.Login    username=${bigip_username}    password=${bigip_password}
    END
    ${retrieved_show_sys_hardware_cli}   SSHLibrary.Execute Command    bash -c 'tmsh show sys hardware'
    Append to file    ${status_output_full_path}    ======> System Hardware:${retrieved_show_sys_hardware_cli}\n
    Set to Dictionary    ${api_responses}    bigip-host-verification=${True}
    # Parse for anomalies
    Should Contain    ${retrieved_show_sys_hardware_cli}   BIG-IP

Test IPv4 iControlREST API Connectivity
    [Documentation]    Tests BIG-IP iControl REST API connectivity using basic authentication
    [Tags]    critical
    TRY
        ${api_response}    BIG-IP iControl BasicAuth GET
        ...    bigip_host=${bigip_host}
        ...    bigip_username=${bigip_username}
        ...    bigip_password=${bigip_password}
        ...    api_uri=/mgmt/tm
    EXCEPT
        Append to file    ${status_output_full_path}    ======> Fatal error: API connectivity failed\n
        Set to Dictionary    ${api_responses}    api-connectivity=${False}
        Log    Fatal error: API connectivity failed
        Log to console    \nFatal error: API connectivity failed
        Fatal Error    No connectivity to device via iControl REST API: Host: ${bigip_host} with user '${bigip_username}'
    ELSE
        Log    Successfully connected to iControl REST API
        Set to Dictionary    ${api_responses}    api-connectivity=${True}
        Append to file    ${status_output_full_path}    ======> API Connecitivity: Succeeded\n
    END

Check BIG-IP for Excessive CPU/Memory Utilization
    [Documentation]    Verifies that resource utilization on the BIG-IP isn't critical and stops all testing if robot tests could cause impact
    [Tags]    critical
    # Retrieval via SSH to store in status file
    SSHLibrary.Open Connection    ${bigip_host}    port=${bigip_ssh_port}
    IF    "${bigip_ssh_identity_file}" != "${EMPTY}"
        SSHLibrary.Login with public key    username=${bigip_username}    keyfile=${bigip_ssh_identity_file}
    ELSE
        SSHLibrary.Login    username=${bigip_username}    password=${bigip_password}
    END
    ${system_performance_cli}    SSHLibrary.Execute Command    bash -c 'tmsh show sys performance all-stats detail raw'
    Append to file    ${statistics_output_full_path}    ======> System Performance All Statistics:${system_performance_cli}\n
    # Retrieval via API to store in the API response dictionary
    ${system_performance_api}    BIG-IP iControl BasicAuth GET
    ...    bigip_host=${bigip_host}
    ...    bigip_username=${bigip_username}
    ...    bigip_password=${bigip_password}
    ...    api_uri=/mgmt/tm/sys/performance/all-stats
    Dictionary should contain item    ${system_performance_api.json()}    kind    tm:sys:performance:all-stats:all-statsstats
    Set to Dictionary    ${api_responses}    system-performance-all-stats=${system_performance_api.json()}
    # Parse for anomalies
    ${system_performance_stats}    Get from dictionary    ${system_performance_api.json()}    entries
    ${utilization_avg}    Set variable    ${system_performance_stats}[https://localhost/mgmt/tm/sys/performance/all-stats/Utilization][nestedStats][entries][Average][description]
    ${other_mem_used_avg}    Set variable    ${system_performance_stats}[https://localhost/mgmt/tm/sys/performance/all-stats/Other%20Memory%20Used][nestedStats][entries][Average][description]
    ${tmm_mem_used_avg}    Set variable    ${system_performance_stats}[https://localhost/mgmt/tm/sys/performance/all-stats/TMM%20Memory%20Used][nestedStats][entries][Average][description]
    ${swap_used_avg}    Set variable    ${system_performance_stats}[https://localhost/mgmt/tm/sys/performance/all-stats/Swap%20Used][nestedStats][entries][Average][description]
    IF    ${utilization_avg} >= 90
        Fatal error    FATAL ERROR: Excessive system utilization: ${utilization_avg}%
    END
    IF    ${tmm_mem_used_avg} >= 90
        Fatal error    FATAL ERROR: Excessive TMM memory utilization: ${utilization_avg}%
    END
    IF    ${other_mem_used_avg} >= 90
        Fatal error    FATAL ERROR: Excessive memory utilization: ${utilization_avg}%
    END
    IF    ${swap_used_avg} > 0
        Log to console    \nWARNING: Swap space in use on device! This is a red flag! (https://my.f5.com/manage/s/article/K55227819)
        Log    WARNING: Swap space in use on device! This is a red flag! (https://my.f5.com/manage/s/article/K55227819)
        Append to file    ${status_output_full_path}    ======> WARNING: Swap space in use on device!\n
    END

Retrieve BIG-IP Hostname
    [Documentation]    Retrieves the configured hostname on the BIG-IP
    # Retrieval via SSH to store in status file
    SSHLibrary.Open Connection    ${bigip_host}    port=${bigip_ssh_port}
    IF    "${bigip_ssh_identity_file}" != "${EMPTY}"
        SSHLibrary.Login with public key    username=${bigip_username}    keyfile=${bigip_ssh_identity_file}
    ELSE
        SSHLibrary.Login    username=${bigip_username}    password=${bigip_password}
    END
    ${retrieved_hostname_cli}    SSHLibrary.Execute Command    bash -c 'tmsh show sys version'
    Append to file    ${status_output_full_path}    ======> Hostname:\n${retrieved_hostname_cli}\n
    # Retrieval via API to store in the API response dictionary
    ${retrieved_hostname_api}    BIG-IP iControl BasicAuth GET
    ...    bigip_host=${bigip_host}
    ...    bigip_username=${bigip_username}
    ...    bigip_password=${bigip_password}
    ...    api_uri=/mgmt/tm/sys/global-settings
    Set to Dictionary    ${api_responses}    hostname=${retrieved_hostname_api.json()}[hostname]

Retrieve BIG-IP License Information
    [Documentation]    Retrieves the current license information on the BIG-IP (https://my.f5.com/manage/s/article/K7752)
    # Retrieval via SSH to store in status file
    SSHLibrary.Open Connection    ${bigip_host}    port=${bigip_ssh_port}
    IF    "${bigip_ssh_identity_file}" != "${EMPTY}"
        SSHLibrary.Login with public key    username=${bigip_username}    keyfile=${bigip_ssh_identity_file}
    ELSE
        SSHLibrary.Login    username=${bigip_username}    password=${bigip_password}
    END
    ${retrieved_license_cli}    SSHLibrary.Execute Command    bash -c 'tmsh show sys license'
    Should not contain    ${retrieved_license_cli}    Can't load license, may not be operational
    Append to file    ${status_output_full_path}    ======> License: ${retrieved_license_cli}\n
    # Retrieval via API to store in the API response dictionary
    ${retrieved_license_api}    BIG-IP iControl BasicAuth GET
    ...    bigip_host=${bigip_host}
    ...    bigip_username=${bigip_username}
    ...    bigip_password=${bigip_password}
    ...    api_uri=/mgmt/tm/sys/license
    Set to Dictionary    ${api_responses}    license=${retrieved_license_api.json()}
    # Parse for anomalies
    Dictionary should not contain key    ${retrieved_license_api.json()}    apiRawValues
    ${service_check_date}    Set variable    ${retrieved_license_api.json()}[entries][https://localhost/mgmt/tm/sys/license/0][nestedStats][entries][serviceCheckDate][description]
    Set to Dictionary    ${api_responses}    license-service-check-date=${service_check_date}
    ${current_date}    Get current date    result_format=%Y/%m/%d
    Append to file    ${status_output_full_path}    ======> Current date: ${current_date}\n
    Set to Dictionary    ${api_responses}    current-date=${current_date}
    ${days_until_service_check_date}    Subtract date from date    ${service_check_date}    ${current_date}
    IF    ${days_until_service_check_date} < 1
        Log to console    \nWARNING: License service check date occurs in the past! Re-activate license required prior to upgrade! (https://my.f5.com/manage/s/article/K7727)
        Log    WARNING: License service check date occurs in the past! Reactivate license required prior to upgrade! (https://my.f5.com/manage/s/article/K7727)
        Append to file    ${status_output_full_path}    ======> WARNING: License service check date occurs in the past! Re-actviate license required prior to upgrade! (https://my.f5.com/manage/s/article/K7727)\n
    ELSE IF    ${days_until_service_check_date} < 14
        Log to console    \nWARNING: Current date is nearing License service check date (${service_check_date})! Reactivate license required prior to upgrade! (https://my.f5.com/manage/s/article/K7727)
        Log    WARNING: Current date is nearing License service check date (${service_check_date})! Reactivate license required prior to upgrade! (https://my.f5.com/manage/s/article/K7727)
        Append to file    ${status_output_full_path}    ======> WARNING: Current date is nearing License service check date (${service_check_date})! Reactivate license required prior to upgrade! (https://my.f5.com/manage/s/article/K7727)\n
    END

Retrieve BIG-IP TMOS Version
    [Documentation]    Retrieves the current TMOS version of the device and verifies lifecycle status. (https://my.f5.com/manage/s/article/K5903)
    # Retrieval via SSH to store in status file
    SSHLibrary.Open Connection    ${bigip_host}    port=${bigip_ssh_port}
    IF    "${bigip_ssh_identity_file}" != "${EMPTY}"
        SSHLibrary.Login with public key    username=${bigip_username}    keyfile=${bigip_ssh_identity_file}
    ELSE
        SSHLibrary.Login    username=${bigip_username}    password=${bigip_password}
    END
    ${retrieved_version_cli}    SSHLibrary.Execute Command    bash -c 'tmsh show sys version'
    Append to file    ${status_output_full_path}    ======> BIG-IP Version: ${retrieved_version_cli}\n
    # Retrieval via API to store in the API response dictionary
    ${retrieved_version_api}    BIG-IP iControl BasicAuth GET
    ...    bigip_host=${bigip_host}
    ...    bigip_username=${bigip_username}
    ...    bigip_password=${bigip_password}
    ...    api_uri=/mgmt/tm/sys/version
    ${bigip_version}    Set variable    ${retrieved_version_api.json()}[entries][https://localhost/mgmt/tm/sys/version/0][nestedStats][entries][Version][description]
    Set to Dictionary    ${api_responses}    version=${retrieved_version_api.json()}
    # Parse for anomalies
    ${current_date}    Get current date    result_format=%Y/%m/%d
    IF    "17.1." in "${bigip_version}"
        ${end_of_software_development}    Set variable    2027/03/31
        ${end_of_technical_support}    Set variable    2027/03/31
        ${remaining_days_software_development}    Subtract date from date    ${end_of_software_development}    ${current_date}
        ${remaining_days_technical_support}    Subtract date from date    ${end_of_technical_support}    ${current_date}
        ${remaining_days_software_development_human_readable}    Subtract date from date    ${end_of_software_development}    ${current_date}    verbose
        ${remaining_days_technical_support_human_readable}    Subtract date from date    ${end_of_technical_support}    ${current_date}    verbose
        IF    ${remaining_days_software_development} > 0 and ${remaining_days_technical_support} > 0
            Set to Dictionary    ${api_responses}    remaining-days-software-development=${remaining_days_software_development}
            Set to Dictionary    ${api_responses}    remaining-days-technical-support=${remaining_days_technical_support}
            Append to file    ${status_output_full_path}    ======> Remaining Days of Software Development Support: ${remaining_days_software_development_human_readable}\n
            Append to file    ${status_output_full_path}    ======> Remaining Days of Technical Support: ${remaining_days_technical_support_human_readable}\n
        ELSE IF    ${remaining_days_software_development} <= 0
            Log to console    \nWARNING: TMOS release has reached end of software development status in lifecycle. (https://my.f5.com/manage/s/article/K5903)
            Log    WARNING: TMOS release has reached end of software development status in lifecycle. (https://my.f5.com/manage/s/article/K5903)
            Append to file    ${status_output_full_path}    ======> WARNING: TMOS release has reached end of software development status in lifecycle. (https://my.f5.com/manage/s/article/K5903)\n
        ELSE IF    ${remaining_days_technical_support} <= 0
            Log to console    \nWARNING: TMOS release has reached end of technical support status in lifecycle. (https://my.f5.com/manage/s/article/K5903)
            Log    WARNING: TMOS release has reached end of software development status in lifecycle. (https://my.f5.com/manage/s/article/K5903)
            Append to file    ${status_output_full_path}    ======> WARNING: TMOS release has reached end of software development status in lifecycle. (https://my.f5.com/manage/s/article/K5903)\n
        END
    ELSE IF    "16.1." in "${bigip_version}"
        ${end_of_software_development}    Set variable    2025/07/31
        ${end_of_technical_support}    Set variable    2025/07/31
        ${remaining_days_software_development}    Subtract date from date    ${end_of_software_development}    ${current_date}
        ${remaining_days_technical_support}    Subtract date from date    ${end_of_technical_support}    ${current_date}
        ${remaining_days_software_development_human_readable}    Subtract date from date    ${end_of_software_development}    ${current_date}    verbose
        ${remaining_days_technical_support_human_readable}    Subtract date from date    ${end_of_technical_support}    ${current_date}    verbose
        IF    ${remaining_days_software_development} > 0 and ${remaining_days_technical_support} > 0
            Set to Dictionary    ${api_responses}    remaining-days-software-development=${remaining_days_software_development}
            Set to Dictionary    ${api_responses}    remaining-days-technical-support=${remaining_days_technical_support}
            Append to file    ${status_output_full_path}    ======> Remaining Days of Software Development Support: ${remaining_days_software_development_human_readable}\n
            Append to file    ${status_output_full_path}    ======> Remaining Days of Technical Support: ${remaining_days_technical_support_human_readable}\n
        ELSE IF    ${remaining_days_software_development} <= 0
            Log to console    \nWARNING: TMOS release has reached end of software development status in lifecycle. (https://my.f5.com/manage/s/article/K5903)
            Log    WARNING: TMOS release has reached end of software development status in lifecycle. (https://my.f5.com/manage/s/article/K5903)
            Append to file    ${status_output_full_path}    ======> WARNING: TMOS release has reached end of software development status in lifecycle. (https://my.f5.com/manage/s/article/K5903)\n
        ELSE IF    ${remaining_days_technical_support} <= 0
            Log to console    \nWARNING: TMOS release has reached end of technical support status in lifecycle. (https://my.f5.com/manage/s/article/K5903)
            Log    WARNING: TMOS release has reached end of software development status in lifecycle. (https://my.f5.com/manage/s/article/K5903)
            Append to file    ${status_output_full_path}    ======> WARNING: TMOS release has reached end of software development status in lifecycle. (https://my.f5.com/manage/s/article/K5903)\n
        END
    ELSE IF    "15.1." in "${bigip_version}"
        ${end_of_software_development}    Set variable    2024/12/31
        ${end_of_technical_support}    Set variable    2024/12/31
        ${remaining_days_software_development}    Subtract date from date    ${end_of_software_development}    ${current_date}
        ${remaining_days_technical_support}    Subtract date from date    ${end_of_technical_support}    ${current_date}
        ${remaining_days_software_development_human_readable}    Subtract date from date    ${end_of_software_development}    ${current_date}    verbose
        ${remaining_days_technical_support_human_readable}    Subtract date from date    ${end_of_technical_support}    ${current_date}    verbose
        IF    ${remaining_days_software_development} > 0 and ${remaining_days_technical_support} > 0
            Set to Dictionary    ${api_responses}    remaining-days-software-development=${remaining_days_software_development}
            Set to Dictionary    ${api_responses}    remaining-days-technical-support=${remaining_days_technical_support}
            Append to file    ${status_output_full_path}    ======> Remaining Days of Software Development Support: ${remaining_days_software_development_human_readable}\n
            Append to file    ${status_output_full_path}    ======> Remaining Days of Technical Support: ${remaining_days_technical_support_human_readable}\n
        ELSE IF    ${remaining_days_software_development} <= 0
            Log to console    \nWARNING: TMOS release has reached end of software development status in lifecycle. (https://my.f5.com/manage/s/article/K5903)
            Log    WARNING: TMOS release has reached end of software development status in lifecycle. (https://my.f5.com/manage/s/article/K5903)
            Append to file    ${status_output_full_path}    ======> WARNING: TMOS release has reached end of software development status in lifecycle. (https://my.f5.com/manage/s/article/K5903)\n
        ELSE IF    ${remaining_days_technical_support} <= 0
            Log to console    \nWARNING: TMOS release has reached end of technical support status in lifecycle. (https://my.f5.com/manage/s/article/K5903)
            Log    WARNING: TMOS release has reached end of software development status in lifecycle. (https://my.f5.com/manage/s/article/K5903)
            Append to file    ${status_output_full_path}    ======> WARNING: TMOS release has reached end of software development status in lifecycle. (https://my.f5.com/manage/s/article/K5903)\n
        END
    ELSE IF    "13.1." in "${bigip_version}" or "14.1." in "${bigip_version}"
        ${end_of_software_development}    Set variable    2023/12/31
        ${end_of_technical_support}    Set variable    2023/12/31
        ${remaining_days_software_development}    Subtract date from date    ${end_of_software_development}    ${current_date}
        ${remaining_days_technical_support}    Subtract date from date    ${end_of_technical_support}    ${current_date}
        ${remaining_days_software_development_human_readable}    Subtract date from date    ${end_of_software_development}    ${current_date}    verbose
        ${remaining_days_technical_support_human_readable}    Subtract date from date    ${end_of_technical_support}    ${current_date}    verbose
        IF    ${remaining_days_software_development} > 0 and ${remaining_days_technical_support} > 0
            Set to Dictionary    ${api_responses}    remaining-days-software-development=${remaining_days_software_development}
            Set to Dictionary    ${api_responses}    remaining-days-technical-support=${remaining_days_technical_support}
            Append to file    ${status_output_full_path}    ======> Remaining Days of Software Development Support: ${remaining_days_software_development_human_readable}\n
            Append to file    ${status_output_full_path}    ======> Remaining Days of Technical Support: ${remaining_days_technical_support_human_readable}\n
        ELSE IF    ${remaining_days_software_development} <= 0
            Log to console    \nWARNING: TMOS release has reached end of software development status in lifecycle. (https://my.f5.com/manage/s/article/K5903)
            Log    WARNING: TMOS release has reached end of software development status in lifecycle. (https://my.f5.com/manage/s/article/K5903)
            Append to file    ${status_output_full_path}    ======> WARNING: TMOS Release has reached end of software development status in lifecycle. (https://my.f5.com/manage/s/article/K5903)\n
        ELSE IF    ${remaining_days_technical_support} <= 0
            Log to console    \nWARNING: TMOS release has reached end of technical support status in lifecycle. (https://my.f5.com/manage/s/article/K5903)
            Log    WARNING: TMOS release has reached end of software development status in lifecycle. (https://my.f5.com/manage/s/article/K5903)
            Append to file    ${status_output_full_path}    ======> WARNING: TMOS Release has reached end of software development status in lifecycle. (https://my.f5.com/manage/s/article/K5903)\n
        END
    ELSE
        Log to console    \nTMOS release ${bigip_version} has reached end of life. (https://my.f5.com/manage/s/article/K5903)
        Append to file    ${status_output_full_path}    ======> TMOS release ${bigip_version} has reached end of life. See https://my.f5.com/manage/s/article/K5903 for more information.\n
    END

Retrieve BIG-IP NTP Configuration and Verify NTP Servers are Configured
    [Documentation]    Retrieves the NTP Configuration on the BIG-IP (https://my.f5.com/manage/s/article/K13380)
    # Retrieval via API to store in the API response dictionary
    ${retrieved_ntp_config_api}    BIG-IP iControl BasicAuth GET
    ...    bigip_host=${bigip_host}
    ...    bigip_username=${bigip_username}
    ...    bigip_password=${bigip_password}
    ...    api_uri=/mgmt/tm/sys/ntp
    # Parse for anomalies
    Dictionary Should Contain Key    ${retrieved_ntp_config_api.json()}   servers

Retrieve and Verify BIG-IP NTP Status
    [Documentation]    Retrieves the NTP status on the BIG-IP (https://my.f5.com/manage/s/article/K10240)
    # Retrieval via SSH to store in status file
    SSHLibrary.Open Connection    ${bigip_host}    port=${bigip_ssh_port}
    IF    "${bigip_ssh_identity_file}" != "${EMPTY}"
        SSHLibrary.Login with public key    username=${bigip_username}    keyfile=${bigip_ssh_identity_file}
    ELSE
        SSHLibrary.Login    username=${bigip_username}    password=${bigip_password}
    END
    ${retrieved_ntp_status_cli}    SSHLibrary.Execute Command    bash -c 'ntpq -pn'
    Append to file    ${status_output_full_path}    ======> NTP Status:\n${retrieved_ntp_status_cli}\n
    # Parse for anomalies
    ${ntpq_output_start}    Set Variable    ${retrieved_ntp_status_cli.find("===\n")}
    ${ntpq_output_clean}    Set Variable    ${retrieved_ntp_status_cli[${ntpq_output_start}+4:]}
    ${ntpq_output_values_list}    Split String    ${ntpq_output_clean}
    ${ntpq_output_length}    get length    ${ntpq_output_values_list}
    ${ntpq_output_server_count}    evaluate    ${ntpq_output_length} / 10
    FOR    ${current_ntp_server}    IN RANGE    0    ${ntpq_output_server_count}
        ${ntp_server_ip}    remove from list    ${ntpq_output_values_list}  0
        ${ntp_server_reference}    remove from list    ${ntpq_output_values_list}  0
        ${ntp_server_stratum}    remove from list    ${ntpq_output_values_list}  0
        ${ntp_server_type}    remove from list    ${ntpq_output_values_list}  0
        ${ntp_server_when}    remove from list    ${ntpq_output_values_list}  0
        ${ntp_server_poll}    remove from list    ${ntpq_output_values_list}  0
        ${ntp_server_reach}    remove from list    ${ntpq_output_values_list}  0
        ${ntp_server_delay}    remove from list    ${ntpq_output_values_list}  0
        ${ntp_server_offset}    remove from list    ${ntpq_output_values_list}  0
        ${ntp_server_jitter}    remove from list    ${ntpq_output_values_list}  0
    END
    should not be equal as integers    ${ntp_server_reach}    0
    should not be equal as strings    ${ntp_server_when}    -
    should not be equal as strings    ${ntp_server_reference}    .STEP.
    should not be equal as strings    ${ntp_server_reference}    .LOCL.
    Set to Dictionary    ${api_responses}    ntp-status=${retrieved_ntp_status_cli}

Verify BIG-IP Disk Space
    [Documentation]    Verifies that the BIG-IP disk utilization is healthy. (https://my.f5.com/manage/s/article/K14403)
    # Retrieval via SSH to store in status file
    SSHLibrary.Open Connection    ${bigip_host}    port=${bigip_ssh_port}
    IF    "${bigip_ssh_identity_file}" != "${EMPTY}"
        SSHLibrary.Login with public key    username=${bigip_username}    keyfile=${bigip_ssh_identity_file}
    ELSE
        SSHLibrary.Login    username=${bigip_username}    password=${bigip_password}
    END
    ${df_output}    SSHLibrary.Execute Command    bash -c 'df --human-readable --output'
    Append to file    ${statistics_output_full_path}    ======> Disk Space Utilization:\n${df_output}\n
    @{df_output_items}    Split to lines    ${df_output}
    FOR    ${current_mount_point}    IN    @{df_output_items}
        IF    "Filesystem" in "${current_mount_point}" and "Use%" in "${current_mount_point}"
            Log    Skipping column header line
        ELSE
            @{df_entry_data}    Split string    ${current_mount_point}
            ${source}    Get from list    ${df_entry_data}    0
            ${type}    Get from list    ${df_entry_data}    1
            ${inodes_total}    Get from list    ${df_entry_data}    2
            ${inodes_used}    Get from list    ${df_entry_data}    3
            ${inodes_free}    Get from list    ${df_entry_data}    4
            ${inodes_used_pct}    Get from list    ${df_entry_data}    5
            ${size}    Get from list    ${df_entry_data}    6
            ${used}    Get from list    ${df_entry_data}    7
            ${avail}    Get from list    ${df_entry_data}    8
            ${used_pct}    Get from list    ${df_entry_data}    9
            ${target}    Get from list    ${df_entry_data}    11
            IF    "${target}" == "/usr"
                Log    Skipping disk space check for /usr (https://my.f5.com/manage/s/article/K23607394)
            ELSE
                ${percentage_used}    Remove string    ${used_pct}    %
                IF    ${${percentage_used}} > 90
                    Log to console    \nWARNING: Filesystem ${target} is using ${used_pct} of available space! (https://my.f5.com/manage/s/article/K14403)
                    Append to file    ${status_output_full_path}    ======> WARNING: Filesystem ${target} is using ${used_pct} of available space! (https://my.f5.com/manage/s/article/K14403)\n
                END
                ${inodes_used_pct}    Remove string    ${inodes_used_pct}    %
                IF    ${${inodes_used_pct}} > 90
                    Log to console    \nWARNING: Filesystem ${target} is using a high percentage (${inodes_used_pct}) of available inodes! (https://my.f5.com/manage/s/article/K14403)
                    Append to file    ${status_output_full_path}    ======> WARNING: Filesystem ${target} is using a high percentage of available inodes! (https://my.f5.com/manage/s/article/K14403)
                END
            END
            Set to dictionary    ${disk_volume_utilization}    ${target}=${used_pct}
        END
    END
    Set to dictionary    ${api_responses}    disk-utilization=${disk_volume_utilization}

Retrieve Top 20 Directories by Size on Disk
    [Documentation]    Retrieves the top 20 directories on the BIG-IP by disk space size (https://my.f5.com/manage/s/article/K14403)
    # Retrieval via SSH to store in status file
    SSHLibrary.Open Connection    ${bigip_host}    port=${bigip_ssh_port}
    IF    "${bigip_ssh_identity_file}" != "${EMPTY}"
        SSHLibrary.Login with public key    username=${bigip_username}    keyfile=${bigip_ssh_identity_file}
    ELSE
        SSHLibrary.Login    username=${bigip_username}    password=${bigip_password}
    END
    ${top_directories}    SSHLibrary.Execute command    bash -c "du --exclude=/proc/* -Sh / | sort -rh | head -n 20"
    Append to file    ${statistics_output_full_path}    ======> Top directories on disk by size:\n${top_directories}\n

Retrieve Top 20 Files by Size on Disk
    [Documentation]    Retrieves the top 20 files on the BIG-IP by disk space size (https://my.f5.com/manage/s/article/K14403)
    # Retrieval via SSH to store in status file
    SSHLibrary.Open Connection    ${bigip_host}    port=${bigip_ssh_port}
    IF    "${bigip_ssh_identity_file}" != "${EMPTY}"
        SSHLibrary.Login with public key    username=${bigip_username}    keyfile=${bigip_ssh_identity_file}
    ELSE
        SSHLibrary.Login    username=${bigip_username}    password=${bigip_password}
    END
    ${top_files}    SSHLibrary.Execute command    bash -c "find / -type f -exec du --exclude=/proc/* -Sh {} + | sort -rh | head -n 20"
    Append to file    ${statistics_output_full_path}    ======> Top files on disk by size:\n${top_files}\n

Verify High Availability Status
    [Documentation]    Retrieves the CM high availability status from the BIG-IP.
    # Retrieval via SSH to store in status file
    SSHLibrary.Open Connection    ${bigip_host}    port=${bigip_ssh_port}
    IF    "${bigip_ssh_identity_file}" != "${EMPTY}"
        SSHLibrary.Login with public key    username=${bigip_username}    keyfile=${bigip_ssh_identity_file}
    ELSE
        SSHLibrary.Login    username=${bigip_username}    password=${bigip_password}
    END
    ${check_cert_output}    SSHLibrary.Execute command    bash -c "tmsh show / cm recursive"
    Append to file    ${status_output_full_path}    ======> HA Status:\n${check_cert_output}\n
    # Retrieval via API to store in the API response dictionary
    ${cm_status}    BIG-IP iControl BasicAuth GET
    ...    bigip_host=${bigip_host}
    ...    bigip_username=${bigip_username}
    ...    bigip_password=${bigip_password}
    ...    api_uri=/mgmt/tm/cm
    Set to dictionary    ${api_responses}    cm_status=${cm_status}

Verify Certificate Status and Expiration
    [Documentation]    Runs the check-cert utility on the BIG-IP to check and record certificate expirations; also retrieves certificates via API and warns if any are set to expire in a specified timeframe (https://clouddocs.f5.com/cli/tmsh-reference/v15/modules/sys/sys_crypto_check-cert.html)
    # Retrieval via SSH to store in status file
    SSHLibrary.Open Connection    ${bigip_host}    port=${bigip_ssh_port}
    IF    "${bigip_ssh_identity_file}" != "${EMPTY}"
        SSHLibrary.Login with public key    username=${bigip_username}    keyfile=${bigip_ssh_identity_file}
    ELSE
        SSHLibrary.Login    username=${bigip_username}    password=${bigip_password}
    END
    ${check_cert_output}    SSHLibrary.Execute command    bash -c "tmsh run sys crypto check-cert verbose enabled ignore-large-cert-bundles enabled"
    Append to file    ${status_output_full_path}    ======> Certificate Check Output:\n${check_cert_output}\n
    # Retrieval via API to store in the API response dictionary
    ${certificate_list_api}    BIG-IP iControl BasicAuth GET
    ...    bigip_host=${bigip_host}
    ...    bigip_username=${bigip_username}
    ...    bigip_password=${bigip_password}
    ...    api_uri=/mgmt/tm/sys/crypto/cert
    @{certificate_list}    Set variable    ${certificate_list_api.json()}[items]
    FOR    ${current_certificate}    IN    @{certificate_list}
        ${current_certificate_name}    Set variable    ${current_certificate}[name]
        ${current_certificate_common_name}    Set variable    ${current_certificate}[commonName]
        ${current_certificate_expiry}    Set variable    ${current_certificate}[apiRawValues][expiration]
        ${current_timestamp}    DateTime.Get current date
        ${current_certificate_remaining_time}    DateTime.Subtract date from date    ${current_certificate_expiry}    ${current_timestamp}    date1_format=%b %d %H:%M:%S %Y %Z
        ${current_certificate_remaining_time_verbose}    DateTime.Subtract date from date    ${current_certificate_expiry}    ${current_timestamp}    verbose    date1_format=%b %d %H:%M:%S %Y %Z
        # Warn about certificates expiring in the next 14 days; value specified is in seconds
        IF    ${${current_certificate_remaining_time}} < 1209600
            Log to console    \nWARNING: ${current_certificate_name} expires in ${current_certificate_remaining_time_verbose} on ${current_certificate_expiry}!
            Append to file    ${status_output_full_path}    WARNING: ${current_certificate_name} expires in ${current_certificate_remaining_time_verbose} on ${current_certificate_expiry}!
        END
    END

Interface Statistics
    [Documentation]    Retrieves BIG-IP interface statistics and highlights those in possibly abnormal state
    # Retrieval via SSH to store in status file
    SSHLibrary.Open Connection    ${bigip_host}    port=${bigip_ssh_port}
    IF    "${bigip_ssh_identity_file}" != "${EMPTY}"
        SSHLibrary.Login with public key    username=${bigip_username}    keyfile=${bigip_ssh_identity_file}
    ELSE
        SSHLibrary.Login    username=${bigip_username}    password=${bigip_password}
    END
    ${interface_stats_cli}    SSHLibrary.Execute Command    bash -c 'show / net interface recursive all-properties'
    Append to file    ${statistics_output_full_path}    ======> Interface Statistics:\n${interface_stats_cli}\n
    # Retrieval via API to store in the API response dictionary
    ${interface_stats_api}    BIG-IP iControl BasicAuth GET
    ...    bigip_host=${bigip_host}
    ...    bigip_username=${bigip_username}
    ...    bigip_password=${bigip_password}
    ...    api_uri=/mgmt/tm/net/interface/stats
    ${interface_stats}    Set variable    ${interface_stats_api.json()}[entries]
    Set to dictionary    ${api_responses}    virtual-address-stats=${interface_stats}
    # Parse for anomalies
    Append to file    ${status_output_full_path}    =====> Interface Status:\n
    @{interface_list}    Get dictionary keys    ${interface_stats}
    FOR    ${current_interface}    IN    @{interface_list}
        ${current_interface_stats}    Get from dictionary    ${interface_stats}    ${current_interface}
        ${current_interface_name}    Set variable    ${current_interface_stats}[nestedStats][entries][tmName][description]
        ${current_interface_status}    Set variable    ${current_interface_stats}[nestedStats][entries][status][description]
        IF    "${current_interface_status}" != "up" and "${current_interface_status}" != "disabled"
            Log to console    \nInterface Impaired: ${current_interface_name} (${current_interface_status})
            Append to file    ${status_output_full_path}    Interface Impaired: ${current_interface_name} (${current_interface_status})
        END
        ${current_interface_counters_drops_all}    Set variable    ${current_interface_stats}[nestedStats][entries][counters.dropsAll][value]
        IF    ${${current_interface_counters_drops_all}} > 0
            Log to console    \nInterface Drops: ${current_interface_name} (${current_interface_counters_drops_all})
            Append to file    ${status_output_full_path}    Interface Drops: ${current_interface_name} (${current_interface_counters_drops_all})
        END
        ${current_interface_counters_errors_all}    Set variable    ${current_interface_stats}[nestedStats][entries][counters.errorsAll][value]
        IF    ${${current_interface_counters_errors_all}} > 0
            Log to console    \nInterface Errors: ${current_interface_name} (${current_interface_counters_errors_all})
            Append to file    ${status_output_full_path}    Interface Errors: ${current_interface_name} (${current_interface_counters_errors_all})
        END
    END

Route Domain Statistics
    [Documentation]    Retrieves BIG-IP route domain statistics and highlights those in possibly abnormal state
    # Retrieval via SSH to store in status file
    SSHLibrary.Open Connection    ${bigip_host}    port=${bigip_ssh_port}
    IF    "${bigip_ssh_identity_file}" != "${EMPTY}"
        SSHLibrary.Login with public key    username=${bigip_username}    keyfile=${bigip_ssh_identity_file}
    ELSE
        SSHLibrary.Login    username=${bigip_username}    password=${bigip_password}
    END
    ${trunk_stats_cli}    SSHLibrary.Execute Command    bash -c 'show net route-domain all'
    Append to file    ${statistics_output_full_path}    ======> Route Domain Statistics:\n${trunk_stats_cli}\n
    # Retrieval via API to store in the API response dictionary
    ${route_domain_stats_api}    BIG-IP iControl BasicAuth GET
    ...    bigip_host=${bigip_host}
    ...    bigip_username=${bigip_username}
    ...    bigip_password=${bigip_password}
    ...    api_uri=/mgmt/tm/net/route-domain/stats
    ${route_domain_stats}    Set variable    ${route_domain_stats_api.json()}[entries]
    Set to dictionary    ${api_responses}    virtual-address-stats=${route_domain_stats}
    # Parse for anomalies
    Append to file    ${status_output_full_path}    =====> Route Domain Status:\n
    @{route_domain_list}    Get dictionary keys    ${route_domain_stats}
    FOR    ${current_route_domain}    IN    @{route_domain_list}
        ${current_route_domain_stats}    Get from dictionary    ${route_domain_stats}    ${current_route_domain}
        ${current_route_domain_name}    Set variable    ${current_route_domain_stats}[nestedStats][entries][tmName][description]
        ${current_route_domain_current_connections}    Set variable    ${current_route_domain_stats}[nestedStats][entries][clientside.curConns][value]
        ${current_route_domain_total_connections}    Set variable    ${current_route_domain_stats}[nestedStats][entries][clientside.totConns][value]
        ${current_route_domain_max_connections}    Set variable    ${current_route_domain_stats}[nestedStats][entries][clientside.maxConns][value]
        IF    ${${current_route_domain_current_connections}} == 0
            Log to console    \nRoute Domain with Zero Current Connections: ${current_route_domain_name} (Max: ${current_route_domain_max_connections} / Total: ${current_route_domain_total_connections})
            Append to file    ${status_output_full_path}    Route Domain with Zero Current Connections: ${current_route_domain_name} (Total: ${current_route_domain_total_connections} / Max: ${current_route_domain_max_connections})
        END
    END

Trunk Statistics
    [Documentation]    Retrieves BIG-IP Trunk statistics and highlights those in possibly abnormal state
    # Retrieval via SSH to store in status file
    SSHLibrary.Open Connection    ${bigip_host}    port=${bigip_ssh_port}
    IF    "${bigip_ssh_identity_file}" != "${EMPTY}"
        SSHLibrary.Login with public key    username=${bigip_username}    keyfile=${bigip_ssh_identity_file}
    ELSE
        SSHLibrary.Login    username=${bigip_username}    password=${bigip_password}
    END
    ${trunk_stats_cli}    SSHLibrary.Execute Command    bash -c 'show net trunk all-properties detail'
    Append to file    ${statistics_output_full_path}    ======> Trunk Statistics:\n${trunk_stats_cli}\n
    # Retrieval via API to store in the API response dictionary
    ${trunk_stats_api}    BIG-IP iControl BasicAuth GET
    ...    bigip_host=${bigip_host}
    ...    bigip_username=${bigip_username}
    ...    bigip_password=${bigip_password}
    ...    api_uri=/mgmt/tm/net/trunk/stats
    ${trunk_stats}    Set variable    ${trunk_stats_api.json()}[entries]
    Set to dictionary    ${api_responses}    virtual-address-stats=${trunk_stats}
    # Parse for anomalies
    Append to file    ${status_output_full_path}    =====> Trunk Status:\n
    @{trunk_list}    Get dictionary keys    ${trunk_stats}
    FOR    ${current_trunk}    IN    @{trunk_list}
        ${current_trunk_stats}    Get from dictionary    ${trunk_stats}    ${current_trunk}
        ${current_trunk_name}    Set variable    ${current_trunk_stats}[nestedStats][entries][tmName][description]
        ${current_trunk_status}    Set variable    ${current_trunk_stats}[nestedStats][entries][status][description]
        IF    "${current_trunk_status}" != "up"
            Log to console    \nTrunk with Impaired Status: ${current_trunk_name} (${current_trunk_status})
            Append to file    ${status_output_full_path}    Trunk with Impaired Status: ${current_trunk_name} (${current_trunk_status})\n
        END
        ${current_trunk_counters_collisions}    Set variable    ${current_trunk_stats}[nestedStats][entries][counters.collisions][value]
        IF    ${${current_trunk_counters_collisions}} > 0
            Log to console    \nTrunk with Collisions: ${current_trunk_name} (${current_trunk_counters_collisions})
            Append to file    ${status_output_full_path}    Trunk with Collisions: ${current_trunk_name} (${current_trunk_counters_collisions})\n
        END
        ${current_trunk_counters_ingress_drops}    Set variable    ${current_trunk_stats}[nestedStats][entries][counters.dropsIn][value]
        IF    ${${current_trunk_counters_ingress_drops}} > 0
            Log to console    \nTrunk with Ingress Drops: ${current_trunk_name} (${current_trunk_counters_ingress_drops})
            Append to file    ${status_output_full_path}    Trunk with Ingress Drops: ${current_trunk_name} (${current_trunk_counters_ingress_drops})\n
        END
        ${current_trunk_counters_egress_drops}    Set variable    ${current_trunk_stats}[nestedStats][entries][counters.dropsOut][value]
        IF    ${${current_trunk_counters_egress_drops}} > 0
            Log to console    \nTrunk with Egress Drops: ${current_trunk_name} (${current_trunk_counters_egress_drops})
            Append to file    ${status_output_full_path}    Trunk with Egress Drops: ${current_trunk_name} (${current_trunk_counters_egress_drops})\n
        END
        ${current_trunk_counters_ingress_errors}    Set variable    ${current_trunk_stats}[nestedStats][entries][counters.errorsIn][value]
        IF    ${${current_trunk_counters_ingress_errors}} > 0
            Log to console    \nTrunk with Ingress Errors: ${current_trunk_name} (${current_trunk_counters_ingress_errors})
            Append to file    ${status_output_full_path}    Trunk with Ingress Errors: ${current_trunk_name} (${current_trunk_counters_ingress_errors})\n
        END
        ${current_trunk_counters_egress_errors}    Set variable    ${current_trunk_stats}[nestedStats][entries][counters.errorsOut][value]
        IF    ${${current_trunk_counters_egress_errors}} > 0
            Log to console    \nTrunk with Egress Errors${current_trunk_name} (${current_trunk_counters_egress_errors})
            Append to file    ${status_output_full_path}    Trunk with Egress Errors: ${current_trunk_name} (${current_trunk_counters_egress_errors})\n
        END
    END

Retrieve BIG-IP Virtual Server Statistics
    [Documentation]    Retrieves BIG-IP virtual server statistics and highlights those in possibly abnormal state
    # Retrieval via SSH to store in status file
    SSHLibrary.Open Connection    ${bigip_host}    port=${bigip_ssh_port}
    IF    "${bigip_ssh_identity_file}" != "${EMPTY}"
        SSHLibrary.Login with public key    username=${bigip_username}    keyfile=${bigip_ssh_identity_file}
    ELSE
        SSHLibrary.Login    username=${bigip_username}    password=${bigip_password}
    END
    ${virtual_server_stats_cli}    SSHLibrary.Execute Command    bash -c 'tmsh show / ltm virtual all-properties recursive'
    Append to file    ${statistics_output_full_path}    ======> Virtual Server Statistics:\n${virtual_server_stats_cli}\n
    # Retrieval via API to store in the API response dictionary
    ${virtual_server_stats_api}    BIG-IP iControl BasicAuth GET
    ...    bigip_host=${bigip_host}
    ...    bigip_username=${bigip_username}
    ...    bigip_password=${bigip_password}
    ...    api_uri=/mgmt/tm/ltm/virtual/stats
    ${virtual_server_stats}    Set variable    ${virtual_server_stats_api.json()}[entries]
    Set to dictionary    ${api_responses}    virtual-address-stats=${virtual_server_stats}
    # Parse for anomalies
    Append to file    ${status_output_full_path}    =====> Virtual Address Status:\n
    @{virtual_server_list}    Get dictionary keys    ${virtual_server_stats}
    FOR    ${current_virtual_server}    IN    @{virtual_server_list}
        ${current_virtual_server_stats}    Get from dictionary    ${virtual_server_stats}    ${current_virtual_server}
        ${current_virtual_server_enabled_state}    Set variable    ${current_virtual_server_stats}[nestedStats][entries][status.enabledState][description]
        ${current_virtual_server_status_reason}    Set variable    ${current_virtual_server_stats}[nestedStats][entries][status.statusReason][description]
        ${current_virtual_server_name}    Set variable    ${current_virtual_server_stats}[nestedStats][entries][tmName][description]
        ${current_virtual_server_destination}    Set variable    ${current_virtual_server_stats}[nestedStats][entries][destination][description]
        ${current_virtual_server_current_connections}    Set variable    ${current_virtual_server_stats}[nestedStats][entries][clientside.curConns][value]
        ${current_virtual_server_max_connections}    Set variable    ${current_virtual_server_stats}[nestedStats][entries][clientside.maxConns][value]
        ${current_virtual_server_total_connections}    Set variable    ${current_virtual_server_stats}[nestedStats][entries][clientside.totConns][value]
        ${current_virtual_server_syncookie_status}    Set variable    ${current_virtual_server_stats}[nestedStats][entries][syncookieStatus][description]
        IF    ${${current_virtual_server_current_connections}} == 0
            Log to console    \nVirtual Server with Zero Connections: ${current_virtual_server_name} (Dest: ${current_virtual_server_destination}) (Max: ${current_virtual_server_max_connections}/Total: ${current_virtual_server_total_connections})
            Append to file    ${status_output_full_path}    Virtual Server with Zero Connections: ${current_virtual_server_name} (Dest: ${current_virtual_server_destination}) (Max: ${current_virtual_server_max_connections}/Total: ${current_virtual_server_total_connections})\n
        END
        IF    "${current_virtual_server_enabled_state}" != "enabled"
            Log to console    \nVirtual Server Not Enabled: ${current_virtual_server_name} (Dest: ${current_virtual_server_destination}) (${current_virtual_server_enabled_state}: ${current_virtual_server_status_reason})
            Append to file    ${status_output_full_path}    Virtual Server Not Enabled: ${current_virtual_server_name} (Dest: ${current_virtual_server_destination}) (${current_virtual_server_enabled_state}: ${current_virtual_server_status_reason})\n
        END
        IF    "${current_virtual_server_syncookie_status}" != "not-activated"
            Log to console    \nVirtual Server with Syn Cookies Active: ${current_virtual_server_name} (Dest: ${current_virtual_server_destination}) (${current_virtual_server_enabled_state}: ${current_virtual_server_status_reason})
            Append to file    ${status_output_full_path}    Virtual Server with Syn Cookies Active: ${current_virtual_server_name} (Dest: ${current_virtual_server_destination})\n
        END
    END

Retrieve BIG-IP Virtual Address Statistics
    [Documentation]    Retrieves BIG-IP virtual address statistics and highlights those in possibly abnormal state
    # Retrieval via SSH to store in status file
    SSHLibrary.Open Connection    ${bigip_host}    port=${bigip_ssh_port}
    IF    "${bigip_ssh_identity_file}" != "${EMPTY}"
        SSHLibrary.Login with public key    username=${bigip_username}    keyfile=${bigip_ssh_identity_file}
    ELSE
        SSHLibrary.Login    username=${bigip_username}    password=${bigip_password}
    END
    ${virtual_address_stats_cli}    SSHLibrary.Execute Command    bash -c 'tmsh show ltm virtual-address all-properties'
    Append to file    ${statistics_output_full_path}    ======> Virtual Address Statistics:\n${virtual_address_stats_cli}\n
    # Retrieval via API to store in the API response dictionary
    ${virtual_address_stats_api}    BIG-IP iControl BasicAuth GET
    ...    bigip_host=${bigip_host}
    ...    bigip_username=${bigip_username}
    ...    bigip_password=${bigip_password}
    ...    api_uri=/mgmt/tm/ltm/virtual-address/stats
    ${virtual_address_stats}    Set variable    ${virtual_address_stats_api.json()}[entries]
    Set to dictionary    ${api_responses}    virtual-address-stats=${virtual_address_stats}
    # Parse for anomalies
    Append to file    ${status_output_full_path}    =====> Virtual Address Status:\n
    @{virtual_address_list}    Get dictionary keys    ${virtual_address_stats}
    FOR    ${current_virtual_address}    IN    @{virtual_address_list}
        ${current_virtual_address_stats}    Get from dictionary    ${virtual_address_stats}    ${current_virtual_address}
        ${current_virtual_address_enabled_state}    Set variable    ${current_virtual_address_stats}[nestedStats][entries][status.enabledState][description]
        ${current_virtual_address_status_reason}    Set variable    ${current_virtual_address_stats}[nestedStats][entries][status.statusReason][description]
        ${current_virtual_address_name}    Set variable    ${current_virtual_address_stats}[nestedStats][entries][tmName][description]
        ${current_virtual_address_current_connections}    Set variable    ${current_virtual_address_stats}[nestedStats][entries][clientside.curConns][value]
        ${current_virtual_address_max_connections}    Set variable    ${current_virtual_address_stats}[nestedStats][entries][clientside.maxConns][value]
        ${current_virtual_address_total_connections}    Set variable    ${current_virtual_address_stats}[nestedStats][entries][clientside.totConns][value]
        IF    ${${current_virtual_address_current_connections}} == 0
            Log to console    \nVirtual Address with Zero Connections: ${current_virtual_address_name} (Max: ${current_virtual_address_max_connections}/Total: ${current_virtual_address_total_connections})
            Append to file    ${status_output_full_path}    Virtual Address with Zero Connections: ${current_virtual_address_name} (Max: ${current_virtual_address_max_connections}/Total: ${current_virtual_address_total_connections})\n
        END
        IF    "${current_virtual_address_enabled_state}" != "enabled"
            Log to console    \nVirtual Address Not Enabled: ${current_virtual_address_name} (${current_virtual_address_enabled_state}: ${current_virtual_address_status_reason})
            Append to file    ${status_output_full_path}    Virtual Address Not Enabled: ${current_virtual_address_name} (${current_virtual_address_enabled_state}: ${current_virtual_address_status_reason})\n
        END
    END

Retrieve Pool Statistics
    [Documentation]
    # Retrieval via SSH to store in status file
    SSHLibrary.Open Connection    host=${bigip_host}    port=${bigip_ssh_port}
    IF    "${bigip_ssh_identity_file}" != "${EMPTY}"
        SSHLibrary.Login with public key    username=${bigip_username}    keyfile=${bigip_ssh_identity_file}
    ELSE
        SSHLibrary.Login    username=${bigip_username}    password=${bigip_password}
    END
    ${pool_stats_cli}    SSHLibrary.Execute Command    bash -c 'tmsh show / ltm pool recursive'
    Append to file    ${statistics_output_full_path}    ======> Pool Statistics:\n${pool_stats_cli}\n
    # Retrieval via API to store in the API response dictionary
    ${pool_stats_api}    BIG-IP iControl BasicAuth GET
    ...    bigip_host=${bigip_host}
    ...    bigip_username=${bigip_username}
    ...    bigip_password=${bigip_password}
    ...    api_uri=/mgmt/tm/ltm/pool/stats
    &{pool_stats}    Set variable    ${pool_stats_api.json()}[entries]
    Set to dictionary    ${api_responses}    pool_statistics=${pool_stats}
    # Parse for anomalies
    Append to file    ${status_output_full_path}    =====> Pool Status:\n
    @{pool_list}    Get dictionary keys    ${pool_stats}
    FOR    ${current_pool}    IN    @{pool_list}
        ${current_pool_stats}    Get from dictionary    ${pool_stats}    ${current_pool}
        Log to console    ${current_pool_stats}
        ${current_pool_availability_state}    Set variable    ${current_pool_stats}[nestedStats][entries][status.availabilityState][description]
        ${current_pool_status_reason}    Set variable    ${current_pool_stats}[nestedStats][entries][status.statusReason][description]
        ${current_pool_available_member_count}    Set variable    ${current_pool_stats}[nestedStats][entries][availableMemberCnt][value]
        ${current_pool_total_member_count}    Set variable    ${current_pool_stats}[nestedStats][entries][memberCnt][value]
        ${current_pool_current_sessions}    Set variable    ${current_pool_stats}[nestedStats][entries][curSessions][value]
        IF    "${current_pool_availability_state}" != "available"
            Append to file    ${status_output_full_path}    Pool Unavailable: ${current_pool}\n
            Log to console    \nPool Unavailable: ${current_pool}\n
        END
        IF    ${${current_pool_total_member_count}} != ${${current_pool_available_member_count}}
            Append to file    ${status_output_full_path}    Pool with Unavailable Members: ${current_pool} (${current_pool_available_member_count}/${current_pool_total_member_count})\n
            Log to console    \nPool with Unavailable Members: ${current_pool} (${current_pool_available_member_count} of ${current_pool_total_member_count} unavailable)
        END
        IF    ${current_pool_current_sessions} <= 0
            Append to file    ${status_output_full_path}    Pool with Zero Connections: ${current_pool}\n
            Log to console    \nPool with Zero Current Connections: ${current_pool}
        END
    END

Retrieve BIG-IP Full Text Configuration via TMSH
    [Documentation]    Retrieve BIG-IPs the full BIG-IP configuration via list output
    # Retrieval via SSH to store in status file
    SSHLibrary.Open Connection    ${bigip_host}    port=${bigip_ssh_port}
    IF    "${bigip_ssh_identity_file}" != "${EMPTY}"
        SSHLibrary.Login with public key    username=${bigip_username}    keyfile=${bigip_ssh_identity_file}
    ELSE
        SSHLibrary.Login    username=${bigip_username}    password=${bigip_password}
    END
    ${full_text_configuration}    SSHLibrary.Execute command    bash -c 'tmsh -q list / all-properties one-line recursive'
    Append to file    ${status_output_full_path}   ======> Full Text Configuration:\n${full_text_configuration}\n

Retrieve BIG-IP Database Variables via TMSH
    [Documentation]    Retrieve BIG-IPs the full BIG-IP configuration via list output
    # Retrieval via SSH to store in status file
    SSHLibrary.Open Connection    ${bigip_host}    port=${bigip_ssh_port}
    IF    "${bigip_ssh_identity_file}" != "${EMPTY}"
        SSHLibrary.Login with public key    username=${bigip_username}    keyfile=${bigip_ssh_identity_file}
    ELSE
        SSHLibrary.Login    username=${bigip_username}    password=${bigip_password}
    END
    ${full_text_configuration}    SSHLibrary.Execute command    bash -c 'tmsh -q list sys db all-properties one-line'
    Append to file    ${status_output_full_path}   ======> Database Variables:\n${full_text_configuration}\n

Log API Responses in JSON
    [Documentation]    Creating a plain text block that can be diff'd between runs to view changes
    Log Dictionary   ${api_responses}
