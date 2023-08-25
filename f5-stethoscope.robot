*** Settings ***
Documentation        F5 stethoscope is a Robot Framework script that checks the generic health
...                  of BIG-IP devices.
...    
Library            String
Library            SSHLibrary    timeout=10 seconds    loglevel=trace
Library            RequestsLibrary
Library            Collections
Library            OperatingSystem
Suite Setup        Set Log Level    trace
Suite Teardown     Run Keywords    SSHLibrary.Close All Connections    RequestsLibrary.Delete All Sessions

*** Variables ***
# To specify the BIG-IP host from the cli, use the following syntax:
# robot f5-stethoscope.robot --host 192.168.1.1 --user admin --pass g00dgrAvy_1984$
${host}    192.168.1.245
${user}    admin
${pass}    default
${text_output_file_name}    device_info.txt
&{api_info_block}

*** Test Cases ***
Check for Required Variables
    [Documentation]    Ensures that the required variables are present
    [Tags]    critical
    TRY
        Should Not Be Empty    ${host}
        Should Not Be Empty    ${user}
        Should Not Be Empty    ${pass}
    EXCEPT
        Fatal Error
    END


Verify SSH Connectivity
    [Documentation]    Logs into the BIG-IP via SSH, executes a BASH command and validates the expected response
    TRY
        ${SSHOpenConnectionOutput}    SSHLibrary.Open Connection    ${host} 
        ${SSHLoginOutput}    SSHLibrary.Log In    ${user}    ${pass}
    EXCEPT
        Log    Could not connect to SSH
        SSHLibrary.Close All Connections
        Append to API Output    ssh_connectivity    ${False}
        Append to Text Output    SSH Connecitivity: Failed
        Set Global Variable    ${ssh_reachable}    ${False}
    ELSE
        Log    Successfully connected to SSH
        Append to API Output    ssh_connectivity    ${True}
        Append to Text Output    SSH Connecitivity: Succeeded
        Set Global Variable    ${ssh_reachable}    ${True}
    END
        Close All Connections
    # Checking to see that prompt includes (tmos)# for tmsh or the default bash prompt
    Should Contain Any    ${SSHLoginOutput}    (tmos)#    ] ~ #

Test IPv4 iControlREST API Connectivity
    [Documentation]    Tests BIG-IP iControl REST API connectivity using basic authentication
    TRY
        Wait until Keyword Succeeds    6x    5 seconds    Retrieve TMOS Version via iControl REST    bigip_host=${host}    bigip_username=${user}    bigip_password=${pass}        
    EXCEPT
        Log    Could not connect to iControl REST
        Append to API Output    api_connectivity    ${True}
        Append to Text Output    API Connecitivity: Succeeded
        Set Global Variable    ${api_reachable}    ${True}

    ELSE
        Log    Successfully connected to iControl REST API
        Append to API Output    api_connectivity    ${False}
        Append to Text Output    API Connecitivity: Failed
        Set Global Variable    ${api_reachable}    ${True}
    END

Verify Connectivty Availability
    [Documentation]    Ensure that SSH or REST is available
    IF    ${api_reachable} == ${False} and ${ssh_reachable} == ${False}
        Append to Text Output    Fatal error: No SSH or API Connectivity succeeded
        Fatal Error    No connectivity to device via SSH or iControl REST API: Host: ${host} with user '${user}'
    END

Retrieve BIG-IP Hostname
    [Documentation]    Retrieves the configured hostname on the BIG-IP
    IF    ${api_reachable} == ${True}
        ${retrieved_hostname_api}    Retrieve Hostname via iControl REST    bigip_host=${host}    bigip_username=${user}    bigip_password=${pass}
        Append to API Output    hostname    ${retrieved_hostname_api}
    END
    IF   ${ssh_reachable} == ${True}
        ${retrieved_hostname_ssh}    Retrieve Hostname via SSH    bigip_host=${host}    bigip_username=${user}    bigip_password=${pass}
        Append to Text Output    Hostname: ${retrieved_hostname_ssh}
    END

Retrieve BIG-IP License Information
    [Documentation]    Retrieves the license information from the BIG-IP
    IF    ${api_reachable} == ${True}
        ${retrieved_license_api}    Retrieve License Information via iControl REST    bigip_host=${host}    bigip_username=${user}    bigip_password=${pass}
        Append to API Output    license    ${retrieved_license_api}
    END
    IF   ${ssh_reachable} == ${True}
        ${retrieved_license_ssh}    Retrieve License Information via SSH    bigip_host=${host}    bigip_username=${user}    bigip_password=${pass}
        Append to Text Output    License: ${retrieved_license_ssh}
    END

