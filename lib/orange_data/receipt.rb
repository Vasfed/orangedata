# frozen_string_literal: true

require 'ostruct'

module OrangeData

  PAYLOAD_SCHEMA = YAML.load_file(File.expand_path('schema_definitions.yml', __dir__)).freeze

  # taken from ActiveSupport
  module StringExt
    refine String do
      def underscore
        self.gsub(/::/, '/').
        gsub(/([A-Z]+)([A-Z][a-z])/,'\1_\2').
        gsub(/([a-z\d])([A-Z])/,'\1_\2').
        tr("-", "_").
        downcase
      end
    end
  end
  using StringExt unless "".respond_to?(:underscore)

  # main class for receipt/correction
  class Document

    attr_accessor :id, :inn, :group, :key_name, :content

    def initialize(id:SecureRandom.uuid, inn:, group:nil, key_name:nil, content:nil)
      @id = id
      @inn = inn
      @group = group
      @key_name = key_name || inn
      @content = content if content
      yield @content if block_given?
    end

    def to_json
      {
        id: id,
        inn: inn,
        group: group || 'Main',
        content: content,
        key: key_name
      }.to_json
    end
  end

  class Receipt < Document
    def initialize(id:SecureRandom.uuid, inn:, group:nil, key_name:nil, content:nil)
      @content = ReceiptContent.new(content || {})
      super
    end
    PAYLOAD_SCHEMA["definitions"]["CheckContent"]["properties"]["type"]["x-enum"].each_pair do |slug, info|
      define_singleton_method(slug) do |**args, &block|
        # TODO: add $.content.type: info["val"]
        new(**args, &block)
      end
    end
  end

  module GeneratedAttributes
    def self.from_schema klass, schema
      klass.class_eval{
        extend GeneratedAttributes
        generate_accessors_from_schema(schema)
      }
    end

    protected
    def generate_accessors_from_schema schema
      plain_types = %w[integer string number]
      schema["properties"].each_pair do |property, info|
        if plain_types.include?(info["type"])
          if info["x-enum"]
            inverse_map = info["x-enum"].map{|k,v| [v['val'], k.to_sym]}.to_h
            define_method(property.underscore){
              return nil if @payload[property].nil?
              inverse_map[@payload[property]] || "unknown value #{@payload[property].inspect} for field #{property}"
            }
            define_method(:"#{property.underscore}="){|val|
              unless val.nil?
                val = (info["x-enum"][val.to_s] || raise(ArgumentError, "unknown value #{val.inspect} for property #{property}"))["val"]
              end
              @payload[property] = val
            }

          elsif info["x-bitfield"]
            bitmap = info["x-bitfield"].map{|k,v| [k.to_sym, 1 << v['bit']]}.to_h
            # TODO: return wrapper so that :<< etc will work
            define_method(property.underscore){
              return nil if @payload[property].nil?
              data = @payload[property].to_i
              # FIXME: unknown bits will be silently lost
              bitmap.reject{|_,v| (data & v).zero? }.map(&:first)
            }
            define_method(:"#{property.underscore}="){|val|
              unless val.nil?
                val = [val] unless val.is_a?(Array)
                val = val.map{|v| bitmap[v] || raise(ArgumentError, "unknown value #{v.inspect} for property #{property}") }.reduce(:|)
              end
              @payload[property] = val
            }
          else
            # primitive
            define_method(property.underscore){ @payload[property] }
            define_method(:"#{property.underscore}="){|val| @payload[property] = val }
          end
        elsif info["type"] == 'array'
          if info["items"] && plain_types.include?(info["items"]["type"])
            define_method(property.underscore){ @payload[property] }
            define_method(:"#{property.underscore}="){|val|
              val = [val] unless val.is_a?(Array)
              @payload[property] = val
            }
          else
            # ref?
          end
        else

        end
      end
    end
  end

  # base class for semi-generated classes
  class PayloadContent
    def initialize payload={}
      @payload = payload
    end

    def to_hash
      @payload
    end

    def to_json(*args)
      to_hash.to_json(*args)
    end
  end

  class ReceiptContent < PayloadContent
    def initialize payload={}
      @payload = payload
      # TODO: import...
      # TODO: taxationSystem default in checkclose
      @check_close = CheckClose.new(@payload['checkClose'])
      @positions = (@payload['positions'] || []).map{|pos| Position.new(pos) }
      if @payload["additionalUserAttribute"]
        @additional_user_attribute = AdditionalUserAttribute.new(@payload["additionalUserAttribute"])
      end
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
      options.each_pair{|k,v| pos.send(:"#{k}=", v) if pos.respond_to?(k) }
      yield(pos) if block_given?
      positions << pos
      self
    end

    def add_payment(amount=nil, type=nil, **options)
      payment = Payment.new
      payment.type = type if type
      payment.amount = amount if amount
      options.each_pair{|k,v| payment.send(:"#{k}=", v) if payment.respond_to?(k) }
      yield(payment) if block_given?
      check_close.payments << payment
      self
    end



    class Position < PayloadContent
      def initialize payload={}
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

      attr_reader :agent_info, :supplier_info

      GeneratedAttributes.from_schema(self, PAYLOAD_SCHEMA["definitions"]["CheckPosition"])
    end

    class AgentInfo < PayloadContent
      def initialize payload={}
        @payload = payload
      end
      def to_hash
        @payload
      end
      GeneratedAttributes.from_schema(self, PAYLOAD_SCHEMA["definitions"]["AgentInfo"])
    end

    class SupplierInfo < PayloadContent
      def initialize payload={}
        @payload = payload
      end
      def to_hash
        @payload
      end
      GeneratedAttributes.from_schema(self, PAYLOAD_SCHEMA["definitions"]["SupplierInfo"])
    end

    class CheckClose < PayloadContent
      def initialize payload={}
        payload ||= {}
        @payload = payload
        @payments = (payload['payments'] || []).map{|p| Payment.new(p)}
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

    class AdditionalUserAttribute
      def initialize payload={}
        @payload = payload
      end

      def to_hash
        @payload
      end

      GeneratedAttributes.from_schema(self, PAYLOAD_SCHEMA["definitions"]["AdditionalUserAttribute"])
    end

    GeneratedAttributes.from_schema(self, PAYLOAD_SCHEMA["definitions"]["CheckContent"])

    attr_reader :positions, :check_close, :additional_user_attribute

  end


  class Correction < Document
    # TODO: same as Receipt, but based on correctionType
  end

  class ReceiptResult < OpenStruct
    def self.from_hash(hash)
      raise ArgumentError, 'Expect hash here' unless hash.is_a?(Hash)
      new(hash)
    end

    def content
      @content ||= OpenStruct.new(super)
    end

    def qr_code_content
      #  С живого чека:  t=20180518T220500&s=975.88&fn=8710000101125654&i=99456&fp=1250448795&n=1
      # Пример: t=20150720T1638&s=9999999.00&fn=000110000105&i=12345678&fp=123456&n=2
      {
        # - t=<date/time - дата и время осуществления расчета в формате ГГГГММДДТЧЧММ>
        t: self.processedAt.gsub(/:\d{2}\z/, '').gsub(/[^0-9T]/, ''),
        # - s=<сумма расчета в рублях и копейках, разделенных точкой>
        s: content.checkClose["payments"].inject(0.0){|d, p| d + p["amount"]},
        # - fn=<заводской номер фискального накопителя>
        fn: fsNumber,
        # - i=<порядковый номер фискального документа, нулями не дополняется>
        i: documentNumber, # documentIndex??
        # - fp=<фискальный признак документа, нулями не дополняется>
        fp: fp,
        # - n=<признак расчета>.
        n: content.type, #??
      }.map{|k, v| "#{k}=#{v}" }.join('&')
    end
  end

end
