*** Settings ***
Library      Browser

*** Keywords ***
Open Application As Guest
    [Documentation]    Opens an unauthenticated context at the home page.
    New Browser    chromium    headless=${HEADLESS}
    New Context    baseURL=${BASE_URL}    viewport={'width': 1280, 'height': 720}
    Set Browser Timeout    60s
    New Page       /

Open Authenticated Browser
    [Documentation]    Opens a context restored from a saved storageState file.
    [Arguments]    ${state_file}
    New Browser    chromium    headless=${HEADLESS}
    New Context    baseURL=${BASE_URL}    storageState=${state_file}    viewport={'width': 1280, 'height': 720}
    Set Browser Timeout    60s
    New Page       /

Close Application
    [Documentation]    Tears down the browser; runs even on failure.
    Close Browser
