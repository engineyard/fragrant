require 'spec_helper'
require 'fileutils'
require 'tempfile'

describe Fragrant::VagrantfileGenerator do
  before do
    @original_pwd = Dir.pwd
    @working_directory = Dir.mktmpdir('fragrant-')
    Dir.chdir @working_directory
  end

  after do
    Dir.chdir @original_pwd
    FileUtils.rm_rf @working_directory
  end

  it 'should create a Vagrantfile' do
    v = Fragrant::VagrantfileGenerator.new(Dir.pwd)
    v.write
    File.exist?(File.join(Dir.pwd, 'Vagrantfile')).should be_true
  end

  describe 'with a provisioning script passed as an option' do
    before do
      v = Fragrant::VagrantfileGenerator.new(Dir.pwd)
      @custom_script = "#!/not/really/bin/bash\nDo this thing!"
      v.add_script @custom_script
      v.write
    end

    it 'should write the provisioning script as a separate file' do
      File.read(File.join(Dir.pwd, 'script001')).should == @custom_script
    end

    it 'should refer to the provisioning script in the Vagrantfile' do
      vagrantfile = File.read(File.join(Dir.pwd, 'Vagrantfile'))
      vagrantfile.split("\n").grep(/provision.*script001/).should_not be_empty
    end
  end
end
