# The priority queue is a queue of queues
class PriorityQueue
  PRIORITY_RANGE = (1..10).to_a

  def initialize(enqueue: false, query: "stars > 10000", rescore: false)
    @queue_base_name = ENV['REDIS_PRIORITY_QUEUE_BASE_NAME']
    enqueue_redis(query, rescore) if enqueue

    @unique_queues = generate_queues
    @queues = skewed_dist_of_queues(@unique_queues)
  end

  def next
    # get leftmost queue and push to the end
    queue = @queues.shift
    @queues.push(queue)
    # return the next repository
    queue.next
  end

  def enqueue_redis(query, rescore)
    tracked_repos = Repository.where(query)
    puts "Retrieved #{tracked_repos.count} repositories"

    puts "Scoring and ordering..."
    calculate_scores(tracked_repos) if rescore
    tracked_repos = tracked_repos.order(:score)

    puts "Creating prioritized queues..."
    enqueue_prioritized_sub_queues(tracked_repos)
  end

  private

  def enqueue_prioritized_sub_queues(tracked_repos)
    bucket_size = (tracked_repos.count.to_f / PRIORITY_RANGE.length).ceil

    # Enqueue a sub queue for each priority level
    index = 0
    tracked_repos.in_batches(of: bucket_size) do |batch|
      priority = PRIORITY_RANGE[index]
      queue_name = sub_queue_name(priority.to_s)
      index += 1

      sub_queue = CircularRedisQueue.new(batch, queue_name)
      sub_queue.enqueue_redis
    end
  end

  # For enqueing
  def calculate_scores
    count = 0
    tracked_repos.in_batches do |batch|
      batch.each do |repo|
        repo.update_score
        count += 1
        puts "#{count} repos scored"
      end
    end
  end

  # For operation
  def generate_queues
    priority_tags = PRIORITY_RANGE

    unique_queues = []
    priority_tags.each do |tag|
      queue_name = sub_queue_name(tag.to_s)
      unique_queues << CircularRedisQueue.new(queue_name)
    end
    unique_queues
  end

  def skewed_dist_of_queues(queues)
    # Want to create a distribution like:
    #   [3, 2, 1] + [3, 2] + [3]
    skewed_dist_of_queues = []
    while queues.length > 0
      queues.each do |queue|
        skewed_dist_of_queues << queue
      end
      queues.pop
    end
    skewed_dist_of_queues
  end

  def sub_queue_name(extension)
    @queue_base_name + "_" + extension
  end
end
