# FortyFacets

FortyFacets lets you easily build explorative search interfaces based on fields of your ActiveRecord models.

![demo](demo.gif)

Try a [working demo](http://forty-facets-demo.herokuapp.com/ "Testinstallation on heroku")!

It offers a simple API to create an interactive UI to browse your data by iteratively adding
filter values.

The search is purely done via SQL queries, which are automatically generated via the AR-mappings.

Narrowing down the search result is done purely via `GET` requests. This way all steps are bookmarkable. This way the search natively works together with turbolinks as well.

There is no JavaScript involved. The collection returned is a normal ActiveRecord collection - this way it works seamlessly together with other GEMs like will_paginate

## Installation

Add this line to your application's Gemfile:

    gem 'forty_facets'

And then execute:

    $ bundle

Or install it yourself as:

    $ gem install forty_facets

## Usage

You can clone a working example at https://github.com/fortytools/forty_facets_demo

If you have Movies with a textual title, categotized by genre, studio and year ..

    class Movie < ActiveRecord::Base
      belongs_to :year
      belongs_to :genre
      belongs_to :studio
    end

You can then declare the structure of your search like so:

```ruby
class HomeController < ApplicationController

  class MovieSearch < FortyFacets::FacetSearch
    model 'Movie' # which model to search for
    text :title   # filter by a generic string entered by the user
    facet :genre, name: 'Genre' # generate a filter with all values of 'genre' occuring in the result
    facet :year, name: 'Releaseyear', order: :year # additionally oder values in the year field
    facet :studio, name: 'Studio', order: :name
  end

  def index
    @search = MovieSearch.new(params) # this initializes your search object from the request params
    @movies = @search.result.paginate(page: params[:page], per_page: 5) # optionally paginate through your results
  end
```

In your view you can iterate the result like any other ActiveRecord collection

```haml
%table.table.table-condensed
  %tbody
    - @movies.each do |movie|
      %tr
        %td
          %strong=movie.title
```

Use the search object to display further narrowing options to the user

```haml
- filter = @search.filter(:genre)
.col-md-4
  .filter
    .filter-title= filter.name
    .filter-values
      %ul.selected
        - filter.selected.each do |genre|
          %li= link_to genre.name, filter.remove(genre).path
      %ul.selectable
        - filter.facet.reject(&:selected).each do |facet_value|
          - genre = facet_value.genre
          %li
            = link_to genre.name, filter.add(genre).path
            %span.count= "(#{facet_value.count})"
```

## FAQ

### Can I create filter for `has_many` associations ?

No. At the moment only objects directly related via a `belongs_to` can be used as filter.

## Contributing

1. Fork it ( http://github.com/fortytools/forty_facets/fork )
2. Create your feature branch (`git checkout -b my-new-feature`)
3. Commit your changes (`git commit -am 'Add some feature'`)
4. Push to the branch (`git push origin my-new-feature`)
5. Create new Pull Request
