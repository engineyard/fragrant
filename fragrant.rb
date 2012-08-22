require 'grape'
require 'uuid'
require 'vagrant'

class Fragrant < Grape::API
  version 'v1', :using => :header, :vendor => 'nextgen'
  format :json

  ENV_REGEX = /[a-f0-9]{8}-[a-f0-9]{4}-[a-f0-9]{4}-[a-f0-9]{4}-[a-f0-9]{12}/

  helpers do

    def box_name
      @box_name ||= 'nextgen64'
    end

    def box_url
      @box_url ||= 'http://shunterus.s3.amazonaws.com/nextgen64.box'
    end

    def env_dir
      @env_dir ||= File.expand_path(File.join(File.dirname(__FILE__), 'vboxes'))
    end

    def env_glob
      Dir.entries(env_dir).select do |d|
        next if d.start_with?('.')
        File.exists?(File.join(env_dir, d, 'Vagrantfile'))
      end
    end

    def env_rand
      UUID.generate
    end

    def v_action
      route.route_path.split(/[\/\(]/)[2]
    end

    def v_env(id = params[:id])
      Vagrant::Environment.new({ :cwd => File.join(env_dir, id) })
    end

  end

  resource :environments do

    desc "Destroys a Vagrant environment"
    params do
      requires :id, :desc => "Vagrant environment id", :type => String, regexp: ENV_REGEX
    end
    delete '/destroy/:id' do
      v = v_env
      v.cli(v_action, '--force')
      params[:id]
    end

    desc "Lists Vagrant environments"
    get :list do
      env_glob
    end

    desc "Halts a Vagrant environment"
    params do
      requires :id, :desc => "Vagrant environment id", :type => String, regexp: ENV_REGEX
    end
    post '/halt/:id' do
      # TODO: argv --force
      v = v_env
      v.cli(v_action)
      params[:id]
    end

    desc "Initializes a Vagrant environment"
    post :init do
      machine = env_rand
      Dir.mkdir(File.join(env_dir, machine), 0755)
      v = v_env(machine)
      v.cli(v_action, box_name, box_url)
      machine
    end

    desc "Provisions a Vagrant environment"
    params do
      requires :id, :desc => "Vagrant environment id", :type => String, regexp: ENV_REGEX
    end
    post '/provision/:id' do
      v = v_env
      v.cli(v_action)
      params[:id]
    end

    desc "Reloads a Vagrant environment"
    params do
      requires :id, :desc => "Vagrant environment id", :type => String, regexp: ENV_REGEX
    end
    post '/reload/:id' do
      # TODO: argv --[no-]provision, --provision-with x,y,z
      v = v_env
      v.cli(v_action)
      params[:id]
    end

    desc "Resumes a Vagrant environment"
    params do
      requires :id, :desc => "Vagrant environment id", :type => String, regexp: ENV_REGEX
    end
    post '/resume/:id' do
      v = v_env
      v.cli(v_action)
      params[:id]
    end

    desc "Prints the status of a Vagrant environment"
    params do
      requires :id, :desc => "Vagrant environment id", :type => String, regexp: ENV_REGEX
    end
    get '/status/:id' do
      v = v_env
      { :state => v.vms[:default].state }
    end

    desc "Suspends a Vagrant environment"
    params do
      requires :id, :desc => "Vagrant environment id", :type => String, regexp: ENV_REGEX
    end
    post '/suspend/:id' do
      v = v_env
      v.cli(v_action)
      params[:id]
    end

    desc "Boots a Vagrant environment"
    params do
      requires :id, :desc => "Vagrant environment id", :type => String, regexp: ENV_REGEX
    end
    post '/up/:id' do
      # TODO: argv --[no-]provision, --provision-with x,y,z
      v = v_env
      v.cli(v_action)
      params[:id]
    end

  end

  resource :vms do

    desc "Lists registered virtual machines"
    get :registered do
      out = %x{VBoxManage list vms}
      out.split('\n')
    end

    desc "Lists running virtual machines"
    get :running do
      out = %x{VBoxManage list runningvms}
      out.split('\n')
    end

  end

end
