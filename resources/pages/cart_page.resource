*** Settings ***
Library    Browser

*** Variables ***
${CART_ITEM_NAME}     [data-test="inventory-item-name"]
${CART_BADGE}         [data-test="shopping-cart-badge"]
${CHECKOUT_BUTTON}    [data-test="checkout"]

*** Keywords ***
Cart Should Contain Product
    [Documentation]    Confirms the named product is listed in the cart.
    [Arguments]    ${product_name}
    Get Text    ${CART_ITEM_NAME}    ==    ${product_name}

Cart Badge Count Should Be
    [Documentation]    Asserts the cart badge shows the expected item count.
    [Arguments]    ${count}
    Get Text    ${CART_BADGE}    ==    ${count}

Proceed To Checkout
    [Documentation]    Starts checkout from the cart and lands on the information step.
    Click      ${CHECKOUT_BUTTON}
    Get Url    *=    /checkout-step-one.html
