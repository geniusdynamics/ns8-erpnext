*** Settings ***
Library    SSHLibrary
Library    Collections

*** Variables ***
${HOST}       erpnext.example.org
# App list in the frappe_docker apps.json format: the image is built with
# ERPNext, and ERPNext is the app installed on the site
${APPS}       [{"url":"https://github.com/frappe/erpnext","branch":"version-15","app_name":"erpnext","title":"ERPNext"}]
# A record of the site that the backup must keep
${TODO}       ns8-backup-check
# A second site, with its own host name and route
${SITE2}      erp2.example.org
${SITE2_PW}   Nethesis,1234

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

Site has the app
    [Arguments]    ${site}    ${app}
    ${output} =    Run bench    ${module_id}    --site ${site} list-apps
    Should Contain    ${output}    ${app}

Administrator logs in on
    [Arguments]    ${host}    ${password}
    ${rc} =    Execute Command    curl -k -s -f -o /dev/null --resolve ${host}:443:127.0.0.1 -X POST -d usr=Administrator -d pwd=${password} https://${host}/api/method/login
    ...    return_rc=True  return_stdout=False
    RETURN    ${rc}

Second site answers on its host
    ${rc} =    Administrator logs in on    ${SITE2}    ${SITE2_PW}
    Should Be Equal As Integers    ${rc}  0

Second site is online
    ${sites} =    Sites of the instance
    Should Be True    ${sites}[${SITE2}][online]
    Should Be Equal    ${sites}[${SITE2}][certificate]    not_valid

Pins of the image
    ${output}  ${rc} =    Execute Command    runagent -m ${module_id} cat image-pins.json
    ...    return_rc=True
    Should Be Equal As Integers    ${rc}  0
    ${pins} =    Evaluate    json.loads($output)    modules=json
    RETURN    ${pins}

HTTP status of the default site
    ${code} =    Execute Command    curl -k -s -o /dev/null -w '%{http_code}' --resolve ${HOST}:443:127.0.0.1 https://${HOST}/login
    RETURN    ${code}

Sites of the instance
    ${output}  ${rc} =    Execute Command    api-cli run module/${module_id}/list-sites --data '{}'
    ...    return_rc=True
    Should Be Equal As Integers    ${rc}  0
    ${sites} =    Evaluate    {s["name"]: s for s in json.loads($output)["sites"]}    modules=json
    RETURN    ${sites}

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
    Should Be Equal    ${config}[apps][0][title]    ERPNext
    Should Not Be True    ${config}[hasGitToken]

Check if the marketplace lists apps for the Frappe version
    ${output}  ${rc} =    Execute Command    api-cli run module/${module_id}/list-marketplace-apps --data '{"frappeVersion":"version-15"}'
    ...    return_rc=True
    Should Be Equal As Integers    ${rc}  0
    ${apps} =    Evaluate    {a["app_name"]: a for a in json.loads($output)["apps"]}    modules=json
    Should Be Equal    ${apps}[hrms][branch]    version-15
    Should Be Equal    ${apps}[hrms][url]    https://github.com/frappe/hrms

Check if the GitHub token is stored as a secret
    # Same apps: the image build is skipped
    ${rc} =    Execute Command    api-cli run module/${module_id}/build-docker-image --data '{"frappeVersion":"version-15","apps":${APPS},"erpSelectedModules":["erpnext"],"gitToken":"ghp_ns8testtoken0123456789"}'
    ...    return_rc=True  return_stdout=False
    Should Be Equal As Integers    ${rc}  0
    ${output}  ${rc} =    Execute Command    api-cli run module/${module_id}/get-configuration --data '{}'
    ...    return_rc=True
    Should Be Equal As Integers    ${rc}  0
    Should Not Contain    ${output}    ghp_ns8testtoken
    ${config} =    Evaluate    json.loads($output)    modules=json
    Should Be True    ${config}[hasGitToken]
    ${mode}  ${rc} =    Execute Command    runagent -m ${module_id} stat -c %a git-token
    ...    return_rc=True
    Should Be Equal As Strings    ${mode.strip()}    600
    ${rc} =    Execute Command    api-cli run module/${module_id}/build-docker-image --data '{"frappeVersion":"version-15","apps":${APPS},"erpSelectedModules":["erpnext"],"clearGitToken":true}'
    ...    return_rc=True  return_stdout=False
    Should Be Equal As Integers    ${rc}  0
    ${rc} =    Execute Command    runagent -m ${module_id} test -e git-token
    ...    return_rc=True  return_stdout=False
    Should Not Be Equal As Integers    ${rc}  0

