# frozen_string_literal: true
# Lumen product shell (v0.1.81). Empty — do not call Wave APIs from here.

module ISOframe
  module StandDesigner
    module Products
      module Lumen
        module_function

        PRODUCT_ID = 'lumen'

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
