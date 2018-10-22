# frozen_string_literal: true

module OrangeData

  class Receipt
    attr_accessor :id, :inn, :group, :key_name

    def initialize id:SecureRandom.uuid, inn:, group:nil, key_name:nil
      @id = id
      @inn = inn
      @group = group
      @key_name = key_name
      yield self if block_given?
    end
  end

  class ReceiptContent

    module AgentTypeSerializer
      AGENT_TYPE_BITS = {         # 1057 (в чеках/БСО должно соответствовать отчету о (пере)регистрации ККТ)
        bank_payment_agent:    (1 << 0), # банковский платежный агент
        bank_payment_subagent: (1 << 1), # банковский платежный субагент
        payment_agent:         (1 << 2), # платежный агент
        payment_subagent:      (1 << 3), # платежный субагент
        attorney:              (1 << 4), # поверенный
        commission_agent:      (1 << 5), # комиссионер
        other_agent:           (1 << 6), # иной агент
      }.freeze

      def self.load data
        data = data.to_i
        AGENT_TYPE_BITS.select{|(k,v)| (data & v) > 0}.map(&:first)
      end

      def self.dump val
        val = [val] unless val.is_a?(Array)
        val.map{|v| AGENT_TYPE_BITS[v] || raise "unknown agent_type #{v}"}.reduce(:|)
      end
    end


    RECEIPT_TYPES = {        # 1054:

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
    }



    def initialize type
      @positions = []
      @payments = []
    end

    def agent_type
      AgentTypeSerializer.load(@agent_type)
    end

    def agent_type= val
      @agent_type = AgentTypeSerializer.dump(val)
    end

  end

end
