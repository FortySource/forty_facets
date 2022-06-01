require 'coveralls'
Coveralls.wear!

require "minitest/autorun"
require 'test_helper'
require 'logger'
# require 'byebug'# travis doenst like byebug
require_relative '../lib/forty_facets'

#silence_warnings do
require_relative 'fixtures'
#end

class MovieSearch < FortyFacets::FacetSearch
  model 'Movie'

  text :title, name: 'Title'
  facet :studio, name: 'Studio'
  facet :year, order: Proc.new {|year| -year}
  facet :genres, name: 'Genre'
  facet :actors, name: 'Actor'
  range :price, name: 'Price'
  facet :writers, name: 'Writer'
  facet [:studio, :country], name: 'Country'
  facet [:studio, :status], name: 'Studio status'
  facet [:studio, :producers], name: 'Producers'
  sql_facet({ uschis: "studios.name = 'Uschi'", non_uschis: "studios.name != 'USCHI'" },
            { name: "Uschis", path: [:studio, :uschis], joins: [:studio] })
  sql_facet({ classic: "year <= 1980", non_classic: "year > 1980" },
            { name: "Classic", path: :classic })
  sql_facet({ classic: "year <= 1980", non_classic: "year > 1980" },
            { name: "Classic" })
  text [:studio, :description], name: 'Studio Description'
  scope :classics, name: 'Name classics'
  scope :year_lte, name: 'Year less than or equal', pass_value: true
  custom :needs_complex_filtering
end

