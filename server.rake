def puma_pidfile # puma pid file path
  @puma_pidfile = ENV['PIDFILE'] || "tmp/pids/puma.pid"
end

def puma_port # port where puma runs
  @puma_port = ENV['PORT'] || "8080"
end

namespace :guard do
  
  desc 'Starts guard *with* puma server'
  task :start => :environment do
    arg = {}
    o = OptionParser.new # 'cause namespace:task'[:opt1, :opt2]' is ugly for me
    o.banner = "Usage: rake [task] -- [options]"
    # options can be given even from parent task(what if two child tasks with same opts?)
    o.on("-c", "--clear", "The shell will be cleared after each change") { 
      arg[:c] = "--clear"
    }
    o.on("-n f", "--notify false", "System notifications will be disabled") {
      arg[:nf] = "--notify false"
    }
    o.on("-d", "--debug", "Guard will display debug information") {
      arg[:d] = "--debug"
    } # there are more modes in guard - add if needed
    o.on("--trace", "Runs rake task with trace") { 
      Rails.logger.level = Logger::DEBUG
    }
    o.on("-h", "--help", "Prints this help") { 
      puts o
      exit(0)
    }
    args = o.order!(ARGV) {}
    o.parse!(args)
    
    trap('INT') {
      puts("\nRake: INT signal, handling inside trap...\n")
      sleep(5)
      exit(0)
    } # exit task witch ^C
    
    begin
      arg.empty? ? system("bundle exec guard") : sh("bundle exec guard #{arg.values.join(' ')}")
    rescue StandardError => error
      error.each { |e|
        printf(
          "\n#{e.class ? (e.message ? ("#{e.class} #{e.message}") : "#{e.class}") : ''}\n"
        )
      }
      raise
    else
      printf "Rake: 'guard:start' is complited without errors.\n"
    ensure
      Rake::Task['puma:kill'].execute
      printf("Rake: '#{Rake.application.top_level_tasks.join(', ')}' ended.\n")
    end
  end
  
  desc 'Restarts guard, puma server *and* pg'
  task :restart do |t, arg|
    begin
      Rake::Task['puma:kill'].execute
      Rake::Task['psql:restart'].execute
      Rake::Task['guard:start'].execute
    end
  end
end

desc 'Starts guard *with* puma server'
task :guard => ['psql:start', 'puma:kill', 'guard:start']

namespace :puma do
  
  desc 'Starts postgresql service *and* puma server'
  task :start do
    trap('INT') {
      puts("\nRake: INT signal, handling inside trap...\n")
      sleep(5)
      exit(0)
    } # exit task witch ^C
    begin
      system("bundle exec puma")
    rescue StandardError => error
      error.each { |e|
        printf(
          "#{e.class ? (e.message ? ("#{e.class} #{e.message}") : "#{e.class}") : ''}\n"
        )
      }
      raise
    else
      printf "Rake: 'puma:start' is complited without errors.\n"
    ensure
      Rake::Task['puma:kill'].execute
      printf("Rake: '#{Rake.application.top_level_tasks.join(', ')}' ended.\n")
    end
  end
  
  desc 'Terminates puma. Port and Pid file path should be defined in taskfile'
  task :kill do 
    if File.exists?("#{puma_pidfile}")
      pid = File.open("#{puma_pidfile}", "rb") { |i| i.read(4).to_i }
      system("kill -s SIGTERM #{pid}")
      File.delete("#{puma_pidfile}")
    end # puma will be terminated corresponding to pid file
    2.times {
      `ps aux | grep puma | grep -v grep | awk '{print $2}'`.split("\n").map do |i|
        system("kill -s SIGTERM #{i}") if `lsof -i TCP:#{puma_port} -t`.split("\n").include?(i)
      end # each puma process on corresponding port will be terminated
      sleep(2)
    }
  end
  
  desc 'Nukes tcp. Port should be defined in taskfile'
  task :overkill do # all processes on #{puma_port} will be killed
    2.times {
      `lsof -i TCP:#{puma_port} -t`.split("\n").each { |i| system("kill -9 #{i}") }
      sleep(2)
    } # seems like it needs to be executed twice. 'cause sometimes on first run array has only one value
  end
end

desc 'Starts postgresql service *and* puma server'
task :puma do
  Rake::Task['psql:start'].execute # Prevent PG::ConnectionBad
  Rake::Task['puma:kill'].execute # Prevent Errno::EADDRINUSE - Address already in use
  STDOUT.puts "Do you want to guard puma server?(\e[42my\e[0m/\e[41mn\e[0m)\n"
  input = ""
  begin
    Timeout.timeout(15) do
      input = STDIN.gets.chomp.upcase
      puts "Rake: Starting puma server with guard..."
    end
  rescue Timeout::Error
    puts "Rake: Starting puma server without guard..."
  end
  /Y/ =~ input ? Rake::Task['guard'].invoke : Rake::Task['puma:start'].execute
end

namespace :psql do
  
  desc 'Starts postgresql service'
  task :start do
    system("sudo service postgresql start") if `service postgresql status`.include?('down')
    Rake::Task['psql:connect'].invoke
  end
  
  desc 'Connects ActiveRecord to postgres db'  
  task :connect => :environment do
    unless ActiveRecord::Base.connection.active?
      ActiveRecord::Base.establish_connection
      printf("[#{Process.pid}] * PG::Connection was dead. Reestablished.")
    else
      system("echo \"[#{Process.pid}] * PG::Connection is online.\"")
    end
  end
  
  desc 'Restarts postgresql service'
  task :restart do
    unless psql_on
      begin
        Timeout.timeout(15) do
          STDOUT.puts "You want to retard inactive server, you sure?(\e[42my\e[0m/\e[41mn\e[0m)\n"
          /Y/ =~ STDIN.gets.chomp.upcase ? 
            system("sudo service postgresql restart")\
            : abort("Didn't see \"y\". Aborted.")
        end
      rescue Timeout::Error
        system("sudo service postgresql restart")
      end
    else
      printf "Retarding...\t<- saw the joke?\n"
      system("sudo service postgresql restart")
    end
  end
  
  desc 'Stops postgresql service'
  task :stop do
    system("sudo service postgresql stop") if !!psql_on
  end
  
  desc 'Tells postgresql service status'
  task :online? do
    puts("#{psql_on}")
  end
  
  def psql_on
    `service postgresql status`.include?('online') ? true : false
  end
end
