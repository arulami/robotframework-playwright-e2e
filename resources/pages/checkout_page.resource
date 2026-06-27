*** Settings ***
Library    Browser

*** Variables ***
${CHECKOUT_FIRST_NAME}       [data-test="firstName"]
${CHECKOUT_LAST_NAME}        [data-test="lastName"]
${CHECKOUT_POSTAL_CODE}      [data-test="postalCode"]
${CHECKOUT_CONTINUE}         [data-test="continue"]
${CHECKOUT_FINISH}           [data-test="finish"]
${CHECKOUT_COMPLETE_HEADER}  [data-test="complete-header"]

*** Keywords ***
Enter Customer Information
    [Documentation]    Fills the checkout information form and continues to the order overview step.
    [Arguments]    ${first_name}    ${last_name}    ${postal_code}
    Fill Text    ${CHECKOUT_FIRST_NAME}     ${first_name}
    Fill Text    ${CHECKOUT_LAST_NAME}      ${last_name}
    Fill Text    ${CHECKOUT_POSTAL_CODE}    ${postal_code}
    Click        ${CHECKOUT_CONTINUE}
    Get Url      *=    /checkout-step-two.html

Finish Order
    [Documentation]    Confirms the order on the overview step and lands on the completion page.
    Click      ${CHECKOUT_FINISH}
    Get Url    *=    /checkout-complete.html

Order Confirmation Should Be Displayed
    [Documentation]    Asserts the order completion banner is shown.
    Get Text    ${CHECKOUT_COMPLETE_HEADER}    ==    Thank you for your order!
