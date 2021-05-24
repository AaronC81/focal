module Focal
  module EPEG
    def self.available?
      `epeg`
      $?.success?
    rescue
      false
    end

    def self.available!
      raise 'the "epeg" executable is not on the PATH, or is not working' unless available?
    end

    def self.create_thumbnail(input_file, output_file, width: nil, height: nil, preserve: false)
      raise "must give both width and height when preserve is false" \
        if !preserve && !(width && height)

      raise "must give only one of width and height when preserve is true" \
        if preserve && (width && height)

      flags = []
      flags << "-w #{width}" if width
      flags << "-h #{height}" if height
      flags << "-p" if preserve

      output = `epeg #{flags.join(" ")} "#{input_file}" "#{output_file}"`

      raise "epeg error: #{output}" unless $?.success?
    end
  end
end
