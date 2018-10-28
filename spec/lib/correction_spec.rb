# frozen_string_literal: true

RSpec.describe OrangeData::Correction do

  describe OrangeData::CorrectionContent do
    it{ is_expected.to have_attributes_from("CorrectionContent") }
  end

  describe OrangeData::CorrectionResult do
    subject{ described_class.new({})}
    it{ is_expected.to have_attributes_from("CheckStatusViewModel[CorrectionContent]") }
  end

  it "has methods for each correction type" do
    expect(described_class.income(inn:"123")).to be_a(OrangeData::Correction)
  end
end
