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
Library            SSHLibrary    timeout=10 seconds    loglevel=trace
Library            RequestsLibrary
Library            Collections
Library            OperatingSystem
Library            DateTime
# Load other robot files that hold settings, variables and keywords
Resource           f5-stethoscope-keywords.robot
Resource           f5-stethoscope-variables.robot
# This commands ensures that the proper log level is used for each test without having to specify
# it repeatedly in each test. This Suite Setup keyword can be extended to issue multiple keywords
# prior to starting a test suite.
Suite Setup        Set Log Level    trace
# This set of commands runs at the end of each test suite, ensuring that SSH connections are 
# closed and any API sessions are closed. 
Suite Teardown     Run Keywords    SSHLibrary.Close All Connections    RequestsLibrary.Delete All Sessions

*** Test Cases ***
Record Timestamp
    [Documentation]    This script simply outputs a timestamp to the console, log file, 
    ...    plain text output file and API output dictionary
    ${timestamp}   Get Current Date
    Log    Test started at ${timestamp}
    Log To Console    Test started at ${timestamp}
    Append to API Output    test_start_time    ${timestamp}
    Create File    ${OUTPUT_DIR}/${status_output_file_name}   Test started at ${timestamp}\n
    
Check for Required Variables
    [Documentation]    Ensures that all required variables are present and contain data
    [Tags]    critical
    TRY
        Should Not Be Empty    ${bigip_host}
        Should Not Be Empty    ${bigip_username}
        Should Not Be Empty    ${bigip_password}
    EXCEPT
        Fatal Error
    END

Verify SSH Connectivity
    [Documentation]    Logs into the BIG-IP via SSH, executes a BASH command and validates the expected response
    [Teardown]    Run Keywords    SSHLibrary.Close All Connections
    [Tags]    critical
    TRY
        # Use the SSH Library to connect to the host
        SSHLibrary.Open Connection    ${bigip_host}
        # Log in and note the returned prompt 
        ${SSHLoginOutput}   SSHLibrary.Log In    ${bigip_username}   ${bigip_password}
        # Verify that the prompt includes (tmos)# for tmsh or the default bash prompt
        Should Contain Any    ${SSHLoginOutput}   (tmos)#    ] ~ #
    EXCEPT
        Log    Could not connect to SSH
        Append to API Output    ssh_connectivity    ${False}
        Append to Status File    SSH Connecitivity: Failed
        Fatal Error
    ELSE
        Log    Successfully connected to SSH
        Append to API Output    ssh_connectivity    ${True}
        Append to file    ${OUTPUT_DIR}/${status_output_file_name}    SSH Connecitivity: Succeeded
    END

Verify Remote Host is a BIG-IP via SSH
    [Documentation]    This test will run a command via SSH to verify that the remote host is
    ...                a BIG-IP device.
    [Teardown]    Run Keywords    SSHLibrary.Close All Connections    
    ...    AND    Run Keyword If Test Failed    Fatal Error    FATAL_ERROR: Aborting as endpoint is not a BIG-IP device!
    [Tags]    critical    
    SSHLibrary.Open Connection    ${bigip_host}
    SSHLibrary.Log In    ${bigip_username}   ${bigip_password}
    ${retrieved_show_sys_hardware_tmsh}   SSHLibrary.Execute Command    bash -c 'tmsh show sys hardware'
    Should Contain    ${retrieved_show_sys_hardware_tmsh}   BIG-IP
    Append to file    ${OUTPUT_DIR}/${status_output_file_name}    System Hardware:${retrieved_show_sys_hardware_tmsh}

Test IPv4 iControlREST API Connectivity
    [Documentation]    Tests BIG-IP iControl REST API connectivity using basic authentication
    [Tags]    critical    
    TRY
        Wait until Keyword Succeeds    6x    5 seconds    Retrieve BIG-IP TMOS Version via iControl REST    ${bigip_host}   ${bigip_username}   ${bigip_password}
    EXCEPT
        Append to file    ${OUTPUT_DIR}/${status_output_file_name}    Fatal error: API connectivity failed
        Append to API Output    error    API connectivity failed
        Log    Fatal error: API connectivity failed
        Log To Console    Fatal error: API connectivity failed
        Fatal Error    No connectivity to device via iControl REST API: Host: ${bigip_host} with user '${bigip_username}'
    ELSE
        Log    Successfully connected to iControl REST API
        Append to API Output    api_connectivity    ${True}
        Append to file    ${OUTPUT_DIR}/${status_output_file_name}    API Connecitivity: Succeeded
    END

Verify Remote Host is a BIG-IP via iControl REST
    [Documentation]    This test will query the iControl REST API to ensure the remote endpoint is
    ...                a BIG-IP device.
    [Teardown]    Run Keyword If Test Failed    Fatal Error    FATAL_ERROR: Aborting as endpoint is not a BIG-IP device!
    [Tags]    critical    
    ${retrieved_sys_hardware_api}   Retrieve BIG-IP Hardware Information    bigip_host=${bigip_host}   bigip_username=${bigip_username}   bigip_password=${bigip_password}
    Should contain    ${retrieved_sys_hardware_api.text}   BIG-IP
    Append to API Output    sys_hardware_api    ${retrieved_sys_hardware_api}

