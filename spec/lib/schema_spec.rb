RSpec.describe "Data Schema" do

  before(:all) do
    require 'json-schema'
  end

  subject{ OrangeData.data_schema_definitions }

  let(:extensions_metaschema){ YAML.load_file(File.expand_path('extensions_metaschema.yml', __dir__)) }

  it "extension metaschema is a valid schema" do
    expect(JSON::Validator.fully_validate_schema(extensions_metaschema, version: :draft4)).to eq([])
  end

  it "data schema is a valid json-schema" do
    # OpenAPI is based on draft5, which has the schema of draft4
    expect(JSON::Validator.fully_validate_schema(subject, version: :draft4)).to eq([])
    expect(JSON::Validator.fully_validate(extensions_metaschema, subject, version: :draft4)).to eq([])
  end

end
