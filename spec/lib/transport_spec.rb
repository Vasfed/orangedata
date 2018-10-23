# frozen_string_literal: true

RSpec.describe OrangeData::Transport do

  let(:test_credentials) do
    OrangeData::Credentials.from_hash(YAML.load_file(File.expand_path('../fixtures/credentials_short.yml', __dir__)))
  end

  subject{ OrangeData::Transport.new("https://apip.orangedata.ru:2443/api/v2/", test_credentials) }

  it "signs post requests" do
    expected_body = '{"some":"data"}'
    req = stub_request(:post, "https://apip.orangedata.ru:2443/api/v2/test").with(
      body: expected_body,
      headers: {
        'User-Agent'=>"OrangeDataRuby/#{OrangeData::VERSION}",
        'Accept'=>'application/json',
        'Content-Type'=>'application/json',
        'X-Signature'=>Base64.strict_encode64(
          test_credentials.signature_key.sign(OpenSSL::Digest::SHA256.new, expected_body)
        )
      }
    ).to_return(status: 200, body: '{"this":"is a response"}', headers: { 'Content-type' => 'application/json' })

    res = subject.raw_post('test', some: 'data')
    expect(res).to be_success
    expect(res.body).to eq('this' => 'is a response')
    expect(req).to have_been_made
  end

  context "when credentials are not full" do
    let(:test_credentials){ OrangeData::Credentials.new }

    it "checks" do
      expect(test_credentials).not_to be_valid
      expect{ subject }.to raise_error(ArgumentError, /credentials/i)
    end
  end

end
