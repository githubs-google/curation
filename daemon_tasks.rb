class DaemonTasks
  NODES = [
    ENV["DURENDAL_NODE"],
    ENV["GUNGNIR_NODE"],
    ENV["MIGL_NODE"]
  ]

  # nodes: by index of NODES. I.e. 0, 1, 2
  def initialize(node_ids = nil)
    @node_ids = node_ids == ['all'] ? all_node_ids : node_ids
  end

  def list_nodes
    NODES.each_with_index do |el, i|
      puts "#{i}:"
      name, ip = el.split('@')
      puts "\tNAME: #{name}"
      puts "\tIP: #{ip}"
      puts
    end
  end

  def start(process)
    @curr_process = process

    @node_ids.each do |n|
      @curr_node = n
      if running?
        puts "Node #{node_name} is currently running"
        next
      end

      init_daemon_folder_structure
      ensure_pidfile
      task = which_task
      write_task_script(task)

      execution = ssh_current
      execution += " \"start-stop-daemon -v --start"
      execution += " -m --pidfile #{pidfile_path}"
      execution += " -u #{user} -d #{working_directory}"
      execution += " -b --startas #{execution_path}\""
      puts `#{execution}`
    end
    status
  end

  def kill
    @node_ids.each do |n|
      @curr_node = n
      if !running?
        puts "Node #{node_name} is not currently running."
        next
      end
      process = `#{ssh_current} ls #{execution_dir}`.chomp
      pid = `#{ssh_current} cat #{pidfile_dir}/*`.chomp
      output = `#{ssh_current} ps --ppid #{pid}`
      ppid = output.split("\n")[1].strip[/^[0-9]+/]
      `#{ssh_current} kill #{ppid}`
      clear_node_task_files
      puts "Process #{process} killed on #{node_name}"
    end
    status
  end

  def restart
    kill
    start('all')
  end

  def status
    nodes = @node_ids || all_node_ids
    nodes.each do |n|
      @curr_node = n
      puts "#{n}:"
      has_no_working_directory = `#{ssh_current} "ls #{working_directory}"`.empty?
      if has_no_working_directory
        puts "\tNOT YET SET UP. Node #{node_name} has not even been set up to run yet."
        puts
        next
      end

      daemon_struct = `#{ssh_current} "ls -a #{working_directory}"`.include?('.daemon_tasks')
      if !daemon_struct
        puts "\tNEVER BEEN RUN. Node #{node_name} has never been run."
        puts
        next
      end

      process = `#{ssh_current} "ls #{execution_dir}"`.chomp
      msg = if running?
              "RUNNING: Node #{node_name} with process #{process}."
            elsif !running? && !process.empty?
              "SHOULD BE RUNNING: Node #{node_name} should be running process #{process}."
            else
              "NOT RUNNING: Node #{node_name} is currently waiting for a job."
            end
      puts "\t" + msg
      puts
    end
  end

  private

  def init_daemon_folder_structure
    # --parents makes no errors thrown if extra folders need to be made
    `#{ssh_current} mkdir #{pidfile_dir} --parents`
    `#{ssh_current} mkdir #{execution_dir} --parents`
  end

  def which_task
    case @curr_process
    when 'commits'
      'rake dispatch:scrape_commits'
    when 'issues'
      'rake dispatch:scrape_issues'
    when 'metadata'
      'rake dispatch:scrape_metadata'
    when 'scrape_once'
      'rake dispatch:scrape_once'
    end
  end

  def write_task_script(task)
    `#{ssh_current} touch #{execution_path}`
    bash_path = `#{ssh_current} which bash`
    `#{ssh_current} 'echo "#!#{bash_path}" > #{execution_path}'`
    `#{ssh_current} 'echo "#{task}" >> #{execution_path}'`
    `#{ssh_current} chmod u=rwx #{execution_path}`
  end

  def running?
    pid = `#{ssh_current} cat #{pidfile_dir}/*`.chomp
    if `#{ssh_current} ps -fp #{pid}`.split("\n").count == 1
      false
    else
      true
    end
  end

  def user(ssh = true)
    if ssh
      node_name.split('@').first
    else
      `echo $USER`.chomp
    end
  end

  def clear_node_task_files
    # TODO: make sure this works
    task_files = `#{ssh_current} ls #{execution_dir}/`.split("\n")
    task_files.each { |f| `#{ssh_current} rm #{execution_dir}/#{f}`}
  end

  def ssh_current
    "ssh #{node_name}"
  end

  def working_directory
    "/home/#{user}/workspace/capstone"
  end

  def pidfile_dir
    "#{working_directory}/.daemon_tasks/tmp"
  end

  def pidfile_path
    pidfile = "#{execution_file}.pid"
    "#{pidfile_dir}/#{pidfile}"
  end

  def ensure_pidfile
    `#{ssh_current} touch #{pidfile_path}`
  end

  def execution_dir
    "#{working_directory}/.daemon_tasks/tasks"
  end

  def execution_file
    "#{@curr_process}_scraper"
  end

  def execution_path
    "#{execution_dir}/#{execution_file}"
  end

  def node_name
    NODES[@curr_node]
  end

  def all_node_ids
    (0...NODES.count).to_a
  end
end
