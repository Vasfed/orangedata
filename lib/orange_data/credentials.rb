# frozen_string_literal: true

require "openssl"
require "base64"
require "securerandom"
require "yaml"

module OrangeData
  # wrapper for keys/certs used for connection auth
  class Credentials

    # nodoc
    module KeyEncoding

      refine OpenSSL::PKey::RSA do
        def to_xml
          h_params = to_hash
          h = { 'Modulus' => :n, 'Exponent' => :e }
          h.merge!('P' => :p, 'Q' => :q, 'DP' => :dmp1, 'DQ' => :dmq1, 'InverseQ' => :iqmp, 'D' => :d) if private?

          "<RSAKeyValue>#{h.map{|(k, v)| "<#{k}>#{h_params[v.to_s]}</#{k}>" }.join('')}</RSAKeyValue>"
        end

        def to_hash
          params.map{|k, v| v != 0 && [k, Base64.strict_encode64(v.to_s(2))] || nil }.compact.to_h
        end
      end

      refine OpenSSL::PKey::RSA.singleton_class do
        def from_xml(xml)
          require "rexml/document"
          kv = REXML::Document.new(xml).elements['RSAKeyValue']
          raise ArgumentError, 'no RSAKeyValue in xml' unless kv && kv.name == 'RSAKeyValue'

          mapping = {
            "Modulus"=>:n, "Exponent"=>:e,
            "D"=>:d, "P"=>:p, "Q"=>:q,
            "DP"=>:dmp1, "DQ"=>:dmq1, "InverseQ"=>:iqmp
          }
          from_hash(
            kv.elements.each_with_object({}){|k, h| h[mapping[k.name]] = k.text if mapping[k.name] }
          )
        end

        def from_hash(hash)
          OpenSSL::PKey::RSA.new.tap do |key|
            key.params.keys.each do |param|
              if (v = hash[param] || hash[param.to_sym])
                key.send(:"#{param}=", OpenSSL::BN.new(Base64.decode64(v), 2))
              end
            end
          end
        end
      end

    end

    using KeyEncoding

    attr_accessor :signature_key_name, :signature_key, :certificate, :certificate_key, :title

    def initialize(signature_key_name:nil, signature_key:nil, certificate:nil, certificate_key:nil, title:nil)
      raise ArgumentError, "Signature key should be a private key" if signature_key && !signature_key.private?
      raise ArgumentError, "Certificate key should be a private key" if certificate_key && !certificate_key.private?
      @signature_key_name = signature_key_name
      @signature_key = signature_key
      @certificate = certificate
      @certificate_key = certificate_key
      @title = title
    end

    def valid?
      signature_key_name &&
        signature_key && signature_key.private? &&
        (signature_key.n.num_bits >= 489) && # minimum working key length for sha256 signature
        certificate && certificate_key &&
        certificate_key.private? && certificate.check_private_key(certificate_key)
    end

    def ==(other)
      return false unless %i[signature_key_name title].all?{|m| self.send(m) == other.send(m) }
      # certificates/keys cannot be compared directly, so dump
      %i[signature_key certificate certificate_key].all?{|m|
        c1 = self.send(m)
        c2 = other.send(m)
        c1 == c2 || (c1 && c2 && c1.to_der == c2.to_der)
      }
    end

    def self.from_hash(creds)
      key = nil
      if creds[:signature_key]
        key = if creds[:signature_key].is_a?(OpenSSL::PKey::RSA)
          creds[:signature_key]
        elsif creds[:signature_key].is_a?(Hash)
          OpenSSL::PKey::RSA.from_hash(creds[:signature_key])
        elsif creds[:signature_key].is_a?(String) && creds[:signature_key].start_with?('<')
          OpenSSL::PKey::RSA.from_xml(creds[:signature_key])
        else
          OpenSSL::PKey::RSA.new(creds[:signature_key], creds[:signature_key_pass])
        end
      end
      new(
        signature_key_name: creds[:signature_key_name],
        signature_key: key,
        certificate: creds[:certificate] && OpenSSL::X509::Certificate.new(creds[:certificate]),
        certificate_key: creds[:certificate_key] &&
          OpenSSL::PKey::RSA.new(creds[:certificate_key], creds[:certificate_key_pass]),
        title: creds[:title]
      )
    end

    def to_hash(key_pass:nil, save_pass:false)
      if key_pass.nil?
        key_pass = SecureRandom.hex
        save_pass = true
      elsif key_pass == false
        key_pass = nil
      end

      {
        title: title,
        signature_key_name: signature_key_name,
        signature_key: signature_key && signature_key.to_pem(key_pass && OpenSSL::Cipher.new("aes-128-cbc"), key_pass),
        certificate: certificate && certificate.to_pem,
        certificate_key: certificate_key && certificate_key.to_pem(key_pass && OpenSSL::Cipher.new("aes-128-cbc"), key_pass),
      }.tap do |h|
        h.delete(:title) if !title || title == ''
        if save_pass
          h[:certificate_key_pass] = key_pass if certificate && key_pass
          h[:signature_key_pass] = key_pass if signature_key && key_pass
        end
      end
    end

    def self.from_json(json)
      require 'json'
      from_hash(JSON.parse(json, symbolize_names: true))
    end

    def to_json(key_pass:nil, save_pass:false)
      to_hash(key_pass:key_pass, save_pass:save_pass).to_json
    end

    def to_yaml(key_pass:nil, save_pass:false)
      to_hash(key_pass:key_pass, save_pass:save_pass).to_yaml
    end

    def inspect
      info_fields = {
        title: (title || 'untitled').inspect,
        key_name: signature_key_name.inspect,
      }

      if certificate && (subject_name = certificate.subject.to_a.select{|ent| ent.first == 'O' }.first)
        info_fields[:certificate] = %Q("#{(subject_name[1] || 'unknown').gsub('"', '\"')}")
      end

      "#<#{self.class.name}:#{object_id} #{info_fields.map{|(k, v)| "#{k}=#{v}" }.join(' ')}>"
    end

    DEFAULT_KEY_LENGTH = 2048

    #deprecated
    def generate_signature_key!(key_length=DEFAULT_KEY_LENGTH)
      self.signature_key = self.class.generate_signature_key(key_length)
    end

    def self.generate_signature_key(key_length=DEFAULT_KEY_LENGTH)
      raise ArgumentError, "key length should be >= 489, recomended #{DEFAULT_KEY_LENGTH}" unless key_length >= 489
      OpenSSL::PKey::RSA.new(key_length)
    end

    def self.read_certs_from_pack(path, signature_key_name:nil, cert_key_pass:nil, title:nil, signature_key:nil)
      path = File.expand_path(path)
      client_cert = Dir.glob(path + '/*.{crt}').select{|f| File.file?(f.sub(/.crt\z/, '.key'))}
      raise 'Expect to find exactly one <num>.crt with corresponding <num>.key file' unless client_cert.size == 1
      client_cert = client_cert.first

      unless signature_key
        # private_key_test.xml || rsa_\d+_private_key.xml
        xmls = Dir.glob(path + '/*.{xml}').select{|f| f =~ /private/}
        signature_key = if xmls.size == 1
          File.read(xmls.first)
        else
          generate_signature_key(DEFAULT_KEY_LENGTH)
          # .tap{|k| logger.info("Generated public signature key: #{k.public_key.to_xml}") }
        end
      end

      from_hash(
        title: title || "Generated from #{File.basename(path)}",
        signature_key_name: signature_key_name || File.basename(client_cert).gsub(/\..*/, ''),
        certificate: File.read(client_cert),
        certificate_key: File.read(client_cert.sub(/.crt\z/, '.key')),
        certificate_key_pass: cert_key_pass,
        signature_key: signature_key,
      )
    end

    # публичная часть ключа подписи в формате пригодном для отдачи в ЛК
    def signature_public_xml
      signature_key.public_key.to_xml
    end

    # ключи для тествого окружения
    def self.default_test
      from_hash(YAML.load_file(File.expand_path('credentials_test.yml', __dir__)))
    end

  end
end
