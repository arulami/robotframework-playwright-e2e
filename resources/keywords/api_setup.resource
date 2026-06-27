*** Settings ***
Library      RequestsLibrary
Library      Collections

*** Keywords ***
Create Api Session
    [Documentation]    Opens an authenticated REST session reused across the suite.
    ${headers}=    Create Dictionary    Authorization=Bearer %{API_TOKEN}
    Create Session    api    ${API_BASE_URL}    headers=${headers}
