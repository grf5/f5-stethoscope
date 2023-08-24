*** Settings ***
Documentation        F5 stethoscope is a Robot Framework script that checks the generic health
...                  of BIG-IP devices.
...    
Library            String
Library            SSHLibrary    timeout=10 seconds    loglevel=trace
Library            RequestsLibrary
Library            Collections
Suite Setup        Set Log Level    trace
Suite Teardown     Run Keywords    SSHLibrary.Close All Connections    RequestsLibrary.Delete All Sessions

*** Variables ***
# To specify the BIG-IP host from the cli, use the following syntax:
# robot f5-stethoscope.robot --host 192.168.1.1 --user admin --pass g00dgrAvy_1984$
${host}    192.168.1.245
${user}    admin
${pass}    default

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
        Log    Could not connect to SSH.
        SSHLibrary.Close All Connections
        ${ssh_reachable}    ${False}
    ELSE
        Log    Successfully connected to SSH
        Set Global Variable    ${ssh_reachable}    ${True}
    END
        Close All Connections
    # Checking to see that prompt includes (tmos)# for tmsh or the default bash prompt
    Should Contain Any    ${SSHLoginOutput}    (tmos)#    ] ~ #

Test IPv4 iControlREST API Connectivity
    [Documentation]    Tests BIG-IP iControl REST API connectivity using basic authentication
    TRY
        Wait until Keyword Succeeds    6x    5 seconds    Retrieve BIG-IP Version via iControl REST    bigip_host=${host}    bigip_username=${user}    bigip_password=${pass}        
    EXCEPT
        Log    Could not connect to iControl REST.
        Set Global Variable    ${api_reachable}    ${False}
    ELSE
        Log    Successfully connected to iControl REST API
        Set Global Variable    ${api_reachable}    ${True}
    END

Verify Connectivty Availability
    [Documentation]    Ensure that SSH or REST is available
    IF    ${api_reachable} == ${False} and ${ssh_reachable} == ${False}
        Fatal Error    No connectivity to device via SSH or iControl REST API
    END

Retrieve Hostname
    [Documentation]    Retrieves the configured hostname on the BIG-IP
    IF    ${api_reachable} == ${True}
        ${retrieved_hostname_api}    Retrieve BIG-IP Hostname via iControl REST    bigip_host=${host}    bigip_username=${user}    bigip_password=${pass}
        Set Global Variable    ${retrieved_hostname_api}
    END
    IF   ${ssh_reachable} == ${True}
        ${retrieved_hostname_ssh}    Retrieve BIG-IP Hostname via SSH    bigip_host=${host}    bigip_username=${user}    bigip_password=${pass}
        Set Global Variable    ${retrieved_hostname_ssh}
    END

Retrieve License Information
    [Documentation]    Retrieves the license information from the BIG-IP
    Set Global Variable    ${retrieved_license_ssh}    ${EMPTY}
    Set Global Variable    ${retrieved_license_api}    ${EMPTY}
    IF    ${api_reachable} == ${True}
        ${retrieved_license_api}    Retrieve BIG-IP License Information via iControl REST    bigip_host=${host}    bigip_username=${user}    bigip_password=${pass}
    END
    IF   ${ssh_reachable} == ${True}
        ${retrieved_license_ssh}    Retrieve BIG-IP License Information via SSH    bigip_host=${host}    bigip_username=${user}    bigip_password=${pass}
    END

Retrieve BIG-IP TMOS Version
    [Documentation]    Retrieves the current TMOS version of the device 
    Set Global Variable    ${retrieved_version_api}    ${EMPTY}
    Set Global Variable    ${retrieved_version_ssh}    ${EMPTY}
    IF    ${api_reachable} == ${True}
        ${retrieved_version_api}    Retrieve BIG-IP Version via iControl REST    bigip_host=${host}    bigip_username=${user}    bigip_password=${pass}
    END
    IF   ${ssh_reachable} == ${True}
        ${retrieved_version_ssh}    Retrieve BIG-IP Version via SSH    bigip_host=${host}    bigip_username=${user}    bigip_password=${pass}
    END

Retrieve NTP Configuration
    [Documentation]
    Set Global Variable    ${retrieved_ntp_config_api}    ${EMPTY}
    Set Global Variable    ${retrieved_ntp_config_ssh}    ${EMPTY}
    IF    ${api_reachable} == ${True}
        Log    Placeholder
    END
    IF   ${ssh_reachable} == ${True}
        Log    Placeholder
    END

Verify NTP Status
    [Documentation]
    Set Global Variable    ${retrieved_ntp_status_api}    ${EMPTY}
    Set Global Variable    ${retrieved_ntp_status_ssh}    ${EMPTY}
    IF    ${api_reachable} == ${True}
        Log    Placeholder
    END
    IF   ${ssh_reachable} == ${True}
        Log    Placeholder
    END

