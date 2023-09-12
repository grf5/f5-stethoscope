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
    Log To Console    \nTest started at ${timestamp}
    Set to Dictionary    ${api_info_block}    test-start-time    ${timestamp}
    Create File    ${OUTPUT_DIR}/${status_output_file_name}   Test started at ${timestamp}\n
    Create File    ${OUTPUT_DIR}/${statistics_output_file_name}   Test started at ${timestamp}\n

Verify SSH Connectivity
    [Documentation]    Logs into the BIG-IP via TMSH, executes a BASH command and validates the expected response
    [Teardown]    Run Keywords    SSHLibrary.Close All Connections
    [Tags]    critical
    TRY
        # Use the SSH Library to connect to the host
        SSHLibrary.Open Connection    ${bigip_host}
        # Log in and note the returned prompt
        ${login_output}   SSHLibrary.Log In    ${bigip_username}   ${bigip_password}
        # Verify that the prompt includes (tmos)# for tmsh or the default bash prompt
        Should Contain Any    ${login_output}   (tmos)#    ] ~ #
    EXCEPT
        Log    Could not connect to SSH
        Append to file    ${OUTPUT_DIR}/${status_output_file_name}    SSH Connecitivity: FAILED\n
        Append to file    ${OUTPUT_DIR}/${statistics_output_file_name}    SSH Connecitivity: FAILED\n
        Fatal Error
    ELSE
        Log    Successfully connected to SSH
        Append to file    ${OUTPUT_DIR}/${status_output_file_name}    SSH Connecitivity: Succeeded\n
    END

Verify Remote Host is a BIG-IP via TMSH
    [Documentation]    This test will run a command via TMSH to verify that the remote host is
    ...                a BIG-IP device.
    [Teardown]    Run Keywords    SSHLibrary.Close All Connections
    ...    AND    Run Keyword If Test Failed    Fatal Error    FATAL_ERROR: Aborting as endpoint is not a BIG-IP device!
    [Tags]    critical
    SSHLibrary.Open Connection    ${bigip_host}
    SSHLibrary.Log In    ${bigip_username}   ${bigip_password}
    ${retrieved_show_sys_hardware_cli}   SSHLibrary.Execute Command    bash -c 'tmsh show sys hardware'
    Should Contain    ${retrieved_show_sys_hardware_cli}   BIG-IP
    Append to file    ${OUTPUT_DIR}/${status_output_file_name}    ======> System Hardware:${retrieved_show_sys_hardware_cli}\n

Test IPv4 iControlREST API Connectivity
    [Documentation]    Tests BIG-IP iControl REST API connectivity using basic authentication
    [Tags]    critical
    TRY
        Wait until Keyword Succeeds    6x    5 seconds    Retrieve BIG-IP TMOS Version via iControl REST    ${bigip_host}   ${bigip_username}   ${bigip_password}
    EXCEPT
        Append to file    ${OUTPUT_DIR}/${status_output_file_name}    ======> Fatal error: API connectivity failed\n
        Set to Dictionary    ${api_info_block}    error    API connectivity failed
        Log    Fatal error: API connectivity failed
        Log To Console    \nFatal error: API connectivity failed
        Fatal Error    No connectivity to device via iControl REST API: Host: ${bigip_host} with user '${bigip_username}'
    ELSE
        Log    Successfully connected to iControl REST API
        Set to Dictionary    ${api_info_block}    api-connectivity    ${True}
        Append to file    ${OUTPUT_DIR}/${status_output_file_name}    ======> API Connecitivity: Succeeded\n
    END

Verify Remote Host is a BIG-IP via iControl REST
    [Documentation]    This test will query the iControl REST API to ensure the remote endpoint is
    ...                a BIG-IP device.
    [Teardown]    Run Keyword If Test Failed    Fatal Error    FATAL_ERROR: Aborting as endpoint is not a BIG-IP device!
    [Tags]    critical
    ${retrieved_sys_hardware_api}   Retrieve BIG-IP Hardware Information    bigip_host=${bigip_host}   bigip_username=${bigip_username}   bigip_password=${bigip_password}
    Should contain    ${retrieved_sys_hardware_api.text}   BIG-IP
    Set to Dictionary    ${api_info_block}    sys-hardware    ${retrieved_sys_hardware_api}

