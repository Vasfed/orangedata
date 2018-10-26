RSpec.describe "Data Schema" do

  subject{ OrangeData::PAYLOAD_SCHEMA }
  let(:extensions_metaschema){ YAML.load_file(File.expand_path('extensions_metaschema.yml', __dir__)) }

  it "extension metaschema is a valid schema" do
    expect(JSON::Validator.fully_validate_schema(extensions_metaschema, version: :draft4)).to eq([])
  end

  it "data schema is a valid json-schema" do
    # OpenAPI is based on draft5, which has the schema of draft4
    expect(JSON::Validator.fully_validate_schema(subject, version: :draft4)).to eq([])
    expect(JSON::Validator.fully_validate(extensions_metaschema, subject)).to eq([])
  end

  it "x-enum and x-bitfield are exclusive" do
    expect(JSON::Validator.fully_validate(extensions_metaschema, {
      "x-bitfield": { a: { bit: 1 }},
      "x-enum": { a: { val: 1 }}
      })).not_to eq([])
  end

end