Check if erpnext works as expected
    # create-site makes the site and installs the selected apps after the
    # services start: wait for the site, then for the web page
    Wait Until Keyword Succeeds    30 minutes    20 seconds    ERPNext site has the app    erpnext
    Wait Until Keyword Succeeds    10 minutes    10 seconds    ERPNext answers through Traefik

Check if the image build is pinned
    ${pins} =    Pins of the image
    Should Be Equal    ${pins}[frappe_branch]    version-15
    Should Match Regexp    ${pins}[apps][frappe]    ^[0-9a-f]{40}$
    Should Match Regexp    ${pins}[apps][erpnext]    ^[0-9a-f]{40}$
    Should Contain    ${pins}[base_image]    @sha256:
    Should Contain    ${pins}[build_image]    @sha256:
    Set Suite Variable    ${erpnext_commit}    ${pins}[apps][erpnext]

Check if a site goes into maintenance mode
    ${rc} =    Execute Command    api-cli run module/${module_id}/set-site-maintenance --data '{"name":"frontend","enabled":true}'
    ...    return_rc=True  return_stdout=False
    Should Be Equal As Integers    ${rc}  0
    ${sites} =    Sites of the instance
    Should Be True    ${sites}[frontend][maintenance]
    ${code} =    HTTP status of the default site
    Should Be Equal As Strings    ${code}    503
    ${rc} =    Execute Command    api-cli run module/${module_id}/set-site-maintenance --data '{"name":"frontend","enabled":false}'
    ...    return_rc=True  return_stdout=False
    Should Be Equal As Integers    ${rc}  0
    ${sites} =    Sites of the instance
    Should Not Be True    ${sites}[frontend][maintenance]
    ${code} =    HTTP status of the default site
    Should Be Equal As Strings    ${code}    200

Check if the status of a site reads back
    ${output}  ${rc} =    Execute Command    api-cli run module/${module_id}/get-site-status --data '{"name":"frontend"}'
    ...    return_rc=True
    Should Be Equal As Integers    ${rc}  0
    ${status} =    Evaluate    json.loads($output)    modules=json
    Should Be Equal    ${status}[site]    frontend
    Should Be True    ${status}[scheduler_enabled]
    Should Not Be True    ${status}[scheduler_paused]
    Dictionary Should Not Contain Key    ${status}    queue_error
    Should Be True    ${status}[workers] >= 1
    Should Be True    isinstance($status["failed"], int)
    Dictionary Should Contain Key    ${status}[queued]    long

Check if the retention removes old frappe backups
    ${rc} =    Execute Command    runagent -m ${module_id} podman exec backend sh -c 'mkdir -p sites/frontend/private/backups && for i in 1 2 3 4 5; do touch sites/frontend/private/backups/2020010\${i}_000000-frontend-database.sql.gz; done'
    ...    return_rc=True  return_stdout=False
    Should Be Equal As Integers    ${rc}  0
    ${output}  ${rc} =    Execute Command    api-cli run module/${module_id}/set-backup-retention --data '{"keep":2,"max_age_days":0}'
    ...    return_rc=True
    Should Be Equal As Integers    ${rc}  0
    ${result} =    Evaluate    json.loads($output)    modules=json
    Should Be Equal As Integers    ${result}[deleted]    3
    ${output}  ${rc} =    Execute Command    runagent -m ${module_id} podman exec backend sh -c 'ls sites/frontend/private/backups/'
    ...    return_rc=True
    Should Contain    ${output}    20200105_000000
    Should Contain    ${output}    20200104_000000
    Should Not Contain    ${output}    20200103_000000
    ${output}  ${rc} =    Execute Command    api-cli run module/${module_id}/get-configuration --data '{}'
    ...    return_rc=True
    ${config} =    Evaluate    json.loads($output)    modules=json
    Should Be Equal As Integers    ${config}[backupRetention][keep]    2
    ${rc} =    Execute Command    api-cli run module/${module_id}/set-backup-retention --data '{"keep":3,"max_age_days":7}'
    ...    return_rc=True  return_stdout=False
    Should Be Equal As Integers    ${rc}  0

