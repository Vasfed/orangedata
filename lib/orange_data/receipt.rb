# frozen_string_literal: true

require 'ostruct'

module OrangeData

  # main class for receipt/correction
  class Document

    attr_accessor :id, :inn, :group, :key_name, :content

    def initialize(id:SecureRandom.uuid, inn:, group:nil, key_name:nil, content:nil)
      @id = id
      @inn = inn
      @group = group
      @key_name = key_name
      @content = content
      yield self if block_given?
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

  class Receipt < Document; end
  class Correction < Document; end

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


  # nodoc
  class ReceiptContent

    # for agent type bit mask
    module AgentTypeSerializer
      AGENT_TYPE_BITS = { # 1057 (в чеках/БСО должно соответствовать отчету о (пере)регистрации ККТ)
        bank_payment_agent:    (1 << 0), # банковский платежный агент
        bank_payment_subagent: (1 << 1), # банковский платежный субагент
        payment_agent:         (1 << 2), # платежный агент
        payment_subagent:      (1 << 3), # платежный субагент
        attorney:              (1 << 4), # поверенный
        commission_agent:      (1 << 5), # комиссионер
        other_agent:           (1 << 6), # иной агент
      }.freeze

      def self.load(data)
        data = data.to_i
        AGENT_TYPE_BITS.reject{|(_, v)| (data & v).zero? }.map(&:first)
      end

      def self.dump(val)
        val = [val] unless val.is_a?(Array)
        val.map{|v| AGENT_TYPE_BITS[v] || raise("unknown agent_type #{v}") }.reduce(:|)
      end
    end

    RECEIPT_TYPES = { # 1054:

    }.freeze

    FIELDS = {
      type: {
        name: 'Признак расчета',
        tag_num: 1054,
        mapper: :enum,
        enum_values: {
          income: 1,        # Приход
          return_income: 2, # Возврат прихода
          expense: 3,       # Расход
          return_expense: 4 # Возврат расхода
        }
      }
    }.freeze

    def initialize(_type)
      @positions = []
      @payments = []
    end

    def agent_type
      AgentTypeSerializer.load(@agent_type)
    end

    def agent_type=(val)
      @agent_type = AgentTypeSerializer.dump(val)
    end

  end

end
