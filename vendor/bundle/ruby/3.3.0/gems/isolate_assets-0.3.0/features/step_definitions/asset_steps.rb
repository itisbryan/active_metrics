# frozen_string_literal: true

When("I request {string}") do |path|
  visit path
end

Then("I should receive a successful response") do
  expect(page.status_code).to eq(200)
end

Then("I should receive a not found response") do
  expect(page.status_code).to eq(404)
end

Then("the content type should be {string}") do |content_type|
  expect(page.response_headers["Content-Type"]).to include(content_type)
end

Then("the response should contain {string}") do |text|
  expect(page.body).to include(text)
end

Then("the response should have caching headers") do
  expect(page.response_headers["Cache-Control"]).to match(/max-age=\d+/)
  expect(page.response_headers["Cache-Control"]).to include("public")
  expect(page.response_headers["ETag"]).to be_present
end
