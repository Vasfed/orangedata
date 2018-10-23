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
        certificate && certificate_key && certificate_key.private?
    end

    def self.from_hash(creds)
      key = nil
      if creds[:signature_key]
        key = if creds[:signature_key].is_a?(Hash)
          OpenSSL::PKey::RSA.from_hash(creds[:signature_key])
        elsif creds[:signature_key].start_with?('<')
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
        signature_key: signature_key && signature_key.to_pem(OpenSSL::Cipher.new("aes-128-cbc"), key_pass),
        certificate: certificate && certificate.to_pem,
        certificate_key: certificate_key && certificate_key.to_pem(OpenSSL::Cipher.new("aes-128-cbc"), key_pass),
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
        info_fields[:certificate] = subject_name.last.inspect
      end

      "#<#{self.class.name}:#{object_id} #{info_fields.map{|(k, v)| "#{k}=#{v}" }.join(' ')}>"
    end

    def generate_signature_key!(key_length=2048)
      self.signature_key = OpenSSL::PKey::RSA.new(key_length)
      signature_public_xml
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
