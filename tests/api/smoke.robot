*** Settings ***
Resource          ../../resources/api.resource
Suite Setup       Create Api Session
Suite Teardown    Delete All Sessions
Test Tags         smoke    api

*** Test Cases ***
Api Is Reachable
    [Documentation]    # TODO: replace with a real endpoint check
    ${response}=    GET On Session    api    /    expected_status=any
    Should Be True    ${response.status_code} < 500
