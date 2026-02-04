# frozen_string_literal: true

When("I visit the dummy engine root") do
  visit "/dummy"
end

Then("the page should have a stylesheet link to {string}") do |path|
  expect(page).to have_css("link[rel='stylesheet'][href^='#{path}']", visible: false)
end

Then("the stylesheet link should include a fingerprint parameter") do
  link = page.find("link[rel='stylesheet']", visible: false)
  expect(link[:href]).to match(/\?v=[a-f0-9]{8}/)
end

Then("the page should have an import map") do
  expect(page).to have_css("script[type='importmap']", visible: false)
end

Then("the import map should include {string}") do |key|
  script = page.find("script[type='importmap']", visible: false)
  import_map = JSON.parse(script.text(:all))
  expect(import_map["imports"]).to have_key(key)
end

Then("the page should have an image tag with src starting with {string}") do |path|
  expect(page).to have_css("img[src^='#{path}']", visible: false)
end

Then("the image tag should include a fingerprint parameter") do
  img = page.find("img", visible: false)
  expect(img[:src]).to match(/\?v=[a-f0-9]{8}/)
end
