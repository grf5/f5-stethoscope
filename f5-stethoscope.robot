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
Resource           f5-stethoscope.robot
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
    ${timestamp}    Get Current Date
    Log    First test started at ${timestamp}
    Log To Console    First test started at ${timestamp}
    Append to API Output    first_test_start_time    ${timestamp}
    Create File    ${OUTPUT_DIR}/${text_output_file_name}    First test started at ${timestamp}\n
    
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
    TRY
        # Use the SSH Library to connect to the host
        SSHLibrary.Open Connection    ${bigip_host}
        # Log in and note the returned prompt 
        ${SSHLoginOutput}    SSHLibrary.Log In    ${bigip_username}    ${bigip_password}
        # Verify that the prompt includes (tmos)# for tmsh or the default bash prompt
        Should Contain Any    ${SSHLoginOutput}    (tmos)#    ] ~ #
    EXCEPT
        Log    Could not connect to SSH
        Append to API Output    ssh_connectivity    ${False}
        Append to Text Output    SSH Connecitivity: Failed
        Set Global Variable    ${ssh_reachable}    ${False}
    ELSE
        Log    Successfully connected to SSH
        Append to API Output    ssh_connectivity    ${True}
        Append to Text Output    SSH Connecitivity: Succeeded
        Set Global Variable    ${ssh_reachable}    ${True}
    END

Verify Remote Host is a BIG-IP via SSH
    [Documentation]    This test will run a command via SSH to verify that the remote host is
    ...                a BIG-IP device.
    [Teardown]    Run Keywords    SSHLibrary.Close All Connections    
    ...    AND    Run Keyword If Test Failed    Fatal Error    FATAL_ERROR: Aborting as endpoint is not a BIG-IP device!
    Skip If    ${ssh_reachable} == ${False}    SSH is not reachable.
    SSHLibrary.Open Connection    ${bigip_host}
    SSHLibrary.Log In    ${bigip_username}    ${bigip_password}
    ${retrieved_show_sys_hardware_tmsh}    SSHLibrary.Execute Command    bash -c 'tmsh show sys hardware'
    Should Contain    ${retrieved_show_sys_hardware_tmsh}    BIG-IP

Test IPv4 iControlREST API Connectivity
    [Documentation]    Tests BIG-IP iControl REST API connectivity using basic authentication
    TRY
        Wait until Keyword Succeeds    6x    5 seconds    Retrieve BIG-IP TMOS Version via iControl REST    ${bigip_host}    ${bigip_username}    ${bigip_password}
    EXCEPT
        Log    Could not connect to iControl REST
        Append to API Output    api_connectivity    ${False}
        Append to Text Output    API Connecitivity: Failed
        Set Global Variable    ${api_reachable}    ${False}
    ELSE
        Log    Successfully connected to iControl REST API
        Append to API Output    api_connectivity    ${True}
        Append to Text Output    API Connecitivity: Succeeded
        Set Global Variable    ${api_reachable}    ${True}
    END

Verify Remote Host is a BIG-IP via iControl REST
    [Documentation]    This test will query the iControl REST API to ensure the remote endpoint is
    ...                a BIG-IP device.
    [Teardown]    Run Keyword If Test Failed    Fatal Error    FATAL_ERROR: Aborting as endpoint is not a BIG-IP device!
    Skip If    ${api_reachable} == ${False}    API is not reachable.
    ${retrieved_sys_hardware_api}    Retrieve BIG-IP Hardware Information    bigip_host=${bigip_host}    bigip_username=${bigip_username}    bigip_password=${bigip_password}
    Should contain    ${retrieved_sys_hardware_api.text}    BIG-IP

Verify Connectivity Availability
    [Documentation]    Ensure that either SSH or REST is available
    IF    ${api_reachable} == ${False} and ${ssh_reachable} == ${False}
        Append to Text Output    Fatal error: No SSH or API Connectivity succeeded
        Append to API Output    fatal_error    No SSH or API Connectivity succeeded
        Log    Fatal error: No SSH or API Connectivity succeeded
        Log To Console    Fatal error: No SSH or API Connectivity succeeded
        Fatal Error    No connectivity to device via SSH or iControl REST API: Host: ${bigip_host} with user '${bigip_username}'
    END

