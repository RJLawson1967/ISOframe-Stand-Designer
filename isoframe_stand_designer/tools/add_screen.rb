# frozen_string_literal: true
module ISOframe
  module StandDesigner
    module Tools
      module AddScreen
        module_function

        # kind: 'small' or 'large'
        def toggle_selected!(kind = 'small')
          Screens.toggle_selected!(kind)
        end
      end
    end
  end
end
