# frozen_string_literal: true

require "net/http"
require "uri"
require "nokogiri"

module ISpeaker
  class WebContentFetcher
    def initialize
      @timeout = 30
    end

    def fetch_content(url)
      uri = parse_url(url)
      return error_result("Invalid URL format") unless uri

      http_response = fetch_http_response(uri)
      return http_response unless http_response[:success]

      content = extract_content(http_response[:body], http_response[:content_type])
      return error_result("Failed to extract readable content") if content.strip.empty?

      success_result(content, uri.to_s)
    rescue StandardError => e
      error_result("Network error: #{e.message}")
    end

    private

    def parse_url(url)
      # Add protocol if missing
      url = "https://#{url}" unless url.match?(%r{\Ahttps?://})

      uri = URI.parse(url)
      return nil unless uri.is_a?(URI::HTTP)

      uri
    rescue URI::InvalidURIError
      nil
    end

    def fetch_http_response(uri)
      Net::HTTP.start(uri.host, uri.port, use_ssl: uri.scheme == "https",
                                          open_timeout: @timeout, read_timeout: @timeout) do |http|
        request = Net::HTTP::Get.new(uri)
        request["User-Agent"] = "ISpeaker-WebFetcher/1.0"
        request["Accept"] = "text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8"

        response = http.request(request)

        case response
        when Net::HTTPSuccess
          { success: true, body: response.body, content_type: response.content_type }
        when Net::HTTPRedirection
          # Handle redirects (up to 3 levels)
          redirect_url = response["location"]
          return error_result("Too many redirects") if redirect_url.nil?

          new_uri = URI.join(uri.to_s, redirect_url)
          return fetch_http_response(new_uri) if redirect_count(uri, new_uri) < 3

          error_result("Too many redirects")
        else
          error_result("HTTP #{response.code}: #{response.message}")
        end
      end
    rescue Net::TimeoutError
      error_result("Request timed out after #{@timeout} seconds")
    rescue Net::HTTPError => e
      error_result("HTTP error: #{e.message}")
    rescue SocketError => e
      error_result("Network error: #{e.message}")
    end

    def extract_content(html_body, content_type)
      return html_body if content_type&.include?("text/plain")

      # Parse HTML and extract meaningful content
      doc = Nokogiri::HTML(html_body)

      # Remove script and style elements
      doc.css("script, style, nav, footer, aside, .sidebar, .navigation").remove

      # Try to find main content area
      main_content = find_main_content(doc)

      # Extract text and clean it up
      text = main_content.text
      clean_text(text)
    rescue Nokogiri::XML::SyntaxError
      # If HTML parsing fails, try to extract basic text
      html_body.gsub(/<[^>]*>/, " ").squeeze(" ").strip
    end

    def find_main_content(doc)
      # Try common content selectors in order of preference
      content_selectors = [
        "main",
        "article",
        ".content",
        ".main-content",
        ".post-content",
        ".entry-content",
        "#content",
        "#main",
        "body"
      ]

      content_selectors.each do |selector|
        element = doc.css(selector).first
        return element if element && !element.text.strip.empty?
      end

      # Fallback to body
      doc.css("body").first || doc
    end

    def clean_text(text)
      # Remove excessive whitespace and normalize
      cleaned = text.gsub(/\s+/, " ").strip

      # Remove common navigation/UI text that isn't useful
      lines = cleaned.split("\n")
      filtered_lines = lines.reject do |line|
        line.strip.length < 10 || # Too short to be meaningful
          line.match?(/^(home|about|contact|menu|search|login|sign up)$/i) ||
          line.match?(/^(copyright|©|\d{4})/i)
      end

      filtered_lines.join("\n").strip
    end

    def redirect_count(original_uri, redirect_uri)
      # Simple redirect tracking to prevent infinite loops
      @redirect_count ||= 0
      @redirect_count += 1 if original_uri.host != redirect_uri.host
      @redirect_count
    end

    def success_result(content, url)
      {
        success: true,
        content: content,
        url: url
      }
    end

    def error_result(message)
      {
        success: false,
        error: message
      }
    end
  end
end
