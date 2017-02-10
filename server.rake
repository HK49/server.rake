namespace :guard do
  
  desc 'Starts guard *with* puma server'
  task :start do # puma:start is almost the same - should simplify
    arg = {} # Hash.new
    o = OptionParser.new # can call task with options, see below:
    o.banner = "Usage: rake [task] -- [options]"
    # options can be given even from parent task(what if two child tasks with same opts?)
    o.on("-c", "--clear", "The shell will be cleared after each change") { 
      arg[:mode] = "--clear"
    }
    o.on("-n f", "--notify false", "System notifications will be disabled") {
      arg[:mode] = "--notify false"
    }
    o.on("-d", "--debug", "Guard will display debug information") {
      arg[:mode] = "--debug"
    } # there are more modes in guard, just didn't include 'em
    o.on("-h", "--help", "Prints this help") { 
      puts o
      exit(0)
    }
    args = o.order!(ARGV) {}
    o.parse!(args)
    
    trap('INT') {
      puts("\nRake: INT signal, handling inside trap...\n")
      exit(0)
    } # exit task witch ^C
    
    begin
      Rake::Task['puma:kill'].execute unless Rake.application.top_level_tasks.join(', ').include?('puma')
      Rake::Task['psql:start'].invoke
      arg[:mode] ? sh("bundle exec guard #{arg[:mode]}") : system("bundle exec guard")
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
      printf("Rake: 'guard:start' ended.\n")
      if File.exists?("tmp/pids/puma.pid") # can exclude and just execute 'puma:kill'
        pid = File.open("tmp/pids/puma.pid", "rb") { |i| i.read(4).to_i }
        system("kill -s SIGTERM #{pid}")
      end
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
task :guard => 'guard:start'

namespace :puma do
  
  desc 'Starts postgresql service *and* puma server'
  task :start do
    trap('INT') {
      puts("\nRake: INT signal, handling inside trap...\n")
      exit(0)
    }
    begin
      Rake::Task['psql:start'].execute
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
      printf "Rake: 'puma:start' ended.\n"
      if File.exists?("tmp/pids/puma.pid") # can exclude and just execute 'puma:kill'
        pid = File.open("tmp/pids/puma.pid", "rb") { |i| i.read(4).to_i }
        system("kill -s SIGTERM #{pid}")
      end
    end
  end
  
  desc 'Kills puma on tcp:8080' # port, where puma runs (8080 is standart on C9)
  task :kill do # each puma process on 8080 port will be terminated
    `ps aux | grep puma | grep -v grep | awk '{print $2}'`.split("\n").map do |i|
      system("kill -s SIGTERM #{i}") if `lsof -i TCP:8080 -t`.split("\n").include?(i)
    end # still puma has controll servers
  end
  
  desc 'Nukes tcp:8080'
  task :overkill do # all processes on 8080 will be killed
    `lsof -i TCP:8080 -t`&.split("\n").to_a.each { |i| system("kill -9 #{i}") }
  end
end

desc 'Starts postgresql service *and* puma server'
task :puma do
  Rake::Task['puma:kill'].execute # Prevent Errno::EADDRINUSE - Address already in use
  # Rake::Task['guard:start'].execute if ARGV.include?("--") # skip IO. modes are only in guard
  STDOUT.puts "Do you want to guard puma server?(\e[42my\e[0m/\e[41mn\e[0m)\n" # colors for 'y' & 'n'
  /Y/ =~ STDIN.gets.chomp.upcase ? Rake::Task['guard'].invoke : Rake::Task['puma:start'].execute
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
    unless online
      begin
        Timeout.timeout(20) do
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
    system("sudo service postgresql stop") if !!online
  end
  
  desc 'Tells postgresql service status'
  task :online? do
    puts("#{online}")
  end
  
  def online
    `service postgresql status`.include?('online') ? true : false
  end
end