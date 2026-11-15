*** Settings ***
Library    SSHLibrary

*** Variables ***
${HOST}       erpnext.example.org
# App list in the frappe_docker apps.json format: the image is built with
# ERPNext, and ERPNext is the app installed on the site
${APPS}       [{"url":"https://github.com/frappe/erpnext","branch":"version-15","app_name":"erpnext"}]
# A record of the site that the backup must keep
${TODO}       ns8-backup-check

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

Run bench
    [Arguments]    ${module}    ${args}
    ${output}  ${rc} =    Execute Command    runagent -m ${module} podman exec backend bench ${args}
    ...    return_rc=True
    Should Be Equal As Integers    ${rc}  0
    RETURN    ${output}

Site has the test ToDo
    [Arguments]    ${module}
    ${output} =    Run bench    ${module}    --site frontend execute frappe.client.get_count --kwargs '{"doctype":"ToDo","filters":{"description":"${TODO}"}}'
    # bench execute prints the count on the last line (nothing for 0)
    ${counts} =    Evaluate    [l.strip() for l in $output.splitlines() if l.strip().isdigit()]
    Should Not Be Empty    ${counts}
    Should Be Equal As Strings    ${counts}[-1]    1

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
    ${config} =    Evaluate    json.loads($output)    modules=json
    Should Be Equal    ${config}[host]    ${HOST}
    Should Be Equal    ${config}[frappeVersion]    version-15
    Should Be Equal    ${config}[erpSelectedModules]    ${{["erpnext"]}}
    Should Be Equal    ${config}[apps][0][url]    https://github.com/frappe/erpnext

Check if erpnext works as expected
    # create-site makes the site and installs the selected apps after the
    # services start: wait for the site, then for the web page
    Wait Until Keyword Succeeds    30 minutes    20 seconds    ERPNext site has the app    erpnext
    Wait Until Keyword Succeeds    10 minutes    10 seconds    ERPNext answers through Traefik

Check if a record can be added to the site
    ${output} =    Run bench    ${module_id}    --site frontend execute frappe.client.insert --kwargs '{"doc":{"doctype":"ToDo","description":"${TODO}"}}'
    Should Contain    ${output}    ${TODO}
    Site has the test ToDo    ${module_id}

Check if module-dump-state dumps every site
    ${rc} =    Execute Command    runagent -m ${module_id} module-dump-state
    ...    return_rc=True  return_stdout=False
    Should Be Equal As Integers    ${rc}  0
    ${rc} =    Execute Command    runagent -m ${module_id} grep -q ${TODO} dumps/frontend/database.sql
    ...    return_rc=True  return_stdout=False
    Should Be Equal As Integers    ${rc}  0
    ${output}  ${rc} =    Execute Command    runagent -m ${module_id} cat dumps/frontend/site.json
    ...    return_rc=True
    Should Be Equal As Integers    ${rc}  0
    ${meta} =    Evaluate    json.loads($output)    modules=json
    Should Be Equal    ${meta}[site]    frontend
    ${apps} =    Evaluate    [a["name"] for a in $meta["apps"]]
    Should Contain    ${apps}    erpnext

Check if module-cleanup-state removes the dumps
    ${rc} =    Execute Command    runagent -m ${module_id} module-cleanup-state
    ...    return_rc=True  return_stdout=False
    Should Be Equal As Integers    ${rc}  0
    ${rc} =    Execute Command    runagent -m ${module_id} test -e dumps
    ...    return_rc=True  return_stdout=False
    Should Not Be Equal As Integers    ${rc}  0

Check if the NethServer backup saves the instance
    # The local WebDAV destination of the node
    ${output}  ${rc} =    Execute Command    api-cli run cluster/list-cluster-backup-endpoints
    ...    return_rc=True
    Should Be Equal As Integers    ${rc}  0
    ${url} =    Evaluate    json.loads($output)["endpoints"][0]["url"]    modules=json
    ${output}  ${rc} =    Execute Command    api-cli run cluster/add-backup-repository --data '{"name":"erpnext-test","provider":"cluster","url":"${url}","password":"","parameters":{}}'
    ...    return_rc=True
    Should Be Equal As Integers    ${rc}  0
    ${repository} =    Evaluate    json.loads($output)["id"]    modules=json
    Set Suite Variable    ${repository}
    ${output}  ${rc} =    Execute Command    api-cli run cluster/add-backup --data '{"name":"erpnext-test","repository":"${repository}","schedule":"daily","retention":1,"instances":["${module_id}"],"enabled":true}'
    ...    return_rc=True
    Should Be Equal As Integers    ${rc}  0
    ${backup_id} =    Evaluate    int($output)
    Set Suite Variable    ${backup_id}
    # module-backup runs module-dump-state, Restic, then module-cleanup-state
    ${rc} =    Execute Command    api-cli run cluster/run-backup --data '{"id":${backup_id}}'
    ...    return_rc=True  return_stdout=False
    Should Be Equal As Integers    ${rc}  0
    ${rc} =    Execute Command    runagent -m ${module_id} test -e dumps
    ...    return_rc=True  return_stdout=False
    Should Not Be Equal As Integers    ${rc}  0
    ${uuid}  ${rc} =    Execute Command    runagent -m ${module_id} printenv MODULE_UUID
    ...    return_rc=True
    Should Be Equal As Integers    ${rc}  0
    Set Suite Variable    ${backup_path}    erpnext/${uuid.strip()}

Check if the instance restores from the backup
    # A new instance replaces the old one: the image is built again, then
    # the database of every site is restored
    ${output}  ${rc} =    Execute Command    api-cli run cluster/restore-module --data '{"repository":"${repository}","path":"${backup_path}","snapshot":"","node":1,"replace":true}'
    ...    return_rc=True
    Should Be Equal As Integers    ${rc}  0
    ${result} =    Evaluate    json.loads($output)    modules=json
    Should Not Be Equal    ${result}[module_id]    ${module_id}
    Set Suite Variable    ${module_id}    ${result}[module_id]

Check if the restored site has the data of the backup
    Site has the test ToDo    ${module_id}
    ERPNext site has the app    erpnext
    ${output}  ${rc} =    Execute Command    api-cli run module/${module_id}/get-configuration --data '{}'
    ...    return_rc=True
    Should Be Equal As Integers    ${rc}  0
    ${config} =    Evaluate    json.loads($output)    modules=json
    Should Be Equal    ${config}[host]    ${HOST}
    Should Not Be True    ${config}[lets_encrypt]
    Should Be Equal    ${config}[erpSelectedModules]    ${{["erpnext"]}}
    Wait Until Keyword Succeeds    10 minutes    10 seconds    ERPNext answers through Traefik

Check if the test backup is removed
    ${rc} =    Execute Command    api-cli run cluster/remove-backup --data '{"id":${backup_id}}'
    ...    return_rc=True  return_stdout=False
    Should Be Equal As Integers    ${rc}  0
    ${rc} =    Execute Command    api-cli run cluster/remove-backup-repository --data '{"id":"${repository}"}'
    ...    return_rc=True  return_stdout=False
    Should Be Equal As Integers    ${rc}  0

Check if erpnext is removed correctly
    ${rc} =    Execute Command    remove-module --no-preserve ${module_id}
    ...    return_rc=True  return_stdout=False
    Should Be Equal As Integers    ${rc}  0
