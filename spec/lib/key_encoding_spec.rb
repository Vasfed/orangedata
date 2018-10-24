RSpec.describe 'KeyEncoding for RSA key' do
  using OrangeData::Credentials::KeyEncoding
  let(:described_class){ OpenSSL::PKey::RSA }
  let(:pem) do
    <<~PEM
      -----BEGIN RSA PRIVATE KEY-----
      MC4CAQACBQDwgCIlAgMBAAECBQDP+/NJAgMA/PsCAwDzXwICShkCAwC5NwIDAOki
      -----END RSA PRIVATE KEY-----
    PEM
  end
  let(:private_xml) do
    <<~XML
      <RSAKeyValue>
        <Modulus>8IAiJQ==</Modulus><Exponent>AQAB</Exponent>
        <P>/Ps=</P><Q>818=</Q><DP>Shk=</DP><DQ>uTc=</DQ>
        <InverseQ>6SI=</InverseQ><D>z/vzSQ==</D>
      </RSAKeyValue>
    XML
  end
  let(:public_xml){ "<RSAKeyValue><Modulus>8IAiJQ==</Modulus><Exponent>AQAB</Exponent></RSAKeyValue>" }
  let(:key){ OpenSSL::PKey::RSA.new pem }

  it "to_hash" do
    expect(key.to_hash).to eq(
      "n"=>"8IAiJQ==", "e"=>"AQAB",
      "d"=>"z/vzSQ==", "p"=>"/Ps=", "q"=>"818=", "dmp1"=>"Shk=", "dmq1"=>"uTc=", "iqmp"=>"6SI="
    )
    expect(key.public_key.to_hash).to eq("n"=>"8IAiJQ==", "e"=>"AQAB")
  end

  it "to_xml" do
    expect(key.to_xml).to eq private_xml.gsub(/\s+/, '')
    expect(key.public_key.to_xml).to eq public_xml
  end

  it "from_hash" do
    expect(OpenSSL::PKey::RSA.from_hash(key.to_hash).to_s).to eq(key.to_s)
    expect(OpenSSL::PKey::RSA.from_hash(key.public_key.to_hash).to_s).to eq(key.public_key.to_s)
    expect(OpenSSL::PKey::RSA.from_hash(n:"8IAiJQ==", e:"AQAB").to_s).to eq(key.public_key.to_s)
  end

  it "from_xml for private" do
    expect(OpenSSL::PKey::RSA.from_xml(private_xml).to_s).to eq(pem)
  end

  it "from_xml for public" do
    expect(OpenSSL::PKey::RSA.from_xml(public_xml).to_s).to eq(key.public_key.to_s)
  end

  it "from_xml for spaced xml" do
    expect(OpenSSL::PKey::RSA.from_xml(<<~XML).to_s).to eq(key.public_key.to_s)
      <RSAKeyValue>
        <Modulus>
          8IA
          iJQ
          ==
        </Modulus>
        <Exponent>
          AQ
          AB
        </Exponent>
      </RSAKeyValue>
    XML
  end

  describe "load_from" do
    it "from key" do
      expect(described_class.load_from(key).to_s).to eq(pem)
    end

    it "from pem" do
      expect(described_class.load_from(pem).to_s).to eq(pem)
    end

    it "from hash" do
      expect(described_class.load_from(key.to_hash).to_s).to eq(pem)
    end

    it "from xml" do
      expect(described_class.load_from(private_xml).to_s).to eq(pem)
    end

    it "from nil" do
      expect(described_class.load_from(nil)).to be_nil
    end

    it "from unknown" do
      expect{ described_class.load_from(123) }.to raise_error(ArgumentError)
    end
  end
end