Retrieve Current CPU Utilization
    [Documentation]
    Set Global Variable    ${retrieved_cpu_stats_api}    ${EMPTY}
    Set Global Variable    ${retrieved_cpu_stats_ssh}    ${EMPTY}
    IF    ${api_reachable} == ${True}
        Log    Placeholder
    END
    IF   ${ssh_reachable} == ${True}
        Log    Placeholder
    END

Retrieve Current Memory Utilization
    [Documentation]
    Set Global Variable    ${retrieved_mem_stats_api}    ${EMPTY}
    Set Global Variable    ${retrieved_mem_stats_ssh}    ${EMPTY}
    IF    ${api_reachable} == ${True}
        Log    Placeholder
    END
    IF   ${ssh_reachable} == ${True}
        Log    Placeholder
    END

Retrieve Disk Space Utilization
    [Documentation]
    Set Global Variable    ${retrieved_disk_stats_api}    ${EMPTY}
    Set Global Variable    ${retrieved_disk_stats_ssh}    ${EMPTY}
    IF    ${api_reachable} == ${True}
        Log    Placeholder
    END
    IF   ${ssh_reachable} == ${True}
        Log    Placeholder
    END

Retrieve Provisioned Software Modules
    [Documentation]
    Set Global Variable    ${retrieved_provisioning_api}    ${EMPTY}
    Set Global Variable    ${retrieved_provisioning_ssh}    ${EMPTY}
    IF    ${api_reachable} == ${True}
        Log    Placeholder
    END
    IF   ${ssh_reachable} == ${True}
        Log    Placeholder
    END

List All System Database Variables
    [Documentation]
    Set Global Variable    ${retrieved_db_vars_api}    ${EMPTY}
    Set Global Variable    ${retrieved_db_vars_ssh}    ${EMPTY}
    IF    ${api_reachable} == ${True}
        Log    Placeholder
    END
    IF   ${ssh_reachable} == ${True}
        Log    Placeholder
    END

Retrieve High Availability Configuration
    [Documentation]
    Set Global Variable    ${retrieved_ha_config_api}    ${EMPTY}
    Set Global Variable    ${retrieved_ha_config_ssh}    ${EMPTY}
    IF    ${api_reachable} == ${True}
        Log    Placeholder
    END
    IF   ${ssh_reachable} == ${True}
        Log    Placeholder
    END

Retrieve SSL Certificate Metadata
    [Documentation]
    Set Global Variable    ${retrieved_ssl_certs_api}    ${EMPTY}
    Set Global Variable    ${retrieved_ssl_certs_ssh}    ${EMPTY}
    IF    ${api_reachable} == ${True}
        Log    Placeholder
    END
    IF   ${ssh_reachable} == ${True}
        Log    Placeholder
    END

Retrieve Interface Configuration
    [Documentation]
    Set Global Variable    ${retrieved_int_config_api}    ${EMPTY}
    Set Global Variable    ${retrieved_int_config_ssh}    ${EMPTY}
    IF    ${api_reachable} == ${True}
        Log    Placeholder
    END
    IF   ${ssh_reachable} == ${True}
        Log    Placeholder
    END

Retrieve Interface Statistics
    [Documentation]
    Set Global Variable    ${retrieved_int_stats_api}    ${EMPTY}
    Set Global Variable    ${retrieved_int_stats_ssh}    ${EMPTY}
    IF    ${api_reachable} == ${True}
        Log    Placeholder
    END
    IF   ${ssh_reachable} == ${True}
        Log    Placeholder
    END

Retrieve VLAN Configuration
    [Documentation]
    Set Global Variable    ${retrieved_vlan_config_api}    ${EMPTY}
    Set Global Variable    ${retrieved_vlan_config_ssh}    ${EMPTY}
    IF    ${api_reachable} == ${True}
        Log    Placeholder
    END
    IF   ${ssh_reachable} == ${True}
        Log    Placeholder
    END

Retrieve VLAN Statistics
    [Documentation]
    Set Global Variable    ${retrieved_vlan_stats_api}    ${EMPTY}
    Set Global Variable    ${retrieved_vlan_stats_ssh}    ${EMPTY}
    IF    ${api_reachable} == ${True}
        Log    Placeholder
    END
    IF   ${ssh_reachable} == ${True}
        Log    Placeholder
    END

Retrive Route Domain Information
    [Documentation]
    Set Global Variable    ${retrieved_route_domain_config_api}    ${EMPTY}
    Set Global Variable    ${retrieved_route_domain_config_ssh}    ${EMPTY}
    IF    ${api_reachable} == ${True}
        Log    Placeholder
    END
    IF   ${ssh_reachable} == ${True}
        Log    Placeholder
    END

