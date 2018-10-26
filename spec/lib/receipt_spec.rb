# frozen_string_literal: true

RSpec.describe OrangeData::Receipt do

  using OrangeData::StringExt unless "".respond_to?(:underscore)


  describe OrangeData::ReceiptContent do
    describe "has fields" do

      it "type enum" do
        subject.type = :income
        expect(subject.to_hash["type"]).to eq(1)
        expect(subject.type).to eq(:income)

        expect{
          subject.type = :unknown_value_123
        }.to raise_error(ArgumentError, /unknown/)
      end

      it "customerContact snakecase" do
        subject.customer_contact = "123"
        expect(subject.to_hash["customerContact"]).to eq "123"
        expect(subject.customer_contact).to eq("123")
      end

      it "agentType bitfield" do
        subject.agent_type = :bank_subagent
        expect(subject.to_hash["agentType"]).to eq(1 << 1)
        expect(subject.agent_type).to eq([:bank_subagent])

        subject.agent_type = [:bank_subagent, :attorney]
        expect(subject.to_hash["agentType"]).to eq(2 + (1 << 4))
        expect(subject.agent_type).to eq([:bank_subagent, :attorney])
      end

      it "paymentTransferOperatorPhoneNumbers string array" do
        subject.payment_transfer_operator_phone_numbers = "1234"
        expect(subject.to_hash["paymentTransferOperatorPhoneNumbers"]).to eq ["1234"]
        expect(subject.payment_transfer_operator_phone_numbers).to eq(["1234"])
      end

      it "has all fields" do
        missing = OrangeData::PAYLOAD_SCHEMA["definitions"]["CheckContent"]["properties"].keys.reject{|k|
          subject.respond_to?(k.underscore)
        }
        expect(missing).to eq([])
      end

      it "class method is protected" do
        expect{ described_class.generate_accessors_from_schema }.to raise_error(NoMethodError, /protected/)
      end

    end

    describe OrangeData::ReceiptContent::Position do
      it "has all fields" do
        missing = OrangeData::PAYLOAD_SCHEMA["definitions"]["CheckPosition"]["properties"].keys.reject{|k|
          subject.respond_to?(k.underscore)
        }
        expect(missing).to eq([])
      end
    end

    describe OrangeData::ReceiptContent::AgentInfo do
      it "has all fields" do
        missing = OrangeData::PAYLOAD_SCHEMA["definitions"]["AgentInfo"]["properties"].keys.reject{|k|
          subject.respond_to?(k.underscore)
        }
        expect(missing).to eq([])
      end
    end

    describe OrangeData::ReceiptContent::SupplierInfo do
      it "has all fields" do
        missing = OrangeData::PAYLOAD_SCHEMA["definitions"]["SupplierInfo"]["properties"].keys.reject{|k|
          subject.respond_to?(k.underscore)
        }
        expect(missing).to eq([])
      end
    end

    describe OrangeData::ReceiptContent::CheckClose do
      it "has all fields" do
        missing = OrangeData::PAYLOAD_SCHEMA["definitions"]["CheckClose"]["properties"].keys.reject{|k|
          subject.respond_to?(k.underscore)
        }
        expect(missing).to eq([])
      end
    end

    describe OrangeData::ReceiptContent::Payment do
      it "has all fields" do
        missing = OrangeData::PAYLOAD_SCHEMA["definitions"]["CheckPayment"]["properties"].keys.reject{|k|
          subject.respond_to?(k.underscore)
        }
        expect(missing).to eq([])
      end
    end


  end

  before(:all) do
    require 'json-schema'
  end

  describe "Creation and export" do

    subject{
      OrangeData::Receipt.income(id:'test123', inn: "12345"){|r|
        r.customer = "Иван Иваныч"
        r.add_position("Спички", price: 12.34){|pos| pos.tax = :vat_not_charged }
        r.add_payment(50, :cash)
      }
    }

    let(:expected_json){
      {
        id: 'test123',
        inn: '12345',
        group: 'Main',
        content: {
          customer: 'Иван Иваныч',
          positions: [
            {
              text: 'Спички',
              price: 12.34,
              tax: 6
            }
          ],
          checkClose: {
            payments: [
              { type: 1, amount: 50 }
            ]
          }
        },
        key: '12345'
      }.to_json
    }

    it "basic" do
      json = subject.to_json
      expect(JSON::Validator.fully_validate_json(OrangeData::PAYLOAD_SCHEMA, json)).to eq []
      expect(json).to eq expected_json
    end
  end

end

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