Check if the sites are dumped before an update migrates them
    ${rc} =    Execute Command    runagent -m ${module_id} ../update-module.d/05dump_sites
    ...    return_rc=True  return_stdout=False
    Should Be Equal As Integers    ${rc}  0
    ${rc} =    Execute Command    runagent -m ${module_id} grep -q tabToDo pre-update-dumps/frontend/database.sql
    ...    return_rc=True  return_stdout=False
    Should Be Equal As Integers    ${rc}  0

Check if a record can be added to the site
    ${output} =    Run bench    ${module_id}    --site frontend execute frappe.client.insert --kwargs '{"doc":{"doctype":"ToDo","description":"${TODO}"}}'
    Should Contain    ${output}    ${TODO}
    Site has the test ToDo    ${module_id}

Check if a second site can be added
    # Creates the site and installs ERPNext on it: a few minutes
    ${rc} =    Execute Command    api-cli run module/${module_id}/add-site --data '{"host":"${SITE2}","http2https":true,"lets_encrypt":false,"admin_password":"${SITE2_PW}","apps":["erpnext"]}'
    ...    return_rc=True  return_stdout=False
    Should Be Equal As Integers    ${rc}  0
    ${sites} =    Sites of the instance
    Should Be True    ${sites}[frontend][default]
    Should Contain    ${sites}[frontend][apps]    erpnext
    Should Be Equal    ${sites}[${SITE2}][host]    ${SITE2}
    Should Contain    ${sites}[${SITE2}][apps]    erpnext
    Should Not Be True    ${sites}[${SITE2}][lets_encrypt]

Check if a site name already in use is refused
    ${rc} =    Execute Command    api-cli run module/${module_id}/add-site --data '{"host":"${SITE2}","admin_password":"${SITE2_PW}"}'
    ...    return_rc=True  return_stdout=False
    Should Not Be Equal As Integers    ${rc}  0
    ${rc} =    Execute Command    api-cli run module/${module_id}/remove-site --data '{"name":"frontend"}'
    ...    return_rc=True  return_stdout=False
    Should Not Be Equal As Integers    ${rc}  0

Check if each host reaches its own site
    Wait Until Keyword Succeeds    5 minutes    10 seconds    Second site answers on its host
    Wait Until Keyword Succeeds    2 minutes    10 seconds    Second site is online
    # The password of the second site does not open the default site
    ${rc} =    Administrator logs in on    ${HOST}    ${SITE2_PW}
    Should Not Be Equal As Integers    ${rc}  0
    ${rc} =    Administrator logs in on    ${HOST}    admin
    Should Be Equal As Integers    ${rc}  0
    ERPNext answers through Traefik

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
    ${rc} =    Execute Command    runagent -m ${module_id} test -s dumps/${SITE2}/database.sql
    ...    return_rc=True  return_stdout=False
    Should Be Equal As Integers    ${rc}  0

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

Check if the restored instance is built from the same pins
    ${pins} =    Pins of the image
    Should Be Equal    ${pins}[apps][erpnext]    ${erpnext_commit}

Check if the restored second site has its route and data
    ${sites} =    Sites of the instance
    Should Contain    ${sites}[${SITE2}][apps]    erpnext
    Should Not Be True    ${sites}[${SITE2}][lets_encrypt]
    Wait Until Keyword Succeeds    5 minutes    10 seconds    Second site answers on its host

