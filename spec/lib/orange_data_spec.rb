# frozen_string_literal: true

RSpec.describe 'OrangeData' do

  describe "receipt" do

    let(:expected_body){
      {
        "id"=>"50152258-a9aa-4d19-9216-5a3eecec7241",
        "inn"=>"1234567890",
        "group"=>"Main",
        "content"=>{
          "customer"=>"Иван Иваныч",
          "type"=>1,
          "positions"=>[{ "text"=>"Спички", "price"=>12.34, "tax"=>6 }],
          "checkClose"=>{ "payments"=>[{ "type"=>1, "amount"=>50 }] }
        },
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
          "positions"=>[{ "price"=>12.34, "tax"=>6, "text"=>"Спички" }],
          "checkClose"=>{ "payments"=>[{ "type"=>1, "amount"=>50.0 }], "taxationSystem"=>0 },
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
          }
        ).to_return(status: 201, body: "", headers: {})
    end

    let!(:document_get_request){
      stub_request(:get, "https://apip.orangedata.ru:2443/api/v2/documents/1234567890/status/50152258-a9aa-4d19-9216-5a3eecec7241").
        with(headers:{ 'Accept'=>'application/json' }).
        to_return(status: 200, body: result_body, headers: { 'Content-type' => 'application/json' })
    }

    before do
      allow(SecureRandom).to receive(:uuid){ "50152258-a9aa-4d19-9216-5a3eecec7241" }.once
    end

    it "example" do
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

  describe "Correction" do
    let(:expected_body){
      {
        id: "12345678990",
        inn: "123456789012",
        group: "Main",
        content: {
          correctionType: 1,
          description: "НЕ ХОЧЕТСЯ НО НАДО",
          causeDocumentDate: "2017-08-10T00:00:00",
          causeDocumentNumber: "ФЗ-54",
          totalSum: 17.25,
          cashSum: 1.23,
          eCashSum: 2.34,
          prepaymentSum: 5.67,
          postpaymentSum: 4.56,
          otherPaymentTypeSum: 3.45,
          tax1Sum: 1.34,
          tax2Sum: 2.34,
          tax3Sum: 3.34,
          tax4Sum: 4.34,
          tax5Sum: 5.34,
          tax6Sum: 6.34,
          taxationSystem: 1,
          automatNumber: "123456789",
          settlementAddress: "г.Москва, Красная площадь, д.1",
          settlementPlace: "Палата No6",
          type: 1,
        },
        key: "123456789012"
      }.to_json
    }
    let(:result_body){
      {
        id: "12345678990",
        deviceSN: "0000000000001358",
        deviceRN: "0000000400054952",
        fsNumber: "9999078900001341",
        ofdName: "ООО \"Ярус\"(\"ОФД-Я\")",
        ofdWebsite: "www.ofd-ya.ru",
        ofdinn: "7728699517",
        fnsWebsite: "www.nalog.ru",
        companyINN: "123456789012",
        companyName: "ЗАО ТОРГОВЫЙ ОБЪЕКТ No1",
        documentNumber: 117,
        shiftNumber: 20,
        documentIndex: 5,
        processedAt: "2017-02-14T14:16:00",
        content: {
          type: 1,
          correctionType: 1,
          description: "НЕ ХОЧЕТСЯ НО НАДО", causeDocumentDate: "2017-08-10T00:00:00", causeDocumentNumber: "ФЗ-54",
          totalSum: 17.25,
          cashSum: 1.23,
          eCashSum: 2.34,
          prepaymentSum: 5.67,
          postpaymentSum: 4.56, otherPaymentTypeSum: 3.45,
          tax1Sum: 1.34,
          tax2Sum: 2.34,
          tax3Sum: 3.34,
          tax4Sum: 4.34,
          tax5Sum: 5.34,
          tax6Sum: 6.34,
          taxationSystem: 1,
        },
        change: 974.01,
        fp: "2364009522"
      }.to_json
    }

    let!(:document_post_request) do
      stub_request(:post, "https://apip.orangedata.ru:2443/api/v2/corrections").
        with(
          body: expected_body,
          headers: {
            'Accept'=>'application/json',
            'Content-Type'=>'application/json',
            'User-Agent'=>"OrangeDataRuby/#{OrangeData::VERSION}",
            'X-Signature'=>Base64.strict_encode64(
              OrangeData::Credentials.default_test.signature_key.sign(OpenSSL::Digest::SHA256.new, expected_body)
            )
          }
        ).to_return(status: 201, body: "", headers: {})
    end

    let!(:document_get_request){
      stub_request(:get, "https://apip.orangedata.ru:2443/api/v2/corrections/123456789012/status/12345678990").
        with(headers:{ 'Accept'=>'application/json' }).
        to_return(status: 200, body: result_body, headers: { 'Content-type' => 'application/json' })
    }

    it "example" do
      transport = OrangeData::Transport.new("https://apip.orangedata.ru:2443/api/v2/", OrangeData::Credentials.default_test)
      correction = OrangeData::Correction.income(inn:"123456789012", id:"12345678990"){|c|
        c.assign_attributes(
          correction_type: :prescribed,
          description: "НЕ ХОЧЕТСЯ НО НАДО",
          cause_document_date: "2017-08-10T00:00:00", cause_document_number: "ФЗ-54",
          total_sum: 17.25,
          sum_cash: 1.23,
          sum_card: 2.34,
          sum_prepaid: 5.67,
          sum_credit: 4.56,
          sum_counterclaim: 3.45,
          vat_18: 1.34,
          vat_10: 2.34,
          vat_0: 3.34,
          vat_not_charged: 4.34,
          vat_18_118: 5.34,
          vat_10_110: 6.34,
          taxation_system: :simplified,
          automat_number: "123456789",
          settlement_address: "г.Москва, Красная площадь, д.1",
          settlement_place: "Палата No6"
        )
      }
      transport.post_correction(correction)
      # wait some time
      res = transport.get_correction(correction.inn, correction.id)

      expect(document_post_request).to have_been_made
      expect(document_get_request).to have_been_made
      expect(res).to be_a(OrangeData::CorrectionResult)
    end
  end
end