Check BIG-IP for Excessive CPU/Memory Utilization    
    [Documentation]    Verifies that resource utilization on the BIG-IP isn't critical and stops all testing if robot tests could cause impact
    [Tags]    critical    
    # Retrieve the desired data via API; returned in JSON format
    ${system_performance_api}   Retrieve BIG-IP System Performance via iControl REST    bigip_host=${bigip_host}   bigip_username=${bigip_username}   bigip_password=${bigip_password}
    ${system_performance_tmsh}   Retrieve BIG-IP System Performance via SSH    bigip_host=${bigip_host}   bigip_username=${bigip_username}   bigip_password=${bigip_password}
    Dictionary should contain item    ${system_performance_api.json()}    kind    tm:sys:performance:all-stats:all-statsstats
    ${system_performance_stats}    Get from dictionary    ${system_performance_api.json()}    entries
    ${utilization_avg}    Set variable    ${system_performance_stats}[https://localhost/mgmt/tm/sys/performance/all-stats/Utilization][nestedStats][entries][Average][description]
    ${other_mem_used_avg}    Set variable    ${system_performance_stats}[https://localhost/mgmt/tm/sys/performance/all-stats/Other%20Memory%20Used][nestedStats][entries][Average][description]
    ${tmm_mem_used_avg}    Set variable    ${system_performance_stats}[https://localhost/mgmt/tm/sys/performance/all-stats/TMM%20Memory%20Used][nestedStats][entries][Average][description]
    ${swap_used_avg}    Set variable    ${system_performance_stats}[https://localhost/mgmt/tm/sys/performance/all-stats/Swap%20Used][nestedStats][entries][Average][description]
    Append to API Output    system_performance_all_stats    ${system_performance_api.json()}
    Append to Statistics File    System Performance All Statistics:${system_performance_tmsh}
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
        Log to Console    Swap space in use on device! This is a red flag! See https://my.f5.com/manage/s/article/K55227819
        Log    Swap space in use on device! This is a red flag! See https://my.f5.com/manage/s/article/K55227819
    END

Retrieve BIG-IP CPU Statistics
    [Documentation]    Retrieves the CPU utilization from the BIG-IP (https://my.f5.com/manage/s/article/K05501591)
    # Retrieve desired information via iControl REST
    ${retrieved_cpu_stats_api}   Retrieve BIG-IP CPU Statistics via iControl REST    bigip_host=${bigip_host}   bigip_username=${bigip_username}   bigip_password=${bigip_password}
    ${retrieved_cpu_stats_tmsh}   Retrieve BIG-IP CPU Statistics via SSH    bigip_host=${bigip_host}   bigip_username=${bigip_username}   bigip_password=${bigip_password}
    Append to API Output    retrieved_cpu_stats_api    ${retrieved_cpu_stats_api}
    Append to file    ${OUTPUT_DIR}/${statistics_output_file_name}    *** CPU Statistics:\n${retrieved_cpu_stats_tmsh}

Retrieve BIG-IP Hostname
    [Documentation]    Retrieves the configured hostname on the BIG-IP
    ${retrieved_hostname_api}   Retrieve BIG-IP Hostname via iControl REST    bigip_host=${bigip_host}   bigip_username=${bigip_username}   bigip_password=${bigip_password}
    ${retrieved_hostname_tmsh}   Retrieve BIG-IP Hostname via SSH    bigip_host=${bigip_host}   bigip_username=${bigip_username}   bigip_password=${bigip_password}
    Append to API Output    hostname    ${retrieved_hostname_api}
    Append to file    ${OUTPUT_DIR}/${status_output_file_name}    *** Hostname: ${retrieved_hostname_tmsh}

Retrieve BIG-IP License Information
    [Documentation]    Retrieves the license information from the BIG-IP
    ${retrieved_license_api}   Retrieve BIG-IP License Information via iControl REST    bigip_host=${bigip_host}   bigip_username=${bigip_username}   bigip_password=${bigip_password}
    ${retrieved_license_tmsh}   Retrieve BIG-IP License Information via SSH    bigip_host=${bigip_host}   bigip_username=${bigip_username}   bigip_password=${bigip_password}
    Should not contain    ${retrieved_license_tmsh}    Can't load license, may not be operational
    Dictionary should not contain key    ${retrieved_license_api.json()}    apiRawValues
    ${service_check_date}    Set variable    ${retrieved_license_api.json()}[entries][https://localhost/mgmt/tm/sys/license/0][nestedStats][entries][serviceCheckDate]
    ${current_date}    Get current date    date_format=%Y/%m/%d
    ${days_until_service_check_date}    Subtract date from date    ${service_check_date}    ${current_date}
    log to console    ${days_until_service_check_date}
    Append to API Output    license    ${retrieved_license_api}
    Append to file    ${OUTPUT_DIR}/${status_output_file_name}    *** License: ${retrieved_license_tmsh}

Retrieve BIG-IP TMOS Version
    [Documentation]    Retrieves the current TMOS version of the device 
    ${retrieved_version_api}   Retrieve BIG-IP TMOS Version via iControl REST    bigip_host=${bigip_host}   bigip_username=${bigip_username}   bigip_password=${bigip_password}
    ${retrieved_version_tmsh}   Retrieve BIG-IP TMOS Version via SSH    bigip_host=${bigip_host}   bigip_username=${bigip_username}   bigip_password=${bigip_password}
    Append to API Output    version    ${retrieved_version_api}
    Append to file    ${OUTPUT_DIR}/${status_output_file_name}    BIG-IP Version: ${retrieved_version_tmsh}

Retrieve BIG-IP NTP Configuration and Verify NTP Servers are Configured
    [Documentation]    Retrieves the NTP Configuration on the BIG-IP (https://my.f5.com/manage/s/article/K13380)
    ${retrieved_ntp_config_api}   Retrieve BIG-IP NTP Configuration via iControl REST        bigip_host=${bigip_host}   bigip_username=${bigip_username}   bigip_password=${bigip_password}
    Dictionary Should Contain Key    ${retrieved_ntp_config_api.json()}   servers
    ${retrieved_ntp_config_tmsh}   Retrieve BIG-IP NTP Configuration via SSH        bigip_host=${bigip_host}   bigip_username=${bigip_username}   bigip_password=${bigip_password}
    Should Not Contain    ${retrieved_ntp_config_tmsh}   servers none

Retrieve and Verify BIG-IP NTP Status
    [Documentation]    Retrieves the NTP status on the BIG-IP (https://my.f5.com/manage/s/article/K10240)
    ${retrieved_ntp_status_tmsh}   Retrieve BIG-IP NTP Status via SSH    bigip_host=${bigip_host}   bigip_username=${bigip_username}   bigip_password=${bigip_password}
    Verify BIG-IP NTP Server Associations    ${retrieved_ntp_status_tmsh}
    Append to API Output    ntp-status    ${retrieved_ntp_status_tmsh}
    Append to file    ${OUTPUT_DIR}/${status_output_file_name}    *** NTP Status: ${retrieved_ntp_status_tmsh}

Retrieve BIG-IP Disk Space Utilization
    Set log level    trace
    [Documentation]

Retrieve BIG-IP Provisioned Software Modules
    [Documentation]
    Set log level    trace

List All System Database Variables
    Set log level    trace
    [Documentation]

Retrieve BIG-IP High Availability Configuration
    Set log level    trace
    [Documentation]

Retrieve BIG-IP SSL Certificate Metadata
    [Documentation]
    Set log level    trace

Retrieve BIG-IP Interface Configuration
    [Documentation]
    Set log level    trace

Retrieve BIG-IP Interface Statistics
    [Documentation]
    Set log level    trace

Retrieve BIG-IP VLAN Configuration
    [Documentation]
    Set log level    trace

Retrieve BIG-IP VLAN Statistics
    [Documentation]
    Set log level    trace

Retrieve Route Domain Information
    [Documentation]
    Set log level    trace

Retrieve BIG-IP Authentication Partition Information
    [Documentation]
    Set log level    trace

Retrieve BIG-IP Trunk Configuration
    [Documentation]
    Set log level    trace

Retrieve BIG-IP Trunk Statistics
    [Documentation]
    Set log level    trace

Retrieve Self-IP Configuration
    [Documentation]
    Set log level    trace

Retrieve BIG-IP Self-IP Statistics
    [Documentation]
    Set log level    trace

Retrieve BIG-IP Static Route Configuration
    [Documentation]
    Set log level    trace

Retrieve BIG-IP Dynamic Route Configuration
    [Documentation]
    Set log level    trace

Retrieve BIG-IP Dynamic Route Status
    [Documentation]
    Set log level    trace

Retrieve BIG-IP Virtual Server Configuration
    [Documentation]
    Set log level    trace

Retrieve BIG-IP Virtual Server Statistics
    [Documentation]
    Set log level    trace
    
Retrieve BIG-IP Pool Configuration
    [Documentation]
    Set log level    trace

Retrieve Pool Statistics
    [Documentation]
    Set log level    trace

Retrieve BIG-IP Policy Configuration
    [Documentation]
    Set log level    trace
Retrieve BIG-IP Monitor Configuration
    [Documentation]
    Set log level    trace

Retrieve BIG-IP SNAT Configuration
    [Documentation]
    Set log level    trace

Retrieve BIG-IP Full Text Configuration via SSH
    [Documentation]    Retrieve BIG-IPs the full BIG-IP configuration via list output
    [Teardown]    Run Keywords    SSHLibrary.Close All Connections    RequestsLibrary.Delete All Sessions
    SSHLibrary.Open connection    ${bigip_host}
    SSHLibrary.Login    username=${bigip_username}    password=${bigip_password}
    ${full_text_configuration}    SSHLibrary.Execute command    bash -c 'tmsh -q list / all-properties one-line recursive'
    Create File    ${OUTPUT_DIR}/${configuration_file_name}   Full Text Configuration:\n${full_text_configuration}

Log API Responses in JSON
    [Documentation]    Creating a plain text block that can be diff'd between runs to view changes
    Log Dictionary   ${api_info_block}

