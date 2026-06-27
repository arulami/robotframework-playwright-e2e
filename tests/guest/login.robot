*** Settings ***
Resource          ../../resources/pages.resource
Test Setup        Open Application As Guest
Test Teardown     Close Application
Test Tags         login    guest

*** Test Cases ***
User Can Log In With Valid Credentials
    Log In With Credentials    standard_user    secret_sauce
    Inventory Page Should Be Displayed

Locked Out User Sees An Error
    Log In With Credentials    locked_out_user    secret_sauce
    Login Error Should Be    Epic sadface: Sorry, this user has been locked out.
