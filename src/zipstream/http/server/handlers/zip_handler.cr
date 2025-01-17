module Zipstream
  class ZipHandler
    include HTTP::Handler

    property config

    def initialize(@config : Config)
    end

    def call(context)
      context.response.content_type = "application/zip"
      context.response.headers["Content-Disposition"] = "attachment; filename=\"#{config.filename}\""

      reader, writer = IO.pipe

      spawn same_thread: true do
        while line = reader.gets(chomp: false)
          context.response.puts(line)
        end

        reader.close
      end

      if File.directory?(config.path)
        zip_directory!(config.path, writer)
      else
        zip_file!(config.path, writer)
      end

      writer.close

      Fiber.yield

      call_next(context)
    end

    private def zip_directory!(path : String, io : IO)
      Zip64::Writer.open(io) do |zip|
        Dir.glob(File.join(path, "**/*"), match_hidden: config.hidden?).each do |entry|
          next unless File.readable?(entry)

          relative_path = [config.prefix, entry.sub(path, "").lstrip("/")].compact.join("/")

          if File.directory?(entry)
            zip.add_dir(relative_path)
          else
            zip.add(relative_path, File.open(entry))
          end
        end
      end
    end

    private def zip_file!(file : String, io : IO)
      Zip64::Writer.open(io) do |zip|
        zip.add("/#{File.basename(file)}", File.read(file))
      end
    end
  end
end