class SmokeTest < Minitest::Test

  def test_sql_facet_with_belongs_to
    search = MovieSearch.new({'studio-uschis' => {}})
    assert_equal Movie.count, search.result.size
    assert_equal search.filter([:studio, :uschis]).facet, [FortyFacets::FacetValue.new(:uschis, 0, false), FortyFacets::FacetValue.new(:non_uschis, 40, false)]
  end

  def test_it_finds_all_movies
    search = MovieSearch.new({})
    assert_equal Movie.all.size, search.result.size
  end

  def test_scope_filter
    search = MovieSearch.new("search" => {})
    assert_equal 40, search.result.size
    assert search.filter(:classic).facet.include? FortyFacets::FacetValue.new(:classic, 6, false)
    assert search.filter(:classic).facet.include? FortyFacets::FacetValue.new(:non_classic, 34, false)

    search = MovieSearch.new("search" => { "classic" => "classic" })
    assert_equal 6, search.result.size
    assert search.filter(:classic).facet.include? FortyFacets::FacetValue.new(:classic, 6, true)
    assert search.filter(:classic).facet.include? FortyFacets::FacetValue.new(:non_classic, 34, false)

    search = MovieSearch.new("search" => { "classic" => "non_classic" })
    assert_equal 34, search.result.size
    assert search.filter(:classic).facet.include? FortyFacets::FacetValue.new(:classic, 6, false)
    assert search.filter(:classic).facet.include? FortyFacets::FacetValue.new(:non_classic, 34, true)

    search = MovieSearch.new("search" => { "classic" => ["non_classic", "classic"] })
    assert_equal 40, search.result.size
    assert search.filter(:classic).facet.include? FortyFacets::FacetValue.new(:classic, 6, true)
    assert search.filter(:classic).facet.include? FortyFacets::FacetValue.new(:non_classic, 34, true)
  end

  def test_scope_filter_without_path
    search = MovieSearch.new("search" => {})
    assert_equal 40, search.result.size
    assert search.filter([:classic, :non_classic]).facet.include? FortyFacets::FacetValue.new(:classic, 6, false)
    assert search.filter([:classic, :non_classic]).facet.include? FortyFacets::FacetValue.new(:non_classic, 34, false)

    search = MovieSearch.new("search" => { "classic-non_classic" => "classic" })
    assert_equal 6, search.result.size
    assert search.filter([:classic, :non_classic]).facet.include? FortyFacets::FacetValue.new(:classic, 6, true)
    assert search.filter([:classic, :non_classic]).facet.include? FortyFacets::FacetValue.new(:non_classic, 34, false)

    search = MovieSearch.new("search" => { "classic-non_classic" => "non_classic" })
    assert_equal 34, search.result.size
    assert search.filter([:classic, :non_classic]).facet.include? FortyFacets::FacetValue.new(:classic, 6, false)
    assert search.filter([:classic, :non_classic]).facet.include? FortyFacets::FacetValue.new(:non_classic, 34, true)

    search = MovieSearch.new("search" => { "classic-non_classic" => ["non_classic", "classic"] })
    assert_equal 40, search.result.size
    assert search.filter([:classic, :non_classic]).facet.include? FortyFacets::FacetValue.new(:classic, 6, true)
    assert search.filter([:classic, :non_classic]).facet.include? FortyFacets::FacetValue.new(:non_classic, 34, true)
  end

  def test_text_filter
    search = MovieSearch.new({'search' => { 'title' => 'ipsum' }})
    assert_equal 1, search.result.size
    assert_equal 'ipsum', search.result.first.title
  end

  def test_year_filter
    search = MovieSearch.new({'search' => { 'year' => '2011' }})
    assert_equal [2011], search.result.map(&:year).uniq

    facet = search.filter(:year).facet
    assert_equal Movie.count, facet.map(&:count).sum
  end

  def test_range_filter
    search = MovieSearch.new({ 'search' => { 'price' => '0 - 20' } })
    assert_equal Movie.count, search.result.size

    search = MovieSearch.new({ 'search' => { 'price' => '5 - 10' } })
    assert_equal Movie.where('price >= ? AND price <= ?', 5, 10).count, search.result.size

    search = MovieSearch.new({ 'search' => { 'price' => '5 - ' } })
    assert_equal Movie.where('price >= ?', 5).count, search.result.size

    search = MovieSearch.new({ 'search' => { 'price' => ' - 5' } })
    assert_equal Movie.where('price <= ?', 5).count, search.result.size

    search = MovieSearch.new({ 'search' => { 'price' => '' } })
    assert_equal Movie.count, search.result.size
  end

  def test_text_filter_via_belongs_to
    description = Studio.first.description
    search = MovieSearch.new({'search' => { 'studio-description' => description }})

    assert_equal Movie.all.reject{|m| m.studio.description != description}.size, search.result.size
    assert_equal description, search.result.first.studio.description
  end

  def test_country_filter
    search = MovieSearch.new('search' => { 'studio-country' => Country.first.id.to_s})
    assert_equal [Country.first], search.result.map{|m| m.studio.country}.uniq
    assert_equal Movie.count / 2, search.result.count

    search = MovieSearch.new('search' => { 'studio-country' => Country.last.id.to_s})
    assert_equal [Country.last], search.result.map{|m| m.studio.country}.uniq
    assert_equal Movie.count / 2, search.result.count
  end

  def test_selected_country_filter
    search = MovieSearch.new('search' => { 'studio-country' => Country.first.id.to_s})
    filter = search.filter([:studio, :country])
    assert_equal FortyFacets::FacetFilterDefinition::BelongsToFilter, filter.class
    assert_equal [Country.first], filter.selected

    assert_equal Movie.count / 2, filter.facet.reject(&:selected).first.count
  end

  def test_studio_status_filter
    search = MovieSearch.new('search' => { 'studio-status' => 'active'})
    assert_equal ['active'], search.result.map{|m| m.studio.status}.uniq
    assert_equal Movie.count / 2, search.result.count

    filter = search.filter([:studio, :status])
    assert_equal ['active'], filter.selected
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

  def test_belongs_to_filter_with_default_scope
    wrap_in_db_transaction do
      deleted_studio = Studio.create!(name: 'Deleted studio', status: 'active')
      movie = Movie.create!(studio: deleted_studio)
      deleted_studio.update!(deleted_at: Time.now)

      blank_search = MovieSearch.new

      assert_equal(
        5, blank_search.filter(:studio).facet.length
      )
    end
  end

  def test_sort_by_proc
    blank_search = MovieSearch.new
    facet_entities = blank_search.filter(:year).facet.map(&:entity)
    assert_equal Movie.all.map(&:year).sort.uniq.reverse, facet_entities
  end

  def test_has_many
    blank_search = MovieSearch.new
    genre = Genre.first
    expected = Movie.order(:id).select{|m| m.genres.include?(genre)}
    assert blank_search.filter(:genres).is_a?(FortyFacets::FacetFilterDefinition::HasManyFilter)
    search = blank_search.filter(:genres).add(genre)
    actual = search.result

    assert_equal expected.size, actual.size
  end

  def test_hast_many_via_belongs_to
    blank_search = MovieSearch.new
    producer = Producer.first
    expected = Movie.order(:id).select{|m| m.studio.producers.include? producer}
    assert blank_search.filter([:studio, :producers]).is_a?(FortyFacets::FacetFilterDefinition::HasManyFilter)
    search = blank_search.filter([:studio, :producers]).add(producer)
    actual = search.result

    assert_equal expected.size, actual.size
  end

  def test_has_many_writers
    blank_search = MovieSearch.new
    writer = Writer.first
    expected = Movie.order(:id).select{|m| m.writers.include?(writer)}
    assert blank_search.filter(:writers).is_a?(FortyFacets::FacetFilterDefinition::HasManyFilter)
    search = blank_search.filter(:writers).add(writer)
    actual = search.result

    assert_equal expected.size, actual.size
  end

  def test_has_many_combo
    blank_search = MovieSearch.new
    genre = Genre.first
    actor = Actor.first
    expected = Movie.order(:id)
                .select{|m| m.genres.include?(genre)}
                .select{|m| m.actors.include?(actor)}
    assert blank_search.filter(:genres).is_a?(FortyFacets::FacetFilterDefinition::HasManyFilter)
    search_with_genre = blank_search.filter(:genres).add(genre)
    search_with_genre_and_actor = search_with_genre.filter(:actors).add(actor)
    actual = search_with_genre_and_actor.result

    assert_equal expected.size, actual.size
  end

  def test_has_many_facet_values_writers
    selected_writer = Writer.first
    search = MovieSearch.new.filter(:writers).add(selected_writer)

    search.filter(:writers).facet.each do |facet_value|
      writer = facet_value.entity
      expected = Movie.order(:id).select{|m| m.writers.include?(writer)}.count
      assert_equal expected, facet_value.count, "The amount of movies for a writer should match the number indicated in the facet"
      assert_equal writer.id == selected_writer.id, facet_value.selected
    end

  end

  def test_has_many_facet_values_genres
    selected_genre = Genre.first
    search = MovieSearch.new.filter(:genres).add(selected_genre)

    search.filter(:genres).facet.each do |facet_value|
      genre = facet_value.entity
      expected = Movie.order(:id).select{|m| m.genres.include?(genre)}.count
      assert_equal expected, facet_value.count, "The amount of movies for a genre should match the number indicated in the facet"
      assert_equal genre.id == selected_genre.id, facet_value.selected
    end

  end

  def test_includes_does_not_blow_up
    selected_genre = Genre.first
    search = MovieSearch.new({}, Movie.all.includes(:studio)).filter(:genres).add(selected_genre)
    search.filter(:studio).facet.reject(&:selected).to_a
  end

  def test_scope_filter
    search_with_scope = MovieSearch.new().filter(:classics).add('1')
    assert search_with_scope.result.count < Movie.count, 'Activating the scope should yield a smaller set of movies'
  end

  def test_scope_filter_with_params
    search_with_scope = MovieSearch.new().filter(:year_lte).add(1980)
    assert search_with_scope.result.count < Movie.count, 'Activating the scope with filter should yield a smaller set of movies'
  end

  def test_custom_filter
    search = MovieSearch.new
    new_search = search.filter(:needs_complex_filtering).set('foo')

    assert_equal 'foo', new_search.filter(:needs_complex_filtering).value
  end

end
