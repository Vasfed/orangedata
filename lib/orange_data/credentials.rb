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

          "<RSAKeyValue>#{h.map{|(k, v)| "<#{k}>#{h_params[v.to_s]}</#{k}>" }.join}</RSAKeyValue>"
        end

        def to_hash
          params.map{|k, v| (v != 0 && [k, Base64.strict_encode64(v.to_s(2))]) || nil }.compact.to_h
        end
      end

      refine OpenSSL::PKey::RSA.singleton_class do
        def from_xml(xml)
          require "rexml/document"
          kv = REXML::Document.new(xml).elements['RSAKeyValue']
          raise ArgumentError, 'no RSAKeyValue in xml' unless kv && kv.name == 'RSAKeyValue'

          mapping = {
            "Modulus" => :n,
            "Exponent" => :e,

            "D" => :d,
            "P" => :p,
            "Q" => :q,

            "DP" => :dmp1,
            "DQ" => :dmq1,
            "InverseQ" => :iqmp
          }
          from_hash(
            kv.elements.each_with_object({}){|k, h| h[mapping[k.name]] = k.text if mapping[k.name] }
          )
        end

        def from_hash(hash)
          OpenSSL::PKey::RSA.new.tap do |key|
            if key.respond_to?(:set_key)
              # ruby 2.5+
              # a bit ugly - simulating with_indifferent_access
              if hash['n'] || hash[:n]
                # public key only has n and e (without them - there's no key actually)
                key.set_key(
                  OpenSSL::BN.new(Base64.decode64(hash['n'] || hash[:n]), 2),
                  OpenSSL::BN.new(Base64.decode64(hash['e'] || hash[:e]), 2),
                  (hash['d'] || hash[:d]) && OpenSSL::BN.new(Base64.decode64(hash['d'] || hash[:d]), 2)
                )
              end

              if hash['p'] || hash[:p]
                key.set_factors(
                  OpenSSL::BN.new(Base64.decode64(hash['p'] || hash[:p]), 2),
                  OpenSSL::BN.new(Base64.decode64(hash['q'] || hash[:q]), 2)
                )
                if hash['dmp1'] || hash[:dmp1]
                  key.set_crt_params(
                    OpenSSL::BN.new(Base64.decode64(hash['dmp1'] || hash[:dmp1]), 2),
                    OpenSSL::BN.new(Base64.decode64(hash['dmq1'] || hash[:dmq1]), 2),
                    OpenSSL::BN.new(Base64.decode64(hash['iqmp'] || hash[:iqmp]), 2)
                  )
                end
              end
            else
              # ruby 2.3 and may be older
              key.params.each_key do |param|
                if (v = hash[param] || hash[param.to_sym])
                  key.send(:"#{param}=", OpenSSL::BN.new(Base64.decode64(v), 2))
                end
              end
            end
          end
        end

        def load_from(val, key_pass=nil)
          return val unless val

          case val
          when self
            val
          when Hash
            from_hash(val)
          when String
            if val.start_with?('<')
              from_xml(val)
            else
              new(val, key_pass)
            end
          else
            raise ArgumentError, "cannot load from #{val.class}"
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
      return false unless %i[signature_key_name title].all?{|m| send(m) == other.send(m) }

      # certificates/keys cannot be compared directly, so dump
      %i[signature_key certificate certificate_key].all?{|m|
        c1 = send(m)
        c2 = other.send(m)
        c1 == c2 || (c1 && c2 && c1.to_der == c2.to_der)
      }
    end

    def self.from_hash(creds, key_pass:nil)
      key_pass ||= '' # to prevent password prompt, works in fresh openssl gem/ruby
      new(
        title: creds[:title],
        signature_key_name: creds[:signature_key_name],
        signature_key: OpenSSL::PKey::RSA.load_from(creds[:signature_key], creds[:signature_key_pass] || key_pass),
        certificate: creds[:certificate] && OpenSSL::X509::Certificate.new(creds[:certificate]),
        certificate_key: OpenSSL::PKey::RSA.load_from(creds[:certificate_key], creds[:certificate_key_pass] || key_pass)
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
        signature_key: signature_key &&
          signature_key.to_pem(key_pass && OpenSSL::Cipher.new("aes-128-cbc"), key_pass),
        certificate: certificate && certificate.to_pem,
        certificate_key: certificate_key &&
          certificate_key.to_pem(key_pass && OpenSSL::Cipher.new("aes-128-cbc"), key_pass),
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

      if certificate && (subject_name = certificate_subject)
        info_fields[:certificate] = %("#{(subject_name || 'unknown').gsub('"', '\"')}")
      end

      "#<#{self.class.name}:#{object_id} #{info_fields.map{|(k, v)| "#{k}=#{v}" }.join(' ')}>"
    end

    def certificate_subject
      return unless (subj = certificate.subject.to_a.select{|ent| ent.first == 'O' }.first)

      subj[1].force_encoding('UTF-8')
    end

    DEFAULT_KEY_LENGTH = 2048

    # deprecated
    def generate_signature_key!(key_length=DEFAULT_KEY_LENGTH)
      self.signature_key = self.class.generate_signature_key(key_length)
    end

    def self.generate_signature_key(key_length=DEFAULT_KEY_LENGTH)
      raise ArgumentError, "key length should be >= 489, recomended #{DEFAULT_KEY_LENGTH}" unless key_length >= 489

      OpenSSL::PKey::RSA.new(key_length)
    end

    def self.read_certs_from_pack(path, signature_key_name:nil, cert_key_pass:nil, title:nil, signature_key:nil)
      path = File.expand_path(path)
      client_cert = Dir.glob("#{path}/*.{crt}").select{|f| File.file?(f.sub(/.crt\z/, '.key')) }
      raise 'Expect to find exactly one <num>.crt with corresponding <num>.key file' unless client_cert.size == 1

      client_cert = client_cert.first

      unless signature_key
        # private_key_test.xml || rsa_\d+_private_key.xml
        xmls = Dir.glob("#{path}/*.{xml}").grep(/private/)
        signature_key = if xmls.size == 1
          File.read(xmls.first)
        else
          generate_signature_key(DEFAULT_KEY_LENGTH)
          # .tap{|k| logger.info("Generated public signature key: #{k.public_key.to_xml}") }
        end
      end

      from_hash({
        title: title || "Generated from #{File.basename(path)}",
        signature_key_name: signature_key_name || File.basename(client_cert).gsub(/\..*/, ''),
        certificate: File.read(client_cert),
        certificate_key: File.read(client_cert.sub(/.crt\z/, '.key')),
        certificate_key_pass: cert_key_pass,
        signature_key: signature_key
      })
    end

    def self.read_certs_from_zip_pack(rubyzip_object, signature_key_name:nil, cert_key_pass:nil, title:nil, signature_key:nil)
      client_cert = rubyzip_object.glob("*.crt").select{|f| rubyzip_object.glob(f.name.sub(/.crt\z/, '.key')).any? }
      raise 'Expect to find exactly one <num>.crt with corresponding <num>.key file' unless client_cert.size == 1

      client_cert = client_cert.first
      client_key = rubyzip_object.glob(client_cert.name.sub(/.crt\z/, '.key')).first

      unless signature_key
        # private_key_test.xml || rsa_\d+_private_key.xml
        xmls = rubyzip_object.glob('/*.{xml}').grep(/private/)
        signature_key = if xmls.size == 1
          xmls.first.get_input_stream.read
        else
          generate_signature_key(DEFAULT_KEY_LENGTH)
          # .tap{|k| logger.info("Generated public signature key: #{k.public_key.to_xml}") }
        end
      end

      from_hash({
        title: title || "Generated from zip",
        signature_key_name: signature_key_name || File.basename(client_cert.name).gsub(/\..*/, ''),
        certificate: client_cert.get_input_stream.read,
        certificate_key: client_key.get_input_stream.read,
        certificate_key_pass: cert_key_pass,
        signature_key: signature_key
      })
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
