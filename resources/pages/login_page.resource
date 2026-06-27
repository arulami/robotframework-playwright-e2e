*** Settings ***
Library    Browser

*** Variables ***
${LOGIN_USERNAME}    [data-test="username"]
${LOGIN_PASSWORD}    [data-test="password"]
${LOGIN_SUBMIT}      [data-test="login-button"]
${LOGIN_ERROR}       [data-test="error"]

*** Keywords ***
Log In With Credentials
    [Documentation]    Submits the login form. Outcome (inventory page or error) is asserted by the caller.
    [Arguments]    ${username}    ${password}
    Fill Text    ${LOGIN_USERNAME}    ${username}
    Fill Text    ${LOGIN_PASSWORD}    ${password}
    Click        ${LOGIN_SUBMIT}

Login Error Should Be
    [Documentation]    Asserts the login error banner shows the expected message.
    [Arguments]    ${message}
    Get Text    ${LOGIN_ERROR}    ==    ${message}
