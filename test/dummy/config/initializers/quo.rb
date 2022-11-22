Quo.configure do |config|
  config.formatted_query_log = true
  config.query_show_callstack_size = 5
  config.logger = Rails.logger
end
