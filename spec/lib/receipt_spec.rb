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
