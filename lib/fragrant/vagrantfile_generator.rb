require 'fileutils'
require 'erb'

module Fragrant
  class VagrantfileGenerator

    attr_accessor :addresses

    def self.template_path
      File.expand_path('../../templates/Vagrantfile', __FILE__)
    end

    def initialize(target_directory, opts={})
      @target_directory = target_directory
      @scripts          = opts[:scripts] || []
      @addresses        = opts[:addresses] || []
      @box_name         = opts[:box_name]
      @box_url          = opts[:box_url]
      @contents         = opts[:contents]
    end

    def box_name
      @box_name || "precise32"
    end

    def box_url
      @box_url || "http://files.vagrantup.com/precise32.box"
    end

    def add_script(contents)
      raise "body set, adding a script not supported" if @contents
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

      writeable_scripts.each do |filename, script_body|
        File.open(File.join(@target_directory, filename), 'w') do |f|
          f.print script_body
          f.chmod 0755
        end
      end

      @contents ||= Vagrant::Util::TemplateRenderer.render(self.class.template_path,
                                                           :box_name => box_name,
                                                           :box_url => box_url,
                                                           :provision_script_paths => writeable_scripts.keys.sort,
                                                           :addresses => addresses)
      File.open(File.join(@target_directory, 'Vagrantfile'), 'w') { |f| f.print @contents }

      true
    end
  end
end
