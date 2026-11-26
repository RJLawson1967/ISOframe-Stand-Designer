# frozen_string_literal: true
module ISOframe
  module StandDesigner
    module Tools
      module AddTable
        module_function

        # type_key is a Tables::REGISTRY key (currently 'keyboard'; more later).
        def toggle_selected!(type_key = 'keyboard')
          Tables.toggle_selected!(type_key)
        end
      end
    end
  end
end
