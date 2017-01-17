# Get commit info from each repo using the redis queue
namespace :dispatch do

  task :priority_commits => :environment do |t|
    puts "Dispatching priority commits scraping pathway..."
    ScraperDispatcher.scrape(queue_name: "prioritized_repositories")
  end

  task :scrape_commits => :environment do |t|
    puts "Dispatching commits scraping pathway..."
    ScraperDispatcher.scrape_commits
  end

  task :scrape_issues => :environment do |t|
    puts "Dispatching commits and issues scraping pathway..."
    ScraperDispatcher.scrape_issues
  end

  task :scrape_metadata => :environment do |t|
    puts "Dispatching agent to work on blank repositories scraping metadata..."
    ScraperDispatcher.scrape_metadata
  end

  task :scrape_once => :environment do |t|
    puts "Dispatching priority commits scraping pathway..."
    ScraperDispatcher.scrape_once
  end
end
