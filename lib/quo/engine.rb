# rbs_inline: enabled

module Quo
  # Rails engine for integrating Quo with Rails applications
  class Engine < ::Rails::Engine
    isolate_namespace Quo

    rake_tasks do
      load "tasks/quo.rake"
    end
  end
end
