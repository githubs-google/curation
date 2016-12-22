class RubyGem < ActiveRecord::Base
  include Elasticsearch::Model
  include Elasticsearch::Model::Callbacks # auto imports to active record to keep them synchronized

  index_name ["ruby_gem", Rails.env].join('_') # create separate indexes for each environment

  def self.update_score
    avg_downloads = self.average(:downloads)
    avg_stars = self.average(:stars)

    star_multiplier = (avg_downloads / avg_stars) + 200

    self.all.each do |gem|
      score = gem.downloads + gem.stars * star_multiplier
      gem.update(score: score)
    end
  end

  def self.search(query, options={})
    search_definition = {
      query: {
        multi_match: {
          fuzziness: 2,
          query: query,
          fields: ["name^100", "description^50"],
          operator: "and"
        }
      },
      highlight: {
        fields: {
          description: {},
          name: {}
        }
      }
    }

    __elasticsearch__.search(search_definition)
  end

  def as_indexed_json(options={})
    as_json(
      only: [:name, :description],
    )
  end
end
