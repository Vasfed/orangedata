# frozen_string_literal: true

RSpec.describe 'OrangeData' do

  let(:expected_body){
    {
      "id"=>"50152258-a9aa-4d19-9216-5a3eecec7241",
      "inn"=>"1234567890",
      "group"=>"Main",
      "content"=>{
        "customer"=>"Иван Иваныч",
        "type"=>1,
        "positions"=>[{"text"=>"Спички", "price"=>12.34, "tax"=>6}],
        "checkClose"=>{"payments"=>[{"type"=>1, "amount"=>50}]}},
      "key"=>"1234567890"
    }.to_json
  }
  let(:result_body){
    {
      "id"=>"50152258-a9aa-4d19-9216-5a3eecec7241",
      "deviceSN"=>"1400000000001033",
      "deviceRN"=>"0000000400054952",
      "fsNumber"=>"9999078900001341",
      "ofdName"=>"ООО \"Ярус\" (\"ОФД-Я\")",
      "ofdWebsite"=>"www.ofd-ya.ru",
      "ofdinn"=>"7728699517",
      "fnsWebsite"=>"www.nalog.ru",
      "companyINN"=>"1234567890",
      "companyName"=>"Тест",
      "documentNumber"=>3243,
      "shiftNumber"=>234,
      "documentIndex"=>7062, "processedAt"=>"2018-10-26T20:21:00",
      "content"=>{
        "type"=>1,
        "positions"=>[{"price"=>12.34, "tax"=>6, "text"=>"Спички"}],
        "checkClose"=>{"payments"=>[{"type"=>1, "amount"=>50.0}], "taxationSystem"=>0},
        "customer"=>"Иван Иваныч"
      },
      "change"=>37.66,
      "fp"=>"301645583"
    }.to_json
  }
  let!(:document_post_request) do
    stub_request(:post, "https://apip.orangedata.ru:2443/api/v2/documents").
    with(
      body: expected_body,
      headers: {
     	  'Accept'=>'application/json',
     	  'Content-Type'=>'application/json',
     	  'User-Agent'=>"OrangeDataRuby/#{OrangeData::VERSION}",
     	  'X-Signature'=>Base64.strict_encode64(
          OrangeData::Credentials.default_test.signature_key.sign(OpenSSL::Digest::SHA256.new, expected_body)
        )
      }).to_return(status: 201, body: "", headers: {})
  end

  let!(:document_get_request){
    stub_request(:get, "https://apip.orangedata.ru:2443/api/v2/documents/1234567890/status/50152258-a9aa-4d19-9216-5a3eecec7241").
      with(headers:{'Accept'=>'application/json'}).
      to_return(status: 200, body: result_body, headers: { 'Content-type' => 'application/json' })
  }

  before do
    allow(SecureRandom).to receive(:uuid){ "50152258-a9aa-4d19-9216-5a3eecec7241" }.once
  end

  it "works" do
    transport = OrangeData::Transport.new("https://apip.orangedata.ru:2443/api/v2/", OrangeData::Credentials.default_test)
    receipt = OrangeData::Receipt.income(inn:"1234567890"){|r|
      r.customer = "Иван Иваныч"
      r.add_position("Спички", price: 12.34){|pos| pos.tax = :vat_not_charged }
      r.add_payment(50, :cash)
    }
    transport.post_document(receipt)
    # wait some time
    res = transport.get_document(receipt.inn, receipt.id)

    expect(document_post_request).to have_been_made
    expect(document_get_request).to have_been_made
    expect(res).to be_a(OrangeData::ReceiptResult)
    # expect(res.content).to eq(receipt.content)
  end
end
