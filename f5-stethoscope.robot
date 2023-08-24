*** Settings ***
Documentation        F5 stethoscope is a Robot Framework script that checks the generic health
...                  of BIG-IP devices.
...    
Library    String
Library    SSHLibrary    timeout=5 seconds    loglevel=trace
Library    RequestsLibrary
Library    Collections

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
    Set Log Level    trace
    TRY
        Should Not Be Empty    ${host}
        Should Not Be Empty    ${user}
        Should Not Be Empty    ${pass}
    EXCEPT
        Fatal Error
    END

Verify SSH Connectivity
    [Documentation]    Logs into the BIG-IP via SSH, executes a BASH command and validates the expected response
    [Tags]    critical
    Set Log Level    trace
    TRY
        ${SSHOpenConnectionOutput}    SSHLibrary.Open Connection    ${host} 
        ${SSHLoginOutput}    SSHLibrary.Log In    ${user}    ${pass}
    EXCEPT    Error connecting to SSH 
        Log    Could not connect to SSH.
        SSHLibrary.Close All Connections
        ${ssh_reachable}    ${False}
    END
        Close All Connections
    # Checking to see that prompt includes (tmos)# for tmsh or the default bash prompt
    Should Contain Any    ${SSHLoginOutput}    (tmos)#    ] ~ #

Test IPv4 iControlREST API Connectivity
    [Documentation]    Tests BIG-IP iControl REST API connectivity using basic authentication
    Set Log Level    trace
    TRY
        Wait until Keyword Succeeds    6x    5 seconds    Retrieve BIG-IP Version via iControl REST    bigip_host=${host}    bigip_username=${user}    bigip_password=${pass}        
    EXCEPT    message
        Log    Could not connect to iControl REST.
        ${api_reachable}    ${False}
    END

Retrieve Hostname
    [Documentation]
    Set Log Level    trace
    ${retrieved_hostname}    Retrieve BIG-IP Hostname via iControl REST    bigip_host=${host}    bigip_username=${user}    bigip_password=${pass}

Retrieve License Information
    [Documentation]
    Set Log Level    trace

Retrieve NTP Configuration
    [Documentation]
    Set Log Level    trace

Verify NTP Status
    [Documentation]
    Set Log Level    trace

Retrieve Current CPU Utilization
    [Documentation]
    Set Log Level    trace

Retrieve Current Memory Utilization
    [Documentation]
    Set Log Level    trace

Retrieve Disk Space Utilization
    [Documentation]
    Set Log Level    trace

Retrieve Provisioned Software Modules
    [Documentation]
    Set Log Level    trace

List All System Database Variables
    [Documentation]
    Set Log Level    trace

Retrieve High Availability Configuration
    [Documentation]
    Set Log Level    trace

Retrieve SSL Certificate Metadata
    [Documentation]
    Set Log Level    trace

Retrieve Interface Configuration
    [Documentation]
    Set Log Level    trace

Retrieve Interface Statistics
    [Documentation]
    Set Log Level    trace

Retrieve VLAN Configuration
    [Documentation]
    Set Log Level    trace

Retrieve VLAN Statistics
    [Documentation]
    Set Log Level    trace

Retrive Route Domain Information
    [Documentation]
    Set Log Level    trace

Retrieve Authentication Partition Information
    [Documentation]
    Set Log Level    trace

Retrieve Trunk Configuration
    [Documentation]
    Set Log Level    trace

Retrieve Trunk Statistics
    [Documentation]
    Set Log Level    trace

Retrive Self-IP Configuration
    [Documentation]
    Set Log Level    trace

Retrieve Self-IP Statistics
    [Documentation]
    Set Log Level    trace

Retrieve Static Route Configuration
    [Documentation]
    Set Log Level    trace

Retrieve Dynamic Route Configuration
    [Documentation]
    Set Log Level    trace

Retrieve Virtual Server Configuration
    [Documentation]
    Set Log Level    trace

Retrieve Virtual Server Statistics
    [Documentation]
    Set Log Level    trace

Retrieve Pool Configuration
    [Documentation]
    Set Log Level    trace

Retrive Pool Statistics
    [Documentation]
    Set Log Level    trace

Retrieve Policy Configuration
    [Documentation]
    Set Log Level    trace

Retrieve Monitor Configuration
    [Documentation]
    Set Log Level    trace

Retrieve SNAT Configuration
    [Documentation]
    Set Log Level    trace


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
    [Documentation]    Shows the current version of software running on the BIG-IP (https://support.f5.com/csp/article/K8759)
    [Arguments]    ${bigip_host}   ${bigip_username}   ${bigip_password}
    ${api_uri}    set variable    /mgmt/tm/sys/version
    ${api_response}    BIG-IP iControl BasicAuth GET   bigip_host=${bigip_host}    bigip_username=${bigip_username}    bigip_password=${bigip_password}    api_uri=${api_uri}
    should be equal as strings    ${api_response.status_code}    200
    [Teardown]    Run Keywords   Delete All Sessions
    [Return]    ${api_response}

Retrieve CPU Statistics via iControl REST
    [Documentation]    Retrieves CPU utilization statistics on the BIG-IP (https://support.f5.com/csp/article/K15468)
    [Arguments]    ${bigip_host}    ${bigip_username}    ${bigip_password}
    ${api_uri}    set variable    /mgmt/tm/sys/cpu
    set test variable    ${api_uri}
    ${api_response}    BIG-IP iControl BasicAuth GET    bigip_host=${bigip_host}    bigip_username=${bigip_username}    bigip_password=${bigip_password}    api_uri=${api_uri}
    should be equal as strings    ${api_response.status_code}    200
    [Return]    ${api_response}

Retrieve BIG-IP Hostname via iControl REST
    [Documentation]    Retrieves the hostname on the BIG-IP (https://support.f5.com/csp/article/K13369)
    [Arguments]    ${bigip_host}    ${bigip_username}    ${bigip_password}
    ${api_uri}    set variable    /mgmt/tm/sys/global-settings
    ${api_response}    BIG-IP iControl BasicAuth GET    bigip_host=${bigip_host}    bigip_username=${bigip_username}    bigip_password=${bigip_password}    api_uri=${api_uri}
    Should Be Equal As Strings    ${api_response.status_code}    ${HTTP_RESPONSE_OK}
    ${api_response_dict}    to json    ${api_response.text}
    ${configured_hostname}    get from dictionary    ${api_response_dict}    hostname
    [Return]    ${configured_hostname}