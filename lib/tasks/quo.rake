# frozen_string_literal: true

desc "List all the query objects in the app"
namespace :quo do
  task list: :environment do
    # In development classes are lazily loaded, so can't use Quo::Query.descendants.
    # Instead we search all *_query.rb files
    Dir["#{Rails.root}/**/*_query.rb"].each do |file|
      source_code = File.read(file)
      result = source_code.match(/class\s+([A-Za-z0-9_:]+)\s*<\s*(::)?Quo::Query/)
      puts (result && result[1]) ? "\n\n> #{result[1]}" : "Class name could not be determined"
      puts "\n"
      comments = source_code.match(/((#[^\n]+\n)*)[^\n]+lass/)
      puts (comments && comments[1].present?) ? comments[1] : "No description for class found"
      puts "\n"
      puts "Found in:"
      puts "    - #{file}"
    end
  end
end
