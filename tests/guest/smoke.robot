*** Settings ***
Resource          ../../resources/pages.resource
Suite Setup       Open Application As Guest
Suite Teardown    Close Application
Test Tags         smoke    guest

*** Test Cases ***
Home Page Loads
    Get Url    *=    /
