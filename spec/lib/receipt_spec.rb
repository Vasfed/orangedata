# frozen_string_literal: true

RSpec.describe OrangeData::ReceiptResult do

  let(:receipt_result){
    {
      "id"=>"a88b6b30-20ab-47ea-95ca-f12f22ef03d3",
      "deviceSN"=>"1400000000001033",
      "deviceRN"=>"0000000400054952",
      "fsNumber"=>"9999078900001341",
      "ofdName"=>"ООО \"Ярус\" (\"ОФД-Я\")",
      "ofdWebsite"=>"www.ofd-ya.ru",
      "ofdinn"=>"7728699517",
      "fnsWebsite"=>"www.nalog.ru",
      "companyINN"=>"1234567890",
      "companyName"=>"Тест",
      "documentNumber"=>5548,
      "shiftNumber"=>6072,
      "documentIndex"=>3045,
      "processedAt"=>"2018-10-22T19:36:00",
      "content"=>
        {
          "type"=>1,
          "positions"=>[{"quantity"=>1.0, "price"=>0.01, "tax"=>4, "text"=>"Товар на копейку"}],
          "checkClose"=>{
            "payments"=>[{"type"=>2, "amount"=>0.01}],
            "taxationSystem"=>1
          }
        },
      "change"=>0.0,
      "fp"=>"787980846"
    }
  }
  subject{ described_class.from_hash(receipt_result) }

  it "loads from hash" do
    is_expected.to be_a(described_class)
  end

  it 'has qr code content' do
    expect(subject.qr_code_content).to eq "t=20181022T1936&s=0.01&fn=9999078900001341&i=5548&fp=787980846&n=1"
  end

end
