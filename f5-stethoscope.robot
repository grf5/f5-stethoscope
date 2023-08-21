*** Settings ***
Documentation        F5 stethoscope is a Robot Framework script that checks the generic health
...                  of BIG-IP devices.
...    
Library    String
Library    SSHLibrary
Library    RequestsLibrary

*** Variables ***
# To specify the BIG-IP host from the cli, use the following syntax:
# robot f5-stethoscope.robot --host 192.168.1.1 --user admin --pass g00dgrAvy_1984$
${host}
${user}
${pass}

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
        Open Connection    ${host} 
        Log In    ${user}    ${pass}
        Run BASH Echo Test
    EXCEPT    Error connecting to SSH 
        Close All Connections
        Fatal Error
    END
        Close All Connections

Test IPv4 iControlREST API Connectivity
    [Documentation]    Tests BIG-IP iControl REST API connectivity using basic authentication
    Set Log Level    trace
    Wait until Keyword Succeeds    6x    5 seconds    Retrieve BIG-IP Version via iControl REST    bigip_host=${host}    bigip_username=${user}    bigip_password=${pass}

*** Keywords ***
Run BASH Echo Test
    [Documentation]    Issues a BASH command and looks for the proper response inside of an existing SSH session
    ${BASH_ECHO_RESPONSE}    Execute Command    echo 'BASH TEST'
    Should Be Equal    ${BASH_ECHO_RESPONSE}    BASH TEST
    [Return]    ${BASH_ECHO_RESPONSE}

Retrieve BIG-IP Version via iControl REST
    [Documentation]    Shows the current version of software running on the BIG-IP (https://support.f5.com/csp/article/K8759)
    [Arguments]    ${bigip_host}   ${bigip_username}   ${bigip_password}
    ${api_uri}    set variable    /mgmt/tm/sys/version
    ${api_response}    BIG-IP iControl BasicAuth GET   bigip_host=${bigip_host}    bigip_username=${bigip_username}    bigip_password=${bigip_password}    api_uri=${api_uri}
    should be equal as strings    ${api_response.status_code}    200
    [Return]    ${api_response}

BIG-IP iControl BasicAuth GET    
    [Documentation]    Performs an iControl REST API GET call using basic auth (See pages 25-38 of https://cdn.f5.com/websites/devcentral.f5.com/downloads/icontrol-rest-api-user-guide-13-1-0-a.pdf.zip)
    [Arguments]    ${bigip_host}    ${bigip_username}    ${bigip_password}    ${api_uri}
    ${api_auth}    Create List    ${bigip_username}   ${bigip_password}
    RequestsLibrary.Create Session    bigip-icontrol-get-basicauth    https://${bigip_host}    auth=${api_auth}
    &{api_headers}    Create Dictionary    Content-type=application/json
    ${api_response}    GET On Session    bigip-icontrol-get-basicauth   ${api_uri}    headers=${api_headers}
    [Teardown]    Delete All Sessions
    [Return]    ${api_response}

Retrieve BIG-IP Version
    [Documentation]    Shows the current version of software running on the BIG-IP (https://support.f5.com/csp/article/K8759)
    [Arguments]    ${bigip_host}   ${bigip_username}   ${bigip_password}
    ${api_uri}    set variable    /mgmt/tm/sys/version
    ${api_response}    BIG-IP iControl BasicAuth GET   bigip_host=${bigip_host}    bigip_username=${bigip_username}    bigip_password=${bigip_password}    api_uri=${api_uri}
    should be equal as strings    ${api_response.status_code}    200
    [Return]    ${api_response}

