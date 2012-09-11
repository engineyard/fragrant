require 'grape'
require 'thread'
require 'fileutils'
require 'uuid'
require 'vagrant'
require 'fragrant/vagrantfile_generator'
require 'fragrant/address_manager'

module Fragrant
  def self.env_dir
    @env_dir ||= begin
                   dir = ENV["FRAGRANT_ENV_DIR"] || File.expand_path("~/.fragrant")
                   FileUtils.mkdir_p(dir)
                   dir
                 end
  end

  def self.address_manager
    data_location = File.join(Fragrant.env_dir, "addresses.json")
    range = ENV["FRAGRANT_IP_RANGE"] || "172.24.24.128/25"
    @address_manager ||= AddressManager.new(data_location, range)
  end

  def self.add_task(task)
    background_worker
    tasks.push(task)
  end

  # Tasks are two-element Arrays of a machine id and a set of vagrant args
  def self.tasks
    @tasks ||= Queue.new
  end

  def self.create_worker_thread
    thread = Thread.new do
      Thread.current.abort_on_exception = true
      until Thread.current[:shutdown] do
        unless Fragrant.tasks.empty?
          task = Fragrant.tasks.pop
          env = Vagrant::Environment.new({ :cwd => File.join(env_dir, task[:id]) })
          env.cli(task[:args])
        end
      end
    end

    at_exit do
      $stderr.puts "Waiting for any running Vagrant tasks to complete."
      thread[:shutdown] = true
      thread.join
    end
    thread
  end

  def self.background_worker
    @background_worker ||= create_worker_thread
  end

  class Frontend < Grape::API
    version 'v1', :using => :header, :vendor => 'fragrant'
    format :json

    ENV_REGEX = /[a-f0-9]{8}-[a-f0-9]{4}-[a-f0-9]{4}-[a-f0-9]{4}-[a-f0-9]{12}/

    rescue_from :all do |e|
      rack_response({ :message => "Encountered exception: #{e}", :backtrace => e.backtrace }, 500, {"Content-Type" => "application/json"})
    end

    helpers do
      def add_task(task)
        Fragrant.add_task(task)
      end

      def box_name
        params[:box_name] || 'precise32'
      end

      def box_url
        params[:box_url] || "http://files.vagrantup.com/precise32.box"
      end

      def user_script
        params[:user_data_script]
      end

      def env_dir
        Fragrant.env_dir
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

      def allocate_address(env_id)
        Fragrant.address_manager.claim_address(env_id)
      end

      def v_file(env_id, directory, contents = nil)
        addresses = [allocate_address(env_id)] unless contents
        VagrantfileGenerator.new(directory, :box_name => box_name,
                                            :box_url => box_url,
                                            :scripts => Array(user_script),
                                            :addresses => addresses,
                                            :contents => contents).write
        Array(addresses)
      end

      def make_machine_dir(machine_id)
        machine_dir = File.join(env_dir, machine_id)
        begin
          Dir.mkdir(machine_dir, 0755)
        rescue Errno::EEXIST
          error!({ "error" => "#{machine_dir} already exists!" }, 409)
        end
        machine_dir
      end
    end

    get '/' do
      {}
    end

    resource :environments do

      desc "Destroys a Vagrant environment"
      params do
        requires :id, :desc => "Vagrant environment id", :type => String, regexp: ENV_REGEX
        optional :vm_name, :desc => 'single vm to act on'
      end
      delete '/destroy/:id' do
        args = [v_action, params[:vm_name], '--force']
        v_env.cli(args.compact)
        {:id => params[:id]}
      end

      desc "Lists Vagrant environments"
      get :list do
        env_glob
      end

      desc "Halts a Vagrant environment"
      params do
        requires :id, :desc => "Vagrant environment id", :type => String, regexp: ENV_REGEX
        optional :force, :desc => 'Force shut down (equivalent of pulling power)'
        optional :vm_name, :desc => 'single vm to act on'
      end
      post '/halt/:id' do
        force = params[:force] == true ? '--force' : nil
        args = [v_action, params[:vm_name], force]
        v_env.cli(args.compact)
        {:id => params[:id]}
      end

      desc "Initializes a Vagrant environment"
      params do
        optional :vagrantfile, :desc => "Vagrant environment configuration", :type => String
      end
      post :init do
        machine = env_rand
        machine_dir = File.join(env_dir, machine)
        begin
          Dir.mkdir(machine_dir, 0755)
        rescue Errno::EEXIST
          error!({ "error" => "#{machine_dir} already exists!" }, 409)
        end
        if params[:vagrantfile].nil?
          v_env(machine).cli(v_action, box_name, box_url)
        else
          File.open(File.join(machine_dir, 'Vagrantfile'), 'w') {|f| f.write(params[:vagrantfile])}
        end
        {:id => machine}
      end

      desc "Provisions a Vagrant environment"
      params do
        requires :id, :desc => "Vagrant environment id", :type => String, regexp: ENV_REGEX
        optional :vm_name, :desc => 'single vm to act on'
      end
      post '/provision/:id' do
        args = [v_action, params[:vm_name]]
        v_env.cli(args.compact)
        {:id => params[:id]}
      end

      desc "Initialize and provision an environment, returns the environment id"
      params do
        requires :box_name, :desc => 'Name for box, used to lookup already loaded box', :type => String, :regexp => /^[\w_-]+$/
        optional :box_url, :desc => 'URL for box location, optional iff \'box_name\' exists', :type => String
        optional :user_data_script, :desc => 'Script to invoke upon provisioning'
      end
      post :create do
        machine_id = env_rand
        machine_dir = make_machine_dir(machine_id)
        addresses = v_file machine_id, machine_dir
        args = 'up', '--provision'
        add_task(:id => machine_id, :args => args)
        {:id => machine_id, :ips => addresses}
      end

      desc "Initializes a Vagrant environment"
      params do
        optional :vagrantfile, :desc => "Vagrant environment configuration", :type => String
      end
      post :init do
        machine_id = env_rand
        machine_dir = make_machine_dir(machine_id)
        if params[:vagrantfile].nil?
          v_env(machine_id).cli(v_action, box_name, box_url)
        else
          v_file(machine_id, machine_dir, params[:vagrantfile])
        end
        {:id => machine_id}
      end

      desc "Purges a Vagrant environment"
      params do
        requires :id, :desc => "Vagrant environment id", :type => String, regexp: ENV_REGEX
      end
      post '/purge/:id' do
        if v_env.vms.all? {|vm| vm.last.state == 'not_created'}
          machine_dir = File.join(env_dir, params[:id])
          FileUtils.remove_entry_secure(machine_dir)
        else
          error!({ "error" => "Environment contains undestroyed machines!" }, 409)
        end
        {:id => params[:id]}
      end

      desc "Reloads a Vagrant environment"
      params do
        requires :id, :desc => "Vagrant environment id", :type => String, regexp: ENV_REGEX
        optional :no_provision, :desc => 'disable provisioning'
        optional :vm_name, :desc => 'single vm to act on'
      end
      post '/reload/:id' do
        provision = params[:no_provision] == true ? '--no-provision' : '--provision'
        args = [v_action, params[:vm_name], provision]
        v_env.cli(args.compact)
        {:id => params[:id]}
      end

      desc "Resumes a Vagrant environment"
      params do
        requires :id, :desc => "Vagrant environment id", :type => String, regexp: ENV_REGEX
        optional :vm_name, :desc => 'single vm to act on'
      end
      post '/resume/:id' do
        args = [v_action, params[:vm_name]]
        v_env.cli(args.compact)
        {:id => params[:id]}
      end

      desc "Prints the status of a Vagrant environment"
      params do
        requires :id, :desc => "Vagrant environment id", :type => String, regexp: ENV_REGEX
      end
      get '/status/:id' do
        state = {}
        v_env.vms.each do |vm|
          state[vm.first] = vm.last.state
        end
        {:status => state}
      end

      desc "Suspends a Vagrant environment"
      params do
        requires :id, :desc => "Vagrant environment id", :type => String, regexp: ENV_REGEX
        optional :vm_name, :desc => 'single vm to act on'
      end
      post '/suspend/:id' do
        args = [v_action, params[:vm_name]]
        v_env.cli(args.compact)
        {:id => params[:id]}
      end

      desc "Boots a Vagrant environment"
      params do
        requires :id, :desc => "Vagrant environment id", :type => String, regexp: ENV_REGEX
        optional :no_provision, :desc => 'disable provisioning'
        optional :vm_name, :desc => 'single vm to act on'
      end
      post '/up/:id' do
        provision = params[:no_provision] == true ? '--no-provision' : '--provision'
        args = [v_action, params[:vm_name], provision]
        v_env.cli(args.compact)
        {:id => params[:id]}
      end

    end

    resource :vms do

      desc "Lists registered virtual machines"
      get :registered do
        out = %x{VBoxManage list vms}
        {:vms => out.split('\n')}
      end

      desc "Lists running virtual machines"
      get :running do
        out = %x{VBoxManage list runningvms}
        {:vms => out.split('\n')}
      end

    end
  end
end
