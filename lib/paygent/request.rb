require 'curb'
require 'iconv' if RUBY_VERSION.to_f < 1.9

module Paygent
  class Request
    attr_accessor :_params, :body_str, :header_str, :response_code, :request, :process_id

    def initialize(option={})
      self._params ||= {}
      self._params.update(option)
      if option[:force_3d]
        self._params.update({
          :merchant_id => Paygent.merchant_id_for_3d,
          :connect_id => Paygent.default_id_for_3d,
          :connect_password => Paygent.default_password_for_3d
        })
      end
      self.process_id = (rand * 100000000).to_i
      self
    end

    def valid?
    end

    def replaceTelegramKana
    end

    def validateTelegramLengthCheck
    end

    def reqPut(key, value)
      _params ||= {}
      _params[key.to_sym] = value
    end

    def reqGet(key)
      params[key.to_sym]
    end

    def params
      {
        :merchant_id => Paygent.merchant_id,
        :connect_id => Paygent.default_id,
        :connect_password => Paygent.default_password,
        :limit_count => Paygent.select_max_cnt,
        :telegram_version => Paygent.telegram_version,
      }.merge(_params || {})
    end

    def params_str
      params.map{|f,k| "#{Curl::Easy.new.escape(f)}=#{Curl::Easy.new.escape(k)}"}.join('&')
    end
    
    def params_fields
      params.map{|f,k| Curl::PostField.content(f, k) if f.present? && k.present? }
    end


    def post
      telegram_kind = params[:telegram_kind]
      base_url = Paygent::Service.get_url_with_telegram_kind(telegram_kind)
      log("Can't found related paygent URL with #{telegram_kind}") unless base_url

      c = Curl::Easy.http_post(base_url, *params_fields) do |curl|
        curl.headers["User-Agent"] = "curl_php"
        curl.headers["Content-Type"] = "application/x-www-form-urlencoded"
        curl.headers["charset"] = "Windows-31J"

        curl.cacert          = Paygent.ca_file_path
        curl.cert            = params[:force_3d] ? Paygent.client_file_path_for_3d : Paygent.client_file_path
        curl.certpassword    = Paygent.cert_password
        curl.connect_timeout = Paygent.timeout
        curl.verbose         = Paygent.verbose
        curl.ssl_verify_host = false

        curl.follow_location = true
        curl.enable_cookies = true
      end

      self.response_code = c.response_code
      self.body_str      = convert_str(c.body_str)
      self.header_str    = c.header_str
      self.request       = c

      log("ResponseCode: #{response_code}")
      log("BODY: #{body_str}")
      log("HEAD: #{header_str}\n\n")

      return self
    end

    def log(str)
      if File.exist?(Paygent.log_output_path)
        File.open(Paygent.log_output_path, "a") do |file|
          file.puts "[#{process_id}][#{params[:trading_id]}] #{str}"
        end
      end
    end

    def success_response?
      response_code.to_i == 200
    end

    def success_processed?
      body_hash[:result].to_i != 1
    end

    def body_hash
      hash = {}
      body_str.scan(/\n(\w+)=(<!DOCTYPE.*?<\/HTML>|.*?)\r/m) { hash.update($1 => $2) }
      hash.with_indifferent_access
    end

    private

    def convert_str(str)
      if RUBY_VERSION.to_f < 1.9
        Iconv.conv('utf-8','Windows-31J', str)
      else
        str.force_encoding('utf-8')
      end
    end
  end
end
