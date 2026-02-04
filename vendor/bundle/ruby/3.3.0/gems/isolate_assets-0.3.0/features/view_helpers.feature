Feature: View Helpers
  As a Rails engine developer
  I want view helpers to generate asset tags
  So that I can easily include my engine's assets in views

  Scenario: Stylesheet link tag includes fingerprint
    When I visit the dummy engine root
    Then the page should have a stylesheet link to "/dummy/assets/application.css"
    And the stylesheet link should include a fingerprint parameter

  Scenario: Import map includes engine JavaScript files
    When I visit the dummy engine root
    Then the page should have an import map
    And the import map should include "dummy/application"

  Scenario: Image tag includes fingerprint
    When I visit the dummy engine root
    Then the page should have an image tag with src starting with "/dummy/assets/logo.png"
    And the image tag should include a fingerprint parameter
