*** Settings ***
Library    SSHLibrary

*** Variables ***
${HOST}       erpnext.example.org
# App list in the frappe_docker apps.json format: the image is built with
# ERPNext, and ERPNext is the app installed on the site
${APPS}       [{"url":"https://github.com/frappe/erpnext","branch":"version-15","app_name":"erpnext"}]

*** Keywords ***
ERPNext site has the app
    [Arguments]    ${app}
    ${output}  ${rc} =    Execute Command    runagent -m ${module_id} podman exec backend bench --site frontend list-apps
    ...    return_rc=True
    Should Be Equal As Integers    ${rc}  0
    Should Contain    ${output}    ${app}

ERPNext answers through Traefik
    ${rc} =    Execute Command    curl -k -s -o /dev/null -f --resolve ${HOST}:443:127.0.0.1 https://${HOST}/login
    ...    return_rc=True  return_stdout=False
    Should Be Equal As Integers    ${rc}  0

*** Test Cases ***
Check if erpnext is installed correctly
    ${output}  ${rc} =    Execute Command    add-module ${IMAGE_URL} 1
    ...    return_rc=True
    Should Be Equal As Integers    ${rc}  0
    &{output} =    Evaluate    ${output}
    Set Suite Variable    ${module_id}    ${output.module_id}

Check if an app outside the app list is refused
    # Validated before the image build: the answer is immediate
    ${rc} =    Execute Command    api-cli run module/${module_id}/configure-module --data '{"host":"${HOST}","http2https":true,"lets_encrypt":false,"frappeVersion":"version-15","apps":${APPS},"erpSelectedModules":["hrms"]}'
    ...    return_rc=True  return_stdout=False
    Should Not Be Equal As Integers    ${rc}  0

Check if erpnext can be configured
    # Builds the image with the apps of the list: this takes several minutes
    ${rc} =    Execute Command    api-cli run module/${module_id}/configure-module --data '{"host":"${HOST}","http2https":true,"lets_encrypt":false,"frappeVersion":"version-15","apps":${APPS},"erpSelectedModules":["erpnext"]}'
    ...    return_rc=True  return_stdout=False
    Should Be Equal As Integers    ${rc}  0

Check if erpnext configuration reads back
    ${output}  ${rc} =    Execute Command    api-cli run module/${module_id}/get-configuration --data '{}'
    ...    return_rc=True
    Should Be Equal As Integers    ${rc}  0
    ${config} =    Evaluate    json.loads('''${output}''')    modules=json
    Should Be Equal    ${config}[host]    ${HOST}
    Should Be Equal    ${config}[frappeVersion]    version-15
    Should Be Equal    ${config}[erpSelectedModules]    ${{["erpnext"]}}
    Should Be Equal    ${config}[apps][0][url]    https://github.com/frappe/erpnext

Check if erpnext works as expected
    # create-site makes the site and installs the selected apps after the
    # services start: wait for the site, then for the web page
    Wait Until Keyword Succeeds    30 minutes    20 seconds    ERPNext site has the app    erpnext
    Wait Until Keyword Succeeds    10 minutes    10 seconds    ERPNext answers through Traefik

Check if erpnext is removed correctly
    ${rc} =    Execute Command    remove-module --no-preserve ${module_id}
    ...    return_rc=True  return_stdout=False
    Should Be Equal As Integers    ${rc}  0