Retrieve Authentication Partition Information
    [Documentation]
    Set Global Variable    ${retrieved_part_config_api}    ${EMPTY}
    Set Global Variable    ${retrieved_part_config_ssh}    ${EMPTY}
    IF    ${api_reachable} == ${True}
        Log    Placeholder
    END
    IF   ${ssh_reachable} == ${True}
        Log    Placeholder
    END

Retrieve Trunk Configuration
    [Documentation]
    Set Global Variable    ${retrieved_trunk_config_api}    ${EMPTY}
    Set Global Variable    ${retrieved_trunk_config_ssh}    ${EMPTY}
    IF    ${api_reachable} == ${True}
        Log    Placeholder
    END
    IF   ${ssh_reachable} == ${True}
        Log    Placeholder
    END

Retrieve Trunk Statistics
    [Documentation]
    Set Global Variable    ${retrieved_trunk_stats_api}    ${EMPTY}
    Set Global Variable    ${retrieved_trunk_stats_ssh}    ${EMPTY}
    IF    ${api_reachable} == ${True}
        Log    Placeholder
    END
    IF   ${ssh_reachable} == ${True}
        Log    Placeholder
    END

Retrive Self-IP Configuration
    [Documentation]
    Set Global Variable    ${retrieved_selfip_config_api}    ${EMPTY}
    Set Global Variable    ${retrieved_selfip_config_ssh}    ${EMPTY}
    IF    ${api_reachable} == ${True}
        Log    Placeholder
    END
    IF   ${ssh_reachable} == ${True}
        Log    Placeholder
    END

Retrieve Self-IP Statistics
    [Documentation]
    Set Global Variable    ${retrieved_selfip_stats_api}    ${EMPTY}
    Set Global Variable    ${retrieved_selfip_stats_ssh}    ${EMPTY}
    IF    ${api_reachable} == ${True}
        Log    Placeholder
    END
    IF   ${ssh_reachable} == ${True}
        Log    Placeholder
    END

Retrieve Static Route Configuration
    [Documentation]
    Set Global Variable    ${retrieved_static_routing_config_api}    ${EMPTY}
    Set Global Variable    ${retrieved_static_routing_config_ssh}    ${EMPTY}
    IF    ${api_reachable} == ${True}
        Log    Placeholder
    END
    IF   ${ssh_reachable} == ${True}
        Log    Placeholder
    END

Retrieve Dynamic Route Configuration
    [Documentation]
    Set Global Variable    ${retrieved_dynamic_routing_config_api}    ${EMPTY}
    Set Global Variable    ${retrieved_dynamic_routing_config_ssh}    ${EMPTY}
    IF    ${api_reachable} == ${True}
        Log    Placeholder
    END
    IF   ${ssh_reachable} == ${True}
        Log    Placeholder
    END

Retrieve Dynamic Route Status
    [Documentation]
    Set Global Variable    ${retrieved_dynamic_routing_status_api}    ${EMPTY}
    Set Global Variable    ${retrieved_dynamic_routing_status_ssh}    ${EMPTY}
    IF    ${api_reachable} == ${True}
        Log    Placeholder
    END
    IF   ${ssh_reachable} == ${True}
        Log    Placeholder
    END

Retrieve Virtual Server Configuration
    [Documentation]
    Set Global Variable    ${retrieved_virtual_config_api}    ${EMPTY}
    Set Global Variable    ${retrieved_virtual_config_ssh}    ${EMPTY}
    IF    ${api_reachable} == ${True}
        Log    Placeholder
    END
    IF   ${ssh_reachable} == ${True}
        Log    Placeholder
    END

Retrieve Virtual Server Statistics
    [Documentation]
    Set Global Variable    ${retrieved_virtual_stats_api}    ${EMPTY}
    Set Global Variable    ${retrieved_virtual_stats_ssh}    ${EMPTY}
    IF    ${api_reachable} == ${True}
        Log    Placeholder
    END
    IF   ${ssh_reachable} == ${True}
        Log    Placeholder
    END
    
Retrieve Pool Configuration
    [Documentation]
    Set Global Variable    ${retrieved_pool_config_api}    ${EMPTY}
    Set Global Variable    ${retrieved_pool_config_ssh}    ${EMPTY}
    IF    ${api_reachable} == ${True}
        Log    Placeholder
    END
    IF   ${ssh_reachable} == ${True}
        Log    Placeholder
    END

Retrive Pool Statistics
    [Documentation]
    Set Global Variable    ${retrieved_pool_stats_api}    ${EMPTY}
    Set Global Variable    ${retrieved_pool_stats_ssh}    ${EMPTY}
    IF    ${api_reachable} == ${True}
        Log    Placeholder
    END
    IF   ${ssh_reachable} == ${True}
        Log    Placeholder
    END

