*** Settings ***
Documentation        F5 stethoscope is a Robot Framework script that checks the generic health
...                  of BIG-IP devices.
...    
Library    String
Library    SSHLibrary

*** Variables ***
# To specify the BIG-IP host from the cli, use the following syntax:
# robot f5-stethoscope.robot --host 192.168.1.1 --user admin --pass g00dgrAvy_1984$
${host}
${user}
${pass}

*** Test Cases ***
Check for Required Variables
    Should Not Be Empty    ${host}
    Should Not Be Empty    ${user}
    Should Not Be Empty    ${pass}

Verify SSH Connectivity
    [Documentation]    Logs into the BIG-IP via SSH, executes a BASH command and validates the expected response
    set log level    trace
    Wait until Keyword Succeeds    3x    5 seconds    Open Connection    ${BIGIP_PRIMARY_MGMT_IP}
    Log In    ${SSH_USERNAME}    ${SSH_PASSWORD}
    Run BASH Echo Test
    Close All Connections
    Return from Keyword If    '${BIGIP_SECONDARY_MGMT_IP}' == 'false'
    Wait until Keyword Succeeds    3x    5 seconds    Open Connection    ${BIGIP_SECONDARY_MGMT_IP}
    Log In    ${SSH_USERNAME}    ${SSH_PASSWORD}
    Run BASH Echo Test
    Close All Connections






*** Keywords ***


Run BASH Echo Test
    [Documentation]    Issues a BASH command and looks for the proper response inside of an existing SSH session
    ${BASH_ECHO_RESPONSE}    Execute Command    echo 'BASH TEST'
    Should Be Equal    ${BASH_ECHO_RESPONSE}    BASH TEST
    [Return]    ${BASH_ECHO_RESPONSE}
