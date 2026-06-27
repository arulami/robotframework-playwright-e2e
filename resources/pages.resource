*** Settings ***
Documentation    Single import surface for all page/component keywords.
Library     Browser
Resource    keywords/browser_setup.resource
Resource    pages/login_page.resource
Resource    pages/inventory_page.resource
Resource    pages/cart_page.resource
Resource    pages/checkout_page.resource
# Add page/component resources here as they are created:
# Resource    components/header.resource
