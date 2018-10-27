# frozen_string_literal: true

RSpec.describe OrangeData::Correction do

  using OrangeData::StringExt unless "".respond_to?(:underscore)


  describe OrangeData::CorrectionContent do
    it "has all fields" do
      missing = OrangeData::PAYLOAD_SCHEMA["definitions"]["CorrectionContent"]["properties"].keys.reject{|k|
        subject.respond_to?(k.underscore)
      }
      expect(missing).to eq([])
    end
  end

  describe OrangeData::CorrectionResult do
    subject{ described_class.new({})}
    it "has all fields" do
      missing = OrangeData::PAYLOAD_SCHEMA["definitions"]["CheckStatusViewModel[CorrectionContent]"]["properties"].keys.reject{|k|
        subject.respond_to?(k.underscore)
      }
      expect(missing).to eq([])
    end
  end

  it "has methods for each correction type" do
    expect(described_class.income(inn:"123")).to be_a(OrangeData::Correction)
  end
end
