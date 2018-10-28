# frozen_string_literal: true

require 'yaml'
require 'json'

module OrangeData

  unless "".respond_to?(:underscore)
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
    using StringExt
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
        property_name = info["x-name"] || property.underscore

        if plain_types.include?(info["type"])
          if info["x-enum"]
            inverse_map = info["x-enum"].map{|k,v| [v['val'], k.to_sym]}.to_h
            define_method(property_name){
              return nil if @payload[property].nil?
              inverse_map[@payload[property]] || "unknown value #{@payload[property].inspect} for field #{property}"
            }
            define_method(:"#{property_name}="){|val|
              unless val.nil?
                val = (info["x-enum"][val.to_s] || raise(ArgumentError, "unknown value #{val.inspect} for property #{property}"))["val"]
              end
              @payload[property] = val
            }

          elsif info["x-bitfield"]
            bitmap = info["x-bitfield"].map{|k,v| [k.to_sym, 1 << v['bit']]}.to_h
            # TODO: return wrapper so that :<< etc will work
            define_method(property_name){
              return nil if @payload[property].nil?
              data = @payload[property].to_i
              # FIXME: unknown bits will be silently lost
              bitmap.reject{|_,v| (data & v).zero? }.map(&:first)
            }
            define_method(:"#{property_name}="){|val|
              unless val.nil?
                val = [val] unless val.is_a?(Array)
                val = val.map{|v| bitmap[v] || raise(ArgumentError, "unknown value #{v.inspect} for property #{property}") }.reduce(:|)
              end
              @payload[property] = val
            }
          else
            # primitive
            define_method(property_name){ @payload[property] }
            define_method(:"#{property_name}="){|val| @payload[property] = val }
          end
        elsif info["type"] == 'array'
          if info["items"] && plain_types.include?(info["items"]["type"])
            define_method(property_name){ @payload[property] }
            define_method(:"#{property_name}="){|val|
              val = [val] unless val.is_a?(Array)
              @payload[property] = val
            }
          else
            # ref?
          end
        else

        end

        if info["x-alias"]
          alias_method "#{info["x-alias"]}", property_name
          alias_method "#{info["x-alias"]}=", "#{property_name}="
        end
      end
    end
  end

  # base class for semi-generated classes
  class PayloadContent
    def initialize payload={}
      @payload = payload
    end

    def assign_attributes options
      options.each_pair{|k,v|
        setter = :"#{k}="
        send(setter, v)
      }
      # for chaining:
      self
    end

    def ==(other)
      self.class == other.class && to_hash == other.to_hash
      #@payload == other.instance_variable_get(:@payload)
    end

    def to_hash
      @payload
    end

    def to_json(*args)
      to_hash.to_json(*args)
    end
  end

end