Retrieve Policy Configuration
    [Documentation]
    Set Global Variable    ${retrieved_policy_config_api}    ${EMPTY}
    Set Global Variable    ${retrieved_policy_config_ssh}    ${EMPTY}
    IF    ${api_reachable} == ${True}
        Log    Placeholder
    END
    IF   ${ssh_reachable} == ${True}
        Log    Placeholder
    END

Retrieve Monitor Configuration
    [Documentation]
    Set Global Variable    ${retrieved_monitor_config_api}    ${EMPTY}
    Set Global Variable    ${retrieved_monitor_config_ssh}    ${EMPTY}
    IF    ${api_reachable} == ${True}
        Log    Placeholder
    END
    IF   ${ssh_reachable} == ${True}
        Log    Placeholder
    END

Retrieve SNAT Configuration
    [Documentation]
    Set Global Variable    ${retrieved_snat_config_api}    ${EMPTY}
    Set Global Variable    ${retrieved_snat_config_ssh}    ${EMPTY}
    IF    ${api_reachable} == ${True}
        Log    Placeholder
    END
    IF   ${ssh_reachable} == ${True}
        Log    Placeholder
    END

Retrieve Full Text Configuration
    [Documentation]    Retrieves the full BIG-IP configuration via list output
    Set Global Variable    ${retrieved__api}    ${EMPTY}
    Set Global Variable    ${retrieved__ssh}    ${EMPTY}
    IF    ${api_reachable} == ${True}
        Log    Placeholder
    END
    IF   ${ssh_reachable} == ${True}
        Log    Placeholder
    END

Create Comparable Output Block
    [Documentation]    Creating a plain text block that can be diff'd between runs to view changes
    IF    ${api_reachable} == ${True}
        Log    ***API Retrieval***\nHostname: ${retrieved_hostname_api}\nTMOS Version: ${retrieved_version_api}\nLicense: ${retrieved_license_api}\n
    END
    IF   ${ssh_reachable} == ${True}
        Log    ***SSH Retrieval***\nHostname: ${retrieved_hostname_ssh}\nTMOS Version: ${retrieved_version_ssh}\nLicense: ${retrieved_license_ssh}\n
    END

*** Keywords ***
BIG-IP iControl BasicAuth GET    
    [Documentation]    Performs an iControl REST API GET call using basic auth (See pages 25-38 of https://cdn.f5.com/websites/devcentral.f5.com/downloads/icontrol-rest-api-user-guide-13-1-0-a.pdf.zip)
    [Arguments]    ${bigip_host}    ${bigip_username}    ${bigip_password}    ${api_uri}
    ${api_auth}    Create List    ${bigip_username}   ${bigip_password}
    RequestsLibrary.Create Session    bigip-icontrol-get-basicauth    https://${bigip_host}    auth=${api_auth}
    &{api_headers}    Create Dictionary    Content-type=application/json
    ${api_response}    GET On Session    bigip-icontrol-get-basicauth   ${api_uri}    headers=${api_headers}
    [Teardown]    Delete All Sessions
    [Return]    ${api_response}

Retrieve BIG-IP Version via iControl REST
    [Documentation]    Retrieves the current version of software running on the BIG-IP (https://support.f5.com/csp/article/K8759)
    [Arguments]    ${bigip_host}   ${bigip_username}   ${bigip_password}
    ${api_uri}    set variable    /mgmt/tm/sys/version
    ${api_response}    BIG-IP iControl BasicAuth GET   bigip_host=${bigip_host}    bigip_username=${bigip_username}    bigip_password=${bigip_password}    api_uri=${api_uri}
    should be equal as strings    ${api_response.status_code}    ${200}
    [Teardown]    Run Keywords   Delete All Sessions
    [Return]    ${api_response.json()}

Retrieve BIG-IP Version via SSH
    [Documentation]    Retrieves the current version of TMOS running on the BIG-IP (https://support.f5.com/csp/article/K8759)
    [Arguments]    ${bigip_host}    ${bigip_username}    ${bigip_password}
    SSHLibrary.Open Connection    ${bigip_host}
    SSHLibrary.Login    ${bigip_username}    ${bigip_password}
    ${version}    SSHLibrary.Execute Command    tmsh show sys version
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
    ${license}    SSHLibrary.Execute Command    tmsh show sys license
    [Teardown]    SSHLibrary.Close Connection
    [Return]    ${license}

Retrieve CPU Statistics via iControl REST
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
    ${hostname}    SSHLibrary.Execute Command    tmsh list sys global-settings hostname    
    [Teardown]    SSHLibrary.Close Connection
    [Return]    ${hostname}