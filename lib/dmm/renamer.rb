require 'ruby-dmm'
require 'highline/import'
require 'fileutils'

module DMM
  class Renamer
    def initialize(config, filename)
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
        menu.prompt = "Select candidates."
        @last_response.items.uniq {|i| i.title}.each do |item|
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
      @last_response = @client.order("date").limit(10).item_list(normalize_filename)
      if @last_response.items.empty?
        fetch_retry
      end
    end

    def fetch_retry
      @last_response = @client.order("date").limit(10).item_list(more_normalize_filename)
    end

    def rename_pattern(item)
      "(AV) [#{item.info.maker[0]["name"]}] #{item.title} - #{item.info.actress.map {|act| act["name"]}.join(" ")}#{extname}"
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
      File.extname(@filename)
    end

    def convert_charset(str)
      RUBY_PLATFORM =~ /darwin/ ? str.encode('UTF-8-MAC', 'UTF-8') : str
    end
  end
end