Retrieve BIG-IP TMOS Version
    [Documentation]    Retrieves the current TMOS version of the device 
    IF    ${api_reachable} == ${True}
        ${retrieved_version_api}    Retrieve TMOS Version via iControl REST    bigip_host=${host}    bigip_username=${user}    bigip_password=${pass}
        Append to API Output    version    ${retrieved_version_api}
    END
    IF   ${ssh_reachable} == ${True}
        ${retrieved_version_ssh}    Retrieve TMOS Version via SSH    bigip_host=${host}    bigip_username=${user}    bigip_password=${pass}
        Append to Text Output    BIG-IP Version: ${Retrieve BIG-IPd_version_ssh}
    END

Retrieve BIG-IP NTP Configuration
    [Documentation]
    IF    ${api_reachable} == ${True}
        ${retrieved_ntp_config_api}    Retreive BIG-IP NT
    END
    IF   ${ssh_reachable} == ${True}
        Log    Placeholder
    END

Verify NTP Status
    [Documentation]
    Set Global Variable    ${retrieved_ntp_status_api}
    Set Global Variable    ${retrieved_ntp_status_ssh}
    IF    ${api_reachable} == ${True}
        Log    Placeholder
    END
    IF   ${ssh_reachable} == ${True}
        Log    Placeholder
    END

Retrieve BIG-IP Current CPU Utilization
    [Documentation]
    Set Global Variable    ${retrieved_cpu_stats_api}
    Set Global Variable    ${retrieved_cpu_stats_ssh}
    IF    ${api_reachable} == ${True}
        Log    Placeholder
    END
    IF   ${ssh_reachable} == ${True}
        Log    Placeholder
    END

Retrieve BIG-IP Current Memory Utilization
    [Documentation]
    Set Global Variable    ${retrieved_mem_stats_api}
    Set Global Variable    ${retrieved_mem_stats_ssh}
    IF    ${api_reachable} == ${True}
        Log    Placeholder
    END
    IF   ${ssh_reachable} == ${True}
        Log    Placeholder
    END

Retrieve BIG-IP Disk Space Utilization
    [Documentation]
    Set Global Variable    ${retrieved_disk_stats_api}
    Set Global Variable    ${retrieved_disk_stats_ssh}
    IF    ${api_reachable} == ${True}
        Log    Placeholder
    END
    IF   ${ssh_reachable} == ${True}
        Log    Placeholder
    END

Retrieve BIG-IP Provisioned Software Modules
    [Documentation]
    Set Global Variable    ${retrieved_provisioning_api}
    Set Global Variable    ${retrieved_provisioning_ssh}
    IF    ${api_reachable} == ${True}
        Log    Placeholder
    END
    IF   ${ssh_reachable} == ${True}
        Log    Placeholder
    END

List All System Database Variables
    [Documentation]
    Set Global Variable    ${retrieved_db_vars_api}
    Set Global Variable    ${retrieved_db_vars_ssh}
    IF    ${api_reachable} == ${True}
        Log    Placeholder
    END
    IF   ${ssh_reachable} == ${True}
        Log    Placeholder
    END

Retrieve BIG-IP High Availability Configuration
    [Documentation]
    Set Global Variable    ${retrieved_ha_config_api}
    Set Global Variable    ${retrieved_ha_config_ssh}
    IF    ${api_reachable} == ${True}
        Log    Placeholder
    END
    IF   ${ssh_reachable} == ${True}
        Log    Placeholder
    END

Retrieve BIG-IP SSL Certificate Metadata
    [Documentation]
    Set Global Variable    ${retrieved_ssl_certs_api}
    Set Global Variable    ${retrieved_ssl_certs_ssh}
    IF    ${api_reachable} == ${True}
        Log    Placeholder
    END
    IF   ${ssh_reachable} == ${True}
        Log    Placeholder
    END

Retrieve BIG-IP Interface Configuration
    [Documentation]
    Set Global Variable    ${retrieved_int_config_api}
    Set Global Variable    ${retrieved_int_config_ssh}
    IF    ${api_reachable} == ${True}
        Log    Placeholder
    END
    IF   ${ssh_reachable} == ${True}
        Log    Placeholder
    END

Retrieve BIG-IP Interface Statistics
    [Documentation]
    Set Global Variable    ${retrieved_int_stats_api}
    Set Global Variable    ${retrieved_int_stats_ssh}
    IF    ${api_reachable} == ${True}
        Log    Placeholder
    END
    IF   ${ssh_reachable} == ${True}
        Log    Placeholder
    END

