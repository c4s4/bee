require 'bee_task_package'

module Bee
  
  module Task
  
    # Package for Hello tasks.
    class Hello < Package
    
      # Sample hello task that prints greeting message on console.
      # 
      # - who: who to greet.
      # 
      # Example
      # 
      #  - hello.hello: "World"
      def hello(who)
        puts "Hello #{who}!"
      end

    end

  end

end
