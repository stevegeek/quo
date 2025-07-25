# Advanced Patterns and Examples

This document showcases advanced usage patterns and real-world examples of Quo query objects.

## Repository Pattern

### Basic Repository

```ruby
# app/repositories/user_repository.rb
class UserRepository
  class << self
    def active
      ActiveUsersQuery.new
    end
    
    def by_state(state)
      UsersByStateQuery.new(state: state)
    end
    
    def premium
      PremiumUsersQuery.new
    end
    
    def with_recent_activity(days: 7)
      RecentlyActiveUsersQuery.new(days_ago: days)
    end
    
    # Compose common combinations
    def active_premium_in_state(state)
      active + premium + by_state(state)
    end
  end
end

# Usage in controllers
class UsersController < ApplicationController
  def index
    @users = UserRepository
      .active_premium_in_state("CA")
      .transform { |u| UserPresenter.new(u) }
      .results
  end
end
```

### Repository with Caching

```ruby
class CachedUserRepository
  class << self
    def search(term, cached: true)
      if cached
        CachedSearchQuery.new(search_term: term)
      else
        LiveSearchQuery.new(search_term: term)
      end
    end
  end
end

class CachedSearchQuery < Quo::CollectionBackedQuery
  prop :search_term, String
  
  def collection
    Rails.cache.fetch("search_#{search_term}", expires_in: 5.minutes) do
      LiveSearchQuery.new(search_term:).results.to_a
    end
  end
end
```

## Composition

```ruby
class UserOnboardingService
  def initialize(user)
    @user = user
  end
  
  def recommended_connections
    # Compose multiple criteria
    query = SimilarUsersQuery.new(interests: @user.interests) +
            NearbyUsersQuery.new(location: @user.location, radius: 50) +
            ActiveInLastWeekQuery.new
    
    query.transform { |u| ConnectionRecommendation.new(@user, u) }
         .results
         .select(&:should_recommend?)
         .first(5)
  end
end
```

## Performance Monitoring

### Instrumented Queries

```ruby
class InstrumentedQuery < Quo::RelationBackedQuery
  def results
    ActiveSupport::Notifications.instrument(
      "query.quo",
      query_class: self.class.name,
      properties: to_h
    ) do
      super
    end
  end
end

# Subscribe to notifications
ActiveSupport::Notifications.subscribe("query.quo") do |*args|
  event = ActiveSupport::Notifications::Event.new(*args)
  
  Rails.logger.info(
    "Query: #{event.payload[:query_class]} " \
    "Duration: #{event.duration}ms " \
    "Properties: #{event.payload[:properties]}"
  )
  
  if event.duration > 1000  # Log slow queries
    SlowQueryLogger.log(event)
  end
end
```

### Query with Explain

```ruby
class AnalyzedQuery < Quo::RelationBackedQuery
  prop :analyze, Boolean, default: -> { Rails.env.development? }
  
  def results
    if analyze && relation?
      log_query_plan
    end
    super
  end
  
  private
  
  def log_query_plan
    plan = configured_query.explain
    Rails.logger.debug("Query Plan for #{self.class.name}:")
    Rails.logger.debug(plan)
    
    if plan.include?("Seq Scan") && configured_query.count > 1000
      Rails.logger.warn("Sequential scan detected on large table!")
    end
  end
end
```