Check BIG-IP for Excessive CPU/Memory Utilization
    [Documentation]    Verifies that resource utilization on the BIG-IP isn't critical and stops all testing if robot tests could cause impact
    [Tags]    critical
    # Retrieve the desired data via API; returned in JSON format
    ${system_performance_api}   Retrieve BIG-IP System Performance via iControl REST    bigip_host=${bigip_host}   bigip_username=${bigip_username}   bigip_password=${bigip_password}
    ${system_performance_cli}   Retrieve BIG-IP System Performance via TMSH    bigip_host=${bigip_host}   bigip_username=${bigip_username}   bigip_password=${bigip_password}
    Dictionary should contain item    ${system_performance_api.json()}    kind    tm:sys:performance:all-stats:all-statsstats
    ${system_performance_stats}    Get from dictionary    ${system_performance_api.json()}    entries
    ${utilization_avg}    Set variable    ${system_performance_stats}[https://localhost/mgmt/tm/sys/performance/all-stats/Utilization][nestedStats][entries][Average][description]
    ${other_mem_used_avg}    Set variable    ${system_performance_stats}[https://localhost/mgmt/tm/sys/performance/all-stats/Other%20Memory%20Used][nestedStats][entries][Average][description]
    ${tmm_mem_used_avg}    Set variable    ${system_performance_stats}[https://localhost/mgmt/tm/sys/performance/all-stats/TMM%20Memory%20Used][nestedStats][entries][Average][description]
    ${swap_used_avg}    Set variable    ${system_performance_stats}[https://localhost/mgmt/tm/sys/performance/all-stats/Swap%20Used][nestedStats][entries][Average][description]
    Set to Dictionary    ${api_info_block}    system-performance-all-stats    ${system_performance_api.json()}
    Append to file    ${OUTPUT_DIR}/${statistics_output_file_name}    ======> System Performance All Statistics:${system_performance_cli}\n
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
        Log to Console    \nWARNING! Swap space in use on device! This is a red flag! See https://my.f5.com/manage/s/article/K55227819
        Log    WARNING! Swap space in use on device! This is a red flag! See https://my.f5.com/manage/s/article/K55227819
        Append to file    ${OUTPUT_DIR}/${status_output_file_name}    ======> WARNING! Swap space in use on device!\n
    END

Retrieve BIG-IP CPU Statistics
    [Documentation]    Retrieves the CPU utilization from the BIG-IP (https://my.f5.com/manage/s/article/K05501591)
    # Retrieve desired information via iControl REST
    ${retrieved_cpu_stats_api}   Retrieve BIG-IP CPU Statistics via iControl REST    bigip_host=${bigip_host}   bigip_username=${bigip_username}   bigip_password=${bigip_password}
    ${retrieved_cpu_stats_cli}   Retrieve BIG-IP CPU Statistics via TMSH    bigip_host=${bigip_host}   bigip_username=${bigip_username}   bigip_password=${bigip_password}
    Set to Dictionary    ${api_info_block}    retrieved-cpu-stats    ${retrieved_cpu_stats_api}
    Append to file    ${OUTPUT_DIR}/${statistics_output_file_name}    ======> CPU Statistics:\n${retrieved_cpu_stats_cli}\n

Retrieve BIG-IP Hostname
    [Documentation]    Retrieves the configured hostname on the BIG-IP
    ${retrieved_hostname_api}   Retrieve BIG-IP Hostname via iControl REST    bigip_host=${bigip_host}   bigip_username=${bigip_username}   bigip_password=${bigip_password}
    ${retrieved_hostname_cli}   Retrieve BIG-IP Hostname via TMSH    bigip_host=${bigip_host}   bigip_username=${bigip_username}   bigip_password=${bigip_password}
    Set to Dictionary    ${api_info_block}    hostname=${retrieved_hostname_api}
    Append to file    ${OUTPUT_DIR}/${status_output_file_name}    ======> Hostname:\n${retrieved_hostname_cli}\n

Retrieve BIG-IP License Information
    [Documentation]    Retrieves the license information from the BIG-IP
    ${retrieved_license_api}   Retrieve BIG-IP License Information via iControl REST    bigip_host=${bigip_host}   bigip_username=${bigip_username}   bigip_password=${bigip_password}
    ${retrieved_license_cli}   Retrieve BIG-IP License Information via TMSH    bigip_host=${bigip_host}   bigip_username=${bigip_username}   bigip_password=${bigip_password}
    Should not contain    ${retrieved_license_cli}    Can't load license, may not be operational
    Dictionary should not contain key    ${retrieved_license_api.json()}    apiRawValues
    ${service_check_date}    Set variable    ${retrieved_license_api.json()}[entries][https://localhost/mgmt/tm/sys/license/0][nestedStats][entries][serviceCheckDate][description]
    Append to file    ${OUTPUT_DIR}/${status_output_file_name}    ======> Service check date: ${service_check_date}\n
    Set to Dictionary    ${api_info_block}    license-service-check-date    ${service_check_date}
    ${current_date}    Get current date    result_format=%Y/%m/%d
    Append to file    ${OUTPUT_DIR}/${status_output_file_name}    ======> Current date: ${current_date}\n
    Set to Dictionary    ${api_info_block}    current-date    ${current_date}
    ${days_until_service_check_date}    Subtract date from date    ${service_check_date}    ${current_date}
    IF    ${days_until_service_check_date} < 1
        Log to console    \nWARNING! License service check date occurs in the past! Re-activate license required prior to upgrade! (https://my.f5.com/manage/s/article/K7727)
        Log    WARNING! License service check date occurs in the past! Reactivate license required prior to upgrade! (https://my.f5.com/manage/s/article/K7727)
        Append to file    ${OUTPUT_DIR}/${status_output_file_name}    ======> WARNING! License service check date occurs in the past! Re-actviate license required prior to upgrade! (https://my.f5.com/manage/s/article/K7727)\n
    END
    Set to Dictionary    ${api_info_block}    license    ${retrieved_license_api}
    Append to file    ${OUTPUT_DIR}/${status_output_file_name}    ======> License: ${retrieved_license_cli}\n

Retrieve BIG-IP TMOS Version
    [Documentation]    Retrieves the current TMOS version of the device and verifies lifecycle status. (https://my.f5.com/manage/s/article/K5903)
    ${retrieved_version_api}   Retrieve BIG-IP TMOS Version via iControl REST    bigip_host=${bigip_host}   bigip_username=${bigip_username}   bigip_password=${bigip_password}
    ${retrieved_version_cli}   Retrieve BIG-IP TMOS Version via TMSH    bigip_host=${bigip_host}   bigip_username=${bigip_username}   bigip_password=${bigip_password}
    ${bigip_version}    Set variable    ${retrieved_version_api.json()}[entries][https://localhost/mgmt/tm/sys/version/0][nestedStats][entries][Version][description]
    Set to Dictionary    ${api_info_block}    version    ${retrieved_version_api}
    Append to file    ${OUTPUT_DIR}/${status_output_file_name}    ======> BIG-IP Version: ${retrieved_version_cli}\n
    ${current_date}    Get current date    result_format=%Y/%m/%d
    IF    "17.1." in "${bigip_version}"
        ${end_of_software_development}    Set variable    2027/03/31
        ${end_of_technical_support}    Set variable    2027/03/31
        ${remaining_days_software_development}    Subtract date from date    ${end_of_software_development}    ${current_date}
        ${remaining_days_technical_support}    Subtract date from date    ${end_of_technical_support}    ${current_date}
        ${remaining_days_software_development_human_readable}    Subtract date from date    ${end_of_software_development}    ${current_date}    verbose
        ${remaining_days_technical_support_human_readable}    Subtract date from date    ${end_of_technical_support}    ${current_date}    verbose
        IF    ${remaining_days_software_development} > 0 and ${remaining_days_technical_support} > 0
            Set to Dictionary    ${api_info_block}    remaining-days-software-development    ${remaining_days_software_development}
            Set to Dictionary    ${api_info_block}    remaining-days-technical-support    ${remaining_days_technical_support}
            Append to file    ${OUTPUT_DIR}/${status_output_file_name}    ======> Remaining Days of Software Development Support: ${remaining_days_software_development_human_readable}\n
            Append to file    ${OUTPUT_DIR}/${status_output_file_name}    ======> Remaining Days of Technical Support: ${remaining_days_technical_support_human_readable}\n
        ELSE IF    ${remaining_days_software_development} <= 0
            Log to console    \nWARNING: TMOS release has reached end of software development status in lifecycle. (https://my.f5.com/manage/s/article/K5903)
            Log    WARNING: TMOS release has reached end of software development status in lifecycle. (https://my.f5.com/manage/s/article/K5903)
            Append to file    ${OUTPUT_DIR}/${status_output_file_name}    ======> WARNING: TMOS release has reached end of software development status in lifecycle. (https://my.f5.com/manage/s/article/K5903)\n
        ELSE IF    ${remaining_days_technical_support} <= 0
            Log to console    \nWARNING: TMOS release has reached end of technical support status in lifecycle. (https://my.f5.com/manage/s/article/K5903)
            Log    WARNING: TMOS release has reached end of software development status in lifecycle. (https://my.f5.com/manage/s/article/K5903)
            Append to file    ${OUTPUT_DIR}/${status_output_file_name}    ======> WARNING: TMOS release has reached end of software development status in lifecycle. (https://my.f5.com/manage/s/article/K5903)\n
        END
    ELSE IF    "16.1." in "${bigip_version}"
        ${end_of_software_development}    Set variable    2025/07/31
        ${end_of_technical_support}    Set variable    2025/07/31
        ${remaining_days_software_development}    Subtract date from date    ${end_of_software_development}    ${current_date}
        ${remaining_days_technical_support}    Subtract date from date    ${end_of_technical_support}    ${current_date}
        ${remaining_days_software_development_human_readable}    Subtract date from date    ${end_of_software_development}    ${current_date}    verbose
        ${remaining_days_technical_support_human_readable}    Subtract date from date    ${end_of_technical_support}    ${current_date}    verbose
        IF    ${remaining_days_software_development} > 0 and ${remaining_days_technical_support} > 0
            Set to Dictionary    ${api_info_block}    remaining-days-software-development    ${remaining_days_software_development}
            Set to Dictionary    ${api_info_block}    remaining-days-technical-support    ${remaining_days_technical_support}
            Append to file    ${OUTPUT_DIR}/${status_output_file_name}    ======> Remaining Days of Software Development Support: ${remaining_days_software_development_human_readable}\n
            Append to file    ${OUTPUT_DIR}/${status_output_file_name}    ======> Remaining Days of Technical Support: ${remaining_days_technical_support_human_readable}\n
        ELSE IF    ${remaining_days_software_development} <= 0
            Log to console    \nWARNING: TMOS release has reached end of software development status in lifecycle. (https://my.f5.com/manage/s/article/K5903)
            Log    WARNING: TMOS release has reached end of software development status in lifecycle. (https://my.f5.com/manage/s/article/K5903)
            Append to file    ${OUTPUT_DIR}/${status_output_file_name}    ======> WARNING: TMOS release has reached end of software development status in lifecycle. (https://my.f5.com/manage/s/article/K5903)\n
        ELSE IF    ${remaining_days_technical_support} <= 0
            Log to console    \nWARNING: TMOS release has reached end of technical support status in lifecycle. (https://my.f5.com/manage/s/article/K5903)
            Log    WARNING: TMOS release has reached end of software development status in lifecycle. (https://my.f5.com/manage/s/article/K5903)
            Append to file    ${OUTPUT_DIR}/${status_output_file_name}    ======> WARNING: TMOS release has reached end of software development status in lifecycle. (https://my.f5.com/manage/s/article/K5903)\n
        END
    ELSE IF    "15.1." in "${bigip_version}"
        ${end_of_software_development}    Set variable    2024/12/31
        ${end_of_technical_support}    Set variable    2024/12/31
        ${remaining_days_software_development}    Subtract date from date    ${end_of_software_development}    ${current_date}
        ${remaining_days_technical_support}    Subtract date from date    ${end_of_technical_support}    ${current_date}
        ${remaining_days_software_development_human_readable}    Subtract date from date    ${end_of_software_development}    ${current_date}    verbose
        ${remaining_days_technical_support_human_readable}    Subtract date from date    ${end_of_technical_support}    ${current_date}    verbose
        IF    ${remaining_days_software_development} > 0 and ${remaining_days_technical_support} > 0
            Set to Dictionary    ${api_info_block}    remaining-days-software-development    ${remaining_days_software_development}
            Set to Dictionary    ${api_info_block}    remaining-days-technical-support    ${remaining_days_technical_support}
            Append to file    ${OUTPUT_DIR}/${status_output_file_name}    ======> Remaining Days of Software Development Support: ${remaining_days_software_development_human_readable}\n
            Append to file    ${OUTPUT_DIR}/${status_output_file_name}    ======> Remaining Days of Technical Support: ${remaining_days_technical_support_human_readable}\n
        ELSE IF    ${remaining_days_software_development} <= 0
            Log to console    \nWARNING: TMOS release has reached end of software development status in lifecycle. (https://my.f5.com/manage/s/article/K5903)
            Log    WARNING: TMOS release has reached end of software development status in lifecycle. (https://my.f5.com/manage/s/article/K5903)
            Append to file    ${OUTPUT_DIR}/${status_output_file_name}    ======> WARNING: TMOS release has reached end of software development status in lifecycle. (https://my.f5.com/manage/s/article/K5903)\n
        ELSE IF    ${remaining_days_technical_support} <= 0
            Log to console    \nWARNING: TMOS release has reached end of technical support status in lifecycle. (https://my.f5.com/manage/s/article/K5903)
            Log    WARNING: TMOS release has reached end of software development status in lifecycle. (https://my.f5.com/manage/s/article/K5903)
            Append to file    ${OUTPUT_DIR}/${status_output_file_name}    ======> WARNING: TMOS release has reached end of software development status in lifecycle. (https://my.f5.com/manage/s/article/K5903)\n
        END
    ELSE IF    "13.1." in "${bigip_version}" or "14.1." in "${bigip_version}"
        ${end_of_software_development}    Set variable    2023/12/31
        ${end_of_technical_support}    Set variable    2023/12/31
        ${remaining_days_software_development}    Subtract date from date    ${end_of_software_development}    ${current_date}
        ${remaining_days_technical_support}    Subtract date from date    ${end_of_technical_support}    ${current_date}
        ${remaining_days_software_development_human_readable}    Subtract date from date    ${end_of_software_development}    ${current_date}    verbose
        ${remaining_days_technical_support_human_readable}    Subtract date from date    ${end_of_technical_support}    ${current_date}    verbose
        IF    ${remaining_days_software_development} > 0 and ${remaining_days_technical_support} > 0
            Set to Dictionary    ${api_info_block}    remaining-days-software-development    ${remaining_days_software_development}
            Set to Dictionary    ${api_info_block}    remaining-days-technical-support    ${remaining_days_technical_support}
            Append to file    ${OUTPUT_DIR}/${status_output_file_name}    ======> Remaining Days of Software Development Support: ${remaining_days_software_development_human_readable}\n
            Append to file    ${OUTPUT_DIR}/${status_output_file_name}    ======> Remaining Days of Technical Support: ${remaining_days_technical_support_human_readable}\n
        ELSE IF    ${remaining_days_software_development} <= 0
            Log to console    \nWARNING: TMOS release has reached end of software development status in lifecycle. (https://my.f5.com/manage/s/article/K5903)
            Log    WARNING: TMOS release has reached end of software development status in lifecycle. (https://my.f5.com/manage/s/article/K5903)
            Append to file    ${OUTPUT_DIR}/${status_output_file_name}    ======> WARNING: TMOS Release has reached end of software development status in lifecycle. (https://my.f5.com/manage/s/article/K5903)\n
        ELSE IF    ${remaining_days_technical_support} <= 0
            Log to console    \nWARNING: TMOS release has reached end of technical support status in lifecycle. (https://my.f5.com/manage/s/article/K5903)
            Log    WARNING: TMOS release has reached end of software development status in lifecycle. (https://my.f5.com/manage/s/article/K5903)
            Append to file    ${OUTPUT_DIR}/${status_output_file_name}    ======> WARNING: TMOS Release has reached end of software development status in lifecycle. (https://my.f5.com/manage/s/article/K5903)\n
        END    
    ELSE
        Log to console    \nTMOS release ${bigip_version} has reached end of life. See https://my.f5.com/manage/s/article/K5903 for more information.
        Append to file    ${OUTPUT_DIR}/${status_output_file_name}    ======> TMOS release ${bigip_version} has reached end of life. See https://my.f5.com/manage/s/article/K5903 for more information.\n
    END

Retrieve BIG-IP NTP Configuration and Verify NTP Servers are Configured
    [Documentation]    Retrieves the NTP Configuration on the BIG-IP (https://my.f5.com/manage/s/article/K13380)
    ${retrieved_ntp_config_api}   Retrieve BIG-IP NTP Configuration via iControl REST    bigip_host=${bigip_host}   bigip_username=${bigip_username}   bigip_password=${bigip_password}
    Dictionary Should Contain Key    ${retrieved_ntp_config_api.json()}   servers
    ${retrieved_ntp_config_cli}   Retrieve BIG-IP NTP Configuration via TMSH        bigip_host=${bigip_host}   bigip_username=${bigip_username}   bigip_password=${bigip_password}
    Should Not Contain    ${retrieved_ntp_config_cli}   servers none

Retrieve and Verify BIG-IP NTP Status
    [Documentation]    Retrieves the NTP status on the BIG-IP (https://my.f5.com/manage/s/article/K10240)
    ${retrieved_ntp_status_cli}   Retrieve BIG-IP NTP Status via TMSH    bigip_host=${bigip_host}   bigip_username=${bigip_username}   bigip_password=${bigip_password}
    Verify BIG-IP NTP Server Associations    ${retrieved_ntp_status_cli}
    Set to Dictionary    ${api_info_block}    ntp-status    ${retrieved_ntp_status_cli}
    Append to file    ${OUTPUT_DIR}/${status_output_file_name}    ======> NTP Status:\n${retrieved_ntp_status_cli}\n

Verify BIG-IP Disk Space    
    [Documentation]    Verifies that the BIG-IP disk utilization is healthy. (https://my.f5.com/manage/s/article/K14403)
    ${df_output}    Retrieve BIG-IP Disk Space Utilization via TMSH    bigip_host=${bigip_host}   bigip_username=${bigip_username}   bigip_password=${bigip_password}
    Append to file    ${OUTPUT_DIR}/${status_output_file_name}    ======> Disk Space Utilization:\n${df_output}\n
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
                    Log to Console    \nWARNING: Filesystem ${target} is using ${used_pct} of available space! (https://my.f5.com/manage/s/article/K14403)
                    Append to file    ${OUTPUT_DIR}/${status_output_file_name}    ======> WARNING: Filesystem ${target} is using ${used_pct} of available space! (https://my.f5.com/manage/s/article/K14403)\n
                END
                ${inodes_used_pct}    Remove string    ${inodes_used_pct}    %
                IF    ${${inodes_used_pct}} > 90
                    Log to Console    \nWARNING: Filesystem ${target} is using a high percentage (${inodes_used_pct}) of available inodes! (https://my.f5.com/manage/s/article/K14403)
                    Append to file    ${OUTPUT_DIR}/${status_output_file_name}    ======> WARNING: Filesystem ${target} is using a high percentage of available inodes! (https://my.f5.com/manage/s/article/K14403)
                END
            END
        END
    END

Retrieve Top 20 Directories and Files by Size on Disk
    [Documentation]    Retrieves the top 20 directories on the BIG-IP by disk space size (https://my.f5.com/manage/s/article/K14403)
    [Teardown]    Run Keywords    SSHLibrary.Close All Connections    RequestsLibrary.Delete All Sessions
    SSHLibrary.Open connection    ${bigip_host}
    SSHLibrary.Login    username=${bigip_username}    password=${bigip_password}
    ${top_directories}    SSHLibrary.Execute command    bash -c "du --exclude=/proc/* -Sh / | sort -rh | head -n 20"
    Append to file    ${OUTPUT_DIR}/${status_output_file_name}    ======> Top directories on disk by size:\n${top_directories}\n
    ${top_files}    SSHLibrary.Execute command    bash -c "find / -type f -exec du --exclude=/proc/* -Sh {} + | sort -rh | head -n 20"
    Append to file    ${OUTPUT_DIR}/${status_output_file_name}    ======> Top files on disk by size:\n${top_files}\n

Verify BIG-IP High Availability Status
    [Documentation]    Retrieves the BIG-IP high availability status (https://my.f5.com/manage/s/article/K08452454)
    ${bigip_cm_devices_api}    Retrieve BIG-IP Cluster Management Device Configuration via iControl REST   bigip_host=${bigip_host}   bigip_username=${bigip_username}   bigip_password=${bigip_password}
    Set to Dictionary    ${api_info_block}    cm-devices    ${bigip_cm_devices_api}
    ${bigip_cm_devices_status_api}    Retrieve BIG-IP Cluster Management Device Status via iControl REST   bigip_host=${bigip_host}   bigip_username=${bigip_username}   bigip_password=${bigip_password}
    Set to Dictionary    ${api_info_block}    cm-devices-status    ${bigip_cm_devices_api}
    @{bigip_cm_device_groups_api}    Retrieve BIG-IP Cluster Management Device Group Configuration via iControl REST   bigip_host=${bigip_host}   bigip_username=${bigip_username}   bigip_password=${bigip_password}
    Set to Dictionary    ${api_info_block}    cm-device-groups    ${bigip_cm_device_groups_api}
    ${bigip_cm_device_groups_status_api}    Retrieve BIG-IP Cluster Management Device Group Status via iControl REST   bigip_host=${bigip_host}   bigip_username=${bigip_username}   bigip_password=${bigip_password}
    Set to Dictionary    ${api_info_block}    cm-device-groups-status    ${bigip_cm_device_groups_status_api}
    @{bigip_cm_traffic_groups_api}    Retrieve BIG-IP Cluster Management Traffic Group Configuration via iControl REST   bigip_host=${bigip_host}   bigip_username=${bigip_username}   bigip_password=${bigip_password}
    Set to Dictionary    ${api_info_block}    cm-traffic-groups    ${bigip_cm_traffic_groups_api}
    ${bigip_cm_traffic_groups_status_api}    Retrieve BIG-IP Cluster Management Traffic Group Status via iControl REST   bigip_host=${bigip_host}   bigip_username=${bigip_username}   bigip_password=${bigip_password}
    Set to Dictionary    ${api_info_block}    cm-traffic-groups-status    ${bigip_cm_traffic_groups_status_api}
    @{bigip_cm_trust_domains_api}    Retrieve BIG-IP Cluster Management Trust Domain Configuration via iControl REST   bigip_host=${bigip_host}   bigip_username=${bigip_username}   bigip_password=${bigip_password}
    Set to Dictionary    ${api_info_block}    cm-trust-domains    ${bigip_cm_trust_domains_api}
    ${bigip_cm_failover_status_api}    Retrieve BIG-IP Cluster Management Failover Status via iControl REST   bigip_host=${bigip_host}   bigip_username=${bigip_username}   bigip_password=${bigip_password}
    Set to Dictionary    ${api_info_block}    cm-failover-status    ${bigip_cm_failover_status_api}
    ${bigip_cm_devices_cli}    Retrieve BIG-IP Cluster Management Status via TMSH   bigip_host=${bigip_host}   bigip_username=${bigip_username}   bigip_password=${bigip_password}
    Append to file    ${OUTPUT_DIR}/${status_output_file_name}    ======> Cluster Management Status:\n${bigip_cm_devices_cli}\n

Verify Certificate/Key Status and Expiration
    [Documentation]
    [Teardown]    Run Keywords    SSHLibrary.Close All Connections    RequestsLibrary.Delete All Sessions
    SSHLibrary.Open connection    ${bigip_host}
    SSHLibrary.Login    username=${bigip_username}    password=${bigip_password}
    ${check-cert_output}    SSHLibrary.Execute command    bash -c "tmsh run sys crypto check-cert verbose enabled"
    Append to file    ${OUTPUT_DIR}/${status_output_file_name}    ======> Certificate Check Output:\n${check-cert_output}\n

Retrieve BIG-IP Interface Statistics
    [Documentation]
    ${interface_stats_api}    Retrieve BIG-IP Interface Statistics via iControl REST   bigip_host=${bigip_host}   bigip_username=${bigip_username}   bigip_password=${bigip_password}
    ${interface_stats_cli}    Retrieve BIG-IP Interface Statistics via TMSH   bigip_host=${bigip_host}   bigip_username=${bigip_username}   bigip_password=${bigip_password}
    Append to file    ${OUTPUT_DIR}/${statistics_output_file_name}    ======> Interface Statistics:\n${interface_stats_cli}\n

Retrieve BIG-IP VLAN Statistics
    [Documentation]
    ${vlan_stats_api}    Retrieve BIG-IP VLAN Statistics via iControl REST   bigip_host=${bigip_host}   bigip_username=${bigip_username}   bigip_password=${bigip_password}
    ${vlan_stats_cli}    Retrieve BIG-IP VLAN Statistics via TMSH   bigip_host=${bigip_host}   bigip_username=${bigip_username}   bigip_password=${bigip_password}
    Append to file    ${OUTPUT_DIR}/${statistics_output_file_name}    ======> VLAN Statistics:\n${vlan_stats_cli}\n

Retrieve Route Domain Information
    [Documentation]
    ${route_domain_stats_api}    Retrieve BIG-IP Route Domain Statistics via iControl REST   bigip_host=${bigip_host}   bigip_username=${bigip_username}   bigip_password=${bigip_password}
    ${route_domain_stats_cli}    Retrieve BIG-IP Route Domain Statistics via TMSH   bigip_host=${bigip_host}   bigip_username=${bigip_username}   bigip_password=${bigip_password}
    Append to file    ${OUTPUT_DIR}/${statistics_output_file_name}    ======> Route Domain Statistics:\n${route_domain_stats_cli}\n
    ${route_domain_dynamic_routing_protocols}    Set variable    temporary
    ${route_domain_dynamic_routing}    Set variable    temporary

Retrieve BIG-IP Trunk Statistics
    [Documentation]
    ${trunk_stats_api}    Retrieve BIG-IP Trunk Statistics via iControl REST   bigip_host=${bigip_host}   bigip_username=${bigip_username}   bigip_password=${bigip_password}
    ${trunk_stats_cli}    Retrieve BIG-IP Trunk Statistics via TMSH   bigip_host=${bigip_host}   bigip_username=${bigip_username}   bigip_password=${bigip_password}
    Append to file    ${OUTPUT_DIR}/${statistics_output_file_name}    ======> Trunk Statistics:\n${trunk_stats_cli}\n

Retrieve BIG-IP Self-IP Statistics
    [Documentation]
    ${self-ip_stats_api}    Retrieve BIG-IP Self IP Statistics via iControl REST   bigip_host=${bigip_host}   bigip_username=${bigip_username}   bigip_password=${bigip_password}
    ${self-ip_stats_cli}    Retrieve BIG-IP Self IP Statistics via TMSH   bigip_host=${bigip_host}   bigip_username=${bigip_username}   bigip_password=${bigip_password}
    Append to file    ${OUTPUT_DIR}/${statistics_output_file_name}    ======> Self-IP Statistics:\n${self-ip_stats_cli}\n

Retrieve BIG-IP Virtual Server Statistics
    [Documentation]
    ${virtual_server_stats_api}    Retrieve BIG-IP Virtual Server Statistics via iControl REST   bigip_host=${bigip_host}   bigip_username=${bigip_username}   bigip_password=${bigip_password}
    ${virtual_server_stats_cli}    Retrieve BIG-IP Virtual Server Statistics via TMSH   bigip_host=${bigip_host}   bigip_username=${bigip_username}   bigip_password=${bigip_password}
    Append to file    ${OUTPUT_DIR}/${statistics_output_file_name}    ======> Virtual Server Statistics:\n${virtual_server_stats_cli}\n

Retrieve BIG-IP Virtual Address Statistics
    [Documentation]
    ${virtual_server_stats_api}    Retrieve BIG-IP Virtual Address Statistics via iControl REST   bigip_host=${bigip_host}   bigip_username=${bigip_username}   bigip_password=${bigip_password}
    ${virtual_server_stats_cli}    Retrieve BIG-IP Virtual Address Statistics via TMSH   bigip_host=${bigip_host}   bigip_username=${bigip_username}   bigip_password=${bigip_password}
    Append to file    ${OUTPUT_DIR}/${statistics_output_file_name}    ======> Virtual Server Statistics:\n${virtual_server_stats_cli}\n

Retrieve Pool Statistics
    [Documentation]
    ${pool_stats_api}    Retrieve BIG-IP Pool Statistics via iControl REST   bigip_host=${bigip_host}   bigip_username=${bigip_username}   bigip_password=${bigip_password}
    ${pool_stats}    Get from dictionary    ${pool_stats_api.json()}    entries
    FOR    ${current_pool}    IN    ${pool_stats}
        Log to console    ${current_pool}
    END
    ${pool_stats_cli}    Retrieve BIG-IP Pool Statistics via TMSH   bigip_host=${bigip_host}   bigip_username=${bigip_username}   bigip_password=${bigip_password}
    Append to file    ${OUTPUT_DIR}/${statistics_output_file_name}    ======> Pool Statistics:\n${pool_stats_cli}\n
    
Retrieve BIG-IP Full Text Configuration via TMSH
    [Documentation]    Retrieve BIG-IPs the full BIG-IP configuration via list output
    [Teardown]    Run Keywords    SSHLibrary.Close All Connections    RequestsLibrary.Delete All Sessions
    SSHLibrary.Open connection    ${bigip_host}
    SSHLibrary.Login    username=${bigip_username}    password=${bigip_password}
    ${full_text_configuration}    SSHLibrary.Execute command    bash -c 'tmsh -q list / all-properties one-line recursive'
    Append to file    ${OUTPUT_DIR}/${status_output_file_name}   ======> Full Text Configuration:\n${full_text_configuration}\n

Retrieve BIG-IP Database Variables via TMSH
    [Documentation]    Retrieve BIG-IPs the full BIG-IP configuration via list output
    [Teardown]    Run Keywords    SSHLibrary.Close All Connections    RequestsLibrary.Delete All Sessions
    SSHLibrary.Open connection    ${bigip_host}
    SSHLibrary.Login    username=${bigip_username}    password=${bigip_password}
    ${full_text_configuration}    SSHLibrary.Execute command    bash -c 'tmsh -q list sys db all-properties one-line'
    Append to file    ${OUTPUT_DIR}/${status_output_file_name}   ======> Database Variables:\n${full_text_configuration}\n

Log API Responses in JSON
    [Documentation]    Creating a plain text block that can be diff'd between runs to view changes
    Log Dictionary   ${api_info_block}

