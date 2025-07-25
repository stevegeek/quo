# Testing and Configuration

This document covers testing strategies for Quo query objects and configuration options.

## Testing Support

Quo provides first-class testing support through helper modules that allow you to mock query results without hitting the database.

### Testing Helpers Overview

```ruby
# For Minitest
module Quo::Minitest::Helpers
  def fake_query(query_class, results: [], total_count: nil, page_count: nil, &block)
    # Mocks query_class.new to return fake results
  end
end

# For RSpec  
module Quo::RSpec::Helpers
  def fake_query(query_class, results: [], total_count: nil, page_count: nil, &block)
    # Same interface as Minitest version
  end
end
```

### Minitest Testing

#### Basic Usage

```ruby
class UserQueryTest < ActiveSupport::TestCase
  include Quo::Minitest::Helpers
  
  test "transforms users to presenters" do
    users = [
      User.new(id: 1, name: "Alice"),
      User.new(id: 2, name: "Bob")
    ]
    
    fake_query(UsersQuery, results: users) do
      query = UsersQuery.new.transform { |u| u.name.upcase }
      results = query.results.to_a
      
      assert_equal ["ALICE", "BOB"], results
    end
  end
  
  test "applies pagination" do
    users = (1..30).map { |i| User.new(id: i) }
    
    fake_query(UsersQuery, results: users) do
      query = UsersQuery.new(page: 2, page_size: 10)
      results = query.results
      
      assert_equal 10, results.page_count
      assert_equal 30, results.total_count
      assert_equal 11, results.first.id  # Page 2 starts at user 11
    end
  end
end
```

#### Testing Query Logic

```ruby
class ComplexQueryTest < ActiveSupport::TestCase
  include Quo::Minitest::Helpers
  
  test "filters by multiple conditions" do
    # Test the actual query logic
    query = ComplexUsersQuery.new(
      min_age: 21,
      state: "CA",
      active: true
    )
    
    sql = query.to_sql
    assert_match /age >= 21/, sql
    assert_match /state = 'CA'/, sql
    assert_match /active = true/, sql
  end
  
  test "composes queries correctly" do
    fake_query(ActiveUsersQuery, results: [User.new(id: 1)]) do
      fake_query(PremiumUsersQuery, results: [User.new(id: 2)]) do
        composed = ActiveUsersQuery.new + PremiumUsersQuery.new
        
        # The composition strategy determines final results
        results = composed.results.to_a
        assert_equal 2, results.count
      end
    end
  end
end
```

### RSpec Testing

#### Basic Usage

```ruby
RSpec.describe UsersQuery do
  include Quo::RSpec::Helpers
  
  describe "#results" do
    it "returns transformed users" do
      users = [User.new(name: "Alice"), User.new(name: "Bob")]
      
      fake_query(UsersQuery, results: users) do
        query = UsersQuery.new.transform { |u| UserPresenter.new(u) }
        results = query.results.to_a
        
        expect(results).to all(be_a(UserPresenter))
        expect(results.map(&:name)).to eq(["Alice", "Bob"])
      end
    end
  end
  
  describe "pagination" do
    it "respects page boundaries" do
      users = build_list(:user, 50)
      
      fake_query(UsersQuery, results: users) do
        query = UsersQuery.new(page: 3, page_size: 15)
        results = query.results
        
        expect(results.page_count).to eq(15)
        expect(results.total_count).to eq(50)
      end
    end
  end
end
```

#### Testing Composition

```ruby
RSpec.describe "Query Composition" do
  include Quo::RSpec::Helpers
  
  it "combines results from multiple queries" do
    active_users = [User.new(name: "Active")]
    premium_users = [User.new(name: "Premium")]
    
    fake_query(ActiveUsersQuery, results: active_users) do
      fake_query(PremiumUsersQuery, results: premium_users) do
        composed = ActiveUsersQuery.new + PremiumUsersQuery.new
        all_users = composed.results.to_a
        
        expect(all_users.map(&:name)).to contain_exactly("Active", "Premium")
      end
    end
  end
end
```