Check if the test backup is removed
    ${rc} =    Execute Command    api-cli run cluster/remove-backup --data '{"id":${backup_id}}'
    ...    return_rc=True  return_stdout=False
    Should Be Equal As Integers    ${rc}  0
    ${rc} =    Execute Command    api-cli run cluster/remove-backup-repository --data '{"id":"${repository}"}'
    ...    return_rc=True  return_stdout=False
    Should Be Equal As Integers    ${rc}  0

Check if an app can be uninstalled from a site
    ${output}  ${rc} =    Execute Command    api-cli run module/${module_id}/set-site-apps --data '{"name":"${SITE2}","apps":[]}'
    ...    return_rc=True
    Should Be Equal As Integers    ${rc}  0
    ${output} =    Run bench    ${module_id}    --site ${SITE2} list-apps
    Should Not Contain    ${output}    erpnext
    # The default site keeps its apps
    Site has the app    frontend    erpnext
    Second site answers on its host

Check if a site can be removed
    ${rc} =    Execute Command    api-cli run module/${module_id}/remove-site --data '{"name":"${SITE2}"}'
    ...    return_rc=True  return_stdout=False
    Should Be Equal As Integers    ${rc}  0
    ${sites} =    Sites of the instance
    Dictionary Should Not Contain Key    ${sites}    ${SITE2}
    ${rc} =    Execute Command    runagent -m ${module_id} podman exec backend test -e sites/${SITE2}
    ...    return_rc=True  return_stdout=False
    Should Not Be Equal As Integers    ${rc}  0
    Wait Until Keyword Succeeds    2 minutes    10 seconds    ERPNext answers through Traefik

Check if the removed site is archived
    ${output}  ${rc} =    Execute Command    api-cli run module/${module_id}/list-archived-sites --data '{}'
    ...    return_rc=True
    Should Be Equal As Integers    ${rc}  0
    ${archives} =    Evaluate    {a["name"]: a for a in json.loads($output)["archived_sites"]}    modules=json
    Should Be Equal    ${archives}[${SITE2}][site]    ${SITE2}
    Should Be True    ${archives}[${SITE2}][size] > 0

Check if a removed site can be restored
    ${rc} =    Execute Command    api-cli run module/${module_id}/restore-archived-site --data '{"name":"${SITE2}"}'
    ...    return_rc=True  return_stdout=False
    Should Be Equal As Integers    ${rc}  0
    ${sites} =    Sites of the instance
    Dictionary Should Contain Key    ${sites}    ${SITE2}
    Should Not Be True    ${sites}[${SITE2}][lets_encrypt]
    Wait Until Keyword Succeeds    5 minutes    10 seconds    Second site answers on its host

Check if a removed site can be deleted
    ${rc} =    Execute Command    api-cli run module/${module_id}/remove-site --data '{"name":"${SITE2}"}'
    ...    return_rc=True  return_stdout=False
    Should Be Equal As Integers    ${rc}  0
    ${rc} =    Execute Command    api-cli run module/${module_id}/delete-archived-site --data '{"name":"${SITE2}"}'
    ...    return_rc=True  return_stdout=False
    Should Be Equal As Integers    ${rc}  0
    ${output}  ${rc} =    Execute Command    api-cli run module/${module_id}/list-archived-sites --data '{}'
    ...    return_rc=True
    ${archives} =    Evaluate    [a["name"] for a in json.loads($output)["archived_sites"]]    modules=json
    Should Not Contain    ${archives}    ${SITE2}
    ${rc} =    Execute Command    api-cli run module/${module_id}/delete-archived-site --data '{"name":"${SITE2}"}'
    ...    return_rc=True  return_stdout=False
    Should Not Be Equal As Integers    ${rc}  0

Check if erpnext is removed correctly
    ${rc} =    Execute Command    remove-module --no-preserve ${module_id}
    ...    return_rc=True  return_stdout=False
    Should Be Equal As Integers    ${rc}  0
