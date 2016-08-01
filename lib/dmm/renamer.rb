require 'ruby-dmm'
require 'highline/import'
require 'fileutils'

module DMM
  class Renamer
    def initialize(config, filename)
      @config = config
      @client = DMM.new(
        api_id: config["api_id"],
        affiliate_id: config["affiliate_id"],
        result_only: true,
        encode_options: {:invalid => :replace, :undef => :replace, :replace => " "}
      )
      @filename = filename
    end

    def process(noop: false)
      fetch
      result = choose do |menu|
        menu.prompt = "Select candidates. original: #{@filename}"
        items.uniq {|i| i[:title]}.each do |item|
          menu.choice(rename_pattern(item))
        end
        menu.choice("No Rename") { nil }
      end

      if result
        rename(result, noop)
      end
    end

    private

    def rename(to, noop)
      dir = File.dirname(@filename)
      if File.exist?(@filename)
        FileUtils.mv(@filename, File.join(dir, to), {noop: noop, verbose: true})
      else
        warn "#{@filename} is not found"
      end
    end

    def fetch
      @last_response = @client.product(site: "DMM.R18", sort: "rank", keyword: normalize_filename, hits: 10)
      if !items || items.empty?
        fetch_retry
      end
    end

    def fetch_retry
      @last_response = @client.product(site: "DMM.R18", sort: "rank", keyword: normalize_filename, hits: 10)
    end

    def rename_pattern(item)
      raise "rename_pattern is not found" unless @config["rename_pattern"]
      eval("\"" + @config["rename_pattern"] + "\"")
        .gsub(/\//, "／")
        .gsub(/〜/, "～") + extname
    end

    def normalize_filename
      stripped = @filename
        .gsub(/^\(.*?\)\s*/, "")
        .gsub(/^\[.*?\]\s*/, "")
      convert_charset(File.basename(stripped, ".*"))
    end

    def more_normalize_filename
      filename = normalize_filename.split(" - ").first
      convert_charset(filename)
    end

    def extname
      File.extname(@filename).downcase
    end

    def convert_charset(str)
      RUBY_PLATFORM =~ /darwin/ ? str.encode('UTF-8-MAC', 'UTF-8') : str
    end

    def items
      @last_response&.result&.[](:items)
    end
  end
end
