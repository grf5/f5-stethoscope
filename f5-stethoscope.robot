*** Settings ***
Documentation        F5 stethoscope is a Robot Framework script that checks the generic health
...                  of BIG-IP devices.
...    
Library            String
Library            SSHLibrary    timeout=5 seconds    loglevel=trace
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
    IF    ${api_reachable} == ${True}
        Log    API Connectivity is available.
    ELSE IF    ${ssh_reachable} == ${True}
        Log    SSH Connectivity is available
    ELSE
        Fatal Error    No connectivity to device via SSH or iControl REST API
    END

Retrieve Hostname
    [Documentation]
        ${retrieved_hostname}    Retrieve BIG-IP Hostname via iControl REST    bigip_host=${host}    bigip_username=${user}    bigip_password=${pass}
        ${retrieved_hostname}    Retrieve BIG-IP Hostname via SSH    bigip_host=${host}    bigip_username=${user}    bigip_password=${pass}

Retrieve License Information
    [Documentation]

Retrieve BIG-IP TMOS Version
    [Documentation]    Retrieves the current TMOS version of the device 

Retrieve NTP Configuration
    [Documentation]

Verify NTP Status
    [Documentation]

Retrieve Current CPU Utilization
    [Documentation]

Retrieve Current Memory Utilization
    [Documentation]

Retrieve Disk Space Utilization
    [Documentation]

Retrieve Provisioned Software Modules
    [Documentation]

List All System Database Variables
    [Documentation]

Retrieve High Availability Configuration
    [Documentation]

Retrieve SSL Certificate Metadata
    [Documentation]

Retrieve Interface Configuration
    [Documentation]

Retrieve Interface Statistics
    [Documentation]

Retrieve VLAN Configuration
    [Documentation]

Retrieve VLAN Statistics
    [Documentation]

Retrive Route Domain Information
    [Documentation]

Retrieve Authentication Partition Information
    [Documentation]

Retrieve Trunk Configuration
    [Documentation]

Retrieve Trunk Statistics
    [Documentation]

Retrive Self-IP Configuration
    [Documentation]

Retrieve Self-IP Statistics
    [Documentation]

Retrieve Static Route Configuration
    [Documentation]

Retrieve Dynamic Route Configuration
    [Documentation]

Retrieve Virtual Server Configuration
    [Documentation]

Retrieve Virtual Server Statistics
    [Documentation]

Retrieve Pool Configuration
    [Documentation]

Retrive Pool Statistics
    [Documentation]

Retrieve Policy Configuration
    [Documentation]

Retrieve Monitor Configuration
    [Documentation]

Retrieve SNAT Configuration
    [Documentation]

Retrieve Full Text Configuration
    [Documentation]    Retrieves the full BIG-IP configuration via list output

Create Comparable Output Block
    [Documentation]    Creating a plain text block that can be diff'd between runs to view changes
    

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
    should be equal as strings    ${api_response.status_code}    ${200}
    [Teardown]    Run Keywords   Delete All Sessions
    [Return]    ${api_response}

Retrieve CPU Statistics via iControl REST
    [Documentation]    Retrieves CPU utilization statistics on the BIG-IP (https://support.f5.com/csp/article/K15468)
    [Arguments]    ${bigip_host}    ${bigip_username}    ${bigip_password}
    ${api_uri}    set variable    /mgmt/tm/sys/cpu
    set test variable    ${api_uri}
    ${api_response}    BIG-IP iControl BasicAuth GET    bigip_host=${bigip_host}    bigip_username=${bigip_username}    bigip_password=${bigip_password}    api_uri=${api_uri}
    should be equal as strings    ${api_response.status_code}    ${200}
    [Return]    ${api_response}

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
    SSHLibrary.Open Connection    ${bigip_host}
    SSHLibrary.Login    ${bigip_username}    ${bigip_password}
    ${hostname}    SSHLibrary.Execute Command    tmsh list sys global-settings hostname    
    [Return]    ${hostname}