Retrieve BIG-IP VLAN Configuration
    [Documentation]
    Set Global Variable    ${retrieved_vlan_config_api}
    Set Global Variable    ${retrieved_vlan_config_ssh}
    IF    ${api_reachable} == ${True}
        Log    Placeholder
    END
    IF   ${ssh_reachable} == ${True}
        Log    Placeholder
    END

Retrieve BIG-IP VLAN Statistics
    [Documentation]
    Set Global Variable    ${retrieved_vlan_stats_api}
    Set Global Variable    ${retrieved_vlan_stats_ssh}
    IF    ${api_reachable} == ${True}
        Log    Placeholder
    END
    IF   ${ssh_reachable} == ${True}
        Log    Placeholder
    END

Retrive Route Domain Information
    [Documentation]
    Set Global Variable    ${retrieved_route_domain_config_api}
    Set Global Variable    ${retrieved_route_domain_config_ssh}
    IF    ${api_reachable} == ${True}
        Log    Placeholder
    END
    IF   ${ssh_reachable} == ${True}
        Log    Placeholder
    END

Retrieve BIG-IP Authentication Partition Information
    [Documentation]
    Set Global Variable    ${retrieved_part_config_api}
    Set Global Variable    ${retrieved_part_config_ssh}
    IF    ${api_reachable} == ${True}
        Log    Placeholder
    END
    IF   ${ssh_reachable} == ${True}
        Log    Placeholder
    END

Retrieve BIG-IP Trunk Configuration
    [Documentation]
    Set Global Variable    ${retrieved_trunk_config_api}
    Set Global Variable    ${retrieved_trunk_config_ssh}
    IF    ${api_reachable} == ${True}
        Log    Placeholder
    END
    IF   ${ssh_reachable} == ${True}
        Log    Placeholder
    END

Retrieve BIG-IP Trunk Statistics
    [Documentation]
    Set Global Variable    ${retrieved_trunk_stats_api}
    Set Global Variable    ${retrieved_trunk_stats_ssh}
    IF    ${api_reachable} == ${True}
        Log    Placeholder
    END
    IF   ${ssh_reachable} == ${True}
        Log    Placeholder
    END

Retrive Self-IP Configuration
    [Documentation]
    IF    ${api_reachable} == ${True}
        Log    Placeholder
        Set Global Variable    ${retrieved_selfip_config_api}
    END
    IF   ${ssh_reachable} == ${True}
        Log    Placeholder
        Set Global Variable    ${retrieved_selfip_config_ssh}
    END

Retrieve BIG-IP Self-IP Statistics
    [Documentation]
    IF    ${api_reachable} == ${True}
        Log    Placeholder
        Set Global Variable    ${retrieved_selfip_stats_api}
    END
    IF   ${ssh_reachable} == ${True}
        Log    Placeholder
        Set Global Variable    ${retrieved_selfip_stats_ssh}
    END

Retrieve BIG-IP Static Route Configuration
    [Documentation]
    Set Global Variable    ${retrieved_static_routing_config_api}
    Set Global Variable    ${retrieved_static_routing_config_ssh}
    IF    ${api_reachable} == ${True}
        Log    Placeholder
    END
    IF   ${ssh_reachable} == ${True}
        Log    Placeholder
    END

Retrieve BIG-IP Dynamic Route Configuration
    [Documentation]
    Set Global Variable    ${retrieved_dynamic_routing_config_api}
    Set Global Variable    ${retrieved_dynamic_routing_config_ssh}
    IF    ${api_reachable} == ${True}
        Log    Placeholder
    END
    IF   ${ssh_reachable} == ${True}
        Log    Placeholder
    END

Retrieve BIG-IP Dynamic Route Status
    [Documentation]
    Set Global Variable    ${retrieved_dynamic_routing_status_api}
    Set Global Variable    ${retrieved_dynamic_routing_status_ssh}
    IF    ${api_reachable} == ${True}
        Log    Placeholder
    END
    IF   ${ssh_reachable} == ${True}
        Log    Placeholder
    END

Retrieve BIG-IP Virtual Server Configuration
    [Documentation]
    Set Global Variable    ${retrieved_virtual_config_api}
    Set Global Variable    ${retrieved_virtual_config_ssh}
    IF    ${api_reachable} == ${True}
        Log    Placeholder
    END
    IF   ${ssh_reachable} == ${True}
        Log    Placeholder
    END

Retrieve BIG-IP Virtual Server Statistics
    [Documentation]
    Set Global Variable    ${retrieved_virtual_stats_api}
    Set Global Variable    ${retrieved_virtual_stats_ssh}
    IF    ${api_reachable} == ${True}
        Log    Placeholder
    END
    IF   ${ssh_reachable} == ${True}
        Log    Placeholder
    END
    