### Testing Implementation Details

#### How fake_query Works

```ruby
def fake_query(query_class, results: [], total_count: nil, page_count: nil, &block)
  if query_class < Quo::CollectionBackedQuery
    # Creates a fake collection-backed query
    klass = Class.new(Quo::Testing::CollectionBackedFake) do
      # Include Preloadable if original has it
      if query_class < Quo::Preloadable
        include Quo::Preloadable
      end
    end
    
    query_class.stub(:new, ->(**kwargs) {
      klass.new(results: results, total_count: total_count, page_count: page_count)
    }) do
      yield
    end
  elsif query_class < Quo::RelationBackedQuery
    # Creates a fake relation-backed query
    query_class.stub(:new, ->(**kwargs) {
      Quo::Testing::RelationBackedFake.new(
        results: results, 
        total_count: total_count, 
        page_count: page_count
      )
    }) do
      yield
    end
  end
end
```

#### Testing Fake Classes

```ruby
# CollectionBackedFake
module Quo::Testing
  class CollectionBackedFake < Quo::CollectionBackedQuery
    prop :results, _Array(_Any), default: -> { [] }
    prop :total_count, _Nilable(Integer)
    prop :page_count, _Nilable(Integer)
    
    def collection
      @results
    end
  end
end

# RelationBackedFake  
module Quo::Testing
  class RelationBackedFake < Quo::RelationBackedQuery
    prop :results, _Array(_Any), default: -> { [] }
    prop :total_count, _Nilable(Integer)
    prop :page_count, _Nilable(Integer)
    
    def query
      # Returns a relation-like object that behaves correctly
    end
  end
end
```

### Advanced Testing Patterns

#### Testing with Dependencies

```ruby
class ServiceQueryTest < ActiveSupport::TestCase
  include Quo::Minitest::Helpers
  
  setup do
    @api_client = mock('api_client')
  end
  
  test "fetches data from external service" do
    expected_data = [{ id: 1, name: "Remote User" }]
    @api_client.expects(:fetch_users).returns(expected_data)
    
    query = ExternalUsersQuery.new(api_client: @api_client)
    results = query.results.to_a
    
    assert_equal expected_data, results
  end
end
```

#### Testing Error Cases

```ruby
RSpec.describe UsersQuery do
  include Quo::RSpec::Helpers
  
  context "with invalid parameters" do
    it "raises ArgumentError for invalid state" do
      expect {
        UsersQuery.new(state: "INVALID")
      }.to raise_error(ArgumentError)
    end
  end
  
  context "when no results found" do
    it "returns empty results" do
      fake_query(UsersQuery, results: []) do
        query = UsersQuery.new(state: "XX")
        
        expect(query.results).to be_empty
        expect(query.results.exists?).to be false
        expect(query.results.count).to eq 0
      end
    end
  end
end
```

## Configuration

### Global Configuration

Configure Quo in an initializer:

```ruby
# config/initializers/quo.rb
module Quo
  # Pagination defaults
  self.default_page_size = 25
  self.max_page_size = 100
  
  # Custom base classes
  self.relation_backed_query_base_class = "ApplicationQuery"
  self.collection_backed_query_base_class = "ApplicationCollectionQuery"
end
```

### Configuration Options Explained

#### default_page_size

```ruby
# Sets the default page size when not specified
Quo.default_page_size = 25

# Used in Query base class
prop :page_size, _Nilable(Integer), 
  default: -> { Quo.default_page_size || 20 }

# Example impact
query = UsersQuery.new(page: 1)  # No page_size specified
query.page_size  # => 25 (from configuration)
```

#### max_page_size

