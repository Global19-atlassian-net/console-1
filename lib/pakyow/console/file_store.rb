require 'mini_magick'
require 'fileutils'

require_relative 'file_store_adapters/database_adapter'
require_relative 'file_store_adapters/file_system_adapter'

module Pakyow::Console
  class FileStore
    include Singleton

    CONTEXT_MEDIA = 'media'
    CONTEXT_THUMB = 'thumb'
    CONTEXT_APP   = 'app'

    def self.type_for_ext(ext)
      case ext.downcase
      when '.png', '.gif', '.jpg', '.jpeg'
        'image'
      when '.mp4', '.webm', '.ogv'
        'video'
      when '.mp3', '.wav'
        'audio'
      else
        'unknown'
      end
    end

    def initialize
      @adapter = Pakyow::Config.console.file_store_adapter.new
    end

    def store(filename, tempfile, context: CONTEXT_APP)
      #TODO raise exception rather than return
      return if filename.nil? || tempfile.nil?

      ext = File.extname(filename).downcase
      type = self.class.type_for_ext(ext)
      hash = Digest::MD5.file(tempfile).hexdigest

      width, height = case type
      when 'image'
        size = ImageSize.new(tempfile)
        [size.width, size.height]
      end

      metadata = {
        id: hash,
        filename: filename,
        size: File.size(tempfile),
        ext: ext,
        type: type,
        context: context,
      }

      metadata[:width] = width unless width.nil?
      metadata[:height] = height unless height.nil?

      @adapter.store(tempfile, metadata)

      # always return the metadata
      metadata
    end

    def find(hash)
      @adapter.find(hash)
    end

    def all
      @adapter.all
    end

    def processed(hash, w: nil, h: nil)
      file = find(hash)
      return if file[:type] != 'image'

      processed = @adapter.processed(file[:id], w: w, h: h)
      return processed unless processed.nil?

      file[:width] = w
      file[:height] = h
      file[:context] = CONTEXT_THUMB

      process(file, w: w, h: h)
    end

    def process(file, w: nil, h: nil)
      image = MiniMagick::Image.read(@adapter.data(file[:id]))
      image.resize "#{w}x#{h}^"
      image.combine_options do |i|
        i.gravity "center"
        i.extent "#{w}x#{h}"
      end

      data = image.to_blob
      @adapter.process(file, data, w: w, h: h)

      # always return the processed data
      data
    end

    def data(hash)
      @adapter.data(hash)
    end
  end
end