Retrieve BIG-IP Pool Configuration
    [Documentation]
    Set Global Variable    ${retrieved_pool_config_api}
    Set Global Variable    ${retrieved_pool_config_ssh}
    IF    ${api_reachable} == ${True}
        Log    Placeholder
    END
    IF   ${ssh_reachable} == ${True}
        Log    Placeholder
    END

Retrive Pool Statistics
    [Documentation]
    Set Global Variable    ${retrieved_pool_stats_api}
    Set Global Variable    ${retrieved_pool_stats_ssh}
    IF    ${api_reachable} == ${True}
        Log    Placeholder
    END
    IF   ${ssh_reachable} == ${True}
        Log    Placeholder
    END

Retrieve BIG-IP Policy Configuration
    [Documentation]
    Set Global Variable    ${retrieved_policy_config_api}
    Set Global Variable    ${retrieved_policy_config_ssh}
    IF    ${api_reachable} == ${True}
        Log    Placeholder
    END
    IF   ${ssh_reachable} == ${True}
        Log    Placeholder
    END

Retrieve BIG-IP Monitor Configuration
    [Documentation]
    Set Global Variable    ${retrieved_monitor_config_api}
    Set Global Variable    ${retrieved_monitor_config_ssh}
    IF    ${api_reachable} == ${True}
        Log    Placeholder
    END
    IF   ${ssh_reachable} == ${True}
        Log    Placeholder
    END

Retrieve BIG-IP SNAT Configuration
    [Documentation]
    Set Global Variable    ${retrieved_snat_config_api}
    Set Global Variable    ${retrieved_snat_config_ssh}
    IF    ${api_reachable} == ${True}
        Log    Placeholder
    END
    IF   ${ssh_reachable} == ${True}
        Log    Placeholder
    END

Retrieve BIG-IP Full Text Configuration
    [Documentation]    Retrieve BIG-IPs the full BIG-IP configuration via list output
    Set Global Variable    ${retrieved__api}
    Set Global Variable    ${retrieved__ssh}
    IF    ${api_reachable} == ${True}
        Log    Placeholder
    END
    IF   ${ssh_reachable} == ${True}
        Log    Placeholder
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
    Append to File    ${OUTPUT_DIR}/${text_output_file_name}    ${text}
    [Return]

