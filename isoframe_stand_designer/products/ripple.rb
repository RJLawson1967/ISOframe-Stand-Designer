# frozen_string_literal: true
# Ripple product shell (v0.1.81). Empty — do not call Wave APIs from here.

module ISOframe
  module StandDesigner
    module Products
      module Ripple
        module_function

        PRODUCT_ID = 'ripple'

        def ready?
          false
        end

        def coming_soon_message
          Products.coming_soon_message(PRODUCT_ID)
        end
      end
    end
  end
end
