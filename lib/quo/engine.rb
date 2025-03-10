# rbs_inline: enabled

module Quo
  class Engine < ::Rails::Engine
    isolate_namespace Quo

    rake_tasks do
      load "tasks/quo.rake"
    end
  end
end
