*** Settings ***
Library    Browser

*** Variables ***
${INVENTORY_TITLE}    [data-test="title"]
${CART_LINK}          [data-test="shopping-cart-link"]

*** Keywords ***
Inventory Page Should Be Displayed
    [Documentation]    Confirms a successful login landed on the products inventory page.
    Get Url     *=    /inventory.html
    Get Text    ${INVENTORY_TITLE}    ==    Products

Add Product To Cart
    [Documentation]    Adds the product with the given slug to the cart; confirms the button toggled to Remove.
    [Arguments]    ${product_slug}
    VAR    ${add_to_cart_button}       [data-test="add-to-cart-${product_slug}"]
    VAR    ${remove_from_cart_button}    [data-test="remove-${product_slug}"]
    Click                 ${add_to_cart_button}
    Get Element States    ${remove_from_cart_button}    *=    visible

Open Cart
    [Documentation]    Opens the shopping cart from the inventory header and lands on the cart page.
    Click      ${CART_LINK}
    Get Url    *=    /cart.html