Retrieve BIG-IP CPU Statistics
    [Documentation]    Retrieves the CPU utilization from the BIG-IP
    IF    ${api_reachable} == ${True}
        ${retrieved_cpu_stats_api}    Retrieve BIG-IP CPU Statistics via iControl REST    bigip_host=${bigip_host}    bigip_username=${bigip_username}    bigip_password=${bigip_password}
        ${retrieved_cpu_stats_tmsh}    Run BASH Command on BIG-IP    bigip_host=${bigip_host}    bigip_username=${bigip_username}    bigip_password=${bigip_password}    command=bash -c 'tmsh show sys cpu all'
    ELSE IF   ${ssh_reachable} == ${True}        
        ${retrieved_cpu_stats_api}    Curl iControl REST via SSH    bigip_host=${bigip_host}    bigip_username=${bigip_username}    bigip_password=${bigip_password}    uri='/mgmt/tm/sys/cpu/stats'
        ${retrieved_cpu_stats_tmsh}    Retrieve BIG-IP CPU Statistics via SSH    bigip_host=${bigip_host}    bigip_username=${bigip_username}    bigip_password=${bigip_password}
    END
    Append to API Output    retrieved_cpu_stats_api    ${retrieved_cpu_stats_api}
    Append to API Output    retrieved_cpu_stats_tmsh    ${retrieved_cpu_stats_tmsh}
    Append to Text Output    CPU Statistics:\n${retrieved_cpu_stats_tmsh}

Retrieve BIG-IP Current Memory Utilization
    [Documentation]
    Set Global Variable    ${retrieved_mem_stats_api}
    Set Global Variable    ${retrieved_mem_stats_tmsh}
    IF    ${api_reachable} == ${True}
        Log    Placeholder
    END
    IF   ${ssh_reachable} == ${True}
        Log    Placeholder
    END

Retrieve BIG-IP Hostname
    [Documentation]    Retrieves the configured hostname on the BIG-IP
    IF    ${api_reachable} == ${True}
        ${retrieved_hostname_api}    Retrieve BIG-IP Hostname via iControl REST    bigip_host=${bigip_host}    bigip_username=${bigip_username}    bigip_password=${bigip_password}
        Append to API Output    hostname    ${retrieved_hostname_api}
    END
    IF   ${ssh_reachable} == ${True}
        ${retrieved_hostname_tmsh}    Retrieve BIG-IP Hostname via SSH    bigip_host=${bigip_host}    bigip_username=${bigip_username}    bigip_password=${bigip_password}
        Append to Text Output    Hostname: ${retrieved_hostname_tmsh}
    END

Retrieve BIG-IP License Information
    [Documentation]    Retrieves the license information from the BIG-IP
    IF    ${api_reachable} == ${True}
        ${retrieved_license_api}    Retrieve BIG-IP License Information via iControl REST    bigip_host=${bigip_host}    bigip_username=${bigip_username}    bigip_password=${bigip_password}
        Append to API Output    license    ${retrieved_license_api}
    END
    IF   ${ssh_reachable} == ${True}
        ${retrieved_license_tmsh}    Retrieve BIG-IP License Information via SSH    bigip_host=${bigip_host}    bigip_username=${bigip_username}    bigip_password=${bigip_password}
        Append to Text Output    License: ${retrieved_license_tmsh}
    END

Retrieve BIG-IP TMOS Version
    [Documentation]    Retrieves the current TMOS version of the device 
    IF    ${api_reachable} == ${True}
        ${retrieved_version_api}    Retrieve BIG-IP TMOS Version via iControl REST    bigip_host=${bigip_host}    bigip_username=${bigip_username}    bigip_password=${bigip_password}
        Append to API Output    version    ${retrieved_version_api}
    END
    IF   ${ssh_reachable} == ${True}
        ${retrieved_version_tmsh}    Retrieve BIG-IP TMOS Version via SSH    bigip_host=${bigip_host}    bigip_username=${bigip_username}    bigip_password=${bigip_password}
        Append to Text Output    BIG-IP Version: ${retrieved_version_tmsh}
    END

