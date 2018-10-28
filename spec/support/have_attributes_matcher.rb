# frozen_string_literal: true

require 'rspec/expectations'

RSpec::Matchers.define :have_attributes_from do |expected|
  using OrangeData::StringExt unless "".respond_to?(:underscore)

  match do |actual|
    schema = OrangeData::PAYLOAD_SCHEMA["definitions"][expected]["properties"]
    expected_attributes = schema.map{|k, v| v["x-name"] || k.underscore }
    @missing = expected_attributes.reject{|k| actual.respond_to?(k) }
    # TODO: check setters?
    @missing_setters = [] # expected_attributes.reject{|k| actual.respond_to?("#{k}=") }
    @missing == [] && @missing_setters == []
  end

  failure_message do |actual|
    [
      "expected #{actual} to have all attributes from definitions.#{expected}.properties",
      @missing.size > 0 && "missing getters: #{@missing}" || nil,
      @missing_setters.size > 0 && "missing setters: #{@missing_setters}" || nil,
    ].compact.join("\n")
  end
end