BIG-IP iControl BasicAuth GET    
    [Documentation]    Performs an iControl REST API GET call using basic auth (See pages 25-38 of https://cdn.f5.com/websites/devcentral.f5.com/downloads/icontrol-rest-api-user-guide-13-1-0-a.pdf.zip)
    [Arguments]    ${bigip_host}    ${bigip_username}    ${bigip_password}    ${api_uri}
    ${api_auth}    Create List    ${bigip_username}   ${bigip_password}
    RequestsLibrary.Create Session    bigip-icontrol-get-basicauth    https://${bigip_host}    auth=${api_auth}
    &{api_headers}    Create Dictionary    Content-type=application/json
    ${api_response}    GET On Session    bigip-icontrol-get-basicauth   ${api_uri}    headers=${api_headers}
    [Teardown]    Delete All Sessions
    [Return]    ${api_response}

Retrieve BIG-IP TMOS Version via iControl REST
    [Documentation]    Retrieves the current version of software running on the BIG-IP (https://support.f5.com/csp/article/K8759)
    [Arguments]    ${bigip_host}   ${bigip_username}   ${bigip_password}
    ${api_uri}    set variable    /mgmt/tm/sys/version
    ${api_response}    BIG-IP iControl BasicAuth GET   bigip_host=${bigip_host}    bigip_username=${bigip_username}    bigip_password=${bigip_password}    api_uri=${api_uri}
    should be equal as strings    ${api_response.status_code}    ${200}
    [Teardown]    Run Keywords   Delete All Sessions
    [Return]    ${api_response.json()}

Retrieve BIG-IP TMOS Version via SSH
    [Documentation]    Retrieves the current version of TMOS running on the BIG-IP (https://support.f5.com/csp/article/K8759)
    [Arguments]    ${bigip_host}    ${bigip_username}    ${bigip_password}
    SSHLibrary.Open Connection    ${bigip_host}
    SSHLibrary.Login    ${bigip_username}    ${bigip_password}
    ${version}    SSHLibrary.Execute Command    bash -c 'tmsh show sys version all-properties'
    [Teardown]    SSHLibrary.Close Connection
    [Return]    ${version}

Retrieve BIG-IP License Information via iControl REST
    [Documentation]    Retrieves the current license information on the BIG-IP (https://my.f5.com/manage/s/article/K7752)
    [Arguments]    ${bigip_host}   ${bigip_username}   ${bigip_password}
    ${api_uri}    set variable    /mgmt/tm/sys/license
    ${api_response}    BIG-IP iControl BasicAuth GET   bigip_host=${bigip_host}    bigip_username=${bigip_username}    bigip_password=${bigip_password}    api_uri=${api_uri}
    should be equal as strings    ${api_response.status_code}    ${200}
    [Teardown]    Run Keywords   Delete All Sessions
    [Return]    ${api_response.json()}

Retrieve BIG-IP License Information via SSH
    [Documentation]    Retrieves the license information on the BIG-IP (https://support.f5.com/csp/article/K13369)
    [Arguments]    ${bigip_host}    ${bigip_username}    ${bigip_password}
    SSHLibrary.Open Connection    ${bigip_host}
    SSHLibrary.Login    ${bigip_username}    ${bigip_password}
    ${license}    SSHLibrary.Execute Command    bash -c 'tmsh show sys license'
    [Teardown]    SSHLibrary.Close Connection
    [Return]    ${license}

Retrieve BIG-IP CPU Statistics via iControl REST
    [Documentation]    Retrieves CPU utilization statistics on the BIG-IP (https://support.f5.com/csp/article/K15468)
    [Arguments]    ${bigip_host}    ${bigip_username}    ${bigip_password}
    ${api_uri}    set variable    /mgmt/tm/sys/cpu
    set test variable    ${api_uri}
    ${api_response}    BIG-IP iControl BasicAuth GET    bigip_host=${bigip_host}    bigip_username=${bigip_username}    bigip_password=${bigip_password}    api_uri=${api_uri}
    should be equal as strings    ${api_response.status_code}    ${200}
    [Teardown]    Run Keywords   Delete All Sessions
    [Return]    ${api_response.json()}

Retrieve BIG-IP Hostname via iControl REST
    [Documentation]    Retrieves the hostname on the BIG-IP (https://support.f5.com/csp/article/K13369)
    [Arguments]    ${bigip_host}    ${bigip_username}    ${bigip_password}
    ${api_uri}    set variable    /mgmt/tm/sys/global-settings
    ${api_response}    BIG-IP iControl BasicAuth GET    bigip_host=${bigip_host}    bigip_username=${bigip_username}    bigip_password=${bigip_password}    api_uri=${api_uri}
    Should Be Equal As Strings    ${api_response.status_code}    ${200}
    ${configured_hostname}    get from dictionary    ${api_response.json()}    hostname
    [Teardown]    Run Keywords   Delete All Sessions
    [Return]    ${configured_hostname}

Retrieve BIG-IP Hostname via SSH
    [Documentation]    Retrieves the hostname on the BIG-IP (https://support.f5.com/csp/article/K13369)
    [Arguments]    ${bigip_host}    ${bigip_username}    ${bigip_password}
    SSHLibrary.Open Connection    ${bigip_host}
    SSHLibrary.Login    ${bigip_username}    ${bigip_password}
    ${hostname}    SSHLibrary.Execute Command    bash -c 'tmsh list sys global-settings hostname all-properties'
    [Teardown]    SSHLibrary.Close Connection
    [Return]    ${hostname}

Retrieve BIG-IP NTP Configuration via iControl REST
    [Documentation]    Retrieves the NTP configuration on the BIG-IP (https://my.f5.com/manage/s/article/K13380)
    [Arguments]    ${bigip_host}    ${bigip_username}    ${bigip_password}
    ${api_uri}    set variable    /mgmt/tm/sys/ntp
    ${api_response}    BIG-IP iControl BasicAuth GET    bigip_host=${bigip_host}    bigip_username=${bigip_username}    bigip_password=${bigip_password}    api_uri=${api_uri}
    Should Be Equal As Strings    ${api_response.status_code}    ${200}
    [Teardown]    Run Keywords   Delete All Sessions
    [Return]    ${api_response.json()}

Retrieve BIG-IP NTP Configuration via SSH
    [Documentation]    Retrieves the NTP configuration on the BIG-IP (https://my.f5.com/manage/s/article/K13380)
    [Arguments]    ${bigip_host}    ${bigip_username}    ${bigip_password}
    SSHLibrary.Open Connection    ${bigip_host}
    SSHLibrary.Login    ${bigip_username}    ${bigip_password}
    ${hostname}    SSHLibrary.Execute Command    bash -c 'tmsh list sys ntp all-properties'
    [Teardown]    SSHLibrary.Close Connection
    [Return]    ${hostname}


