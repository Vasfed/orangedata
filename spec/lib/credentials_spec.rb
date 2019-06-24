# frozen_string_literal: true

RSpec.describe OrangeData::Credentials do

  let(:fixtures_path){ File.expand_path('../fixtures', __dir__) }
  let(:short_credentials_hash){ YAML.load_file("#{fixtures_path}/credentials_short.yml") }

  describe "loading and inspect" do
    subject{ described_class.from_hash(short_credentials_hash) }
    it "load from_hash" do
      is_expected.to be_valid
      expect(subject.title).to eq 'Test minimal credentials'
      expect(subject.signature_key_name).to eq '1234567890'
      expect(subject.signature_key).to be_a(OpenSSL::PKey::RSA)
      expect(subject.certificate).to be_a(OpenSSL::X509::Certificate)
      expect(subject.certificate_key).to be_a(OpenSSL::PKey::RSA)
    end

    it "load from hash with key pass" do
      is_expected.to be_valid

      hash = subject.to_hash(key_pass: '3210', save_pass: false)

      expect{
        described_class.from_hash(hash)
      }.to raise_error(OpenSSL::PKey::RSAError)

      expect(described_class.from_hash(hash, key_pass:'3210')).to eq subject
    end

    it "load from folder" do
      cr = described_class.read_certs_from_pack("#{fixtures_path}/cert_folder_123", cert_key_pass:'1234')
      expect(cr).to be_a(described_class)
      expect(cr).to be_valid
      expect(cr.title).to eq 'Generated from cert_folder_123'
      expect(cr.signature_key_name).to eq '1234567890'

      expect(cr.certificate.to_pem).to eq(short_credentials_hash[:certificate])
      expect(cr.certificate_key.to_pem).to eq(short_credentials_hash[:certificate_key])
      expect(cr.signature_key).to be_a(OpenSSL::PKey::RSA)
      expect(cr.signature_key).to be_private
      expect(cr.signature_key.n.num_bits).to eq 2048
    end

    it "load from zip" do
      require 'zip'
      cr = Zip::File.open("#{fixtures_path}/cert_folder_123.zip") do |zip_file|
        described_class.read_certs_from_zip_pack(zip_file, cert_key_pass:'1234')
      end
      expect(cr).to be_a(described_class)
      expect(cr).to be_valid
      expect(cr.title).to eq 'Generated from zip'
      expect(cr.signature_key_name).to eq '1234567890'

      expect(cr.certificate.to_pem).to eq(short_credentials_hash[:certificate])
      expect(cr.certificate_key.to_pem).to eq(short_credentials_hash[:certificate_key])
      expect(cr.signature_key).to be_a(OpenSSL::PKey::RSA)
      expect(cr.signature_key).to be_private
      expect(cr.signature_key.n.num_bits).to eq 2048
    end

    it "export to hash" do
      expect(subject.to_hash(key_pass:false)).to eq short_credentials_hash
      expect(subject.signature_public_xml).to eq '<RSAKeyValue><Modulus>6PA+veZ0WKLyB48DfrPyCbYYe9JNvbzoHckF3AlTLSsylVHjZu4ebWGBgNVtV52HZfOkYALPR5z0SLiq0DRL3Q==</Modulus><Exponent>AQAB</Exponent></RSAKeyValue>'
      expect(subject.inspect).to match(/#<OrangeData::Credentials:[0-9a-fx]+ title="Test minimal credentials" key_name="1234567890" certificate="Orangedata test client">/)
    end

    it "to_yaml" do
      expect(described_class.from_hash(YAML.safe_load(subject.to_yaml, [Symbol]))).to eq(subject)
    end

    it "to_json" do
      expect(described_class.from_json(subject.to_json)).to eq(subject)
    end
  end

  describe "comparison" do
    let(:one){ described_class.from_hash(short_credentials_hash) }
    let(:other){ described_class.from_hash(short_credentials_hash) }
    it "comparison - loaded from same data is equal" do
      expect(one).to eq(other)
      one.signature_key = nil
      expect(one).not_to eq(other)
    end
  end

  describe "can generate key" do
    subject{ described_class.new }

    it "with defaults" do
      expect{ subject.generate_signature_key! }.to change(subject, :signature_key)
      expect(subject.signature_key).to be_a(OpenSSL::PKey::RSA).and(be_private)
    end
  end

  describe "default credentials" do
    subject{ described_class.default_test }

    it "are present and generated from original" do
      is_expected.to be_a(described_class).and(be_valid)

      cr = described_class.read_certs_from_pack("#{fixtures_path}/cert_test_pack", cert_key_pass:'1234')
      cr.title = subject.title # ignore title
      cr.signature_key_name = subject.signature_key_name # also ignore
      expect(cr).to eq(described_class.default_test)
    end

    it "have certificate_subject" do
      expect(subject.certificate_subject).to eq "Orangedata test client"
    end
  end

end
