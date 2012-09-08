require 'fileutils'
require 'erb'

module Fragrant
  class VagrantfileGenerator

    attr_accessor :addresses

    def self.template_path
      File.expand_path(File.join(File.dirname(__FILE__), '..', 'templates', 'Vagrantfile'))
    end

    def initialize(target_directory, opts={})
      @target_directory = target_directory
      @scripts          = []
      @addresses        = []
      @box_name         = opts[:box_name]
      @box_url          = opts[:box_url]
    end

    def box_name
      @box_name || "base32"
    end

    def box_url
      @box_url || "http://example.com/base32.box"
    end

    def add_script(contents)
      @scripts << contents
      true
    end

    def writeable_scripts
      retval = {}
      @scripts.each_with_index do |contents, i|
        retval[sprintf("script%03d", i + 1)] = contents
      end
      retval
    end

    def write
      FileUtils.mkdir_p(@target_directory)

      writeable_scripts.each do |filename, contents|
        File.open(File.join(@target_directory, filename), 'w') { |f| f.print contents }
      end

      contents = Vagrant::Util::TemplateRenderer.render(self.class.template_path,
                                                        :box_name => box_name,
                                                        :box_url => box_url,
                                                        :provision_script_paths => writeable_scripts.keys.sort,
                                                        :addresses => addresses)
      File.open(File.join(@target_directory, 'Vagrantfile'), 'w') { |f| f.print contents }

      true
    end
  end
end