Retrieve BIG-IP NTP Configuration and Verify NTP Servers are Configured
    [Documentation]    Retrieves the NTP Configuration on the BIG-IP (https://my.f5.com/manage/s/article/K13380)
    IF    ${api_reachable} == ${True}
        ${retrieved_ntp_config_api}    Retrieve BIG-IP NTP Configuration via iControl REST        bigip_host=${bigip_host}    bigip_username=${bigip_username}    bigip_password=${bigip_password}
        Append to API Output    ntp-config    ${retrieved_ntp_config_api}
        Dictionary Should Contain Key    ${retrieved_ntp_config_api}    servers
    END
    IF   ${ssh_reachable} == ${True}
        ${retrieved_ntp_config_tmsh}    Retrieve BIG-IP NTP Configuration via SSH        bigip_host=${bigip_host}    bigip_username=${bigip_username}    bigip_password=${bigip_password}
        Append to Text Output    NTP Configuration: ${retrieved_ntp_config_tmsh}
        Should Not Contain    ${retrieved_ntp_config_tmsh}    servers none
    END

Retrieve and Verify BIG-IP NTP Status
    [Documentation]    Retrieves the NTP status on the BIG-IP (https://my.f5.com/manage/s/article/K10240)
    IF    ${api_reachable} == ${True}
        ${retrieved_ntp_status_api}    Retrieve BIG-IP NTP Status via iControl REST    bigip_host=${bigip_host}    bigip_username=${bigip_username}    bigip_password=${bigip_password}
        Verify BIG-IP NTP Server Associations    ${retrieved_ntp_status_api}
        Append to API Output    ntp-status    ${retrieved_ntp_status_api}
    END
    IF   ${ssh_reachable} == ${True}
        ${retrieved_ntp_status_tmsh}    Retrieve BIG-IP NTP Status via SSH    bigip_host=${bigip_host}    bigip_username=${bigip_username}    bigip_password=${bigip_password}
        Verify BIG-IP NTP Server Associations    ${retrieved_ntp_status_tmsh}
        Append to Text Output    NTP Status: ${retrieved_ntp_status_tmsh}
    END

Retrieve BIG-IP Disk Space Utilization
    [Documentation]
    Set Global Variable    ${retrieved_disk_stats_api}
    Set Global Variable    ${retrieved_disk_stats_tmsh}
    IF    ${api_reachable} == ${True}
        Log    Placeholder
    END
    IF   ${ssh_reachable} == ${True}
        Log    Placeholder
    END

Retrieve BIG-IP Provisioned Software Modules
    [Documentation]
    Set Global Variable    ${retrieved_provisioning_api}
    Set Global Variable    ${retrieved_provisioning_tmsh}
    IF    ${api_reachable} == ${True}
        Log    Placeholder
    END
    IF   ${ssh_reachable} == ${True}
        Log    Placeholder
    END

List All System Database Variables
    [Documentation]
    Set Global Variable    ${retrieved_db_vars_api}
    Set Global Variable    ${retrieved_db_vars_tmsh}
    IF    ${api_reachable} == ${True}
        Log    Placeholder
    END
    IF   ${ssh_reachable} == ${True}
        Log    Placeholder
    END

Retrieve BIG-IP High Availability Configuration
    [Documentation]
    Set Global Variable    ${retrieved_ha_config_api}
    Set Global Variable    ${retrieved_ha_config_tmsh}
    IF    ${api_reachable} == ${True}
        Log    Placeholder
    END
    IF   ${ssh_reachable} == ${True}
        Log    Placeholder
    END

Retrieve BIG-IP SSL Certificate Metadata
    [Documentation]
    Set Global Variable    ${retrieved_ssl_certs_api}
    Set Global Variable    ${retrieved_ssl_certs_tmsh}
    IF    ${api_reachable} == ${True}
        Log    Placeholder
    END
    IF   ${ssh_reachable} == ${True}
        Log    Placeholder
    END

Retrieve BIG-IP Interface Configuration
    [Documentation]
    Set Global Variable    ${retrieved_int_config_api}
    Set Global Variable    ${retrieved_int_config_tmsh}
    IF    ${api_reachable} == ${True}
        Log    Placeholder
    END
    IF   ${ssh_reachable} == ${True}
        Log    Placeholder
    END

Retrieve BIG-IP Interface Statistics
    [Documentation]
    Set Global Variable    ${retrieved_int_stats_api}
    Set Global Variable    ${retrieved_int_stats_tmsh}
    IF    ${api_reachable} == ${True}
        Log    Placeholder
    END
    IF   ${ssh_reachable} == ${True}
        Log    Placeholder
    END

Retrieve BIG-IP VLAN Configuration
    [Documentation]
    Set Global Variable    ${retrieved_vlan_config_api}
    Set Global Variable    ${retrieved_vlan_config_tmsh}
    IF    ${api_reachable} == ${True}
        Log    Placeholder
    END
    IF   ${ssh_reachable} == ${True}
        Log    Placeholder
    END

Retrieve BIG-IP VLAN Statistics
    [Documentation]
    Set Global Variable    ${retrieved_vlan_stats_api}
    Set Global Variable    ${retrieved_vlan_stats_tmsh}
    IF    ${api_reachable} == ${True}
        Log    Placeholder
    END
    IF   ${ssh_reachable} == ${True}
        Log    Placeholder
    END

Retrieve Route Domain Information
    [Documentation]
    Set Global Variable    ${retrieved_route_domain_config_api}
    Set Global Variable    ${retrieved_route_domain_config_tmsh}
    IF    ${api_reachable} == ${True}
        Log    Placeholder
    END
    IF   ${ssh_reachable} == ${True}
        Log    Placeholder
    END

Retrieve BIG-IP Authentication Partition Information
    [Documentation]
    Set Global Variable    ${retrieved_part_config_api}
    Set Global Variable    ${retrieved_part_config_tmsh}
    IF    ${api_reachable} == ${True}
        Log    Placeholder
    END
    IF   ${ssh_reachable} == ${True}
        Log    Placeholder
    END

Retrieve BIG-IP Trunk Configuration
    [Documentation]
    Set Global Variable    ${retrieved_trunk_config_api}
    Set Global Variable    ${retrieved_trunk_config_tmsh}
    IF    ${api_reachable} == ${True}
        Log    Placeholder
    END
    IF   ${ssh_reachable} == ${True}
        Log    Placeholder
    END

Retrieve BIG-IP Trunk Statistics
    [Documentation]
    Set Global Variable    ${retrieved_trunk_stats_api}
    Set Global Variable    ${retrieved_trunk_stats_tmsh}
    IF    ${api_reachable} == ${True}
        Log    Placeholder
    END
    IF   ${ssh_reachable} == ${True}
        Log    Placeholder
    END

Retrieve Self-IP Configuration
    [Documentation]
    IF    ${api_reachable} == ${True}
        Log    Placeholder
        Set Global Variable    ${retrieved_selfip_config_api}
    END
    IF   ${ssh_reachable} == ${True}
        Log    Placeholder
        Set Global Variable    ${retrieved_selfip_config_tmsh}
    END

Retrieve BIG-IP Self-IP Statistics
    [Documentation]
    IF    ${api_reachable} == ${True}
        Log    Placeholder
        Set Global Variable    ${retrieved_selfip_stats_api}
    END
    IF   ${ssh_reachable} == ${True}
        Log    Placeholder
        Set Global Variable    ${retrieved_selfip_stats_tmsh}
    END

Retrieve BIG-IP Static Route Configuration
    [Documentation]
    Set Global Variable    ${retrieved_static_routing_config_api}
    Set Global Variable    ${retrieved_static_routing_config_tmsh}
    IF    ${api_reachable} == ${True}
        Log    Placeholder
    END
    IF   ${ssh_reachable} == ${True}
        Log    Placeholder
    END

Retrieve BIG-IP Dynamic Route Configuration
    [Documentation]
    Set Global Variable    ${retrieved_dynamic_routing_config_api}
    Set Global Variable    ${retrieved_dynamic_routing_config_tmsh}
    IF    ${api_reachable} == ${True}
        Log    Placeholder
    END
    IF   ${ssh_reachable} == ${True}
        Log    Placeholder
    END

Retrieve BIG-IP Dynamic Route Status
    [Documentation]
    Set Global Variable    ${retrieved_dynamic_routing_status_api}
    Set Global Variable    ${retrieved_dynamic_routing_status_tmsh}
    IF    ${api_reachable} == ${True}
        Log    Placeholder
    END
    IF   ${ssh_reachable} == ${True}
        Log    Placeholder
    END

Retrieve BIG-IP Virtual Server Configuration
    [Documentation]
    Set Global Variable    ${retrieved_virtual_config_api}
    Set Global Variable    ${retrieved_virtual_config_tmsh}
    IF    ${api_reachable} == ${True}
        Log    Placeholder
    END
    IF   ${ssh_reachable} == ${True}
        Log    Placeholder
    END

Retrieve BIG-IP Virtual Server Statistics
    [Documentation]
    Set Global Variable    ${retrieved_virtual_stats_api}
    Set Global Variable    ${retrieved_virtual_stats_tmsh}
    IF    ${api_reachable} == ${True}
        Log    Placeholder
    END
    IF   ${ssh_reachable} == ${True}
        Log    Placeholder
    END
    
Retrieve BIG-IP Pool Configuration
    [Documentation]
    Set Global Variable    ${retrieved_pool_config_api}
    Set Global Variable    ${retrieved_pool_config_tmsh}
    IF    ${api_reachable} == ${True}
        Log    Placeholder
    END
    IF   ${ssh_reachable} == ${True}
        Log    Placeholder
    END

Retrieve Pool Statistics
    [Documentation]
    Set Global Variable    ${retrieved_pool_stats_api}
    Set Global Variable    ${retrieved_pool_stats_tmsh}
    IF    ${api_reachable} == ${True}
        Log    Placeholder
    END
    IF   ${ssh_reachable} == ${True}
        Log    Placeholder
    END

Retrieve BIG-IP Policy Configuration
    [Documentation]
    Set Global Variable    ${retrieved_policy_config_api}
    Set Global Variable    ${retrieved_policy_config_tmsh}
    IF    ${api_reachable} == ${True}
        Log    Placeholder
    END
    IF   ${ssh_reachable} == ${True}
        Log    Placeholder
    END

Retrieve BIG-IP Monitor Configuration
    [Documentation]
    Set Global Variable    ${retrieved_monitor_config_api}
    Set Global Variable    ${retrieved_monitor_config_tmsh}
    IF    ${api_reachable} == ${True}
        Log    Placeholder
    END
    IF   ${ssh_reachable} == ${True}
        Log    Placeholder
    END

Retrieve BIG-IP SNAT Configuration
    [Documentation]
    Set Global Variable    ${retrieved_snat_config_api}
    Set Global Variable    ${retrieved_snat_config_tmsh}
    IF    ${api_reachable} == ${True}
        Log    Placeholder
    END
    IF   ${ssh_reachable} == ${True}
        Log    Placeholder
    END

Retrieve BIG-IP Full Text Configuration
    [Documentation]    Retrieve BIG-IPs the full BIG-IP configuration via list output
    [Teardown]    Run Keywords    SSHLibrary.Close All Connections    RequestsLibrary.Delete All Sessions
    IF    ${api_reachable} == ${True}
        ${full_text_configuration}    Run BASH Command on BIG-IP    bigip_host=${bigip_host}    bigip_username=${bigip_username}    bigip_password=${bigip_password}    command=list / one-line all-properties recursive
        Append to Text Output    Output of "ls / one-line recursive all-properites":\n${full_text_configuration}
        Append to API Output    Full Text Configuration:    ${full_text_configuration}
    END
    IF   ${ssh_reachable} == ${True}
        SSHLibrary.Open Connection    ${bigip_host}
        SSHLibrary.Login    ${bigip_username}    ${bigip_password}
        ${full_text_configuration}    Execute Command    list / one-line all-properties recursive
        Append to Text Output    Output of "ls / one-line recursive all-properites":\n${full_text_configuration}
        Append to API Output    Full Text Configuration:    ${full_text_configuration}
    END

Log API Responses in JSON
    [Documentation]    Creating a plain text block that can be diff'd between runs to view changes
    IF    ${api_reachable} == ${True}
        Log Dictionary   ${api_info_block}
    END

Record Text Output from Tests
    [Documentation]    Displays the contents of the plain text file output
    TRY
        OperatingSystem.Get File    ${OUTPUT_DIR}/${text_output_file_name}
    EXCEPT    message
        Log    Could not retrieve text file output        
    END
*** Keywords ***
Append to API Output
    [Documentation]    Builds the JSON output block for API information
    [Arguments]    ${key}    ${value}
    Set To Dictionary    ${api_info_block}    ${key}    ${value}
    [Return]

Append to Text Output
    [Documentation]    Builds the plain text output for SSH information
    [Arguments]    ${text}
    Append to File    ${OUTPUT_DIR}/${text_output_file_name}    ${text}\n
    [Return]

BIG-IP iControl BasicAuth GET    
    [Documentation]    Performs an iControl REST API GET call using basic auth (See pages 25-38 of https://cdn.f5.com/websites/devcentral.f5.com/downloads/icontrol-rest-api-user-guide-13-1-0-a.pdf.zip)
    [Arguments]    ${bigip_host}    ${bigip_username}    ${bigip_password}    ${api_uri}
    [Teardown]    RequestsLibrary.Delete All Sessions
    ${api_auth}    Create List    ${bigip_username}   ${bigip_password}
    RequestsLibrary.Create Session    bigip-icontrol-get-basicauth    https://${bigip_host}    auth=${api_auth}
    &{api_headers}    Create Dictionary    Content-type=application/json
    ${api_response}    GET On Session    bigip-icontrol-get-basicauth   ${api_uri}    headers=${api_headers}
    [Return]    ${api_response}

Retrieve BIG-IP TMOS Version via iControl REST
    [Documentation]    Retrieves the current version of software running on the BIG-IP (https://support.f5.com/csp/article/K8759)
    [Arguments]    ${bigip_host}   ${bigip_username}   ${bigip_password}
    ${api_uri}    set variable    /mgmt/tm/sys/version
    ${api_response}    BIG-IP iControl BasicAuth GET   bigip_host=${bigip_host}    bigip_username=${bigip_username}    bigip_password=${bigip_password}    api_uri=${api_uri}
    Should Be Equal As Strings    ${api_response.status_code}    ${200}
    [Return]    ${api_response.json()}

Retrieve BIG-IP TMOS Version via SSH
    [Documentation]    Retrieves the current version of TMOS running on the BIG-IP (https://support.f5.com/csp/article/K8759)
    [Arguments]    ${bigip_host}    ${bigip_username}    ${bigip_password}
    [Teardown]    SSHLibrary.Close Connection
    SSHLibrary.Open Connection    ${bigip_host}
    SSHLibrary.Login    ${bigip_username}    ${bigip_password}
    ${version}    SSHLibrary.Execute Command    bash -c 'tmsh show sys version'
    [Return]    ${version}

Retrieve BIG-IP License Information via iControl REST
    [Documentation]    Retrieves the current license information on the BIG-IP (https://my.f5.com/manage/s/article/K7752)
    [Arguments]    ${bigip_host}   ${bigip_username}   ${bigip_password}
    ${api_uri}    set variable    /mgmt/tm/sys/license
    ${api_response}    BIG-IP iControl BasicAuth GET   bigip_host=${bigip_host}    bigip_username=${bigip_username}    bigip_password=${bigip_password}    api_uri=${api_uri}
    Should Be Equal As Strings    ${api_response.status_code}    ${200}
    [Return]    ${api_response.json()}

Retrieve BIG-IP License Information via SSH
    [Documentation]    Retrieves the license information on the BIG-IP (https://support.f5.com/csp/article/K13369)
    [Arguments]    ${bigip_host}    ${bigip_username}    ${bigip_password}
    [Teardown]    SSHLibrary.Close Connection
    SSHLibrary.Open Connection    ${bigip_host}
    SSHLibrary.Login    ${bigip_username}    ${bigip_password}
    ${license}    SSHLibrary.Execute Command    bash -c 'tmsh show sys license'
    [Return]    ${license}

Retrieve BIG-IP Hostname via iControl REST
    [Documentation]    Retrieves the hostname on the BIG-IP (https://support.f5.com/csp/article/K13369)
    [Arguments]    ${bigip_host}    ${bigip_username}    ${bigip_password}
    ${api_uri}    set variable    /mgmt/tm/sys/global-settings
    ${api_response}    BIG-IP iControl BasicAuth GET    bigip_host=${bigip_host}    bigip_username=${bigip_username}    bigip_password=${bigip_password}    api_uri=${api_uri}
    Should Be Equal As Strings    ${api_response.status_code}    ${200}
    ${configured_hostname}    get from dictionary    ${api_response.json()}    hostname
    [Return]    ${configured_hostname}

Retrieve BIG-IP Hostname via SSH
    [Documentation]    Retrieves the hostname on the BIG-IP (https://support.f5.com/csp/article/K13369)
    [Arguments]    ${bigip_host}    ${bigip_username}    ${bigip_password}
    [Teardown]    SSHLibrary.Close Connection
    SSHLibrary.Open Connection    ${bigip_host}
    SSHLibrary.Login    ${bigip_username}    ${bigip_password}
    ${hostname}    SSHLibrary.Execute Command    bash -c 'tmsh list sys global-settings hostname all-properties'
    [Return]    ${hostname}

Retrieve BIG-IP NTP Configuration via iControl REST
    [Documentation]    Retrieves the NTP configuration on the BIG-IP (https://my.f5.com/manage/s/article/K13380)
    [Arguments]    ${bigip_host}    ${bigip_username}    ${bigip_password}
    ${api_uri}    set variable    /mgmt/tm/sys/ntp
    ${api_response}    BIG-IP iControl BasicAuth GET    bigip_host=${bigip_host}    bigip_username=${bigip_username}    bigip_password=${bigip_password}    api_uri=${api_uri}
    Should Be Equal As Strings    ${api_response.status_code}    ${200}
    [Return]    ${api_response.json()}

Retrieve BIG-IP NTP Configuration via SSH
    [Documentation]    Retrieves the NTP configuration on the BIG-IP (https://my.f5.com/manage/s/article/K13380)
    [Arguments]    ${bigip_host}    ${bigip_username}    ${bigip_password}
    [Teardown]    SSHLibrary.Close Connection
    SSHLibrary.Open Connection    ${bigip_host}
    SSHLibrary.Login    ${bigip_username}    ${bigip_password}
    ${hostname}    SSHLibrary.Execute Command    bash -c 'tmsh list sys ntp all-properties'
    [Return]    ${hostname}

Run BASH Command on BIG-IP
    [Documentation]    Executes bash command on the BIG-IP via iControl REST (https://my.f5.com/manage/s/article/K13225405)
    [Arguments]    ${bigip_host}    ${bigip_username}    ${bigip_password}    ${command}
    ${api_payload}    create dictionary    command=run    utilCmdArgs=-c "${command}"
    ${api_uri}    set variable    /mgmt/tm/util/bash
    ${api_response}    BIG-IP iControl BasicAuth POST    bigip_host=${bigip_host}    bigip_username=${bigip_username}    bigip_password=${bigip_password}    api_uri=${api_uri}    api_payload=${api_payload}
    Should Be Equal As Strings    ${api_response.status_code}    ${200}
    [Return]    ${api_response}

BIG-IP iControl BasicAuth POST    
    [Documentation]    Performs an iControl REST API POST call using basic auth (See pages 39-44 of https://cdn.f5.com/websites/devcentral.f5.com/downloads/icontrol-rest-api-user-guide-13-1-0-a.pdf.zip)
    [Arguments]    ${bigip_host}    ${bigip_username}    ${bigip_password}    ${api_uri}    ${api_payload}
    [Teardown]    RequestsLibrary.Delete All Sessions
    ${api_auth}    Create List    ${bigip_username}   ${bigip_password}
    RequestsLibrary.Create Session    bigip-icontrol-post-basicauth    https://${bigip_host}		auth=${api_auth}
    &{api_headers}    Create Dictionary    Content-type=application/json
    ${api_response}    RequestsLibrary.POST On Session    bigip-icontrol-post-basicauth   ${api_uri}    headers=${api_headers}    json=${api_payload}
    [Return]    ${api_response}

Retrieve BIG-IP NTP Status via iControl REST
    [Documentation]    Retrieves the output of the ntpq command on the BIG-IP (https://my.f5.com/manage/s/article/K10240)
    [Arguments]    ${bigip_host}    ${bigip_username}    ${bigip_password}
    ${api_payload}    Create Dictionary    command    run    utilCmdArgs    -c \'ntpq -pn\'
    ${api_uri}    set variable    /mgmt/tm/util/bash
    ${api_response}    BIG-IP iControl BasicAuth POST    bigip_host=${bigip_host}  bigip_username=${bigip_username}    bigip_password=${bigip_password}    api_uri=${api_uri}    api_payload=${api_payload}
    Should Be Equal As Strings    ${api_response.status_code}    ${200}
    ${ntpq_output}    Get From Dictionary    ${api_response.json()}    commandResult
    [Return]    ${ntpq_output}

Retrieve BIG-IP NTP Status via SSH
    [Documentation]    Retrieves the output of the ntpq command on the BIG-IP (https://my.f5.com/manage/s/article/K10240)
    [Arguments]    ${bigip_host}    ${bigip_username}    ${bigip_password}
    [Teardown]    SSHLibrary.Close All Connections
    SSHLibrary.Open Connection    ${bigip_host}
    SSHLibrary.Login    ${bigip_username}    ${bigip_password}
    ${ntpq_output}    SSHLibrary.Execute Command    bash -c 'ntpq -pn'
    [Return]    ${ntpq_output}

Verify BIG-IP NTP Server Associations
    [Documentation]    Verifies that all configured NTP servers are synced (https://support.f5.com/csp/article/K13380)
    [Arguments]    ${ntpq_output}
    ${ntpq_output_start}    Set Variable    ${ntpq_output.find("===\n")}
    ${ntpq_output_clean}    Set Variable    ${ntpq_output[${ntpq_output_start}+4:]}
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
    [Return]

Retrieve BIG-IP CPU Statistics via iControl REST
    [Documentation]    Retrieves the CPU statistics from the BIG-IP using iControl REST (https://my.f5.com/manage/s/article/K15468)
    [Arguments]    ${bigip_host}    ${bigip_username}    ${bigip_password}
    ${api_uri}    set variable    /mgmt/tm/sys/cpu/stats
    ${api_response}    BIG-IP iControl BasicAuth GET    bigip_host=${bigip_host}  bigip_username=${bigip_username}    bigip_password=${bigip_password}    api_uri=${api_uri}
    Should Be Equal As Strings    ${api_response.status_code}    ${200}
    [Return]    ${api_response}

Retrieve BIG-IP CPU Statistics via SSH
    [Arguments]    ${bigip_host}    ${bigip_username}    ${bigip_password}
    [Documentation]    Retrieves the output of the ntpq command on the BIG-IP (https://my.f5.com/manage/s/article/K10240)
    [Teardown]    SSHLibrary.Close All Connections
    SSHLibrary.Open Connection    ${bigip_host}
    SSHLibrary.Login    ${bigip_username}    ${bigip_password}
    ${cpu_stats}    SSHLibrary.Execute Command    bash -c 'ntpq -pn'
    [Return]    ${cpu_stats}

Curl iControl REST via SSH
    [Documentation]    Retrieves an iControl REST API endpoint via curl task from BASH
    [Arguments]    ${bigip_host}    ${bigip_username}    ${bigip_password}    ${uri}
    ${command}    Set Variable    curl -sku ${bigip_username}:${bigip_password} https://127.0.0.1/${uri}
    ${retrieved_api_response}    Run BASH Command on BIG-IP    ${bigip_host}    ${bigip_username}    ${bigip_password}    ${command}
