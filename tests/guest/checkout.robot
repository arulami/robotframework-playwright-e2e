*** Settings ***
Resource          ../../resources/pages.resource
Test Setup        Open Application As Guest
Test Teardown     Close Application
Test Tags         checkout    guest

*** Test Cases ***
User Can Complete Checkout For A Single Product
    Log In With Credentials    standard_user    secret_sauce
    Inventory Page Should Be Displayed
    Add Product To Cart    sauce-labs-backpack
    Open Cart
    Cart Should Contain Product    Sauce Labs Backpack
    Cart Badge Count Should Be    1
    Proceed To Checkout
    Enter Customer Information    John    Doe    12345
    Finish Order
    Order Confirmation Should Be Displayed
