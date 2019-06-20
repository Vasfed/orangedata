# frozen_string_literal: true

RSpec.describe OrangeData::Transport do

  let(:test_credentials) do
    OrangeData::Credentials.from_hash(YAML.load_file(File.expand_path('../fixtures/credentials_short.yml', __dir__)))
  end
  let(:api_root){ "https://apip.orangedata.ru:2443/api/v2/" }
  let(:transport){ OrangeData::Transport.new(api_root, test_credentials) }
  subject{ transport }

  it "signs post requests" do
    expected_body = '{"some":"data"}'
    req = stub_request(:post, "#{api_root}test").with(
      body: expected_body,
      headers: {
        'User-Agent' => "OrangeDataRuby/#{OrangeData::VERSION}",
        'Accept' => 'application/json',
        'Content-Type' => 'application/json',
        'X-Signature' => Base64.strict_encode64(
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

  describe "ping" do
    subject{ transport.ping }

    it "works" do
      stub_request(:get, api_root).to_return(status: 200, body: "Nebula.Api v2")
      expect(subject).to be_truthy
    end

    it "when timeout" do
      stub_request(:get, api_root).to_timeout
      expect(subject).to be_falsey
    end
  end

  describe "post document validate" do
    let(:document){ { some: 'data' } }
    subject{ transport.post_document_validate document }
    let(:response){ { status: 200 } }
    before do
      stub_request(:post, "#{api_root}validateDocument").
        with(body: "{\"some\":\"data\"}").to_return(response)
    end

    it "works" do
      is_expected.to be_truthy
    end

    context "when not valid" do
      let(:response){ { status: 400, body: '{"errors":["Some error"]}', headers: { 'Content-type' => 'application/json' } } }
      it{ is_expected.to eq(["Some error"]) }
    end

    context "when not authorized" do
      let(:response){ { status: 401 } }
      it{ expect{ subject }.to raise_error(/Unauthorized/) }
    end

    context "when 500" do
      let(:response){ { status: 500 } }
      it{ expect{ subject }.to raise_error(/Unexpected/) }
    end
  end

  describe "post document" do
    let(:document){ { some: 'data' } }
    let(:raise_errors){ true }
    subject{ transport.post_document document, raise_errors:raise_errors }
    let(:resp_status){ 201 }
    let(:resp_body){ nil }
    let(:resp_headers){ { 'Content-type' => 'application/json' } }
    before do
      stub_request(:post, "#{api_root}documents").
        with(body: "{\"some\":\"data\"}").
        to_return(status: resp_status, body: resp_body&.to_json, headers: resp_headers)
    end

    it do
      is_expected.to be_truthy.and(be_a(OrangeData::Transport::IntermediateResult))
      is_expected.to be_success
    end

    it "chained result" do
      expect(transport).to receive(:get_document)
      subject.get_result
    end

    context "when conflict" do
      let(:resp_status){ 409 }
      it{ expect{ subject }.to raise_error(/Conflict/) }

      context "when not raising" do
        let(:raise_errors){ false }
        it{ is_expected.not_to be_success }
        it{ is_expected.not_to be_should_retry }
      end
    end

    context "when invalid doc" do
      let(:resp_status){ 400 }
      let(:resp_body){ { errors: ["blablabla"] } }
      it{ expect{ subject }.to raise_error(/blablabla/) }

      context "when not raising" do
        let(:raise_errors){ false }
        it{ is_expected.not_to be_success }
        it do
          is_expected.not_to be_should_retry
          expect(subject.errors).to eq(["blablabla"])
        end
      end
    end

    context "when queue full" do
      let(:resp_status){ 503 }
      let(:resp_headers){ { 'Content-type' => 'application/json', 'Retry-After' => 5 } }
      it{
        expect{ subject }.to raise_error(/Retry/i)
      }

      context "when not raising" do
        let(:raise_errors){ false }
        it{ is_expected.not_to be_success }
        it{
          is_expected.to be_should_retry
          expect(subject.retry_in).to eq(5)
        }
        it "can be retried" do
          stub_request(:post, "#{api_root}documents").
            with(body: "{\"some\":\"data\"}").
            to_return(status: 503).
            to_return(status: 201)

          expect(subject.retry).to be_success
        end
      end
    end

    context "when other error on server" do
      let(:resp_status){ 500 }
      it{ expect{ subject }.to raise_error(/Unknown/) }

      context "when not raising" do
        let(:raise_errors){ false }
        it{ is_expected.not_to be_success }
        it{ is_expected.to be_should_retry }
      end
    end
  end

  describe "post correction" do
    let(:document){ { some: 'data' } }
    subject{ transport.post_correction document }
    before do
      stub_request(:post, "#{api_root}corrections").
        with(body: "{\"some\":\"data\"}").to_return(status: 201)
    end

    it{ is_expected.to be_success }

    it "chained result" do
      expect(transport).to receive(:get_correction)
      subject.get_result
    end

    # shares inplementation with post_document, so no need to test separately
  end

  describe "get document" do
    let(:inn){ 123 }
    let(:doc_id){ 456 }
    subject{ transport.get_document inn, doc_id }
    let(:resp_body){ { id: 'resp' } }
    let(:resp_status){ 200 }
    before do
      stub_request(:get, "#{api_root}documents/123/status/456").
        to_return(status: resp_status, body: resp_body.to_json, headers: { 'Content-type' => 'application/json' })
    end
    it do
      is_expected.to be_a(OrangeData::ReceiptResult)
      expect(subject.id).to eq('resp')
    end

    context "when error" do
      let(:resp_status){ 400 }
      let(:resp_body){ { errors:["somefailhere"] } }
      it{ expect{ subject }.to raise_error(/somefailhere/) }
    end

    context "when not authorized" do
      let(:resp_status){ 401 }
      let(:resp_body){ {} }
      it{ expect{ subject }.to raise_error(/Unauthorized/) }
    end
  end

  describe "get correction" do
    let(:inn){ 123 }
    let(:doc_id){ 456 }
    subject{ transport.get_correction inn, doc_id }

    it "works" do
      stub_request(:get, "#{api_root}corrections/123/status/456").
        to_return(status: 200, body:{ id: 'resp' }.to_json, headers: { 'Content-type' => 'application/json' })
      is_expected.to be_a(OrangeData::CorrectionResult)
      expect(subject.id).to eq('resp')
    end
  end

end
