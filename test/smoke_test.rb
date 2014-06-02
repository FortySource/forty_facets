require 'coveralls'
Coveralls.wear!

require "minitest/autorun"
require 'active_record'
require 'logger'
require_relative '../lib/forty_facets'

silence_warnings do
  ActiveRecord::Migration.verbose = false
  ActiveRecord::Base.logger = Logger.new(nil)
  ActiveRecord::Base.establish_connection(:adapter => "sqlite3", :database => ":memory:")
end

ActiveRecord::Base.connection.instance_eval do

  create_table :studios do |t|
    t.string :name
  end

  create_table :movies do |t|
    t.integer :studio_id
    t.integer :year
    t.string :title
    t.float :price
  end

end

class Studio < ActiveRecord::Base
end

class Movie < ActiveRecord::Base
  belongs_to :studio
end

class MovieSearch < FortyFacets::FacetSearch
  model 'Movie'

  text :title, name: 'Title'
  facet :studio, name: 'Studio'
  facet :year, order: Proc.new {|year| -year}
  range :price, name: 'Price'
end

studios = []
%w{A B C D}.each do |suffix|
  studios << Studio.create!(name: "Studio #{suffix}")
end

rand = Random.new
%w{Lorem ipsum dolor sit amet, consetetur sadipscing elitr, sed diam nonumy eirmod tempor invidunt ut labore et dolore magna aliquyam erat, sed diam voluptua. At vero eos et accusam et justo duo dolores et ea rebum. Stet clita kasd gubergren}.each_with_index do |title, index|
  Movie.create!(title: title, studio: studios[index % studios.length], price: rand.rand(20.0), year: (index%3 + 2010) )
end

class SmokeTest < Minitest::Test

  def test_it_finds_all_movies
    search = MovieSearch.new({})
    assert_equal Movie.all.size, search.result.size
  end

  def test_text_filter
    search = MovieSearch.new({'search' => { title: 'ipsum' }})
    assert_equal 1, search.result.size
    assert_equal 'ipsum', search.result.first.title
  end

  def test_year_filter
    search = MovieSearch.new({'search' => { year: '2011' }})
    assert_equal [2011], search.result.map(&:year).uniq

    facet = search.filter(:year).facet
    assert_equal Movie.count, facet.map(&:count).sum
  end

  def test_year_add_remove_filter

    search = MovieSearch.new()

    search = search.filter(:year).add(2010)
    assert_equal Movie.where(year: 2010).count, search.result.count

    search = search.filter(:year).add(2011)
    assert_equal Movie.where(year: [2010, 2011]).count, search.result.count

    search = search.filter(:year).remove(2010)
    assert_equal Movie.where(year: 2011).count, search.result.count
  end

  def test_selected_year_filter
    search = MovieSearch.new()

    search = search.filter(:year).add(2010)
    assert_equal [2010], search.filter(:year).selected

    search = search.filter(:year).add(2011)
    assert_equal [2010, 2011], search.filter(:year).selected

    facet = search.filter(:year).facet
    assert facet.find{|fv| fv.entity == 2010}.selected
    assert facet.find{|fv| fv.entity == 2011}.selected
    assert !facet.find{|fv| fv.entity == 2012}.selected
  end

  def test_belongs_to_filter
    blank_search = MovieSearch.new
    first_facet_value = blank_search.filter(:studio).facet.first
    studio = first_facet_value.entity
    assert_kind_of Studio, studio

    movies_with_studio = Movie.where(studio: studio)
    search_with_studio = blank_search.filter(:studio).add(studio)

    assert_equal movies_with_studio.size, search_with_studio.result.size
    assert_equal movies_with_studio.size, first_facet_value.count
  end

  def test_sort_by_proc
    blank_search = MovieSearch.new
    facet_entities = blank_search.filter(:year).facet.map(&:entity)
    assert_equal Movie.all.map(&:year).sort.uniq.reverse, facet_entities
  end

end
