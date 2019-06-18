# frozen_string_literal: true

RSpec.describe 'KeyEncoding for RSA key' do
  let(:described_class){ OpenSSL::PKey::RSA }
  subject{ described_class }

  it "refinements are still needed and do not interfere with existing methods" do
    is_expected.not_to respond_to(:from_hash)
    is_expected.not_to respond_to(:from_xml)
    is_expected.not_to respond_to(:load_from)

    obj = subject.new(512)
    expect(obj).not_to respond_to(:to_hash)
    expect(obj).not_to respond_to(:to_xml)
  end

  describe "key encoding refinements" do
    using OrangeData::Credentials::KeyEncoding
    
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
    let(:key_private_hash){
      {
        "n"=>"8IAiJQ==", "e"=>"AQAB",
        "d"=>"z/vzSQ==", "p"=>"/Ps=", "q"=>"818=", "dmp1"=>"Shk=", "dmq1"=>"uTc=", "iqmp"=>"6SI="
      }
    }
    let(:key_public_hash){ key_private_hash.slice("n", "e") }
    let(:key){ OpenSSL::PKey::RSA.new pem }

    it "to_hash" do
      expect(key.to_hash).to eq(key_private_hash)
      expect(key.public_key.to_hash).to eq(key_public_hash)
    end

    it "to_xml" do
      expect(key.to_xml).to eq private_xml.gsub(/\s+/, '')
      expect(key.public_key.to_xml).to eq public_xml
    end

    describe "from_hash" do
      it "is inverse of to_hash" do
        expect(described_class.from_hash(key.to_hash).to_s).to eq(key.to_s)
        expect(described_class.from_hash(key.public_key.to_hash).to_s).to eq(key.public_key.to_s)
        expect(described_class.from_hash(key_public_hash).to_s).to eq(key.public_key.to_s)
      end

      let(:input_hash){ key_private_hash }

      subject{ OpenSSL::PKey::RSA.from_hash(input_hash) }

      it "from_hash" do
        is_expected.to be_a(OpenSSL::PKey::RSA)
        is_expected.to be_private
        is_expected.to be_public
      end

      context "symbol keys and no base64 padding" do
        let(:input_hash){
          {
            n:"8IAiJQ", e:"AQAB",
            d:"z/vzSQ", p:"/Ps", q:"818", dmp1:"Shk", dmq1:"uTc", iqmp:"6SI"
          }
        }

        it "are accepted" do
          is_expected.to be_a(OpenSSL::PKey::RSA)
          is_expected.to be_private
          is_expected.to be_public
          expect(subject.to_s).to eq(key.to_s)
        end
      end

      context "public key" do
        let(:input_hash){ key_public_hash }

        it "from_hash" do
          expect(subject).to be_a(OpenSSL::PKey::RSA)
          is_expected.to be_public
          is_expected.not_to be_private
        end
      end
    end

    describe "from_xml" do
      it "for private" do
        expect(OpenSSL::PKey::RSA.from_xml(private_xml).to_s).to eq(pem)
      end

      it "for public" do
        expect(OpenSSL::PKey::RSA.from_xml(public_xml).to_s).to eq(key.public_key.to_s)
      end

      it "for spaced xml" do
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
end
