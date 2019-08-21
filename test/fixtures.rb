require 'active_record'

ActiveRecord::Migration.verbose = false
ActiveRecord::Base.logger = Logger.new(nil)
ActiveRecord::Base.establish_connection(:adapter => "sqlite3", :database => ":memory:")

ActiveRecord::Schema.define do
  create_table :countries do |t|
    t.string :name
  end

  create_table :studios do |t|
    t.integer :country_id
    t.string :status
    t.string :name
    t.string :description
    t.datetime :deleted_at
  end

  create_table :producers do |t|
    t.string :name
  end

  create_table :actors do |t|
    t.string :name
  end

  create_table :writers do |t|
    t.string :name
  end

  create_table :genres do |t|
    t.string :name
  end

  create_table :movies do |t|
    t.integer :studio_id
    t.integer :year
    t.string :title
    t.float :price
  end

  create_table :actors_movies do |t|
    t.integer :movie_id
    t.integer :actor_id
  end

  create_table :movies_writers do |t|
    t.integer :movie_id
    t.integer :writer_id
  end

  create_table :genres_movies do |t|
    t.integer :movie_id
    t.integer :genre_id
  end

  create_table :producers_studios do |t|
    t.integer :producer_id
    t.integer :studio_id
  end

end

class Producer < ActiveRecord::Base
end

class Actor < ActiveRecord::Base
end

class Writer < ActiveRecord::Base
end

class Genre < ActiveRecord::Base
end

class Country < ActiveRecord::Base
end

class Studio < ActiveRecord::Base
  belongs_to :country
  has_and_belongs_to_many :producers

  default_scope ->{ where(deleted_at: nil) }
  scope :with_deleted, ->{ unscope(where: :deleted_at) }
end

class Movie < ActiveRecord::Base
  belongs_to :studio, ->{ with_deleted }
  has_and_belongs_to_many :genres
  has_and_belongs_to_many :actors
  has_and_belongs_to_many :writers

  scope :classics, -> { where("year <= ?", 1980) }
  scope :non_classics, -> { where("year > ?", 1980) }
  scope :year_lte, -> (year) { where("year > ?", year) }
end

LOREM = %w{Lorem ipsum dolor sit amet, consetetur sadipscing elitr, sed diam nonumy eirmod tempor invidunt ut labore et dolore magna aliquyam erat, sed diam voluptua. At vero eos et accusam et justo duo dolores et ea rebum. Stet clita kasd gubergren}

countries = []
%w{US UK}.each do |code|
  countries << Country.create!(name: code)
end

producers = []
%w(Smith Logan Kelly Anderson Hendricks Bush).each do |name|
  producers << Producer.create!(name: name)
end


studios = []
%w{A B C D}.each_with_index do |suffix, index|
  studio = Studio.create!(name: "Studio #{suffix}", status: %w(active inactive)[index % 2],
    country: countries[index % countries.length], description: LOREM.shuffle.take(5).join(' '))

  3.times do
    producer = producers[rand(producers.length)]
    unless studio.producers.include? producer
      studio.producers << producer
    end
  end

  studios << studio
end

genres = []
%w{horror thriller drama comedy family action documentery}.each do |genre_name|
  genres << Genre.create!(name: genre_name)
end

actors = []
%w{Matt Julie Tom Brad Tony Dustin Lucy Jenny}.each do |actor_name|
  actors << Actor.create!(name: actor_name)
end

writers = []
%w{Matt Julie Tom Brad Tony Dustin Lucy Jenny}.each do |writer_name|
  writers << Writer.create!(name: writer_name)
end

rand = Random.new
LOREM.each_with_index do |title, index|
  m = Movie.create!(title: title, studio: studios[index % studios.length],
                    price: rand.rand(20.0), year: (index + 1975))
  3.times do
    actor = actors[rand(actors.length)]
    unless m.actors.include? actor
      m.actors << actor
    end
  end
  3.times do
    writer = writers[rand(writers.length)]
    unless m.writers.include? writer
      m.writers << writer
    end
  end
  rand(6).to_i.times do
    genre = genres[rand(genres.length)]
    unless m.genres.include? genre
      m.genres << genre
    end
  end
end


