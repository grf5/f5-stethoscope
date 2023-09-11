*** Settings ***
Library            Collections
Library            String
Library            RequestsLibrary
Library            SSHLibrary
Library            OperatingSystem
Resource           f5-stethoscope-variables.robot

*** Keywords ***
Append to API Output
    [Documentation]    Builds the JSON output block for API information
    [Arguments]    ${key}    ${value}
    Set To Dictionary    ${api_info_block}    ${key}    ${value}
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
    [Return]    ${api_response}

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
    [Return]    ${api_response}

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
    ${hostname}    SSHLibrary.Execute Command    bash -c 'tmsh list sys global-settings hostname'
    [Return]    ${hostname}

Retrieve BIG-IP NTP Configuration via iControl REST
    [Documentation]    Retrieves the NTP configuration on the BIG-IP (https://my.f5.com/manage/s/article/K13380)
    [Arguments]    ${bigip_host}    ${bigip_username}    ${bigip_password}
    ${api_uri}    set variable    /mgmt/tm/sys/ntp
    ${api_response}    BIG-IP iControl BasicAuth GET    bigip_host=${bigip_host}    bigip_username=${bigip_username}    bigip_password=${bigip_password}    api_uri=${api_uri}
    Should Be Equal As Strings    ${api_response.status_code}    ${200}
    [Return]    ${api_response}

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
    ${cpu_stats}    SSHLibrary.Execute Command    bash -c 'tmsh show sys cpu all field-fmt'
    [Return]    ${cpu_stats}

Curl iControl REST via SSH
    [Documentation]    Retrieves an iControl REST API endpoint via curl task from BASH
    [Arguments]    ${bigip_host}    ${bigip_username}    ${bigip_password}    ${uri}
    ${command}    Set Variable    curl -sku ${bigip_username}:${bigip_password} https://127.0.0.1/${uri}
    ${retrieved_api_response}    Run BASH Command on BIG-IP    ${bigip_host}    ${bigip_username}    ${bigip_password}    ${command}
    [Return]    ${retrieved_api_response}

Retrieve BIG-IP Hardware Information
    [Documentation]    Retrieves the BIG-IP hardware information, applicable to virtual editions as well (https://my.f5.com/manage/s/article/K13144)
    [Arguments]    ${bigip_host}    ${bigip_username}    ${bigip_password}
    ${api_uri}    set variable    /mgmt/tm/sys/hardware
    ${api_response}    BIG-IP iControl BasicAuth GET    bigip_host=${bigip_host}    bigip_username=${bigip_username}    bigip_password=${bigip_password}    api_uri=${api_uri}
    Should Be Equal As Strings    ${api_response.status_code}    ${200}
    [Return]    ${api_response}

Retrieve BIG-IP System Performance via iControl REST
    [Documentation]    Retrieves the CPU statistics from the BIG-IP using iControl REST (https://my.f5.com/manage/s/article/K15468)
    [Arguments]    ${bigip_host}    ${bigip_username}    ${bigip_password}
    ${api_uri}    set variable    /mgmt/tm/sys/performance/all-stats
    ${api_response}    BIG-IP iControl BasicAuth GET    bigip_host=${bigip_host}  bigip_username=${bigip_username}    bigip_password=${bigip_password}    api_uri=${api_uri}
    Should Be Equal As Strings    ${api_response.status_code}    ${200}
    [Return]    ${api_response}

Retrieve BIG-IP System Performance via SSH
    [Arguments]    ${bigip_host}    ${bigip_username}    ${bigip_password}
    [Documentation]    Retrieves the output of the ntpq command on the BIG-IP (https://my.f5.com/manage/s/article/K10240)
    [Teardown]    SSHLibrary.Close All Connections
    SSHLibrary.Open Connection    ${bigip_host}
    SSHLibrary.Login    ${bigip_username}    ${bigip_password}
    ${sys_performance_all_stats}    SSHLibrary.Execute Command    bash -c 'tmsh show sys performance all-stats detail raw'
    [Return]    ${sys_performance_all_stats}

Retrieve BIG-IP Disk Space Utilization via SSH
    [Arguments]    ${bigip_host}    ${bigip_username}    ${bigip_password}
    [Documentation]    Retrieves the disk space utilization on the BIG-IP
    [Teardown]    SSHLibrary.Close All Connections
    SSHLibrary.Open Connection    ${bigip_host}
    SSHLibrary.Login    ${bigip_username}    ${bigip_password}
    ${disk_space_output}    SSHLibrary.Execute Command    bash -c 'df -h'
    [Return]    ${disk_space_output}
