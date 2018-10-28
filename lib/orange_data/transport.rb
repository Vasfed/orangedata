# frozen_string_literal: true

require 'openssl'
require 'base64'
require 'faraday'
require 'faraday_middleware'

module OrangeData
  # handles low-level http requests to orangedata, including auth
  class Transport

    DEFAULT_TEST_API_URL = "https://apip.orangedata.ru:2443/api/v2/"
    DEFAULT_PRODUCTION_API_URL = "https://api.orangedata.ru:12003/api/v2/"

    def initialize(api_url=DEFAULT_TEST_API_URL, credentials=Credentials.default_test)
      raise ArgumentError, "Need full credentials for connection" unless credentials.valid?
      @credentials = credentials
      @api_url = api_url
    end

    # middleware for request signatures
    class RequestSignatureMiddleware < Faraday::Middleware
      def initialize(app, signature_key)
        @app = app
        @signature_key = signature_key
      end

      def call(env)
        if env.body
          signature = @signature_key.sign(OpenSSL::Digest::SHA256.new, env.body)
          env.request_headers['X-Signature'] = Base64.strict_encode64(signature)
        end
        @app.call(env)
      end
    end

    def transport
      @transport ||= Faraday.new(
        url: @api_url,
        ssl: {
          client_cert: @credentials.certificate,
          client_key: @credentials.certificate_key,
        }
      ) do |conn|
        conn.headers['User-Agent'] = "OrangeDataRuby/#{OrangeData::VERSION}"
        conn.headers['Accept'] = "application/json"
        conn.request(:json)
        conn.use(RequestSignatureMiddleware, @credentials.signature_key)
        conn.response :json, content_type: /\bjson$/
        conn.adapter(Faraday.default_adapter)
      end
    end

    def raw_post(method, data)
      transport.post(method, data)
    end

    def post_request(method, data)
      raw_post(method, data).tap{|resp|
        if resp.status == 401
          # TODO: better exceptions
          raise 'Unauthorized'
        end
      }
    end

    def post_entity(sub_url, data)
      res = post_request(sub_url, data)

      case res.status
      when 201
        return true
      when 409
        raise "Conflict"
      when 400
        raise "Invalid doc: #{res.body['errors'] || res.body}"
      when 503
        if res.headers['Retry-After']
          raise "Document queue full, retry in #{res.headers['Retry-After']}"
        end
      end
      raise "Unknown code from OD: #{res.status} #{res.reason_phrase} #{res.body}"
    end

    def get_entity(sub_url)
      res = transport.get(sub_url)

      case res.status
      when 200
        return res.body
      when 400
        raise "Cannot get doc: #{res.body['errors'] || res.body}"
      when 401
        raise 'Unauthorized'
      end
    end

    # Below actual methods from api

    def ping
      res = transport.get(''){|r| r.headers['Accept'] = 'text/plain' }
      res.status == 200 && res.body == "Nebula.Api v2"
    rescue StandardError => _e
      return false
    end

    def post_document_validate(data)
      res = post_request 'validateDocument', data

      case res.status
      when 200
        return true
      when 400
        return res.body["errors"]
      else
        raise "Unexpected response: #{res.status} #{res.reason_phrase}"
      end
    end

    def post_document(data)
      post_entity 'documents', data
    end

    def get_document(inn, document_id)
      ReceiptResult.from_hash(get_entity("documents/#{inn}/status/#{document_id}"))
    end

    def post_correction(data)
      post_entity 'corrections', data
    end

    def get_correction(inn, document_id)
      CorrectionResult.from_hash(get_entity("corrections/#{inn}/status/#{document_id}"))
    end

  end
end
