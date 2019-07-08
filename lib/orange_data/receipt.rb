# frozen_string_literal: true

require 'yaml'
require 'json'
require_relative "generated_attributes"

module OrangeData

  PAYLOAD_SCHEMA = YAML.load_file(File.expand_path('schema_definitions.yml', __dir__)).freeze

  # main class for receipt/correction
  class Document

    attr_accessor :id, :inn, :group, :key_name, :content, :callback_url

    def initialize(id:SecureRandom.uuid, inn:, group:nil, key_name:nil, content:nil, callback_url: nil)
      @id = id
      @inn = inn
      @group = group
      @key_name = key_name || inn
      @content ||= content if content
      @callback_url = callback_url
      yield @content if block_given?
    end

    def self.from_hash(hash)
      new(
        id: hash[:id] || hash['id'],
        inn: hash[:inn] || hash['inn'],
        group: hash[:group] || hash['group'],
        key_name: hash[:key] || hash['key'],
        content: hash[:content] || hash['content'],
        callback_url: hash[:callbackUrl] || hash['callbackUrl'],
      )
    end

    def as_json
      {
        id: id,
        inn: inn,
        group: group || 'Main',
        content: content.is_a?(Hash) ? content : content.as_json,
        key: key_name
      }.tap{|h|
        h[:callbackUrl] = @callback_url if @callback_url
      }
    end

    def to_json(*args)
      as_json.to_json(*args)
    end
  end

  class Receipt < Document
    def initialize(id:SecureRandom.uuid, inn:, group:nil, key_name:nil, content:nil, callback_url: nil)
      @content = ReceiptContent.new(content || {})
      super
    end

    PAYLOAD_SCHEMA["definitions"]["CheckContent"]["properties"]["type"]["x-enum"].each_pair do |slug, _info|
      define_singleton_method(slug) do |**args, &block|
        new(**args, &block).tap{|doc|
          doc.content.type = slug
        }
      end
    end
  end

  class ReceiptContent < PayloadContent
    def initialize(payload={})
      @payload = payload || {}
      # TODO: import...
      # TODO: taxationSystem default in checkclose
      @check_close = CheckClose.new(@payload['checkClose'])
      if @payload["additionalUserAttribute"]
        @additional_user_attribute = AdditionalUserAttribute.new(@payload["additionalUserAttribute"])
      end

      @positions = (@payload['positions'] || []).map{|pos| Position.new(pos) }
    end

    # сырой тип используется в qr_code
    def raw_type
      @payload["type"]
    end

    def to_hash
      @payload.dup.tap{|h|
        h["positions"] = @positions.map(&:to_hash)
        h["checkClose"] = check_close.to_hash if check_close
        h["additionalUserAttribute"] = additional_user_attribute.to_hash if additional_user_attribute
      }
    end

    def add_position(text=nil, **options)
      pos = Position.new
      pos.text = text if text
      pos.assign_attributes(options)
      yield(pos) if block_given?
      positions << pos
      self
    end

    def add_payment(amount=nil, type=nil, **options)
      payment = Payment.new
      payment.type = type if type
      payment.amount = amount if amount
      payment.assign_attributes(options)
      yield(payment) if block_given?
      check_close.payments << payment
      self
    end

    def set_additional_user_attribute(**options)
      @additional_user_attribute = AdditionalUserAttribute.new.assign_attributes(options)
    end

    def set_agent_info(**options)
      # agent info may have some validations/transformations, so
      agent_info = AgentInfo.new.assign_attributes(options)
      assign_attributes(agent_info.attributes.reject{|_k, v| v.nil? })
    end

    class Position < PayloadContent
      def initialize(payload={})
        @payload = payload
        @supplier_info = SupplierInfo.new(@payload['supplierInfo']) if @payload['supplierInfo']
        @agent_info = AgentInfo.new(@payload['agentInfo']) if @payload['agentInfo']
      end

      def to_hash
        @payload.dup.tap{|h|
          h["supplierInfo"] = supplier_info.to_hash if supplier_info
          h["agentInfo"] = agent_info.to_hash if agent_info
        }
      end

      def set_supplier_info(**options)
        @supplier_info = SupplierInfo.new.assign_attributes(options)
        self
      end

      def set_agent_info(**options)
        @agent_info = AgentInfo.new.assign_attributes(options)
        self
      end

      attr_reader :agent_info, :supplier_info

      GeneratedAttributes.from_schema(self, PAYLOAD_SCHEMA["definitions"]["CheckPosition"])
    end

    class AgentInfo < PayloadContent
      GeneratedAttributes.from_schema(self, PAYLOAD_SCHEMA["definitions"]["AgentInfo"])
    end

    class SupplierInfo < PayloadContent
      GeneratedAttributes.from_schema(self, PAYLOAD_SCHEMA["definitions"]["SupplierInfo"])
    end

    class CheckClose < PayloadContent
      def initialize(payload={})
        payload ||= {}
        @payload = payload
        @payments = (payload['payments'] || []).map{|p| Payment.new(p) }
      end

      def to_hash
        @payload.dup.tap{|h|
          h["payments"] = @payments.map(&:to_hash) if @payments
        }
      end

      attr_reader :payments

      GeneratedAttributes.from_schema(self, PAYLOAD_SCHEMA["definitions"]["CheckClose"])
    end

    class Payment < PayloadContent
      GeneratedAttributes.from_schema(self, PAYLOAD_SCHEMA["definitions"]["CheckPayment"])
    end

    class AdditionalUserAttribute < PayloadContent
      GeneratedAttributes.from_schema(self, PAYLOAD_SCHEMA["definitions"]["AdditionalUserAttribute"])
    end

    GeneratedAttributes.from_schema(self, PAYLOAD_SCHEMA["definitions"]["CheckContent"])

    attr_reader :positions, :check_close, :additional_user_attribute

  end

  class ReceiptResult < PayloadContent
    def initialize(payload)
      @payload = payload
      @content = ReceiptContent.new(@payload["content"])
    end

    def self.from_hash(hash)
      return if hash.nil?
      raise ArgumentError, 'Expect hash here' unless hash.is_a?(Hash)

      new(hash)
    end

    attr_reader :content
    GeneratedAttributes.from_schema(self, PAYLOAD_SCHEMA["definitions"]["CheckStatusViewModel[CheckContent]"])

    def qr_code_content
      # Пример: t=20150720T1638&s=9999999.00&fn=000110000105&i=12345678&fp=123456&n=2
      # вообще это тег 1196, но OD его не присылают
      {
        # - t=<date/time - дата и время осуществления расчета в формате ГГГГММДДТЧЧММ>
        t: processed_at.gsub(/:\d{2}\z/, '').gsub(/[^0-9T]/, ''),
        # - s=<сумма расчета в рублях и копейках, разделенных точкой>
        s: content.check_close.payments.inject(0.0){|d, p| d + p.amount },
        # - fn=<заводской номер фискального накопителя>
        fn: fs_number,
        # - i=<порядковый номер фискального документа, нулями не дополняется>
        i: document_number, # documentIndex??
        # - fp=<фискальный признак документа, нулями не дополняется>
        fp: fp,
        # - n=<признак расчета>.
        n: content.raw_type,
      }.map{|k, v| "#{k}=#{v}" }.join('&')
    end
  end

  # Correction

  class Correction < Document
    def initialize(id:SecureRandom.uuid, inn:, group:nil, key_name:nil, content:nil, callback_url: nil)
      @content = CorrectionContent.new(content || {})
      super
    end
    PAYLOAD_SCHEMA["definitions"]["CorrectionContent"]["properties"]["type"]["x-enum"].each_pair do |slug, _info|
      define_singleton_method(slug) do |**args, &block|
        new(**args, &block).tap{|doc|
          doc.content.type = slug
        }
      end
    end
  end

  class CorrectionContent < PayloadContent
    GeneratedAttributes.from_schema(self, PAYLOAD_SCHEMA["definitions"]["CorrectionContent"])
  end

  class CorrectionResult < PayloadContent
    def initialize(payload)
      @payload = payload || {}
      @content = CorrectionContent.new(@payload["content"] || {})
    end

    def self.from_hash(hash)
      return if hash.nil?
      raise ArgumentError, 'Expect hash here' unless hash.is_a?(Hash)

      new(hash)
    end

    attr_reader :content
    GeneratedAttributes.from_schema(self, PAYLOAD_SCHEMA["definitions"]["CheckStatusViewModel[CheckContent]"])
  end

end