```ruby
# Prevents excessive resource usage
Quo.max_page_size = 100

# Applied during sanitization
def sanitised_page_size
  if page_size&.positive?
    given_size = page_size.to_i
    max_page_size = Quo.max_page_size || 200
    given_size > max_page_size ? max_page_size : given_size
  else
    Quo.default_page_size || 20
  end
end

# Example protection
query = UsersQuery.new(page_size: 10000)  # Excessive!
query.results  # Actually uses page_size of 100
```

#### Custom Base Classes

```ruby
# app/queries/application_query.rb
class ApplicationQuery < Quo::RelationBackedQuery
  # Shared functionality for all relation queries
  
  # Add default scope
  def query
    super.where(tenant_id: Current.tenant_id)
  end
  
  # Add logging
  def results
    Rails.logger.info "Executing query: #{self.class.name}"
    super
  end
end

# app/queries/application_collection_query.rb
class ApplicationCollectionQuery < Quo::CollectionBackedQuery
  # Shared functionality for all collection queries
  
  include Quo::Preloadable  # All collections can preload
  
  # Add caching support
  def cached_collection(key, expires_in: 1.hour)
    Rails.cache.fetch(key, expires_in: expires_in) do
      collection
    end
  end
end

# Configure Quo to use these
Quo.relation_backed_query_base_class = "ApplicationQuery"
Quo.collection_backed_query_base_class = "ApplicationCollectionQuery"
```

### Environment-Specific Configuration

```ruby
# config/environments/development.rb
Quo.max_page_size = 50  # Smaller in development

# config/environments/production.rb  
Quo.max_page_size = 200  # Larger in production

# config/environments/test.rb
Quo.default_page_size = 10  # Smaller for faster tests
```

### Dynamic Configuration

```ruby
# Configuration can be changed at runtime
class AdminController < ApplicationController
  around_action :with_admin_pagination
  
  private
  
  def with_admin_pagination
    old_max = Quo.max_page_size
    Quo.max_page_size = 500  # Admins can see more
    yield
  ensure
    Quo.max_page_size = old_max
  end
end
```

## Testing Best Practices

### 1. Test Query Logic Separately

```ruby
# Test the query building logic
test "builds correct query" do
  query = ComplexQuery.new(filters: { active: true, role: "admin" })
  
  sql = query.to_sql
  assert_match /active = true/, sql
  assert_match /role = 'admin'/, sql
end

# Test the results separately with fake_query
test "transforms results correctly" do
  fake_query(ComplexQuery, results: [User.new]) do
    query = ComplexQuery.new.transform { |u| u.name.upcase }
    assert_equal "ALICE", query.results.first
  end
end
```

### 2. Use Factories

```ruby
# spec/support/query_helpers.rb
module QueryHelpers
  def build_fake_users(count: 10, **attributes)
    (1..count).map do |i|
      User.new(id: i, name: "User #{i}", **attributes)
    end
  end
end

# In tests
test "paginates correctly" do
  users = build_fake_users(count: 100)
  
  fake_query(UsersQuery, results: users) do
    # Test pagination
  end
end
```

### 3. Test Edge Cases

```ruby
describe "edge cases" do
  it "handles empty results" do
    fake_query(UsersQuery, results: []) do
      query = UsersQuery.new
      expect(query.results).to be_empty
    end
  end
  
  it "handles nil transformer" do
    fake_query(UsersQuery, results: [User.new]) do
      query = UsersQuery.new  # No transformer
      expect(query.results.first).to be_a(User)
    end
  end
  
  it "handles pagination beyond available results" do
    fake_query(UsersQuery, results: [User.new]) do
      query = UsersQuery.new(page: 999)
      expect(query.results).to be_empty
    end
  end
end
```

### 4. Integration Tests

```ruby
# Sometimes you want to test against real database
class IntegrationTest < ActiveSupport::TestCase
  # Don't include Quo::Minitest::Helpers
  
  test "actually queries database" do
    user = User.create!(name: "Real User", state: "CA")
    
    query = UsersQuery.new(state: "CA")
    results = query.results
    
    assert_includes results.to_a, user
  end
end
```