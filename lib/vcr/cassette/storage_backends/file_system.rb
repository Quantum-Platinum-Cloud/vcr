require 'fileutils'

module VCR
  class Cassette
    class StorageBackends
      module FileSystem
        extend self

        attr_reader :storage_location

        # User can set where to store the files
        def storage_location=(dir)
          FileUtils.mkdir_p(dir) if dir
          @storage_location = dir ? absolute_path_for(dir) : nil
        end

        def [](file_name)
          path = absolute_path_to_file(file_name)
          return nil unless File.exist?(path)
          File.read(path)
        end

        def []=(file_name, content)
          path = absolute_path_to_file(file_name)
          directory = File.dirname(path)
          FileUtils.mkdir_p(directory) unless File.exist?(directory)
          File.open(path, 'w') { |f| f.write(content) }
        end

        def absolute_path_to_file(file_name)
          return nil unless storage_location
          File.join(storage_location, file_name)
        end

      private

        def absolute_path_for(path)
          Dir.chdir(path) { Dir.pwd }
        end
      end
    end
  end
end