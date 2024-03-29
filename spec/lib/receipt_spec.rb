# frozen_string_literal: true

RSpec.describe OrangeData::Receipt do

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

        subject.agent_type = %i[bank_subagent attorney]
        expect(subject.to_hash["agentType"]).to eq(2 + (1 << 4))
        expect(subject.agent_type).to eq(%i[bank_subagent attorney])
      end

      it "paymentTransferOperatorPhoneNumbers string array" do
        subject.payment_transfer_operator_phone_numbers = "1234"
        expect(subject.to_hash["paymentTransferOperatorPhoneNumbers"]).to eq ["1234"]
        expect(subject.payment_transfer_operator_phone_numbers).to eq(["1234"])
      end

      it "class method is protected" do
        expect{ described_class.generate_accessors_from_schema }.to raise_error(NoMethodError, /protected/)
      end

      it{ is_expected.to have_attributes_from("CheckContent") }
    end

    describe OrangeData::ReceiptContent::Position do
      it{ is_expected.to have_attributes_from("CheckPosition") }
    end

    describe OrangeData::ReceiptContent::AgentInfo do
      it{ is_expected.to have_attributes_from("AgentInfo") }
    end

    describe OrangeData::ReceiptContent::SupplierInfo do
      it{ is_expected.to have_attributes_from("SupplierInfo") }
    end

    describe OrangeData::ReceiptContent::CheckClose do
      it{ is_expected.to have_attributes_from("CheckClose") }
    end

    describe OrangeData::ReceiptContent::Payment do
      it{ is_expected.to have_attributes_from("CheckPayment") }
    end

    describe OrangeData::ReceiptResult do
      subject{ described_class.new({}) }
      it{ is_expected.to have_attributes_from("CheckStatusViewModel[CheckContent]") }
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
          type: 1,
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

    it "has as_json" do
      json = subject.as_json.to_json
      expect(JSON::Validator.fully_validate_json(OrangeData::PAYLOAD_SCHEMA, json)).to eq []
      expect(json).to eq expected_json
    end

    it "has from_hash" do
      rec = OrangeData::Receipt.from_hash(subject.as_json)
      expect(rec.to_json).to eq(subject.to_json)
    end

    it "more complex example" do
      receipt = OrangeData::Receipt.income_return(id: 'test321', inn:'43121'){|r|
        r.customer = "Иван Иваныч"
        r.add_position("Спички", price: 12.34, tax: :vat_not_charged)
        r.add_position("Какая-то агентская хрень", price: 12.34, tax: :vat_not_charged){|pos|
          pos.set_agent_info payment_operator_inn:'12345'
          pos.set_supplier_info name:'ООО Ромашка'
        }
        r.set_agent_info payment_agent_operation: 'операциия'
        r.add_payment(1, :card)
        r.add_payment(50, :cash)
        r.check_close.taxation_system = :common
        r.set_additional_user_attribute name:'Аттрибут', value:'lala'
      }

      expect(receipt.content.payment_agent_operation).to eq 'операциия'

      json = receipt.to_json
      expect(JSON::Validator.fully_validate_json(OrangeData::PAYLOAD_SCHEMA, json)).to eq []

      # puts JSON.pretty_generate(JSON.parse(json))

      # parse back to get additional coverage:
      parsed = OrangeData::ReceiptContent.new(JSON.parse(json)["content"])
      expect(parsed).to be_a(OrangeData::ReceiptContent).and(eq(receipt.content))
    end
  end

end
