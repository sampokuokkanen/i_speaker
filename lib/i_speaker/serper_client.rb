# frozen_string_literal: true

require "uri"
require "json"
require "net/http"

module ISpeaker
  class SerperClient
    SERPER_API_URL = "https://google.serper.dev/search"

    def initialize
      @api_key = ENV.fetch("SERPER_KEY", nil)
      @timeout = 10
    end

    def available?
      !@api_key.nil? && !@api_key.empty?
    end

    def search(query, options = {})
      return error_result("Serper API key not available. Please set SERPER_KEY environment variable.") unless available?

      begin
        response = make_request(query, options)
        parse_search_response(response)
      rescue StandardError => e
        error_result("Search failed: #{e.message}")
      end
    end

    def search_for_fact_checking(claims)
      return [] unless available?

      results = []

      claims.each do |claim|
        # Generate targeted search queries for fact-checking
        search_queries = generate_fact_check_queries(claim)

        search_queries.each do |query|
          result = search(query, { num: 5 })
          if result[:success]
            results << {
              claim: claim,
              query: query,
              search_results: result[:data]
            }
          end

          # Small delay to be respectful to the API
          sleep(0.5)
        end
      end

      results
    end

    private

    def make_request(query, options = {})
      uri = URI(SERPER_API_URL)

      http = Net::HTTP.new(uri.host, uri.port)
      http.use_ssl = true
      http.open_timeout = @timeout
      http.read_timeout = @timeout

      request = Net::HTTP::Post.new(uri)
      request["X-API-KEY"] = @api_key
      request["Content-Type"] = "application/json"

      # Default search parameters
      search_params = {
        q: query,
        gl: "us",
        hl: "en",
        num: options[:num] || 10,
        autocorrect: true
      }

      request.body = JSON.dump(search_params)

      response = http.request(request)

      raise "HTTP #{response.code}: #{response.message}" unless response.code == "200"

      JSON.parse(response.body)
    end

    def parse_search_response(response)
      parsed_results = {
        organic_results: [],
        knowledge_graph: nil,
        people_also_ask: [],
        related_searches: []
      }

      # Extract organic search results
      if response["organic"]
        parsed_results[:organic_results] = response["organic"].map do |result|
          {
            title: result["title"],
            link: result["link"],
            snippet: result["snippet"],
            position: result["position"]
          }
        end
      end

      # Extract knowledge graph information
      if response["knowledgeGraph"]
        kg = response["knowledgeGraph"]
        parsed_results[:knowledge_graph] = {
          title: kg["title"],
          type: kg["type"],
          description: kg["description"],
          website: kg["website"],
          attributes: kg["attributes"] || {}
        }
      end

      # Extract "People also ask" questions
      if response["peopleAlsoAsk"]
        parsed_results[:people_also_ask] = response["peopleAlsoAsk"].map do |paa|
          {
            question: paa["question"],
            snippet: paa["snippet"],
            title: paa["title"],
            link: paa["link"]
          }
        end
      end

      # Extract related searches
      if response["relatedSearches"]
        parsed_results[:related_searches] = response["relatedSearches"].map do |rs|
          rs["query"]
        end
      end

      success_result(parsed_results)
    end

    def generate_fact_check_queries(claim)
      # Generate multiple search queries to verify a claim
      base_queries = []

      # Direct claim search
      base_queries << claim

      # Add verification keywords
      base_queries << "#{claim} facts"
      base_queries << "#{claim} verify"
      base_queries << "#{claim} statistics"

      # Extract key terms for more focused searches
      key_terms = extract_key_terms(claim)
      if key_terms.any?
        base_queries << key_terms.join(" ")
        base_queries << "#{key_terms.join(" ")} latest"
      end

      # Limit to most relevant queries
      base_queries.uniq.first(3)
    end

    def extract_key_terms(text)
      # Simple keyword extraction - remove common words
      stop_words = %w[the and or but if then when where how what why who which that this these those a an in on at by
                      for with from to of is are was were be been being have has had do does did will would could should may might can about up down over under through across between among within without]

      words = text.downcase.gsub(/[^\w\s]/, "").split(/\s+/)
      keywords = words.reject { |word| stop_words.include?(word) || word.length < 3 }

      # Return most significant terms (longer words first, then frequency)
      keywords.sort_by { |word| [-word.length, -keywords.count(word)] }.uniq.first(5)
    end

    def success_result(data)
      {
        success: true,
        data: data
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
