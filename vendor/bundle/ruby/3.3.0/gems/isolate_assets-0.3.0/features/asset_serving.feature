Feature: Asset Serving
  As a Rails engine developer
  I want to serve JavaScript and CSS assets from my engine
  So that my engine's UI works without depending on the host app's asset pipeline

  Scenario: Serving a JavaScript file
    When I request "/dummy/assets/application.js"
    Then I should receive a successful response
    And the content type should be "application/javascript"
    And the response should contain "Dummy engine loaded"

  Scenario: Serving a CSS file
    When I request "/dummy/assets/application.css"
    Then I should receive a successful response
    And the content type should be "text/css"
    And the response should contain "font-family: sans-serif"

  Scenario: Serving an image file
    When I request "/dummy/assets/logo.png"
    Then I should receive a successful response
    And the content type should be "image/png"

  Scenario: Asset fingerprinting
    When I request "/dummy/assets/application.js"
    Then the response should have caching headers

  Scenario: Missing asset returns 404
    When I request "/dummy/assets/nonexistent.js"
    Then I should receive a not found response

  Scenario: Path traversal is blocked
    When I request "/dummy/assets/../../lib/dummy.rb"
    Then I should receive a not found response
