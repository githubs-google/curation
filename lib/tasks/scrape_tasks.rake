# TODO: extract with the ruby gems scraper and bundle the
# ruby_gems namespace rake tasks with it
namespace :ruby_gems do
  require_relative "../scraper/ruby_gems_scraper"

  # Get all gems from ruby gems
  # Can call for a single letter and x amount of gems:
  #   ex. rake scrape:gems[F, 20]
  task :gems, [:letters_to_traverse, :upsert_limit] => :environment do |t, args|
    options = args.to_h
    if args.letters_to_traverse
      options[:letters_to_traverse] = args.letters_to_traverse.split(" ")
    end

    babysitter do
      RubyGemsScraper.upsert_all_gems(options)
    end
  end

  task :top_100 => :environment do |t|
    babysitter do
      RubyGemsScraper.upsert_top_100_gems
    end
  end
end

namespace :github do
  require_relative "../scraper/github_scraper"

  # Get github repo information for each repo
  task :repos => :environment do |t|
    babysitter(t) do
      GithubScraper.update_repo_data
    end
  end

  # Get commit info from each repo
  # TODO: make args take in the 3 options for lib_commits
  task :commits, [:infinite] => :environment do |t, args|
    if args.infinite == "true"
      babysitter(t) do
        loop do
          GithubScraper.lib_commits
        end
      end
    else
      babysitter(t) do
        GithubScraper.lib_commits
      end
    end
  end

  task :all => [:repos, :commits]
end

# Get commit info from each repo using the redis queue
namespace :dispatch do
  require_relative '../scraper/scraper_dispatcher'

  task :jobs => :environment do |t|
    babysitter(t) do
      ScraperDispatcher.scrape_commits
    end
  end

  task :enqueue => :environment do
    ScraperDispatcher.redis_requeue
  end
end

namespace :github_api do
  task :search_repos => :environment do
    require_relative '../api/github_search_wrapper.rb'
    GithubWrapper.paginate_repos
  end

  task :public_repos, [:start_id, :stop_id] => :environment do |t, args|
    require_relative '../api/github_repos_wrapper'
    
    GithubReposWrapper.paginate_repos(args.to_h)
  end
end

task "repos:gscores" => :environment do
  # TODO: update score doesn't exist yet
  Repository.update_score
end

def babysitter(task = NullTask.new)
  # Handles additional logging and error handling for the task
  start_time = Time.now
  begin
    yield
  rescue Exception => e
    completion_message = "Task #{task.name} completed ? FALSE : ERROR #{e.message}"
  end
  finish_time = Time.now

  completion_message = "Task complethttps://ruby-doc.org/core-2.2.0/File.htmlred ? TRUE" unless completion_message

  HttpLog.log(tag_meta("NAME: " + task.name))
  HttpLog.log(tag_meta("EXITED: " + completion_message))
  HttpLog.log(tag_meta("RUNTIME: #{(finish_time - start_time).seconds} seconds"))
  HttpLog.log(tag_meta("START: #{start_time}"))
  HttpLog.log(tag_meta("FINISH: #{finish_time}"))
  HttpLog.log(tag_meta("__END_OF_REQUEST_SEQUENCE__"))
  RequestsLogReport.present
end

def tag_meta(str)
  "|META| #{str}"
end

class NullTask
  attr_accessor :name, :desc

  def initialize
    @name = "UNNAMED"
    @desc = "NO DESCRIPTION"
  end
end
